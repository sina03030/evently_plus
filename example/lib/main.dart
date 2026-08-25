import 'package:flutter/material.dart';
import 'package:evently_plus/evently_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Evently SDK
  await EventlyClient.initialize(
    config: EventlyConfig(
      uploadEndpoint: Uri.parse(
        'https://analytics.example.com/v1/event-batches',
      ),
      requestHeaders: const {
        'Authorization': 'Bearer your-api-key-here',
      },
      environment: 'development',
      debugMode: true,
    ),
  );

  runApp(
    MyApp(
      eventlyObserver: EventlyNavigatorObserver(
        client: EventlyClient.instance,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final EventlyNavigatorObserver eventlyObserver;

  const MyApp({
    required this.eventlyObserver,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Evently Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      navigatorObservers: [eventlyObserver],
      home: const EventlyDemoScreen(),
    );
  }
}

class EventlyDemoScreen extends StatefulWidget {
  const EventlyDemoScreen({super.key});

  @override
  State<EventlyDemoScreen> createState() => _EventlyDemoScreenState();
}

class _EventlyDemoScreenState extends State<EventlyDemoScreen> {
  int _eventCount = 0;
  String _lastEvent = 'None';

  Future<void> _logEvent(
      String eventName, Map<String, dynamic>? properties) async {
    try {
      await EventlyClient.instance.logEvent(
        name: eventName,
        screenName: 'EventlyDemoScreen',
        properties: properties,
        userId: 'demo_user_123',
      );

      setState(() {
        _eventCount++;
        _lastEvent = eventName;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event logged: $eventName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Evently SDK Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stats Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Event Statistics',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text('Events logged: $_eventCount'),
                    Text('Last event: $_lastEvent'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Event Buttons
            Text(
              'Log Events',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () =>
                  _logEvent('button_click', {'button_id': 'simple'}),
              icon: const Icon(Icons.touch_app),
              label: const Text('Simple Event'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () => _logEvent(
                'page_view',
                {
                  'page': 'home',
                  'timestamp': DateTime.now().toIso8601String(),
                },
              ),
              icon: const Icon(Icons.pageview),
              label: const Text('Page View Event'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () => _logEvent(
                'purchase_completed',
                {
                  'product_id': '12345',
                  'amount': 99.99,
                  'currency': 'USD',
                  'quantity': 1,
                },
              ),
              icon: const Icon(Icons.shopping_cart),
              label: const Text('Purchase Event'),
            ),
            const SizedBox(height: 24),

            // Control Buttons
            Text(
              'SDK Controls',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () async {
                final count =
                    await EventlyClient.instance.getPendingEventCount();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pending events: $count'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.info),
              label: const Text('Show Pending Count'),
            ),

            const Spacer(),

            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'About Evently V2',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Production-ready analytics SDK with:\n'
                      '• Clean architecture\n'
                      '• Durable local queue\n'
                      '• Background mobile upload\n'
                      '• Automatic web upload\n'
                      '• Error handling',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
