import Foundation
import SMIClientCore
import SMIClientUI
import Security
import UIKit
import UserNotifications
import os.log

protocol SalesforceAuthTokenProvider: AnyObject {
    func onGetToken(completion: @escaping (String?) -> Void)
    func onRefreshToken(completion: @escaping (String?) -> Void)
}

/// Manager class for Salesforce In-App Messaging SDK
/// Handles configuration and opening of chat conversations
class SalesforceMessagingManager: NSObject {

    static let shared = SalesforceMessagingManager()

    private struct HiddenPreChatValues {
        let clientId: String
        let policyNumber: String
        let reason: String
        let timeZoneOffset: String
    }

    private var config: UIConfiguration?
    private var conversationId: UUID?
    private var eventChannel: FlutterMethodChannel?
    private var eventCallback: ((String) -> Void)?
    private var authTokenProvider: SalesforceAuthTokenProvider?
    private var coreClient: CoreClient?
    private var conversationClient: (any ConversationClient)?
    private var userVerificationDelegate: UserVerificationDelegateImplementation?
    private var hiddenPreChatDelegate: HiddenPrechatDelegateImplementation?
    private var unreadObserverTimer: Timer?
    private var lastUnreadCount: Int?
    private var shouldShowAssistantHeaderTitle: Bool = true
    private var chatAssistantTitle: String?
    private var chatAssistantTooltipMessage: String?
    private var assistantHeaderStateCallback: ((Bool) -> Void)?
    // private var coreDelegate: CoreEventDelegate?
    private var lastChatNotificationTimestamp: TimeInterval = 0
    private var latestHiddenPreChatValues: HiddenPreChatValues?
    private var didSubmitPreChatForCurrentSession: Bool = false
    private var hasUserSentMessageInActiveSession: Bool = false

    private let configFileName = "salesforce_config"
    private let conversationIdKey = "com.salesforce.messaging.conversationId"

    private var currentChatViewController: UIViewController?

    override private init() {}

    /// Set the event channel for sending events to Flutter
    func setEventChannel(_ channel: FlutterMethodChannel?) {
        print("[SalesforceMessagingManager] setEventChannel: \(channel != nil ? "set" : "cleared")")
        self.eventChannel = channel
    }

    func setAuthTokenProvider(_ provider: SalesforceAuthTokenProvider?) {
        self.authTokenProvider = provider
    }

    func setAssistantHeaderStateCallback(_ callback: ((Bool) -> Void)?) {
        self.assistantHeaderStateCallback = callback
    }

    func resolveAssistantHeaderState(completion: @escaping (Bool) -> Void) {
        guard let conversationClient = conversationClient else {
            DispatchQueue.main.async {
                completion(true)
            }
            return
        }

        conversationClient.conversation { [weak self] conversation, _ in
            guard let self = self, let conversation = conversation else {
                DispatchQueue.main.async {
                    completion(true)
                }
                return
            }

            let showAssistantTitle = self.shouldShowAssistantHeaderTitle(for: conversation)
            self.shouldShowAssistantHeaderTitle = showAssistantTitle
            DispatchQueue.main.async {
                completion(showAssistantTitle)
            }
        }
    }

    private func sendAssistantHeaderState(_ showAssistantTitle: Bool) {
        DispatchQueue.main.async {
            self.assistantHeaderStateCallback?(showAssistantTitle)
        }
    }

    private func applyBrandingConfiguration(to uiConfig: UIConfiguration) {
        // iOS 26+ uses Liquid Glass by default; enable SDK branding so custom tokens can render.
        uiConfig.liquidGlassConfiguration = LiquidGlassConfiguration(
            allowBrandingForLiquidGlass: true)
    }

    private func configureUserVerificationDelegate() {
        guard let coreClient = self.coreClient else {
            os_log("[SalesforceMessagingManager] configureUserVerify: fail: no core client")
            return
        }

        guard let provider = self.authTokenProvider else {
            os_log("[SalesforceMessagingManager] configureUserVerify: fail: no auth provider")
            return
        }

        self.userVerificationDelegate = UserVerificationDelegateImplementation(
            authTokenProvider: provider)

        guard let delegate = self.userVerificationDelegate else {
            os_log("[SalesforceMessagingManager] configureUserVerify: fail: no verify delegate")
            return
        }

        coreClient.setUserVerificationDelegate(delegate: delegate, queue: .main)
        os_log("[SalesforceMessagingManager] configureUserVerify: UserVerficationDelegate configured")
    }

    private func configureHiddenPreChatDelegate(
        clientId: String,
        policyNumber: String,
        reason: String,
        timeZoneOffset: String
    ) {
        guard let coreClient = self.coreClient else {
            os_log("[SalesforceMessagingManager] configureHiddenPrechat: fail: no core client")
            return
        }

        self.hiddenPreChatDelegate = HiddenPrechatDelegateImplementation(
            clientId: clientId,
            policyNumber: policyNumber,
            reason: reason,
            timeZoneOffset: timeZoneOffset
        )

        guard let delegate = self.hiddenPreChatDelegate else {
            os_log("[SalesforceMessagingManager] configureHiddenPrechat: fail: no delegate")
            return
        }

        coreClient.setPreChatDelegate(delegate: delegate, queue: .main)
        os_log("[SalesforceMessagingManager] configureHiddenPrechat: HiddenPreChatDelegate configured")
    }

    private func populateHiddenPreChatFields(
        _ hiddenPreChatFields: [any HiddenPreChatField],
        with values: HiddenPreChatValues
    ) {
        os_log("[SalesforceMessagingManager] populate fields: start")
        for preChatField in hiddenPreChatFields {
            switch preChatField.name {
            case "Client_Id": preChatField.value = values.clientId
            case "Policy_Number": preChatField.value = values.policyNumber
            case "Reason": preChatField.value = values.reason
            case "P_TimeZoneOffset": preChatField.value = values.timeZoneOffset
            default: break
            }
        }
        os_log("[SalesforceMessagingManager] populate fields: completed")
    }

    private func submitHiddenPreChatDataIfNeeded(
        conversation: Conversation,
        createConversationOnSubmit: Bool
    ) {
        os_log("[SalesforceMessagingManager] submit chat: start")
        os_log("[SalesforceMessagingManager] submit chat: didSubmit: \(self.didSubmitPreChatForCurrentSession)")
        guard !didSubmitPreChatForCurrentSession else {
            os_log("[SalesforceMessagingManager] submit chat: fail: already submitted")
            return
        }
        guard let values = latestHiddenPreChatValues else {
            os_log("[SalesforceMessagingManager] submit chat: fail: no preChatValues")
            return
        }
        guard let conversationClient = conversationClient else {
            os_log("[SalesforceMessagingManager] submit chat: fail: no conversationClient")
            return
        }

        os_log("[SalesforceMessagingManager] submit chat: preChatFields: count: \(conversation.preChatFields.count)")
        os_log("[SalesforceMessagingManager] submit chat: hiddenpreChatFields: count: \(conversation.hiddenPreChatFields.count)")

        let hiddenPreChatFields = conversation.hiddenPreChatFields
        if hiddenPreChatFields.isEmpty {
            os_log("[SalesforceMessagingManager] submit chat: fail: hiddenFields: empty")
            return
        }

        populateHiddenPreChatFields(hiddenPreChatFields, with: values)

        // Submit pre-chat data before user send attempts to avoid first-message error flash.
        guard conversationClient.submit?(preChatFields: conversation.preChatFields,
                                        hiddenPreChatFields: hiddenPreChatFields,
                                        createConversationOnSubmit: createConversationOnSubmit) != nil else {
            os_log("[SalesforceMessagingManager] submit chat: fail: submit callback unavailable")
            return
        }

        didSubmitPreChatForCurrentSession = true
        os_log("[SalesforceMessagingManager] submit chat: completed")
    }

    private func primeHiddenPreChatForCurrentSession() {
        os_log("[SalesforceMessagingManager] prime chat: start")
        guard latestHiddenPreChatValues != nil else {
            os_log("[SalesforceMessagingManager] prime chat: preChatValues: fail")
            return
        }
        guard let conversationClient = conversationClient else {
            os_log("[SalesforceMessagingManager] prime chat: conversation client: fail")
            return
        }

        conversationClient.conversation { [weak self] conversation, _ in
            guard let self = self, let conversation = conversation else {
                os_log("[SalesforceMessagingManager] prime chat: get conversation: fail")
                return
            }

            self.submitHiddenPreChatDataIfNeeded(
                conversation: conversation,
                createConversationOnSubmit: true)
        }
    }

    private func sendEventToFlutter(_ event: String, arguments: Any? = nil) {
        os_log("[SalesforceMessagingManager] sending event to flutter: \(event)")
        switch event {
        case "minimized":
            eventChannel?.invokeMethod("onChatMinimized", arguments: arguments) { _ in }
        case "closed":
            eventChannel?.invokeMethod("onChatClosed", arguments: arguments) { _ in }
        case "opened":
            eventChannel?.invokeMethod("onChatOpened", arguments: arguments) { _ in }
        case "session_ended":
            eventChannel?.invokeMethod("onSessionEnded", arguments: arguments) { _ in }
        case "chat_unread_count_changed":
            eventChannel?.invokeMethod("onChatUnreadCountChanged", arguments: arguments) { _ in }
        case "chat_new_message":
            eventChannel?.invokeMethod("onChatNewMessage", arguments: arguments) { _ in }
        default:
            eventChannel?.invokeMethod(event, arguments: arguments) { _ in }
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

    /// Opens the Salesforce chat conversation using manual configuration
    /// Based on: Step 2 Option 2 - Configure Manually with Config Info
    /// - Parameters:
    ///   - viewController: The view controller to present the chat from
    ///   - serviceApiUrl: The Salesforce Service API URL
    ///   - orgId: Your Salesforce Organization ID
    ///   - deploymentName: The API name of your deployment
    func resumeChat(
        from viewController: UIViewController,
        serviceApiUrl: String,
        orgId: String,
        deploymentName: String,
        chatAssistantTitle: String? = nil,
        chatAssistantTooltipMessage: String? = nil

    ) throws {
        print("[SalesforceMessagingManager] resumeChat called")

        // Get a URL for the service API path
        guard let serviceAPIURL = URL(string: serviceApiUrl) else {
            throw SalesforceMessagingError.invalidUrl
        }

        // Get or generate conversation ID (UUID v4)
        // Use the SAME conversation ID to continue conversation across app restarts
        let conversationID =  getOrCreateConversationId() 
        self.conversationId = conversationID
        self.chatAssistantTitle = chatAssistantTitle
        self.chatAssistantTooltipMessage = chatAssistantTooltipMessage
        self.latestHiddenPreChatValues = nil
        self.didSubmitPreChatForCurrentSession = false
        self.hasUserSentMessageInActiveSession = false
        print("[SalesforceMessagingManager] Conversation ID: \(conversationID)")

        // Create a configuration object (per Step 2 Option 2)
        let uiConfig = UIConfiguration(
            serviceAPI: serviceAPIURL,
            organizationId: orgId,
            developerName: deploymentName,
            userVerificationRequired: true,
            conversationId: conversationID

        )
        applyBrandingConfiguration(to: uiConfig)
        self.coreClient = CoreFactory.create(withConfig: uiConfig)

        if self.coreClient != nil {
            print(
                "[SalesforceMessagingManager] CoreClient created, setting UserVerificationDelegate")
            configureUserVerificationDelegate()
            self.coreClient?.start()
            self.conversationClient = self.coreClient?.conversationClient(with: conversationID)
        } else {
            print("[SalesforceMessagingManager] ERROR: Failed to create CoreClient")
        }

        self.config = uiConfig
        startUnreadObserver()
        try presentChatContainer(with: uiConfig, from: viewController)
    }

    /// Opens the Salesforce chat conversation using manual configuration with pre-chat values.
    /// This keeps method-channel parity with Android while reusing the current iOS container.
    func openChat(
        from viewController: UIViewController,
        serviceApiUrl: String,
        orgId: String,
        deploymentName: String,
        clientId: String,
        policyNumber: String,
        reason: String,
        timeZoneOffset: String,
        chatAssistantTitle: String? = nil,
        chatAssistantTooltipMessage: String? = nil
    ) throws {
        os_log("[SalesforceMessagingManager] openChat called")

        guard let serviceAPIURL = URL(string: serviceApiUrl) else {
            throw SalesforceMessagingError.invalidUrl
        }

        // Get or generate conversation ID (UUID v4)
        // Use the SAME conversation ID to continue conversation across app restarts
        let conversationID =  getOrCreateConversationId()
        self.conversationId = conversationID
        self.chatAssistantTitle = chatAssistantTitle
        self.chatAssistantTooltipMessage = chatAssistantTooltipMessage
        self.latestHiddenPreChatValues = HiddenPreChatValues(
            clientId: clientId,
            policyNumber: policyNumber,
            reason: reason,
            timeZoneOffset: timeZoneOffset
        )
        self.didSubmitPreChatForCurrentSession = false
        self.hasUserSentMessageInActiveSession = false
        os_log("[SalesforceMessagingManager] Conversation ID: \(conversationID)")

        // Create a configuration object (per Step 2 Option 2)
        let uiConfig = UIConfiguration.init(
            serviceAPI: serviceAPIURL,
            organizationId: orgId,
            developerName: deploymentName,
            userVerificationRequired: true,
            conversationId: conversationID
        )
        applyBrandingConfiguration(to: uiConfig)

        uiConfig.attachmentConfiguration = AttachmentConfiguration(endUserToAgent: false)

        self.coreClient = CoreFactory.create(withConfig: uiConfig)

        configureUserVerificationDelegate()
        self.coreClient?.start()
        self.conversationClient = self.coreClient?.conversationClient(with: conversationID)
        configureHiddenPreChatDelegate(
            clientId: clientId,
            policyNumber: policyNumber,
            reason: reason,
            timeZoneOffset: timeZoneOffset
        )
        primeHiddenPreChatForCurrentSession()

        self.config = uiConfig
        startUnreadObserver()
        try presentChatContainer(with: uiConfig, from: viewController)
    }

    private func startUnreadObserver() {
        os_log("[SalesforceMessagingManager] init unread observer: start")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { 
                os_log("[SalesforceMessagingManager] unread observer: fail: no self")
                return
            }
            self.stopUnreadObserver()
            let timer = Timer(
                timeInterval: 1.0,
                target: self,
                selector: #selector(Self.pollUnreadCount),
                userInfo: nil,
                repeats: true
            )
            self.unreadObserverTimer = timer
            RunLoop.main.add(timer, forMode: .common)
            os_log("[SalesforceMessagingManager] init unread observer: completed")
        }
    }

    @discardableResult
    private func recoverConversationClientIfNeeded() -> Bool {
        os_log("[SalesforceMessagingManager] recover conversationClient: start")
        if conversationClient != nil {
            os_log("[SalesforceMessagingManager] recover conversationClient: present already")
            return true
        }
        guard let conversationId = conversationId, let coreClient = coreClient else {
            os_log("[SalesforceMessagingManager] recover conversationClient: fail: no conversation id or core client")
            return false
        }
        conversationClient = coreClient.conversationClient(with: conversationId)
        os_log("[SalesforceMessagingManager] recover conversationClient: completed")
        return conversationClient != nil
    }

    private func stopUnreadObserver() {
        os_log("[SalesforceMessagingManager] stop unread observer: start")
        unreadObserverTimer?.invalidate()
        unreadObserverTimer = nil
        os_log("[SalesforceMessagingManager] stop unread observer: completed")
    }

    @objc private func pollUnreadCount() {
        os_log("[SalesforceMessagingManager] poller: start")
        guard conversationId != nil else {
            os_log("[SalesforceMessagingManager] poller: fail: no conversation id")
            stopUnreadObserver()
            return
        }

        guard recoverConversationClientIfNeeded() else {
            return
        }

        conversationClient?.conversation(completion: { [weak self] conversation, _ in
            guard let self = self, let conversation = conversation else {
                _ = self?.recoverConversationClientIfNeeded()
                return
            }

            self.submitHiddenPreChatDataIfNeeded(
                conversation: conversation,
                createConversationOnSubmit: true)

            let unread = Int(conversation.unreadMessageCount)
            let previous = self.lastUnreadCount
            let nextAssistantState = self.shouldShowAssistantHeaderTitle(for: conversation)
            if nextAssistantState != self.shouldShowAssistantHeaderTitle {
                self.shouldShowAssistantHeaderTitle = nextAssistantState
                self.sendAssistantHeaderState(nextAssistantState)
            }
            guard previous == nil || unread != previous else {
                return
            }

            self.sendEventToFlutter("chat_unread_count_changed", arguments: ["count": unread])

            if let previous = previous, unread > previous {
                self.sendEventToFlutter("chat_new_message", arguments: ["count": unread])
                self.showLocalChatNotificationIfBackground()
            }

            self.lastUnreadCount = unread
        })
    }

    private func presentChatContainer(
        with uiConfig: UIConfiguration, from viewController: UIViewController
    ) throws {
        os_log("[SalesforceMessagingManager] present chat: start")
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
            navigationBarBuilder: navigationBarBuilder
        )
        os_log("[SalesforceMessagingManager] present chat: ModalInterfaceViewController created")
        chatVC.setNavigationBarHidden(true, animated: false)

        let containerVC = ChatContainerViewController(
            contentController: chatVC,
            assistantTitle: chatAssistantTitle,
            assistantTooltipMessage: chatAssistantTooltipMessage,
            eventCallback: { [weak self] event in
                os_log("[SalesforceMessagingManager] present chat: ChatContainerViewController event: \(event)")
                if event == "minimized" || event == "closed" {
                    self?.currentChatViewController = nil
                }
                self?.sendEventToFlutter(event)
            })
        self.currentChatViewController = containerVC

        containerVC.modalPresentationStyle = .fullScreen
        os_log("[SalesforceMessagingManager] present chat: Presenting chat UI")
        viewController.present(containerVC, animated: true)
    }

    /// Closes the current conversation explicitly
    /// When closed, no new messages can be sent to this conversation
    func closeConversation(completion: ((Error?) -> Void)? = nil) {
        os_log("[SalesforceMessagingManager] close conversation: start")
        guard let conversationClient = conversationClient else {
            os_log("[SalesforceMessagingManager] close conversation: fail: no conversation client")
            completion?(SalesforceMessagingError.chatNotInitialized)
            return
        }

        if let presentedChat = currentChatViewController {
            presentedChat.dismiss(animated: true) {
                self.currentChatViewController = nil
                conversationClient.endSession { error in
                    if let error = error {
                        os_log("[SalesforceMessagingManager] close conversation: end session: fail: \(error.localizedDescription)")
                        self.clearConversation(deletePersistedConversationId: false)
                        completion?(error)
                        return
                    }
                }
                self.clearConversation(deletePersistedConversationId: false)
                self.sendEventToFlutter("session_ended")
                os_log("[SalesforceMessagingManager] close conversation: completed")
                completion?(nil)
            }
        } else {
            os_log("[SalesforceMessagingManager] close conversation: fail: no controller")
            completion?(SalesforceMessagingError.chatNotInitialized)
        }
    }

    /// Minimizes/dismisses the active chat UI without ending the conversation.
    func minimizeChat() {
        currentChatViewController?.dismiss(animated: true) {
            self.currentChatViewController = nil
        }
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

    func sendMessageFromFooter(message: String, completion: @escaping (Bool) -> Void) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty, let conversationClient = conversationClient else {
            completion(false)
            return
        }

        DispatchQueue.main.async {
            var didComplete = false
            var didSend = false

            func completeOnce(_ success: Bool) {
                guard !didComplete else { return }
                didComplete = true
                let completeBlock = {
                    if success {
                        self.hasUserSentMessageInActiveSession = true
                    }
                    completion(success)
                }
                if Thread.isMainThread {
                    completeBlock()
                } else {
                    DispatchQueue.main.async(execute: completeBlock)
                }
            }

            func sendOnce() {
                guard !didSend else { return }
                didSend = true
                let sendBlock = {
                    conversationClient.send(message: trimmedMessage)
                }
                if Thread.isMainThread {
                    sendBlock()
                } else {
                    DispatchQueue.main.async(execute: sendBlock)
                }
            }

            // Safety fallback: never block message send if conversation fetch is delayed.
            let sendFallbackWorkItem = DispatchWorkItem {
                sendOnce()
                completeOnce(true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: sendFallbackWorkItem)

            conversationClient.conversation { [weak self] conversation, _ in
                guard let self = self else {
                    completeOnce(false)
                    return
                }

                if let conversation = conversation {
                    os_log("[SalesforceMessagingManager] sendMessage : got conversation")
                    self.submitHiddenPreChatDataIfNeeded(
                        conversation: conversation,
                        createConversationOnSubmit: true)
                }

                sendFallbackWorkItem.cancel()
                sendOnce()
                completeOnce(true)
            }
        }
    }

    func resolveFooterHintState(completion: @escaping (Bool) -> Void) {
        // Only show "Type your message" if user has sent a message in this session.
        // Ignore conversation history from previous sessions.
        completion(hasUserSentMessageInActiveSession)
    }

    private class ChatContainerViewController: UIViewController, UITextFieldDelegate {
        private let contentController: UIViewController
        private let assistantTitle: String?
        private let assistantTooltipMessage: String?
        private let maxMessageLength = 4000
        private let headerHeight: CGFloat = 56
        private let footerHeight: CGFloat = 95
        private let topSpacing: CGFloat = 0
        private let headerColor = UIColor(
            red: 18 / 255,
            green: 52 / 255,
            blue: 84 / 255,
            alpha: 1.0
        )
        private let footerDividerColor = UIColor(
            red: 218 / 255,
            green: 225 / 255,
            blue: 229 / 255,
            alpha: 1.0
        )
        private let inputTextColor = UIColor(
            red: 31 / 255,
            green: 42 / 255,
            blue: 51 / 255,
            alpha: 1.0
        )
        private let hintTextColor = UIColor(
            red: 141 / 255,
            green: 153 / 255,
            blue: 161 / 255,
            alpha: 1.0
        )
        private let enabledSendColor = UIColor(
            red: 0 / 255,
            green: 121 / 255,
            blue: 194 / 255,
            alpha: 1.0
        )
        private let disabledSendColor = UIColor(
            red: 204 / 255,
            green: 204 / 255,
            blue: 204 / 255,
            alpha: 1.0
        )
        private let disabledChevronColor = UIColor(
            red: 153 / 255,
            green: 153 / 255,
            blue: 153 / 255,
            alpha: 1.0
        )

        private var eventCallback: ((String) -> Void)?
        private var footerView: UIView?
        private var messageInput: UITextField?
        private var sendButton: UIButton?
        private var footerBottomConstraint: NSLayoutConstraint?
        private var assistantHeaderContainer: UIStackView?
        private var assistantTooltipOverlay: UIControl?

        private lazy var enabledSendImage: UIImage = makeSendButtonImage(
            backgroundColor: enabledSendColor,
            chevronColor: .white
        )
        private lazy var disabledSendImage: UIImage = makeSendButtonImage(
            backgroundColor: disabledSendColor,
            chevronColor: disabledChevronColor
        )

        override var preferredStatusBarStyle: UIStatusBarStyle {
            return .lightContent
        }

        private let sheetView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = .white
            view.layer.cornerRadius = 0
            view.clipsToBounds = true
            return view
        }()

        init(
            contentController: UIViewController,
            assistantTitle: String? = nil,
            assistantTooltipMessage: String? = nil,
            eventCallback: ((String) -> Void)? = nil
        ) {
            self.contentController = contentController
            self.assistantTitle = assistantTitle
            self.assistantTooltipMessage = assistantTooltipMessage
            self.eventCallback = eventCallback
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = headerColor
            setNeedsStatusBarAppearanceUpdate()
            setupSheetView()
            setupHeader()
            setupFooter()
            setupContentController()
            registerForKeyboardNotifications()
            SalesforceMessagingManager.shared.setAssistantHeaderStateCallback {
                [weak self] showAssistantTitle in
                self?.updateAssistantHeader(showAssistantTitle: showAssistantTitle)
            }
            SalesforceMessagingManager.shared.resolveAssistantHeaderState {
                [weak self] showAssistantTitle in
                self?.updateAssistantHeader(showAssistantTitle: showAssistantTitle)
            }
            SalesforceMessagingManager.shared.resolveFooterHintState { [weak self] hasHistory in
                self?.updateHint(hasConversationHistory: hasHistory)
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
            SalesforceMessagingManager.shared.setAssistantHeaderStateCallback(nil)
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
            headerView.backgroundColor = headerColor

            // Create logo view with New York Life icon
            let logoImageView = UIImageView()
            logoImageView.translatesAutoresizingMaskIntoConstraints = false
            logoImageView.contentMode = .scaleAspectFit
            logoImageView.image = UIImage(named: "nyl_logo") ?? UIImage(systemName: "square.fill")
            logoImageView.tintColor = .white

            let assistantTitleLabel = UILabel()
            assistantTitleLabel.translatesAutoresizingMaskIntoConstraints = false
            assistantTitleLabel.text = assistantTitle?.isEmpty == false ? assistantTitle : nil
            assistantTitleLabel.textColor = .white
            assistantTitleLabel.font = .systemFont(ofSize: 16, weight: .medium)
            assistantTitleLabel.numberOfLines = 1

            let assistantInfoButton = UIButton(type: .system)
            assistantInfoButton.translatesAutoresizingMaskIntoConstraints = false
            assistantInfoButton.tintColor = .white
            assistantInfoButton.setImage(UIImage(named: "icn_info"), for: .normal)
            assistantInfoButton.addTarget(
                self, action: #selector(toggleAssistantTooltip(_:)), for: .touchUpInside)
            assistantInfoButton.accessibilityLabel = assistantTitleLabel.text

            let assistantHeaderContainer = UIStackView(arrangedSubviews: [
                assistantTitleLabel, assistantInfoButton,
            ])
            assistantHeaderContainer.translatesAutoresizingMaskIntoConstraints = false
            assistantHeaderContainer.axis = .horizontal
            assistantHeaderContainer.alignment = .center
            assistantHeaderContainer.spacing = 4
            assistantHeaderContainer.isHidden = true

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
            closeButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)

            // Create spacer between buttons
            let buttonStack = UIStackView(arrangedSubviews: [minimizeButton, closeButton])
            buttonStack.translatesAutoresizingMaskIntoConstraints = false
            buttonStack.axis = .horizontal
            buttonStack.spacing = 16
            buttonStack.distribution = .equalSpacing

            sheetView.addSubview(headerView)
            headerView.addSubview(logoImageView)
            headerView.addSubview(assistantHeaderContainer)
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

                assistantHeaderContainer.centerYAnchor.constraint(
                    equalTo: headerView.centerYAnchor),
                assistantHeaderContainer.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
                assistantHeaderContainer.leadingAnchor.constraint(
                    greaterThanOrEqualTo: logoImageView.trailingAnchor, constant: 16),
                assistantHeaderContainer.trailingAnchor.constraint(
                    lessThanOrEqualTo: buttonStack.leadingAnchor, constant: -12),

                assistantInfoButton.widthAnchor.constraint(equalToConstant: 20),
                assistantInfoButton.heightAnchor.constraint(equalToConstant: 20),

                minimizeButton.widthAnchor.constraint(equalToConstant: 24),
                minimizeButton.heightAnchor.constraint(equalToConstant: 24),

                closeButton.widthAnchor.constraint(equalToConstant: 24),
                closeButton.heightAnchor.constraint(equalToConstant: 24),

                buttonStack.trailingAnchor.constraint(
                    equalTo: headerView.trailingAnchor, constant: -12),
                buttonStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            ])

            self.assistantHeaderContainer = assistantHeaderContainer
        }

        @objc private func buttonTapped(_ sender: UIButton) {
            if sender.tag == 1 {
                // Minimize button (chevron.down)
                eventCallback?("minimized")
                print("Minimize button tapped - sending minimized event")
                dismiss(animated: true, completion: nil)
            } else if sender.tag == 2 {
                SalesforceMessagingManager.shared.closeConversation { error in
                    if let error = error {
                        print(
                            "Close button tapped - failed to close conversation: \(error.localizedDescription)"
                        )
                        self.eventCallback?("closed")
                        self.dismiss(animated: true, completion: nil)
                        return
                    }
                    print("Close button tapped - conversation closed")
                }
            }
        }

        private func updateAssistantHeader(showAssistantTitle: Bool) {
            DispatchQueue.main.async {
                self.assistantHeaderContainer?.isHidden = !showAssistantTitle
                if !showAssistantTitle {
                    self.hideAssistantTooltip()
                }
            }
        }

        @objc private func toggleAssistantTooltip(_ sender: UIButton) {
            guard
                let assistantTooltipMessage = assistantTooltipMessage?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ), !assistantTooltipMessage.isEmpty
            else {
                return
            }

            if assistantTooltipOverlay != nil {
                hideAssistantTooltip()
                return
            }

            showAssistantTooltip(anchorView: sender, message: assistantTooltipMessage)
        }

        private func showAssistantTooltip(anchorView: UIView, message: String) {
            let anchorFrame = anchorView.convert(anchorView.bounds, to: view)
            let tooltipTop = anchorFrame.maxY + 12

            let overlay = UIControl()
            overlay.translatesAutoresizingMaskIntoConstraints = false
            overlay.backgroundColor = .clear
            overlay.addTarget(self, action: #selector(handleTooltipOverlayTap), for: .touchUpInside)

            let tooltipView = UIView()
            tooltipView.translatesAutoresizingMaskIntoConstraints = false
            tooltipView.backgroundColor = .white
            tooltipView.layer.cornerRadius = 8
            tooltipView.layer.borderWidth = 1
            tooltipView.layer.borderColor = footerDividerColor.cgColor
            tooltipView.layer.shadowColor = UIColor.black.cgColor
            tooltipView.layer.shadowOpacity = 0.15
            tooltipView.layer.shadowRadius = 12
            tooltipView.layer.shadowOffset = CGSize(width: 0, height: 6)

            let titleLabel = UILabel()
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.attributedText = buildTooltipAttributedText(from: message)
            titleLabel.textColor = inputTextColor
            titleLabel.font = .systemFont(ofSize: 14)
            titleLabel.numberOfLines = 0

            view.addSubview(overlay)
            overlay.addSubview(tooltipView)
            tooltipView.addSubview(titleLabel)

            NSLayoutConstraint.activate([
                overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                overlay.topAnchor.constraint(equalTo: view.topAnchor),
                overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

                tooltipView.topAnchor.constraint(equalTo: overlay.topAnchor, constant: tooltipTop),
                tooltipView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                tooltipView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

                titleLabel.topAnchor.constraint(equalTo: tooltipView.topAnchor, constant: 14),
                titleLabel.leadingAnchor.constraint(
                    equalTo: tooltipView.leadingAnchor, constant: 16),
                titleLabel.trailingAnchor.constraint(
                    equalTo: tooltipView.trailingAnchor, constant: -16),
                titleLabel.bottomAnchor.constraint(equalTo: tooltipView.bottomAnchor, constant: -16),
            ])

            assistantTooltipOverlay = overlay
        }

        private func buildTooltipAttributedText(from message: String) -> NSAttributedString {
            let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4

            let fullAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: inputTextColor,
                .paragraphStyle: paragraphStyle,
            ]

            guard !normalized.isEmpty else {
                return NSAttributedString(string: "", attributes: fullAttributes)
            }

            guard let firstSentenceRange = normalized.range(of: #"^.*?[.]"#, options: .regularExpression)
            else {
                return NSAttributedString(
                    string: normalized,
                    attributes: [
                        .font: UIFont.boldSystemFont(ofSize: 14),
                        .foregroundColor: inputTextColor,
                        .paragraphStyle: paragraphStyle,
                    ])
            }

            let firstSentence = String(normalized[firstSentenceRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let remainder = String(normalized[firstSentenceRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

            let attributed = NSMutableAttributedString(
                string: firstSentence,
                attributes: [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: inputTextColor,
                    .paragraphStyle: paragraphStyle,
                ])

            if !remainder.isEmpty {
                attributed.append(NSAttributedString(string: "\n", attributes: fullAttributes))
                attributed.append(NSAttributedString(string: remainder, attributes: fullAttributes))
            }

            return attributed
        }

        @objc private func handleTooltipOverlayTap() {
            hideAssistantTooltip()
        }

        private func hideAssistantTooltip() {
            assistantTooltipOverlay?.removeFromSuperview()
            assistantTooltipOverlay = nil
        }

        private func setupFooter() {
            let footerView = UIView()
            footerView.translatesAutoresizingMaskIntoConstraints = false
            footerView.backgroundColor = .white

            let dividerView = UIView()
            dividerView.translatesAutoresizingMaskIntoConstraints = false
            dividerView.backgroundColor = footerDividerColor

            let footerContentView = UIView()
            footerContentView.translatesAutoresizingMaskIntoConstraints = false

            let textField = UITextField()
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.borderStyle = .none
            textField.backgroundColor = .clear
            textField.textColor = inputTextColor
            textField.font = UIFont.systemFont(ofSize: 16)
            textField.attributedPlaceholder = NSAttributedString(
                string: "Start a new chat",
                attributes: [.foregroundColor: hintTextColor]
            )
            textField.returnKeyType = .send
            textField.delegate = self
            textField.addTarget(
                self, action: #selector(messageInputDidChange), for: .editingChanged)

            let sendButton = UIButton(type: .custom)
            sendButton.translatesAutoresizingMaskIntoConstraints = false
            sendButton.setImage(enabledSendImage, for: .normal)
            sendButton.setImage(disabledSendImage, for: .disabled)
            sendButton.adjustsImageWhenDisabled = false
            sendButton.isEnabled = false
            sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
            sendButton.accessibilityLabel = "Send message"

            sheetView.addSubview(footerView)
            footerView.addSubview(dividerView)
            footerView.addSubview(footerContentView)
            footerContentView.addSubview(textField)
            footerContentView.addSubview(sendButton)

            let footerBottomConstraint = footerView.bottomAnchor.constraint(
                equalTo: sheetView.bottomAnchor)

            NSLayoutConstraint.activate([
                footerView.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
                footerView.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
                footerBottomConstraint,
                footerView.heightAnchor.constraint(equalToConstant: footerHeight),

                dividerView.topAnchor.constraint(equalTo: footerView.topAnchor),
                dividerView.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
                dividerView.trailingAnchor.constraint(equalTo: footerView.trailingAnchor),
                dividerView.heightAnchor.constraint(equalToConstant: 2),

                footerContentView.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
                footerContentView.trailingAnchor.constraint(equalTo: footerView.trailingAnchor),
                footerContentView.topAnchor.constraint(
                    equalTo: dividerView.bottomAnchor, constant: 16),
                footerContentView.bottomAnchor.constraint(equalTo: footerView.bottomAnchor),

                textField.leadingAnchor.constraint(
                    equalTo: footerContentView.leadingAnchor, constant: 32),
                textField.topAnchor.constraint(equalTo: footerContentView.topAnchor),
                textField.trailingAnchor.constraint(
                    equalTo: sendButton.leadingAnchor, constant: -16),

                sendButton.trailingAnchor.constraint(
                    equalTo: footerContentView.trailingAnchor, constant: -16),
                sendButton.topAnchor.constraint(equalTo: footerContentView.topAnchor),
                sendButton.widthAnchor.constraint(equalToConstant: 40),
                sendButton.heightAnchor.constraint(equalToConstant: 40),
            ])

            self.footerView = footerView
            self.messageInput = textField
            self.sendButton = sendButton
            self.footerBottomConstraint = footerBottomConstraint
            updateSendState()
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

            if let footerView = footerView {
                sheetView.bringSubviewToFront(footerView)
            }
        }

        private func updateHint(hasConversationHistory: Bool) {
            guard let messageInput = messageInput else { return }
            if let text = messageInput.text,
                !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                return
            }

            let hint = hasConversationHistory ? "Type your message" : "Start a new chat"
            messageInput.attributedPlaceholder = NSAttributedString(
                string: hint,
                attributes: [.foregroundColor: hintTextColor]
            )
        }

        private func updateSendState() {
            guard let messageInput = messageInput, let sendButton = sendButton else { return }
            let hasText =
                !(messageInput.text?.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty ?? true)
            sendButton.isEnabled = hasText
        }

        private func registerForKeyboardNotifications() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleKeyboardNotification(_:)),
                name: UIResponder.keyboardWillChangeFrameNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleKeyboardNotification(_:)),
                name: UIResponder.keyboardWillHideNotification,
                object: nil
            )
        }

        @objc private func handleKeyboardNotification(_ notification: Notification) {
            guard
                let userInfo = notification.userInfo,
                let keyboardFrameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey]
                    as? NSValue,
                let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey]
                    as? Double,
                let curveRawValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey]
                    as? UInt,
                let footerBottomConstraint = footerBottomConstraint
            else {
                return
            }

            let keyboardFrameInScreen = keyboardFrameValue.cgRectValue
            let keyboardFrameInView = view.convert(keyboardFrameInScreen, from: nil)
            let overlapHeight = max(0, view.bounds.maxY - keyboardFrameInView.minY)
            let safeAreaBottomInset = view.safeAreaInsets.bottom
            let bottomOffset = max(0, overlapHeight - safeAreaBottomInset)

            footerBottomConstraint.constant = -bottomOffset

            let animationOptions = UIView.AnimationOptions(rawValue: curveRawValue << 16)
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: [animationOptions, .beginFromCurrentState]
            ) {
                self.view.layoutIfNeeded()
            }
        }

        @objc private func messageInputDidChange() {
            sanitizeCurrentMessageInput()
            updateSendState()
        }

        @objc private func sendButtonTapped() {
            sendMessage()
        }

        private func sendMessage() {
            guard let messageInput = messageInput else { return }
            sanitizeCurrentMessageInput()
            let message = messageInput.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !message.isEmpty else { return }

            sendButton?.isEnabled = false
            SalesforceMessagingManager.shared.sendMessageFromFooter(message: message) {
                [weak self] success in
                guard let self = self else { return }
                if success {
                    self.messageInput?.text = ""
                    self.updateHint(hasConversationHistory: true)
                }
                self.updateSendState()
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            sendMessage()
            return false
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let currentText = textField.text ?? ""
            guard let textRange = Range(range, in: currentText) else { return false }

            let sanitizedReplacement = sanitizeMessage(string)
            let updatedText = currentText.replacingCharacters(in: textRange, with: sanitizedReplacement)
            let limitedText = String(updatedText.prefix(maxMessageLength))

            if limitedText == currentText.replacingCharacters(in: textRange, with: string) {
                return true
            }

            textField.text = limitedText
            updateSendState()
            return false
        }

        private func sanitizeCurrentMessageInput() {
            guard let messageInput = messageInput else { return }
            let sanitizedText = String(sanitizeMessage(messageInput.text ?? "").prefix(maxMessageLength))
            if sanitizedText != messageInput.text {
                messageInput.text = sanitizedText
            }
        }

        private func sanitizeMessage(_ text: String) -> String {
            String(text.unicodeScalars.filter { !isEmojiScalar($0) })
        }

        private func isEmojiScalar(_ scalar: UnicodeScalar) -> Bool {
            switch scalar.value {
            case 0x200D, 0xFE0F, 0x20E3,
                0x1F1E6...0x1F1FF,
                0x1F300...0x1FAFF,
                0x2600...0x27BF:
                return true
            default:
                return false
            }
        }

        private func makeSendButtonImage(backgroundColor: UIColor, chevronColor: UIColor) -> UIImage
        {
            let size = CGSize(width: 40, height: 40)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                let rect = CGRect(origin: .zero, size: size)
                let backgroundPath = UIBezierPath(roundedRect: rect, cornerRadius: 4)
                backgroundColor.setFill()
                backgroundPath.fill()

                let chevronPath = UIBezierPath()
                chevronPath.move(to: CGPoint(x: 16.729, y: 29.2407))
                chevronPath.addLine(to: CGPoint(x: 25.3683, y: 20.0123))
                chevronPath.addLine(to: CGPoint(x: 16.7277, y: 10.7599))
                chevronPath.lineCapStyle = .round
                chevronPath.lineJoinStyle = .round
                chevronPath.lineWidth = 2
                chevronColor.setStroke()
                chevronPath.stroke()
                context.cgContext.flush()
            }
        }
    }

    /// Clears in-memory chat state; caller controls whether persisted conversation ID is removed.
    func clearConversation(deletePersistedConversationId: Bool = true) {
        os_log("[SalesforceMessagingManager] clear conversation: start")
        stopUnreadObserver()
        lastUnreadCount = nil
        shouldShowAssistantHeaderTitle = true
        chatAssistantTitle = nil
        chatAssistantTooltipMessage = nil
        sendAssistantHeaderState(true)
        coreClient?.stop()
        if deletePersistedConversationId {
            deleteFromKeychain(key: conversationIdKey)
        }
        conversationId = nil
        config = nil
        coreClient = nil
        conversationClient = nil
        userVerificationDelegate = nil
        hiddenPreChatDelegate = nil
        latestHiddenPreChatValues = nil
        didSubmitPreChatForCurrentSession = false
        hasUserSentMessageInActiveSession = false
        currentChatViewController = nil
        os_log("[SalesforceMessagingManager] clear conversation: completed")
    }

    /// Returns the current conversation ID if one exists
    func getCurrentConversationId() -> UUID? {
        return conversationId
    }

    private func shouldShowAssistantHeaderTitle(for conversation: Conversation) -> Bool {
        let participants = conversation.activeParticipants.isEmpty ? conversation.participants : conversation.activeParticipants

        let hasHumanOrQueuePresence = participants.contains { participant in
            return !participant.isLocal && (participant.role == .agent || participant.role == .supervisor || participant.role == .router)
        }

        return !hasHumanOrQueuePresence
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

    private let authTokenProvider: SalesforceAuthTokenProvider?

    init(authTokenProvider: SalesforceAuthTokenProvider?) {
        self.authTokenProvider = authTokenProvider
    }

    func core(
        _ core: CoreClient,
        userVerificationChallengeWith reason: ChallengeReason,
        completionHandler completion: @escaping UserVerificationChallengeCompletion
    ) {

        guard let authTokenProvider = authTokenProvider else {
            completion(nil)
            return
        }

        switch reason {
        case .initial:
            authTokenProvider.onGetToken { [weak self] token in
                self?.handleTokenResponse(token, completion: completion, reason: "initial")
            }

        case .refresh:
            authTokenProvider.onRefreshToken { [weak self] token in
                self?.handleTokenResponse(token, completion: completion, reason: "refresh")
            }

        case .expired:
            authTokenProvider.onRefreshToken { [weak self] token in
                self?.handleTokenResponse(token, completion: completion, reason: "expired")
            }

        case .malformed:
            authTokenProvider.onGetToken { [weak self] token in
                self?.handleTokenResponse(token, completion: completion, reason: "malformed")
            }

        @unknown default:
            completion(nil)
        }
    }

    private func handleTokenResponse(
        _ token: String?,
        completion: @escaping UserVerificationChallengeCompletion,
        reason: String
    ) {
        if let token = token, !token.isEmpty {
            completion(UserVerification(customerIdentityToken: token, type: .JWT))
        } else {
            // Still complete with nil if token is empty - let SDK handle it
            completion(nil)
        }
    }
}

// MARK: - HiddenPreChatDelegate

class HiddenPrechatDelegateImplementation: HiddenPreChatDelegate {

    private var clientId: String
    private var policyNumber: String
    private var reason: String
    private var timeZoneOffset: String

    init(clientId: String, policyNumber: String, reason: String, timeZoneOffset: String) {
        self.clientId = clientId
        self.policyNumber = policyNumber
        self.reason = reason
        self.timeZoneOffset = timeZoneOffset
    }

    func core(
        _ core: CoreClient,
        conversation: Conversation,
        didRequestPrechatValues hiddenPreChatFields: [HiddenPreChatField],
        completionHandler: HiddenPreChatValueCompletion
    ) {

        print(
            "[HiddenPrechatDelegate] Requested hidden pre-chat fields count: \(hiddenPreChatFields.count)"
        )

        // Fill in all the hidden pre-chat fields
        for preChatField in hiddenPreChatFields {
            print("[HiddenPrechatDelegate] Field requested: \(preChatField.name)")
            switch preChatField.name {
            case "Client_Id": preChatField.value = clientId
            case "Policy_Number": preChatField.value = policyNumber
            case "Reason": preChatField.value = reason
            case "P_TimeZoneOffset": preChatField.value = timeZoneOffset
            default: print("Unknown hidden prechat field: \(preChatField.name)")
            }
        }

        completionHandler(hiddenPreChatFields)
    }
}

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
