# Evently Plus

[![pub package](https://img.shields.io/pub/v/evently_plus.svg)](https://pub.dev/packages/evently_plus)
[![pub points](https://img.shields.io/pub/points/evently_plus)](https://pub.dev/packages/evently_plus/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

An independently maintained Flutter event-tracking SDK with persistent local
queuing and background-only remote delivery. Evently Plus is an unofficial fork
of [Evently](https://github.com/EbramWagdy1/evently).

## ✨ Features

- 🏗️ **Clean Architecture** - Separation of concerns with clear layer boundaries
- 💾 **Persistent Queue** - Retains queued events across application restarts
- ⏰ **Background-only Uploads** - Uses best-effort Android and iOS background work
- 🚫 **No Foreground Requests** - Event logging only writes to the local queue
- 🌐 **Consumer-owned Endpoint** - Sends to the exact endpoint and headers you configure
- 🛡️ **Error Handling** - Comprehensive error handling with custom exceptions
- 📝 **Structured Logging** - Configurable logging for debugging
- 🧪 **Automated Tests** - Covers configuration, queuing, models, and navigation timing
- 🎯 **Type Safe** - Strong typing with clear contracts

## 📦 Installation

Install the latest release from pub.dev:

```bash
flutter pub add evently_plus
```

## 🚀 Quick Start

### 1. Initialize the SDK

Initialize Evently Plus in your `main.dart` before running your app:

```dart
import 'package:flutter/material.dart';
import 'package:evently_plus/evently_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EventlyClient.initialize(
    config: EventlyConfig(
      // This is the complete upload URL. Evently Plus appends no path.
      uploadEndpoint: Uri.parse(
        'https://analytics.example.com/v1/event-batches',
      ),
      requestHeaders: const {
        'Authorization': 'Bearer your-api-key',
      },
      environment: 'production',
      debugMode: false,
    ),
  );

  runApp(MyApp());
}
```

### 2. Track Events

Log events anywhere in your app:

```dart
// Simple event
await EventlyClient.instance.logEvent(
  name: 'button_click',
  screenName: 'HomeScreen',
);

// Event with properties
await EventlyClient.instance.logEvent(
  name: 'purchase_completed',
  screenName: 'CheckoutScreen',
  properties: {
    'product_id': '12345',
    'amount': 99.99,
    'currency': 'USD',
  },
  userId: 'user_123',
);
```

### 3. Track Time Spent on Screens

Create one observer after Evently is initialized and inject it into your router:

```dart
final eventlyObserver = EventlyNavigatorObserver(
  client: EventlyClient.instance,
);

MaterialApp(
  navigatorObservers: [eventlyObserver],
);
```

The observer queues a `SCREEN_TIME_SPENT` event whenever a page stops being
visible or the app leaves the foreground. Each event contains
`duration_milliseconds` and `duration_seconds`. Dialogs, menus, and bottom
sheets are ignored by default. For parameterized routes, provide a
`screenNameResolver` that returns a stable name rather than a user- or
content-specific path.

If your app owns analytics initialization or user identity, route measurements
through its analytics service:

```dart
final eventlyObserver = EventlyNavigatorObserver(
  onScreenTime: (screenTime) => analyticsService.logScreenTime(screenTime),
);
```

## ⚙️ Configuration

`EventlyConfig` supports the following options:

```dart
EventlyConfig(
  uploadEndpoint: Uri.parse(                  // Required: complete upload URL
    'https://api.example.com/v1/events',
  ),
  requestHeaders: const {                     // Optional: auth/custom headers
    'Authorization': 'Bearer your-token',
  },
  environment: 'production',                  // Sent as X-Evently-Environment
  debugMode: false,                           // Enable diagnostic logging
  requestTimeout: const Duration(seconds: 30),
  enableBackgroundUpload: true,
  backgroundUploadFrequency: const Duration(hours: 1), // Android interval
)
```

### Upload protocol

The background worker sends an HTTP `POST` to `uploadEndpoint` exactly as
provided. Evently Plus sets `Content-Type: application/json`, adds
`X-Evently-Environment`, and merges the configured `requestHeaders`. A request
body has this shape:

```json
{
  "events": [
    {
      "id": "...",
      "event_name": "button_click",
      "occurred_at": "2026-08-05T12:00:00.000Z",
      "properties": {"button_id": "save"},
      "session_id": "...",
      "platform": "android",
      "app_version": "42",
      "release_market": "play_store"
    }
  ],
  "timestamp": "2026-08-05T12:01:00.000Z",
  "sdk_version": "2.1.1"
}
```

Any HTTP status from 200 through 299 is treated as success, after which those
events are removed from the queue. Other statuses and network errors preserve
the events and report failure to the operating system's background scheduler.

## ⏰ Periodic Background Upload

Background upload is enabled by default. During app runtime, every event is
persisted locally and no upload is attempted. A Workmanager isolate is the only
code path that sends events. The package exposes no foreground upload API. The
task runs only when a network connection is available and uses one unique task
registration to avoid duplicate schedules.

Android requires no additional host-app setup. For iOS, enable the `processing`
background mode, permit the identifier
`com.eventlyplus.backgroundUpload`, and register that identifier from the
host app's `AppDelegate`. The Dart `backgroundUploadFrequency` configures
Android; set the corresponding iOS frequency in native code.

Mobile operating systems treat periodic background work as best-effort. Android
may delay work because of battery or network constraints, and iOS does not
guarantee exact execution times.

To turn scheduling off:

```dart
EventlyConfig(
  uploadEndpoint: Uri.parse('https://api.example.com/v1/events'),
  enableBackgroundUpload: false,
)
```

## 🔧 Advanced Usage

### Check Pending Events

Get the count of events waiting for background upload:

```dart
final count = await EventlyClient.instance.getPendingEventCount();
print('Pending events: $count');
```

### Clear Event Queue

Remove all queued events:

```dart
await EventlyClient.instance.clearPendingEvents();
```

### Custom Logger

Provide your own logger implementation:

```dart
class CustomLogger implements EventlyLogger {
  @override
  void log(LogLevel level, String message, [dynamic error, StackTrace? stackTrace]) {
    // Your custom logging logic
  }

  // Implement other methods...
}

await EventlyClient.initialize(
  config: config,
  logger: CustomLogger(),
);
```

## 🏗️ Architecture

Evently Plus follows Clean Architecture principles:

```
📁 lib/
├── 📁 core/              # Core infrastructure
│   ├── config/           # Configuration
│   ├── error/            # Exceptions & failures
│   └── logging/          # Logging abstraction
├── 📁 domain/            # Business logic
│   ├── entities/         # Core entities
│   └── repositories/     # Repository contracts
└── 📁 data/              # Data layer
    ├── models/           # Data models
    ├── datasources/      # Remote & local data sources
    └── repositories/     # Repository implementations
```

## 🔒 Security Best Practices

1. **Never hardcode credentials** - Inject them from your application's configuration
2. **Use HTTPS** - Always use a secure upload endpoint outside local development
3. **Validate input** - The SDK validates all events automatically
4. **Sanitize PII** - Don't include sensitive personal information in events

When background upload is enabled, Evently Plus persists `requestHeaders` in
`SharedPreferences` so a background isolate can reconstruct the request. This
storage is not encrypted. Use a scoped, revocable credential rather than a
high-value long-lived secret, and reinitialize the client after rotating it.

## 🧪 Testing

Run tests:

```bash
flutter test
```

The SDK includes comprehensive tests for:
- Configuration validation
- Event creation and validation
- Client initialization
- Error handling
- Logging

## 📚 Documentation

- Read the [API reference](https://pub.dev/documentation/evently_plus/latest/).
- See the [example](example/) directory for a complete demo app.
- Review the [changelog](CHANGELOG.md) before upgrading.

## 🔄 Migration from v1.x

**v2.0.0 is a breaking change** with a complete rewrite. Key differences:

### Old (v1.x):
```dart
Evently().initialize(serverUrl: 'https://api.example.com');
Evently().logEvent('event', screenName: 'Screen', description: 'Desc');
```

### New (v2.0.0):
```dart
await EventlyClient.initialize(
  config: EventlyConfig(
    uploadEndpoint: Uri.parse('https://api.example.com/v1/events'),
  ),
);
await EventlyClient.instance.logEvent(
  name: 'event',
  screenName: 'Screen',
  properties: {'description': 'Desc'},
);
```

### Benefits of v2:
- Async initialization for better performance
- Configuration object for better organization
- Properties map instead of simple description
- Error handling with exceptions
- Durable local queue and background-only delivery
- Background-oriented architecture

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

For issues, feature requests, or questions, [open a GitHub issue](https://github.com/sina03030/evently_plus/issues).

---

Based on the original [Evently](https://github.com/EbramWagdy1/evently) package.
