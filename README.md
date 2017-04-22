# Microsoft Authentication Library (MSAL) for iOS
=====================================

## Our new SDK is under development!

MSAL for ObjC is in active development, but not yet ready. We encourage you to look at our work in progress and provide feedback! 

**It should not be used in production environments.**

## License

Copyright (c) Microsoft Corporation.  All rights reserved. Licensed under the MIT License (the "License");

## We Value and Adhere to the Microsoft Open Source Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Adding MSAL to your project
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

## Creating an Application Object
Use the client ID from yout app listing when initializing your MSALPublicClientApplication object:
```objective-c
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:@"<your-client-id-here>"
                                                    error:&error];
```
                                                    
## Acquiring Your First Token
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
    }
```

## Silently Acquiring an Updated Token
```objective-c
    NSError *error = nil;
    MSALUser *user = [application userForIdentifier:userIdentifier error:&error];
    if (!user)
    {
        // handle error
        return;
    }
    
    [application acquireTokenSilentForScopes:@["scope1"]
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
    }
```

## Responding to an Interaction Required Error
Occasionally user interaction will be required to get a new access token, when this occurs you will receive a `MSALErrorInteractionRequired` error when trying to silently acquire a new token. In those cases call `acquireToken:` with the same user and scopes as the failing `acquireTokenSilent:` call. It is recommending to display a status message to the user in an unobtrusive way first before using an interactive `acquireToken:` call.
```objective-c
    [application acquireTokenForScopes:@["scope1"]
                                  user:user
                             completionBlock:^(MSALResult *result, NSError *error) { }];
```
