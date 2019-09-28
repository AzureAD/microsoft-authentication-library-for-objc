Microsoft Authentication Library for iOS and macOS
=====================================

| [Get Started](https://docs.microsoft.com/azure/active-directory/develop/quickstart-v2-ios) | [iOS Sample Code](https://github.com/Azure-Samples/active-directory-ios-swift-native-v2) | [macOS Sample Code](https://github.com/Azure-Samples/active-directory-macOS-swift-native-v2) | [Library reference](https://azuread.github.io/microsoft-authentication-library-for-objc/index.html) | [Support](https://github.com/AzureAD/microsoft-authentication-library-for-objc/blob/dev/README.md#community-help-and-support) 
| --- | --- | --- | --- | --- |

The MSAL library for iOS and macOS gives your app the ability to begin using the [Microsoft Identity platform](https://aka.ms/aaddev) by supporting [Azure Active Directory](https://azure.microsoft.com/en-us/services/active-directory/) and [Microsoft Accounts](https://account.microsoft.com) in a converged experience using industry standard OAuth2 and OpenID Connect. The library also supports [Azure AD B2C](https://azure.microsoft.com/services/active-directory-b2c/) for those using our hosted identity management service.

[![Build Status](https://travis-ci.org/AzureAD/microsoft-authentication-library-for-objc.svg?branch=dev)](https://travis-ci.org/AzureAD/microsoft-authentication-library-for-objc)

## Quick sample

###Swift

```swift
let config = MSALPublicClientApplicationConfig(clientId: "<your-client-id-here>")
let scopes = ["your-scope1-here", "your-scope2-here"]
        
if let application = try? MSALPublicClientApplication(configuration: config) {
            
	#if os(iOS)
	let viewController = ... // Pass a reference to the view controller that should be used when getting a token interactively
	let webviewParameters = MSALWebviewParameters(parentViewController: viewController)
	#else
	let webviewParameters = MSALWebviewParameters()
	#endif
	
	let interactiveParameters = MSALInteractiveTokenParameters(scopes: scopes, webviewParameters: webviewParameters)
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

###Objective-C

```obj-c
NSError *msalError = nil;
    
MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"<your-client-id-here>"];
NSArray<NSString *> *scopes = @[@"your-scope1-here", @"your-scope2-here"];
    
MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&msalError];
    
#if TARGET_OS_IPHONE
    UIViewController *viewController = ...; // Pass a reference to the view controller that should be used when getting a token interactively
    MSALWebviewParameters *webParameters = [[MSALWebviewParameters alloc] initWithParentViewController:viewController];
#else
    MSALWebviewParameters *webParameters = [MSALWebviewParameters new];
#endif
    
MSALInteractiveTokenParameters *interactiveParams = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes webviewParameters:webParameters];
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

3. Add a new keychain group to your project Capabilities. Keychain group should be  `com.microsoft.adalcache` on iOS and `com.microsoft.identity.universalstorage` on macOS. 

![](Images/keychain_example.png)

See more information about [keychain groups](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-v2-keychain-objc) and [Silent SSO for MSAL](https://docs.microsoft.com/en-us/azure/active-directory/develop/single-sign-on-macos-ios).

#### iOS only steps:

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

Note that "msauthv3" scheme is needed when compiling your app with Xcode 11 and later. 

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
	<string>msauthv2</string>
	<string>msauthv3</string>
</array>
```
See more info about [configuring redirect uri for MSAL](https://docs.microsoft.com/en-us/azure/active-directory/develop/redirect-uris)

3. To handle a callback, add the following to `appDelegate`:

Swift
```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
	return MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String)
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

**Note, that if you adopted UISceneDelegate on iOS 13+**, MSAL callback needs to be placed into the appropriate delegate method of UISceneDelegate instead of AppDelegate. MSAL `handleMSALResponse:sourceApplication:` must be called only once for each URL. If you support both UISceneDelegate and UIApplicationDelegate for compatibility with older iOS, MSAL callback would need to be placed into both files.

Swift

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        
        guard let urlContext = URLContexts.first else {
            return
        }
        
        let url = urlContext.url
        let sourceApp = urlContext.options.sourceApplication
        
        MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: sourceApp)
    }
```

Objective-C

```objective-c
- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts
{
    UIOpenURLContext *context = URLContexts.anyObject;
    NSURL *url = context.URL;
    NSString *sourceApplication = context.options.sourceApplication;
    
    [MSALPublicClientApplication handleMSALResponse:url sourceApplication:sourceApplication];
}
```



#### macOS only steps:

1. Make sure your application is signed with a valid development certificate. While MSAL will still work in the unsigned mode, it will behave differently around cache persistence.

## Using MSAL

### Creating an Application Object
Use the client ID from your app listing when initializing your MSALPublicClientApplication object:

Swift
```swift
let config = MSALPublicClientApplicationConfig(clientId: "<your-client-id-here>")
let application = try? MSALPublicClientApplication(configuration: config) 
```

Objective-C
```obj-c
NSError *msalError = nil;
    
MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"<your-client-id-here>"];
MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&msalError];
    
```
### Acquiring Your First Token interactively
Swift
```swift
#if os(iOS)
	let viewController = ... // Pass a reference to the view controller that should be used when getting a token interactively
	let webviewParameters = MSALWebviewParameters(parentViewController: viewController)
#else
	let webviewParameters = MSALWebviewParameters()
#endif
let interactiveParameters = MSALInteractiveTokenParameters(scopes: scopes, webviewParameters: webviewParameters)
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
#if TARGET_OS_IPHONE
    UIViewController *viewController = ...; // Pass a reference to the view controller that should be used when getting a token interactively
    MSALWebviewParameters *webParameters = [[MSALWebviewParameters alloc] initWithParentViewController:viewController];
#else
    MSALWebviewParameters *webParameters = [MSALWebviewParameters new];
#endif 

MSALInteractiveTokenParameters *interactiveParams = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes webviewParameters:webParameters];
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
> Our library uses the ASWebAuthenticationSession for authentication on iOS 12 by default. See more information about [default values, and support for other iOS versions](https://docs.microsoft.com/en-us/azure/active-directory/develop/customize-webviews).

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

For more information, please see [MSAL error handling guide](https://docs.microsoft.com/en-us/azure/active-directory/develop/msal-handling-exceptions).

## Supported Versions

**iOS** - MSAL supports iOS 10 and above.

**macOS** - MSAL supports macOS (OSX) 10.12 and above.

## Migrating from ADAL Objective-C
MSAL Objective-C is designed to support smooth migration from ADAL Objective-C library. For detailed design and instructions, follow this [guide](https://docs.microsoft.com/en-us/azure/active-directory/develop/migrate-objc-adal-msal)

## Additional guidance

Our [wiki](https://github.com/AzureAD/microsoft-authentication-library-for-objc/wiki) is intended to document common patterns, error handling and debugging, functionality (e.g. logging, telemetry), and active bugs.
You can find it [here](https://github.com/AzureAD/microsoft-authentication-library-for-objc/wiki).


## Community Help and Support

We use [Stack Overflow](http://stackoverflow.com/questions/tagged/msal) with the community to provide support. We highly recommend you ask your questions on Stack Overflow first and browse existing issues to see if someone has asked your question before. 

If you find a bug or have a feature request, please raise the issue on [GitHub Issues](../../issues). 

To provide a recommendation, visit our [User Voice page](https://feedback.azure.com/forums/169401-azure-active-directory).

## Contribute

We enthusiastically welcome contributions and feedback. You can clone the repo and start contributing now.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Security Library

This library controls how users sign-in and access services. We recommend you always take the latest version of our library in your app when possible. We use [semantic versioning](http://semver.org) so you can control the risk associated with updating your app. As an example, always downloading the latest minor version number (e.g. x.*y*.x) ensures you get the latest security and feature enhanements but our API surface remains the same. You can always see the latest version and release notes under the Releases tab of GitHub.

### Security Reporting

If you find a security issue with our libraries or services please report it to [secure@microsoft.com](mailto:secure@microsoft.com) with as much detail as possible. Your submission may be eligible for a bounty through the [Microsoft Bounty](http://aka.ms/bugbounty) program. Please do not post security issues to GitHub Issues or any other public site. We will contact you shortly upon receiving the information. We encourage you to get notifications of when security incidents occur by visiting [this page](https://technet.microsoft.com/en-us/security/dd252948) and subscribing to Security Advisory Alerts.


## License

Copyright (c) Microsoft Corporation.  All rights reserved. Licensed under the MIT License (the "License").
