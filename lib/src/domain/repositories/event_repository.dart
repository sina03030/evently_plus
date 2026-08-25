import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/event.dart';

/// Repository interface for event operations.
///
/// This defines the contract for runtime event persistence. Transmission is
/// handled separately by the platform upload schedulers.
abstract class EventRepository {
  /// Track a single event.
  ///
  /// Returns [Right] with void on success.
  /// Returns [Left] with [Failure] on error.
  Future<Either<Failure, void>> trackEvent(Event event);

  /// Get events waiting for upload.
  ///
  /// Returns [Right] with list of events on success.
  /// Returns [Left] with [Failure] on error.
  Future<Either<Failure, List<Event>>> getPendingEvents();

  /// Clear pending events.
  ///
  /// Returns [Right] with void on success.
  /// Returns [Left] with [Failure] on error.
  Future<Either<Failure, void>> clearPendingEvents();
}
