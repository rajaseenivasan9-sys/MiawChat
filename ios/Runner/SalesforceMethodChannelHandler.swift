import Flutter
import UIKit

/// Handles Flutter method channel communication for Salesforce In-App Chat
class SalesforceMethodChannelHandler {

    static let shared = SalesforceMethodChannelHandler()

    private let channelName = "com.example.newproject/salesforce_chat"
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
                result(FlutterError(code: "HANDLER_ERROR", message: "Handler deallocated", details: nil))
                return
            }
            self.handleMethodCall(call, result: result)
        }
        
        print("Salesforce Method Channel Handler setup complete for channel: \(channelName)")
    }

    /// Handle incoming method calls from Flutter
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Root view controller not found", details: nil))
            return
        }

        switch call.method {
        case "openChat":
            handleOpenChat(call, viewController: rootViewController, result: result)

        case "clearConversation":
            SalesforceMessagingManager.shared.clearConversation()
            result(true)

        case "closeConversation":
            SalesforceMessagingManager.shared.closeConversation { error in
                if let error = error {
                    result(FlutterError(code: "CLOSE_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(true)
                }
            }

        case "startNewConversation":
            SalesforceMessagingManager.shared.startNewConversation(from: rootViewController)
            result(true)

        case "getConversationId":
            let conversationId = SalesforceMessagingManager.shared.getCurrentConversationId()
            result(conversationId?.uuidString)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Handle openChat method call
    private func handleOpenChat(_ call: FlutterMethodCall, viewController: UIViewController, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let useConfigFile = args?["useConfigFile"] as? Bool ?? true
        let persistConversation = args?["persistConversation"] as? Bool ?? true

        do {
            if useConfigFile {
                try SalesforceMessagingManager.shared.openChatAsBottomSheet(
                    from: viewController,
                    usePersistedConversation: persistConversation
                )
            } else {
                guard let serviceApiUrl = args?["serviceApiUrl"] as? String,
                      let orgId = args?["orgId"] as? String,
                      let deploymentName = args?["deploymentName"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing configuration parameters", details: nil))
                    return
                }

                try SalesforceMessagingManager.shared.openChatManual(
                    from: viewController,
                    serviceApiUrl: serviceApiUrl,
                    orgId: orgId,
                    deploymentName: deploymentName,
                    usePersistedConversation: persistConversation
                )
            }
            result(true)
        } catch {
            result(FlutterError(code: "CHAT_ERROR", message: error.localizedDescription, details: nil))
        }
    }
}

