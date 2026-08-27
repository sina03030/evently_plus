import 'package:http/http.dart' as http;

import '../core/config/evently_config.dart';
import '../core/logging/logger.dart';
import '../data/datasources/event_local_datasource.dart';
import '../data/datasources/event_remote_datasource.dart';
import 'event_queue_uploader.dart';
import 'runtime_upload_scheduler_base.dart';

RuntimeUploadScheduler createRuntimeUploadScheduler({
  required EventlyConfig config,
  required EventLocalDataSource localDataSource,
  required EventlyLogger logger,
}) {
  if (!config.enableWebUpload) {
    return const NoopRuntimeUploadScheduler();
  }

  final client = http.Client();
  return WebRuntimeUploadScheduler(
    client: client,
    uploader: EventQueueUploader(
      localDataSource: localDataSource,
      remoteDataSource: EventRemoteDataSourceImpl(
        client: client,
        config: config,
        logger: logger,
      ),
    ),
    logger: logger,
  );
}

/// Serializes upload attempts made by the active browser page.
class WebRuntimeUploadScheduler implements RuntimeUploadScheduler {
  final http.Client client;
  final EventQueueUploader uploader;
  final EventlyLogger logger;

  Future<void>? _activeUpload;
  bool _uploadRequested = false;
  bool _disposed = false;

  WebRuntimeUploadScheduler({
    required this.client,
    required this.uploader,
    required this.logger,
  });

  @override
  Future<void> requestUpload() {
    if (_disposed) return Future<void>.value();

    _uploadRequested = true;
    return _activeUpload ??= _drainUploadRequests();
  }

  Future<void> _drainUploadRequests() async {
    // Let events logged in the same turn collect in one batch.
    await Future<void>.delayed(Duration.zero);

    while (_uploadRequested && !_disposed) {
      _uploadRequested = false;
      try {
        final uploadedCount = await uploader.uploadPending();
        if (uploadedCount > 0) {
          logger.info('Web upload sent $uploadedCount queued event(s)');
        }
      } catch (error, stackTrace) {
        logger.error(
          'Web upload failed; queued events will be retried later',
          error,
          stackTrace,
        );
      }
    }

    _activeUpload = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    client.close();
  }
}
