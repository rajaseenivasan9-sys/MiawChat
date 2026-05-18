import Flutter
import UIKit
import os.log

/// Handles Flutter method channel communication for Salesforce In-App Chat
class SalesforceMethodChannelHandler: SalesforceAuthTokenProvider {

    static let shared = SalesforceMethodChannelHandler()

    private let channelName = "com.newyorklife.mynyl.mobile/salesforce_chat"
    private var channel: FlutterMethodChannel?

    private init() {}

    /// Setup method channel for Flutter communication
    func setup(with engine: FlutterEngine) {
        channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: engine.binaryMessenger
        )

        channel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(
                    FlutterError(
                        code: "HANDLER_ERROR", message: "Handler deallocated", details: nil))
                return
            }
            self.handleMethodCall(call, result: result)
        }

        // Set the channel reference in SalesforceMessagingManager so it can send events
        SalesforceMessagingManager.shared.setEventChannel(channel)
        SalesforceMessagingManager.shared.setAuthTokenProvider(self)

        print("Salesforce Method Channel Handler setup complete for channel: \(channelName)")
    }

    /// Invoke a method on Flutter side
    func invokeFlutterMethod(_ method: String, arguments: Any? = nil) {
        channel?.invokeMethod(method, arguments: arguments) { _ in }
    }

    /// Handle incoming method calls from Flutter
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard
            let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }),
            let rootViewController = window.rootViewController
        else {
            result(
                FlutterError(
                    code: "NO_VIEW_CONTROLLER", message: "Root view controller not found",
                    details: nil))
            return
        }

        switch call.method {
        case "openChat":
            handleOpenChat(call, viewController: rootViewController, result: result)

        case "clearConversation":
            let args = call.arguments as? [String: Any]
            let deletePersistedConversationId =
                args?["deletePersistedConversationId"] as? Bool ?? true
            SalesforceMessagingManager.shared.clearConversation(
                deletePersistedConversationId: deletePersistedConversationId)
            result(true)

        case "closeConversation":
            SalesforceMessagingManager.shared.closeConversation { error in
                if let error = error {
                    result(
                        FlutterError(
                            code: "CLOSE_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(true)
                }
            }

        case "minimizeChat":
            SalesforceMessagingManager.shared.minimizeChat()
            result(true)

        case "getConversationId":
            let conversationId = SalesforceMessagingManager.shared.getCurrentConversationId()
            result(conversationId?.uuidString)

        case "revokeToken":
            SalesforceMessagingManager.shared.revokeToken()
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func onGetToken(completion: @escaping (String?) -> Void) {
        requestTokenFromFlutter(method: "getToken", completion: completion)
    }

    func onRefreshToken(completion: @escaping (String?) -> Void) {
        requestTokenFromFlutter(method: "refreshToken", completion: completion)
    }

    private func requestTokenFromFlutter(method: String, completion: @escaping (String?) -> Void) {
        guard let channel = channel else {
            print("[SalesforceMethodChannelHandler] ERROR: Channel unavailable for \(method)")
            completion(nil)
            return
        }

        func requestToken(attempt: Int) {
            channel.invokeMethod(method, arguments: nil) { response in
                if let token = response as? String, !token.isEmpty {
                    print(
                        "[SalesforceMethodChannelHandler] \(method) token response length: \(token.count) (attempt=\(attempt))"
                    )
                    completion(token)
                    return
                }

                if attempt == 1 {
                    print("[SalesforceMethodChannelHandler] \(method) empty token on attempt=1, retrying")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        requestToken(attempt: 2)
                    }
                    return
                }

                completion(nil)
            }
        }

        DispatchQueue.main.async {
            requestToken(attempt: 1)
        }
    }

    /// Handle openChat method call
    private func handleOpenChat(
        _ call: FlutterMethodCall, viewController: UIViewController, result: @escaping FlutterResult
    ) {
        let args = call.arguments as? [String: Any]

        do {
            guard let serviceApiUrl = args?["serviceApiUrl"] as? String,
                let orgId = args?["orgId"] as? String,
                let deploymentName = args?["deploymentName"] as? String
            else {
                result(
                    FlutterError(
                        code: "INVALID_ARGS", message: "Missing configuration parameters",
                        details: nil))
                return
            }

            let chatAssistantTitle = args?["chatAssistantTitle"] as? String
            let chatAssistantTooltipMessage = args?["chatAssistantTooltipMessage"] as? String

            let hasPreChatValues = args?["hasPreChatValues"] as? Bool ?? false
            let clientId = args?["clientId"] as? String
            let policyNumber = args?["policyNumber"] as? String
            let reason = args?["reason"] as? String
            let timeZoneOffset = args?["timeZoneOffset"] as? String
            let hasAllPreChatValues =
                !(clientId?.isEmpty ?? true)
                && !(policyNumber?.isEmpty ?? true)
                && !(reason?.isEmpty ?? true)
                && !(timeZoneOffset?.isEmpty ?? true)

            os_log(
                "[SalesforceMethodChannelHandler] openChat manual mode hasPreChatValues=\(hasPreChatValues)"
            )

            if hasPreChatValues && !hasAllPreChatValues {
                result(
                    FlutterError(
                        code: "INVALID_ARGS",
                        message:
                            "hasPreChatValues is true but one or more pre-chat fields are missing",
                        details: [
                            "clientId": clientId != nil,
                            "policyNumber": policyNumber != nil,
                            "reason": reason != nil,
                            "timeZoneOffset": timeZoneOffset != nil,
                        ]
                    ))
                return
            }

            if hasAllPreChatValues,
                let clientId = clientId,
                let policyNumber = policyNumber,
                let reason = reason,
                let timeZoneOffset = timeZoneOffset
            {
                os_log(
                    "[SalesforceMethodChannelHandler] pre-chat payload lengths clientId=\(clientId.count) policyNumber=\(policyNumber.count) reason=\(reason.count) timeZoneOffset=\(timeZoneOffset.count)"
                )
                try SalesforceMessagingManager.shared.openChat(
                    from: viewController,
                    serviceApiUrl: serviceApiUrl,
                    orgId: orgId,
                    deploymentName: deploymentName,
                    clientId: clientId,
                    policyNumber: policyNumber,
                    reason: reason,
                    timeZoneOffset: timeZoneOffset,
                    chatAssistantTitle: chatAssistantTitle,
                    chatAssistantTooltipMessage: chatAssistantTooltipMessage
                )
            } else {
                try SalesforceMessagingManager.shared.resumeChat(
                    from: viewController,
                    serviceApiUrl: serviceApiUrl,
                    orgId: orgId,
                    deploymentName: deploymentName,
                    chatAssistantTitle: chatAssistantTitle,
                    chatAssistantTooltipMessage: chatAssistantTooltipMessage
                )
            }
            invokeFlutterMethod("onChatOpened")
            result(true)
        } catch {
            result(
                FlutterError(code: "CHAT_ERROR", message: error.localizedDescription, details: nil))
        }
    }
}
