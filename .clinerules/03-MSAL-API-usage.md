# MSAL API Usage Examples

This document provides code snippets for common MSAL authentication patterns in both Swift and Objective-C.

## Interactive Token Acquisition

Interactive token acquisition presents a UI to the user for authentication. This is typically used for initial sign-in or when a silent token acquisition fails.

### Swift

```swift
import MSAL

// Configure the application
let config = MSALPublicClientApplicationConfig(clientId: "YOUR_CLIENT_ID")
let application = try MSALPublicClientApplication(configuration: config)

// Configure webview parameters
let webViewParameters = MSALWebviewParameters(authPresentationViewController: self)

// Create interactive token parameters
let interactiveParameters = MSALInteractiveTokenParameters(scopes: ["user.read"], 
                                                           webviewParameters: webViewParameters)

// Acquire token interactively
application.acquireToken(with: interactiveParameters) { (result, error) in
    guard let result = result else {
        print("Could not acquire token: \(error?.localizedDescription ?? "Unknown error")")
        return
    }
    
    let accessToken = result.accessToken
    let account = result.account
    print("Access token acquired: \(accessToken)")
    print("Account: \(account.username ?? "Unknown")")
}
```

### Objective-C

```objc
#import <MSAL/MSAL.h>

// Configure the application
MSALPublicClientApplicationConfig *config = 
    [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"YOUR_CLIENT_ID"];

NSError *error = nil;
MSALPublicClientApplication *application = 
    [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];

if (error) {
    NSLog(@"Failed to create application: %@", error);
    return;
}

// Configure webview parameters
MSALWebviewParameters *webViewParameters = 
    [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:self];

// Create interactive token parameters
MSALInteractiveTokenParameters *interactiveParams = 
    [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"user.read"]
                                         webviewParameters:webViewParameters];

// Acquire token interactively
[application acquireTokenWithParameters:interactiveParams 
                        completionBlock:^(MSALResult * _Nullable result, NSError * _Nullable error) {
    if (error) {
        NSLog(@"Could not acquire token: %@", error);
        return;
    }
    
    NSString *accessToken = result.accessToken;
    MSALAccount *account = result.account;
    NSLog(@"Access token acquired: %@", accessToken);
    NSLog(@"Account: %@", account.username);
}];
```

## Silent Token Acquisition

Silent token acquisition attempts to get a token without user interaction, using cached tokens or refresh tokens. This is the recommended approach for acquiring tokens in most scenarios.

### Swift

```swift
import MSAL

// Configure the application
let config = MSALPublicClientApplicationConfig(clientId: "YOUR_CLIENT_ID")
let application = try MSALPublicClientApplication(configuration: config)

// Get the account (from previous interactive sign-in)
guard let account = try application.accountForIdentifier("ACCOUNT_IDENTIFIER") else {
    print("Account not found")
    return
}

// Create silent token parameters
let silentParameters = MSALSilentTokenParameters(scopes: ["user.read"], 
                                                 account: account)

// Acquire token silently
application.acquireTokenSilent(with: silentParameters) { (result, error) in
    if let error = error as NSError? {
        // Check if interaction is required
        if error.domain == MSALErrorDomain && 
           error.code == MSALError.interactionRequired.rawValue {
            // Fall back to interactive token acquisition
            print("Interaction required, use interactive flow")
        } else {
            print("Could not acquire token silently: \(error.localizedDescription)")
        }
        return
    }
    
    guard let result = result else {
        print("No result returned")
        return
    }
    
    let accessToken = result.accessToken
    print("Access token acquired silently: \(accessToken)")
}
```

### Objective-C

```objc
#import <MSAL/MSAL.h>

// Configure the application
MSALPublicClientApplicationConfig *config = 
    [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"YOUR_CLIENT_ID"];

NSError *error = nil;
MSALPublicClientApplication *application = 
    [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];

if (error) {
    NSLog(@"Failed to create application: %@", error);
    return;
}

// Get the account (from previous interactive sign-in)
MSALAccount *account = [application accountForIdentifier:@"ACCOUNT_IDENTIFIER" error:&error];

if (!account) {
    NSLog(@"Account not found");
    return;
}

// Create silent token parameters
MSALSilentTokenParameters *silentParams = 
    [[MSALSilentTokenParameters alloc] initWithScopes:@[@"user.read"] 
                                              account:account];

// Acquire token silently
[application acquireTokenSilentWithParameters:silentParams 
                              completionBlock:^(MSALResult * _Nullable result, NSError * _Nullable error) {
    if (error) {
        // Check if interaction is required
        if ([error.domain isEqualToString:MSALErrorDomain] && 
            error.code == MSALErrorInteractionRequired) {
            // Fall back to interactive token acquisition
            NSLog(@"Interaction required, use interactive flow");
        } else {
            NSLog(@"Could not acquire token silently: %@", error);
        }
        return;
    }
    
    NSString *accessToken = result.accessToken;
    NSLog(@"Access token acquired silently: %@", accessToken);
}];
```

## Best Practices

1. **Always try silent acquisition first**: Before prompting the user, attempt to acquire a token silently using `acquireTokenSilentWithParameters:completionBlock:`.

2. **Handle interaction required errors**: When silent acquisition fails with `MSALErrorInteractionRequired`, fall back to interactive acquisition using `acquireTokenWithParameters:completionBlock:`.

3. **Cache the account identifier**: Store the account identifier (`account.identifier`) after successful interactive sign-in for use in subsequent silent token requests.

4. **Use appropriate scopes**: Request only the scopes your application needs. The Microsoft Graph API uses scopes like `user.read`, `mail.read`, etc.

5. **Configure the application once**: Create a single instance of `MSALPublicClientApplication` and reuse it throughout your app's lifecycle.

6. **Handle errors gracefully**: Implement proper error handling for network issues, user cancellations, and authentication failures.

7. **Use MSALPublicClientApplicationConfig**: Always initialize MSAL using `MSALPublicClientApplicationConfig` to take advantage of all configuration options.

## Additional Resources

- For more information about MSAL scopes, see the Microsoft Graph permissions reference
- For authority configuration, see the Azure AD documentation on authentication endpoints
- For broker integration on iOS, ensure your redirect URI is properly configured in the Azure portal
