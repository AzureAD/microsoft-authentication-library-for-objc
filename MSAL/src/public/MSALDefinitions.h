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

#ifndef MSALDefinitions_h
#define MSALDefinitions_h

@class MSALResult;
@class MSALAccount;

/**
 Levels of logging. Defines the priority of the logged message
 */
typedef NS_ENUM(NSInteger, MSALLogLevel)
{
    /** Disable all logging */
    MSALLogLevelNothing,
    
    /** Default level, prints out information only when errors occur */
    MSALLogLevelError,
    
    /** Warnings only */
    MSALLogLevelWarning,
    
    /** Library entry points, with parameters and various keychain operations */
    MSALLogLevelInfo,
    
    /** API tracing */
    MSALLogLevelVerbose,
    
    /** API tracing */
    MSALLogLevelLast = MSALLogLevelVerbose,
};

/**
 MSAL requires a web browser is required for interactive authentication.
 There are multiple web browsers available to complete authentication.
 MSAL will default to the web browser that provides best security and user experience for a given platform.
 MSALWebviewType allows changing the experience by customizing the configuration to other options for displaying web content
 */
typedef NS_ENUM(NSInteger, MSALWebviewType)
{
#if TARGET_OS_IPHONE
    /**
     For iOS 11 and up, uses AuthenticationSession (ASWebAuthenticationSession or SFAuthenticationSession).
     For older versions, with AuthenticationSession not being available, uses SafariViewController.
     */
    MSALWebviewTypeDefault,
    
    /** Use SFAuthenticationSession/ASWebAuthenticationSession */
    MSALWebviewTypeAuthenticationSession,
    
    /** Use SFSafariViewController for all versions. */
    MSALWebviewTypeSafariViewController,
    
#endif
    /** Use WKWebView */
    MSALWebviewTypeWKWebView,
};

/**
    Controls where would the credentials dialog reside.
    By default, when Microsoft Authenticator application is present on a device, MSAL will try to acquire a token through the Authenticator app
    To disable this behavior, set MSALBrokerAvailability to MSALBrokeredAvailabilityNone
 */

typedef NS_ENUM(NSInteger, MSALBrokeredAvailability)
{
#if TARGET_OS_IPHONE
    /**
    The SDK determines automatically the most suitable option, optimized for user experience.
    E.g. it may invoke another application for a single sign on (Microsoft Authenticator), if such application is present.
    This is the default option.
    */
    MSALBrokeredAvailabilityAuto,
#endif
    
    /**
    The SDK will present a webview within the application. It will not invoke external application.
    */
    MSALBrokeredAvailabilityNone
};

/**
 OIDC prompt parameter  that specifies whether the Authorization Server prompts the End-User for reauthentication and consent.
 */
typedef NS_ENUM(NSUInteger, MSALPromptType)
{
    /**
     If no user is specified the authentication webview will present a list of users currently
     signed in for the user to select among.
     */
    MSALPromptTypeSelectAccount,

    /**
     Require the user to authenticate in the webview
     */
    MSALPromptTypeLogin,
    /**
     Require the user to consent to the current set of scopes for the request.
     */
    MSALPromptTypeConsent,
    /**
     The SSO experience will be determined by the presence of cookies in the webview and account type.
     User won't be prompted unless necessary.
     If multiple users are signed in, select account experience will be presented.
     */
    MSALPromptTypePromptIfNecessary,
    MSALPromptTypeDefault = MSALPromptTypePromptIfNecessary,
};

/**
    The block that gets invoked after MSAL has finished getting a token silently or interactively.
    @param result       Represents information returned to the application after a successful interactive or silent token acquisition. See `MSALResult` for more information.
    @param error         Provides information about error that prevented MSAL from getting a token. See `MSALError` for possible errors.
 */
typedef void (^MSALCompletionBlock)(MSALResult * _Nullable result, NSError * _Nullable error);

/**
    The completion block that will be called when accounts are loaded, or MSAL encountered an error.
 */
typedef void (^MSALAccountsCompletionBlock)(NSArray<MSALAccount *> * _Nullable accounts, NSError * _Nullable error);

/**
 The block that returns a MSAL log message.
 
 @param  level                     The level of the log message
 @param  message                 The message being logged
 @param  containsPII        If the message might contain Personally Identifiable Information (PII)
                         this will be true. Log messages possibly containing PII will not be
                         sent to the callback unless PIllLoggingEnabled is set to YES on the
                         logger.
 
 */
typedef void (^MSALLogCallback)(MSALLogLevel level, NSString * _Nullable message, BOOL containsPII);

/**
 MSAL telemetry callback.
 
 @param event Aggregated telemetry event.
 */
typedef void(^MSALTelemetryCallback)(NSDictionary<NSString *, NSString *> * _Nonnull event);

#endif /* MSALConstants_h */
