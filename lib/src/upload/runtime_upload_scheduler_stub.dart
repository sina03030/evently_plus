import '../core/config/evently_config.dart';
import '../core/logging/logger.dart';
import '../data/datasources/event_local_datasource.dart';
import 'runtime_upload_scheduler_base.dart';

RuntimeUploadScheduler createRuntimeUploadScheduler({
  required EventlyConfig config,
  required EventLocalDataSource localDataSource,
  required EventlyLogger logger,
}) {
  return const NoopRuntimeUploadScheduler();
}
