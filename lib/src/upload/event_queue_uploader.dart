import '../data/datasources/event_local_datasource.dart';
import '../data/datasources/event_remote_datasource.dart';

/// Uploads one snapshot of the durable event queue.
///
/// Scheduling is deliberately kept outside this class. Mobile background work
/// and web runtime delivery can therefore share the same send-and-remove flow.
class EventQueueUploader {
  final EventLocalDataSource localDataSource;
  final EventRemoteDataSource remoteDataSource;

  const EventQueueUploader({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  /// Sends the events currently in the queue and returns the number uploaded.
  ///
  /// Events are removed only after the complete batch succeeds. A failed
  /// request leaves the queue unchanged so a later attempt can retry it.
  Future<int> uploadPending() async {
    final events = await localDataSource.getEvents();
    if (events.isEmpty) return 0;

    await remoteDataSource.sendEvents(events);
    await localDataSource.removeEventsById(events.map((event) => event.id));
    return events.length;
  }
}
