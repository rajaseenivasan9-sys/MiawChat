import 'package:flutter/material.dart';
import 'services/salesforce_messaging_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  bool _isLoading = false;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  /// Opens Salesforce In-App Chat
  Future<void> _openSalesforceChat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await SalesforceMessagingService.openChatWithConfigFile(
        persistConversation: true,
      );

      if (!success) {
        _showSnackBar('Failed to open chat');
      }

      // Option 2: Open chat with manual configuration (uncomment to use)
      // final success = await SalesforceMessagingService.openChatManual(
      //   serviceApiUrl: 'https://YOUR_URL.salesforce-scrt.com',
      //   orgId: 'YOUR_ORG_ID',
      //   deploymentName: 'YOUR_DEPLOYMENT_NAME',
      //   persistConversation: true,
      // );
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Clears the current conversation
  Future<void> _clearConversation() async {
    final success = await SalesforceMessagingService.clearConversation();
    if (success) {
      _showSnackBar('Conversation cleared');
    } else {
      _showSnackBar('Failed to clear conversation');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Conversation',
            onPressed: _clearConversation,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 40),
            // Salesforce Chat Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _openSalesforceChat,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chat),
              label: Text(
                _isLoading ? 'Opening Chat...' : 'Open Salesforce Chat',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
