import '../../domain/entities/event.dart';
import '../../core/error/exceptions.dart';

/// Data model for Event with JSON serialization.
class EventModel {
  final String id;
  final String name;
  final DateTime timestamp;
  final String? screenName;
  final Map<String, dynamic> properties;
  final String? userId;
  final String? sessionId;
  final String platform;
  final String appVersion;
  final String releaseMarket;

  const EventModel({
    required this.id,
    required this.name,
    required this.timestamp,
    this.screenName,
    this.properties = const {},
    this.userId,
    this.sessionId,
    this.platform = 'unknown',
    this.appVersion = 'unknown',
    this.releaseMarket = 'unknown',
  });

  /// Convert domain entity to data model.
  factory EventModel.fromEntity(Event event) {
    return EventModel(
      id: event.id,
      name: event.name,
      timestamp: event.timestamp,
      screenName: event.screenName,
      properties: event.properties,
      userId: event.userId,
      sessionId: event.sessionId,
      platform: event.platform,
      appVersion: event.appVersion,
      releaseMarket: event.releaseMarket,
    );
  }

  /// Convert data model to domain entity.
  Event toEntity() {
    return Event(
      id: id,
      name: name,
      timestamp: timestamp,
      screenName: screenName,
      properties: properties,
      userId: userId,
      sessionId: sessionId,
      platform: platform,
      appVersion: appVersion,
      releaseMarket: releaseMarket,
    );
  }

  /// Create from JSON map.
  factory EventModel.fromJson(Map<String, dynamic> json) {
    try {
      return EventModel(
        id: json['id'] as String,
        name: json['event_name'] as String,
        timestamp: DateTime.parse(json['occurred_at'] as String),
        screenName: json['screen_name'] as String?,
        properties: (json['properties'] as Map<String, dynamic>?) ?? {},
        userId: json['user_id'] as String?,
        sessionId: json['session_id'] as String?,
        platform: json['platform'] as String? ?? 'unknown',
        appVersion: json['app_version'] as String? ?? 'unknown',
        releaseMarket: json['release_market'] as String? ?? 'unknown',
      );
    } catch (e, stackTrace) {
      throw SerializationException(
        'Failed to deserialize EventModel from JSON',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() {
    try {
      return {
        'id': id,
        'event_name': name,
        'occurred_at': timestamp.toIso8601String(),
        if (screenName != null) 'screen_name': screenName,
        if (properties.isNotEmpty) 'properties': properties,
        if (userId != null) 'user_id': userId,
        if (sessionId != null) 'session_id': sessionId,
        'platform': platform,
        'app_version': appVersion,
        'release_market': releaseMarket,
      };
    } catch (e, stackTrace) {
      throw SerializationException(
        'Failed to serialize EventModel to JSON',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Validate the model.
  bool isValid() {
    if (name.isEmpty) return false;
    if (name.length > 255) return false;
    if (screenName != null && screenName!.length > 255) return false;
    return true;
  }

  @override
  String toString() => 'EventModel(id: $id, name: $name)';
}
