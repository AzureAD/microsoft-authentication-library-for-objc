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

extern NSString *MSALErrorDomain;

/* !

    Following list of keys represents a set of optional
    keys that can be found in error's userInfo that MSAL returns.

    Examples of usage:

    if (error && [error.domain isEqualToString:MSALErrorDomain])
    {
        NSInteger errorCode = error.code; // Get error code
        NSString *oauthError = error.userInfo[MSALOAuthErrorKey]; // Get OAuth2 error code
        NSString *subError = error.userInfo[MSALOAuthSubErrorKey]; // Get sub error
        NSString *httpResponseCode = error.userInfo[MSALHTTPResponseCodeKey]; // Get HTTP response code

        // ....
    }

 */

/*!
    The OAuth error returned by the service.
 */
extern NSString *MSALOAuthErrorKey;

/*!
    The suberror returned by the service.
 */
extern NSString *MSALOAuthSubErrorKey;

/*!
    The extded error description. Note that this string can change ands should
    not be relied upon for any error handling logic.
 */
extern NSString *MSALErrorDescriptionKey;

/*!
 Contains all http headers returned from the http error response
 */
extern NSString *MSALHTTPHeadersKey;

/*!
 Correlation ID used for the request
 */
extern NSString *MSALCorrelationIDKey;

/*!
 Specifies http response code for error cases
 */
extern NSString *MSALHTTPResponseCodeKey;

/*!
 List of scopes that were requested from MSAL, but not granted in the response.

 This can happen in multiple cases:

    * Requested scope is not supported
    * Requested scope is not Recognized (According to OIDC, any scope values used that are not understood by an implementation SHOULD be ignored.)
    * Requested scope is not supported for a particular account (Organizational scopes when it is a consumer account)

 */
extern NSString *MSALDeclinedScopesKey;

/*
 Displayable user id for the particular error if available
 */
extern NSString *MSALDisplayableUserIdKey;

/*!
 List of granted scopes in case some scopes weren't granted (see MSALDeclinedScopesKey for more info)
 */
extern NSString *MSALGrantedScopesKey;

/*!
 If server returned tokens successfully, but response data doesn't pass validation,
 MSAL will return an error and original result in the error userInfo
 */
extern NSString *MSALInvalidResultKey;

/*!
 Broker version that was used for the authentication
 */
extern NSString *MSALBrokerVersionKey;

/*
 Home account id for the particular error if available
 */
extern NSString *MSALHomeAccountIdKey;

typedef NS_ENUM(NSInteger, MSALErrorCode)
{
    /*!
        A required parameter was not provided, or a passed in parameter was
        invalid. See MSALErrorDescriptionKey for more information.
     */
    MSALErrorInvalidParameter = -42000,
    
    /*!
        The required MSAL URL scheme is not registered in the app's info.plist.
        The scheme should be "msal<clientid>"
     
        e.g. an app with the client ID "abcde-12345-vwxyz-67890" would need to
        register the scheme "msalabcde-12345-vwxyz-67890" and add the
        following to the info.plist file:
     
        <key>CFBundleURLTypes</key>
        <array>
            <dict>
                <key>CFBundleTypeRole</key>
                <string>Editor</string>
                <key>CFBundleURLName</key>
                <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
                <key>CFBundleURLSchemes</key>
                <array>
                    <string>msalabcde-12345-vwxyz-67890</string>
                </array>
            </dict>

     */
    MSALErrorRedirectSchemeNotRegistered    = -42001,

    MSALErrorInvalidRequest                 = -42002,
    MSALErrorInvalidClient                  = -42003,
    MSALErrorInvalidGrant                   = -42004,
    MSALErrorInvalidScope                   = -42005,
    MSALErrorUnauthorizedClient             = -42006,
    
    /*!
     The server returned an unexpected http response. For instance, this code
     is returned for 5xx server response when something has gone wrong on the server but the
     server could not be more specific on what the exact problem is.
     */
    MSALErrorUnhandledResponse              = -42007,

    MSALErrorServerDeclinedScopes           = -42008,

    /*! 
        The passed in authority URL does not pass validation.
        If you're trying to use B2C, you must disable authority validation by
        setting validateAuthority of MSALPublicClientApplication to NO.
     */
    MSALErrorFailedAuthorityValidation = -42010,
    
    /*!
        Interaction required errors occur because of a wide variety of errors
        returned by the authentication service. In all cases the proper response
        is to use a MSAL interactive AcquireToken call with the same parameters.
        For more details check MSALOAuthErrorKey and MSALOAuthErrorDescriptionKey
        in the userInfo dictionary.
     */
    MSALErrorInteractionRequired        = -42100,
    MSALErrorMismatchedUser             = -42101,
    MSALErrorNoAuthorizationResponse    = -42102,
    MSALErrorBadAuthorizationResponse   = -42103,
    
    /*!
        The user or application failed to authenticate in the interactive flow.
        Inspect MSALOAuthErrorKey and MSALErrorDescriptionKey in the userInfo
        dictionary for more detailed information about the specific error.
     */
    MSALErrorAuthorizationFailed = -42104,
    
    /*!
        MSAL received a bad token response, it didn't contain an access token or id token.
        Check to make sure your application is consented to get all of the scopes you are asking for.
     */
    MSALErrorBadTokenResponse = -42105,

    /*!
     MSAL requires a non-nil account for the acquire token silent call
     */
    MSALErrorAccountRequired = -42106,
    
    MSALErrorWrapperCacheFailure = -42270,
    
    /*!
        The user cancelled the web auth session by tapping the "Done" button on the
        SFSafariViewController.
     */
    MSALErrorUserCanceled = -42400,
    /*!
        The authentication request was cancelled programmatically.
     */
    MSALErrorSessionCanceled = -42401,
    /*!
        An interactive authentication session is already running with the
        SafariViewController visible. Another authentication session can not be
        launched yet.
     */
    MSALErrorInteractiveSessionAlreadyRunning = -42402,
    /*!
        MSAL could not find the current view controller in the view controller
        heirarchy to display the SFSafariViewController on top of.
     */
    MSALErrorNoViewController = -42403,
    
    /*!
        MSAL tried to open a URL from an extension, which is not allowed.
     */
    MSALErrorAttemptToOpenURLFromExtension = -42404,

    /*!
     MSAL tried to show UI in the extension, which is not allowed.
     */
    MSALErrorUINotSupportedInExtension = -42405,
    
    /*!
        An error ocurred within the MSAL client, inspect the MSALErrorDescriptionKey
        in the userInfo dictionary for more detailed information about the specific
        error.
     */
    MSALErrorInternal = -42500,
    /*!
        The state returned by the server does not match the state that was sent to
        the server at the beginning of the authorization attempt.
     */
    MSALErrorInvalidState = -42501,
    
    /*!
     Response was received in a network call, but the response body was invalid.

     e.g. Response was to be expected a key-value pair with "key1" and
     the json response does not contain "key1" elements
     
     */
    MSALErrorInvalidResponse = -42600,
    
    /*!
     Server returned a refresh token reject response
     */
    MSALErrorRefreshTokenRejected = -42601,
    
    /*!
     Server tried to redirect to non http URL
     */
    MSALErrorNonHttpsRedirect = -42602,

    /*!
        The requested resource is protected by an Intune Conditional Access policy.
        The calling app should integrate the Intune SDK and call the remediateComplianceForIdentity:silent: API,
        please see https://aka.ms/intuneMAMSDK for more information.
     */
    MSALErrorServerProtectionPoliciesRequired = -42603,

    /*!
     User returned manually to the application without completion authentication inside the broker
     */
    MSALErrorBrokerResponseNotReceived      =  -42700,

    /*!
     MSAL cannot read broker resume state. It might be that application removed it, or NSUserDefaults is corrupted.
     */
    MSALErrorBrokerNoResumeStateFound       =  -42701,

    /*!
     MSAL cannot read broker resume state. It is corrupted.
     */
    MSALErrorBrokerBadResumeStateFound      =  -42702,

    /*!
     MSAL cannot read broker resume state. It is saved for a different redirect uri. The app should check its registered schemes.
     */
    MSALErrorBrokerMismatchedResumeState    =  -42703,

    /*!
     Invalid broker response.
     */
    MSALErrorBrokerResponseHashMissing      =  -42704,

    /*!
     Corrupted broker response.
     */
    MSALErrorBrokerCorruptedResponse        =  -42705,

    /*!
     Decryption of broker response failed.
     */
    MSALErrorBrokerResponseDecryptionFailed =  -42706,

    /*!
     Unexpected broker response hash.
     */
    MSALErrorBrokerResponseHashMismatch     =  -42707,

    /*!
     Failed to create broker key.
     */
    MSALErrorBrokerKeyFailedToCreate        =  -42708,

    /*!
     Couldn't read broker key. Maybe broker key got wiped from the keychain.
     */
    MSALErrorBrokerKeyNotFound              =  -42709,

    // Workplace join is required to proceed
    MSALErrorWorkplaceJoinRequired          =  -42710,

    /*!
     Broker returned unreadable result
     */
    MSALErrorBrokerUnknown                  =  -42711
};

