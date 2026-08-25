import '../core/config/evently_config.dart';
import '../core/logging/logger.dart';
import '../data/datasources/event_local_datasource.dart';
import 'runtime_upload_scheduler_base.dart';
import 'runtime_upload_scheduler_stub.dart'
    if (dart.library.html) 'runtime_upload_scheduler_web.dart' as platform;

/// Creates the runtime scheduler selected for the current platform.
RuntimeUploadScheduler createRuntimeUploadScheduler({
  required EventlyConfig config,
  required EventLocalDataSource localDataSource,
  required EventlyLogger logger,
}) {
  return platform.createRuntimeUploadScheduler(
    config: config,
    localDataSource: localDataSource,
    logger: logger,
  );
}
