import 'package:equatable/equatable.dart';

/// Base class for failures (functional error handling).
/// Use this for expected errors that should be handled gracefully.
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => 'Failure: $message${code != null ? ' ($code)' : ''}';
}

/// Failure when network operations fail.
class NetworkFailure extends Failure {
  final int? statusCode;

  const NetworkFailure(
    super.message, {
    this.statusCode,
    super.code,
  });

  @override
  List<Object?> get props => [...super.props, statusCode];
}

/// Failure when validation fails.
class ValidationFailure extends Failure {
  final String field;

  const ValidationFailure(
    super.message,
    this.field, {
    super.code,
  });

  @override
  List<Object?> get props => [...super.props, field];
}

/// Failure when storage operations fail.
class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.code});
}

/// Failure when configuration is invalid.
class ConfigurationFailure extends Failure {
  const ConfigurationFailure(super.message, {super.code});
}

/// Failure when serialization fails.
class SerializationFailure extends Failure {
  const SerializationFailure(super.message, {super.code});
}
