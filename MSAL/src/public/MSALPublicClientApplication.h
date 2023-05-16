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
#import "MSALPublicClientApplicationConfig.h"
#import "MSALGlobalConfig.h"

@class MSALResult;
@class MSALAccount;
@class MSALTokenRequest;
@class MSALAuthority;
@class MSALSilentTokenParameters;
@class MSALInteractiveTokenParameters;
@class MSALClaimsRequest;
@class MSALAccountEnumerationParameters;
@class MSALWebviewParameters;
@class MSALSignoutParameters;
@class WKWebView;
@class MSALParameters;

/**
    Representation of OAuth 2.0 Public client application. Create an instance of this class to acquire tokens.
    One instance of MSALPublicClientApplication can be used to interact with multiple AAD clouds, and tenants, without needing to create a new instance for each authority. For most apps, one MSALPublicClientApplication instance is sufficient.

    To create an instance of the MSALPublicClientApplication, first create an instance `MSALPublicClientApplicationConfig`.
    Setup  `MSALPublicClientApplicationConfig` with needed configuration, and pass it to the `[MSALPublicClientApplication initWithConfiguration:error:]` initializer.

    For example:

    <pre>
    NSError *msalError = nil;

    MSALPublicClientApplicationConfig *config =
            [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"your-client-id-here"];

    MSALPublicClientApplication *application =
            [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&msalError];
    </pre>

*/
@interface MSALPublicClientApplication : NSObject

#pragma mark - Configuration

/**
    A copy of the configuration which was provided in the initializer.
    Any changes to mutable properties on the configuration object will not affect the behavior of the Public Cilent Application.
    Parameter to be used to configure MSALPublicClientApplication.
    It contains all values to be used in the instance and is a superset of all properties
    known to this class.
 */
@property (atomic, readonly, nonnull) MSALPublicClientApplicationConfig *configuration;

/**
    When set to YES (default), MSAL will compare the application's authority against well-known URLs
    templates representing well-formed authorities. It is useful when the authority is obtained at
    run time to prevent MSAL from displaying authentication prompts from malicious pages.
 */
@property (atomic) BOOL validateAuthority DEPRECATED_MSG_ATTRIBUTE("Use knowAuthorities in MSALPublicClientApplicationConfig instead (create your config and pass it to -initWithConfiguration:error:)");

/**
 The webview type to be used for authorization.
 */
@property MSALWebviewType webviewType DEPRECATED_MSG_ATTRIBUTE("Use webviewParameters to configure web view type in MSALInteractiveTokenParameters instead (create parameters object and pass it to -acquireTokenWithParameters:completionBlock:)");

/**
 Passed in webview to display web content when webviewSelection is set to MSALWebviewTypeWKWebView.
 For iOS, this will be ignored if MSALWebviewTypeSystemDefault is chosen.
 */
@property (atomic, nullable) WKWebView *customWebview DEPRECATED_MSG_ATTRIBUTE("Use webviewParameters to configure custom web view in MSALInteractiveTokenParameters instead (create parameters object and pass it to -acquireTokenWithParameters:completionBlock:)");

#pragma mark - Initializing MSALPublicClientApplication

/**
 Initialize a MSALPublicClientApplication with a given configuration
 
 @note It is important to configure your MSALPublicClientApplicationConfig object before calling MSALPublicClientApplication's initializer.
 MSALPublicClientApplication makes a copy of the configuration object you provide on initialization.
 Once configured, MSALPublicClientApplication object ignores any changes you make to the MSALPublicClientApplicationConfig object.
 
 @param  config       Configuration for PublicClientApplication
 @param  error        The error that occurred creating the application object, if any (optional)
 */
- (nullable instancetype)initWithConfiguration:(nonnull MSALPublicClientApplicationConfig *)config
                                         error:(NSError * _Nullable __autoreleasing * _Nullable)error;

/**
    Initialize a MSALPublicClientApplication with a given clientID
 
    @param  clientId    The clientID of your application, you should get this from the app portal.
    @param  error       The error that occurred creating the application object, if any (optional)
 */
- (nullable instancetype)initWithClientId:(nonnull NSString *)clientId
                                    error:(NSError * _Nullable __autoreleasing * _Nullable)error;
/**
    Initialize a MSALPublicClientApplication with a given clientID and authority
 
    @param  clientId    The clientID of your application, you should get this from the app portal.
    @param  authority   Authority indicating a directory that MSAL can use to obtain tokens. In Azure AD
                        it is of the form https://authority_instance/authority_tenant, where authority_instance is the
                        directory host (e.g. https://login.microsoftonline.com) and authority_tenant is a
                        identifier within the directory itself (e.g. a domain associated to the
                        tenant, such as contoso.onmicrosoft.com, or the GUID representing the
                        TenantID property of the directory)
    @param  error       The error that occurred creating the application object, if any, if you're
                        not interested in the specific error pass in nil.
 */
- (nullable instancetype)initWithClientId:(nonnull NSString *)clientId
                                authority:(nullable MSALAuthority *)authority
                                    error:(NSError * _Nullable __autoreleasing * _Nullable)error DEPRECATED_MSG_ATTRIBUTE("Use -initWithConfiguration:error: instead");

/**
 Initialize a MSALPublicClientApplication with a given clientID, authority and redirectUri

 @param  clientId       The clientID of your application, you should get this from the app portal.
 @param  authority      Authority indicating a directory that MSAL can use to obtain tokens. In Azure AD
                        it is of the form https://authority_instance/authority_tenant, where authority_instance is the
                        directory host (e.g. https://login.microsoftonline.com) and authority_tenant is a
                        identifier within the directory itself (e.g. a domain associated to the
                        tenant, such as contoso.onmicrosoft.com, or the GUID representing the
                        TenantID property of the directory)
 @param  redirectUri    The redirect URI of the application
 @param  error          The error that occurred creating the application object, if any, if you're
                        not interested in the specific error pass in nil.
 */
- (nullable instancetype)initWithClientId:(nonnull NSString *)clientId
                                authority:(nullable MSALAuthority *)authority
                              redirectUri:(nullable NSString *)redirectUri
                                    error:(NSError * _Nullable __autoreleasing * _Nullable)error DEPRECATED_MSG_ATTRIBUTE("Use -initWithConfiguration:error: instead");

#if TARGET_OS_IPHONE

/**
 Initialize a MSALPublicClientApplication with a given clientID, authority, keychain group and redirect uri
 
 @param  clientId       The clientID of your application, you should get this from the app portal.
 @param  keychainGroup  The keychain sharing group to use for the token cache. (optional)
                        If you provide this key, you MUST add the capability to your Application Entilement.
 @param  authority      Authority indicating a directory that MSAL can use to obtain tokens. In Azure AD
                        it is of the form https://<instance/<tenant>, where <instance> is the
                        directory host (e.g. https://login.microsoftonline.com) and <tenant> is a
                        identifier within the directory itself (e.g. a domain associated to the
                        tenant, such as contoso.onmicrosoft.com, or the GUID representing the
                        TenantID property of the directory)
 @param  redirectUri    The redirect URI of the application
 @param  error          The error that occurred creating the application object, if any, if you're
                        not interested in the specific error pass in nil.
 */
- (nullable instancetype)initWithClientId:(nonnull NSString *)clientId
                            keychainGroup:(nullable NSString *)keychainGroup
                                authority:(nullable MSALAuthority *)authority
                              redirectUri:(nullable NSString *)redirectUri
                                    error:(NSError * _Nullable __autoreleasing * _Nullable)error DEPRECATED_MSG_ATTRIBUTE("Use -initWithConfiguration:error: instead");
#endif

/**
 Returns an array of all accounts visible to this application.

 @param  error      The error that occured trying to retrieve accounts, if any, if you're
                    not interested in the specific error pass in nil.
 */

- (nullable NSArray <MSALAccount *> *)allAccounts:(NSError * _Nullable __autoreleasing * _Nullable)error;

/**
 Returns account for the given home identifier (received from an account object returned in a previous acquireToken call)

 @param  error      The error that occured trying to get the accounts, if any, if you're
                    not interested in the specific error pass in nil.
 */
- (nullable MSALAccount *)accountForHomeAccountId:(nonnull NSString *)homeAccountId
                                            error:(NSError * _Nullable __autoreleasing * _Nullable)error DEPRECATED_MSG_ATTRIBUTE("Use -accountForIdentifier:error: instead");

/**
 Returns account for the given account identifier (received from an account object returned in a previous acquireToken call)
 
 @param  error      The error that occured trying to get the accounts, if any, if you're
                    not interested in the specific error pass in nil.
 */
- (nullable MSALAccount *)accountForIdentifier:(nonnull NSString *)identifier
                                         error:(NSError * _Nullable __autoreleasing * _Nullable)error;

/**
 Returns account for the given account identifying parameters (received from an account object returned in a previous acquireToken call)
 
 @param  error      The error that occured trying to get the accounts, if any, if you're
                    not interested in the specific error pass in nil.
 */
- (nullable NSArray<MSALAccount *> *)accountsForParameters:(nonnull MSALAccountEnumerationParameters *)parameters
                                                     error:(NSError * _Nullable __autoreleasing * _Nullable)error;


/**
 Returns account for for the given username (received from an account object returned in a previous acquireToken call or ADAL)

 @param  username    The displayable value in UserPrincipleName(UPN) format
 @param  error       The error that occured trying to get the accounts, if any, if you're
                     not interested in the specific error pass in nil.
 */
- (nullable MSALAccount *)accountForUsername:(nonnull NSString *)username
                                       error:(NSError * _Nullable __autoreleasing * _Nullable)error;

/**
    Returns an array of accounts visible to this application and filtered by authority.
 
    @param  completionBlock     The completion block that will be called when accounts are loaded, or MSAL encountered an error.
 */
- (void)allAccountsFilteredByAuthority:(nonnull MSALAccountsCompletionBlock)completionBlock DEPRECATED_MSG_ATTRIBUTE("Use other synchronous account retrieval API instead.");

/**
    Returns account for the given account identifying parameters including locally cached accounts and accounts from the SSO extension
    Accounts from SSO extension are only available on iOS 13+ and macOS 10.15+. On earlier versions, this method will return same results as a local account query.

    @param  completionBlock     The completion block that will be called when accounts are loaded, or MSAL encountered an error.
*/
- (void)accountsFromDeviceForParameters:(nonnull MSALAccountEnumerationParameters *)parameters
                        completionBlock:(nonnull MSALAccountsCompletionBlock)completionBlock;

#pragma mark - Handling MSAL responses

#if TARGET_OS_IPHONE
/**
    Ask MSAL to handle a URL response.
    
    @param   response   URL response from your application delegate's openURL handler into
                        MSAL for web authentication sessions
    @return  YES if URL is a response to a MSAL web authentication session and handled,
             NO otherwise.
 */
+ (BOOL)handleMSALResponse:(nonnull NSURL *)response DEPRECATED_MSG_ATTRIBUTE("Use -handleMSALResponse:sourceApplication: method instead.");

/**
 Ask MSAL to handle a URL response.

 @param   response              URL response from your application delegate's openURL handler for MSAL web or brokered authentication sessions
 @param   sourceApplication     The application that opened your app with that URL. Can be retrieved from options by UIApplicationOpenURLOptionsSourceApplicationKey key.
                                See more info here: https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623112-application?language=objc
 @return  YES if URL is a response to a MSAL web or brokered session and handled, NO otherwise.
 */
+ (BOOL)handleMSALResponse:(nonnull NSURL *)response sourceApplication:(nullable NSString *)sourceApplication;
#endif

/**
    Cancels any currently running interactive web authentication session, resulting
    in the authorization UI being dismissed and the acquireToken request ending
    in a cancelation error.
 */
+ (BOOL)cancelCurrentWebAuthSession;

#pragma mark - Getting a token interactively

/**
 Acquire a token for a provided parameters using interactive authentication.
 
 @param  parameters Parameters used for interactive authentication.
 @param  completionBlock The completion block that will be called when the authentication
 flow completes, or encounters an error.
 */
- (void)acquireTokenWithParameters:(nonnull MSALInteractiveTokenParameters *)parameters
                   completionBlock:(nonnull MSALCompletionBlock)completionBlock;

/**
    Acquire a token for a new account using interactive authentication
 
    @param  scopes          Permissions you want included in the access token received
                            in the result in the completionBlock. Not all scopes are
                            guaranteed to be included in the access token returned.
    @param  completionBlock The completion block that will be called when the authentication
                            flow completes, or encounters an error.
 */
- (void)acquireTokenForScopes:(nonnull NSArray<NSString *> *)scopes
              completionBlock:(nonnull MSALCompletionBlock)completionBlock DEPRECATED_MSG_ATTRIBUTE("Use -acquireTokenWithParameters:completionBlock instead");

#pragma mark - Getting a token interactively with a Login Hint


/**
    Acquire a token for a new account using interactive authentication
 
    @param  scopes          Permissions you want included in the access token received
                            in the result in the completionBlock. Not all scopes are
                            guaranteed to be included in the access token returned.
    @param  loginHint       A loginHint (usually an email) to pass to the service at the
                            beginning of the interactive authentication flow. The account returned
                            in the completion block is not guaranteed to match the loginHint.
    @param  completionBlock The completion block that will be called when the authentication
                            flow completes, or encounters an error.
 */
- (void)acquireTokenForScopes:(nonnull NSArray<NSString *> *)scopes
                    loginHint:(nullable NSString *)loginHint
              completionBlock:(nonnull MSALCompletionBlock)completionBlock DEPRECATED_MSG_ATTRIBUTE("Use -acquireTokenWithParameters:completionBlock instead");

#pragma mark - Acquire Token for a specific Account

/**
    Acquire a token interactively for an existing account. This is typically used after receiving
    a MSALErrorInteractionRequired error.
 
    @param  scopes          Permissions you want included in the access token received
                            in the result in the completionBlock. Not all scopes are
                            guaranteed to be included in the access token returned.
    @param  account         An account object retrieved from the application object that the
                            interactive authentication flow will be locked down to.
    @param  completionBlock The completion block that will be called when the authentication
                            flow completes, or encounters an error.
 */
- (void)acquireTokenForScopes:(nonnull NSArray<NSString *> *)scopes
                      account:(nullable MSALAccount *)account
              completionBlock:(nonnull MSALCompletionBlock)completionBlock DEPRECATED_MSG_ATTRIBUTE("Use -acquireTokenWithParameters:completionBlock instead");

/**
 Acquire a token interactively for an existing account. This is typically used after receiving
 a MSALErrorInteractionRequired error.
 
 @param  scopes                 Permissions you want included in the access token received
                                in the result in the completionBlock. Not all scopes are
                                guaranteed to be included in the access token returned.
 @param  account                An account object retrieved from the application object that the
                                interactive authentication flow will be locked down to.
 @param  promptType             A prompt type for the interactive authentication flow
 @param  extraQueryParameters   Key-value pairs to pass to the authentication server during
                                the interactive authentication flow. This should not be url-encoded value.
 @param  completionBlock        The completion block that will be called when the authentication
                                flow completes, or encounters an error.
 */
- (void)acquireTokenForScopes:(nonnull NSArray<NSString *> *)scopes
                      account:(nullable MSALAccount *)account
                   promptType:(MSALPromptType)promptType
         extraQueryParameters:(nullable NSDictionary <NSString *, NSString *> *)extraQueryParameters
              completionBlock:(nonnull MSALCompletionBlock)completionBlock DEPRECATED_MSG_ATTRIBUTE("Use -acquireTokenWithParameters:completionBlock instead");

#pragma mark - Acquire Token Silent

/**
 Acquire a token silently for a provided parameters.
 
 @param  parameters Parameters used for silent authentication.
 @param  completionBlock The completion block that will be called when the authentication
 flow completes, or encounters an error.
 */
- (void)acquireTokenSilentWithParameters:(nonnull MSALSilentTokenParameters *)parameters
                         completionBlock:(nonnull MSALCompletionBlock)completionBlock;

/**
    Acquire a token silently for an existing account.
 
    @param  scopes          Permissions you want included in the access token received
                            in the result in the completionBlock. Not all scopes are
                            guaranteed to be included in the access token returned.
    @param  account         An account object retrieved from the application object that the
                            interactive authentication flow will be locked down to.
    @param  completionBlock The completion block that will be called when the authentication
                            flow completes, or encounters an error.
 */
- (void)acquireTokenSilentForScopes:(nonnull NSArray<NSString *> *)scopes
                            account:(nonnull MSALAccount *)account
                    completionBlock:(nonnull MSALCompletionBlock)completionBlock DEPRECATED_MSG_ATTRIBUTE("Use -acquireTokenSilentWithParameters:completionBlock instead");

/**
    Acquire a token silently for an existing account.
 
    @param  scopes                  Permissions you want included in the access token received
                                    in the result in the completionBlock. Not all scopes are
                                    guaranteed to be included in the access token returned.
    @param  account                 An account object retrieved from the application object that the
                                    interactive authentication flow will be locked down to.
    @param  authority               Authority indicating a directory that MSAL can use to obtain tokens.
                                    Azure AD it is of the form https://authority_instance/authority_tenant, where
                                    authority_instance is the directory host
                                    (e.g. https://login.microsoftonline.com) and authority_tenant is a
                                    identifier within the directory itself (e.g. a domain associated
                                    to the tenant, such as contoso.onmicrosoft.com, or the GUID
                                    representing the TenantID property of the directory)
    @param  completionBlock         The completion block that will be called when the authentication
                                    flow completes, or encounters an error.
 */
- (void)acquireTokenSilentForScopes:(nonnull NSArray<NSString *> *)scopes
                            account:(nonnull MSALAccount *)account
                          authority:(nullable MSALAuthority *)authority
                    completionBlock:(nonnull MSALCompletionBlock)completionBlock DEPRECATED_MSG_ATTRIBUTE("Use -acquireTokenSilentWithParameters:completionBlock instead");


/**
 Acquire a token silently for an existing account.
 
 @param  scopes                 Scopes to request from the server, the scopes that come back
                                can differ from the ones in the original call
 @param  account                An account object retrieved from the application object that the
                                interactive authentication flow will be locked down to.
 @param  authority              Authority indicating a directory that MSAL can use to obtain tokens.
                                Azure AD it is of the form https://<instance/<tenant>, where
                                <instance> is the directory host
                                (e.g. https://login.microsoftonline.com) and <tenant> is a
                                identifier within the directory itself (e.g. a domain associated
                                to the tenant, such as contoso.onmicrosoft.com, or the GUID
                                representing the TenantID property of the directory)
 @param  claimsRequest          The claims parameter that needs to be sent to token endpoint. When claims
                                is passed, access token will be skipped and refresh token will be tried.
 @param  forceRefresh           Ignore any existing access token in the cache and force MSAL to
                                get a new access token from the service.
 @param  correlationId          UUID to correlate this request with the server
 @param  completionBlock        The completion block that will be called when the authentication
                                flow completes, or encounters an error.
 */
- (void)acquireTokenSilentForScopes:(nonnull NSArray<NSString *> *)scopes
                            account:(nonnull MSALAccount *)account
                          authority:(nullable MSALAuthority *)authority
                      claimsRequest:(nullable MSALClaimsRequest *)claimsRequest
                       forceRefresh:(BOOL)forceRefresh
                      correlationId:(nullable NSUUID *)correlationId
                    completionBlock:(nonnull MSALCompletionBlock)completionBlock DEPRECATED_MSG_ATTRIBUTE("Use -acquireTokenSilentWithParameters:completionBlock instead");


#pragma mark - Remove account from cache

/**
    Removes all tokens from the cache for this application for the provided account.
    MSAL won't be able to return tokens silently after calling this API, and developer will need to call acquireToken.
    User might need to enter his credentials again after calling this API
 
    @param  account    The account to remove from the cache
 */
- (BOOL)removeAccount:(nonnull MSALAccount *)account
                error:(NSError * _Nullable __autoreleasing * _Nullable)error;

/**
   Removes all tokens from the cache for this application for the provided account.
   Additionally, this API will remove account from the system browser or the embedded webView by navigating to the OIDC end session endpoint if requested in parameters (see more https://openid.net/specs/openid-connect-session-1_0.html).
   Moreover, if device has an SSO extension installed, the signout request will be handled through the SSO extension.
 
   As a result of the signout operation, application will not be able to get tokens for the given account without user entering credentials.
   However, this will not sign out from other signed in apps on the device, unless it is explicitly enabled by the administrator configuration through an MDM profile.
*/
- (void)signoutWithAccount:(nonnull MSALAccount *)account
         signoutParameters:(nonnull MSALSignoutParameters *)signoutParameters
           completionBlock:(nonnull MSALSignoutCompletionBlock)signoutCompletionBlock;

#pragma mark - Device information

/**
   Reads device information from the authentication broker if present on the device. 
*/
- (void)getDeviceInformationWithParameters:(nullable MSALParameters *)parameters
                           completionBlock:(nonnull MSALDeviceInformationCompletionBlock)completionBlock;

/**
   Reads WPJ metadata  (UPN, tenant ID, deviCe ID) from the authentication broker if present on the device for a specific tenantId
*/
- (void)getWPJMetaDataDeviceWithParameters:(nullable MSALParameters *)parameters
                               forTenantId:(nullable NSString *)tenantId
                           completionBlock:(nonnull MSALWPJMetaDataCompletionBlock)completionBlock;

/**
   A boolean indicates if a compatible broker is present in device for AAD requests.
*/
@property (readonly) BOOL isCompatibleAADBrokerAvailable;

/**
   A String indicates the version of current MSAL SDK
*/
@property (nullable, class, readonly) NSString *sdkVersion;

@end


