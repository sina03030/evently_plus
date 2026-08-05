/// Evently Plus - A production-ready Flutter SDK for event tracking and analytics.
///
/// ## Features
/// - Clean architecture with separation of concerns
/// - Durable local event queue
/// - Background-only uploads on Android and iOS
/// - Type-safe error handling
/// - Structured logging
/// - Production-ready with proper abstractions
///
/// ## Usage
///
/// ### Initialization
/// ```dart
/// import 'package:evently_plus/evently_plus.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await EventlyClient.initialize(
///     config: EventlyConfig(
///       uploadEndpoint: Uri.parse(
///         'https://analytics.example.com/v1/event-batches',
///       ),
///       requestHeaders: const {
///         'Authorization': 'Bearer your-api-key',
///       },
///       environment: 'production',
///       debugMode: false,
///     ),
///   );
///
///   runApp(MyApp());
/// }
/// ```
///
/// ### Tracking Events
/// ```dart
/// // Simple event
/// await EventlyClient.instance.logEvent(
///   name: 'button_click',
///   screenName: 'HomeScreen',
/// );
///
/// // Event with properties
/// await EventlyClient.instance.logEvent(
///   name: 'purchase_completed',
///   screenName: 'CheckoutScreen',
///   properties: {
///     'product_id': '12345',
///     'amount': 99.99,
///     'currency': 'USD',
///   },
///   userId: 'user_123',
/// );
/// ```
library;

// Core
export 'src/core/config/evently_config.dart';
export 'src/core/error/exceptions.dart';
export 'src/core/error/failures.dart';
export 'src/core/logging/logger.dart';

// Domain
export 'src/domain/entities/event.dart';

// Client
export 'src/evently_client.dart';

// Navigation
export 'src/navigation/evently_navigator_observer.dart';
