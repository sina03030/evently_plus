import 'package:evently_plus/evently_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PageRoute<void> page(String name) {
    return PageRouteBuilder<void>(
      settings: RouteSettings(name: name),
      pageBuilder: (_, __, ___) => const SizedBox(),
    );
  }

  group('EventlyNavigatorObserver', () {
    test('measures each visible page with millisecond precision', () {
      var elapsed = Duration.zero;
      final measurements = <EventlyScreenTime>[];
      final observer = EventlyNavigatorObserver(
        elapsedTime: () => elapsed,
        onScreenTime: measurements.add,
      );
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

      final home = page('/home');
      final details = page('/details');

      observer.didPush(home, null);
      elapsed += const Duration(milliseconds: 1250);
      observer.didPush(details, home);
      elapsed += const Duration(milliseconds: 375);
      observer.didPop(details, home);

      expect(measurements, hasLength(2));
      expect(measurements[0].screenName, '/home');
      expect(measurements[0].duration, const Duration(milliseconds: 1250));
      expect(measurements[0].properties, {
        'duration_milliseconds': 1250,
        'duration_seconds': 1.25,
      });
      expect(measurements[1].screenName, '/details');
      expect(measurements[1].duration, const Duration(milliseconds: 375));

      observer.dispose();
    });

    test('keeps timing the page while an ignored popup is on top', () {
      var elapsed = Duration.zero;
      final measurements = <EventlyScreenTime>[];
      final observer = EventlyNavigatorObserver(
        elapsedTime: () => elapsed,
        onScreenTime: measurements.add,
      );
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

      final home = page('/home');
      final details = page('/details');
      final popup = RawDialogRoute<void>(
        pageBuilder: (_, __, ___) => const SizedBox(),
      );

      observer.didPush(home, null);
      elapsed += const Duration(milliseconds: 400);
      observer.didPush(popup, home);
      elapsed += const Duration(milliseconds: 600);
      observer.didPop(popup, home);
      observer.didPush(details, home);

      expect(measurements, hasLength(1));
      expect(measurements.single.screenName, '/home');
      expect(
        measurements.single.duration,
        const Duration(milliseconds: 1000),
      );

      observer.dispose();
    });

    test('ends a visible period when the app leaves the foreground', () {
      var elapsed = Duration.zero;
      final measurements = <EventlyScreenTime>[];
      final observer = EventlyNavigatorObserver(
        elapsedTime: () => elapsed,
        onScreenTime: measurements.add,
      );
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

      final home = page('/home');
      final details = page('/details');

      observer.didPush(home, null);
      elapsed += const Duration(seconds: 2);
      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
      elapsed += const Duration(seconds: 10);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      elapsed += const Duration(seconds: 3);
      observer.didPush(details, home);

      expect(
        measurements.map((measurement) => measurement.duration),
        [
          const Duration(seconds: 2),
          const Duration(seconds: 3),
        ],
      );

      observer.dispose();
    });

    test('handles route replacement and removal', () {
      var elapsed = Duration.zero;
      final measurements = <EventlyScreenTime>[];
      final observer = EventlyNavigatorObserver(
        elapsedTime: () => elapsed,
        onScreenTime: measurements.add,
      );
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

      final home = page('/home');
      final details = page('/details');

      observer.didPush(home, null);
      elapsed += const Duration(seconds: 1);
      observer.didReplace(newRoute: details, oldRoute: home);
      elapsed += const Duration(seconds: 2);
      observer.didRemove(details, null);

      expect(
        measurements
            .map((measurement) => (
                  measurement.screenName,
                  measurement.duration,
                ))
            .toList(),
        [
          ('/home', const Duration(seconds: 1)),
          ('/details', const Duration(seconds: 2)),
        ],
      );

      observer.dispose();
    });

    test('normalizes negative elapsed time to zero', () {
      var elapsed = const Duration(seconds: 2);
      final measurements = <EventlyScreenTime>[];
      final observer = EventlyNavigatorObserver(
        elapsedTime: () => elapsed,
        onScreenTime: measurements.add,
      );
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

      final home = page('/home');
      final details = page('/details');
      observer.didPush(home, null);
      elapsed = const Duration(seconds: 1);
      observer.didPush(details, home);

      expect(measurements.single.duration, Duration.zero);

      observer.dispose();
    });
  });
}
