import Foundation
import SMIClientCore
import SMIClientUI
import Security
import UIKit
import UserNotifications

protocol SalesforceAuthTokenProvider: AnyObject {
    func onGetToken(completion: @escaping (String?) -> Void)
    func onRefreshToken(completion: @escaping (String?) -> Void)
}

/// Manager class for Salesforce In-App Messaging SDK
/// Handles configuration and opening of chat conversations
class SalesforceMessagingManager: NSObject {

    static let shared = SalesforceMessagingManager()

    private var config: UIConfiguration?
    private var conversationId: UUID?
    private var eventChannel: FlutterMethodChannel?
    private var eventCallback: ((String) -> Void)?
    private weak var authTokenProvider: SalesforceAuthTokenProvider?
    private var coreClient: CoreClient?
    // private var coreDelegate: CoreEventDelegate?
    private var lastChatNotificationTimestamp: TimeInterval = 0

    private let configFileName = "salesforce_config"
    private let conversationIdKey = "com.salesforce.messaging.conversationId"

    private var currentChatViewController: UIViewController?

    override private init() {}

    /// Set the event channel for sending events to Flutter
    func setEventChannel(_ channel: FlutterMethodChannel?) {
        self.eventChannel = channel
    }

    func setAuthTokenProvider(_ provider: SalesforceAuthTokenProvider?) {
        self.authTokenProvider = provider
    }

    private func sendEventToFlutter(_ event: String) {
        print("Sending event to Flutter: \(event)")
        switch event {
        case "minimized":
            eventChannel?.invokeMethod("onChatMinimized", arguments: nil) { _ in }
        case "closed":
            eventChannel?.invokeMethod("onChatClosed", arguments: nil) { _ in }
        case "opened":
            eventChannel?.invokeMethod("onChatOpened", arguments: nil) { _ in }
        case "session_ended":
            eventChannel?.invokeMethod("onSessionEnded", arguments: nil) { _ in }
        default:
            eventChannel?.invokeMethod(event, arguments: nil) { _ in }
        }
        eventCallback?(event)
    }

    fileprivate func showLocalChatNotificationIfBackground() {
        guard UIApplication.shared.applicationState != .active else {
            return
        }

        let now = Date().timeIntervalSince1970
        if now - lastChatNotificationTimestamp < 1 {
            return
        }
        lastChatNotificationTimestamp = now

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard
                settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
            else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "MyNYL"
            content.body = "You have a new chat message"
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "salesforce_chat_message_notification",
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to show chat notification: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Open Chat Methods

    /// Opens the Salesforce chat conversation using config file
    /// Based on: Step 2 Option 1 - Configure Using the Config File
    /// - Parameters:
    ///   - viewController: The view controller to present the chat from
    ///   - usePersistedConversation: If true, uses the same conversation ID across app restarts
    func openChatWithConfigFile(
        from viewController: UIViewController, usePersistedConversation: Bool = true
    ) throws {
        // Get the path for the config file
        guard let configPath = Bundle.main.path(forResource: configFileName, ofType: "json") else {
            throw SalesforceMessagingError.configFileNotFound
        }

        // Get a URL for the config file
        let configURL = URL(fileURLWithPath: configPath)

        // Get or generate conversation ID (UUID v4)
        // Use the SAME conversation ID to continue conversation across app restarts
        let conversationID = usePersistedConversation ? getOrCreateConversationId() : UUID()
        self.conversationId = conversationID

        // Create a configuration object (per Step 2 Option 1)
        let uiConfig = UIConfiguration(url: configURL, conversationId: conversationID)!
        self.config = uiConfig
        try presentChatContainer(with: uiConfig, from: viewController)
    }

    /// Opens the Salesforce chat conversation using manual configuration
    /// Based on: Step 2 Option 2 - Configure Manually with Config Info
    /// - Parameters:
    ///   - viewController: The view controller to present the chat from
    ///   - serviceApiUrl: The Salesforce Service API URL
    ///   - orgId: Your Salesforce Organization ID
    ///   - deploymentName: The API name of your deployment
    ///   - usePersistedConversation: If true, uses the same conversation ID across app restarts
    func openChatManual(
        from viewController: UIViewController,
        serviceApiUrl: String,
        orgId: String,
        deploymentName: String,
        usePersistedConversation: Bool = true
        
    ) throws {
        // Get a URL for the service API path
        guard let serviceAPIURL = URL(string: serviceApiUrl) else {
            throw SalesforceMessagingError.invalidUrl
        }

        // Get or generate conversation ID (UUID v4)
        // Use the SAME conversation ID to continue conversation across app restarts
        let conversationID = usePersistedConversation ? getOrCreateConversationId() : UUID()
        self.conversationId = conversationID

        // Create a configuration object (per Step 2 Option 2)
        let uiConfig = UIConfiguration(
            serviceAPI: serviceAPIURL,
            organizationId: orgId,
            developerName: deploymentName,
            conversationId: conversationID
            
        )
        self.coreClient = CoreFactory.create(withConfig: uiConfig)
        self.coreClient?.setUserVerificationDelegate(delegate: UserVerificationDelegateImplementation(authTokenProvider: self.authTokenProvider), queue: DispatchQueue.main)
      
        
        self.config = uiConfig
        try presentChatContainer(with: uiConfig, from: viewController)
    }

    /// Opens the Salesforce chat conversation using manual configuration with pre-chat values.
    /// This keeps method-channel parity with Android while reusing the current iOS container.
    func openChatManualWithPreChatValues(
        from viewController: UIViewController,
        serviceApiUrl: String,
        orgId: String,
        deploymentName: String,
        clientId: String,
        policyNumber: String,
        reason: String,
        timeZoneOffset: String,
        usePersistedConversation: Bool = true
    ) throws {
        guard let serviceAPIURL = URL(string: serviceApiUrl) else {
            throw SalesforceMessagingError.invalidUrl
        }

        // Get or generate conversation ID (UUID v4)
        // Use the SAME conversation ID to continue conversation across app restarts
        let conversationID = usePersistedConversation ? getOrCreateConversationId() : UUID()
        self.conversationId = conversationID

        // Create a configuration object (per Step 2 Option 2)
        let uiConfig = UIConfiguration(
            serviceAPI: serviceAPIURL,
            organizationId: orgId,
            developerName: deploymentName,
            conversationId: conversationID
            
        )
        self.coreClient = CoreFactory.create(withConfig: uiConfig)
        self.coreClient?.setUserVerificationDelegate(delegate: UserVerificationDelegateImplementation(authTokenProvider: self.authTokenProvider), queue: .main)
        self.coreClient?.preChatDelegate = HiddenPrechatDelegateImplementation(clientId: clientId, policyNumber: policyNumber, reason: reason, timeZoneOffset: timeZoneOffset)
        
        self.config = uiConfig
        try presentChatContainer(with: uiConfig, from: viewController)

    }

    /// Opens the Salesforce chat modally
    /// Based on: Step 3 - ModalInterfaceViewController option
    func openChatModally(
        from viewController: UIViewController, usePersistedConversation: Bool = true
    ) throws {
        guard let configPath = Bundle.main.path(forResource: configFileName, ofType: "json") else {
            throw SalesforceMessagingError.configFileNotFound
        }

        let configURL = URL(fileURLWithPath: configPath)
        let conversationID = usePersistedConversation ? getOrCreateConversationId() : UUID()
        self.conversationId = conversationID

        let uiConfig = UIConfiguration(url: configURL, conversationId: conversationID)!
        self.config = uiConfig
        try presentChatContainer(with: uiConfig, from: viewController)
    }

    func openChatAsBottomSheet(
        from viewController: UIViewController, usePersistedConversation: Bool = true
    ) throws {
        guard let configPath = Bundle.main.path(forResource: configFileName, ofType: "json") else {
            throw SalesforceMessagingError.configFileNotFound
        }

        let configURL = URL(fileURLWithPath: configPath)
        let conversationID = usePersistedConversation ? getOrCreateConversationId() : UUID()
        self.conversationId = conversationID

        let uiConfig = UIConfiguration(url: configURL, conversationId: conversationID)!
        self.config = uiConfig

        try presentChatContainer(with: uiConfig, from: viewController)
    }

    private func presentChatContainer(
        with uiConfig: UIConfiguration, from viewController: UIViewController
    ) throws {
        // Extract CoreConfiguration for delegate access if needed
        // The CoreClient may be created internally by UIConfiguration
        // For now, we'll try to access it via UIConfiguration or create separately
        // TODO: Verify CoreClient access pattern in UIConfiguration for this SDK version

        // Register delegate if CoreClient is available
        // Note: The exact method to access CoreClient from UIConfiguration may vary
        // This is a placeholder for proper integration once SDK internals are verified
        // registerCoreDelegate()

        let navigationBarBuilder = NavigationBarBuilder()
        navigationBarBuilder.updateNavigation { _, navigationItem in
            navigationItem.leftBarButtonItems = []
            navigationItem.rightBarButtonItems = []
            navigationItem.title = ""
            navigationItem.titleView = nil
            navigationItem.hidesBackButton = true
        }

        let chatVC = ModalInterfaceViewController(
            uiConfig,
            preChatFieldValueProvider: nil,
            chatFeedViewBuilder: nil,
            navigationBarBuilder: navigationBarBuilder
        )
        
        chatVC.setNavigationBarHidden(true, animated: false)

        let containerVC = ChatContainerViewController(
            contentController: chatVC,
            eventCallback: { [weak self] event in
                self?.sendEventToFlutter(event)
            })
        self.currentChatViewController = containerVC

        containerVC.modalPresentationStyle = .fullScreen
        viewController.present(containerVC, animated: true)
    }

    /// Closes the current conversation explicitly
    /// When closed, no new messages can be sent to this conversation
    func closeConversation(completion: ((Error?) -> Void)? = nil) {
        if let presentedChat = currentChatViewController {
            presentedChat.dismiss(animated: true) {
                self.currentChatViewController = nil
                self.clearConversation()
                self.sendEventToFlutter("session_ended")
                completion?(nil)
            }
        } else if conversationId != nil {
            clearConversation()
            sendEventToFlutter("session_ended")
            completion?(nil)
        } else {
            completion?(SalesforceMessagingError.chatNotInitialized)
        }
    }

    /// Minimizes/dismisses the active chat UI without ending the conversation.
    func minimizeChat() {
        currentChatViewController?.dismiss(animated: true, completion: nil)
        sendEventToFlutter("minimized")
    }

    /// Token revocation hook for parity with Android method channel.
    /// Current iOS integration does not retain SDK token state here.
    func revokeToken() {
        authTokenProvider?.onRefreshToken { [weak self] token in
            guard let token = token, !token.isEmpty else {
                return
            }
        }
    }

    private class ChatContainerViewController: UIViewController {
        private let contentController: UIViewController
        private let headerHeight: CGFloat = 56
        private let topSpacing: CGFloat = 20
        private var eventCallback: ((String) -> Void)?

        private let sheetView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = .white
            view.layer.cornerRadius = 0
            view.clipsToBounds = true
            return view
        }()

        init(contentController: UIViewController, eventCallback: ((String) -> Void)? = nil) {
            self.contentController = contentController
            self.eventCallback = eventCallback
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            setupSheetView()
            setupHeader()
            setupContentController()
        }

        private func setupSheetView() {
            view.addSubview(sheetView)

            NSLayoutConstraint.activate([
                sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                sheetView.topAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.topAnchor, constant: topSpacing),
                sheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }

        private func setupHeader() {
            let headerView = UIView()
            headerView.translatesAutoresizingMaskIntoConstraints = false
            headerView.backgroundColor = UIColor(
                red: 18 / 255, green: 52 / 255, blue: 84 / 255, alpha: 1.0)  // Dark blue #123454

            // Create logo view with New York Life icon
            let logoImageView = UIImageView()
            logoImageView.translatesAutoresizingMaskIntoConstraints = false
            logoImageView.contentMode = .scaleAspectFit
            logoImageView.image = UIImage(named: "nyl_logo") ?? UIImage(systemName: "square.fill")
            logoImageView.tintColor = .white

            // Minimize button with custom icon
            let minimizeButton = UIButton(type: .custom)
            minimizeButton.translatesAutoresizingMaskIntoConstraints = false
            minimizeButton.setImage(UIImage(named: "icn_live_chat_minimize"), for: .normal)
            minimizeButton.tag = 1
            minimizeButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            minimizeButton.imageView?.contentMode = .scaleAspectFit

            // Close button with custom icon
            let closeButton = UIButton(type: .custom)
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            closeButton.setImage(UIImage(named: "icn_close"), for: .normal)
            closeButton.tag = 2
            closeButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            closeButton.imageView?.contentMode = .scaleAspectFit

            // Create spacer between buttons
            let buttonStack = UIStackView(arrangedSubviews: [minimizeButton, closeButton])
            buttonStack.translatesAutoresizingMaskIntoConstraints = false
            buttonStack.axis = .horizontal
            buttonStack.spacing = 16
            buttonStack.distribution = .equalSpacing

            sheetView.addSubview(headerView)
            headerView.addSubview(logoImageView)
            headerView.addSubview(buttonStack)

            NSLayoutConstraint.activate([
                headerView.topAnchor.constraint(equalTo: sheetView.topAnchor),
                headerView.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
                headerView.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
                headerView.heightAnchor.constraint(equalToConstant: headerHeight),

                logoImageView.leadingAnchor.constraint(
                    equalTo: headerView.leadingAnchor, constant: 12),
                logoImageView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
                logoImageView.widthAnchor.constraint(equalToConstant: 32),
                logoImageView.heightAnchor.constraint(equalToConstant: 32),

                minimizeButton.widthAnchor.constraint(equalToConstant: 24),
                minimizeButton.heightAnchor.constraint(equalToConstant: 24),

                closeButton.widthAnchor.constraint(equalToConstant: 24),
                closeButton.heightAnchor.constraint(equalToConstant: 24),

                buttonStack.trailingAnchor.constraint(
                    equalTo: headerView.trailingAnchor, constant: -12),
                buttonStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            ])
        }

        @objc private func buttonTapped(_ sender: UIButton) {
            if sender.tag == 1 {
                // Minimize button (chevron.down)
                eventCallback?("minimized")
                print("Minimize button tapped - sending minimized event")
            } else if sender.tag == 2 {
                // Close button (xmark)
                eventCallback?("closed")
                print("Close button tapped - sending closed event")
            }
            dismiss(animated: true, completion: nil)
        }

        private func setupContentController() {
            addChild(contentController)
            contentController.view.translatesAutoresizingMaskIntoConstraints = false
            sheetView.addSubview(contentController.view)
            contentController.didMove(toParent: self)

            NSLayoutConstraint.activate([
                contentController.view.topAnchor.constraint(
                    equalTo: sheetView.topAnchor, constant: headerHeight),
                contentController.view.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
                contentController.view.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
                contentController.view.bottomAnchor.constraint(equalTo: sheetView.bottomAnchor),
            ])
        }
    }

    /// Starts a new conversation (clears current and creates new ID)
    func startNewConversation(from viewController: UIViewController) {
        clearConversation()
        try? openChatWithConfigFile(from: viewController, usePersistedConversation: false)
    }

    /// Clears the stored conversation ID from Keychain
    func clearConversation() {
        deleteFromKeychain(key: conversationIdKey)
        conversationId = nil
        config = nil
    }

    /// Returns the current conversation ID if one exists
    func getCurrentConversationId() -> UUID? {
        return conversationId
    }

    // MARK: - Conversation ID Management (UUID v4)

    /// Gets an existing conversation ID or creates a new one
    /// Uses Keychain for secure, persistent storage (recommended by Salesforce)
    private func getOrCreateConversationId() -> UUID {
        // Try to retrieve from Keychain first
        if let savedIdString = loadFromKeychain(key: conversationIdKey),
            let savedId = UUID(uuidString: savedIdString)
        {
            return savedId
        }

        // Generate new UUID v4 (randomly generated)
        let newId = UUID()
        saveToKeychain(key: conversationIdKey, value: newId.uuidString)
        return newId
    }

    // MARK: - Keychain Storage (Secure Persistence)

    /// Saves a value to the Keychain
    private func saveToKeychain(key: String, value: String) {
        let data = Data(value.utf8)

        // Delete any existing item first
        deleteFromKeychain(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Error saving to Keychain: \(status)")
        }
    }

    /// Loads a value from the Keychain
    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
            let data = result as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return value
    }

    /// Deletes a value from the Keychain
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)
    }

    /// Registers CoreDelegate to listen for SDK events (messages, unread count changes)
    // private func registerCoreDelegate() {
    //     guard let client = coreClient else {
    //         print("CoreClient not available for delegate registration")
    //         return
    //     }

    //     // Create and register the delegate
    //     let delegate = CoreEventDelegate(manager: self)
    //     self.coreDelegate = delegate
    //     client.addDelegate(delegate, queue: .main)
    //     print("CoreDelegate registered with CoreClient")
    // }
}

// MARK: - UserVerificationDelegate

class UserVerificationDelegateImplementation: NSObject, UserVerificationDelegate {

    private weak var authTokenProvider: SalesforceAuthTokenProvider?

    init(authTokenProvider: SalesforceAuthTokenProvider?) {
        self.authTokenProvider = authTokenProvider
    }


    func core(_ core: CoreClient,
                userVerificationChallengeWith reason: ChallengeReason,
                completionHandler completion: @escaping UserVerificationChallengeCompletion) {
                    guard let authTokenProvider = authTokenProvider else {
                        completion(nil)
                        return
                    }

        switch reason {
        case .initial: authTokenProvider.onGetToken { token in
            completion(UserVerification(customerIdentityToken: token!,type: .JWT));
        }
        case .refresh: authTokenProvider.onRefreshToken { token in
            completion(UserVerification(customerIdentityToken: token!,type: .JWT));
        }
        case .expired: authTokenProvider.onRefreshToken { token in
            completion(UserVerification(customerIdentityToken: token!,type: .JWT));
        }
        case .malformed:authTokenProvider.onGetToken { token in
            completion(UserVerification(customerIdentityToken: token!,type: .JWT));
        }
        default: print("nothing to do")
            
        }
    }
}

// MARK: - HiddenPreChatDelegate

class HiddenPrechatDelegateImplementation: HiddenPreChatDelegate {

    private var clientId : String
    private var policyNumber : String
    private var reason : String
    private var timeZoneOffset : String


    init(clientId: String, policyNumber: String, reason: String, timeZoneOffset: String) {
        self.clientId = clientId
        self.policyNumber = policyNumber
        self.reason = reason
        self.timeZoneOffset = timeZoneOffset
    }

  func core(_ core: CoreClient!,
            conversation: Conversation!,
            didRequestPrechatValues hiddenPreChatFields: [HiddenPreChatField]!,
            completionHandler: HiddenPreChatValueCompletion!) {

    // Fill in all the hidden pre-chat fields
    for preChatField in hiddenPreChatFields {
      switch preChatField.name {
            case "Client_Id": preChatField.value = clientId
            case "Policy_Number": preChatField.value = policyNumber
            case "Reason": preChatField.value = reason
            case "P_TimeZoneOffset": preChatField.value = timeZoneOffset
            default: print("Unknown hidden prechat field: \(preChatField.name)")
            }
    }

    // Pass pre-chat fields back to SDK
    completionHandler(hiddenPreChatFields)
  }
}

// MARK: - CoreEventDelegate

/// Delegate to listen for Salesforce In-App Messaging SDK events
// private class CoreEventDelegate: NSObject, CoreDelegate {
//     weak var manager: SalesforceMessagingManager?

//     init(manager: SalesforceMessagingManager?) {
//         self.manager = manager
//     }

//     // MARK: - CoreDelegate Methods

//     /// Called when a new conversation entry (message) is received
//     func core(
//         _ client: any CoreClient,
//         didReceive entry: any ConversationEntry
//     ) {
//         // print("[CoreDelegate] New message received")
//         manager?.eventCallback?("onChatNewMessage")
//         manager?.showLocalChatNotificationIfBackground()
//     }

//     /// Called when conversation unread count changes
//     func core(
//         _ client: any CoreClient,
//         conversation: any Conversation,
//         didUpdateUnreadMessageCount unreadCount: Int
//     ) {
//         // print("[CoreDelegate] Unread count updated: \(unreadCount)")
//         manager?.eventCallback?("onChatUnreadCountChanged")
//     }

//     /// Called when multiple conversation entries are received
//     func core(
//         _ client: any CoreClient,
//         conversation: any Conversation,
//         didReceiveEvents entries: [any ConversationEntry]
//     ) {
//         // print("[CoreDelegate] Received \(entries.count) events")
//         if !entries.isEmpty {
//             manager?.eventCallback?("onChatNewMessage")
//             manager?.showLocalChatNotificationIfBackground()
//         }
//     }

//     /// Called when entries are updated
//     func core(
//         _ client: any CoreClient,
//         conversation: any Conversation,
//         didUpdateEntries entries: [any ConversationEntry]
//     ) {
//         // print("\[CoreDelegate] Entries updated: \(entries.count)")
//     }

//     /// Called when realtime connection state changes
//     func core(
//         _ client: any CoreClient,
//         didChangeConnectionState state: RealtimeConnectionState
//     ) {
//         // print("\[CoreDelegate] Connection state changed: \(state)")
//     }

//     /// Called when network connectivity state changes
//     func core(
//         _ client: any CoreClient,
//         didChangeNetworkState state: NetworkConnectivityState
//     ) {
//         // print("\[CoreDelegate] Network state changed: \(state)")
//     }

//     /// Called when conversation is updated
//     func core(
//         _ client: any CoreClient,
//         didUpdate conversation: any Conversation
//     ) {
//         // print("\[CoreDelegate] Conversation updated")
//     }

//     /// Called when active participants in conversation change
//     func core(
//         _ client: any CoreClient,
//         conversation: any Conversation,
//         didUpdateActiveParticipants participants: [any Participant]
//     ) {
//         // print("\[CoreDelegate] Active participants updated: \(participants.count)")
//     }
// }

// MARK: - Error Types

enum SalesforceMessagingError: Error {
    case configFileNotFound
    case invalidUrl
    case chatNotInitialized

    var localizedDescription: String {
        switch self {
        case .configFileNotFound:
            return "Salesforce config file not found in bundle"
        case .invalidUrl:
            return "Invalid Service API URL"
        case .chatNotInitialized:
            return "Chat has not been initialized"
        }
    }
}
