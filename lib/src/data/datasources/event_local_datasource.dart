import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/error/exceptions.dart';
import '../../core/logging/logger.dart';
import '../models/event_model.dart';

/// Local data source for the durable background-upload queue.
abstract class EventLocalDataSource {
  /// Get all stored events.
  Future<List<EventModel>> getEvents();

  /// Clear all stored events.
  Future<void> clearEvents();

  /// Add a single event to storage.
  Future<void> addEvent(EventModel event);

  /// Remove events after they have been uploaded successfully.
  Future<void> removeEventsById(Iterable<String> eventIds);
}

/// SharedPreferences implementation of local data source.
class EventLocalDataSourceImpl implements EventLocalDataSource {
  static const String _eventStorageKeyPrefix = 'evently_queued_event_';

  final SharedPreferences prefs;
  final EventlyLogger logger;

  const EventLocalDataSourceImpl({
    required this.prefs,
    required this.logger,
  });

  @override
  Future<List<EventModel>> getEvents() async {
    try {
      // Background workers run in a separate isolate with their own
      // SharedPreferences cache, so always refresh before reading the queue.
      await prefs.reload();
      final eventsById = <String, EventModel>{};

      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_eventStorageKeyPrefix)) continue;
        final value = prefs.getString(key);
        if (value == null || value.isEmpty) continue;
        final event = EventModel.fromJson(
          jsonDecode(value) as Map<String, dynamic>,
        );
        eventsById[event.id] = event;
      }

      if (eventsById.isEmpty) {
        logger.debug('No stored events found');
        return [];
      }

      final events = eventsById.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      logger.debug('Retrieved ${events.length} event(s) from local storage');
      return events;
    } catch (e, stackTrace) {
      logger.error(
          'Failed to retrieve events from local storage', e, stackTrace);
      throw StorageException(
        'Failed to retrieve events from local storage',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> clearEvents() async {
    try {
      await prefs.reload();
      final eventKeys = prefs
          .getKeys()
          .where((key) => key.startsWith(_eventStorageKeyPrefix))
          .toList();
      for (final key in eventKeys) {
        await prefs.remove(key);
      }
      logger.debug('Cleared local event storage');
    } catch (e, stackTrace) {
      logger.error('Failed to clear local storage', e, stackTrace);
      throw StorageException(
        'Failed to clear local storage',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> addEvent(EventModel event) async {
    try {
      await prefs.setString(
        '$_eventStorageKeyPrefix${event.id}',
        jsonEncode(event.toJson()),
      );
      logger.debug('Saved event ${event.id} to local storage');
    } catch (e, stackTrace) {
      logger.error('Failed to add event to local storage', e, stackTrace);
      throw StorageException(
        'Failed to add event to local storage',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> removeEventsById(Iterable<String> eventIds) async {
    try {
      final ids = eventIds.toSet();
      if (ids.isEmpty) return;

      await prefs.reload();
      for (final id in ids) {
        await prefs.remove('$_eventStorageKeyPrefix$id');
      }
      logger.debug('Removed ${ids.length} uploaded event(s)');
    } catch (e, stackTrace) {
      logger.error('Failed to remove uploaded events', e, stackTrace);
      throw StorageException(
        'Failed to remove uploaded events',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
}
