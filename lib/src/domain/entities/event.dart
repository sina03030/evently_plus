import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Immutable domain entity representing an analytics event.
class Event extends Equatable {
  /// Unique identifier for this event.
  final String id;

  /// Name of the event (e.g., 'button_click', 'page_view').
  final String name;

  /// Timestamp when the event occurred.
  final DateTime timestamp;

  /// Screen or page where the event occurred.
  final String? screenName;

  /// Additional event properties.
  final Map<String, dynamic> properties;

  /// User identifier (optional).
  final String? userId;

  /// Session identifier (optional).
  final String? sessionId;

  /// Platform on which this event was created.
  final String platform;

  /// Host application version at the time this event was created.
  final String appVersion;

  /// Distribution market for the host application.
  final String releaseMarket;

  const Event({
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

  /// Create an event with auto-generated ID and current timestamp.
  factory Event.create({
    required String name,
    String? screenName,
    Map<String, dynamic>? properties,
    String? userId,
    String? sessionId,
    String platform = 'unknown',
    String appVersion = 'unknown',
    String releaseMarket = 'unknown',
  }) {
    return Event(
      id: _generateId(),
      name: name,
      timestamp: DateTime.now(),
      screenName: screenName,
      properties: properties ?? {},
      userId: userId,
      sessionId: sessionId,
      platform: platform,
      appVersion: appVersion,
      releaseMarket: releaseMarket,
    );
  }

  /// Generate a unique ID for the event.
  static String _generateId() {
    return const Uuid().v4();
  }

  /// Validate the event.
  bool isValid() {
    if (name.isEmpty) return false;
    if (name.length > 255) return false;
    if (screenName != null && screenName!.length > 255) return false;
    return true;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        timestamp,
        screenName,
        properties,
        userId,
        sessionId,
        platform,
        appVersion,
        releaseMarket,
      ];

  @override
  String toString() => 'Event(id: $id, name: $name, timestamp: $timestamp)';
}
