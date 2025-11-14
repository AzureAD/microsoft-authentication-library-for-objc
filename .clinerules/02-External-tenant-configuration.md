# Agent Instructions: Create iOS/macOS Sample Application with Microsoft Entra ID - External configuration

## Overview

These instructions guide agents through creating a sample iOS or macOS application that implements user sign-in using Microsoft Entra External ID for external tenants (customer-facing applications) and calls the Microsoft Graph API.

## Prerequisites

Before starting, ensure the following requirements are met:

### Azure Requirements

- Active Azure subscription with an active account
- Permissions to manage applications (requires one of these roles):
  - Application Administrator
  - Application Developer
- An external tenant. To create one, choose from:
  - Use the [Microsoft Entra External ID extension](https://aka.ms/ciamvscode/samples/marketplace) to set up an external tenant directly in Visual Studio Code _(Recommended)_
  - [Create a new external tenant](https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-create-external-tenant-portal) in the Microsoft Entra admin center

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
  - **Tenant Subdomain** (e.g., if your tenant primary domain is `contoso.onmicrosoft.com`, the subdomain is `contoso`)

### Additional Requirements

- A user flow configured for self-service sign-up
- The application must be added to the user flow

## Step 1: Register Application in Microsoft Entra Admin Center

### 1.1 Create App Registration

1. Navigate to the [Microsoft Entra admin center](https://entra.microsoft.com)
2. Select **Applications** > **App registrations** > **New registration**
3. Enter a name for your application
4. Select "Accounts in this organizational directory only" as the supported account types
5. Click **Register**
6. Save the **Application (client) ID** and **Directory (tenant) ID** from the Overview page

### 1.2 Get Tenant Details

1. Note your tenant's primary domain (e.g., `contoso.onmicrosoft.com`)
2. Extract the subdomain portion (e.g., `contoso`)
3. Save this subdomain for later configuration

### 1.3 Configure Platform (iOS/macOS)

1. Under **Manage**, select **Authentication** > **Add Platform** > **iOS / macOS**
2. Enter your **Bundle Identifier**
   - For the sample code: `com.microsoft.identitysample.ciam.MSALiOS`
   - For custom apps: Use your unique identifier (e.g., `com.yourcompany.appname`)
3. Click **Configure** and save the **MSAL Configuration** details
4. Click **Done**

### 1.4 Enable Public Client Flow

1. Under **Manage**, select **Authentication**
2. Scroll to **Advanced settings**
3. For **Allow public client flows**, select **Yes**
4. Click **Save**

## Step 2: Configure User Flow

### 2.1 Create User Flow

1. In the Microsoft Entra admin center, navigate to **External Identities** > **User flows**
2. Click **New user flow**
3. Select **Sign up and sign in** as the user flow type
4. Configure the user flow:
   - Name the user flow
   - Select identity providers (e.g., Email and password)
   - Choose user attributes to collect during sign-up
   - Configure optional claims
5. Click **Create**

### 2.2 Add Application to User Flow

1. Open your created user flow
2. Select **Applications**
3. Click **Add application**
4. Select your registered application
5. Click **Add**

For detailed instructions, see:

- [Create self-service sign-up user flows](https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-user-flow-sign-up-sign-in-customers)
- [Add application to user flow](https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-user-flow-add-application)

## Step 3: Download Sample Code

### 3.1 Clone the Repository

Open Terminal and run the following command:

```bash
git clone https://github.com/Azure-Samples/ms-identity-ciam-browser-delegated-ios-sample.git
cd ms-identity-ciam-browser-delegated-ios-sample
```

Alternatively, download as a ZIP file:

```bash
curl -L https://github.com/Azure-Samples/ms-identity-ciam-browser-delegated-ios-sample/archive/refs/heads/main.zip -o ios-ciam-sample.zip
unzip ios-ciam-sample.zip
cd ms-identity-ciam-browser-delegated-ios-sample-main
```

## Step 4: Install Dependencies

### 4.1 Install MSAL Library

1. Navigate to the project directory in Terminal
2. Run CocoaPods to install the Microsoft Authentication Library (MSAL):
```bash
pod install
```
3. Wait for the installation to complete

### 4.2 Open Workspace

After pod installation, open the `.xcworkspace` file:

```bash
open *.xcworkspace
```

**Important**: Always use the `.xcworkspace` file, not the `.xcodeproj` file when working with CocoaPods.

## Step 5: Configure the Application

### 5.1 Update Configuration.swift

1. In Xcode, locate and open **/MSALiOS/Configuration.swift**
2. Replace the placeholders with your values:

```swift
// Replace Enter_the_Application_Id_Here with your Application (client) ID
let kClientID = "YOUR_APPLICATION_CLIENT_ID_HERE"

// Replace Enter_the_Redirect_URI_Here with your redirect URI
// This should match the MSAL configuration from the portal
let kRedirectUri = "msauth.com.microsoft.identitysample.ciam.MSALiOS://auth"

// Replace Enter_the_Tenant_Subdomain_Here with your tenant subdomain
// For example, if your domain is contoso.onmicrosoft.com, use "contoso"
let kTenantSubdomain = "YOUR_TENANT_SUBDOMAIN"

// Replace Enter_the_Protected_API_Scopes_Here with your API scopes
// If you haven't configured any scopes yet, you can leave this empty
let kScopes = ["YOUR_API_SCOPES_HERE"]
// Example: let kScopes = ["api://YOUR_CLIENT_ID/ToDoList.Read", "api://YOUR_CLIENT_ID/ToDoList.ReadWrite"]
```

### 5.2 Configure Bundle Identifier

1. In Xcode, select the project in the navigator
2. Select your target
3. Go to the **General** tab
4. In the **Identity** section, verify the **Bundle Identifier** matches what you registered in the Azure portal
   - Default sample: `com.microsoft.identitysample.ciam.MSALiOS`

### 5.3 Update Info.plist (if needed)

The Info.plist should already be configured correctly for the sample. If you're using a custom Bundle Identifier:

1. Right-click **Info.plist** in the project navigator
2. Select **Open As** > **Source Code**
3. Find the `CFBundleURLTypes` section
4. Ensure the URL scheme matches your configuration:

```xml
<key>CFBundleURLTypes</key>
<array>
   <dict>
      <key>CFBundleURLSchemes</key>
      <array>
         <string>msauth.YOUR_BUNDLE_IDENTIFIER</string>
      </array>
   </dict>
</array>
```

## Step 6: Grant Admin Consent (if required)

If your application requires API permissions:

1. In the Microsoft Entra admin center, go to your app registration
2. Under **Manage**, select **API permissions**
3. Review the configured permissions
4. Click **Grant admin consent for [your tenant]**
5. Confirm the consent

For more details, see [Grant admin consent](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app#grant-admin-consent-external-tenants-only).

## Step 7: Build and Run the Application

### 7.1 Build the Project

1. Select your target device or simulator from the scheme selector
2. Click the **Build** button (⌘+B) or select **Product** > **Build**
3. Verify there are no build errors

### 7.2 Run the Application

1. Select **Product** > **Run** from the menu (or press ⌘+R)
2. The app will launch in the simulator or on your connected device

### 7.3 Test Authentication

1. When the app launches, you'll see the main interface
2. Click **Acquire Token Interactively**
3. A browser or web view will open with your configured sign-in experience
4. Complete the sign-up or sign-in process:
   - For new users: Fill in required attributes during sign-up
   - For existing users: Enter credentials
5. After successful authentication, you'll be redirected back to the app
6. The app will display user information and the access token

### 7.4 Test API Calls

1. Click **API - Perform GET** to test calling a protected API
2. Note: If you haven't configured a protected API yet, you may receive an error
3. For testing purposes, you can use Microsoft Graph API or deploy a custom API

## Step 8: Understanding the External Tenant Flow

### Authentication Flow for External Tenants

```
User opens app
        ↓
User clicks "Acquire Token Interactively"
        ↓
App initiates MSAL authentication with external tenant
        ↓
Browser/Web view opens with custom sign-up/sign-in UI
        ↓
New user: Sign-up flow with attribute collection
Existing user: Sign-in with credentials
        ↓
External tenant validates credentials
        ↓
User grants consent (if needed)
        ↓
Redirect back to app with authorization code
        ↓
MSAL exchanges code for access token
        ↓
App receives access token and ID token
        ↓
App can call protected APIs
```

### Key Differences from Workforce Tenants

- **User Flows**: External tenants use customizable user flows for sign-up/sign-in
- **Self-Service Registration**: Users can sign up without admin pre-creation
- **Branding**: Fully customizable sign-up/sign-in experience
- **Identity Providers**: Can configure social identity providers (Google, Facebook, etc.)
- **Attribute Collection**: Configure which user attributes to collect during sign-up

## Step 9: Testing the Application

### 9.1 Test New User Sign-Up

1. Launch the app
2. Click **Acquire Token Interactively**
3. On the sign-in page, click **Sign up now** or similar link
4. Fill in required attributes (email, password, etc.)
5. Complete email verification if configured
6. Verify successful account creation and sign-in
7. Check that user information is displayed in the app

### 9.2 Test Existing User Sign-In

1. Launch the app (or sign out if already signed in)
2. Click **Acquire Token Interactively**
3. Enter credentials for an existing user
4. Verify successful sign-in
5. Check that user information is displayed

### 9.3 Test Silent Token Acquisition

1. After initial sign-in, restart the app
2. Click **Acquire Token Silently**
3. Verify token is obtained without user interaction
4. This validates token caching and refresh token functionality

### 9.4 Test API Access

If you've configured a protected API:

1. Click **API - Perform GET**
2. Verify successful API call with the acquired token
3. Check the response data

## Step 10: Customize Branding and User Experience

### 10.1 Customize Branding

1. In the Microsoft Entra admin center, go to **Company branding**
2. Configure:
   - Logo and background images
   - Colors and themes
   - Custom text and messages
3. Save changes
4. Test the updated branding in your app

For details, see [Customize the default branding](https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-customize-branding-customers).

### 10.2 Configure Social Identity Providers

Add social sign-in options (Google, Facebook, etc.):

1. In the Microsoft Entra admin center, go to **External Identities** > **All identity providers**
2. Click **New identity provider**
3. Select the provider (e.g., Google)
4. Configure the provider settings
5. Add the provider to your user flow

For details, see [Configure sign-in with Google](https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-google-federation-customers).

## Step 11: Common Configuration Issues

### Issue: "Invalid tenant subdomain"

- **Solution**: Verify the tenant subdomain in Configuration.swift
- Ensure no extra spaces or characters
- Check that it matches your tenant's primary domain

### Issue: "Application not found in user flow"

- **Solution**: Verify the app is added to the user flow
- Check that the user flow is active
- Ensure the correct user flow is configured

### Issue: "Redirect URI mismatch"

- **Solution**: Verify Bundle Identifier matches Azure portal configuration
- Ensure the redirect URI in Configuration.swift matches the portal
- Check that URL scheme in Info.plist is correct

### Issue: "Invalid client"

- **Solution**: Double-check Application (client) ID in Configuration.swift
- Ensure the app registration exists in the correct tenant
- Verify no extra spaces or characters

### Issue: "Scopes not granted"

- **Solution**: Verify API permissions are configured
- Grant admin consent if required
- Check that scopes in Configuration.swift match configured permissions

### Issue: "Pod install fails"

- **Solution**: Update CocoaPods: `sudo gem install cocoapods`
- Clear pod cache: `pod cache clean --all`
- Try again: `pod install`

### Issue: "Sign-up attributes not appearing"

- **Solution**: Check user flow configuration
- Verify required attributes are selected
- Ensure custom attributes are defined if needed

## Step 12: Next Steps

After successfully building and running the sample:

### Implement Protected API Calls

- Follow the tutorial: [Sign in users and call a protected web API in sample iOS (Swift) app](https://learn.microsoft.com/en-us/entra/external-id/customers/sample-mobile-app-ios-swift-sign-in-call-api)
- Deploy an ASP.NET Core web API
- Configure API permissions and scopes
- Implement authenticated API calls from the mobile app

### Enhance User Experience

- Customize the in-app UI after authentication
- Implement user profile management
- Add password reset functionality
- Configure multi-factor authentication

### Add Advanced Features

- Implement token refresh strategies
- Add offline support with cached tokens
- Integrate biometric authentication (Face ID, Touch ID)
- Add logging and analytics

### Production Readiness

- Implement comprehensive error handling
- Add retry logic for network failures
- Configure app transport security
- Implement certificate pinning
- Add crash reporting and monitoring

## Step 13: Additional Resources

### Documentation

- **External ID Overview**: [Microsoft Entra External ID documentation](https://learn.microsoft.com/en-us/entra/external-id/)
- **MSAL for iOS/macOS**: [Microsoft Authentication Library for iOS and macOS](https://github.com/AzureAD/microsoft-authentication-library-for-objc)
- **User Flows**: [User flows for external tenants](https://learn.microsoft.com/en-us/entra/external-id/customers/concept-user-flows)
- **API Protection**: [Protect an API in external tenants](https://learn.microsoft.com/en-us/entra/external-id/customers/tutorial-protect-web-api-dotnet-core-build-app)

### Sample Applications

- **iOS Sample**: [ms-identity-ciam-browser-delegated-ios-sample](https://github.com/Azure-Samples/ms-identity-ciam-browser-delegated-ios-sample)
- **macOS Sample**: Available in the same repository with platform-specific configurations

### Best Practices

- **Security**: [Security best practices for external tenants](https://learn.microsoft.com/en-us/entra/external-id/customers/concept-security-customers)
- **User Experience**: [UX best practices for customer-facing apps](https://learn.microsoft.com/en-us/entra/external-id/customers/concept-branding-customers)
- **Token Management**: [Token lifetimes and policies](https://learn.microsoft.com/en-us/entra/identity-platform/configurable-token-lifetimes)

## Step 14: Security Considerations for External Tenants

### Authentication Security

1. **Use strong password policies**: Configure in user flow settings
2. **Enable MFA**: Add multi-factor authentication to user flows
3. **Implement account protection**: Configure suspicious activity detection
4. **Rate limiting**: Protect against brute force attacks

### Token Security

1. **Minimal scopes**: Request only necessary API permissions
2. **Token validation**: Always validate tokens server-side
3. **Secure storage**: Use iOS Keychain for token storage
4. **Token refresh**: Implement proper token refresh logic
5. **Revocation**: Support token and session revocation

### Data Protection

1. **HTTPS only**: Ensure all communication uses HTTPS
2. **Certificate pinning**: Consider implementing for production
3. **Data encryption**: Encrypt sensitive data at rest
4. **PII handling**: Follow privacy regulations (GDPR, CCPA)

### App Security

1. **Code obfuscation**: Protect sensitive logic in production
2. **Jailbreak detection**: Consider detecting compromised devices
3. **Input validation**: Validate all user inputs
4. **Secure coding**: Follow OWASP Mobile Security guidelines

---

**Source**: [Microsoft Learn - Quickstart: Sign in users in a sample mobile app (External Tenants)](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-mobile-app-sign-in?tabs=ios-macos-external&pivots=external)
