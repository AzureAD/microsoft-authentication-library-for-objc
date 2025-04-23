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
#import <WebKit/WebKit.h>

#if TARGET_OS_IPHONE
typedef UIViewController    MSALViewController;
#else
typedef NSViewController    MSALViewController;
#endif

NS_ASSUME_NONNULL_BEGIN

/**
    User Interface configuration that MSAL uses when getting a token interactively or authorizing an end user.
 */
@interface MSALWebviewParameters : NSObject <NSCopying>

#pragma mark - Configuration options

/**
 The view controller to present from. If nil is provided, or if the view controller's view is not attached to a window (i.e., parentViewController.view.window is nil), MSAL will return an error and will not proceed with authentication.
 A valid parentViewController with its view attached to a valid window is required to proceed with authentication.
 */
@property (nonatomic, strong, nonnull) MSALViewController *parentViewController;

#if TARGET_OS_IPHONE

/**
 Modal presentation style for displaying authentication web content.
 Note that presentationStyle has no effect when webviewType == MSALWebviewType.MSALWebviewTypeDefault or
 webviewType == MSALWebviewType.MSALWebviewTypeAuthenticationSession.
 */
@property (nonatomic) UIModalPresentationStyle presentationStyle;

#endif

/**
 A Boolean value that indicates whether the ASWebAuthenticationSession should ask the browser for a private authentication session.
 The value of this property is false by default. For more info see here: https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession/3237231-prefersephemeralwebbrowsersessio?language=objc
 */
@property (nonatomic) BOOL prefersEphemeralWebBrowserSession;

/**
 A specific webView type for the interactive authentication flow.
 By default, it will be set to MSALGlobalConfig.defaultWebviewType.
 */
@property (nonatomic) MSALWebviewType webviewType;

/**
 For a webviewType MSALWebviewTypeWKWebView, custom WKWebView can be passed on.
 Web content will be rendered onto this view.
 Observe strings declared in MSALPublicClientStatusNotifications to know when to dismiss.
 */
@property (nonatomic, nullable) WKWebView *customWebview;

#pragma mark - Constructing MSALWebviewParameters

/**
   Creates an instance of MSALWebviewParameters with the provided parentViewController.
   @param parentViewController The view controller to present authorization UI from.
   @note parentViewController is mandatory on iOS 13+  and macOS 10.15+. If nil is provided, or if the view controller's view is not attached to a window (i.e., parentViewController.view.window is nil), MSAL will return an error and authentication will not proceed. A valid parentViewController with its view attached to a valid window is required to proceed with authentication.
*/
- (nonnull instancetype)initWithAuthPresentationViewController:(nonnull MSALViewController *)parentViewController;


/**
 It is recommended to use the default webview configuration setting provided by a public MSAL API.
 ex:
 WKWebViewConfiguration *defaultWKWebConfig = [MSALWebviewParameters defaultWKWebviewConfiguration];
 WKWebView *embeddedWebview = [[WKWebView alloc] initWithFrame:yourWebview.frame configuration:defaultWKWebConfig];
 */

@property (class, nonatomic, readonly) WKWebViewConfiguration *defaultWKWebviewConfiguration;

#pragma mark - Unavailable initializers

/**
   @note Use `[MSALWebviewParameters initWithAuthPresentationViewController:]` instead
*/
- (nonnull instancetype)init NS_UNAVAILABLE;

/**
   @note Use `[MSALWebviewParameters initWithAuthPresentationViewController:]` instead
*/
+ (nonnull instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
