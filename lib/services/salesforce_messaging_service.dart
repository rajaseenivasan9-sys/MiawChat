import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum ChatSessionStatus { opened, minimized, closed, sessionEnded, unknown }

class ChatAssistantTooltipRequest {
  final double? anchorX;
  final double? anchorY;

  const ChatAssistantTooltipRequest({this.anchorX, this.anchorY});
}

/// Service class to interact with Salesforce In-App Messaging SDK
/// This provides a Flutter interface to the native Android Salesforce chat
class SalesforceMessagingService {
  static const MethodChannel _channel = MethodChannel(
    'com.newyorklife.mynyl.mobile/salesforce_chat',
  );

  static final _chatDismissedController = StreamController<String>.broadcast();
  static final _chatStatusController =
      StreamController<ChatSessionStatus>.broadcast();
  static final _chatUnreadCountController = StreamController<int>.broadcast();
  static final _chatAssistantTooltipController =
      StreamController<ChatAssistantTooltipRequest>.broadcast();
  static bool _handlerInitialized = false;
  static int _chatUnreadCount = 0;
  static bool _hasNativeUnreadCountSource = false;
  static ChatSessionStatus _chatSessionStatus = ChatSessionStatus.unknown;

  static String? _authToken;

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[SalesforceUnread] $message');
    }
  }

  static Map<String, String> _chatAssistantLocalizationPayload() {
    // final context = NavigatorHelper.navigatorKey.currentContext;
    // final localizations = context == null ? null : AppLocalizations.of(context);
    // if (localizations == null) {
    //   return const {};
    // }

    return {
      'chatAssistantTitle': 'localizations.chat_assistant_tooltip_title',
      'chatAssistantTooltipMessage':
          'localizations.chat_assistant_tooltip_message',
    };
  }

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
      } else if (call.method == 'onChatMinimized' ||
          call.method == 'minimized') {
        _emitChatStatus(ChatSessionStatus.minimized);
        return true;
      } else if (call.method == 'onSessionEnded' ||
          call.method == 'sessionEnded') {
        _emitChatStatus(ChatSessionStatus.sessionEnded);
        return true;
      } else if (call.method == 'onChatUnreadCountChanged') {
        final dynamic args = call.arguments;
        if (args is int) {
          _log('onChatUnreadCountChanged(int): $args');
          _setUnreadCountFromNative(args);
        } else if (args is String) {
          final parsed = int.tryParse(args) ?? _chatUnreadCount;
          _log('onChatUnreadCountChanged(String): raw=$args parsed=$parsed');
          _setUnreadCountFromNative(parsed);
        } else if (args is Map) {
          final dynamic raw = args['count'];
          final parsed = raw is int
              ? raw
              : int.tryParse(raw?.toString() ?? '') ?? _chatUnreadCount;
          _log('onChatUnreadCountChanged(Map): raw=$raw parsed=$parsed');
          _setUnreadCountFromNative(parsed);
        }
        return true;
      } else if (call.method == 'onChatNewMessage') {
        final dynamic args = call.arguments;
        int? nativeCount;
        if (args is int) {
          nativeCount = args;
        } else if (args is String) {
          nativeCount = int.tryParse(args);
        } else if (args is Map) {
          final dynamic raw = args['count'];
          nativeCount = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
        }

        _log(
          'onChatNewMessage: args=$args nativeCount=$nativeCount status=$_chatSessionStatus unread=$_chatUnreadCount hasNative=$_hasNativeUnreadCountSource',
        );

        // Native absolute unread callbacks have proven unreliable after minimize.
        // Keep badge state recoverable from new-message events while chat is minimized.
        if (_chatSessionStatus == ChatSessionStatus.minimized) {
          if (nativeCount != null) {
            if (nativeCount > _chatUnreadCount) {
              _log(
                'onChatNewMessage(minimized): applying nativeCount=$nativeCount',
              );
              _setUnreadCount(nativeCount);
            }
          } else {
            _log('onChatNewMessage(minimized): increment fallback');
            incrementUnreadCount();
          }
        } else if (!_hasNativeUnreadCountSource) {
          _log('onChatNewMessage(non-minimized/no-native): increment fallback');
          incrementUnreadCount();
        }
        return true;
      } else if (call.method == 'chat_assistant_tooltip_requested') {
        final dynamic args = call.arguments;
        if (args is Map) {
          final dynamic rawX = args['anchorX'];
          final dynamic rawY = args['anchorY'];
          final anchorX = rawX is num
              ? rawX.toDouble()
              : double.tryParse(rawX?.toString() ?? '');
          final anchorY = rawY is num
              ? rawY.toDouble()
              : double.tryParse(rawY?.toString() ?? '');
          _chatAssistantTooltipController.add(
            ChatAssistantTooltipRequest(anchorX: anchorX, anchorY: anchorY),
          );
        }
        return true;
      } else if (call.method == 'getToken' || call.method == 'refreshToken') {
        final token = await _fetchAuthToken(
          refresh: call.method == 'refreshToken',
        );
        if (token != null) {
          return token;
        }
        return null;
      }
      return false;
    });
  }

  static void _emitChatStatus(ChatSessionStatus status) {
    _log('status: $_chatSessionStatus -> $status');
    _chatSessionStatus = status;
    _chatStatusController.add(status);
    if (status == ChatSessionStatus.closed ||
        status == ChatSessionStatus.sessionEnded) {
      _log('status=$status, resetting unread to 0');
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
    _log('setUnread: old=$_chatUnreadCount new=$normalized');
    _chatUnreadCount = normalized;
    _chatUnreadCountController.add(_chatUnreadCount);
  }

  static void _setUnreadCountFromNative(int count) {
    _log('setUnreadFromNative: count=$count');
    _hasNativeUnreadCountSource = true;
    _setUnreadCount(count);
  }

  static Future<String?> _fetchAuthToken({bool refresh = false}) async {
    return '';
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

  /// Revokes user verification token on native SDK side.
  static Future<bool> revokeToken() async {
    try {
      final result = await _channel.invokeMethod('revokeToken');
      return result == true;
    } on MissingPluginException catch (e) {
      debugPrint('Salesforce chat plugin not available on this platform: $e');
      return false;
    } on PlatformException catch (e) {
      debugPrint('Failed to revoke Salesforce token: ${e.message}');
      return false;
    }
  }

  /// Clears local and native chat state during logout.
  static Future<void> resetForLogout() async {
    _authToken = null;
    await dismissChat();
    resetUnreadCount();
    notifyChatClosed();

    await revokeToken();
    await clearConversation(deletePersistedConversationId: true);
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

  static Stream<ChatAssistantTooltipRequest>
  get onChatAssistantTooltipRequested {
    _initializeHandler();
    return _chatAssistantTooltipController.stream;
  }

  static int get chatUnreadCount => _chatUnreadCount;

  static void incrementUnreadCount() {
    _log('incrementUnreadCount from=$_chatUnreadCount');
    _setUnreadCount(_chatUnreadCount + 1);
  }

  static void resetUnreadCount() {
    _log('resetUnreadCount (clear source + set 0)');
    _hasNativeUnreadCountSource = false;
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
    debugPrint('TEST: Triggering minimize event');
    notifyChatMinimized();
  }

  /// Debug method: Manually trigger close event (for testing)
  static Future<void> testCloseEvent() async {
    debugPrint('TEST: Triggering close event');
    notifyChatClosed();
  }

  /// Opens the Salesforce chat using manual configuration
  ///
  /// [serviceApiUrl] - The Salesforce Service API URL
  /// [orgId] - Your Salesforce Organization ID
  /// [deploymentName] - The API name of your deployment
  /// [persistConversation] - If true, uses the same conversation ID across app restarts
  static Future<bool> resumeChat({
    required String serviceApiUrl,
    required String orgId,
    required String deploymentName,
  }) async {
    _initializeHandler();
    try {
      final result = await _channel.invokeMethod('openChat', {
        'serviceApiUrl': serviceApiUrl,
        'orgId': orgId,
        'deploymentName': deploymentName,
        ..._chatAssistantLocalizationPayload(),
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
  static Future<bool> openChat({
    required String serviceApiUrl,
    required String orgId,
    required String deploymentName,
    required String clientId,
    required String policyNumber,
    required String reason,
  }) async {
    _initializeHandler();
    try {
      final timeZoneOffset = DateTime.now().timeZoneOffset.inMinutes;
      final result = await _channel.invokeMethod('openChat', {
        'serviceApiUrl': serviceApiUrl,
        'orgId': orgId,
        'deploymentName': deploymentName,
        'hasPreChatValues': true,
        'clientId': clientId,
        'policyNumber': policyNumber,
        'reason': reason,
        'timeZoneOffset': timeZoneOffset.toString(),
        ..._chatAssistantLocalizationPayload(),
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

  /// Clears current native chat state.
  ///
  /// When [deletePersistedConversationId] is true, a fresh conversation ID will
  /// be generated on next open. Set it to false to preserve history continuity.
  static Future<bool> clearConversation({
    bool deletePersistedConversationId = true,
  }) async {
    try {
      final result = await _channel.invokeMethod('clearConversation', {
        'deletePersistedConversationId': deletePersistedConversationId,
      });
      return result == true;
    } on MissingPluginException catch (e) {
      debugPrint('Salesforce chat plugin not available on this platform: $e');
      return false;
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
    } on MissingPluginException catch (e) {
      debugPrint('Salesforce chat plugin not available on this platform: $e');
      return false;
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
    } on MissingPluginException catch (e) {
      debugPrint('Salesforce chat plugin not available on this platform: $e');
      return false;
    } on PlatformException catch (e) {
      debugPrint('Failed to minimize chat: ${e.message}');
      return false;
    }
  }

  /// Dismisses any currently visible native chat UI without depending on header actions.
  static Future<bool> dismissChat() async {
    try {
      final result = await _channel.invokeMethod('dismissChat');
      return result == true;
    } on MissingPluginException catch (e) {
      debugPrint('Salesforce chat plugin not available on this platform: $e');
      return false;
    } on PlatformException catch (e) {
      debugPrint('Failed to dismiss chat: ${e.message}');
      return false;
    }
  }

  /// Gets the current conversation ID if one exists
  static Future<String?> getConversationId() async {
    try {
      final result = await _channel.invokeMethod('getConversationId');
      return result as String?;
    } on MissingPluginException catch (e) {
      debugPrint('Salesforce chat plugin not available on this platform: $e');
      return null;
    } on PlatformException catch (e) {
      debugPrint('Failed to get conversation ID: ${e.message}');
      return null;
    }
  }
}
