import Flutter
import UIKit

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
                result(FlutterError(code: "HANDLER_ERROR", message: "Handler deallocated", details: nil))
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
            invokeFlutterMethod("onChatOpened")
            result(true)

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
            completion(nil)
            return
        }

        channel.invokeMethod(method, arguments: nil) { response in
            print(response)
            completion(response as? String)
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
                    setAuthTokenProvider(<#T##SalesforceAuthTokenProvider?#>)
                )
            } else {
                guard let serviceApiUrl = args?["serviceApiUrl"] as? String,
                      let orgId = args?["orgId"] as? String,
                      let deploymentName = args?["deploymentName"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing configuration parameters", details: nil))
                    return
                }

                let hasPreChatValues = args?["hasPreChatValues"] as? Bool ?? false

                if hasPreChatValues,
                   let clientId = args?["clientId"] as? String,
                   let policyNumber = args?["policyNumber"] as? String,
                   let reason = args?["reason"] as? String,
                   let timeZoneOffset = args?["timeZoneOffset"] as? String {
                    try SalesforceMessagingManager.shared.openChatManualWithPreChatValues(
                        from: viewController,
                        serviceApiUrl: serviceApiUrl,
                        orgId: orgId,
                        deploymentName: deploymentName,
                        clientId: clientId,
                        policyNumber: policyNumber,
                        reason: reason,
                        timeZoneOffset: timeZoneOffset,
                        usePersistedConversation: persistConversation
                    )
                } else {
                    try SalesforceMessagingManager.shared.openChatManual(
                        from: viewController,
                        serviceApiUrl: serviceApiUrl,
                        orgId: orgId,
                        deploymentName: deploymentName,
                        usePersistedConversation: persistConversation
                    )
                }
            }
            invokeFlutterMethod("onChatOpened")
            result(true)
        } catch {
            result(FlutterError(code: "CHAT_ERROR", message: error.localizedDescription, details: nil))
        }
    }
}

