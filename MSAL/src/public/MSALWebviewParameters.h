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
 The view controller to present from. If nil, the current topmost view controller will be used.
 */
@property (nullable, weak, nonatomic) MSALViewController *parentViewController;

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
@property (nonatomic) BOOL prefersEphemeralWebBrowserSession API_AVAILABLE(ios(13.0), macos(10.15));

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
    Creates an instance of MSALWebviewParameters with a provided parentViewController.
    @param parentViewController The view controller to present authorization UI from.
    @note parentViewController is mandatory on iOS 13+. It is strongly recommended on macOS 10.15+ to allow correct presentation of ASWebAuthenticationSession. If parentViewController is not provided on macOS 10.15+, MSAL will use application's keyWindow for presentation
 */
- (nonnull instancetype)initWithParentViewController:(MSALViewController *)parentViewController DEPRECATED_MSG_ATTRIBUTE("Use -initWithAuthPresentationViewController: instead.");;

/**
   Creates an instance of MSALWebviewParameters with a provided parentViewController.
   @param parentViewController The view controller to present authorization UI from.
   @note parentViewController is mandatory on iOS 13+. It is strongly recommended on macOS 10.15+ to allow correct presentation of ASWebAuthenticationSession. If parentViewController is not provided on macOS 10.15+, MSAL will use application's keyWindow for presentation
*/
- (nonnull instancetype)initWithAuthPresentationViewController:(MSALViewController *)parentViewController;


/**
 It is recommended to use the default webview configuration setting provided by a public MSAL API.
 ex:
 WKWebViewConfiguration *defaultWKWebConfig = [MSALWebviewParameters defaultWKWebviewConfiguration];
 WKWebView *embeddedWebview = [[WKWebView alloc] initWithFrame:yourWebview.frame configuration:defaultWKWebConfig];
 */

@property (class, nonatomic, readonly) WKWebViewConfiguration *defaultWKWebviewConfiguration;


#if TARGET_OS_IPHONE

#pragma mark - Unavailable initializers

- (nonnull instancetype)init DEPRECATED_MSG_ATTRIBUTE("Use -initWithAuthPresentationViewController: instead.");

+ (nonnull instancetype)new DEPRECATED_MSG_ATTRIBUTE("Use -initWithAuthPresentationViewController: instead.");

#endif

@end

NS_ASSUME_NONNULL_END
