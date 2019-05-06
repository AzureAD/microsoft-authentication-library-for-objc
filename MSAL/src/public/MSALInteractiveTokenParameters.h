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

#import "MSALTokenParameters.h"

NS_ASSUME_NONNULL_BEGIN

@class WKWebView;

/*!
 Token parameters to be used in interactive flow.
 */
@interface MSALInteractiveTokenParameters : MSALTokenParameters

/*!
 A specific prompt type for the interactive authentication flow.
 */
@property (nonatomic) MSALPromptType promptType;

/*!
 A loginHint (usually an email) to pass to the service at the
 beginning of the interactive authentication flow. The account returned
 in the completion block is not guaranteed to match the loginHint.
 */
@property (nonatomic, nullable) NSString *loginHint;

/*!
 Key-value pairs to pass to the authentication server during
 the interactive authentication flow. This should not be url-encoded value.
 */
@property (nonatomic, nullable) NSDictionary <NSString *, NSString *> *extraQueryParameters;

/*!
 Permissions you want the account to consent to in the same
 authentication flow, but won't be included in the returned
 access token.
 */
@property (nonatomic, nullable) NSArray<NSString *> *extraScopesToConsent;

/*!
 Initialize a MSALInteractiveTokenParameters with scopes.
 
 @param scopes      Permissions you want included in the access token received
                    in the result in the completionBlock. Not all scopes are
                    gauranteed to be included in the access token returned.
 */
- (instancetype)initWithScopes:(NSArray<NSString *> *)scopes NS_DESIGNATED_INITIALIZER;

#if TARGET_OS_IPHONE
/*!
 Modal presentation style for displaying authentication web content.
 */
@property (nullable, weak, nonatomic) UIViewController *parentViewController;
@property (nonatomic) UIModalPresentationStyle presentationStyle;
#endif

/*!
 A specific webView type for the interactive authentication flow.
 By default, it will be set to MSALGlobalConfig.defaultWebviewType.
 */
@property (nonatomic) MSALWebviewType webviewType;
/*!
 For a webviewType MSALWebviewTypeWKWebView, custom WKWebView can be passed on.
 Web content will be rendered onto this view.
 Observe strings declared in MSALPublicClientStatusNotifications to know when to dismiss.
 */
@property (nonatomic, nullable) WKWebView *customWebview;

@end

NS_ASSUME_NONNULL_END
