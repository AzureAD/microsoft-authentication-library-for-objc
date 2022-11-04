//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <Foundation/Foundation.h>
#import "MSALParameters.h"

NS_ASSUME_NONNULL_BEGIN

@class MSALWebviewParameters;

@interface MSALSignoutParameters : MSALParameters

/**
 A copy of the configuration which was provided in the initializer.
 */
@property (nonatomic, readonly, copy) MSALWebviewParameters *webviewParameters;

/**
  Specifies whether signout should also open the browser and send a network request to the end_session_endpoint.
  NO by default.
 */
@property (nonatomic) BOOL signoutFromBrowser;

/*
  Removes account from the keychain with either com.microsoft.adalcache shared group by default or the one provided when configuring MSALPublicClientApplication.

  This is a destructive action and will remove the SSO state from all apps sharing the same cache!
  It's intended to be used only as a way to achieve GDPR compliance and make sure all user artifacts are cleaned on user sign out.
  It's not intended to be used as a way to reset or fix token cache.
  Please make sure end user is shown UI and/or warning before this flag gets set to YES.
  NO by default.
*/
@property (nonatomic) BOOL wipeAccount;

/*
  When flag is set, following should happen:
    - Wipe all known universal cache locations regardless of the clientId, account etc. Should include all tokens and metadata for any cloud.
    - Wipe all known legacy ADAL cache locations regardless of the clientId, account etc.
    - MSALWipeCacheForAllAccountsConfig contains a list of additional locations for partner caches to be wiped (e.g. Teams, VisualStudio etc). Wipe operation should wipe out all those additional locations. This file includes "display identifier" of the location (e.g. Teams cache), and precise identifiers like kSecAttrAccount, kSecAttrService etc.
    - If SSO extension is present, call SSO extension wipe operation. Wipe operation should only be allowed to the privileged applications like Intune CP on macOS or Authenticator on iOS.
    - Failing any of the steps should return error back to the app including exact locations and apps that failed to be cleared.
  NO by default.
  This is a dangerous operation.
*/
@property (nonatomic) BOOL wipeCacheForAllAccounts;

/**
 Initialize MSALSignoutParameters with web parameters.
 
 @param webviewParameters   User Interface configuration that MSAL uses when getting a token interactively or authorizing an end user.
 */
- (instancetype)initWithWebviewParameters:(MSALWebviewParameters *)webviewParameters;

@end

NS_ASSUME_NONNULL_END
