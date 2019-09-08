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

NS_ASSUME_NONNULL_BEGIN

@class MSALHTTPConfig;
@class MSALTelemetryConfig;
@class MSALLoggerConfig;
@class MSALCacheConfig;

/**
    MSAL configuration interface responsible for globally applicable authentication properties.
    @note Configuration changes inside MSALGlobalConfig will apply to all instances of `MSALPublicClientApplication`
*/
@interface MSALGlobalConfig : NSObject

#pragma mark - Configuration options

/**
    Network configuration, refer to `MSALHTTPConfig` for more details
 */
@property (class, readonly) MSALHTTPConfig *httpConfig;

/**
    Telemetry configurations, refer to `MSALTelemetryConfig` for more details
 */
@property (class, readonly) MSALTelemetryConfig *telemetryConfig;

/**
    Logger configurations, refer to `MSALLoggerConfig` for more details
 */
@property (class, readonly) MSALLoggerConfig *loggerConfig;

/**
    The webview selection to be used for authentication.
    By default, it is going to use the following to authenticate.
        - iOS: ASWebAuthenticationSession for iOS 12+, SFAuthenticationSession for iOS11, SFSafariViewController on iOS 10.
        - macOS:  WKWebView
 */
@property (class) MSALWebviewType defaultWebviewType DEPRECATED_MSG_ATTRIBUTE("Use webviewParameters to configure web view type in MSALInteractiveTokenParameters instead (create parameters object and pass it to MSALPublicClientApplication -acquireTokenWithParameters:completionBlock:)");

#if TARGET_OS_IPHONE
/**
    Setting to define MSAL behavior when Microsoft Authenticator application is installed.
    By default, MSAL will always try to use Microsoft Authenticator application when getting a token interactively. 
    Set this property to MSALBrokeredAvailabilityNone to disable this behavior
 */
@property (class) MSALBrokeredAvailability brokerAvailability;
#endif

#pragma mark - Unavailable initializers

/**
    Use class properties instead.
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

/**
    Use class properties instead.
*/
+ (nonnull instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
