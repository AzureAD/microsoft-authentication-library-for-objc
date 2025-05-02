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

@class MSALAccount;
@class MSALSilentTokenParameters;
@class MSALInteractiveTokenParameters;
@class MSALAccountEnumerationParameters;
@class MSALSignoutParameters;
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
 Returns an array of all accounts visible to this application.

 @param  error      The error that occured trying to retrieve accounts, if any, if you're
                    not interested in the specific error pass in nil.
 */

- (nullable NSArray <MSALAccount *> *)allAccounts:(NSError * _Nullable __autoreleasing * _Nullable)error;

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

#pragma mark - Acquire Token Silent

/**
 Acquire a token silently for a provided parameters.
 
 @param  parameters Parameters used for silent authentication.
 @param  completionBlock The completion block that will be called when the authentication
 flow completes, or encounters an error.
 */
- (void)acquireTokenSilentWithParameters:(nonnull MSALSilentTokenParameters *)parameters
                         completionBlock:(nonnull MSALCompletionBlock)completionBlock;

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


