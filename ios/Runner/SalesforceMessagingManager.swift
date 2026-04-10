import Foundation
import SMIClientUI
import SMIClientCore
import Security
import UIKit

/// Manager class for Salesforce In-App Messaging SDK
/// Handles configuration and opening of chat conversations
class SalesforceMessagingManager {

    static let shared = SalesforceMessagingManager()

    private var config: UIConfiguration?
    private var conversationId: UUID?

    private let configFileName = "salesforce_config"
    private let conversationIdKey = "com.salesforce.messaging.conversationId"

    private var currentChatViewController: UIViewController?

    private init() {}

    // MARK: - Open Chat Methods

    /// Opens the Salesforce chat conversation using config file
    /// Based on: Step 2 Option 1 - Configure Using the Config File
    /// - Parameters:
    ///   - viewController: The view controller to present the chat from
    ///   - usePersistedConversation: If true, uses the same conversation ID across app restarts
    func openChatWithConfigFile(from viewController: UIViewController, usePersistedConversation: Bool = true) throws {
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

        // Add the View to Your App (per Step 3)
        // Using InterfaceViewController for Swift
        let chatVC = InterfaceViewController(uiConfig)
        viewController.present(chatVC, animated: true, completion: nil)
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
        self.config = uiConfig

        // Add the View to Your App (per Step 3)
        // Using InterfaceViewController for Swift
        let chatVC = InterfaceViewController(uiConfig)
        viewController.present(chatVC, animated: true, completion: nil)
    }

    /// Opens the Salesforce chat modally
    /// Based on: Step 3 - ModalInterfaceViewController option
    func openChatModally(from viewController: UIViewController, usePersistedConversation: Bool = true) throws {
        guard let configPath = Bundle.main.path(forResource: configFileName, ofType: "json") else {
            throw SalesforceMessagingError.configFileNotFound
        }

        let configURL = URL(fileURLWithPath: configPath)
        let conversationID = usePersistedConversation ? getOrCreateConversationId() : UUID()
        self.conversationId = conversationID

        let uiConfig = UIConfiguration(url: configURL, conversationId: conversationID)!
        self.config = uiConfig

        // Create a ModalInterfaceViewController to present chat modally
        let chatVC = ModalInterfaceViewController(uiConfig)
        chatVC.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        viewController.present(chatVC, animated: true, completion: nil)
    }

    func openChatAsBottomSheet(from viewController: UIViewController, usePersistedConversation: Bool = true) throws {
    guard let configPath = Bundle.main.path(forResource: configFileName, ofType: "json") else {
        throw SalesforceMessagingError.configFileNotFound
    }

    let configURL = URL(fileURLWithPath: configPath)
    let conversationID = usePersistedConversation ? getOrCreateConversationId() : UUID()
    self.conversationId = conversationID

    let uiConfig = UIConfiguration(url: configURL, conversationId: conversationID)!
    self.config = uiConfig

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

    let containerVC = ChatContainerViewController(contentController: chatVC)
    self.currentChatViewController = containerVC

    containerVC.modalPresentationStyle = .overFullScreen
    viewController.present(containerVC, animated: true)
}

    /// Closes the current conversation explicitly
    /// When closed, no new messages can be sent to this conversation
    func closeConversation(completion: ((Error?) -> Void)? = nil) {
        if let presentedChat = currentChatViewController {
            presentedChat.dismiss(animated: true) {
                self.currentChatViewController = nil
                self.clearConversation()
                completion?(nil)
            }
        } else if conversationId != nil {
            clearConversation()
            completion?(nil)
        } else {
            completion?(SalesforceMessagingError.chatNotInitialized)
        }
    }

private class ChatContainerViewController: UIViewController {
    private let contentController: UIViewController
    private let headerHeight: CGFloat = 54

    private let sheetView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.layer.cornerRadius = 4
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        return view
    }()

    init(contentController: UIViewController) {
        self.contentController = contentController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0, alpha: 0.35)
        setupSheetView()
        setupHeader()
        setupContentController()
    }

    private func setupSheetView() {
        view.addSubview(sheetView)

        NSLayoutConstraint.activate([
            sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sheetView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.80)
        ])
    }

    private func setupHeader() {
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor(red: 8/255, green: 60/255, blue: 91/255, alpha: 1.0)

        let logoLabel = UILabel()
        logoLabel.translatesAutoresizingMaskIntoConstraints = false
        logoLabel.text = "New York Life"
        logoLabel.textColor = .white
        logoLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)

        let minimizeButton = UIButton(type: .system)
        minimizeButton.translatesAutoresizingMaskIntoConstraints = false
        minimizeButton.tintColor = .white
        minimizeButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        minimizeButton.addTarget(self, action: #selector(closeSheet), for: .touchUpInside)
        minimizeButton.imageView?.contentMode = .scaleAspectFit

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.tintColor = .white
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.addTarget(self, action: #selector(closeSheet), for: .touchUpInside)
        closeButton.imageView?.contentMode = .scaleAspectFit

        let buttonStack = UIStackView(arrangedSubviews: [minimizeButton, closeButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12

        sheetView.addSubview(headerView)
        headerView.addSubview(logoLabel)
        headerView.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: sheetView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: headerHeight),

            logoLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            logoLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            minimizeButton.widthAnchor.constraint(equalToConstant: 28),
            minimizeButton.heightAnchor.constraint(equalToConstant: 28),

            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),

            buttonStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -12),
            buttonStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
    }

    private func setupContentController() {
        addChild(contentController)
        contentController.view.translatesAutoresizingMaskIntoConstraints = false
        sheetView.addSubview(contentController.view)
        contentController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            contentController.view.topAnchor.constraint(equalTo: sheetView.topAnchor, constant: headerHeight),
            contentController.view.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
            contentController.view.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
            contentController.view.bottomAnchor.constraint(equalTo: sheetView.bottomAnchor)
        ])
    }

    @objc private func closeSheet() {
        dismiss(animated: true, completion: nil)
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
           let savedId = UUID(uuidString: savedIdString) {
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
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
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
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    /// Deletes a value from the Keychain
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

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
