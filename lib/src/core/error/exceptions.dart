/// Base exception for all Evently errors.
abstract class EventlyException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const EventlyException(
    this.message, {
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('EventlyException: $message');
    if (code != null) buffer.write(' (code: $code)');
    if (originalError != null) buffer.write('\nCaused by: $originalError');
    return buffer.toString();
  }
}

/// Thrown when SDK is not properly configured.
class ConfigurationException extends EventlyException {
  const ConfigurationException(
    super.message, {
    super.code = 'CONFIGURATION_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Thrown when network operations fail.
class NetworkException extends EventlyException {
  final int? statusCode;

  const NetworkException(
    super.message, {
    this.statusCode,
    super.code = 'NETWORK_ERROR',
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    if (statusCode != null) buffer.write(' (HTTP $statusCode)');
    return buffer.toString();
  }
}

/// Thrown when event validation fails.
class ValidationException extends EventlyException {
  final String field;

  const ValidationException(
    super.message,
    this.field, {
    super.code = 'VALIDATION_ERROR',
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() => 'ValidationException: $message (field: $field)';
}

/// Thrown when storage operations fail.
class StorageException extends EventlyException {
  const StorageException(
    super.message, {
    super.code = 'STORAGE_ERROR',
    super.originalError,
    super.stackTrace,
  });
}

/// Thrown when event serialization/deserialization fails.
class SerializationException extends EventlyException {
  const SerializationException(
    super.message, {
    super.code = 'SERIALIZATION_ERROR',
    super.originalError,
    super.stackTrace,
  });
}
