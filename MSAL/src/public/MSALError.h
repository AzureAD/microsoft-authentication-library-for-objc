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

/**
    The OAuth error returned by the service.
 */
extern NSString *MSALOAuthErrorKey;

/**
    The suberror returned by the service.
 */
extern NSString *MSALOAuthSubErrorKey;

/**
    The extended error description. Note that this string can change and should
    not be relied upon for any error handling logic.
 */
extern NSString *MSALErrorDescriptionKey;

/**
 Internal error code returned together with MSALErrorInternal error.
 */
extern NSString *MSALInternalErrorCodeKey;

/**
 Contains all http headers returned from the http error response
 */
extern NSString *MSALHTTPHeadersKey;

/**
 Correlation ID used for the request
 */
extern NSString *MSALCorrelationIDKey;

/**
 Specifies http response code for error cases
 */
extern NSString *MSALHTTPResponseCodeKey;

/**
 List of scopes that were requested from MSAL, but not granted in the response.

 This can happen in multiple cases:

    * Requested scope is not supported
    * Requested scope is not Recognized (According to OIDC, any scope values used that are not understood by an implementation SHOULD be ignored.)
    * Requested scope is not supported for a particular account (Organizational scopes when it is a consumer account)

 */
extern NSString *MSALDeclinedScopesKey;

/**
 Displayable user id for the particular error if available
 */
extern NSString *MSALDisplayableUserIdKey;

/**
 List of granted scopes in case some scopes weren't granted (see MSALDeclinedScopesKey for more info)
 */
extern NSString *MSALGrantedScopesKey;

/**
 If server returned tokens successfully, but response data doesn't pass validation,
 MSAL will return an error and original result in the error userInfo
 */
extern NSString *MSALInvalidResultKey;

/**
 Broker version that was used for the authentication
 */
extern NSString *MSALBrokerVersionKey;

/**
 Home account id for the particular error if available
 */
extern NSString *MSALHomeAccountIdKey;

/**
 Error domain that MSAL uses for authentication related errors. 
 */
extern NSString *MSALErrorDomain;

/**
 MSALError enum contains all errors that should be considered for handling in runtime.
 */
typedef NS_ENUM(NSInteger, MSALError)
{
    /**
     An unrecoverable error occured either within the MSAL client or on server side.
     Generally, this error cannot be resolved in runtime. Log the error, then inspect the MSALInternalErrorCodeKey in the userInfo dictionary.
     More detailed information about the specific error under MSALInternalErrorCodeKey can be found in MSALInternalError enum.
     */
    MSALErrorInternal                            = -50000,
    
    /**
     Workplace join is required to proceed. Handling of this error is optional.
     */
    MSALErrorWorkplaceJoinRequired               = -50001,
    
    /**
     Interaction required errors occur because of a wide variety of errors
     returned by the authentication service. In all cases the proper response
     is to use a MSAL interactive AcquireToken call with the same parameters.
     For more details check MSALOAuthErrorKey and MSALOAuthErrorDescriptionKey
     in the userInfo dictionary. Handling of this error is required.
     */
    MSALErrorInteractionRequired                 = -50002,
    
    /**
     The request was not fully completed and some scopes were not granted access to.
     This can be caused by a user declining consent on certain scopes.
     For more details check MSALGrantedScopesKey and MSALDeclinedScopesKey
     in the userInfo dictionary. Handling of this error is required.
     */
    MSALErrorServerDeclinedScopes                = -50003,
    
    /**
     The requested resource is protected by an Intune Conditional Access policy.
     The calling app should integrate the Intune SDK and call the remediateComplianceForIdentity:silent: API,
     please see https://aka.ms/intuneMAMSDK for more information. Handling of this error is optional (handle it only
     if you are going to access resources protected by an Intune Conditional Access policy).
     */
    MSALErrorServerProtectionPoliciesRequired    = -50004,
    
    /**
     The user cancelled the web auth session by tapping the "Done" or "Cancel" button in the web browser.
     Handling of this error is optional.
     */
    MSALErrorUserCanceled                        = -50005,
    
    /**
    The server error happens when server returns server_error
     */
    MSALErrorServerError                         = -50006,
};

/**
 MSALInternalError enum contains all possible errors under MSALInternalErrorCodeKey.
 This enum exists only for the debugging and error information purposes, you should not try to recover from these errors in runtime.
 */
typedef NS_ENUM(NSInteger, MSALInternalError)
{
    /**
     A required parameter was not provided, or a passed in parameter was
     invalid. See MSALErrorDescriptionKey for more information.
     */
    MSALInternalErrorInvalidParameter                   = -42000,
    
    /**
     The required MSAL URL scheme is not registered in the app's info.plist.
     The scheme should be "msauth.[my.app.bundleId]"
     
     e.g. an app with the bundle Identifier "com.contoso.myapp" would need to
     register the scheme "msauth.com.contoso.myapp" and add the scheme into its Info.plist under CFBundleURLTypes - CFBundleURLSchemes key
     
     */
    MSALInternalErrorRedirectSchemeNotRegistered        = -42001,
    
    /**
     Protocol error, such as a missing required parameter.
     */
    MSALInternalErrorInvalidRequest                     = -42002,
    
    /**
     Client authentication failed.
     The client credentials aren't valid. To fix, the application administrator updates the credentials.
     */
    MSALInternalErrorInvalidClient                      = -42003,
    
    /**
     The provided grant is invalid or has expired.
     Try a new request to the /authorize endpoint.
     */
    MSALInternalErrorInvalidGrant                       = -42004,
    
    /**
     Invalid scope parameter.
     */
    MSALInternalErrorInvalidScope                       = -42005,
    
    /**
     The client application isn't permitted to request an authorization code.
     This error usually occurs when the client application isn't registered in Azure AD or isn't added to the user's Azure AD tenant. The application can prompt the user with instruction for installing the application and adding it to Azure AD.
     */
    MSALInternalErrorUnauthorizedClient                 = -42006,
    
    /**
     The server returned an unexpected http response. For instance, this code
     is returned for 5xx server response when something has gone wrong on the server but the
     server could not be more specific on what the exact problem is.
     */
    MSALInternalErrorUnhandledResponse                  = -42007,
    
    /**
     An unexpected error occured within the MSAL client.
     */
    MSALInternalErrorUnexpected                         = -42008,
    
    /**
     The passed in authority URL does not pass validation.
     If you're trying to use B2C, you must disable authority validation by
     setting validateAuthority of MSALPublicClientApplication to NO.
     */
    MSALInternalErrorFailedAuthorityValidation          = -42010,
    
    MSALInternalErrorMismatchedUser                     = -42101,
    
    /**
      Found multiple accounts in cache. Please use getAccounts: API which supports multiple accounts.
     */
    MSALInternalErrorAmbiguousAccount                   = -42102,
    
    /**
     The user or application failed to authenticate in the interactive flow.
     Inspect MSALOAuthErrorKey and MSALErrorDescriptionKey in the userInfo
     dictionary for more detailed information about the specific error.
     */
    MSALInternalErrorAuthorizationFailed                = -42104,
    
    /**
     MSAL requires a non-nil account for the acquire token silent call
     */
    MSALInternalErrorAccountRequired                    = -42106,
    
    /**
     The authentication request was cancelled programmatically.
     */
    MSALInternalErrorSessionCanceled                    = -42401,
    
    /**
     An interactive authentication session is already running with the
     web browser visible. Another authentication session can not be
     launched yet.
     */
    MSALInternalErrorInteractiveSessionAlreadyRunning   = -42402,
    
    /**
     MSAL could not find the current view controller in the view controller
     heirarchy to display the web browser on top of.
     */
    MSALInternalErrorNoViewController                   = -42403,
    
    /**
     MSAL tried to open a URL from an extension, which is not allowed.
     */
    MSALInternalErrorAttemptToOpenURLFromExtension      = -42404,
    
    /**
     MSAL tried to show UI in the extension, which is not allowed.
     */
    MSALInternalErrorUINotSupportedInExtension          = -42405,
    
    /**
     The state returned by the server does not match the state that was sent to
     the server at the beginning of the authorization attempt.
     */
    MSALInternalErrorInvalidState                       = -42501,
    
    /**
     Response was received in a network call, but the response body was invalid.
     
     e.g. Response was to be expected a key-value pair with "key1" and
     the json response does not contain "key1" elements
     
     */
    MSALInternalErrorInvalidResponse                    = -42600,
    
    /**
     Server tried to redirect to non https URL.
     */
    MSALInternalErrorNonHttpsRedirect                   = -42602,
    
    /**
     User returned manually to the application without completion authentication inside the broker
     */
    MSALInternalErrorBrokerResponseNotReceived          = -42700,
    
    /**
     MSAL cannot read broker resume state. It might be that application removed it, or NSUserDefaults is corrupted.
     */
    MSALInternalErrorBrokerNoResumeStateFound           = -42701,
    
    /**
     MSAL cannot read broker resume state. It is corrupted.
     */
    MSALInternalErrorBrokerBadResumeStateFound          = -42702,
    
    /**
     MSAL cannot read broker resume state. It is saved for a different redirect uri. The app should check its registered schemes.
     */
    MSALInternalErrorBrokerMismatchedResumeState        = -42703,
    
    /**
     Invalid broker response.
     */
    MSALInternalErrorBrokerResponseHashMissing          = -42704,
    
    /**
     Corrupted broker response.
     */
    MSALInternalErrorBrokerCorruptedResponse            = -42705,
    
    /**
     Decryption of broker response failed.
     */
    MSALInternalErrorBrokerResponseDecryptionFailed     = -42706,
    
    /**
     Unexpected broker response hash.
     */
    MSALInternalErrorBrokerResponseHashMismatch         = -42707,
    
    /**
     Failed to create broker key.
     */
    MSALInternalErrorBrokerKeyFailedToCreate            = -42708,
    
    /**
     Couldn't read broker key. Maybe broker key got wiped from the keychain.
     */
    MSALInternalErrorBrokerKeyNotFound                  = -42709,
    
    /**
     Broker returned unreadable result.
     */
    MSALInternalErrorBrokerUnknown                      = -42711,
    
    /**
     Failed to write broker application token.
     */
    MSALInternalErrorBrokerApplicationTokenWriteFailed  = -42712,
    
    /**
     Failed to read broker application token.
     */
    MSALInternalErrorBrokerApplicationTokenReadFailed   = -42713,
    
    /**
     Broker is either not found on device or not available for this configuration.
    */
    MSALInternalBrokerNotAvailable                      = -42714,
    
    /**
     JIT - Link - Timeout while waiting for server confirmation.
    */
    MSALInternalErrorJITLinkServerConfirmationTimeout   = -42714,
    
    /**
     JIT - Link - Error while waiting for server confirmation
     */
    MSALInternalErrorJITLinkServerConfirmationError     =   -42715,
    
    /**
     JIT - Link - Error while acquiring intune token
     */
    MSALInternalErrorJITLinkAcquireTokenError           =   -42716,
    
    /**
     JIT - Link - Token acquired for wrong tenant
     */
    MSALInternalErrorJITLinkTokenAcquiredWrongTenant    =   -42717,
    
    /**
     JIT - Link - Error during linking
     */
    MSALInternalErrorJITLinkError                       =   -42718,
    
    /**
     JIT - Compliance Check - Device not compliant
     */
    MSALInternalErrorJITComplianceCheckResultNotCompliant =   -42719,
    
    /**
     JIT - Compliance Check - CP timeout
     */
    MSALInternalErrorJITComplianceCheckResultTimeout    =   -42720,
    
    /**
     JIT - Compliance Check - Result unknown
     */
    MSALInternalErrorJITComplianceCheckResultUnknown    =   -42721,

    /**
     JIT - JIT - Compliance Check - Invalid linkPayload from SSO configuration
     */
    MSALErrorJITComplianceCheckInvalidLinkPayload       =   -42722,

    /**
     JIT - Compliance Check - Could not create compliance check web view controller
     */
    MSALErrorJITComplianceCheckCreateController         =   -42723,

    /**
     JIT - Link - LinkConfig not found
     */
    MSALErrorJITLinkConfigNotFound                      =   -42724,

    /**
     JIT - Link - Invalid LinkTokenConfig
     */
    MSALErrorJITInvalidLinkTokenConfig                  =   -42725,

    /**
     JIT - WPJ - Device Registration Failed
     */
    MSALErrorJITWPJDeviceRegistrationFailed             =   -42726,

    /**
     JIT - WPJ - AccountIdentifier is nil
     */
    MSALErrorJITWPJAccountIdentifierNil                 =   -42727,

    /**
     JIT - WPJ - Failed to acquire broker token
     */
    MSALErrorJITWPJAcquireTokenError                    =   -42728,
    
    /**
     JIT - Retry JIT process (WPJ or Link)
     */
    MSALErrorJITRetryRequired                           = -42729,
    
    /**
     JIT - Unexpected status received from webCP troubleshooting flow
     */
    MSALErrorJITUnknownStatusWebCP                      = -42730,

    /**
     JIT - Troubleshooting flow needed
     */
    MSALErrorJITTroubleshootingRequired                 = -42730,

    /**
     JIT - Troubleshooting - Could not create web view controller
     */
    MSALErrorJITTroubleshootingCreateController         = -42731,

    /**
     JIT - Troubleshooting - Result unknown
     */
    MSALErrorJITTroubleshootingResultUnknown         = -42731,
    
    /**
     JIT - Troubleshooting - Acquire token error
     */
    MSALErrorJITTroubleshootingAcquireToken          = -42732,
    
};
