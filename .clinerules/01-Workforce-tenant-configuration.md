# Agent Instructions: Create iOS/macOS Sample Application with Microsoft Entra ID - Workforce configuration

## Overview

These instructions guide agents through creating a sample iOS or macOS application that implements user sign-in using Microsoft Entra ID (formerly Azure AD) and calls the Microsoft Graph API.

## Prerequisites

Before starting, ensure the following requirements are met:

### Azure Requirements

- Active Azure subscription with an active account
- Permissions to manage applications (requires one of these roles):
  - Application Administrator
  - Application Developer
- A workforce tenant (or create a new tenant)

### Development Environment

- **iOS**: Version 16 or higher (for iOS apps)
- **macOS**: Version 11 or higher (for macOS apps)
- **CocoaPods**: For dependency management

### Pre-Configuration

- Register a new application in the Microsoft Entra admin center
- Configure for "Accounts in this organizational directory only"
- Record the following values from the application Overview page:
  - **Application (client) ID**
  - **Directory (tenant) ID**

## Step 1: Register Application in Microsoft Entra Admin Center

### 1.1 Create App Registration

1. Navigate to the [Microsoft Entra admin center](https://entra.microsoft.com)
2. Select **Applications** > **App registrations** > **New registration**
3. Enter a name for your application
4. Select "Accounts in this organizational directory only" as the supported account types
5. Click **Register**
6. Save the **Application (client) ID** and **Directory (tenant) ID** from the Overview page

### 1.2 Configure Platform (iOS/macOS)

1. Under **Manage**, select **Authentication** > **Add Platform** > **iOS/macOS**
2. Enter your **Bundle Identifier** (e.g., `com.<yourname>.identitysample.MSALMacOS`)
   - Note: This is a unique string that identifies your application
   - The iOS configuration also applies to macOS applications
3. Click **Configure** and save the **MSAL Configuration** details
4. Click **Done**

### 1.3 Enable Public Client Flow

1. Under **Manage**, select **Authentication**
2. Scroll to **Advanced settings**
3. For **Allow public client flows**, select **Yes**
4. Click **Save**

## Step 2: Download Sample Code

### 2.1 Download the Project

Choose the appropriate sample based on your target platform:

**For iOS:**

```bash
curl -L https://github.com/Azure-Samples/active-directory-ios-swift-native-v2/archive/master.zip -o ios-sample.zip
unzip ios-sample.zip
cd active-directory-ios-swift-native-v2-master
```

**For macOS:**

```bash
curl -L https://github.com/Azure-Samples/active-directory-macOS-swift-native-v2/archive/master.zip -o macos-sample.zip
unzip macos-sample.zip
cd active-directory-macOS-swift-native-v2-master
```

## Step 3: Install Dependencies

### 3.1 Install MSAL Library

1. Open Terminal and navigate to the project directory
2. Run CocoaPods to install the Microsoft Authentication Library (MSAL):
```bash
pod install
```
3. Wait for the installation to complete

### 3.2 Open Workspace

After pod installation, open the `.xcworkspace` file (NOT the `.xcodeproj` file):

```bash
open *.xcworkspace
```

## Step 4: Configure the Application

### 4.1 Update ViewController.swift

1. In Xcode, open the project navigator
2. Locate and open **ViewController.swift**
3. Find the line starting with `let kClientID` and replace it with your Application (client) ID:

```swift
let kClientID = "YOUR_APPLICATION_CLIENT_ID_HERE"
```

### 4.2 Configure Endpoints

For standard Microsoft Entra ID (global access), use default values:

```swift
let kGraphEndpoint = "https://graph.microsoft.com/"
let kAuthority = "https://login.microsoftonline.com/common"
```

**For national clouds** (if applicable):

- **Microsoft Entra Germany:**

```swift
let kGraphEndpoint = "https://graph.microsoft.de/"
let kAuthority = "https://login.microsoftonline.de/common"
```

See [Microsoft Graph deployments documentation](https://learn.microsoft.com/en-us/graph/deployments#app-registration-and-token-service-root-endpoints) for other endpoints.

### 4.3 Configure Bundle Identifier

1. In Xcode, select the project in the navigator
2. Select your target
3. Go to the **General** tab
4. In the **Identity** section, set the **Bundle Identifier** to match what you registered in the Azure portal

### 4.4 Update Info.plist

1. Right-click **Info.plist** in the project navigator
2. Select **Open As** > **Source Code**
3. Find the `CFBundleURLTypes` section under the dict root node
4. Replace `Enter_the_Bundle_Id_Here` with your Bundle Identifier
5. Note: Keep the `msauth.` prefix in the string

```xml
<key>CFBundleURLTypes</key>
<array>
   <dict>
      <key>CFBundleURLSchemes</key>
      <array>
         <string>msauth.YOUR_BUNDLE_IDENTIFIER_HERE</string>
      </array>
   </dict>
</array>
```

## Step 5: Build and Run the Application

### 5.1 Build the Project

1. Select your target device or simulator from the scheme selector
2. Click the **Build** button (⌘+B) or select **Product** > **Build**
3. Verify there are no build errors

### 5.2 Run the Application

1. Select **Product** > **Run** from the menu (or press ⌘+R)
2. The app will launch in the simulator or on your connected device

### 5.3 Test Authentication

1. When the app launches, you'll see the main interface
2. Click **Sign In** or **Acquire Token Interactively**
3. You'll be prompted to enter your credentials
4. After successful authentication, the app will display user information
5. The app can now make authenticated calls to Microsoft Graph API

## Step 6: Understanding the Code Flow

### Authentication Flow Diagram

```
User clicks "Sign In"
        ↓
App initiates MSAL authentication
        ↓
Browser/Web view opens with Microsoft login
        ↓
User enters credentials
        ↓
Microsoft Entra ID validates credentials
        ↓
Redirect back to app with authorization code
        ↓
MSAL exchanges code for access token
        ↓
App receives access token
        ↓
App can call Microsoft Graph API
```

### Key Components

- **MSAL Library**: Handles authentication and token management
- **ViewController**: Main UI and authentication logic
- **Microsoft Graph API**: Provides access to user data and resources
- **Access Token**: JWT token used to authenticate API calls

## Step 7: Testing the Application

### 7.1 Interactive Sign-In

Test the interactive authentication flow:

1. Launch the app
2. Click **Acquire Token Interactively**
3. Enter valid test credentials
4. Verify successful sign-in
5. Check that user information is displayed

### 7.2 Silent Token Acquisition

Test silent token refresh:

1. After initial sign-in, click **Acquire Token Silently**
2. Verify token is obtained without user interaction
3. This uses cached refresh tokens

### 7.3 Microsoft Graph API Call

Test API access:

1. Click **Get Graph Data Interactively** or **Get Graph Data Silently**
2. Verify the app successfully calls Microsoft Graph API
3. Check that user profile data is displayed

## Step 8: Common Configuration Issues

### Issue: "Redirect URI mismatch"

- **Solution**: Verify Bundle Identifier in Info.plist matches Azure portal configuration
- Ensure `msauth.` prefix is included in the redirect URI

### Issue: "Invalid client"

- **Solution**: Double-check Application (client) ID in ViewController.swift
- Ensure no extra spaces or characters

### Issue: "Pod install fails"

- **Solution**: Update CocoaPods: `sudo gem install cocoapods`
- Clear pod cache: `pod cache clean --all`
- Try again: `pod install`

### Issue: "Build fails with MSAL errors"

- **Solution**: Ensure you opened the `.xcworkspace` file, not `.xcodeproj`
- Clean build folder: **Product** > **Clean Build Folder** (⇧⌘K)

## Step 9: Next Steps

After successfully building and running the sample:

### For iOS Applications

- Follow the tutorial: [Sign in users and call Microsoft Graph from an iOS app](https://learn.microsoft.com/en-us/entra/identity-platform/tutorial-v2-ios)
- Implement additional Microsoft Graph API calls
- Add custom UI and branding
- Implement token caching strategies

### For macOS Applications

- Follow the iOS tutorial (also applies to macOS): [Sign in users and call Microsoft Graph from a iOS/macOS app](https://learn.microsoft.com/en-us/entra/identity-platform/tutorial-v2-ios)
- Implement additional application features
- Add keychain integration for secure token storage

### General Enhancements

- Implement error handling and retry logic
- Add logging and telemetry
- Configure additional API scopes
- Implement sign-out functionality
- Add multi-account support

## Additional Resources

- **MSAL Documentation**: [Microsoft Authentication Library for iOS and macOS](https://github.com/AzureAD/microsoft-authentication-library-for-objc)
- **Microsoft Graph API**: [Microsoft Graph REST API reference](https://learn.microsoft.com/en-us/graph/api/overview)
- **Authentication Flows**: [OAuth 2.0 and OpenID Connect protocols](https://learn.microsoft.com/en-us/entra/identity-platform/v2-protocols)
- **Best Practices**: [Security best practices for application developers](https://learn.microsoft.com/en-us/entra/identity-platform/identity-platform-integration-checklist)

## Security Considerations

1. **Never hardcode secrets**: Use secure storage mechanisms
2. **Validate tokens**: Always validate tokens server-side for API calls
3. **Use HTTPS**: Ensure all network communication uses HTTPS
4. **Minimal scopes**: Request only the minimum required API scopes
5. **Token expiration**: Handle token expiration and refresh appropriately
6. **Secure storage**: Use iOS Keychain or macOS Keychain for sensitive data

---

**Source**: [Microsoft Learn - Quickstart: Sign in users in a sample mobile app](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-mobile-app-sign-in)
