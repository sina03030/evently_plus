import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'background/background_upload_scheduler.dart';
import 'core/config/evently_config.dart';
import 'core/error/exceptions.dart';
import 'core/error/failures.dart';
import 'core/evently_version.dart';
import 'core/logging/logger.dart';
import 'data/datasources/event_local_datasource.dart';
import 'data/repositories/event_repository_impl.dart';
import 'domain/entities/event.dart';
import 'domain/repositories/event_repository.dart';
import 'upload/runtime_upload_scheduler.dart';
import 'upload/runtime_upload_scheduler_base.dart';

/// Main client for Evently SDK.
///
/// This is the primary interface for tracking analytics events.
/// Use the singleton instance via [EventlyClient.instance].
class EventlyClient {
  static EventlyClient? _instance;

  final EventlyConfig config;
  final EventlyLogger logger;
  final EventRepository repository;
  final String platform;
  final String appVersion;
  final String releaseMarket;
  final RuntimeUploadScheduler _runtimeUploadScheduler;

  /// Unique identifier shared by all events logged by this client runtime.
  final String sessionId;

  EventlyClient._({
    required this.config,
    required this.logger,
    required this.repository,
    required this.platform,
    required this.appVersion,
    required this.releaseMarket,
    required this.sessionId,
    required RuntimeUploadScheduler runtimeUploadScheduler,
  }) : _runtimeUploadScheduler = runtimeUploadScheduler;

  /// Get the singleton instance.
  ///
  /// Throws [ConfigurationException] if not initialized.
  static EventlyClient get instance {
    if (_instance == null) {
      throw const ConfigurationException(
        'EventlyClient not initialized. Call EventlyClient.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Check if the client is initialized.
  static bool get isInitialized => _instance != null;

  /// Initialize the Evently SDK.
  ///
  /// This must be called before using any other methods.
  ///
  /// Example:
  /// ```dart
  /// await EventlyClient.initialize(
  ///   config: EventlyConfig(
  ///     uploadEndpoint: Uri.parse('https://api.example.com/events'),
  ///     debugMode: true,
  ///   ),
  /// );
  /// ```
  static Future<void> initialize({
    required EventlyConfig config,
    EventlyLogger? logger,
    SharedPreferences? sharedPreferences,
  }) async {
    // Validate configuration
    config.validate();

    // Create logger
    final effectiveLogger = logger ??
        (config.debugMode ? const ConsoleLogger() : const SilentLogger());

    effectiveLogger.info(
      'Initializing Evently Plus SDK v$eventlyPlusSdkVersion',
    );
    effectiveLogger.debug(
      'Upload endpoint: ${config.redactedUploadEndpoint}',
    );
    effectiveLogger.debug('Environment: ${config.environment}');

    // Initialize dependencies
    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    final platform = _currentPlatform();

    final localDataSource = EventLocalDataSourceImpl(
      prefs: prefs,
      logger: effectiveLogger,
    );

    // Create repository
    final repository = EventRepositoryImpl(
      localDataSource: localDataSource,
      logger: effectiveLogger,
    );
    final runtimeUploadScheduler = createRuntimeUploadScheduler(
      config: config,
      localDataSource: localDataSource,
      logger: effectiveLogger,
    );

    // Create and store instance
    _instance?._runtimeUploadScheduler.dispose();
    _instance = EventlyClient._(
      config: config,
      logger: effectiveLogger,
      repository: repository,
      platform: platform,
      appVersion: config.appVersion,
      releaseMarket: config.releaseMarket,
      sessionId: const Uuid().v4(),
      runtimeUploadScheduler: runtimeUploadScheduler,
    );

    try {
      await configureBackgroundUpload(
        config: config,
        preferences: prefs,
        logger: effectiveLogger,
      );
    } catch (e, stackTrace) {
      // Event tracking remains available if the OS refuses to schedule
      // background work or the host app has not completed native setup.
      effectiveLogger.error(
        'Could not configure periodic background upload',
        e,
        stackTrace,
      );
    }

    // On web, retry anything retained from an earlier page session. This is a
    // no-op on platforms where Workmanager owns delivery.
    await runtimeUploadScheduler.requestUpload();

    effectiveLogger.info('Evently Plus SDK initialized successfully');
  }

  /// Reset the SDK instance (useful for testing).
  static void reset() {
    _instance?._runtimeUploadScheduler.dispose();
    _instance = null;
  }

  /// Track an analytics event.
  ///
  /// Example:
  /// ```dart
  /// await EventlyClient.instance.logEvent(
  ///   name: 'button_click',
  ///   screenName: 'HomeScreen',
  ///   properties: {'button_id': 'login_button'},
  /// );
  /// ```
  Future<void> logEvent({
    required String name,
    String? screenName,
    Map<String, dynamic>? properties,
    String? userId,
    String? sessionId,
  }) async {
    if (name.isEmpty) {
      throw const ValidationException('Event name cannot be empty', 'name');
    }

    final event = Event.create(
      name: name,
      screenName: screenName,
      properties: properties,
      userId: userId,
      sessionId: sessionId ?? this.sessionId,
      platform: platform,
      appVersion: appVersion,
      releaseMarket: releaseMarket,
    );

    logger.debug('Logging event: $name');

    final result = await repository.trackEvent(event);

    result.fold(
      (failure) {
        logger.error('Failed to track event: $failure');
        if (failure is ValidationFailure) {
          throw ValidationException(failure.message, failure.field);
        }
        throw StorageException(failure.message);
      },
      (_) {
        logger.debug('Event tracked successfully: $name');
        unawaited(_runtimeUploadScheduler.requestUpload());
      },
    );
  }

  /// Get the count of events waiting for upload.
  Future<int> getPendingEventCount() async {
    final result = await repository.getPendingEvents();
    return result.fold(
      (failure) {
        logger.warning('Failed to get pending event count: $failure');
        return 0;
      },
      (events) => events.length,
    );
  }

  /// Clear all events waiting for upload.
  Future<void> clearPendingEvents() async {
    logger.info('Clearing all pending events');
    final result = await repository.clearPendingEvents();

    result.fold(
      (failure) {
        logger.error('Failed to clear pending events: $failure');
        throw StorageException(failure.message);
      },
      (_) {
        logger.info('Pending events cleared successfully');
      },
    );
  }

  static String _currentPlatform() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return defaultTargetPlatform.name;
  }
}
