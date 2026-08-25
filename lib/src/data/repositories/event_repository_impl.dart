import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/logging/logger.dart';
import '../../domain/entities/event.dart';
import '../../domain/repositories/event_repository.dart';
import '../datasources/event_local_datasource.dart';
import '../models/event_model.dart';

/// Runtime repository that only persists events to the durable local queue.
///
/// Network delivery is intentionally owned by the platform upload schedulers,
/// keeping persistence independent from when each platform can send events.
class EventRepositoryImpl implements EventRepository {
  final EventLocalDataSource localDataSource;
  final EventlyLogger logger;

  EventRepositoryImpl({
    required this.localDataSource,
    required this.logger,
  });

  @override
  Future<Either<Failure, void>> trackEvent(Event event) async {
    try {
      // Validate event
      if (!event.isValid()) {
        final failure = ValidationFailure(
          'Invalid event: ${event.name}',
          'name',
        );
        logger.warning(failure.toString());
        return Left(failure);
      }

      final model = EventModel.fromEntity(event);
      await localDataSource.addEvent(model);
      logger.debug('Event added to queue: ${event.name}');

      return const Right(null);
    } catch (e, stackTrace) {
      logger.error('Error tracking event', e, stackTrace);
      return Left(
        StorageFailure('Failed to track event: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Event>>> getPendingEvents() async {
    try {
      final models = await localDataSource.getEvents();
      final events = models.map((m) => m.toEntity()).toList();
      return Right(events);
    } catch (e, stackTrace) {
      logger.error('Error getting pending events', e, stackTrace);
      return Left(
        StorageFailure('Failed to get pending events: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> clearPendingEvents() async {
    try {
      await localDataSource.clearEvents();
      return const Right(null);
    } catch (e, stackTrace) {
      logger.error('Error clearing pending events', e, stackTrace);
      return Left(
        StorageFailure('Failed to clear pending events: $e'),
      );
    }
  }
}
