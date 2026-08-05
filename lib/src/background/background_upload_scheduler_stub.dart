import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/evently_config.dart';
import '../core/logging/logger.dart';

Future<void> configureBackgroundUpload({
  required EventlyConfig config,
  required SharedPreferences preferences,
  required EventlyLogger logger,
}) async {
  logger.debug('Background upload is not supported on this platform');
}
