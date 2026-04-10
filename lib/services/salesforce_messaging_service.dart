import 'package:flutter/services.dart';
import 'dart:async';

/// Service class to interact with Salesforce In-App Messaging SDK
/// This provides a Flutter interface to the native Android Salesforce chat
class SalesforceMessagingService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.newproject/salesforce_chat',
  );

  static final _chatDismissedController = StreamController<String>.broadcast();
  static bool _handlerInitialized = false;

  /// Initialize the method call handler (only once)
  static void _initializeHandler() {
    if (_handlerInitialized) return;
    _handlerInitialized = true;

    _channel.setMethodCallHandler((call) async {
      // Check for the method names that native side is sending
      if (call.method == 'onChatClosed' || call.method == 'closed') {
        _chatDismissedController.add('closed');
        return true;
      } else if (call.method == 'onChatMinimized' ||
          call.method == 'minimized') {
        _chatDismissedController.add('minimized');
        return true;
      }
      return false;
    });
  }

  /// Stream for listening to chat dismissed events (minimized or closed) from native side
  /// Emits 'minimized' when user minimizes the chat
  /// Emits 'closed' when user closes the chat
  static Stream<String> get onChatDismissed {
    _initializeHandler();
    return _chatDismissedController.stream;
  }

  /// Debug method: Manually trigger minimize event (for testing)
  static Future<void> testMinimizeEvent() async {
    print('TEST: Triggering minimize event');
    _chatDismissedController.add('minimized');
  }

  /// Debug method: Manually trigger close event (for testing)
  static Future<void> testCloseEvent() async {
    print('TEST: Triggering close event');
    _chatDismissedController.add('closed');
  }

  /// Opens the Salesforce chat using the config file (salesforce_config.json)
  ///
  /// [persistConversation] - If true, uses the same conversation ID across app restarts
  static Future<bool> openChatWithConfigFile({
    bool persistConversation = true,
  }) async {
    try {
      final result = await _channel.invokeMethod('openChat', {
        'useConfigFile': true,
        'persistConversation': persistConversation,
      });
      return result == true;
    } on PlatformException catch (e) {
      print('Failed to open Salesforce chat: ${e.message}');
      return false;
    }
  }

  /// Opens the Salesforce chat using manual configuration
  ///
  /// [serviceApiUrl] - The Salesforce Service API URL
  /// [orgId] - Your Salesforce Organization ID
  /// [deploymentName] - The API name of your deployment
  /// [persistConversation] - If true, uses the same conversation ID across app restarts
  static Future<bool> openChatManual({
    required String serviceApiUrl,
    required String orgId,
    required String deploymentName,
    bool persistConversation = true,
  }) async {
    try {
      final result = await _channel.invokeMethod('openChat', {
        'useConfigFile': false,
        'persistConversation': persistConversation,
        'serviceApiUrl': serviceApiUrl,
        'orgId': orgId,
        'deploymentName': deploymentName,
      });
      return result == true;
    } on PlatformException catch (e) {
      print('Failed to open Salesforce chat: ${e.message}');
      return false;
    }
  }

  /// Clears the current conversation ID (but doesn't close the conversation)
  /// Call this when you want to start a fresh conversation
  static Future<bool> clearConversation() async {
    try {
      final result = await _channel.invokeMethod('clearConversation');
      return result == true;
    } on PlatformException catch (e) {
      print('Failed to clear conversation: ${e.message}');
      return false;
    }
  }

  /// Closes the current conversation explicitly
  /// When closed, no new messages can be sent to this conversation
  /// The conversation history is preserved and can be queried
  static Future<bool> closeConversation() async {
    try {
      final result = await _channel.invokeMethod('closeConversation');
      return result == true;
    } on PlatformException catch (e) {
      print('Failed to close conversation: ${e.message}');
      return false;
    }
  }

  /// Minimizes/dismisses the chat without closing the session
  static Future<bool> minimizeChat() async {
    try {
      final result = await _channel.invokeMethod('minimizeChat');
      return result == true;
    } on PlatformException catch (e) {
      print('Failed to minimize chat: ${e.message}');
      return false;
    }
  }

  /// Starts a new conversation (closes current and creates new ID)
  static Future<bool> startNewConversation() async {
    try {
      final result = await _channel.invokeMethod('startNewConversation');
      return result == true;
    } on PlatformException catch (e) {
      print('Failed to start new conversation: ${e.message}');
      return false;
    }
  }

  /// Gets the current conversation ID if one exists
  static Future<String?> getConversationId() async {
    try {
      final result = await _channel.invokeMethod('getConversationId');
      return result as String?;
    } on PlatformException catch (e) {
      print('Failed to get conversation ID: ${e.message}');
      return null;
    }
  }
}
