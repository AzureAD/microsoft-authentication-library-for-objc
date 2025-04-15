# MSAL 2.x for iOS/macOS – Major Release Announcement & Migration Guide

We’re excited to announce the upcoming release of Microsoft Authentication Library (MSAL) 2.x for iOS and macOS platforms! This is a major release that introduces breaking changes, API cleanup, and a shift towards a more secure and standards-aligned SDK.

This guide will help you:
- Understand what’s changing and why
- Migrate your existing apps to MSAL 2.x
- Avoid breaking your current authentication flow

## What’s changing and why (MSAL 2.x vs 1.x)

### 1. Valid Redirect URI Enforcement for Enterprise

In MSAL 2.x, all enterprise use cases must specify a valid redirect URI in the following format:
- Default Format: msauth.[BUNDLE_ID]://auth
- Legacy ADAL Format: <scheme>://[BUNDLE_ID]

This is part of a platform-wide standardization to ensure safe redirection after interactive flows.

### 2. Parent UI Anchor Window Required for Interactive Token Requests

In MSAL 1.x, it was optional to provide a parentViewController. In MSAL 2.x, you must pass a valid UIViewController (iOS) or NSViewController (macOS) for any interactive token acquisition.

This change ensures consistent UX and avoids runtime UI permission issues.

### 3. Removal of Deprecated APIs

All deprecated APIs from MSAL 1.x are removed in 2.x. This includes old initializers, account management methods, token acquisition methods logging and telemetry interfaces.

## Migration to MSAL 2.x

### 1. Redirect URI Migration

#### a. Register your App with valid redirect URI format: msauth.[BUNDLE_ID]://auth or <scheme>://[BUNDLE_ID] (Legacy ADAL Format) in the Azure Portal under App Registrations > Authentication.

#### b. Update Info.plist:

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

#### c. Use the same to initialize MSALPublicClientApplication

Objective-C:
```objc
MSALPublicClientApplicationConfig *config = 
    [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"your-client-id" 
                                                     redirectUri:@"msauth.your.bundle.id://auth" 
                                                     authority:authority];

NSError *error = nil;
MSALPublicClientApplication *application = 
    [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
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
    print(error.localizedDescription)
}
```

### 2. UI Parent Window Anchor Migration

#### a. Create MSALWebviewParameters with a valid anchor

Objective-C:
```objc
MSALViewController *viewController = ...; 
MSALWebviewParameters *webParameters = [[MSALWebviewParameters alloc] 
    initWithAuthPresentationViewController:viewController];
```

Swift:
```swift
let viewController = ... // Your UI ViewController
let webviewParameters = MSALWebviewParameters(authPresentationViewController: viewController)
```

#### b. Pass it to MSALInteractiveTokenParameters:

Objective-C:
```objc
MSALInteractiveTokenParameters *parameters = 
    [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes 
                                          webviewParameters:webParameters];
```

Swift:
```swift
let interactiveParameters = MSALInteractiveTokenParameters(scopes: scopes, webviewParameters: webviewParameters)
```

### 3. Deprecated API Migration

#### 1. MSALPublicClientApplication Initializers

**Deprecated:**
- `initWithClientId:authority:error:`
- `initWithClientId:authority:redirectUri:error:`
- `initWithClientId:keychainGroup:authority:redirectUri:error:` (iOS only)

**Use Instead:**
`initWithConfiguration:error:` using `MSALPublicClientApplicationConfig`

Objective-C – Before (Deprecated):
```objc
MSALPublicClientApplication *application = 
  [[MSALPublicClientApplication alloc] initWithClientId:@"your-client-id"
                                               authority:authority
                                                   error:nil];
```

Objective-C – After:
```objc
MSALPublicClientApplicationConfig *config = 
  [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"your-client-id"];
config.redirectUri = @"your-redirect-uri";
config.knownAuthorities = @[authority];
MSALPublicClientApplication *application = 
  [[MSALPublicClientApplication alloc] initWithConfiguration:config error:nil];
```

Swift – After:
```swift
let config = MSALPublicClientApplicationConfig(clientId: "your-client-id")
config.redirectUri = "your-redirect-uri"
config.knownAuthorities = [authority]
let application = try! MSALPublicClientApplication(configuration: config)
```

#### 2. Token Acquisition (Silent)

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
                         completionBlock:^(MSALResult *result, NSError *error) {
    // Handle result
}];
```

Objective-C – After:
```objc
MSALSilentTokenParameters *params = 
  [[MSALSilentTokenParameters alloc] initWithScopes:@[@"user.read"] account:account];
params.authority = authority;
[application acquireTokenSilentWithParameters:params completionBlock:^(MSALResult *result, NSError *error) {
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

#### 3. Token Acquisition (Interactive)

**Deprecated:**
- `acquireTokenForScopes:`
- `acquireTokenForScopes:extraScopesToConsent:loginHint:promptType:extraQueryParameters:authority:correlationId:`

**Use Instead:**
`acquireTokenWithParameters:completionBlock:`

Objective-C – Before (Deprecated):
```objc
[application acquireTokenForScopes:@[@"user.read"]
                   completionBlock:^(MSALResult *result, NSError *error) {
    // Handle result
}];
```

Objective-C – After:
```objc
MSALInteractiveTokenParameters *parameters = 
  [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"user.read"]
                                         webviewParameters:webviewParams];
parameters.promptType = MSALPromptTypeSelectAccount;
[application acquireTokenWithParameters:parameters completionBlock:^(MSALResult *result, NSError *error) {
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

#### 4. Account Management APIs

**Deprecated:**
- `allAccountsWithError:`
- `removeAccount:error:`

**Use Instead:**
- `accountsFromDeviceWithCompletionBlock:`
- `removeAccount:completionBlock:`

Objective-C – Before (Deprecated):
```objc
NSError *error = nil;
NSArray *accounts = [application allAccountsWithError:&error];
[application removeAccount:account error:&error];
```

Objective-C – After:
```objc
[application accountsFromDeviceWithCompletionBlock:^(NSArray<MSALAccount *> *accounts, NSError *error) {
    // Handle accounts
}];
[application removeAccount:account completionBlock:^(BOOL success, NSError *error) {
    // Handle result
}];
```

Swift – After:
```swift
application.accountsFromDevice { (accounts, error) in
    // Handle accounts
}
application.remove(account) { (success, error) in
    // Handle result
}
```

### MSALLogger is Deprecated – Use MSALLoggerConfig Instead

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
[[MSALLogger sharedLogger] setCallback:^(MSALLogLevel level, NSString *message, BOOL containsPII) {
    NSLog(@"%@", message);
}];
```

Objective-C – After:
```objc
MSALGlobalConfig.loggerConfig.logLevel = MSALLogLevelVerbose;
[MSALGlobalConfig.loggerConfig setLogCallback:^(MSALLogLevel level, NSString *message, BOOL containsPII) {
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

### Summary: MSALLogger Deprecations

| Deprecated Item               | Replacement                          |
|-------------------------------|--------------------------------------|
| MSALLogger.sharedLogger       | MSALGlobalConfig.loggerConfig        |
| MSALLogger.level              | MSALGlobalConfig.loggerConfig.logLevel |
| setCallback:                  | setLogCallback: via loggerConfig     |

### MSALTelemetry is Deprecated – Use MSALTelemetryConfig Instead

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
[[MSALTelemetry sharedInstance] setTelemetryCallback:^(MSALTelemetryEvent *event) {
    NSLog(@"%@", event.name);
}];
```

Objective-C – After:
```objc
MSALGlobalConfig.telemetryConfig.piiEnabled = YES;
MSALGlobalConfig.telemetryConfig.notifyOnFailureOnly = NO;
MSALGlobalConfig.telemetryConfig.telemetryCallback = ^(MSALTelemetryEvent *event) {
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

### Summary: MSALTelemetry Deprecations

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

### Resources

- [MSAL iOS/macOS GitHub Repository](https://github.com/AzureAD/microsoft-authentication-library-for-objc)
- [SDK reference](https://azuread.github.io/microsoft-authentication-library-for-objc/)
- [MSAL redirect URI format requirements](https://learn.microsoft.com/en-us/entra/msal/objc/redirect-uris-ios#msal-redirect-uri-format-requirements)

