import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/evently_config.dart';

/// Persists the SDK configuration needed by the Workmanager isolate.
class BackgroundUploadConfigStore {
  static const String _storageKey = 'evently_plus_background_upload_config';

  final SharedPreferences preferences;

  const BackgroundUploadConfigStore(this.preferences);

  Future<void> save(EventlyConfig config) async {
    await preferences.setString(
      _storageKey,
      jsonEncode({
        'uploadEndpoint': config.uploadEndpoint.toString(),
        'requestHeaders': config.requestHeaders,
        'environment': config.environment,
        'debugMode': config.debugMode,
        'requestTimeoutMilliseconds': config.requestTimeout.inMilliseconds,
        'enableBackgroundUpload': config.enableBackgroundUpload,
        'enableWebUpload': config.enableWebUpload,
        'backgroundUploadFrequencyMilliseconds':
            config.backgroundUploadFrequency.inMilliseconds,
        'appVersion': config.appVersion,
        'releaseMarket': config.releaseMarket,
      }),
    );
  }

  Future<EventlyConfig?> load() async {
    await preferences.reload();
    final value = preferences.getString(_storageKey);
    if (value == null || value.isEmpty) return null;

    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      final requestHeaders = _readRequestHeaders(json);
      return EventlyConfig(
        uploadEndpoint: _readUploadEndpoint(json),
        requestHeaders: requestHeaders,
        environment: json['environment'] as String? ?? 'production',
        debugMode: json['debugMode'] as bool? ?? false,
        requestTimeout: _readRequestTimeout(json),
        enableBackgroundUpload: json['enableBackgroundUpload'] as bool? ?? true,
        enableWebUpload: json['enableWebUpload'] as bool? ?? true,
        backgroundUploadFrequency: Duration(
          milliseconds: (json['backgroundUploadFrequencyMilliseconds'] as num?)
                  ?.toInt() ??
              const Duration(hours: 1).inMilliseconds,
        ),
        appVersion: json['appVersion'] as String? ?? 'unknown',
        releaseMarket: json['releaseMarket'] as String? ?? 'unknown',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() => preferences.remove(_storageKey);

  static Uri _readUploadEndpoint(Map<String, dynamic> json) {
    final endpoint = json['uploadEndpoint'] as String?;
    if (endpoint != null && endpoint.isNotEmpty) return Uri.parse(endpoint);

    // Migrate configuration saved by local versions that accepted a base URL
    // and appended `/store` inside the uploader.
    final legacyServerUrl = json['serverUrl'] as String;
    return Uri.parse(
        '${legacyServerUrl.replaceFirst(RegExp(r'/+$'), '')}/store');
  }

  static Map<String, String> _readRequestHeaders(Map<String, dynamic> json) {
    final savedHeaders = json['requestHeaders'];
    final headers = <String, String>{};
    if (savedHeaders is Map) {
      for (final entry in savedHeaders.entries) {
        headers[entry.key.toString()] = entry.value.toString();
      }
    }

    // Migrate the old Bearer-token convenience option without retaining that
    // authentication assumption in the public API.
    final legacyApiKey = json['apiKey'] as String?;
    if (legacyApiKey != null &&
        legacyApiKey.isNotEmpty &&
        !headers.keys.any((name) => name.toLowerCase() == 'authorization')) {
      headers['Authorization'] = 'Bearer $legacyApiKey';
    }
    return headers;
  }

  static Duration _readRequestTimeout(Map<String, dynamic> json) {
    final milliseconds = json['requestTimeoutMilliseconds'] as num?;
    if (milliseconds != null) {
      return Duration(milliseconds: milliseconds.toInt());
    }

    final legacySeconds = json['requestTimeoutSeconds'] as num?;
    return Duration(seconds: legacySeconds?.toInt() ?? 30);
  }
}
