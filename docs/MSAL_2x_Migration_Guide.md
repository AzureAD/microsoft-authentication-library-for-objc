# MSAL 2.x for iOS/macOS – Major Release Announcement & Migration Guide

We’re excited to announce the release of Microsoft Authentication Library (MSAL) 2.x for iOS and macOS platforms! This is a major release that introduces breaking changes, API cleanup, and a shift towards a more secure and standards-aligned SDK.

This guide will help you:

- Understand what changed in MSAL 2.x and why
- Migrate your existing apps to MSAL 2.x
- Avoid breaking your current authentication flow

## MSAL 2.x vs 1.x: What Changed, Why It Matters, and How to Migrate

### 1. Valid Redirect URI Format Requirement for Enterprise (AAD) Scenarios

#### What Changed

In **MSAL 2.x**, all enterprise **(AAD)** applications must specify a valid redirect URI in the format: `msauth.[BUNDLE_ID]://auth`.

For applications migrating from **ADAL**, redirect URIs formatted as `<scheme>://[BUNDLE_ID]` remain valid and are still supported in **MSAL 2.x**.

📖 For more information, see: [MSAL Redirect URI Format Requirements](https://learn.microsoft.com/en-us/entra/msal/objc/redirect-uris-ios#msal-redirect-uri-format-requirements)

#### Why It Matters

This standardization enables secure and valid redirection to brokered authentication with **Microsoft Authenticator** or **Company Portal**.

#### How to Migrate

##### 1. Register a valid redirect URI

In the Azure Portal under-App Registrations > Authentication, configure a redirect URI in the format: `msauth.[BUNDLE_ID]://auth`.

Note: If migrating from ADAL, the `<scheme>://[BUNDLE_ID]` format is still supported.

⚠️ Important: Ensure this redirect URI is configured across all **app targets and extensions** (such as Share Extensions) to enable smooth brokered authentication.

##### 2. Update Info.plist

Add the following entry to your app’s Info.plist:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>msauth.com.yourcompany.yourapp</string>
    </array>
  </dict>
</array>
```

##### 3. Add URL schemes to Info.plist

Include the following in Info.plist under LSApplicationQueriesSchemes:

```xml
<key>LSApplicationQueriesSchemes</key> 
<array>  
    <string>msauthv2</string>  
    <string>msauthv3</string>  
</array> 
```

##### 4. Initialize MSALPublicClientApplication using the configured redirect URI

Objective-C:
```objc
MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"your-client-id"
                                                                                            redirectUri:@"msauth.your.bundle.id://auth"
                                                                                              authority:authority];
 
NSError *error = nil;
MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                                error:&error];
 
if (error)
{
    NSLog(@"Error initializing MSAL: %@", error.localizedDescription);
     return;
}
```

Swift:
```swift
let config = MSALPublicClientApplicationConfig(clientId: "your-client-id",  
                                               redirectUri: "msauth.your.bundle.id://auth",  
                                               authority: authority) 
 
do { 
    let application = try MSALPublicClientApplication(configuration: config) 
    // Proceed with application 
} catch let error as NSError { 
    print("Error initializing MSAL: \(error.localizedDescription)") 
} 
```
Note: Remember to replace any placeholder values with your actual app-specific values 

⚠️ Important: Do not set bypassRedirectURIValidation = YES/true on MSALPublicClientApplicationConfig when using enterprise (AAD) redirect URIs. This will disable MSAL’s validation and brokered authentication, leading to failures in supported authentication scenarios. 

#### Invalid Format Handling

If an invalid redirect URI is provided for enterprise (AAD) scenarios, MSAL will fail at initialization of `MSALPublicClientApplication` with the following error:

| Property           | Value                   |
|--------------------|-------------------------|
| **Error Domain**   | `MSALErrorDomain`       |
| **Error Code**     | `-50000`                |
| **Internal Error Code** | `-42011`           |
| **Description**    | Varies depending on the validation failure (e.g., missing scheme, mismatched bundle ID, invalid host) |

#### Common Redirect URI Errors

| Error Scenario               | Example                      | Error Description                                                                                                                                                        |
|------------------------------|------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Empty URI**                | `nil`                        | "The provided redirect URI is nil or empty. Please ensure the redirect URI follows the valid format: `msauth.<bundle_id>://auth.`"                                      |
| **Missing scheme**           | `://auth` (missing scheme)   | "The provided redirect URI is missing a scheme. Please ensure the redirect URI follows the valid format: `msauth.<bundle_id>://auth`. Register your scheme in `Info.plist` under `CFBundleURLSchemes`." |
| **HTTP/HTTPS scheme**        | `http://yourapp.com`         | "The provided redirect URI uses an unsupported scheme (`http(s)://host`). Please ensure the redirect URI follows the valid format: `msauth.<bundle_id>://auth.`"        |
| **Bundle ID mismatch**       | `msauth.wrong.bundle.id://auth` | "The provided redirect URI uses MSAL format but the bundle ID does not match the app’s bundle ID. Please ensure the redirect URI follows the valid format: `msauth.<bundle_id>://auth.`" |
| **Missing host**             | `msauth.appid:/`             | "The provided redirect URI is missing the required host component `auth`. Please ensure the redirect URI follows the valid format: `msauth.<bundle_id>://auth.`"      |
| **Legacy OAuth2 out-of-band format** | `urn:ietf:wg:oauth:2.0:oob` | "The provided redirect URI `urn:ietf:wg:oauth:2.0:oob` is not supported. Please ensure the redirect URI follows the valid format: `msauth.<bundle_id>://auth.`"         |
| **Unknown invalid format**   | Any other invalid URI        | "The provided redirect URI is invalid. Please ensure the redirect URI follows the valid format: `msauth.<bundle_id>://auth.`"                                           |

### 2. Valid Parent View Controller (UI Anchor Window) Requirement for Interactive Token Requests

#### What Changed

Starting with **MSAL 2.x** for **iOS** and **macOS**, providing a valid parent view controller is **mandatory** for any interactive authentication flow.  
In **MSAL 1.x**, it was optional for macOS.

A valid parent view controller must be **non-nil** and its view must be attached to a valid **window** (i.e., `parentViewController.view.window != nil`).

#### Why It Matters

This ensures that the authentication UI can be correctly presented over the app's visible window and prevents runtime presentation issues.

#### How to Migrate

##### 1. Create MSALWebviewParameters with a valid parent view controller with its view attached to a valid window

Objective-C:
```objc
MSALViewController *viewController = ...;  
MSALWebviewParameters *webParameters = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:viewController];
```

Swift:
```swift
let viewController = ... // Your UI ViewController
let webviewParameters = MSALWebviewParameters(authPresentationViewController: viewController)
```

##### 2. Pass it to `MSALInteractiveTokenParameters`

Objective-C:
```objc
MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes
                                                                                  webviewParameters:webParameters];
```

Swift:
```swift
let interactiveParameters = MSALInteractiveTokenParameters(scopes: scopes, webviewParameters: webviewParameters)
```

#### Missing or Invalid Parent View Controller Handling

If a valid `parentViewController` is not provided through `MSALWebviewParameters`, MSAL will fail during token acquisition with the following error:

| Property            | Value              |
|---------------------|--------------------|
| **Error Domain**     | MSALErrorDomain     |
| **Error Code**       | -50000              |
| **Internal Error Code** | -42000              |
| **Error Description** | Varies depending on the validation failure (e.g., missing `webviewParameters`, missing `parentViewController`) |

#### Common Invalid Parent View Controller Errors

| Error Scenario                        | Example                                              | Error Description                                                                 |
|--------------------------------------|------------------------------------------------------|----------------------------------------------------------------------------------|
| **`webParameters` is nil**            | Passing `nil` instead of a valid `MSALWebviewParameters` instance | `"webviewParameters is a required parameter."`                                   |
| **`parentViewController` is nil**     | Not setting `parentViewController` on `MSALWebviewParameters`     | `"parentViewController is a required parameter."`                                |
| **`parentViewController.view.window` is nil** | Providing a view controller not attached to a window          | `"parentViewController has no window! Provide a valid controller with its view attached to a valid window."` |

### 3. MSALAccount Protocol Refactor

#### What Changed

Starting with **MSAL 2.x**, all properties previously declared in the `MSALAccount+MultiTenantAccount` category have been **moved into the main `MSALAccount` protocol**. As a result, the header file `MSALAccount+MultiTenantAccount.h` has been removed.

**Properties Moved to `MSALAccount` Protocol:**

| Property         | Type                                          |
|------------------|-----------------------------------------------|
| `homeAccountId`  | `MSALHomeAccountId *` / `MSALHomeAccountId?`  |
| `tenantProfiles` | `NSArray<MSALTenantProfile *> *` / `[MSALTenantProfile]?` |
| `isSSOAccount`   | `BOOL` / `Bool`                               |


#### Why It Matters

This **consolidates all account-related properties** into a single protocol, enabling mocking and protocol-based abstraction without exposing internal implementation.

#### How to Migrate

##### 1. Header Import Updates

Remove any direct imports of  MSALAccount+MultiTenantAccount.h. Instead, always import the umbrella header: MSAL.h

##### 2. Swift Property Access Updates

If you access the following properties in Swift:

- `homeAccountId`
- `tenantProfiles`
- `isSSOAccount`

You must now unwrap them safely, as Swift enforces optional access due to their declaration in the protocol exposed through the bridging header.

```swift
if let homeAccountId = account.homeAccountId {
    // Use homeAccountId.identifier
}

guard let tenantProfiles = account.tenantProfiles else {
    // Handle missing tenant profiles
    return
}

if account.isSSOAccount {
    // Proceed with SSO-specific logic
}
```

### 4. Removal of Deprecated APIs

#### What Changed

All deprecated APIs from **MSAL 1.x** are removed in **MSAL 2.x**. This includes deprecated initializers, account management methods, token acquisition methods, logging and telemetry interfaces.

#### Why It Matters

This removes reliance on outdated methods, streamlines code maintenance, and ensures all token acquisition and configuration follow a consistent approach—enhancing application reliability, consistency, and long-term compatibility.

#### How to Migrate

##### 1. MSALPublicClientApplication Initializers

**Deprecated:**
- `initWithClientId:authority:error:`
- `initWithClientId:authority:redirectUri:error:`
- `initWithClientId:keychainGroup:authority:redirectUri:error:` (iOS only)

**Use Instead:**
`initWithConfiguration:error:` using `MSALPublicClientApplicationConfig`

Objective-C – Before (Deprecated):
```objc
MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:@"your-client-id"
                                                                                       authority:authority
                                                                                           error:nil];
```

Objective-C – After:
```objc
MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"your-client-id"
                                                                                            redirectUri:@"your-redirect-uri"
                                                                                              authority:authority];
MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                                error:nil];
```

Swift – After:
```swift
let config = MSALPublicClientApplicationConfig(
    clientId: "your-client-id",
    redirectUri: "your-redirect-uri",
    authority: authority
)

do {
    let application = try MSALPublicClientApplication(configuration: config)
    // Use `application`
} catch {
    print("Failed to initialize MSAL: \(error.localizedDescription)")
}
```

##### 2. Token Acquisition (Silent)

**Deprecated:**
- `acquireTokenSilentForScopes:account:authority:`
- `acquireTokenSilentForScopes:account:authority:claims:correlationId:`

**Use Instead:**
`acquireTokenSilentWithParameters:completionBlock:`

Objective-C – Before (Deprecated):
```objc
[application acquireTokenSilentForScopes:@[@"user.read"]
                                 account:account
                               authority:authority
                         completionBlock:^(MSALResult *result, NSError *error)
 {
    // Handle result
}];
```

Objective-C – After:
```objc
MSALSilentTokenParameters *params = [[MSALSilentTokenParameters alloc] initWithScopes:@[@"user.read"]
                                                                              account:account];
params.authority = authority;
[application acquireTokenSilentWithParameters:params
                              completionBlock:^(MSALResult *result, NSError *error)
 {
    // Handle result
}];
```

Swift – After:
```swift
let parameters = MSALSilentTokenParameters(scopes: ["user.read"], account: account)
parameters.authority = authority
application.acquireTokenSilent(with: parameters) { (result, error) in
    // Handle result
}
```

##### 3. Token Acquisition (Interactive)

**Deprecated:**
- `acquireTokenForScopes:`
- `acquireTokenForScopes:extraScopesToConsent:loginHint:promptType:extraQueryParameters:authority:correlationId:`

**Use Instead:**
`acquireTokenWithParameters:completionBlock:`

Objective-C – Before (Deprecated):
```objc
[application acquireTokenForScopes:@[@"user.read"]
                   completionBlock:^(MSALResult *result, NSError *error)
 {
    // Handle result
}];
```

Objective-C – After:
```objc
MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"user.read"]
                                                                                  webviewParameters:webviewParams];
parameters.promptType = MSALPromptTypeSelectAccount;
[application acquireTokenWithParameters:parameters
                        completionBlock:^(MSALResult *result, NSError *error)
 {
    // Handle result
}];
```

Swift – After:
```swift
let parameters = MSALInteractiveTokenParameters(scopes: ["user.read"], webviewParameters: webviewParams)
parameters.promptType = .selectAccount
application.acquireToken(with: parameters) { (result, error) in
    // Handle result
}
```

##### 4. Account Management APIs

**Deprecated:**
- `accountForHomeAccountId:error:`
- `allAccountsFilteredByAuthority:`

**Use Instead:**
- `accountForIdentifier:error:`
- Use other synchronous or asynchronous account retrieval APIs like `accountsFromDeviceWithCompletionBlock:` depending on your scenario

Objective-C – Before (Deprecated):
```objc
NSError *error = nil;
MSALAccount *account = [application accountForHomeAccountId:@"homeAccountId"
                                                      error:&error];

// Deprecated method to fetch accounts filtered by authority
[application allAccountsFilteredByAuthority:^(NSArray<MSALAccount *> *accounts, NSError *error)
 {
    // Handle accounts
}];
```

Objective-C – After:
```objc
NSError *error = nil;
MSALAccount *account = [application accountForIdentifier:@"accountId"
                                                   error:&error];

// Recommended modern asynchronous way to fetch accounts
[application accountsFromDeviceWithCompletionBlock:^(NSArray<MSALAccount *> *accounts, NSError *error)
 {
    // Handle accounts
}];
```

Swift – Before:
```swift
do {
    let account = try application.account(forIdentifier: "accountId")
    // Handle account
} catch {
    print("Failed to get account: \(error)")
}

application.accountsFromDevice { (accounts, error) in
    // Handle accounts
}
```

Swift – Before (Deprecated):
```swift
do {
    let account = try application.account(forHomeAccountId: "homeAccountId")
    // Handle account
} catch {
    print("Failed to get account: \(error)")
}

application.allAccountsFilteredByAuthority { (accounts, error) in
    // Handle accounts
}
```

##### 5. MSALLogger is Deprecated – Use MSALLoggerConfig Instead

MSALLogger’s singleton-based logging approach is now deprecated. Configure logging behavior via MSALGlobalConfig.loggerConfig.

**Deprecated:**
- `[MSALLogger sharedLogger]`
- `MSALLogger.level`
- `[MSALLogger setCallback:]`

**Use Instead:**
- `MSALGlobalConfig.loggerConfig`
- `logLevel`
- `setLogCallback:`

Migration Examples – MSALLogger

Objective-C – Before (Deprecated):
```objc
[MSALLogger sharedLogger].level = MSALLogLevelVerbose;
[[MSALLogger sharedLogger] setCallback:^(MSALLogLevel level, NSString *message, BOOL containsPII)
 {
    NSLog(@"%@", message);
}];
```

Objective-C – After:
```objc
MSALGlobalConfig.loggerConfig.logLevel = MSALLogLevelVerbose;
[MSALGlobalConfig.loggerConfig setLogCallback:^(MSALLogLevel level, NSString *message, BOOL containsPII)
 {
    NSLog(@"%@", message);
}];
```

Swift – Before (Deprecated):
```swift
MSALLogger.shared().level = .verbose
MSALLogger.shared().setCallback { (level, message, containsPII) in
    print(message)
}
```

Swift – After:
```swift
MSALGlobalConfig.loggerConfig.logLevel = .verbose
MSALGlobalConfig.loggerConfig.setLogCallback { (level, message, containsPII) in
    print(message)
}
```

###### Summary: MSALLogger Deprecations

| Deprecated Item               | Replacement                          |
|-------------------------------|--------------------------------------|
| MSALLogger.sharedLogger       | MSALGlobalConfig.loggerConfig        |
| MSALLogger.level              | MSALGlobalConfig.loggerConfig.logLevel |
| setCallback:                  | setLogCallback: via loggerConfig     |

##### 6. MSALTelemetry is Deprecated – Use MSALTelemetryConfig Instead

MSALTelemetry’s singleton is deprecated. Configure telemetry via MSALGlobalConfig.telemetryConfig.

**Deprecated:**
- `[MSALTelemetry sharedInstance]`
- `piiEnabled / setPiiEnabled:`
- `notifyOnFailureOnly / setNotifyOnFailureOnly:`
- `telemetryCallback / setTelemetryCallback:`

**Use Instead:**
- `MSALGlobalConfig.telemetryConfig` and its properties

Migration Examples – MSALTelemetry

Objective-C – Before (Deprecated):
```objc
[MSALTelemetry sharedInstance].piiEnabled = YES;
[MSALTelemetry sharedInstance].notifyOnFailureOnly = NO;
[[MSALTelemetry sharedInstance] setTelemetryCallback:^(MSALTelemetryEvent *event)
 {
    NSLog(@"%@", event.name);
}];
```

Objective-C – After:
```objc
MSALGlobalConfig.telemetryConfig.piiEnabled = YES;
MSALGlobalConfig.telemetryConfig.notifyOnFailureOnly = NO;
MSALGlobalConfig.telemetryConfig.telemetryCallback = ^(MSALTelemetryEvent *event)
 {
    NSLog(@"%@", event.name);
};
```

Swift – Before (Deprecated):
```swift
MSALTelemetry.sharedInstance().piiEnabled = true
MSALTelemetry.sharedInstance().notifyOnFailureOnly = false
MSALTelemetry.sharedInstance().telemetryCallback = { event in
    print(event.name)
}
```

Swift – After:
```swift
MSALGlobalConfig.telemetryConfig.piiEnabled = true
MSALGlobalConfig.telemetryConfig.notifyOnFailureOnly = false
MSALGlobalConfig.telemetryConfig.telemetryCallback = { event in
    print(event.name)
}
```

###### Summary: MSALTelemetry Deprecations

| Deprecated Item               | Replacement                          |
|-------------------------------|--------------------------------------|
| MSALTelemetry.sharedInstance  | MSALGlobalConfig.telemetryConfig     |
| piiEnabled / setPiiEnabled:   | MSALGlobalConfig.telemetryConfig.piiEnabled |
| notifyOnFailureOnly / setNotifyOnFailureOnly: | MSALGlobalConfig.telemetryConfig.notifyOnFailureOnly |
| telemetryCallback / setTelemetryCallback: | MSALGlobalConfig.telemetryConfig.telemetryCallback |

### Testing & Validation

Before upgrading to MSAL 2.x, make sure to:
- ✅ Test all interactive and silent authentication flows
- ✅ Validate redirect URIs in both the Azure portal and Info.plist
- ✅ Update all deprecated API calls to supported alternatives
- ✅ Review and migrate telemetry and logging configurations
- ✅ Add unit tests or integration tests to validate authentication flows after migration
- ✅ Thoroughly test in staging before deploying changes to production.

### Resources

- [MSAL iOS/macOS GitHub Repository](https://github.com/AzureAD/microsoft-authentication-library-for-objc)
- [SDK reference](https://azuread.github.io/microsoft-authentication-library-for-objc/)
- [MSAL redirect URI format requirements](https://learn.microsoft.com/en-us/entra/msal/objc/redirect-uris-ios#msal-redirect-uri-format-requirements)

