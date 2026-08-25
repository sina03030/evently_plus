import '../error/exceptions.dart';

/// Configuration class for Evently SDK.
class EventlyConfig {
  /// The complete HTTP endpoint that receives event batches.
  ///
  /// Evently Plus uses this URI exactly as provided. It never appends a path.
  final Uri uploadEndpoint;

  /// Additional headers included with every upload request.
  ///
  /// Use this for authentication or server-specific headers. `Content-Type` is
  /// always set to `application/json` by Evently Plus.
  final Map<String, String> requestHeaders;

  /// Environment name (e.g., 'production', 'staging', 'development').
  final String environment;

  /// Enable debug logging.
  final bool debugMode;

  /// Timeout applied to each upload request.
  final Duration requestTimeout;

  /// Schedule periodic background uploads on Android and iOS.
  final bool enableBackgroundUpload;

  /// Upload queued events while the web app is open.
  ///
  /// Browsers do not provide reliable cross-browser background execution, so
  /// web delivery is retried when the page starts and after an event is queued.
  final bool enableWebUpload;

  /// Requested interval between Android background uploads.
  ///
  /// Android enforces a minimum interval of 15 minutes. On iOS, the equivalent
  /// frequency is configured in the host app and remains best-effort.
  final Duration backgroundUploadFrequency;

  /// Version value attached to every event as `app_version`.
  final String appVersion;

  /// Distribution market attached to every event as `release_market`.
  final String releaseMarket;

  EventlyConfig({
    required this.uploadEndpoint,
    Map<String, String> requestHeaders = const {},
    this.environment = 'production',
    this.debugMode = false,
    this.requestTimeout = const Duration(seconds: 30),
    this.enableBackgroundUpload = true,
    this.enableWebUpload = true,
    this.backgroundUploadFrequency = const Duration(hours: 1),
    this.appVersion = 'unknown',
    this.releaseMarket = 'unknown',
  }) : requestHeaders = Map.unmodifiable(requestHeaders);

  /// Upload endpoint without query parameters, fragments, or user information.
  ///
  /// This representation is safe for diagnostic logs that should not expose
  /// credentials or tenant identifiers embedded in the endpoint URI.
  String get redactedUploadEndpoint => Uri(
        scheme: uploadEndpoint.scheme,
        host: uploadEndpoint.host,
        port: uploadEndpoint.hasPort ? uploadEndpoint.port : null,
        path: uploadEndpoint.path,
      ).toString();

  /// Validate the configuration.
  void validate() {
    if (!uploadEndpoint.hasScheme || uploadEndpoint.host.isEmpty) {
      throw const ConfigurationException(
        'Upload endpoint must be an absolute HTTP or HTTPS URI',
      );
    }

    if (uploadEndpoint.scheme != 'http' && uploadEndpoint.scheme != 'https') {
      throw const ConfigurationException(
        'Upload endpoint must use http:// or https://',
      );
    }

    if (requestTimeout <= Duration.zero) {
      throw const ConfigurationException('Request timeout must be positive');
    }

    if (enableBackgroundUpload &&
        backgroundUploadFrequency < const Duration(minutes: 15)) {
      throw const ConfigurationException(
        'Background upload frequency must be at least 15 minutes',
      );
    }

    if (requestHeaders.keys.any((name) => name.trim().isEmpty)) {
      throw const ConfigurationException(
          'Request header names cannot be empty');
    }
  }

  /// Create a copy with modified fields.
  EventlyConfig copyWith({
    Uri? uploadEndpoint,
    Map<String, String>? requestHeaders,
    String? environment,
    bool? debugMode,
    Duration? requestTimeout,
    bool? enableBackgroundUpload,
    bool? enableWebUpload,
    Duration? backgroundUploadFrequency,
    String? appVersion,
    String? releaseMarket,
  }) {
    return EventlyConfig(
      uploadEndpoint: uploadEndpoint ?? this.uploadEndpoint,
      requestHeaders: requestHeaders ?? this.requestHeaders,
      environment: environment ?? this.environment,
      debugMode: debugMode ?? this.debugMode,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      enableBackgroundUpload:
          enableBackgroundUpload ?? this.enableBackgroundUpload,
      enableWebUpload: enableWebUpload ?? this.enableWebUpload,
      backgroundUploadFrequency:
          backgroundUploadFrequency ?? this.backgroundUploadFrequency,
      appVersion: appVersion ?? this.appVersion,
      releaseMarket: releaseMarket ?? this.releaseMarket,
    );
  }

  @override
  String toString() => 'EventlyConfig(uploadEndpoint: $uploadEndpoint, '
      'environment: $environment, debugMode: $debugMode)';
}
