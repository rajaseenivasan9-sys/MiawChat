# newproject

A Flutter project with Salesforce In-App Chat integration for Android and iOS.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

## Salesforce In-App Chat Integration

This project integrates Salesforce Enhanced In-App Chat using the UI SDK for both Android and iOS platforms.

### Features

- ✅ Ready-to-use Salesforce chat UI
- ✅ Conversation persistence across app restarts
- ✅ Support for image attachments
- ✅ Pre-chat forms and bot support
- ✅ Secure conversation ID storage (Keychain on iOS, SharedPreferences on Android)

---

## Quick Start Guide (New Project Setup)

If you're setting up Salesforce In-App Chat in a **new Flutter project**, follow these steps:

### Prerequisites
- Flutter SDK installed
- Android Studio / Xcode installed
- Salesforce org with Enhanced In-App Chat deployment configured
- Config file downloaded from Salesforce (or credentials noted)

### Step-by-Step Overview

| Step | Android | iOS | Flutter |
|------|---------|-----|---------|
| 1 | Add Maven repository | Update deployment target to 15.0 | Create services folder |
| 2 | Add dependencies & dataBinding | Create Podfile with SDK | Create SalesforceMessagingService.dart |
| 3 | Add INTERNET permission | Update Info.plist permissions | Update main.dart with chat button |
| 4 | Create assets folder & config.json | Create Resources folder & config.json | - |
| 5 | Create SalesforceMessagingManager.kt | Create SalesforceMessagingManager.swift | - |
| 6 | Update MainActivity.kt | Create SalesforceMethodChannelHandler.swift | - |
| 7 | - | Update AppDelegate.swift | - |
| 8 | - | Add files to Xcode project | - |
| 9 | - | Run `pod install` | - |

### Quick Commands

```bash
# Create new Flutter project
flutter create my_salesforce_app
cd my_salesforce_app

# Create required folders
mkdir -p android/app/src/main/assets
mkdir -p ios/Runner/Resources
mkdir -p lib/services

# For iOS (on Mac)
cd ios
pod install
cd ..

# Run the app
flutter run
```

### Method Channel Name (IMPORTANT!)
The method channel name **must match** across all platforms:
```
com.example.newproject/salesforce_chat
```
Replace `newproject` with your actual project name.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        FLUTTER                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  main.dart (UI)                                      │   │
│  │         ↓                                            │   │
│  │  SalesforceMessagingService (Dart API)              │   │
│  │         ↓ Method Channel                             │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌───────────────────────────┐   ┌───────────────────────────┐
│      ANDROID (Kotlin)     │   │        iOS (Swift)        │
│  MainActivity.kt          │   │  AppDelegate.swift        │
│         ↓                 │   │         ↓                 │
│  SalesforceMessaging      │   │  SalesforceMethodChannel  │
│  Manager.kt               │   │  Handler.swift            │
│         ↓                 │   │         ↓                 │
│  Salesforce SDK           │   │  SalesforceMessaging      │
│  (UIClient, CoreClient)   │   │  Manager.swift            │
│         ↓                 │   │         ↓                 │
│  salesforce_config.json   │   │  Salesforce SDK           │
└───────────────────────────┘   │  (SMIClientUI, Core)      │
                                │         ↓                 │
                                │  salesforce_config.json   │
                                └───────────────────────────┘
```

---

## Android Setup

This section provides a complete step-by-step guide for integrating Salesforce In-App Chat on Android with Flutter.

### Prerequisites

- Android SDK 21+ (or as defined by Flutter)
- Kotlin support
- Android Studio or VS Code with Flutter

### Files Structure

```
android/
├── build.gradle.kts                    # Maven repository
├── app/
│   ├── build.gradle.kts                # Dependencies, dataBinding, packaging
│   └── src/main/
│       ├── AndroidManifest.xml         # Internet permission
│       ├── assets/
│       │   └── salesforce_config.json  # Salesforce credentials
│       └── kotlin/com/example/newproject/
│           ├── MainActivity.kt                  # Method channel handler
│           └── SalesforceMessagingManager.kt    # SDK operations
```

---

### Step 1: Add Maven Repository

**File:** `android/build.gradle.kts`

Add the Salesforce Maven repository:

```kotlin
allprojects {
    repositories {
        google()
        mavenCentral()
        // Salesforce In-App Messaging SDK
        maven {
            url = uri("https://s3.amazonaws.com/inapp.salesforce.com/public/android")
        }
    }
}
```

**Why:** Tells Gradle where to download the Salesforce SDK packages from.

---

### Step 2: Add Dependencies, DataBinding & Packaging

**File:** `android/app/build.gradle.kts`

```kotlin
android {
    namespace = "com.example.newproject"
    compileSdk = flutter.compileSdkVersion
    
    // Enable dataBinding for Salesforce In-App Messaging SDK
    buildFeatures {
        dataBinding = true
    }
    
    // ... other android configurations ...
    
    // Exclude duplicate META-INF files from dependencies
    packaging {
        resources {
            excludes += setOf(
                "META-INF/versions/9/OSGI-INF/MANIFEST.MF",
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt"
            )
        }
    }
}

dependencies {
    // Salesforce In-App Messaging UI SDK
    implementation("com.salesforce.service:messaging-inapp-ui:1.10.0")
    
    // Kotlin Coroutines for async operations
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
```

**Why:**
- `dataBinding = true` - Required by Salesforce SDK
- `packaging.excludes` - Fixes build error with duplicate META-INF files from OkHttp
- `messaging-inapp-ui` - Salesforce UI SDK (includes Core SDK)
- `kotlinx-coroutines` - Required for async `closeConversation()` call

---

### Step 3: Add Internet Permission

**File:** `android/app/src/main/AndroidManifest.xml`

Add inside `<manifest>` tag before `<application>`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Internet permission required for Salesforce In-App Messaging -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <application ...>
```

**Why:** Required for network communication with Salesforce servers.

---

### Step 4: Create Config File

**File:** `android/app/src/main/assets/salesforce_config.json`

First, create the `assets` folder inside `src/main/`, then create the JSON file:

```json
{
  "OrganizationId": "YOUR_ORG_ID",
  "DeveloperName": "YOUR_DEPLOYMENT_NAME",
  "Url": "https://YOUR_URL.salesforce-scrt.com"
}
```

**Why:** Stores Salesforce deployment credentials that the SDK reads at runtime.

---

### Step 5: Create SalesforceMessagingManager.kt

**File:** `android/app/src/main/kotlin/com/example/newproject/SalesforceMessagingManager.kt`

This class handles all Salesforce SDK operations:

```kotlin
package com.example.newproject

import android.content.Context
import com.salesforce.android.smi.core.*
import com.salesforce.android.smi.ui.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.net.URL
import java.util.UUID

class SalesforceMessagingManager(private val context: Context) {

    private var uiClient: UIClient? = null
    private var coreClient: CoreClient? = null
    private var conversationId: UUID? = null
    
    // Coroutine scope for async operations
    private val supervisorJob = SupervisorJob()
    private val scope = CoroutineScope(Dispatchers.Main + supervisorJob)

    companion object {
        private const val CONFIG_FILE_NAME = "salesforce_config.json"
        private const val PREF_CONVERSATION_ID = "salesforce_conversation_id"
        private const val PREFS_NAME = "salesforce_messaging_prefs"
    }

    /**
     * Opens the Salesforce chat conversation using config file
     */
    fun openChatWithConfigFile(usePersistedConversation: Boolean = true) {
        // Create a Core configuration object from config file
        val coreConfig = CoreConfiguration.fromFile(context, CONFIG_FILE_NAME)

        // Get or generate conversation ID
        val conversationID = if (usePersistedConversation) {
            getOrCreateConversationId()
        } else {
            UUID.randomUUID()
        }
        this.conversationId = conversationID

        // Create a UI configuration object
        val config = UIConfiguration(coreConfig, conversationID)

        // Create CoreClient for conversation management
        coreClient = CoreClient.Factory.create(context, coreConfig)

        // Create UIClient and open conversation
        uiClient = UIClient.Factory.create(config)
        uiClient?.openConversationActivity(context)
    }

    /**
     * Opens the Salesforce chat conversation using manual configuration
     */
    fun openChatManual(
        usePersistedConversation: Boolean = true,
        serviceApiUrl: String,
        orgId: String,
        deploymentName: String
    ) {
        val url = URL(serviceApiUrl)
        val coreConfig = CoreConfiguration(url, orgId, deploymentName)

        val conversationID = if (usePersistedConversation) {
            getOrCreateConversationId()
        } else {
            UUID.randomUUID()
        }
        this.conversationId = conversationID

        val config = UIConfiguration(coreConfig, conversationID)
        coreClient = CoreClient.Factory.create(context, coreConfig)
        uiClient = UIClient.Factory.create(config)
        uiClient?.openConversationActivity(context)
    }

    /**
     * Closes the current conversation using coroutines
     */
    fun closeConversation(): Boolean {
        return try {
            conversationId?.let { id ->
                scope.launch {
                    try {
                        coreClient?.closeConversation(id)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
                clearConversation()
                true
            } ?: false
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * Starts a new conversation
     */
    fun startNewConversation() {
        closeConversation()
        openChatWithConfigFile(usePersistedConversation = false)
    }

    /**
     * Clears the stored conversation ID
     */
    fun clearConversation() {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove(PREF_CONVERSATION_ID).apply()
        conversationId = null
    }

    /**
     * Returns the current conversation ID
     */
    fun getCurrentConversationId(): UUID? = conversationId

    /**
     * Gets existing or creates new conversation ID (stored in SharedPreferences)
     */
    private fun getOrCreateConversationId(): UUID {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val savedId = prefs.getString(PREF_CONVERSATION_ID, null)
        
        return if (savedId != null) {
            try {
                UUID.fromString(savedId)
            } catch (e: IllegalArgumentException) {
                createAndSaveNewConversationId(prefs)
            }
        } else {
            createAndSaveNewConversationId(prefs)
        }
    }

    private fun createAndSaveNewConversationId(prefs: android.content.SharedPreferences): UUID {
        val newId = UUID.randomUUID()
        prefs.edit().putString(PREF_CONVERSATION_ID, newId.toString()).apply()
        return newId
    }
}
```

**Why:**
- `openChatWithConfigFile()` - Reads config from JSON file and opens chat UI
- `openChatManual()` - Opens chat with manually provided credentials
- `closeConversation()` - Uses coroutines because SDK method is a suspend function
- `getOrCreateConversationId()` - Stores conversation ID in SharedPreferences for persistence
- UUID v4 - Uses random UUID for conversation IDs (per Salesforce guidelines)

---

### Step 6: Update MainActivity.kt

**File:** `android/app/src/main/kotlin/com/example/newproject/MainActivity.kt`

This sets up the Flutter method channel:

```kotlin
package com.example.newproject

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    companion object {
        private const val CHANNEL = "com.example.newproject/salesforce_chat"
    }
    
    private lateinit var salesforceManager: SalesforceMessagingManager
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize Salesforce Messaging Manager
        salesforceManager = SalesforceMessagingManager(this)
        
        // Set up method channel for Flutter communication
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openChat" -> {
                    try {
                        val useConfigFile = call.argument<Boolean>("useConfigFile") ?: true
                        val persistConversation = call.argument<Boolean>("persistConversation") ?: true
                        
                        if (useConfigFile) {
                            salesforceManager.openChatWithConfigFile(persistConversation)
                        } else {
                            val serviceApiUrl = call.argument<String>("serviceApiUrl")
                            val orgId = call.argument<String>("orgId")
                            val deploymentName = call.argument<String>("deploymentName")
                            
                            if (serviceApiUrl != null && orgId != null && deploymentName != null) {
                                salesforceManager.openChatManual(
                                    persistConversation,
                                    serviceApiUrl,
                                    orgId,
                                    deploymentName
                                )
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CHAT_ERROR", e.message, null)
                    }
                }
                "clearConversation" -> {
                    salesforceManager.clearConversation()
                    result.success(true)
                }
                "closeConversation" -> {
                    val success = salesforceManager.closeConversation()
                    result.success(success)
                }
                "startNewConversation" -> {
                    salesforceManager.startNewConversation()
                    result.success(true)
                }
                "getConversationId" -> {
                    val conversationId = salesforceManager.getCurrentConversationId()
                    result.success(conversationId?.toString())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
```

**Why:**
- Creates Method Channel for Flutter ↔ Android communication
- Handles all method calls from Flutter
- Initializes `SalesforceMessagingManager`
- Returns results/errors back to Flutter

---

### Android Integration Summary

| Step | File | Purpose |
|------|------|---------|
| 1 | `build.gradle.kts` (project) | Add Salesforce Maven repository |
| 2 | `build.gradle.kts` (app) | Add SDK dependency, dataBinding, packaging |
| 3 | `AndroidManifest.xml` | Add INTERNET permission |
| 4 | `assets/salesforce_config.json` | Salesforce credentials |
| 5 | `SalesforceMessagingManager.kt` | SDK operations, conversation management |
| 6 | `MainActivity.kt` | Flutter method channel handler |

---

### Android Method Channel

The method channel name must match between Flutter and Android:

```
Channel Name: "com.example.newproject/salesforce_chat"
```

**Methods:**

| Method | Parameters | Description |
|--------|------------|-------------|
| `openChat` | `useConfigFile`, `persistConversation`, `serviceApiUrl`*, `orgId`*, `deploymentName`* | Opens chat UI |
| `closeConversation` | none | Closes current conversation |
| `clearConversation` | none | Clears stored conversation ID |
| `startNewConversation` | none | Starts fresh conversation |
| `getConversationId` | none | Returns current conversation ID |

*Required only when `useConfigFile` is false

---

## iOS Setup

This section provides a complete step-by-step guide for integrating Salesforce In-App Chat on iOS with Flutter.

### Prerequisites

- iOS 15.0+ (required for UI SDK)
- Xcode 12.3+
- CocoaPods installed
- Mac computer (required for iOS development)

### Files Structure

```
ios/
├── Podfile                                    # CocoaPods dependencies
└── Runner/
    ├── AppDelegate.swift                      # Method channel setup (minimal)
    ├── SalesforceMessagingManager.swift       # SDK operations
    ├── SalesforceMethodChannelHandler.swift   # Flutter ↔ iOS communication
    ├── Info.plist                             # Permissions
    └── Resources/
        └── salesforce_config.json             # Salesforce credentials
```

---

### Step 1: Update iOS Deployment Target

**File:** `ios/Runner.xcodeproj/project.pbxproj`

Find all instances of `IPHONEOS_DEPLOYMENT_TARGET` and change from `13.0` (or lower) to `15.0`:

```
IPHONEOS_DEPLOYMENT_TARGET = 15.0;
```

**Why:** The Salesforce UI SDK requires iOS 15.0 or higher.

---

### Step 2: Create Podfile with Salesforce SDK

**File:** `ios/Podfile`

```ruby
# Uncomment this line to define a global platform for your project
platform :ios, '15.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  
  # Salesforce Enhanced In-App Chat UI and Core SDK
  pod 'Messaging-InApp-UI'
end

target 'RunnerTests' do
  inherit! :search_paths
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
```

**Why:** 
- Adds Salesforce `Messaging-InApp-UI` pod (includes both UI and Core SDK)
- Sets iOS deployment target to 15.0 for all pods
- Configures Flutter pod helper

---

### Step 3: Update Info.plist with Required Permissions

**File:** `ios/Runner/Info.plist`

Add these entries inside the `<dict>` tag:

```xml
<!-- Salesforce In-App Chat: Camera access for sending image attachments -->
<key>NSCameraUsageDescription</key>
<string>Used when sending an image to a rep.</string>

<!-- Salesforce In-App Chat: Photo library access for sending image attachments -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Used when sending an image to a rep.</string>

<!-- Salesforce In-App Chat: Access to files for sharing with rep -->
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
<key>UIFileSharingEnabled</key>
<true/>
```

**Why:**
- `NSCameraUsageDescription` - Required when user wants to take a photo to send
- `NSPhotoLibraryUsageDescription` - Required when user wants to select an image
- `LSSupportsOpeningDocumentsInPlace` & `UIFileSharingEnabled` - Required for file attachments

---

### Step 4: Create Config File

**File:** `ios/Runner/Resources/salesforce_config.json`

First, create the `Resources` folder inside `Runner`, then create the JSON file:

```json
{
  "OrganizationId": "YOUR_ORG_ID",
  "DeveloperName": "YOUR_DEPLOYMENT_NAME",
  "Url": "https://YOUR_URL.salesforce-scrt.com"
}
```

**Important:** This file must be added to Xcode project and included in "Copy Bundle Resources" build phase.

**Why:** Stores Salesforce deployment credentials that the SDK reads at runtime.

---

### Step 5: Create SalesforceMessagingManager.swift

**File:** `ios/Runner/SalesforceMessagingManager.swift`

This class handles all Salesforce SDK operations:

```swift
import Foundation
import SMIClientUI
import SMIClientCore
import Security

/// Manager class for Salesforce In-App Messaging SDK
/// Handles configuration and opening of chat conversations
class SalesforceMessagingManager {
    
    static let shared = SalesforceMessagingManager()
    
    private var uiClient: UIClient?
    private var coreClient: CoreClient?
    private var conversationId: UUID?
    
    private let configFileName = "salesforce_config"
    private let conversationIdKey = "com.salesforce.messaging.conversationId"
    
    private init() {}
    
    // MARK: - Open Chat Methods
    
    /// Opens the Salesforce chat conversation using config file
    /// - Parameters:
    ///   - viewController: The view controller to present the chat from
    ///   - usePersistedConversation: If true, uses the same conversation ID across app restarts
    func openChatWithConfigFile(from viewController: UIViewController, usePersistedConversation: Bool = true) throws {
        // Load config from file
        guard let configURL = Bundle.main.url(forResource: configFileName, withExtension: "json") else {
            throw SalesforceMessagingError.configFileNotFound
        }
        
        let coreConfig = try CoreConfiguration(configURL)
        
        // Get or generate conversation ID (UUID v4)
        let conversationID = usePersistedConversation ? getOrCreateConversationId() : UUID()
        self.conversationId = conversationID
        
        // Create UI configuration
        let config = UIConfiguration(coreConfig: coreConfig, conversationId: conversationID)
        
        // Create CoreClient for conversation management
        coreClient = CoreFactory.create(withConfig: coreConfig)
        
        // Create UIClient and open conversation
        uiClient = UIClientFactory.create(withConfig: config)
        
        // Present the chat interface
        if let chatViewController = uiClient?.createMessagingViewController() {
            let navController = UINavigationController(rootViewController: chatViewController)
            navController.modalPresentationStyle = .fullScreen
            viewController.present(navController, animated: true)
        }
    }
    
    /// Opens the Salesforce chat conversation using manual configuration
    func openChatManual(
        from viewController: UIViewController,
        serviceApiUrl: String,
        orgId: String,
        deploymentName: String,
        usePersistedConversation: Bool = true
    ) throws {
        guard let url = URL(string: serviceApiUrl) else {
            throw SalesforceMessagingError.invalidUrl
        }
        
        // Create Core configuration manually
        let coreConfig = CoreConfiguration(serviceAPIURL: url, organizationId: orgId, developerName: deploymentName)
        
        // Get or generate conversation ID (UUID v4)
        let conversationID = usePersistedConversation ? getOrCreateConversationId() : UUID()
        self.conversationId = conversationID
        
        // Create UI configuration
        let config = UIConfiguration(coreConfig: coreConfig, conversationId: conversationID)
        
        // Create CoreClient for conversation management
        coreClient = CoreFactory.create(withConfig: coreConfig)
        
        // Create UIClient and open conversation
        uiClient = UIClientFactory.create(withConfig: config)
        
        // Present the chat interface
        if let chatViewController = uiClient?.createMessagingViewController() {
            let navController = UINavigationController(rootViewController: chatViewController)
            navController.modalPresentationStyle = .fullScreen
            viewController.present(navController, animated: true)
        }
    }
    
    // MARK: - Conversation Management
    
    /// Closes the current conversation explicitly using completion handler
    func closeConversation(completion: ((Error?) -> Void)? = nil) {
        guard let conversationId = conversationId else {
            completion?(SalesforceMessagingError.chatNotInitialized)
            return
        }
        
        // Use the CoreClient's closeConversation with completion handler
        coreClient?.closeConversation(identifier: conversationId) { [weak self] error in
            if let error = error {
                print("Error closing conversation: \(error)")
                completion?(error)
            } else {
                self?.clearConversation()
                completion?(nil)
            }
        }
    }
    
    /// Starts a new conversation (closes current and creates new ID)
    func startNewConversation(from viewController: UIViewController) {
        closeConversation { [weak self] _ in
            try? self?.openChatWithConfigFile(from: viewController, usePersistedConversation: false)
        }
    }
    
    /// Clears the stored conversation ID from Keychain
    func clearConversation() {
        deleteFromKeychain(key: conversationIdKey)
        conversationId = nil
    }
    
    /// Returns the current conversation ID if one exists
    func getCurrentConversationId() -> UUID? {
        return conversationId
    }
    
    // MARK: - Conversation ID Management (UUID v4)
    
    /// Gets an existing conversation ID or creates a new one
    /// Uses Keychain for secure, persistent storage
    private func getOrCreateConversationId() -> UUID {
        if let savedIdString = loadFromKeychain(key: conversationIdKey),
           let savedId = UUID(uuidString: savedIdString) {
            return savedId
        }
        
        let newId = UUID()
        saveToKeychain(key: conversationIdKey, value: newId.uuidString)
        return newId
    }
    
    // MARK: - Keychain Storage (Secure Persistence)
    
    private func saveToKeychain(key: String, value: String) {
        let data = Data(value.utf8)
        deleteFromKeychain(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
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
```

**Why:**
- `openChatWithConfigFile()` - Reads config from JSON file and opens chat UI
- `openChatManual()` - Opens chat with manually provided credentials
- `closeConversation()` - Closes conversation with completion handler (per iOS guidelines)
- Keychain storage - Securely stores conversation ID (recommended by Salesforce)
- UUID v4 - Uses random UUID for conversation IDs

---

### Step 6: Create SalesforceMethodChannelHandler.swift

**File:** `ios/Runner/SalesforceMethodChannelHandler.swift`

This class handles Flutter ↔ iOS communication:

```swift
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
            self?.handleMethodCall(call, result: result)
        }
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
                try SalesforceMessagingManager.shared.openChatWithConfigFile(
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
```

**Why:**
- Keeps AppDelegate clean (separation of concerns)
- Handles all Flutter method calls (`openChat`, `closeConversation`, etc.)
- Gets root view controller for presenting chat UI
- Returns results back to Flutter

---

### Step 7: Update AppDelegate.swift

**File:** `ios/Runner/AppDelegate.swift`

Keep it minimal - just initialize the method channel handler:

```swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        
        // Setup Salesforce chat method channel
        SalesforceMethodChannelHandler.shared.setup(with: engineBridge.engine)
    }
}
```

**Why:**
- Clean AppDelegate (single responsibility)
- Only initializes the method channel handler
- All Salesforce logic is in separate files

---

### Step 8: Add Files to Xcode Project

The new Swift files must be added to the Xcode project. In `project.pbxproj`:

1. **Add file references** in `PBXFileReference` section
2. **Add to Runner group** in `PBXGroup` section
3. **Add to Sources build phase** in `PBXSourcesBuildPhase` section
4. **Add config.json to Resources build phase** in `PBXResourcesBuildPhase` section

**Or simply:** Open Xcode, right-click on Runner folder, select "Add Files to Runner", and add the Swift files and Resources folder.

---

### Step 9: Install Pods (on Mac)

```bash
cd ios
pod install
```

Then open `Runner.xcworkspace` (not `.xcodeproj`) in Xcode.

---

### iOS Integration Summary

| Step | File | Purpose |
|------|------|---------|
| 1 | `project.pbxproj` | Set iOS deployment target to 15.0 |
| 2 | `Podfile` | Add Salesforce SDK dependency |
| 3 | `Info.plist` | Add camera, photo, file permissions |
| 4 | `Resources/salesforce_config.json` | Salesforce credentials |
| 5 | `SalesforceMessagingManager.swift` | SDK operations, Keychain storage |
| 6 | `SalesforceMethodChannelHandler.swift` | Flutter ↔ iOS communication |
| 7 | `AppDelegate.swift` | Initialize method channel |
| 8 | Xcode project | Add files to build |
| 9 | Terminal | Run `pod install` |

---

### iOS Method Channel

The method channel name must match between Flutter and iOS:

```
Channel Name: "com.example.newproject/salesforce_chat"
```

**Methods:**

| Method | Parameters | Description |
|--------|------------|-------------|
| `openChat` | `useConfigFile`, `persistConversation`, `serviceApiUrl`*, `orgId`*, `deploymentName`* | Opens chat UI |
| `closeConversation` | none | Closes current conversation |
| `clearConversation` | none | Clears stored conversation ID |
| `startNewConversation` | none | Starts fresh conversation |
| `getConversationId` | none | Returns current conversation ID |

*Required only when `useConfigFile` is false

---

## Flutter Setup

This section provides the Flutter/Dart code needed to communicate with the native Android and iOS implementations.

### Files Structure

```
lib/
├── main.dart                                    # Main app with chat button
└── services/
    └── salesforce_messaging_service.dart        # Dart API for Salesforce chat
```

---

### Step 1: Create SalesforceMessagingService

**File:** `lib/services/salesforce_messaging_service.dart`

This service provides a clean Dart API for the native implementations:

```dart
import 'package:flutter/services.dart';

/// Service class to interact with Salesforce In-App Messaging SDK
/// This provides a Flutter interface to the native Android/iOS Salesforce chat
class SalesforceMessagingService {
  static const MethodChannel _channel =
      MethodChannel('com.example.newproject/salesforce_chat');

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
```

**Why:**
- Provides a clean Dart API for Flutter developers
- Handles PlatformException errors gracefully
- Uses the same method channel name as native implementations
- Supports both config file and manual configuration

---

### Step 2: Using the Service in Your App

**File:** `lib/main.dart` (example usage)

```dart
import 'package:flutter/material.dart';
import 'services/salesforce_messaging_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = false;

  /// Opens Salesforce In-App Chat
  Future<void> _openSalesforceChat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Option 1: Open chat using config file (recommended)
      final success = await SalesforceMessagingService.openChatWithConfigFile(
        persistConversation: true,
      );

      if (!success) {
        _showSnackBar('Failed to open chat');
      }

      // Option 2: Open chat with manual configuration
      // final success = await SalesforceMessagingService.openChatManual(
      //   serviceApiUrl: 'https://YOUR_URL.salesforce-scrt.com',
      //   orgId: 'YOUR_ORG_ID',
      //   deploymentName: 'YOUR_DEPLOYMENT_NAME',
      //   persistConversation: true,
      // );
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Clears the current conversation
  Future<void> _clearConversation() async {
    final success = await SalesforceMessagingService.clearConversation();
    if (success) {
      _showSnackBar('Conversation cleared');
    } else {
      _showSnackBar('Failed to clear conversation');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Conversation',
            onPressed: _clearConversation,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Salesforce Chat Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _openSalesforceChat,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chat),
              label: Text(_isLoading ? 'Opening Chat...' : 'Open Salesforce Chat'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Flutter Integration Summary

| Step | File | Purpose |
|------|------|---------|
| 1 | `salesforce_messaging_service.dart` | Dart API with method channel |
| 2 | `main.dart` | UI with chat button |

---

## Flutter Usage

### Open Salesforce Chat

```dart
import 'services/salesforce_messaging_service.dart';

// Open chat with config file (persists conversation)
await SalesforceMessagingService.openChatWithConfigFile(
  persistConversation: true,
);

// Open chat with manual configuration
await SalesforceMessagingService.openChatManual(
  serviceApiUrl: 'https://YOUR_URL.salesforce-scrt.com',
  orgId: 'YOUR_ORG_ID',
  deploymentName: 'YOUR_DEPLOYMENT_NAME',
  persistConversation: true,
);
```

### Manage Conversations

```dart
// Close the current conversation
await SalesforceMessagingService.closeConversation();

// Start a new conversation
await SalesforceMessagingService.startNewConversation();

// Clear stored conversation ID
await SalesforceMessagingService.clearConversation();

// Get current conversation ID
String? conversationId = await SalesforceMessagingService.getConversationId();
```

---

## Configuration

### Getting Salesforce Credentials

1. Log in to your Salesforce org
2. Go to **Setup** → **Messaging Settings**
3. Find your Enhanced In-App Chat deployment
4. Click **Download Config File** or copy values manually:
   - **OrganizationId**: Setup → Company Information
   - **DeveloperName**: API Name of your deployment
   - **Url**: Service API URL

### Updating Config Files

Update credentials in both:
- `android/app/src/main/assets/salesforce_config.json`
- `ios/Runner/Resources/salesforce_config.json`

---

## Conversation Management

### Conversation ID Guidelines

| Guideline | Implementation |
|-----------|----------------|
| Use UUID v4 | ✅ `UUID.randomUUID()` / `UUID()` |
| Secure storage | ✅ SharedPreferences (Android) / Keychain (iOS) |
| Persist across restarts | ✅ Stored locally |
| Independent of business logic | ✅ Random UUID only |

### Conversation Lifecycle

1. **Creation** - New conversation starts with unique UUID
2. **Session** - Messages exchanged (ending session ≠ ending conversation)
3. **Closing** - Explicitly close with `closeConversation()`
4. **Persistence** - History preserved for querying

---

## Requirements

### Android
- Min SDK: 21 (or as defined by Flutter)
- Kotlin
- DataBinding enabled

### iOS
- iOS 15.0+
- Xcode 12.3+
- Swift

---

## Troubleshooting

### Android Build Error: Duplicate META-INF files

Add to `android/app/build.gradle.kts`:

```kotlin
packaging {
    resources {
        excludes += setOf("META-INF/versions/9/OSGI-INF/MANIFEST.MF")
    }
}
```

### Android: Suspend function error

Ensure coroutines dependency is added and use `scope.launch {}` for suspend functions.

### iOS: Config file not found

Ensure `salesforce_config.json` is added to the Xcode project and included in the target's "Copy Bundle Resources" build phase.

---

## License

This project uses:
- [Salesforce Enhanced In-App Chat SDK](https://developer.salesforce.com/docs/service/messaging-in-app/overview)
- [SQLCipher Community Edition](https://www.zetetic.net/sqlcipher/community/) (iOS SDK dependency)

See individual licenses for terms of use.

