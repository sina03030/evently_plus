import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/evently_config.dart';
import '../core/logging/logger.dart';
import 'background_upload_scheduler_stub.dart'
    if (dart.library.io) 'background_upload_scheduler_io.dart' as platform;

/// Configures the platform background uploader when the platform supports it.
Future<void> configureBackgroundUpload({
  required EventlyConfig config,
  required SharedPreferences preferences,
  required EventlyLogger logger,
}) {
  return platform.configureBackgroundUpload(
    config: config,
    preferences: preferences,
    logger: logger,
  );
}
