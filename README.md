Microsoft Authentication Library Preview for iOS and macOS
=====================================

| [Get Started](https://docs.microsoft.com/azure/active-directory/develop/quickstart-v2-ios) | [Sample Code](https://github.com/Azure-Samples/active-directory-ios-swift-native-v2) | [Support](README.md#community-help-and-support) 
| --- | --- | --- |

The MSAL library preview gives your app the ability to begin using the [Microsoft Identity platform](https://aka.ms/aaddev) by supporting [Azure Active Directory](https://azure.microsoft.com/en-us/services/active-directory/) and [Microsoft Accounts](https://account.microsoft.com) in a converged experience using industry standard OAuth2 and OpenID Connect. The library also supports [Azure AD B2C](https://azure.microsoft.com/services/active-directory-b2c/) for those using our hosted identity management service.

Note that throughout the preview, only iOS has been supported. Starting with **MSAL release 0.5.0**, MSAL now supports macOS. 

## Important Note about the MSAL Preview

These libraries are suitable to use in a production environment. We provide the same production level support for these libraries as we do our current production libraries. During the preview we reserve the right to make changes to the API, cache format, and other mechanisms of this library without notice which you will be required to take along with bug fixes or feature improvements  This may impact your application. For instance, a change to the cache format may impact your users, such as requiring them to sign in again and an API change may require you to update your code. When we provide our General Availability release later, we will require you to update your application to our General Availabilty version within six months to continue to get support.

[![Build Status](https://travis-ci.org/AzureAD/microsoft-authentication-library-for-objc.svg?branch=dev)](https://travis-ci.org/AzureAD/microsoft-authentication-library-for-objc)

## Swift

```swift
        let config = MSALPublicClientApplicationConfig(clientId: "<your-client-id-here>")
        let scopes = ["your-scope1-here", "your-scope2-here"]
        
        if let application = try? MSALPublicClientApplication(configuration: config) {
            
            let interactiveParameters = MSALInteractiveTokenParameters(scopes: scopes)
            application.acquireToken(with: interactiveParameters, completionBlock: { (result, error) in
                
                guard let authResult = result, error == nil else {
                    print(error!.localizedDescription)
                    return
                }
                
                // Get access token from result
                let accessToken = authResult.accessToken
                
                // You'll want to get the account identifier to retrieve and reuse the account for later acquireToken calls
                let accountIdentifier = authResult.account.identifier
            })
        }
        else {
            print("Unable to create application.")
        }
```

## Objective-C

```obj-c
    NSError *msalError;
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"<your-client-id-here>"];
    NSArray<NSString *> *scopes = @[@"your-scope1-here", @"your-scope2-here"];
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&msalError];
    
    MSALInteractiveTokenParameters *interactiveParams = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes];
    [application acquireTokenWithParameters:interactiveParams completionBlock:^(MSALResult *result, NSError *error) {
        if (!error)
        {
            // You'll want to get the account identifier to retrieve and reuse the account
            // for later acquireToken calls
            NSString *accountIdentifier = result.account.identifier;
            
            NSString *accessToken = result.accessToken;
        }
        else
        {
            // Check the error
        }
    }];
```

## Installation
### Using CocoaPods

You can use [CocoaPods](http://cocoapods.org/) to install `MSAL` by adding it to your `Podfile` under target:

```
use_frameworks!
 
target 'your-target-here' do
	pod 'MSAL'
end
```

### Using Carthage

You can use [Carthage](https://github.com/Carthage/Carthage) to install `MSAL` by adding it to your `Cartfile`: 

```
github "AzureAD/microsoft-authentication-library-for-objc" "master"
```

### Manually

You can also use Git Submodule or check out the latest release and use as framework in your application.


## Configuring MSAL

### Adding MSAL to your project
1. Register your app in the [Azure portal](https://aka.ms/MobileAppReg)
2. Make sure you register a redirect URI for your application. It should be in the following format: 

 `msauth.[BUNDLE_ID]://auth`

####iOS only steps:

1. Add your application's redirect URI scheme to your `Info.plist` file, it will be in the format of `msauth.[BUNDLE_ID]`
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>msauth.[BUNDLE_ID]</string>
        </array>
    </dict>
</array>
```
2. Add `LSApplicationQueriesSchemes` to allow making call to Microsoft Authenticator if installed.

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>msauth</string>
    <string>msauthv2</string>
</array>
```
See more info about configuring redirect uri for MSAL in our [Wiki](https://github.com/AzureAD/microsoft-authentication-library-for-objc/wiki/Redirect-uris-in-MSAL)

3. Add a new keychain group to your project Capabilities `com.microsoft.adalcache` . See more information about keychain groups for MSAL in our [Wiki](https://github.com/AzureAD/microsoft-authentication-library-for-objc/wiki/Keychain-on-iOS)

![](Images/keychain_example.png)

4. To handle a callback, add the following to `appDelegate`:

Swift
```swift
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        guard let sourceApplication = options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String else {
            return false
        }
        
        return MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: sourceApplication)
    }
```

Objective-C
```obj-c
- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    return [MSALPublicClientApplication handleMSALResponse:url 
                                         sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]];
}
```

#### macOS only steps:

1. Make sure your application is signed with a valid development certificate. While MSAL will still work in the unsigned mode, it will behave differently around cache persistence.

## Using MSAL

### Creating an Application Object
Use the client ID from yout app listing when initializing your MSALPublicClientApplication object:

Swift
```swift
let config = MSALPublicClientApplicationConfig(clientId: "<your-client-id-here>")
let application = try? MSALPublicClientApplication(configuration: config) 
```

Objective-C
```obj-c
NSError *msalError;
    
MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"<your-client-id-here>"];
MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&msalError];
    
```
### Acquiring Your First Token
Swift
```swift
    let interactiveParameters = MSALInteractiveTokenParameters(scopes: scopes)
            application.acquireToken(with: interactiveParameters, completionBlock: { (result, error) in
                
                guard let authResult = result, error == nil else {
                    print(error!.localizedDescription)
                    return
                }
                
                // Get access token from result
                let accessToken = authResult.accessToken
                
                // You'll want to get the account identifier to retrieve and reuse the account for later acquireToken calls
                let accountIdentifier = authResult.account.identifier
            })
```
Objective-C
```obj-c
    MSALInteractiveTokenParameters *interactiveParams = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes];
    [application acquireTokenWithParameters:interactiveParams completionBlock:^(MSALResult *result, NSError *error) {
        if (!error)
        {
            // You'll want to get the account identifier to retrieve and reuse the account
            // for later acquireToken calls
            NSString *accountIdentifier = result.account.identifier;
            
            NSString *accessToken = result.accessToken;
        }
        else
        {
            // Check the error
        }
    }];
```
> Our library uses the ASWebAuthenticationSession for authentication on iOS 12 by default. See more information about default values, and support for other iOS versions [Wiki](https://github.com/AzureAD/microsoft-authentication-library-for-objc/wiki/MSAL-for-iOS-uses-web-browser)

### Silently Acquiring an Updated Token
Swift
```swift
guard let account = try? application.account(forIdentifier: accountIdentifier) else { return }
        let silentParameters = MSALSilentTokenParameters(scopes: scopes, account: account)
        application.acquireTokenSilent(with: silentParameters) { (result, error) in
            
            guard let authResult = result, error == nil else {
                
                let nsError = error! as NSError
                
                if (nsError.domain == MSALErrorDomain &&
                    nsError.code == MSALError.interactionRequired.rawValue) {
                    
                    // Interactive auth will be required
                    return
                }
                return
            }
            
            // Get access token from result
            let accessToken = authResult.accessToken
        }
```
Objective-C
```objective-c
    NSError *error = nil;
    MSALAccount *account = [application accountForIdentifier:accountIdentifier error:&error];
    if (!account)
    {
        // handle error
        return;
    }
    
    MSALSilentTokenParameters *silentParams = [[MSALSilentTokenParameters alloc] initWithScopes:scopes account:account];
    [application acquireTokenSilentWithParameters:silentParams completionBlock:^(MSALResult *result, NSError *error) {
        if (!error)
        {
            NSString *accessToken = result.accessToken;
        }
        else
        {
            // Check the error
            if ([error.domain isEqual:MSALErrorDomain] && error.code == MSALErrorInteractionRequired)
            {
                // Interactive auth will be required
            }
            
            // Other errors may require trying again later, or reporting authentication problems to the user
        }
    }];
```


### Responding to an Interaction Required Error
Occasionally user interaction will be required to get a new access token, when this occurs you will receive a `MSALErrorInteractionRequired` error when trying to silently acquire a new token. In those cases call `acquireToken:` with the same account and scopes as the failing `acquireTokenSilent:` call. It is recommended to display a status message to the user in an unobtrusive way before invoking interactive `acquireToken:` call.

For more information, please see the [wiki](https://github.com/AzureAD/microsoft-authentication-library-for-objc/wiki/Error-Handling).

## Migrating from ADAL Objective-C
MSAL Objective-C is designed to support smooth migration from ADAL Objective-C library. For detailed design and instructions, follow this [guide](https://github.com/AzureAD/microsoft-authentication-library-for-objc/wiki/Migrating-from-ADAL-Objective-C-to-MSAL-SDK).

## Additional guidance

Our [wiki](https://github.com/AzureAD/microsoft-authentication-library-for-objc/wiki) is intended to document common patterns, error handling and debugging, functionality (e.g. logging, telemetry), and active bugs.
You can find it [here](https://github.com/AzureAD/microsoft-authentication-library-for-objc/wiki)


## Community Help and Support

We use [Stack Overflow](http://stackoverflow.com/questions/tagged/msal) with the community to provide support. We highly recommend you ask your questions on Stack Overflow first and browse existing issues to see if someone has asked your question before. 

If you find and bug or have a feature request, please raise the issue on [GitHub Issues](../../issues). 

To provide a recommendation, visit our [User Voice page](https://feedback.azure.com/forums/169401-azure-active-directory).

## Contribute

We enthusiastically welcome contributions and feedback. You can clone the repo and start contributing now. Read our [Contribution Guide](Contributing.md) for more information.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Security Library

This library controls how users sign-in and access services. We recommend you always take the latest version of our library in your app when possible. We use [semantic versioning](http://semver.org) so you can control the risk associated with updating your app. As an example, always downloading the latest minor version number (e.g. x.*y*.x) ensures you get the latest security and feature enhanements but our API surface remains the same. You can always see the latest version and release notes under the Releases tab of GitHub.

### Security Reporting

If you find a security issue with our libraries or services please report it to [secure@microsoft.com](mailto:secure@microsoft.com) with as much detail as possible. Your submission may be eligible for a bounty through the [Microsoft Bounty](http://aka.ms/bugbounty) program. Please do not post security issues to GitHub Issues or any other public site. We will contact you shortly upon receiving the information. We encourage you to get notifications of when security incidents occur by visiting [this page](https://technet.microsoft.com/en-us/security/dd252948) and subscribing to Security Advisory Alerts.


## License

Copyright (c) Microsoft Corporation.  All rights reserved. Licensed under the MIT License (the "License");
