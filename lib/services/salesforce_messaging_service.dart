import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mynyl/utils/bloc/post_login_bloc.dart';

enum ChatSessionStatus {
  opened,
  minimized,
  closed,
  sessionEnded,
  unknown,
}

/// Service class to interact with Salesforce In-App Messaging SDK
/// This provides a Flutter interface to the native Android Salesforce chat
class SalesforceMessagingService {
  static const MethodChannel _channel = MethodChannel(
    'com.newyorklife.mynyl.mobile/salesforce_chat',
  );

  static final _chatDismissedController = StreamController<String>.broadcast();
  static final _chatStatusController = StreamController<ChatSessionStatus>.broadcast();
  static final _chatUnreadCountController = StreamController<int>.broadcast();
  static bool _handlerInitialized = false;
  static int _chatUnreadCount = 0;

  static String? _authToken;

  /// Initialize the method call handler (only once)
  static void _initializeHandler() {
    if (_handlerInitialized) return;
    _handlerInitialized = true;

    _channel.setMethodCallHandler((call) async {
      // Check for the method names that native side is sending
      if (call.method == 'onChatOpened' || call.method == 'opened') {
        _emitChatStatus(ChatSessionStatus.opened);
        return true;
      } else if (call.method == 'onChatClosed' || call.method == 'closed') {
        _emitChatStatus(ChatSessionStatus.closed);
        return true;
      } else if (call.method == 'onChatMinimized' || call.method == 'minimized') {
        _emitChatStatus(ChatSessionStatus.minimized);
        return true;
      } else if (call.method == 'onSessionEnded' || call.method == 'sessionEnded') {
        _emitChatStatus(ChatSessionStatus.sessionEnded);
        return true;
      } else if (call.method == 'onChatUnreadCountChanged') {
        final dynamic args = call.arguments;
        if (args is int) {
          _setUnreadCount(args);
        } else if (args is String) {
          _setUnreadCount(int.tryParse(args) ?? _chatUnreadCount);
        } else if (args is Map) {
          final dynamic raw = args['count'];
          _setUnreadCount(raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? _chatUnreadCount);
        }
        return true;
      } else if (call.method == 'onChatNewMessage') {
        incrementUnreadCount();
        return true;
      } else if (call.method == 'getToken' || call.method == 'refreshToken') {
        final token = await _fetchAuthToken(refresh: call.method == 'refreshToken');
        if (token != null) {
          return token;
        }
        return null;
      }
      return false;
    });
  }

  static void _emitChatStatus(ChatSessionStatus status) {
    _chatStatusController.add(status);
    if (status == ChatSessionStatus.opened ||
        status == ChatSessionStatus.closed ||
        status == ChatSessionStatus.sessionEnded) {
      _setUnreadCount(0);
    }
    if (status == ChatSessionStatus.minimized) {
      _chatDismissedController.add('minimized');
    } else if (status == ChatSessionStatus.closed) {
      _chatDismissedController.add('closed');
    }
  }

  static void _setUnreadCount(int count) {
    final normalized = count < 0 ? 0 : count;
    _chatUnreadCount = normalized;
    _chatUnreadCountController.add(_chatUnreadCount);
  }

  static Future<String?> _fetchAuthToken({bool refresh = false}) async {
    if (!refresh && _authToken != null) {
      return _authToken!;
    }

    final result = await PostLoginBlocHelper.dashboardRepository.fetchChatCredentials();
    if (result.$2) {
      _authToken = result.$1.token;
    }
    return _authToken;
  }

  static Future<bool> setUserVerificationToken(String token) async {
    try {
      final result = await _channel.invokeMethod('setUserVerificationToken', {
        'token': token,
      });
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('Failed to set user verification token: ${e.message}');
      return false;
    }
  }

  /// Stream for listening to chat dismissed events (minimized or closed) from native side
  /// Emits 'minimized' when user minimizes the chat
  /// Emits 'closed' when user closes the chat
  static Stream<String> get onChatDismissed {
    _initializeHandler();
    return _chatDismissedController.stream;
  }

  /// Stream for full chat session lifecycle state updates.
  static Stream<ChatSessionStatus> get onChatSessionStatus {
    _initializeHandler();
    return _chatStatusController.stream;
  }

  static Stream<int> get onChatUnreadCount {
    _initializeHandler();
    return _chatUnreadCountController.stream;
  }

  static int get chatUnreadCount => _chatUnreadCount;

  static void incrementUnreadCount() {
    _setUnreadCount(_chatUnreadCount + 1);
  }

  static void resetUnreadCount() {
    _setUnreadCount(0);
  }

  /// Notify listeners about a minimize action triggered from Flutter UI.
  static void notifyChatMinimized() {
    _emitChatStatus(ChatSessionStatus.minimized);
  }

  /// Notify listeners about a close action triggered from Flutter UI.
  static void notifyChatClosed() {
    _emitChatStatus(ChatSessionStatus.closed);
  }

  /// Debug method: Manually trigger minimize event (for testing)
  static Future<void> testMinimizeEvent() async {
    print('TEST: Triggering minimize event');
    notifyChatMinimized();
  }

  /// Debug method: Manually trigger close event (for testing)
  static Future<void> testCloseEvent() async {
    print('TEST: Triggering close event');
    notifyChatClosed();
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
    } on MissingPluginException catch (e) {
      debugPrint('Salesforce chat plugin not available on this platform: $e');
      return false;
    } on PlatformException catch (e) {
      debugPrint('Failed to open Salesforce chat: ${e.message}');
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
    } on MissingPluginException catch (e) {
      debugPrint('Salesforce chat plugin not available on this platform: $e');
      return false;
    } on PlatformException catch (e) {
      debugPrint('Failed to open Salesforce chat: ${e.message}');
      return false;
    }
  }

  /// Opens the Salesforce chat using manual configuration with pre-chat form values
  ///
  /// [serviceApiUrl] - The Salesforce Service API URL
  /// [orgId] - Your Salesforce Organization ID
  /// [deploymentName] - The API name of your deployment
  /// [persistConversation] - If true, uses the same conversation ID across app restarts
  static Future<bool> openChatManualWithPreChatValues({
    required String serviceApiUrl,
    required String orgId,
    required String deploymentName,
    required String clientId,
    required String policyNumber,
    required String reason,
    bool persistConversation = true,
  }) async {
    try {
      final timeZoneOffset = DateTime.now().timeZoneOffset.inMinutes;
      final result = await _channel.invokeMethod('openChat', {
        'useConfigFile': false,
        'persistConversation': persistConversation,
        'serviceApiUrl': serviceApiUrl,
        'orgId': orgId,
        'deploymentName': deploymentName,
        'hasPreChatValues': true,
        'clientId': clientId,
        'policyNumber': policyNumber,
        'reason': reason,
        'timeZoneOffset': timeZoneOffset.toString(),
      });
      return result == true;
    } on MissingPluginException catch (e) {
      debugPrint('Salesforce chat plugin not available on this platform: $e');
      return false;
    } on PlatformException catch (e) {
      debugPrint('Failed to open Salesforce chat: ${e.message}');
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
      debugPrint('Failed to clear conversation: ${e.message}');
      return false;
    }
  }

  /// Closes the current conversation explicitly
  /// When closed, no new messages can be sent to this conversation
  /// The conversation history is preserved and can be queried
  static Future<bool> closeConversation() async {
    try {
      final result = await _channel.invokeMethod('closeConversation');
      final isSuccess = result == true;
      if (isSuccess) {
        _emitChatStatus(ChatSessionStatus.sessionEnded);
      }
      return isSuccess;
    } on PlatformException catch (e) {
      debugPrint('Failed to close conversation: ${e.message}');
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
      debugPrint('Failed to start new conversation: ${e.message}');
      return false;
    }
  }

  /// Gets the current conversation ID if one exists
  static Future<String?> getConversationId() async {
    try {
      final result = await _channel.invokeMethod('getConversationId');
      return result as String?;
    } on PlatformException catch (e) {
      debugPrint('Failed to get conversation ID: ${e.message}');
      return null;
    }
  }
}
