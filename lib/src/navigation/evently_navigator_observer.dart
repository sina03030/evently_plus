import 'dart:async';

import 'package:flutter/widgets.dart';

import '../evently_client.dart';

/// A completed period during which a screen was visible in the foreground.
@immutable
class EventlyScreenTime {
  const EventlyScreenTime({
    required this.screenName,
    required this.duration,
  });

  /// The stable analytics name resolved from the route.
  final String screenName;

  /// Foreground-visible time for this screen visit.
  final Duration duration;

  /// Properties suitable for sending with an Evently event.
  Map<String, dynamic> get properties => {
        'duration_milliseconds': duration.inMilliseconds,
        'duration_seconds':
            duration.inMicroseconds / Duration.microsecondsPerSecond,
      };
}

/// Resolves a stable analytics name for a route.
typedef EventlyScreenNameResolver = String Function(Route<dynamic> route);

/// Receives a completed screen-time measurement.
typedef EventlyScreenTimeCallback = FutureOr<void> Function(
  EventlyScreenTime screenTime,
);

/// Tracks how long each page route is visible in the foreground.
///
/// Add the same observer instance to `MaterialApp.navigatorObservers` or to the
/// observer list exposed by another Flutter router.
///
/// By default, only [PageRoute] instances are considered screens. This keeps
/// dialogs, menus, and bottom sheets from interrupting the underlying screen's
/// timer. Supply [routeFilter] or [screenNameResolver] when the host app uses
/// custom route types or parameterized route names.
class EventlyNavigatorObserver extends NavigatorObserver
    with WidgetsBindingObserver {
  EventlyNavigatorObserver({
    EventlyClient? client,
    this.eventName = 'SCREEN_TIME_SPENT',
    this.onScreenTime,
    this.screenNameResolver = _defaultScreenNameResolver,
    this.routeFilter = _defaultRouteFilter,
    this.minimumDuration = Duration.zero,
    this.userIdProvider,
    Duration Function()? elapsedTime,
  })  : _client = client,
        assert(!minimumDuration.isNegative),
        _elapsedTime = elapsedTime ?? _createElapsedClock() {
    final binding = WidgetsBinding.instance;
    final lifecycleState = binding.lifecycleState;
    _isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
  }

  /// Event name used when [onScreenTime] is not supplied.
  final String eventName;

  /// Optional initialized client. When omitted, the current singleton is used.
  final EventlyClient? _client;

  /// Optional callback for applications that centralize analytics dispatch.
  final EventlyScreenTimeCallback? onScreenTime;

  /// Converts a route into a stable, low-cardinality screen name.
  final EventlyScreenNameResolver screenNameResolver;

  /// Selects which routes represent screens.
  final bool Function(Route<dynamic> route) routeFilter;

  /// Visits shorter than this duration are discarded.
  final Duration minimumDuration;

  /// Supplies the current user ID when the observer logs directly to Evently.
  final String? Function()? userIdProvider;

  final Duration Function() _elapsedTime;

  Route<dynamic>? _activeRoute;
  String? _activeScreenName;
  Duration? _visibleSince;
  late bool _isForeground;
  bool _disposed = false;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _activateIfScreen(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _revealAfterRemoving(route, previousRoute);
  }

  @override
  void didReplace({
    Route<dynamic>? newRoute,
    Route<dynamic>? oldRoute,
  }) {
    if (oldRoute != null && identical(_activeRoute, oldRoute)) {
      _setActiveRoute(newRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _revealAfterRemoving(route, previousRoute);
  }

  void _activateIfScreen(Route<dynamic> route) {
    if (_disposed || !routeFilter(route)) return;
    _setActiveRoute(route);
  }

  void _revealAfterRemoving(
    Route<dynamic> removedRoute,
    Route<dynamic>? revealedRoute,
  ) {
    if (_disposed || !identical(_activeRoute, removedRoute)) return;
    _setActiveRoute(revealedRoute);
  }

  void _setActiveRoute(Route<dynamic>? route) {
    if (identical(_activeRoute, route)) return;

    _finishVisiblePeriod();
    _activeRoute = null;
    _activeScreenName = null;
    if (route == null || !routeFilter(route)) return;

    final screenName = screenNameResolver(route).trim();
    if (screenName.isEmpty) return;

    _activeRoute = route;
    _activeScreenName = screenName;
    if (_isForeground) {
      _visibleSince = _elapsedTime();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;

    if (state == AppLifecycleState.resumed) {
      if (!_isForeground) {
        _isForeground = true;
        if (_activeRoute != null) {
          _visibleSince = _elapsedTime();
        }
      }
      return;
    }

    if (_isForeground) {
      _isForeground = false;
      _finishVisiblePeriod();
    }
  }

  /// Stops observation and records the current visible period, if any.
  void dispose() {
    if (_disposed) return;
    _finishVisiblePeriod();
    _disposed = true;
    _activeRoute = null;
    _activeScreenName = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  void _finishVisiblePeriod() {
    final visibleSince = _visibleSince;
    final screenName = _activeScreenName;
    _visibleSince = null;
    if (visibleSince == null || screenName == null) return;

    final elapsed = _elapsedTime() - visibleSince;
    final duration = elapsed.isNegative ? Duration.zero : elapsed;
    if (duration < minimumDuration) return;

    unawaited(
      _emit(
        EventlyScreenTime(
          screenName: screenName,
          duration: duration,
        ),
      ),
    );
  }

  Future<void> _emit(EventlyScreenTime screenTime) async {
    try {
      final callback = onScreenTime;
      if (callback != null) {
        await callback(screenTime);
        return;
      }

      final client = _client ??
          (EventlyClient.isInitialized ? EventlyClient.instance : null);
      if (client == null) return;

      await client.logEvent(
        name: eventName,
        screenName: screenTime.screenName,
        properties: screenTime.properties,
        userId: userIdProvider?.call(),
      );
    } catch (error, stackTrace) {
      final client = _client ??
          (EventlyClient.isInitialized ? EventlyClient.instance : null);
      client?.logger.error(
        'Failed to track screen time for ${screenTime.screenName}',
        error,
        stackTrace,
      );
    }
  }

  static bool _defaultRouteFilter(Route<dynamic> route) => route is PageRoute;

  static String _defaultScreenNameResolver(Route<dynamic> route) {
    final routeName = route.settings.name?.trim();
    if (routeName != null && routeName.isNotEmpty) return routeName;
    return route.runtimeType.toString();
  }

  static Duration Function() _createElapsedClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }
}
