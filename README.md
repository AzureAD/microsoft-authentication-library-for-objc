Microsoft Authentication Library for iOS and macOS
=====================================


| Documentation                  | Code Samples      | Library Reference | Support | Feedback|
|-------------------------------|---------------------------|-------------------|---------|----------|
| [MSAL iOS and macOS documentation](https://learn.microsoft.com/en-us/entra/msal/objc/) | &#8226;  [Microsoft Entra ID (workforce samples)](https://learn.microsoft.com/en-us/entra/identity-platform/sample-v2-code?tabs=framework#ios)<br/>&#8226; [Microsoft Entra External ID (customer samples)](https://learn.microsoft.com/en-us/entra/external-id/customers/samples-ciam-all?tabs=apptype#mobile)          | [ SDK reference](https://azuread.github.io/microsoft-authentication-library-for-objc/)             | [Get support](README.md#community-help-and-support) | [Feedback](https://forms.office.com/r/xuBV0CzEih) |


The Microsoft Authentication Library (MSAL) for iOS and macOS is an auth SDK that can be used to seamlessly integrate authentication into your apps using industry standard OAuth2 and OpenID Connect. It allows you to sign in users or apps with Microsoft identities. These identities include Microsoft Entra ID work and school accounts, personal Microsoft accounts, social accounts, and customer accounts. 

Using MSAL for iOS and macOS, you can acquire security tokens from the Microsoft identity platform to authenticate users and access secure web APIs for their applications. The library supports multiple authentication scenarios, such as single sign-on (SSO), Conditional Access, and brokered authentication. 

#### Native authentication support in MSAL

MSAL iOS also provides native authentication APIs that allow applications to implement a native experience with end-to-end customizable flows in their mobile applications. With native authentication, users are guided through a rich, native, mobile-first sign-up and sign-in journey without leaving the app. The native authentication feature is only available for mobile apps on [External ID for customers](https://learn.microsoft.com/en-us/entra/external-id/customers/concept-native-authentication). macOS is not supported. It is recommended to always use the most up-to-date version of the SDK.

## Get started

To use MSAL iOS and macOS in your application, you need to register your application in the Microsoft Entra Admin center and configure your project. Since the SDK supports both browser-delegated and native authentication experiences, follow the steps in the one of these quickstarts based on your scenario.

* For browser-delegated authentication scenarios, refer to the quickstart, [Sign in users and call Microsoft Graph from an iOS or macOS app](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-mobile-app-ios-sign-in).

* For native authentication scenarios on iOS apps, refer to the Microsoft Entra External ID sample guide, [Run iOS sample app](https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app).

## Migrate from ADAL Objective-C

The Azure Active Directory Authentication Library (ADAL) for Objective-C has been deprecated effective June 2023. Follow the [ADAL to MSAL migration guide for iOS and macOS](https://learn.microsoft.com/en-us/entra/msal/objc/migrate-objc-adal-msal) to avoid putting your app's security at risk.


## Quick sample

#### Swift
```swift
let config = MSALPublicClientApplicationConfig(clientId: "<your-client-id-here>")
let scopes = ["your-scope1-here", "your-scope2-here"]
        
if let application = try? MSALPublicClientApplication(configuration: config) {
            
	let viewController = ... // Pass a reference to the view controller that should be used when getting a token interactively
	let webviewParameters = MSALWebviewParameters(authPresentationViewController: viewController)
	
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

#### Objective-C
```obj-c
NSError *msalError = nil;
    
MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"<your-client-id-here>"];
NSArray<NSString *> *scopes = @[@"your-scope1-here", @"your-scope2-here"];
    
MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&msalError];
    
MSALViewController *viewController = ...; // Pass a reference to the view controller that should be used when getting a token interactively
MSALWebviewParameters *webParameters = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:viewController];
    
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

## Master branch deprecation

The master branch has been copied over to main branch. The master branch will contain updates only until version 1.2.14, for further releases please refer to 'main' branch instead of 'master'.

## Installation

### Using CocoaPods

**For browser-delegated authentication:**

You can use [CocoaPods](http://cocoapods.org/) to install `MSAL` by adding it to your `Podfile` under target:

```
use_frameworks!
 
target 'your-target-here' do
	pod 'MSAL'
end
```

**For native-authentication:**

To use the native authentication capabilities provided by MSAL in your iOS application, you need to specify `native-auth` as subspec for the `MSAL` dependency as follows:

```
use_frameworks!
 
target 'your-target-here' do
	pod 'MSAL/native-auth'
end
```

Note: If you're using the `native-auth` subspec, you must include the `use_frameworks!` setting in your `Podfile`.

### Using Carthage

You can use [Carthage](https://github.com/Carthage/Carthage) to install `MSAL` by adding it to your `Cartfile`: 

```
github "AzureAD/microsoft-authentication-library-for-objc" "main"
```
### Using Swift Packages

You can add `MSAL` as a [swift package dependency](https://developer.apple.com/documentation/swift_packages/distributing_binary_frameworks_as_swift_packages).
For MSAL version 1.1.14 and above, distribution of MSAL binary framework as a Swift package is available.

1. For your project in Xcode, click File → Swift Packages → Add Package Dependency...
2. Choose project to add dependency in
3. Enter : https://github.com/AzureAD/microsoft-authentication-library-for-objc as the package repository URL
4. Choose package options with :
    1. Rules → Branch : main (For latest MSAL release)
    2. Rules → Version → Exact : [release version >= 1.1.14] (For a particular release version)

For any issues, please check if there is an outstanding SPM/Xcode bug.
Workarounds for some bugs we encountered :
* If you have a plugin in your project you might encounter [CFBundleIdentifier collision. Each bundle must have a unique bundle identifier](https://github.com/AzureAD/microsoft-authentication-library-for-objc/issues/737#issuecomment-767311138) error. [Workaround](https://github.com/AzureAD/microsoft-authentication-library-for-objc/issues/737#issuecomment-767990771)
* While archiving, error : “IPA processing failed” UserInfo={NSLocalizedDescription=IPA processing failed}. [Workaround](https://github.com/AzureAD/microsoft-authentication-library-for-objc/issues/737#issuecomment-767990771)
* For a macOS app, “Command CodeSign failed with a nonzero exit code” error. [Workaround](https://github.com/AzureAD/microsoft-authentication-library-for-objc/issues/737#issuecomment-770056675)

### Manually

If you choose to manually integrate MSAL for iOS and macOS into your Xcode project, follow the guidance in the official documentation on how to [add package dependencies to your application](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app#Add-a-package-dependency).

## Using Git Submodule

If your project is managed in a git repository you can include MSAL as a git submodule. First check the GitHub Releases Page for the latest release tag. Replace <latest_release_tag> with that version.

* `git submodule add https://github.com/AzureAD/microsoft-authentication-library-for-objc msal`
* `cd msal`
* `git checkout tags/<latest_release_tag>`
* `git submodule update --init --recursive`
* `cd ..`
* `git add msal`
* `git commit -m "Use MSAL git submodule at <latest_release_tag>"`
* `git push`

## Next steps

After installation, please follow the official [MSAL iOS and macOS documentation](https://learn.microsoft.com/en-us/entra/msal/objc/) on Microsoft Learn to complete the following steps:

* [Configure your project to use MSAL](https://learn.microsoft.com/en-us/entra/msal/objc/install-and-configure-msal#configuring-your-project-to-use-msal)
* [Configure authority for different identities](https://learn.microsoft.com/en-us/entra/msal/objc/configure-authority)
* [Configure redirect URIs](https://learn.microsoft.com/en-us/entra/msal/objc/redirect-uris-ios)
* [Acquire tokens](https://learn.microsoft.com/en-us/entra/msal/objc/acquire-tokens)

For more information on common usage patterns, error handling and debugging, logging, telemetry, and other library functionalities, please refere to the official [MSAL iOS and macOS documentation](https://learn.microsoft.com/en-us/entra/msal/objc/).

## Supported Versions

**iOS** - MSAL supports iOS 14 and above.

**macOS** - MSAL supports macOS (OSX) 10.13 and above.

## Community help and support

We use [Stack Overflow](http://stackoverflow.com/questions/tagged/msal) with the community to provide support. We highly recommend you ask your questions on Stack Overflow first and browse existing issues to see if someone has asked your question before. 

If you find a bug or have a feature request, please raise the issue on [GitHub Issues](../../issues). 

To provide a recommendation, visit our [User Voice page](https://feedback.azure.com/forums/169401-azure-active-directory).

## Submit feedback

We'd like your thoughts on this library. Please complete [this short survey.](https://forms.office.com/r/xuBV0CzEih)

## Contribute

We enthusiastically welcome contributions and feedback. You can clone the repo and start contributing now.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Security library

This library controls how users sign-in and access services. We recommend you always take the latest version of our library in your app when possible. We use [semantic versioning](http://semver.org), so you can control the risk associated with updating your app. As an example, always downloading the latest minor version number (e.g. x.*y*.x) ensures you get the latest security and feature enhancements, but our API surface remains the same. You can always see the latest version and release notes under the Releases tab of GitHub.

### Security reporting

If you find a security issue with our libraries or services please report it to [secure@microsoft.com](mailto:secure@microsoft.com) with as much detail as possible. Your submission may be eligible for a bounty through the [Microsoft Bounty](http://aka.ms/bugbounty) program. Please do not post security issues to GitHub Issues or any other public site. We will contact you shortly upon receiving the information. We encourage you to get notifications of when security incidents occur by visiting [this page](https://technet.microsoft.com/en-us/security/dd252948) and subscribing to Security Advisory Alerts.


## License

Copyright © Microsoft Corporation.  All rights reserved. Licensed under the MIT License (the “License”).
