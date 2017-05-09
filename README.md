Microsoft Authentication Library Preview for iOS
=====================================

| [Get Started](https://apps.dev.microsoft.com/)| [Sample Code](https://github.com/Azure-Samples/active-directory-ios-swift-native-v2) | [API Reference](https://azuread.github.io/docs/objc/) | [Support](README.md#community-help-and-support)
| --- | --- | --- | --- |


The MSAL library preview for iOS gives your app the ability to begin using the [Microsoft Cloud](https://cloud.microsoft.com) by supporting [Microsoft Azure Active Directory](https://azure.microsoft.com/en-us/services/active-directory/) and [Microsoft Accounts](https://account.microsoft.com) in a converged experience using industry standard OAuth2 and OpenID Connect. The library also supports [Microsoft Azure B2C](https://azure.microsoft.com/services/active-directory-b2c/) for those using our hosted identity management service.

Note that for the preview, **only iOS is supported.** macOS support will be provided later. 

## Important Note about the MSAL Preview

These libraries are suitable to use in a production environment. We provide the same production level support for these libraries as we do our current production libraries. During the preview we reserve the right to make changes to the API, cache format, and other mechanisms of this library without notice which you will be required to take along with bug fixes or feature improvements  This may impact your application. For instance, a change to the cache format may impact your users, such as requiring them to sign in again and an API change may require you to update your code. When we provide our General Availability release later, we will require you to update your application to our General Availabilty version within six months to continue to get support.

[![Build Status](https://travis-ci.org/AzureAD/microsoft-authentication-library-for-objc.svg?branch=dev)](https://travis-ci.org/AzureAD/microsoft-authentication-library-for-objc)

## Example in Swift

```swift
    if let application = try? MSALPublicClientApplication.init(clientId: <your-client-id-here>) {
        application.acquireToken(forScopes: kScopes) { (result, error) in
            if result != nil {
                    // Set up your app for the user
            } else {
                print(error?.localizedDescription)
            }
        }
    }
    else {
            print("Unable to create application.")
        } 
```

## Example in Objective C

```objective-c
 MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:@"<your-client-id-here>"
                                                    error:&error];
    [application acquireTokenForScopes:@[@"scope1", @"scope2"]
                       completionBlock:^(MSALResult *result, NSError *error)
    {
        if (!error)
        {
            // You'll want to get the user identifier to retrieve and reuse the user
            // for later acquireToken calls
            NSString *userIdentifier = result.user.userIdentifier;
            
            NSString *accessToken = result.accessToken;
        }
        else
        {
            // Check the error
        }
    }]
```

## Installation

### Using Carthage

We use [Carthage](https://github.com/Carthage/Carthage) for package management during the preview period of MSAL. This package manager integrates very nicely with XCode while maintaining our ability to make changes to the library. The sample is set up to use Carthage.

##### If you're building for iOS, tvOS, or watchOS

1. Install Carthage on your Mac using a download from their website or if using Homebrew `brew install carthage`.
1. You must create a `Cartfile` that lists the MSAL library for this project on Github. 

```
github "AzureAD/microsoft-authentication-library-for-objc" "master"
```

1. Run `carthage update`. This will fetch dependencies into a `Carthage/Checkouts` folder, then build the MSAL library.
1. On your application targets’ “General” settings tab, in the “Linked Frameworks and Libraries” section, drag and drop the `MSAL.framework` from the `Carthage/Build` folder on disk.
1. On your application targets’ “Build Phases” settings tab, click the “+” icon and choose “New Run Script Phase”. Create a Run Script in which you specify your shell (ex: `/bin/sh`), add the following contents to the script area below the shell:

  ```sh
  /usr/local/bin/carthage copy-frameworks
  ```

  and add the paths to the frameworks you want to use under “Input Files”, e.g.:

  ```
  $(SRCROOT)/Carthage/Build/iOS/MSAL.framework
  ```
  This script works around an [App Store submission bug](http://www.openradar.me/radar?id=6409498411401216) triggered by universal binaries and ensures that necessary bitcode-related files and dSYMs are copied when archiving.

With the debug information copied into the built products directory, Xcode will be able to symbolicate the stack trace whenever you stop at a breakpoint. This will also enable you to step through third-party code in the debugger.

When archiving your application for submission to the App Store or TestFlight, Xcode will also copy these files into the dSYMs subdirectory of your application’s `.xcarchive` bundle.


### Using Git Submodule

If your project is managed in a git repository you can include MSAL as a git submodule. First check the GitHub Releases Page for the latest release tag. Replace <latest_release_tag> with that version.

* `git submodule add https://github.com/AzureAD/microsoft-authentication-library-for-objc msal`
* `cd msal`
* `git checkout tags/<latest_release_tag>`
* `cd ..`
* `git add msal`
* `git commit -m "Use MSAL git submodule at <latest_release_tag>"`
* `git push`

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


## Using MSAL

### Adding MSAL to your project
1. If you have not done so already, create an app listing at [apps.dev.microsoft.com](https://apps.dev.microsoft.com)
2. Clone the repository
```
    git clone https://github.com/AzureAD/microsoft-authentication-library-for-objc.git
```
3. Add `MSAL/MSAL.xcodeproj` to your Project or Workspace
4. Add `MSAL.framework` to your Application's "Embedded Binaries" and "Linked Frameworks and Library Section"
5. Add your application's redirect URI scheme to your `info.plist` file, it will be in the format of `msal<client-id>`
```xml
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLName</key>
            <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>msalyour-client-id-here</string>
            </array>
        </dict>
    </array>
```

Our library uses the SFSafariViewController for authentication. The authorization response URL is returned to the app via the iOS openURL app delegate method, so you need to pipe this through to the current authorization session. 

### Handling the redirect from the SFSafariViewController (Objective C)

You will need to add the following to your `AppDelegate.m` file:

```objective-c
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
{
    
    [MSALPublicClientApplication handleMSALResponse:url];
    
    return YES;
}
```

### Handling the redirect from the SFSafariViewController (Swift)

You will need to add the following to your `AppDelegate.swift` file:

```swift
func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        
        MSALPublicClientApplication.handleMSALResponse(url)
        
        
        return true
    }
```

### Creating an Application Object (Objective-C)
Use the client ID from yout app listing when initializing your MSALPublicClientApplication object:
```objective-c
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:@"<your-client-id-here>"
                                                    error:&error];
```

### Creating an Application Object (Swift)

```swift
let application = try MSALPublicClientApplication.init(clientId: kClientID, authority: kAuthority)

```
                                                    
### Acquiring Your First Token (Objective-C)
```objective-c
    [application acquireTokenForScopes:@[@"scope1", @"scope2"]
                       completionBlock:^(MSALResult *result, NSError *error)
    {
        if (!error)
        {
            // You'll want to get the user identifier to retrieve and reuse the user
            // for later acquireToken calls
            NSString *userIdentifier = result.user.userIdentifier;
            
            NSString *accessToken = result.accessToken;
        }
        else
        {
            // Check the error
        }
    }]
```

### Acquiring Your First Token (Swift)

```swift
    application.acquireToken(forScopes: kScopes) { (result, error) in
                
        if error == nil {
                        
            // You'll want to get the user identifier to retrieve and reuse the user
            // for later acquireToken calls

            userIdentifier = result.user.userIdentifier
            accessToken = result.accessToken
            
        } else {
                // Check error
        }
    }
```

### Silently Acquiring an Updated Token (Objective C)
```objective-c
    NSError *error = nil;
    MSALUser *user = [application userForIdentifier:userIdentifier error:&error];
    if (!user)
    {
        // handle error
        return;
    }
    
    [application acquireTokenSilentForScopes:@[@"scope1"]
                                        user:user
                             completionBlock:^(MSALResult *result, NSError *error)
    {
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
    }]
```

### Silently Acquiring an Updated Token (Swift)
```swift

    application.acquireTokenSilent(forScopes: kScopes, user: user) { (result, error) in
    
        if error == nil {

          accessToken = result!.accessToken
                        
        } else {
                        
            if (error! as NSError).code == MSALErrorCode.interactionRequired.rawValue {

               // Interactive auth will be required
            }
        }
    }

```

### Responding to an Interaction Required Error
Occasionally user interaction will be required to get a new access token, when this occurs you will receive a `MSALErrorInteractionRequired` error when trying to silently acquire a new token. In those cases call `acquireToken:` with the same user and scopes as the failing `acquireTokenSilent:` call. It is recommending to display a status message to the user in an unobtrusive way first before using an interactive `acquireToken:` call.
```objective-c
    [application acquireTokenForScopes:@["scope1"]
                                  user:user
                             completionBlock:^(MSALResult *result, NSError *error) { }];
```



Copyright (c) Microsoft Corporation.  All rights reserved. Licensed under the MIT License (the "License");
