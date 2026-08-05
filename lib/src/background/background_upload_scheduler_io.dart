import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../core/config/evently_config.dart';
import '../core/logging/logger.dart';
import '../data/datasources/event_local_datasource.dart';
import '../data/datasources/event_remote_datasource.dart';
import 'background_upload_config_store.dart';

const String eventlyBackgroundUploadUniqueName =
    'com.eventlyplus.backgroundUpload';
const String eventlyBackgroundUploadTaskName = 'evently_plus_background_upload';
const String _eventlyBackgroundUploadTag = 'evently_plus_background_upload';
bool _workmanagerInitialized = false;

Future<void> configureBackgroundUpload({
  required EventlyConfig config,
  required SharedPreferences preferences,
  required EventlyLogger logger,
}) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    logger.debug('Background upload is not supported on this platform');
    return;
  }

  final configStore = BackgroundUploadConfigStore(preferences);
  if (config.enableBackgroundUpload) {
    await configStore.save(config);
  } else {
    await configStore.clear();
  }

  await _initializeWorkmanager();

  if (!config.enableBackgroundUpload) {
    await Workmanager().cancelByUniqueName(eventlyBackgroundUploadUniqueName);
    logger.info('Periodic background event upload disabled');
    return;
  }

  await Workmanager().registerPeriodicTask(
    eventlyBackgroundUploadUniqueName,
    eventlyBackgroundUploadTaskName,
    frequency: config.backgroundUploadFrequency,
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    tag: _eventlyBackgroundUploadTag,
  );
  logger.info('Periodic background event upload scheduled');
}

Future<void> _initializeWorkmanager() async {
  if (_workmanagerInitialized) return;
  await Workmanager().initialize(eventlyBackgroundCallbackDispatcher);
  _workmanagerInitialized = true;
}

/// Entry point invoked by Workmanager in a separate Flutter isolate.
@pragma('vm:entry-point')
void eventlyBackgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final isEventlyTask = taskName == eventlyBackgroundUploadTaskName ||
        taskName == eventlyBackgroundUploadUniqueName ||
        taskName == Workmanager.iOSBackgroundTask;
    if (!isEventlyTask) return true;

    final client = http.Client();
    try {
      final preferences = await SharedPreferences.getInstance();
      final config = await BackgroundUploadConfigStore(preferences).load();
      if (config == null || !config.enableBackgroundUpload) return true;
      config.validate();

      final logger =
          config.debugMode ? const ConsoleLogger() : const SilentLogger();
      final localDataSource = EventLocalDataSourceImpl(
        prefs: preferences,
        logger: logger,
      );
      final events = await localDataSource.getEvents();
      if (events.isEmpty) return true;

      final remoteDataSource = EventRemoteDataSourceImpl(
        client: client,
        config: config,
        logger: logger,
      );
      await remoteDataSource.sendEvents(events);
      await localDataSource.removeEventsById(
        events.map((event) => event.id),
      );
      logger.info(
        'Background upload sent ${events.length} queued event(s)',
      );
      return true;
    } catch (_) {
      // Returning false asks Android WorkManager to retry using its backoff
      // policy. iOS decides independently when another run is available.
      return false;
    } finally {
      client.close();
    }
  });
}
