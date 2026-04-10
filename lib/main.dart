import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  bool _isLoading = false;
  bool _showFloatingIcon = false;

  @override
  void initState() {
    super.initState();
    _showFloatingIcon =
        false; // Initially hide the floating icon (chat not opened yet)
    _setupChatListener();
  }

  /// Listen for chat dismissed events (minimized or closed) from the native side
  void _setupChatListener() {
    SalesforceMessagingService.onChatDismissed.listen((event) {
      if (mounted) {
        if (event == 'minimized') {
          // Show floating icon only when chat is minimized
          setState(() {
            _showFloatingIcon = true;
          });
        } else if (event == 'closed') {
          // Hide floating icon when chat is closed
          setState(() {
            _showFloatingIcon = false;
          });
        }
      }
    });
  }

  /// Opens Salesforce In-App Chat
  Future<void> _openSalesforceChat() async {
    setState(() {
      _isLoading = true;
      _showFloatingIcon = false; // Hide floating icon when trying to open chat
    });

    try {
      final success = await SalesforceMessagingService.openChatWithConfigFile(
        persistConversation: true,
      );

      if (!success) {
        _showSnackBar('Failed to open chat');
      }
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
    return Stack(
      children: [
        Scaffold(
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
        ),
        // Floating Chat Icon - Appears as overlay when chat is minimized
        if (_showFloatingIcon)
          Positioned(
            bottom: 24,
            right: 24,
            child: GestureDetector(
              onTap: _isLoading ? null : _openSalesforceChat,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SvgPicture.asset(
                  'assets/images/icn_live_chat_floating.svg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
