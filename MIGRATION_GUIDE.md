# POC to Production Migration Guide

**Project**: Salesforce In-App Chat Flutter Application  
**Created**: March 30, 2026  
**Purpose**: Guide for migrating this POC project to a production-level application

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Technology Stack](#technology-stack)
4. [Project Structure](#project-structure)
5. [File Breakdown](#file-breakdown)
6. [Dependencies & Versions](#dependencies--versions)
7. [Platform-Specific Implementation](#platform-specific-implementation)
8. [Key Features](#key-features)
9. [Critical Migration Checklist](#critical-migration-checklist)
10. [Production-Ready Considerations](#production-ready-considerations)

---

## 🎯 Quick Reference: POC vs Production Values

> **IMPORTANT**: This section clarifies which values come from this POC project vs. your production project.

### 📍 Values FROM This POC Project (Reference Only)

These are the Salesforce chat configuration and SDK implementations you should **reference** from this POC:

- ✅ **MethodChannel Communication Pattern**: See `lib/services/salesforce_messaging_service.dart`
- ✅ **iOS Implementation**: See `ios/Runner/SalesforceMessagingManager.swift` and `SalesforceMethodChannelHandler.swift`
- ✅ **Android Implementation**: See `android/app/src/main/kotlin/SalesforceMessagingManager.kt`
- ✅ **Salesforce SDK Versions**: Android `1.10.0`, iOS latest from CocoaPods
- ✅ **Conversation Persistence Logic**: Secure storage patterns (Keychain/SharedPrefs)
- ✅ **Error Handling**: Try-catch patterns and error enums

### 📍 Values FROM Your Production Project (Replace)

These are the values you must **get from your production project** and update in the POC code:

- 🔄 **Package Name**: From your production project registration (e.g., `com.acmecorp.chatapp`)
- 🔄 **Flutter/Dart SDK Versions**: From your production project requirements
- 🔄 **Android minSdk/targetSdk**: From your production project configuration
- 🔄 **iOS Deployment Target**: From your production project requirements
- 🔄 **Kotlin/Java Versions**: From your production project standards
- 🔄 **Additional Dependencies**: Any extra libraries used in production
- 🔄 **Signing Certificates**: For iOS and Android release builds
- 🔄 **App Name/Theme**: Your production branding
- 🔄 **Salesforce Config**: Production Salesforce org credentials

---

## ⚙️ Build & Run Prerequisites

> **CRITICAL**: Ensure all prerequisites are met before building/running this project.

### System Requirements

| Tool | Version | Platform | Install Command |
|------|---------|----------|-----------------|
| **Flutter SDK** | ^3.10.0 | All | See [flutter.dev/docs/get-started](https://docs.flutter.dev/get-started/install) |
| **Dart SDK** | ^3.10.0 | All | Bundled with Flutter |
| **Android Studio** | Latest | macOS/Windows/Linux | [developer.android.com](https://developer.android.com/studio) |
| **Xcode** | 14.0+ | macOS | App Store or [developer.apple.com](https://developer.apple.com/download/) |
| **CocoaPods** | 1.11+ | macOS | `sudo gem install cocoapods` |
| **Java/JDK** | 17 | All | Android Studio includes JDK 17 |
| **Gradle** | 7.0+ | All | Android Studio includes Gradle |

### Expected POC Files (Should Already Exist)

These files should be present in the POC project. If missing, migration is incomplete:

| File/Folder | Platform | Status | Purpose |
|------------|----------|--------|---------|
| `lib/main.dart` | All | ✅ Required | Entry point and UI |
| `lib/services/salesforce_messaging_service.dart` | All | ✅ Required | Dart ↔ Native bridge |
| `ios/Runner/SalesforceMessagingManager.swift` | iOS | ✅ Required | iOS chat logic |
| `ios/Runner/SalesforceMethodChannelHandler.swift` | iOS | ✅ Required | iOS MethodChannel handler |
| `ios/Podfile` | iOS | ✅ Required | iOS dependencies |
| `android/app/src/main/kotlin/SalesforceMessagingManager.kt` | Android | ✅ Required | Android chat logic |
| `android/app/src/main/kotlin/SalesforceMethodChannelHandler.kt` | Android | ✅ Required | Android MethodChannel handler |
| `android/app/build.gradle.kts` | Android | ✅ Required | Android build config |
| `pubspec.yaml` | All | ✅ Required | Dart dependencies |
| `ios/Runner/Resources/` | iOS | ⚠️ Conditional | Place `salesforce_config.json` here |
| `android/app/src/main/assets/` | Android | ⚠️ Conditional | Place `salesforce_config.json` here |

### Pre-Build Checklist

```bash
# 1. Verify Flutter installation
flutter --version

# 2. Run Flutter doctor to check environment
flutter doctor

# 3. Verify Java version (for Android)
java -version  # Should show Java 17

# 4. Accept Android licenses (Android only)
flutter doctor --android-licenses

# 5. Verify iOS tools (macOS only)
xcode-select --print-path

# 6. Verify all required POC files exist
ls lib/main.dart lib/services/salesforce_messaging_service.dart
ls android/app/src/main/kotlin/com/example/newproject/*.kt
ls ios/Runner/SalesforceMessagingManager.swift ios/Runner/SalesforceMethodChannelHandler.swift
```

### Critical: Salesforce Configuration File Setup

> **REQUIRED**: You must have `salesforce_config.json` before building.

**File Location**:
- **iOS**: `ios/Runner/Resources/salesforce_config.json`
- **Android**: `android/app/src/main/assets/salesforce_config.json`

**Obtain Config File**:
1. Log in to your Salesforce org
2. Navigate to **Setup** → **Feature Settings** → **Service** → **Messaging**
3. Find your **In-App Messaging Deployment**
4. Download the **Configuration File** (JSON format)
5. Place in both iOS and Android locations above

**Config File Example Structure**:
```json
{
  "url": "https://your-instance.my.salesforce.com/",
  "deploymentId": "your-deployment-id",
  "organizationId": "your-org-id",
  "visitorId": "your-visitor-id"
}
```

**Troubleshooting**:
- If using **manual configuration** instead, pass parameters at runtime (see `openChatManual()` in service)
- iOS will look for file in app bundle main directory first
- Android will look for file in app/src/main/assets

---

## 🎯 Project Overview

### What is This Project?

This is a **Flutter POC (Proof of Concept)** application that integrates **Salesforce Enhanced In-App Chat** across multiple platforms (iOS, Android, macOS, Linux, Web, Windows).

### Current Status

- ✅ **Cross-platform support**: iOS, Android, macOS, Linux, Web, Windows
- ✅ **Salesforce messaging integration**: Using native SDKs with Flutter bridge
- ✅ **Conversation persistence**: Conversation IDs stored securely across app sessions
- ⚠️ **Development quality**: POC-level, not production-hardened

### Primary Goal

Enable users to open Salesforce chat conversations directly from a Flutter app with conversation persistence and manual/config-file-based configuration options.

---

## 🏗️ Architecture

### High-Level Design

```
┌─────────────────────────────────────────────┐
│         Flutter UI Layer (Dart)            │
│  ├─ main.dart (MyApp, MyHomePage)          │
│  └─ services/                              │
│     └─ salesforce_messaging_service.dart   │
│        (MethodChannel communication)       │
└──────────────┬──────────────────────────────┘
               │ MethodChannel
       ┌───────┴─────────────┬────────────────┐
       │                     │                │
┌──────▼───────────┐  ┌─────▼──────────┐  ┌──▼──────────────┐
│     iOS          │  │     Android    │  │ Other Platforms │
│   (Swift)        │  │    (Kotlin)    │  │  (Not Shown)    │
│                  │  │                │  │                │
│ ┌──────────────┐ │  │ ┌────────────┐ │  └─────────────────┘
│ │ SalesforceM..│ │  │ │ SalesforceM│ │
│ │Manager.swift │ │  │ │..Manager.kt
│ └──────────────┘ │  │ └────────────┘ │
│ ┌──────────────┐ │  │ ┌────────────┐ │
│ │SalesforceM..│ │  │ │KeyStore or │ │
│ │ChannelH...  │ │  │ │SharedPrefs │ │
│ └──────────────┘ │  │ └────────────┘ │
└──────────────────┘  └────────────────┘
```

### Communication Flow

1. **Flutter Layer** initiates a method call via `SalesforceMessagingService`
2. **MethodChannel** routes to platform-specific handler
3. **iOS/Android** receives call, invokes Salesforce SDK
4. **Native Layer** presents chat UI or performs action
5. **Result** returned back to Flutter

---

## 🛠️ Technology Stack

### Framework & Language

> **ℹ️ NOTE**: These are the versions used in **this POC project**. Your production project should use appropriate versions based on your requirements.

| Component | POC Version | Production Recommendation | Details |
|-----------|------------|--------------------------|---------|
| Flutter SDK | ^3.10.0 | ^3.10.0 or higher | Core framework (update as needed) |
| Dart SDK | ^3.10.0 | ^3.10.0 or higher | Language (update as needed) |
| Android | API 21+ (minSdk) | API 21+ or higher | Minimum API level |
| iOS | 15.0+ | 15.0+ or higher | Minimum deployment target |
| Java | 17 | 17 or higher | Android compilation target |

### Native SDKs

| Platform | SDK | Version | Purpose |
|----------|-----|---------|---------|
| iOS | Messaging-InApp-UI | Latest | Salesforce chat UI |
| iOS | Messaging-InApp-Core | Latest | Salesforce chat core |
| Android | messaging-inapp-ui | 1.10.0 | Salesforce chat |

### Flutter Dependencies

```yaml
dependencies:
  flutter: (SDK)
  cupertino_icons: ^1.0.8 (Optional)

dev_dependencies:
  flutter_test: (SDK)
  flutter_lints: ^6.0.0
```

### Android Dependencies

```kotlin
// Salesforce In-App Messaging UI SDK
implementation("com.salesforce.service:messaging-inapp-ui:1.10.0")

// Kotlin Coroutines
implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
```

### iOS Dependencies (CocoaPods)

```ruby
pod 'Messaging-InApp-UI'     # Includes Core SDK
```

---

## ⚙️ Configuration Reference

### MethodChannel Configuration (From This POC)

> **CRITICAL**: These values are specific to this POC project. Use this as a reference for your production project setup.

| Configuration | POC Value | Production Value | Usage |
|-------------|-----------|-------------------|-------|
| **MethodChannel Name** | `com.example.newproject/salesforce_chat` | `<your.package.name>/salesforce_chat` | Flutter ↔ Native communication bridge |
| **File Location** | `lib/services/salesforce_messaging_service.dart` | Same structure in production | Dart layer |

### Salesforce SDK Versions (From This POC)

> **INFO**: These are the Salesforce SDK versions currently used in this POC. Pin these or newer versions in production.

| Platform | SDK Package | POC Version | Notes |
|----------|-------------|-------------|-------|
| **Android** | `com.salesforce.service:messaging-inapp-ui` | `1.10.0` | Pin this version in production (don't use "latest") |
| **iOS** | `Messaging-InApp-UI` (CocoaPods) | Latest via pod | Recommended: Pin to specific version |
| **iOS Core** | `Messaging-InApp-Core` | Latest (via InApp-UI) | Required for InApp-UI |
| **Kotlin Coroutines** | `org.jetbrains.kotlinx:kotlinx-coroutines-android` | `1.7.3` | Android async operations |

### Bundle/Package Identifiers (POC → Production Mapping)

| Item | POC Value | Production Value | Location |
|------|-----------|------------------|----------|
| **Dart Package Name** | `newproject` | `production_app_name` | `pubspec.yaml` |
| **Android Namespace** | `com.example.newproject` | `com.yourcompany.yourapp` | `android/app/build.gradle.kts` |
| **Android Application ID** | `com.example.newproject` | `com.yourcompany.yourapp` | `android/app/build.gradle.kts` |
| **iOS Bundle Identifier** | `com.example.newproject` | `com.yourcompany.yourapp` | Xcode project settings |
| **Salesforce Channel Name** | `com.example.newproject/salesforce_chat` | `com.yourcompany.yourapp/salesforce_chat` | `SalesforceMessagingService.dart` (must match Android namespace + `/salesforce_chat`) |

---

### Production Configuration Steps

> **ACTION ITEMS**: When setting up your production project, follow these steps to properly configure values from this POC:

1. **Choose Your Production Package Name**
   - Example: `com.mycompany.myapp`
   - Used for: Android namespace, Android app ID, iOS bundle ID, MethodChannel name

2. **Update MethodChannel Name**
   - This POC: `com.example.newproject/salesforce_chat`
   - Your Production: `<your.package.name>/salesforce_chat`
   - Locations to update:
     - `lib/services/salesforce_messaging_service.dart` (line with `MethodChannel()`)
     - iOS handler (if hardcoded)
     - Android handler (if hardcoded)

3. **Android Configuration**
   - Update `android/app/build.gradle.kts`:
     - `namespace = "com.yourcompany.yourapp"`
     - `applicationId = "com.yourcompany.yourapp"`
   - Keep Salesforce SDK version: `1.10.0` (or update to newer if available)
   - Keep Kotlin Coroutines: `1.7.3`

4. **iOS Configuration**
   - Update Bundle Identifier in Xcode
   - Ensure iOS deployment target: 15.0+
   - MethodChannel name must match Android namespace

5. **Salesforce SDK Versions**
   - Android: Pin `messaging-inapp-ui:1.10.0` (don't use "latest" in production)
   - iOS: Pin specific versions in `Podfile` (document versioning)
   - iOS Core automatically included with InApp-UI

6. **Flutter/Dart Versions**
   - Production Flutter SDK: ^3.10.0 (or higher based on your needs)
   - Dart SDK: ^3.10.0 (or higher based on your needs)
   - Update `pubspec.yaml` environment section accordingly

---

## 📁 Project Structure

### Root Level

```
newproject/
├── analysis_options.yaml       # Dart analysis configuration
├── pubspec.yaml               # Flutter project manifest
├── README.md                  # Original README (basic)
├── newproject.iml             # IntelliJ project file
│
├── lib/                       # Dart/Flutter source code
├── test/                      # Dart widget tests
│
├── android/                   # Android native code
├── ios/                       # iOS native code
├── macos/                     # macOS native code
├── linux/                     # Linux native code
├── web/                       # Web platform code
├── windows/                   # Windows native code
│
└── build/                     # Build artifacts (auto-generated)
```

### Dart Source Code (`lib/`)

```
lib/
├── main.dart                           # Entry point + UI
└── services/
    └── salesforce_messaging_service.dart  # Flutter ↔ Native bridge
```

### iOS Implementation (`ios/`)

```
ios/
├── Podfile                             # CocoaPods dependencies
├── Runner/
│   ├── AppDelegate.swift              # App lifecycle
│   ├── SceneDelegate.swift            # Scene management
│   ├── SalesforceMessagingManager.swift        # Core logic ⭐
│   ├── SalesforceMethodChannelHandler.swift    # MethodChannel handler ⭐
│   ├── GeneratedPluginRegistrant.h/m          # Auto-generated
│   ├── Runner-Bridging-Header.h       # Bridging header
│   ├── Info.plist                     # App configuration
│   ├── Assets.xcassets/               # Images and icons
│   └── Resources/                     # Other resources
├── Runner.xcodeproj/                  # Xcode project
├── Runner.xcworkspace/                # Xcode workspace
└── Flutter/                           # Flutter integration
```

### Android Implementation (`android/`)

```
android/
├── settings.gradle.kts                # Build settings
├── build.gradle.kts                   # Root build config
├── gradle.properties                  # Gradle configuration
├── local.properties                   # Local SDK paths
├── app/
│   └── build.gradle.kts              # App-level build config ⭐
│   └── src/
│       └── main/
│           ├── AndroidManifest.xml   # App manifest
│           ├── kotlin/
│           │   └── com/example/newproject/
│           │       ├── MainActivity.kt                    # Entry point ⭐
│           │       ├── SalesforceMessagingManager.kt     # Core logic ⭐
│           │       └── SalesforceMethodChannelHandler.kt # MethodChannel handler ⭐
│           ├── res/                  # Resources
│           └── assets/               # Raw assets
└── gradle/                            # Gradle wrapper
```

---

## 📄 File Breakdown

### Dart Files

#### `lib/main.dart`

**Purpose**: Application entry point and main UI  
**Size**: ~150 lines  
**Key Components**:
- `MyApp`: Root widget with Material theme (deepPurple)
- `MyHomePage`: Stateful widget with demo counter and Salesforce chat button
- `_openSalesforceChat()`: Calls `SalesforceMessagingService.openChatWithConfigFile()`
- Error handling and loading state

**Migration Notes**:
- Replace demo counter logic with real business logic
- Customize theme colors and fonts for production
- Add proper error handling UI
- Implement navigation structure

---

#### `lib/services/salesforce_messaging_service.dart`

**Purpose**: Dart ↔ Native platform bridge for Salesforce operations  
**Size**: ~90 lines  
**Key Methods**:

| Method | Parameters | Returns | Purpose |
|--------|-----------|---------|---------|
| `openChatWithConfigFile()` | `persistConversation: bool` | `Future<bool>` | Opens chat using SF config file |
| `openChatManual()` | `serviceApiUrl, orgId, deploymentName, persistConversation` | `Future<bool>` | Opens chat with manual config |
| `clearConversation()` | None | `Future<bool>` | Clears current conversation |
| `closeConversation()` | None | `Future<bool>` | Explicitly closes conversation |
| `minimizeChat()` | None | `Future<bool>` | Minimizes chat without closing |

**MethodChannel**: `com.example.newproject/salesforce_chat`

**Migration Notes**:
- Keep this as-is; it's well-structured
- Consider adding error callbacks/logging
- May add methods for conversation history, etc.

---

### iOS Files

#### `ios/Runner/SalesforceMessagingManager.swift`

**Purpose**: Core iOS logic for Salesforce messaging  
**Size**: ~200+ lines (needs reading full file)  
**Key Responsibilities**:

1. **Configuration Management**
   - Load config from `salesforce_config.json`
   - Handle manual configuration with URL, Org ID, Deployment Name

2. **Conversation ID Persistence**
   - Store in Keychain (secure)
   - Retrieve across app restarts
   - Key: `com.salesforce.messaging.conversationId`

3. **Chat UI Presentation**
   - Create `InterfaceViewController` or `UIViewController` from config
   - Present as modal or bottom sheet
   - Handle presentation from root view controller

4. **Error Handling**
   - Custom `SalesforceMessagingError` enum
   - Specific error types: `.configFileNotFound`, `.invalidUrl`, etc.

**Migration Notes**:
- Ensure `salesforce_config.json` is bundled in Xcode
- Update deployment target if needed (currently 15.0)
- Add logging for debugging
- Consider adding analytics hooks

---

#### `ios/Runner/SalesforceMethodChannelHandler.swift`

**Purpose**: Handles Flutter → iOS method channel calls  
**Size**: ~80+ lines  
**Key Methods**:

| Method | Handler | Action |
|--------|---------|--------|
| `openChat` | `handleOpenChat()` | Opens chat (config or manual) |
| `clearConversation` | Direct call | Clears conversation ID |
| `closeConversation` | Direct call with completion | Closes conversation |
| `startNewConversation` | Direct call | Starts fresh conversation |
| `getConversationId` | Direct call | Returns current UUID |

**Setup**: Called from `AppDelegate.swift` via `FlutterEngine`

**Migration Notes**:
- Verify all methods are implemented
- Add proper error tracking
- Consider adding method for getting connection state

---

#### `ios/Podfile`

**Purpose**: CocoaPods dependency management  
**Current Configuration**:
- Platform: iOS 15.0+
- `use_frameworks!` and `use_modular_headers!` enabled
- Data binding enabled for Salesforce SDKs

**Migration Notes**:
- Pin SDK versions for production (currently "latest")
- Add other SDK dependencies as needed
- Document why data binding is needed

---

### Android Files

#### `android/app/src/main/kotlin/SalesforceMessagingManager.kt`

**Purpose**: Core Android logic (parallel to iOS Manager)  
**Key Responsibilities**:
- Similar to iOS: config loading, conversation persistence, UI presentation
- Uses SharedPreferences for encryption
- Handles Activity context for presenting chat

**Migration Notes**:
- Ensure SharedPreferences encryption is used
- Test conversation persistence on device

---

#### `android/app/src/main/kotlin/SalesforceMethodChannelHandler.kt`

**Purpose**: Handles Flutter → Android method channel calls  
**Key Methods**:
- `openChat`: Delegate to `SalesforceMessagingManager`
- `clearConversation`, `closeConversation`, etc.

**Migration Notes**:
- Mirror iOS implementation for consistency
- Add same error handling

---

#### `android/app/build.gradle.kts`

**Purpose**: Android build configuration  
**Key Settings**:
- `namespace`: `com.example.newproject` ⚠️
- `compileSdk`: Flutter default
- `minSdk`/`targetSdk`: Flutter defaults
- `dataBinding`: Enabled (required for Salesforce SDK)
- Java version: 17
- Kotlin JVM target: 17

**Dependencies**:
```kotlin
implementation("com.salesforce.service:messaging-inapp-ui:1.10.0")
implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
```

**Migration Notes**:
- ⚠️ **CRITICAL**: Change `namespace` and `applicationId` to production package name
- Pin Salesforce SDK version in production
- Add additional dependencies as needed

---

### Configuration Files

#### `pubspec.yaml`

- **Package Name**: `newproject`
- **Version**: `1.0.0+1`
- **Dart SDK**: `^3.10.0`
- **Key Dependencies**: `flutter`, `cupertino_icons`

**Migration Notes**:
- Update package name and version
- Add production dependencies (state management, networking, etc.)
- Consider: `provider`, `riverpod`, `bloc` for state
- Consider: `http`, `dio` for API calls
- Consider: `logger`, `crashlytics` for production

---

#### `analysis_options.yaml`

- Standard Flutter linting configuration

**Migration Notes**:
- Customize lint rules for team standards
- Enable strict null safety checks

---

---

## 🔧 Platform-Specific Implementation Details

### iOS Implementation Details

**Framework Integration**:
- Uses SMIClientUI and SMIClientCore frameworks
- Integrates with Flutter via native channel in `AppDelegate`

**Secure Storage**:
- Keychain used for conversation ID persistence
- Encryption via iOS Security framework

**UI Presentation**:
- `InterfaceViewController` from Salesforce SDK
- Presented modally from root `UIViewController`

**Error Handling**:
- Custom error enum for specific failures
- Try-throw-catch pattern used

---

### Android Implementation Details

**Framework Integration**:
- Salesforce Messaging SDK (1.10.0)
- Kotlin coroutines for async operations

**Secure Storage**:
- SharedPreferences with encryption
- Serialization/deserialization of UUID for persistence

**UI Presentation**:
- Uses Activity context for presenting chat UI
- Native Salesforce SDK handles presentation

**Error Handling**:
- Result callback pattern for async operations
- Exception handling in coroutines

---

---

## ✨ Key Features

### 1. **Conversation Persistence**
- ✅ Conversation ID stored securely across app sessions
- ✅ Same UUID reused unless explicitly cleared
- ✅ Platform-specific secure storage (Keychain/SharedPrefs)

### 2. **Dual Configuration Methods**
- ✅ **Config File**: Load from `salesforce_config.json` bundled in app
- ✅ **Manual**: Provide URL, Org ID, Deployment Name at runtime

### 3. **Cross-Platform Support**
- ✅ iOS and Android with native implementations
- ⚠️ macOS, Linux, Web, Windows directories exist but not implemented

### 4. **Conversation Management**
- ✅ Open chat
- ✅ Clear conversation
- ✅ Close conversation
- ✅ Minimize chat
- ✅ Get current conversation ID

---

---

## 📊 Configuration Changes Reference Table

### Example: Migrating from POC to Production

> **EXAMPLE**: If your production package name is `com.acmecorp.chatapp`, here's what changes:

| Category | POC Project | Production Project | File(s) |
|----------|-------------|-------------------|---------|
| **Package Name (Dart)** | `newproject` | `acmecorp_chatapp` | `pubspec.yaml` → `name:` |
| **Android Namespace** | `com.example.newproject` | `com.acmecorp.chatapp` | `android/app/build.gradle.kts` → `namespace =` |
| **Android App ID** | `com.example.newproject` | `com.acmecorp.chatapp` | `android/app/build.gradle.kts` → `applicationId =` |
| **iOS Bundle ID** | `com.example.newproject` | `com.acmecorp.chatapp` | Xcode project settings |
| **MethodChannel Name** | `com.example.newproject/salesforce_chat` | `com.acmecorp.chatapp/salesforce_chat` | `lib/services/salesforce_messaging_service.dart` |
| **Salesforce Android SDK** | `1.10.0` | `1.10.0` (or higher, pinned) | `android/app/build.gradle.kts` |
| **Salesforce iOS SDK** | Latest via pod | Versioned pod (pinned) | `ios/Podfile` |
| **Flutter SDK** | `^3.10.0` | `^3.10.0` (or your policy) | `pubspec.yaml` → `environment:` |
| **Kotlin Coroutines** | `1.7.3` | `1.7.3` (or higher, pinned) | `android/app/build.gradle.kts` |

### Example Configuration File Changes

#### `lib/services/salesforce_messaging_service.dart`

**Before (POC):**
```dart
static const MethodChannel _channel = MethodChannel(
  'com.example.newproject/salesforce_chat',
);
```

**After (Production):**
```dart
static const MethodChannel _channel = MethodChannel(
  'com.acmecorp.chatapp/salesforce_chat',
);
```

---

#### `android/app/build.gradle.kts`

**Before (POC):**
```kotlin
android {
    namespace = "com.example.newproject"
    // ... other config
}

defaultConfig {
    applicationId = "com.example.newproject"
    // ... other config
}

dependencies {
    implementation("com.salesforce.service:messaging-inapp-ui:1.10.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
```

**After (Production):**
```kotlin
android {
    namespace = "com.acmecorp.chatapp"
    // ... other config
}

defaultConfig {
    applicationId = "com.acmecorp.chatapp"
    // ... other config
}

dependencies {
    implementation("com.salesforce.service:messaging-inapp-ui:1.10.0") // ← Pinned
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3") // ← Pinned
}
```

---

#### `pubspec.yaml`

**Before (POC):**
```yaml
name: newproject
version: 1.0.0+1

environment:
  sdk: ^3.10.0
```

**After (Production):**
```yaml
name: acmecorp_chatapp
version: 1.0.0+1

environment:
  sdk: ^3.10.0  # Keep aligned with your Flutter/Dart version policy
```

---

#### `ios/Podfile`

**Before (POC):**
```ruby
platform :ios, '15.0'
# ... setup code
pod 'Messaging-InApp-UI'
```

**After (Production):**
```ruby
platform :ios, '15.0'  # Verify this matches your requirements
# ... setup code
pod 'Messaging-InApp-UI', '~> X.X.X'  # ← Pin specific version
```

---

## 🚀 Quick Build & Run Commands

> **BEFORE RUNNING**: Ensure all prerequisites above are met and `salesforce_config.json` is in place.

### Step-by-Step Build Instructions

#### 1. Get Dependencies
```bash
# Navigate to project root
cd /path/to/newproject

# Get Flutter dependencies
flutter pub get

# Get iOS dependencies (macOS only, required)
cd ios
pod install
cd ..
```

#### 2. Update Configuration (if needed)
```bash
# Update MethodChannel name and package identifiers
# Edit these files with your production values:
# - lib/services/salesforce_messaging_service.dart (MethodChannel name)
# - android/app/build.gradle.kts (namespace, applicationId)
# - Xcode project settings (Bundle Identifier)
```

#### 3. Build for Android
```bash
# Debug build
flutter build apk --debug

# Release build (requires signing config)
flutter build apk --release

# Build AAB for Play Store
flutter build appbundle --release
```

#### 4. Build for iOS
```bash
# Debug build
flutter build ios --debug

# Release build
flutter build ios --release

# Create IPA file for TestFlight/App Store
flutter build ipa --release
```

#### 5. Run on Device/Emulator
```bash
# Run on Android emulator
flutter emulators --launch Pixel_4_API_30  # or your emulator
flutter run

# Run on connected Android device
flutter run -d <device-id>

# Run on iOS simulator (macOS only)
open -a Simulator
flutter run

# Run on connected iOS device
flutter run -d <device-id>
```

### Troubleshooting Build Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `Pod install failed` | CocoaPods cache outdated | `cd ios && rm -rf Pods Podfile.lock && pod install && cd ..` |
| `Gradle sync failed` | JDK mismatch | Verify Java 17: `java -version` |
| `Config file not found` | `salesforce_config.json` missing | Place in iOS Resources and Android assets (see above) |
| `MethodChannel not found` | Package name mismatch | Verify all identifiers match across files |
| `Xcode signing error` | Signing certificate issue | Update signing in Xcode → Signing & Capabilities |
| `App crashes on startup` | Salesforce SDK not initialized | Check `AppDelegate.swift` setup (iOS) |

---

## ✅ Critical Migration Checklist

### Pre-Migration Planning
- [ ] Define production package name (e.g., `com.company.app`)
- [ ] Obtain production Salesforce org ID and deployment details
- [ ] Generate Salesforce config file for production
- [ ] Create app signing keys for iOS and Android
- [ ] Plan state management architecture
- [ ] Document business logic requirements

### Code Migration
- [ ] Change bundle/package identifiers throughout project
- [ ] Update Salesforce configuration (production values)
- [ ] Implement real business logic in `main.dart`
- [ ] Add state management (Provider/Riverpod/Bloc)
- [ ] Add error handling and user feedback
- [ ] Implement logging/analytics
- [ ] Add production theme and branding
- [ ] Implement real navigation structure

### Android Migration
- [ ] Update `namespace` in `build.gradle.kts`
- [ ] Update `applicationId`
- [ ] Pin dependency versions (no "latest")
- [ ] Configure signing keys for release builds
- [ ] Update `AndroidManifest.xml` metadata
- [ ] Test on physical Android devices (API 21+)

### iOS Migration
- [ ] Update bundle identifier in Xcode
- [ ] Update team ID and signing certificate
- [ ] Bundle production `salesforce_config.json`
- [ ] Update deployment target if needed
- [ ] Configure development/production provisioning profiles
- [ ] Test on physical iOS devices (iOS 15.0+)
- [ ] Set up TestFlight/App Store Connect

### Testing
- [ ] Unit tests for Dart services
- [ ] Widget tests for UI
- [ ] Integration tests across platforms
- [ ] Test conversation persistence
- [ ] Test error scenarios
- [ ] Device/OS compatibility testing
- [ ] Performance testing on real devices

### Deployment
- [ ] Set up CI/CD pipeline (GitHub Actions/Fastlane)
- [ ] Configure App Store Connect (iOS)
- [ ] Configure Google Play Console (Android)
- [ ] Prepare privacy policy and terms
- [ ] Prepare app store descriptions/screenshots
- [ ] Configure crash reporting (Crashlytics/Sentry)
- [ ] Set up analytics (Firebase/Amplitude)

---

## 🚀 Production-Ready Considerations

### 1. **Security**
- [ ] Use environment variables for sensitive configuration
- [ ] Implement certificate pinning if connecting to APIs
- [ ] Validate all user inputs
- [ ] Use HTTPS for all network communication
- [ ] Implement proper authentication flow
- [ ] Store sensitive data in secure storage only
- [ ] Review Salesforce SDK security practices

### 2. **Error Handling & Monitoring**
- [ ] Comprehensive try-catch throughout
- [ ] User-friendly error messages
- [ ] Detailed logs for debugging (but not sensitive data)
- [ ] Crash reporting integration
- [ ] Performance monitoring
- [ ] Analytics for feature usage

### 3. **Performance**
- [ ] Lazy load heavy components
- [ ] Optimize images and assets
- [ ] Minimize network calls
- [ ] Profile app on real devices
- [ ] Test with poor network conditions
- [ ] Optimize memory usage

### 4. **Accessibility**
- [ ] Screen reader support
- [ ] Adequate contrast ratios
- [ ] Touch target sizes >= 48x48 dp
- [ ] Keyboard navigation support
- [ ] Semantic labels for UI elements

### 5. **Device Coverage**
- [ ] Test iOS: iPhone 12+, iPad (if applicable)
- [ ] Test Android: Various devices and OS versions
- [ ] Test landscape/portrait orientations
- [ ] Test with different screen sizes
- [ ] Test with notches/safe areas

### 6. **Versioning & Updates**
- [ ] Semantic versioning (major.minor.patch)
- [ ] Update messaging for major releases
- [ ] Plan deprecation strategy for old versions
- [ ] In-app update prompts

### 7. **Documentation**
- [ ] Architecture decision records (ADRs)
- [ ] API documentation
- [ ] Deployment procedures
- [ ] Emergency rollback procedures
- [ ] Known issues and workarounds

---

## 📝 Migration Process Template

### Phase 1: Setup
1. Fork/clone this project
2. Update package identifiers
3. Set up production build signing

### Phase 2: Implementation
1. Implement business logic
2. Add state management
3. Refine UI/UX
4. Implement navigation
5. Add logging/analytics

### Phase 3: Testing
1. Unit testing
2. Integration testing
3. User acceptance testing (UAT)

### Post-Build Verification Checklist

> **CRITICAL**: After successful build, verify these tests pass before deployment:

**Runtime Checks** (on device/emulator):
- [ ] App launches without crashes into MyHomePage
- [ ] "Open Chat" button visible and clickable
- [ ] Click "Open Chat" → Salesforce chat UI appears within 2-3 seconds
- [ ] Chat interface responds to user input
- [ ] App doesn't crash when chat opens/closes
- [ ] No "PlatformException" in `flutter logs` output
- [ ] No red error screens or stack traces visible

**Conversation Persistence Verification** (iOS & Android):
- [ ] Open chat → Send/receive message → Minimize app
- [ ] Force close app (Android: kill process, iOS: swipe up)
- [ ] Reopen app → Open chat → Same conversation ID appears (verify in logs)
- [ ] Message history visible from previous session
- [ ] Clear conversation → Reopen → New conversation starts

**Error Handling Robustness**:
- [ ] Remove/move `salesforce_config.json` → App shows error dialog (not crash)
- [ ] Disable network during chat → App handles gracefully
- [ ] Restart app 5 times → No memory leaks (check `flutter logs` for warnings)
- [ ] Open/close chat 10 times → No resource leaks

**Platform-Specific Validation**:
- [ ] **Android**: SharedPreferences encryption confirmed (check logs)
- [ ] **iOS**: Keychain storing conversation ID (check via Keychain Access if needed)
- [ ] **Both**: MethodChannel communication appears in `flutter logs`
- [ ] **Both**: Salesforce SDK callbacks firing correctly

**Device/OS Compatibility**:
- [ ] Android: Test on minSdk (API 21) and current API
- [ ] iOS: Test on iOS 15.0 and latest iOS
- [ ] Test on tablets if targeting iPad

### Phase 4: Deployment
1. Configure app stores
2. Set up CI/CD
3. Alpha/Beta releases
4. Production release

---

## 📚 Reference Files

- **Salesforce SDK Docs**: Consult official Salesforce documentation for SDK specifics
- **Flutter Documentation**: https://docs.flutter.dev
- **Android Best Practices**: https://developer.android.com
- **iOS Best Practices**: https://developer.apple.com

---

## 🎓 For Other Agents

### ⚠️ Critical DO's & DON'Ts

**DO:**
- ✅ Keep `SalesforceMessagingService.dart` (Dart bridge) as-is unless adding features
- ✅ Pin all dependency versions in production (no "latest" or floating versions)
- ✅ Test conversation persistence by force-closing app multiple times
- ✅ Verify both iOS and Android implementations match architecture
- ✅ Keep secure storage (Keychain/SharedPrefs) for conversation IDs
- ✅ Test error scenarios (missing config, network issues)
- ✅ Update ALL occurrences of bundle identifiers (Dart, Android, iOS)
- ✅ Place `salesforce_config.json` in BOTH iOS and Android locations
- ✅ Run `flutter pub get` before building
- ✅ Run `pod install` before iOS build

**DON'T:**
- ❌ Don't modify MethodChannel names without updating all three files
- ❌ Don't use different package names in iOS and Android
- ❌ Don't forget to run `pod install` when pod versions change
- ❌ Don't commit `salesforce_config.json` to version control (security risk)
- ❌ Don't hardcode Salesforce credentials in code
- ❌ Don't skip the `flutter doctor` health check
- ❌ Don't use "latest" for Salesforce SDK versions (lock versions)
- ❌ Don't ignore PlatformException errors during development
- ❌ Don't assume conversation persists if config file path is wrong
- ❌ Don't skip testing conversation persistence on real device
- ❌ Don't build without verifying all required files exist

### Dependency Version Locking (Critical for Production)

When migrating to production, LOCK all versions:

```yaml
# ❌ DON'T do this in production
pod 'Messaging-InApp-UI'  # "latest" - unpredictable

# ✅ DO this in production
pod 'Messaging-InApp-UI', '~> 7.1.0'  # Pinned version
```

Similar for Android:
```kotlin
// ❌ DON'T
implementation("com.salesforce.service:messaging-inapp-ui:+")

// ✅ DO
implementation("com.salesforce.service:messaging-inapp-ui:1.10.0")
```

---

## 🎓 For Other Agents

### Important Files Summary
1. `lib/main.dart` - Main UI logic
2. `lib/services/salesforce_messaging_service.dart` - Keep as bridge
3. `ios/Runner/SalesforceMessagingManager.swift` - iOS implementation
4. `android/app/src/main/kotlin/*` - Android implementation
5. `android/app/build.gradle.kts` - Android config
6. `ios/Podfile` - iOS dependencies
7. `pubspec.yaml` - Dart dependencies

**Critical Paths**:
- ⚠️ Bundle identifiers must match everywhere
- ⚠️ Salesforce configuration must be production-ready
- ⚠️ Secure storage implemented correctly (Keychain/SharedPrefs)
- ⚠️ MethodChannel names must be consistent

**Testing Entry Points**:
- Test Salesforce chat opening on both platforms
- Test conversation persistence (clear state, reopen app)
- Test error handling (missing config, network errors)
- Test with real Salesforce org

---

## 📞 Questions for Production Owner

1. What state management pattern should we use?
2. Are there additional Salesforce APIs needed?
3. What analytics/crash reporting service?
4. How should authentication work?
5. What additional features beyond chat?
6. Target minimum OS versions for production?
7. Internationalization requirements?
8. Offline support needed?
9. What CI/CD platform?
10. Additional platforms (Web, Desktop) needed?

---

## ✅ Final Verification Checklist (Before Handoff to Agent)

### Document Completeness Verification

- [x] **Project Overview**: Clear description of POC scope
- [x] **Architecture**: Diagram and communication flow documented
- [x] **Technology Stack**: All versions listed with POC vs. Production notes
- [x] **Configuration Reference**: MethodChannel names and SDK versions specified
- [x] **Bundle/Package Identifiers**: POC and production examples provided
- [x] **Build Prerequisites**: System requirements and setup steps documented
- [x] **Salesforce Config File**: Location and setup clearly specified
- [x] **Build & Run Commands**: Step-by-step shell commands provided
- [x] **Troubleshooting**: Common build issues with solutions
- [x] **Expected Files**: List of files that should exist in POC
- [x] **Post-Build Verification**: Detailed testing checklist
- [x] **Critical DO's & DON'Ts**: Common mistakes highlighted
- [x] **Key Files to Modify**: Clear file list for production setup
- [x] **Testing Entry Points**: What to test to validate functionality
- [x] **Platform-Specific Details**: iOS/Android implementation details
- [x] **Dependencies**: Flutter, Dart, Salesforce SDK versions documented

### Preparation Checklist for Other Agent

Before giving this document to another agent:

- [ ] Verify `MIGRATION_GUIDE.md` exists and is complete
- [ ] Verify all POC source files required are present:
  - [ ] `lib/main.dart`
  - [ ] `lib/services/salesforce_messaging_service.dart`
  - [ ] `ios/Runner/SalesforceMessagingManager.swift`
  - [ ] `ios/Runner/SalesforceMethodChannelHandler.swift`
  - [ ] `android/app/src/main/kotlin/SalesforceMessagingManager.kt`
  - [ ] `android/app/src/main/kotlin/SalesforceMethodChannelHandler.kt`
- [ ] Verify build configurations present:
  - [ ] `pubspec.yaml` with proper structure
  - [ ] `android/app/build.gradle.kts` with Salesforce SDK
  - [ ] `ios/Podfile` with messaging dependencies
- [ ] Ensure `README.md` and this migration guide are present
- [ ] Confirm `.gitignore` excludes `salesforce_config.json` (if applicable)
- [ ] Create a separate document for your production package name (pass to agent)

### Information to Provide to Other Agent

The agent will need these values from **YOUR production project**:

```
PRODUCTION_PACKAGE_NAME = "com.company.appname"
PRODUCTION_FLUTTER_VERSION = "^3.10.0"
PRODUCTION_MIN_SDK_ANDROID = "21"
PRODUCTION_TARGET_SDK_ANDROID = "34"
IOS_DEPLOYMENT_TARGET = "15.0"
SALESFORCE_ORG_ID = "your-org-id"
SALESFORCE_DEPLOYMENT_ID = "your-deployment-id"
```

Pass these as environment variables or a config file to the agent.

---

**Last Updated**: March 30, 2026  
**Status**: POC → Production Migration Ready
**Document Version**: 1.0 (Final for Agent Handoff)
