import 'dart:convert';

import 'package:evently_plus/evently_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:evently_plus/src/background/background_upload_config_store.dart';
import 'package:evently_plus/src/data/datasources/event_local_datasource.dart';
import 'package:evently_plus/src/data/datasources/event_remote_datasource.dart';
import 'package:evently_plus/src/data/models/event_model.dart';
import 'package:evently_plus/src/upload/event_queue_uploader.dart';
import 'package:evently_plus/src/upload/runtime_upload_scheduler_web.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EventlyConfig', () {
    test('should create config with required parameters', () {
      final config = EventlyConfig(
        uploadEndpoint: Uri.parse('https://api.example.com/v1/events'),
      );

      expect(
        config.uploadEndpoint,
        Uri.parse('https://api.example.com/v1/events'),
      );
      expect(config.requestHeaders, isEmpty);
      expect(config.environment, 'production');
      expect(config.debugMode, false);
      expect(config.enableBackgroundUpload, true);
      expect(config.enableWebUpload, true);
      expect(config.backgroundUploadFrequency, const Duration(hours: 1));
    });

    test('should require an absolute upload endpoint', () {
      final config = EventlyConfig(uploadEndpoint: Uri());

      expect(
        () => config.validate(),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('should require http:// or https:// protocol', () {
      final config = EventlyConfig(
        uploadEndpoint: Uri.parse('ftp://api.example.com/events'),
      );

      expect(
        () => config.validate(),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('should create copy with modified fields', () {
      final config = EventlyConfig(
        uploadEndpoint: Uri.parse('https://api.example.com/v1/events'),
        requestHeaders: const {'Authorization': 'Bearer original'},
        debugMode: false,
      );

      final newConfig = config.copyWith(
        debugMode: true,
        requestHeaders: const {'X-Client': 'example'},
        enableWebUpload: false,
      );

      expect(newConfig.debugMode, true);
      expect(newConfig.uploadEndpoint, config.uploadEndpoint);
      expect(newConfig.requestHeaders, const {'X-Client': 'example'});
      expect(newConfig.enableWebUpload, false);
    });

    test('should reject a background interval shorter than 15 minutes', () {
      final config = EventlyConfig(
        uploadEndpoint: Uri.parse('https://api.example.com/v1/events'),
        backgroundUploadFrequency: const Duration(minutes: 14),
      );

      expect(
        () => config.validate(),
        throwsA(isA<ConfigurationException>()),
      );
    });
  });

  group('Event', () {
    test('should create event with factory method', () {
      final event = Event.create(
        name: 'test_event',
        screenName: 'TestScreen',
        properties: const {'key': 'value'},
      );

      expect(event.name, 'test_event');
      expect(event.screenName, 'TestScreen');
      expect(event.properties['key'], 'value');
      expect(event.id, isNotEmpty);
      expect(event.timestamp, isNotNull);
    });

    test('should validate event name', () {
      final validEvent = Event.create(name: 'valid_event');
      final invalidEvent = Event.create(name: '');

      expect(validEvent.isValid(), true);
      expect(invalidEvent.isValid(), false);
    });

    test('should reject event name longer than 255 characters', () {
      final longName = 'a' * 256;
      final event = Event.create(name: longName);

      expect(event.isValid(), false);
    });
  });

  group('EventModel', () {
    test('should deserialize its locally persisted JSON', () {
      final original = EventModel.fromEntity(
        Event.create(
          name: 'persisted_event',
          platform: 'android',
          appVersion: '4',
          releaseMarket: 'BAZZAR',
        ),
      );

      final json = original.toJson();
      final restored = EventModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.timestamp, original.timestamp);
      expect(json['platform'], 'android');
      expect(json['app_version'], '4');
      expect(json['release_market'], 'BAZZAR');
      expect(restored.platform, original.platform);
      expect(restored.appVersion, original.appVersion);
      expect(restored.releaseMarket, original.releaseMarket);
      expect(json, isNot(contains('session_id')));
    });
  });

  group('EventRemoteDataSource', () {
    test('should use the exact configured endpoint and request headers',
        () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response('', 202);
      });
      final config = EventlyConfig(
        uploadEndpoint: Uri.parse(
          'https://collector.example.com/custom/ingest?source=mobile',
        ),
        requestHeaders: const {
          'Authorization': 'Token package-user-value',
          'X-Tenant': 'tenant-42',
        },
        environment: 'staging',
      );
      final dataSource = EventRemoteDataSourceImpl(
        client: client,
        config: config,
        logger: const SilentLogger(),
      );

      await dataSource.sendEvents([
        EventModel.fromEntity(Event.create(name: 'standalone_test')),
      ]);

      expect(
        capturedRequest.url,
        Uri.parse(
          'https://collector.example.com/custom/ingest?source=mobile',
        ),
      );
      expect(capturedRequest.method, 'POST');
      expect(
        capturedRequest.headers['authorization'],
        'Token package-user-value',
      );
      expect(capturedRequest.headers['x-tenant'], 'tenant-42');
      expect(capturedRequest.headers['content-type'], 'application/json');
      expect(capturedRequest.headers['x-evently-environment'], 'staging');

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['events'], hasLength(1));
      expect(body['sdk_version'], isNotEmpty);
    });

    test('should preserve a failed batch by throwing on non-2xx responses',
        () async {
      final client = MockClient(
        (_) async => http.Response('temporarily unavailable', 503),
      );
      final dataSource = EventRemoteDataSourceImpl(
        client: client,
        config: EventlyConfig(
          uploadEndpoint: Uri.parse('https://collector.example.com/ingest'),
        ),
        logger: const SilentLogger(),
      );

      await expectLater(
        dataSource.sendEvents([
          EventModel.fromEntity(Event.create(name: 'retry_me')),
        ]),
        throwsA(
          isA<NetworkException>().having(
            (exception) => exception.statusCode,
            'statusCode',
            503,
          ),
        ),
      );
    });
  });

  group('EventQueueUploader', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('removes a queued batch only after a successful upload', () async {
      final preferences = await SharedPreferences.getInstance();
      final localDataSource = EventLocalDataSourceImpl(
        prefs: preferences,
        logger: const SilentLogger(),
      );
      await localDataSource.addEvent(
        EventModel.fromEntity(Event.create(name: 'first')),
      );
      await localDataSource.addEvent(
        EventModel.fromEntity(Event.create(name: 'second')),
      );
      final uploader = EventQueueUploader(
        localDataSource: localDataSource,
        remoteDataSource: EventRemoteDataSourceImpl(
          client: MockClient((_) async => http.Response('', 202)),
          config: EventlyConfig(
            uploadEndpoint: Uri.parse('https://collector.example.com/events'),
          ),
          logger: const SilentLogger(),
        ),
      );

      final uploadedCount = await uploader.uploadPending();

      expect(uploadedCount, 2);
      expect(await localDataSource.getEvents(), isEmpty);
    });

    test('leaves a failed batch in the queue', () async {
      final preferences = await SharedPreferences.getInstance();
      final localDataSource = EventLocalDataSourceImpl(
        prefs: preferences,
        logger: const SilentLogger(),
      );
      await localDataSource.addEvent(
        EventModel.fromEntity(Event.create(name: 'retry_me')),
      );
      final uploader = EventQueueUploader(
        localDataSource: localDataSource,
        remoteDataSource: EventRemoteDataSourceImpl(
          client: MockClient((_) async => http.Response('', 503)),
          config: EventlyConfig(
            uploadEndpoint: Uri.parse('https://collector.example.com/events'),
          ),
          logger: const SilentLogger(),
        ),
      );

      await expectLater(
        uploader.uploadPending(),
        throwsA(isA<NetworkException>()),
      );

      expect(await localDataSource.getEvents(), hasLength(1));
    });
  });

  group('WebRuntimeUploadScheduler', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('uploads queued events without overlapping requests', () async {
      final preferences = await SharedPreferences.getInstance();
      final localDataSource = EventLocalDataSourceImpl(
        prefs: preferences,
        logger: const SilentLogger(),
      );
      await localDataSource.addEvent(
        EventModel.fromEntity(Event.create(name: 'web_event')),
      );
      var requestCount = 0;
      final client = MockClient((_) async {
        requestCount++;
        return http.Response('', 200);
      });
      final scheduler = WebRuntimeUploadScheduler(
        client: client,
        uploader: EventQueueUploader(
          localDataSource: localDataSource,
          remoteDataSource: EventRemoteDataSourceImpl(
            client: client,
            config: EventlyConfig(
              uploadEndpoint: Uri.parse(
                'https://collector.example.com/events',
              ),
            ),
            logger: const SilentLogger(),
          ),
        ),
        logger: const SilentLogger(),
      );

      scheduler.requestUpload();
      scheduler.requestUpload();
      await scheduler.waitForIdle();

      expect(requestCount, 1);
      expect(await localDataSource.getEvents(), isEmpty);
      scheduler.dispose();
    });
  });

  group('BackgroundUploadConfigStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('should round-trip standalone upload configuration', () async {
      final preferences = await SharedPreferences.getInstance();
      final store = BackgroundUploadConfigStore(preferences);
      final config = EventlyConfig(
        uploadEndpoint: Uri.parse(
          'https://collector.example.com/v2/events?tenant=42',
        ),
        requestHeaders: const {'Authorization': 'Token scoped-value'},
        environment: 'qa',
        requestTimeout: const Duration(seconds: 12),
        backgroundUploadFrequency: const Duration(minutes: 45),
        enableWebUpload: false,
        appVersion: '7.2.0',
        releaseMarket: 'internal',
      );

      await store.save(config);
      final restored = await store.load();

      expect(restored, isNotNull);
      expect(restored!.uploadEndpoint, config.uploadEndpoint);
      expect(restored.requestHeaders, config.requestHeaders);
      expect(restored.environment, config.environment);
      expect(restored.requestTimeout, config.requestTimeout);
      expect(restored.enableWebUpload, false);
      expect(
        restored.backgroundUploadFrequency,
        config.backgroundUploadFrequency,
      );
      expect(restored.appVersion, config.appVersion);
      expect(restored.releaseMarket, config.releaseMarket);
    });

    test('should migrate locally saved serverUrl and apiKey values', () async {
      SharedPreferences.setMockInitialValues({
        'evently_plus_background_upload_config': jsonEncode({
          'serverUrl': 'https://legacy.example.com/analytics/',
          'apiKey': 'legacy-token',
          'environment': 'production',
          'debugMode': false,
          'requestTimeoutSeconds': 20,
          'enableBackgroundUpload': true,
        }),
      });
      final preferences = await SharedPreferences.getInstance();

      final restored = await BackgroundUploadConfigStore(preferences).load();

      expect(
        restored!.uploadEndpoint,
        Uri.parse('https://legacy.example.com/analytics/store'),
      );
      expect(
        restored.requestHeaders['Authorization'],
        'Bearer legacy-token',
      );
      expect(restored.requestTimeout, const Duration(seconds: 20));
    });
  });

  group('EventlyClient', () {
    setUp(() async {
      // Reset singleton before each test
      EventlyClient.reset();

      // Clear shared preferences
      SharedPreferences.setMockInitialValues({});
    });

    test('should throw exception when not initialized', () {
      expect(
        () => EventlyClient.instance,
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('should initialize successfully', () async {
      await EventlyClient.initialize(
        config: EventlyConfig(
          uploadEndpoint: Uri.parse('https://api.example.com/v1/events'),
        ),
      );

      expect(EventlyClient.isInitialized, true);
      expect(EventlyClient.instance, isNotNull);
    });

    test('should validate config during initialization', () async {
      expect(
        () => EventlyClient.initialize(
          config: EventlyConfig(uploadEndpoint: Uri()),
        ),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('should log event successfully', () async {
      await EventlyClient.initialize(
        config: EventlyConfig(
          uploadEndpoint: Uri.parse('https://api.example.com/v1/events'),
          debugMode: true,
          enableWebUpload: false,
          appVersion: '4',
          releaseMarket: 'BAZZAR',
        ),
      );

      // Should not throw
      await EventlyClient.instance.logEvent(
        name: 'test_event',
        screenName: 'TestScreen',
        properties: {'test': 'value'},
      );

      expect(EventlyClient.instance.appVersion, '4');
      expect(EventlyClient.instance.releaseMarket, 'BAZZAR');
      expect(EventlyClient.instance.platform, isNotEmpty);
    });

    test('should reject empty event name', () async {
      await EventlyClient.initialize(
        config: EventlyConfig(
          uploadEndpoint: Uri.parse('https://api.example.com/v1/events'),
        ),
      );

      expect(
        () => EventlyClient.instance.logEvent(name: ''),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should keep runtime events in the local queue', () async {
      final preferences = await SharedPreferences.getInstance();
      await EventlyClient.initialize(
        config: EventlyConfig(
          uploadEndpoint: Uri.parse('https://api.example.com/v1/events'),
          enableBackgroundUpload: false,
          enableWebUpload: false,
        ),
        sharedPreferences: preferences,
      );

      await EventlyClient.instance.logEvent(name: 'queued_event_1');
      await EventlyClient.instance.logEvent(name: 'queued_event_2');

      expect(await EventlyClient.instance.getPendingEventCount(), 2);

      await preferences.reload();
      final firstRuntimeEvents = preferences
          .getKeys()
          .where((key) => key.startsWith('evently_queued_event_'))
          .map((key) => preferences.getString(key))
          .whereType<String>()
          .map((value) => jsonDecode(value) as Map<String, dynamic>)
          .toList();
      final firstRuntimeSessionId = EventlyClient.instance.sessionId;

      expect(firstRuntimeSessionId, isNotEmpty);
      expect(firstRuntimeSessionId, isNot('1'));
      expect(
        firstRuntimeEvents.map((event) => event['session_id']).toSet(),
        {firstRuntimeSessionId},
      );

      EventlyClient.reset();
      await EventlyClient.initialize(
        config: EventlyConfig(
          uploadEndpoint: Uri.parse('https://api.example.com/v1/events'),
          enableBackgroundUpload: false,
          enableWebUpload: false,
        ),
        sharedPreferences: preferences,
      );

      expect(EventlyClient.instance.sessionId, isNot(firstRuntimeSessionId));
    });
  });

  group('ConsoleLogger', () {
    test('should log debug messages when enabled', () {
      const logger = ConsoleLogger(enabled: true);

      // Should not throw
      logger.debug('Test debug message');
      logger.info('Test info message');
      logger.warning('Test warning');
      logger.error('Test error');
    });

    test('should not log when disabled', () {
      const logger = ConsoleLogger(enabled: false);

      // Should not throw or output
      logger.debug('This should not appear');
      logger.error('This should not appear either');
    });
  });

  group('SilentLogger', () {
    test('should not log anything', () {
      const logger = SilentLogger();

      // Should not throw
      logger.debug('Test');
      logger.info('Test');
      logger.warning('Test');
      logger.error('Test');
    });
  });

  group('Exceptions', () {
    test('should create ConfigurationException', () {
      const exception = ConfigurationException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.code, 'CONFIGURATION_ERROR');
    });

    test('should create NetworkException with status code', () {
      const exception = NetworkException(
        'Network error',
        statusCode: 500,
      );

      expect(exception.message, 'Network error');
      expect(exception.statusCode, 500);
      expect(exception.toString(), contains('HTTP 500'));
    });

    test('should create ValidationException with field', () {
      const exception = ValidationException('Invalid field', 'email');

      expect(exception.message, 'Invalid field');
      expect(exception.field, 'email');
    });
  });

  group('Integration Tests', () {
    setUp(() {
      EventlyClient.reset();
      SharedPreferences.setMockInitialValues({});
    });

    test('should handle full event lifecycle', () async {
      await EventlyClient.initialize(
        config: EventlyConfig(
          uploadEndpoint: Uri.parse('https://api.example.com/v1/events'),
          debugMode: true,
          enableWebUpload: false,
        ),
      );

      // Log multiple events
      for (int i = 0; i < 3; i++) {
        await EventlyClient.instance.logEvent(
          name: 'test_event_$i',
          screenName: 'TestScreen',
          properties: {'index': i},
        );
      }

      // Should complete without errors
      expect(EventlyClient.isInitialized, true);
    });

    tearDown(() {
      EventlyClient.reset();
    });
  });
}
