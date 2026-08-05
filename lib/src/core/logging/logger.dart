import 'package:flutter/foundation.dart';

/// Log levels for structured logging.
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Logger interface for Evently SDK.
abstract class EventlyLogger {
  void log(LogLevel level, String message,
      [dynamic error, StackTrace? stackTrace]);
  void debug(String message);
  void info(String message);
  void warning(String message, [dynamic error]);
  void error(String message, [dynamic error, StackTrace? stackTrace]);
}

/// Default console logger implementation.
class ConsoleLogger implements EventlyLogger {
  final bool enabled;
  final String prefix;

  const ConsoleLogger({
    this.enabled = true,
    this.prefix = '[Evently]',
  });

  @override
  void log(
    LogLevel level,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    if (!enabled) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(7);
    final logMessage = '$timestamp $prefix $levelStr: $message';

    if (kDebugMode) {
      // ignore: avoid_print
      print(logMessage);
      if (error != null) {
        // ignore: avoid_print
        print('  └─ Error: $error');
      }
      if (stackTrace != null) {
        // ignore: avoid_print
        print('  └─ StackTrace:\n$stackTrace');
      }
    }
  }

  @override
  void debug(String message) => log(LogLevel.debug, message);

  @override
  void info(String message) => log(LogLevel.info, message);

  @override
  void warning(String message, [dynamic error]) {
    log(LogLevel.warning, message, error);
  }

  @override
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    log(LogLevel.error, message, error, stackTrace);
  }
}

/// Silent logger (no-op) for production or when logging is disabled.
class SilentLogger implements EventlyLogger {
  const SilentLogger();

  @override
  void log(LogLevel level, String message,
      [dynamic error, StackTrace? stackTrace]) {}

  @override
  void debug(String message) {}

  @override
  void info(String message) {}

  @override
  void warning(String message, [dynamic error]) {}

  @override
  void error(String message, [dynamic error, StackTrace? stackTrace]) {}
}
