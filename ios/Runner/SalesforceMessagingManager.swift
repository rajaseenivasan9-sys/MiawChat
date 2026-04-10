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

    let chatVC = ModalInterfaceViewController(uiConfig)
    self.currentChatViewController = chatVC  
    
    // Allow swipe to dismiss
    chatVC.isModalInPresentation = false

    // Configure as bottom sheet with 80% height
    if #available(iOS 16.0, *) {
        if let sheet = chatVC.sheetPresentationController {
            let eightyPercentDetent = UISheetPresentationController.Detent.custom { context in
                return context.maximumDetentValue * 0.80
            }
            sheet.detents = [eightyPercentDetent]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
    } else if #available(iOS 15.0, *) {
        if let sheet = chatVC.sheetPresentationController {
            sheet.detents = [.large()]  // Fallback to full screen for iOS 15
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
    } else {
        chatVC.modalPresentationStyle = .pageSheet
    }
    
    viewController.present(chatVC, animated: true)
}

    // MARK: - Conversation Management

    /// Closes the current conversation explicitly
    /// When closed, no new messages can be sent to this conversation
    func closeConversation(completion: ((Error?) -> Void)? = nil) {
        guard conversationId != nil else {
            completion?(SalesforceMessagingError.chatNotInitialized)
            return
        }

        // Clear conversation data
        clearConversation()
        completion?(nil)
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
