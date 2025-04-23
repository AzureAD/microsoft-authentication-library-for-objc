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

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "MSALTokenParameters.h"

NS_ASSUME_NONNULL_BEGIN

@class WKWebView;
@class MSALWebviewParameters;

/**
 Token parameters to be used when MSAL is getting a token interactively.
 */
@interface MSALInteractiveTokenParameters : MSALTokenParameters

#pragma mark - Configuring MSALInteractiveTokenParameters

/**
 A specific prompt type for the interactive authentication flow.
 */
@property (nonatomic) MSALPromptType promptType;

/**
 A loginHint (usually an email) to pass to the service at the
 beginning of the interactive authentication flow. The account returned
 in the completion block is not guaranteed to match the loginHint.
 */
@property (nonatomic, nullable) NSString *loginHint;

/**
 Permissions you want the account to consent to in the same
 authentication flow, but won't be included in the returned
 access token.
 */
@property (nonatomic, nullable) NSArray<NSString *> *extraScopesToConsent;

/**
 A copy of the configuration which was provided in the initializer.
 */
@property (nonatomic, readonly, copy) MSALWebviewParameters *webviewParameters;

/**
 The pre-defined preferred auth method for the interactive request.
 By default, it will be set to MSALPreferredAuthMethod.MSALPreferredAuthMethodNone.
 */
@property (nonatomic) MSALPreferredAuthMethod preferredAuthMethod;

#pragma mark - Constructing MSALInteractiveTokenParameters

/**
 Initializes MSALInteractiveTokenParameters with scopes.
 
 @param scopes      Permissions you want included in the access token received
 in the result in the completionBlock. Not all scopes are
 guaranteed to be included in the access token returned.
 */
- (instancetype)initWithScopes:(NSArray<NSString *> *)scopes NS_UNAVAILABLE;

/**
 Initialize MSALInteractiveTokenParameters with scopes and web parameters.
 
 @param scopes      Permissions you want included in the access token received
 in the result in the completionBlock. Not all scopes are
 guaranteed to be included in the access token returned.
 @param webviewParameters   User Interface configuration that MSAL uses when getting a token interactively or authorizing an end user.
 */
- (instancetype)initWithScopes:(NSArray<NSString *> *)scopes
             webviewParameters:(MSALWebviewParameters *)webviewParameters NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
