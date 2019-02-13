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

#import "MSALPublicClientApplication+Internal.h"
#import "MSALError_Internal.h"
#import "MSALUIBehavior_Internal.h"

#import "MSALTelemetryApiId.h"
#import "MSALTelemetry.h"
#if TARGET_OS_IPHONE
#import "MSIDKeychainTokenCache.h"
#import "MSIDCertAuthHandler+iOS.h"
#endif
#import "MSIDMacTokenCache.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccount.h"
#import "NSURL+MSIDExtensions.h"
#import "MSALAccount+Internal.h"
#import "MSALAADAuthority.h"
#import "MSALAuthority_Internal.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSALOauth2FactoryProducer.h"
#import "MSALWebviewType_Internal.h"
#import "MSIDAuthority.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSALRedirectUriVerifier.h"
#import "MSIDWebviewAuthorization.h"
#import "MSALAccountsProvider.h"
#import "MSALResult+Internal.h"
#import "MSIDRequestControllerFactory.h"
#import "MSIDRequestParameters.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDDefaultTokenRequestProvider.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSALAccountId.h"
#import "MSIDAuthorityFactory.h"
#import "MSALErrorConverter.h"
#import "MSIDBrokerInteractiveController.h"
#import "MSIDDefaultBrokerResponseHandler.h"
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSALRedirectUri.h"
#import "MSIDConfiguration.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDIntuneUserDefaultsCacheDataSource.h"
#import "MSIDIntuneMAMResourcesCache.h"
#import "MSIDIntuneEnrollmentIdsCache.h"
#import "MSALPublicClientStatusNotifications.h"
#import "MSIDNotifications.h"

@interface MSALPublicClientApplication()
{
    WKWebView *_customWebview;
    NSString *_defaultKeychainGroup;
}

@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;
#if TARGET_OS_IPHONE
@property (nonatomic, readwrite) NSString *keychainGroup;
#endif

@end

static NSString *const s_defaultAuthorityUrlString = @"https://login.microsoftonline.com/common";

@implementation MSALPublicClientApplication

- (NSString *)defaultKeychainGroup
{
#if TARGET_OS_IPHONE
    return MSIDKeychainTokenCache.defaultKeychainGroup;
#else
    return nil;
#endif
}

+ (void)load
{
    [MSIDIntuneMAMResourcesCache setSharedCache:[[MSIDIntuneMAMResourcesCache alloc] initWithDataSource:[MSIDIntuneUserDefaultsCacheDataSource new]]];
    [MSIDIntuneEnrollmentIdsCache setSharedCache:[[MSIDIntuneEnrollmentIdsCache alloc] initWithDataSource:[MSIDIntuneUserDefaultsCacheDataSource new]]];
    
    MSIDNotifications.webAuthDidCompleteNotificationName = MSALWebAuthDidCompleteNotification;
    MSIDNotifications.webAuthDidFailNotificationName = MSALWebAuthDidFailNotification;
    MSIDNotifications.webAuthDidStartLoadNotificationName = MSALWebAuthDidStartLoadNotification;
    MSIDNotifications.webAuthDidFinishLoadNotificationName = MSALWebAuthDidFinishLoadNotification;
    MSIDNotifications.webAuthWillSwitchToBrokerAppNotificationName = MSALWebAuthWillSwitchToBrokerApp;
    MSIDNotifications.webAuthDidReceiveResponseFromBrokerNotificationName = MSALWebAuthDidReceieveResponseFromBroker;
}

- (id)initWithClientId:(NSString *)clientId
                 error:(NSError * __autoreleasing *)error
{
    return [self initWithClientId:clientId
                    keychainGroup:self.defaultKeychainGroup
                        authority:nil
                      redirectUri:nil
                            error:error];
}

- (id)initWithClientId:(NSString *)clientId
             authority:(MSALAuthority *)authority
                 error:(NSError **)error
{
    return [self initWithClientId:clientId
                    keychainGroup:self.defaultKeychainGroup
                        authority:authority
                      redirectUri:nil
                            error:error];
}

- (id)initWithClientId:(NSString *)clientId
             authority:(MSALAuthority *)authority
           redirectUri:(NSString *)redirectUri
                 error:(NSError **)error
{
    return [self initWithClientId:clientId
                    keychainGroup:self.defaultKeychainGroup
                        authority:authority
                      redirectUri:redirectUri
                            error:error];
}

#if TARGET_OS_IPHONE

- (id)initWithClientId:(NSString *)clientId
         keychainGroup:(NSString *)keychainGroup
                 error:(NSError * __autoreleasing *)error
{
    return [self initWithClientId:clientId
                    keychainGroup:keychainGroup
                        authority:nil
                      redirectUri:nil
                            error:error];
}

- (id)initWithClientId:(NSString *)clientId
         keychainGroup:(NSString *)keychainGroup
             authority:(MSALAuthority *)authority
                 error:(NSError * __autoreleasing *)error
{
    return [self initWithClientId:clientId
                    keychainGroup:keychainGroup
                        authority:authority
                      redirectUri:nil
                            error:error];
}

#endif

- (id)initWithClientId:(NSString *)clientId
         keychainGroup:(NSString *)keychainGroup
             authority:(MSALAuthority *)authority
           redirectUri:(NSString *)redirectUri
                 error:(NSError * __autoreleasing *)error
{
    if (!(self = [super init]))
    {
        return nil;
    }

    if ([NSString msidIsStringNilOrBlank:clientId])
    {
        MSAL_ERROR_PARAM(nil, MSALErrorInvalidParameter, @"clientId is a required parameter and must not be nil or empty.");
        return nil;
    }

    _clientId = clientId;

    NSError *msidError = nil;
    
    if (authority)
    {
        _authority = authority;
    }
    else
    {
        // TODO: Rationalize our default authority behavior (#93)
        NSURL *authorityURL = [NSURL URLWithString:s_defaultAuthorityUrlString];
        _authority = [[MSALAADAuthority alloc] initWithURL:authorityURL context:nil error:&msidError];
    }

    if (!_authority)
    {
        if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
        return nil;
    }

    MSALRedirectUri *msalRedirectUri = [MSALRedirectUriVerifier msalRedirectUriWithCustomUri:redirectUri
                                                                                    clientId:clientId
                                                                                       error:&msidError];

    if (!msalRedirectUri)
    {
        if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
        return nil;
    }

    _redirectUri = msalRedirectUri;

#if TARGET_OS_IPHONE
    // Optional Paramater
    _keychainGroup = keychainGroup;

    MSIDKeychainTokenCache *dataSource;
    if (_keychainGroup == nil)
    {
        _keychainGroup = [[NSBundle mainBundle] bundleIdentifier];
    }
    
    dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:_keychainGroup];

    MSIDLegacyTokenCacheAccessor *legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    MSIDDefaultTokenCacheAccessor *defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:@[legacyAccessor]];
    
    self.tokenCache = defaultAccessor;
    
    _webviewType = MSALWebviewTypeDefault;
    
#else
    __auto_type dataSource = MSIDMacTokenCache.defaultCache;

    MSIDDefaultTokenCacheAccessor *defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    self.tokenCache = defaultAccessor;
    _webviewType = MSALWebviewTypeWKWebView;
    
#endif
    
    _validateAuthority = YES;
    _extendedLifetimeEnabled = NO;
    
    _sliceParameters = [MSALPublicClientApplication defaultSliceParameters];
    
    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = @"v2.0";
    _expirationBuffer = 300;  //in seconds, ensures catching of clock differences between the server and the device
    
    return self;
}

#pragma mark - Accounts

- (NSArray <MSALAccount *> *)allAccounts:(NSError * __autoreleasing *)error
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                          clientId:self.clientId];
    NSError *msidError = nil;
    NSArray *accounts = [request allAccounts:&msidError];
    if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
    
    return accounts;
}

- (MSALAccount *)accountForHomeAccountId:(NSString *)homeAccountId
                                   error:(NSError * __autoreleasing *)error
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                          clientId:self.clientId];
    NSError *msidError = nil;
    MSALAccount *account = [request accountForHomeAccountId:homeAccountId error:&msidError];
    
    if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
    
    return account;
}

- (MSALAccount *)accountForUsername:(NSString *)username
                              error:(NSError * __autoreleasing *)error
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                          clientId:self.clientId];
    NSError *msidError = nil;
    MSALAccount *account = [request accountForUsername:username error:&msidError];
    
    if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
    
    return account;
}

- (void)allAccountsFilteredByAuthority:(MSALAccountsCompletionBlock)completionBlock
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                          clientId:self.clientId];

    [request allAccountsFilteredByAuthority:self.authority completionBlock:^(NSArray<MSALAccount *> *accounts, NSError *msidError) {
        completionBlock(accounts, [MSALErrorConverter msalErrorFromMsidError:msidError]);
    }];
}

#pragma SafariViewController Support

#if TARGET_OS_IPHONE
+ (BOOL)handleMSALResponse:(NSURL *)response
{
    return [self handleMSALResponse:response sourceApplication:@""];
}

+ (BOOL)handleMSALResponse:(NSURL *)response
         sourceApplication:(NSString *)sourceApplication
{
    if ([MSIDWebviewAuthorization handleURLResponseForSystemWebviewController:response])
    {
        return YES;
    }

    if ([MSIDCertAuthHandler completeCertAuthChallenge:response])
    {
        return YES;
    }

    if ([NSString msidIsStringNilOrBlank:sourceApplication])
    {
        MSID_LOG_WARN(nil, @"Application doesn't integrate with broker correctly");
        // TODO: add a link to Wiki describing why broker is necessary
        return NO;
    }

    // Only AAD is supported in broker at this time. If we need to support something else, we need to change this to dynamically read authority from response and create factory
    MSIDDefaultBrokerResponseHandler *brokerResponseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new]
                                                                                                      tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];

    if ([MSIDBrokerInteractiveController completeAcquireToken:response
                                            sourceApplication:sourceApplication
                                        brokerResponseHandler:brokerResponseHandler])
    {
        return YES;
    }

    return NO;
}

#endif

+ (BOOL)cancelCurrentWebAuthSession
{
    if ([MSIDWebviewAuthorization currentSession])
    {
        [MSIDWebviewAuthorization cancelCurrentSession];
        return YES;
    }
    
    return NO;
}

#pragma mark -
#pragma mark acquireToken

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                        account:nil
                      loginHint:nil
                     uiBehavior:MSALUIBehaviorDefault
           extraQueryParameters:nil
                         claims:nil
                      authority:nil
                  correlationId:nil
                          apiId:MSALTelemetryApiIdAcquire
                completionBlock:completionBlock];
}

#pragma mark -
#pragma mark Login Hint

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                    loginHint:(NSString *)loginHint
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                        account:nil
                      loginHint:loginHint
                     uiBehavior:MSALUIBehaviorDefault
           extraQueryParameters:nil
                         claims:nil
                      authority:nil
                  correlationId:nil
                          apiId:MSALTelemetryApiIdAcquireWithHint
                completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                    loginHint:(NSString *)loginHint
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                        account:nil
                      loginHint:loginHint
                     uiBehavior:uiBehavior
           extraQueryParameters:extraQueryParameters
                         claims:nil
                      authority:nil
                  correlationId:nil
                          apiId:MSALTelemetryApiIdAcquireWithHintBehaviorAndParameters
                completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
         extraScopesToConsent:(NSArray<NSString *> *)extraScopesToConsent
                    loginHint:(NSString *)loginHint
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
                    authority:(MSALAuthority *)authority
                correlationId:(NSUUID *)correlationId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:extraScopesToConsent
                        account:nil
                      loginHint:loginHint
                     uiBehavior:uiBehavior
           extraQueryParameters:extraQueryParameters
                         claims:nil
                      authority:authority
                  correlationId:correlationId
                          apiId:MSALTelemetryApiIdAcquireWithHintBehaviorParametersAuthorityAndCorrelationId
                completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(nonnull NSArray<NSString *> *)scopes
         extraScopesToConsent:(nullable NSArray<NSString *> *)extraScopesToConsent
                    loginHint:(nullable NSString *)loginHint
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(nullable NSDictionary <NSString *, NSString *> *)extraQueryParameters
                       claims:(nullable NSString *)claims
                    authority:(nullable MSALAuthority *)authority
                correlationId:(nullable NSUUID *)correlationId
              completionBlock:(nonnull MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:extraScopesToConsent
                        account:nil
                      loginHint:loginHint
                     uiBehavior:uiBehavior
           extraQueryParameters:extraQueryParameters
                         claims:claims
                      authority:authority
                  correlationId:correlationId
                          apiId:MSALTelemetryApiIdAcquireWithHintBehaviorParametersAuthorityAndClaimsAndCorrelationId
                completionBlock:completionBlock];
}

#pragma mark -
#pragma mark Account


- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                      account:(MSALAccount *)account
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                        account:account
                      loginHint:nil
                     uiBehavior:MSALUIBehaviorDefault
           extraQueryParameters:nil
                         claims:nil
                      authority:nil
                  correlationId:nil
                          apiId:MSALTelemetryApiIdAcquireWithUserBehaviorAndParameters
                completionBlock:completionBlock];
    
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                      account:(MSALAccount *)account
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                        account:account
                      loginHint:nil
                     uiBehavior:uiBehavior
           extraQueryParameters:extraQueryParameters
                         claims:nil
                      authority:nil
                  correlationId:nil
                          apiId:MSALTelemetryApiIdAcquireWithUserBehaviorAndParameters
                completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
         extraScopesToConsent:(NSArray<NSString *> *)extraScopesToConsent
                      account:(MSALAccount *)account
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
                    authority:(MSALAuthority *)authority
                correlationId:(NSUUID *)correlationId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:extraScopesToConsent
                        account:account
                      loginHint:nil
                     uiBehavior:uiBehavior
           extraQueryParameters:extraQueryParameters
                         claims:nil
                      authority:authority
                  correlationId:correlationId
                          apiId:MSALTelemetryApiIdAcquireWithUserBehaviorParametersAuthorityAndCorrelationId
                completionBlock:completionBlock];
    
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
         extraScopesToConsent:(NSArray<NSString *> *)extraScopesToConsent
                      account:(MSALAccount *)account
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
                       claims:(NSString *)claims
                    authority:(MSALAuthority *)authority
                correlationId:(NSUUID *)correlationId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:extraScopesToConsent
                        account:account
                      loginHint:nil
                     uiBehavior:uiBehavior
           extraQueryParameters:extraQueryParameters
                         claims:claims
                      authority:authority
                  correlationId:correlationId
                          apiId:MSALTelemetryApiIdAcquireWithUserBehaviorParametersAuthorityAndCorrelationId
                completionBlock:completionBlock];
    
}

#pragma mark -
#pragma mark Silent

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                            account:(MSALAccount *)account
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenSilentForScopes:scopes
                              account:account
                            authority:nil
                               claims:nil
                         forceRefresh:NO
                        correlationId:nil
                                apiId:MSALTelemetryApiIdAcquireSilentWithUser
                      completionBlock:completionBlock];
}

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                            account:(MSALAccount *)account
                          authority:(MSALAuthority *)authority
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenSilentForScopes:scopes
                              account:account
                            authority:authority
                               claims:nil
                         forceRefresh:NO
                        correlationId:nil
                                apiId:MSALTelemetryApiIdAcquireSilentWithUserAndAuthority
                      completionBlock:completionBlock];
}

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                            account:(MSALAccount *)account
                          authority:(MSALAuthority *)authority
                       forceRefresh:(BOOL)forceRefresh
                      correlationId:(NSUUID *)correlationId
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenSilentForScopes:scopes
                              account:account
                            authority:authority
                               claims:nil
                         forceRefresh:forceRefresh
                        correlationId:correlationId
                                apiId:MSALTelemetryApiIdAcquireSilentWithUserAuthorityForceRefreshAndCorrelationId
                      completionBlock:completionBlock];
}

- (void)acquireTokenSilentForScopes:(nonnull NSArray<NSString *> *)scopes
                            account:(nonnull MSALAccount *)account
                          authority:(nullable MSALAuthority *)authority
                             claims:(nullable NSString *)claims
                       forceRefresh:(BOOL)forceRefresh
                      correlationId:(nullable NSUUID *)correlationId
                    completionBlock:(nonnull MSALCompletionBlock)completionBlock
{
    [self acquireTokenSilentForScopes:scopes
                              account:account
                            authority:authority
                               claims:claims
                         forceRefresh:forceRefresh
                        correlationId:correlationId
                                apiId:MSALTelemetryApiIdAcquireSilentWithUserAuthorityForceRefreshAndCorrelationId
                      completionBlock:completionBlock];
}

#pragma mark -
#pragma mark - private methods

+ (void)logOperation:(NSString *)operation
              result:(MSALResult *)result
               error:(NSError *)error
             context:(id<MSIDRequestContext>)ctx
{
    if (error)
    {
        NSString *errorDescription = error.userInfo[MSALErrorDescriptionKey];
        errorDescription = errorDescription ? errorDescription : @"";
        MSID_LOG_ERROR(ctx, @"%@ returning with error: (%@, %ld)", operation, error.domain, (long)error.code);
        MSID_LOG_ERROR_PII(ctx, @"%@ returning with error: (%@, %ld) %@", operation, error.domain, (long)error.code, errorDescription);
    }
    
    if (result)
    {
        NSString *hashedAT = [result.accessToken msidTokenHash];
        MSID_LOG_INFO(ctx, @"%@ returning with at: %@ scopes:%@ expiration:%@", operation, _PII_NULLIFY(hashedAT), _PII_NULLIFY(result.scopes), result.expiresOn);
        MSID_LOG_INFO_PII(ctx, @"%@ returning with at: %@ scopes:%@ expiration:%@", operation, hashedAT, result.scopes, result.expiresOn);
    }
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
         extraScopesToConsent:(NSArray<NSString *> *)extraScopesToConsent
                      account:(MSALAccount *)account
                    loginHint:(NSString *)loginHint
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
                       claims:(NSString *)claims
                    authority:(MSALAuthority *)authority
                correlationId:(NSUUID *)correlationId
                        apiId:(MSALTelemetryApiId)apiId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    MSIDAuthority *requestAuthority = authority.msidAuthority ?: _authority.msidAuthority;
    NSOrderedSet *requestScopes = [[NSOrderedSet alloc] initWithArray:scopes copyItems:YES];
    NSOrderedSet *requestExtraScopes = extraScopesToConsent ? [[NSOrderedSet alloc] initWithArray:extraScopesToConsent copyItems:YES] : nil;
    NSOrderedSet *requestOIDCScopes = [self.class defaultOIDCScopes];
    NSString *requestTelemetryId = [NSString stringWithFormat:@"%ld", (long)apiId];

    NSError *msidError = nil;

    MSIDInteractiveRequestType interactiveRequestType = MSIDInteractiveRequestBrokeredType;

    if (_brokerAvailability == MSALBrokeredAvailabilityNone)
    {
        interactiveRequestType = MSIDInteractiveRequestLocalType;
    }
    else if (!_redirectUri.brokerCapable)
    {
        interactiveRequestType = MSIDInteractiveRequestLocalType;

#if DEBUG && TARGET_OS_IPHONE
        // Unless broker is explicitly disabled, show the warning in debug mode to configure broker correctly
        NSURL *redirectUri = [MSALRedirectUriVerifier defaultBrokerCapableRedirectUri];
        NSString *brokerWarning = [NSString stringWithFormat:@"The configured redirect URI for this application doesn't support brokered authentication. This means that your users might experience worse SSO rate or not be able to complete certain conditional access policies. To resolve it, register %@ scheme in your Info.plist and add \"msauthv2\" under LSApplicationQueriesSchemes. Go to \"aka.ms/msalbroker\" to check possible steps to resolve this warning", redirectUri.scheme];

        MSID_LOG_WARN(nil, @"%@", brokerWarning);
        NSLog(@"%@", brokerWarning);
#endif
    }

    MSIDInteractiveRequestParameters *params = [[MSIDInteractiveRequestParameters alloc] initWithAuthority:requestAuthority
                                                                                               redirectUri:_redirectUri.url.absoluteString
                                                                                                  clientId:_clientId
                                                                                                    scopes:requestScopes
                                                                                                oidcScopes:requestOIDCScopes
                                                                                      extraScopesToConsent:requestExtraScopes
                                                                                             correlationId:correlationId
                                                                                            telemetryApiId:requestTelemetryId
                                                                                   supportedBrokerProtocol:MSID_BROKER_MSAL_SCHEME
                                                                                               requestType:interactiveRequestType
                                                                                                     error:&msidError];

    if (!params)
    {
        completionBlock(nil, [MSALErrorConverter msalErrorFromMsidError:msidError]);
        return;
    }

    // Configure optional parameters
    BOOL accountHintPresent = (![NSString msidIsStringNilOrBlank:loginHint] || account);

    // Select account experience is undefined if user identity is passed (login_hint or account)
    // Therefore, if there's user identity, we don't pass select account prompt type
    if (accountHintPresent && uiBehavior == MSALSelectAccount)
    {
        params.promptType = MSIDPromptTypePromptIfNecessary;
    }
    else
    {
        params.promptType = MSIDPromptTypeForBehavior(uiBehavior);
    }

    params.loginHint = loginHint;
    params.extraAuthorizeURLQueryParameters = extraQueryParameters;
    params.accountIdentifier = account.lookupAccountIdentifier;
    params.validateAuthority = _validateAuthority;
    params.extraURLQueryParameters = _sliceParameters;
    params.tokenExpirationBuffer = _expirationBuffer;
    params.extendedLifetimeEnabled = _extendedLifetimeEnabled;
    params.clientCapabilities = _clientCapabilities;

    // Configure webview
    NSError *msidWebviewError = nil;
    MSIDWebviewType msidWebViewType = MSIDWebviewTypeFromMSALType(_webviewType, &msidWebviewError);

    if (msidWebviewError)
    {
        completionBlock(nil, [MSALErrorConverter msalErrorFromMsidError:msidWebviewError]);
        return;
    }

    params.webviewType = msidWebViewType;
    params.telemetryWebviewType = MSALStringForMSALWebviewType(_webviewType);
    params.customWebview = _customWebview;
    
    MSID_LOG_INFO(params,
             @"-[MSALPublicClientApplication acquireTokenForScopes:%@\n"
              "                               extraScopesToConsent:%@\n"
              "                                            account:%@\n"
              "                                          loginHint:%@\n"
              "                                         uiBehavior:%@\n"
              "                               extraQueryParameters:%@\n"
              "                                          authority:%@\n"
              "                                      correlationId:%@\n"
              "                                       capabilities:%@\n"
              "                                             claims:%@]",
             _PII_NULLIFY(scopes), _PII_NULLIFY(extraScopesToConsent), _PII_NULLIFY(account.homeAccountId), _PII_NULLIFY(loginHint), MSALStringForMSALUIBehavior(uiBehavior), extraQueryParameters, _PII_NULLIFY(authority), correlationId, _clientCapabilities, claims);
    MSID_LOG_INFO_PII(params,
                 @"-[MSALPublicClientApplication acquireTokenForScopes:%@\n"
                  "                               extraScopesToConsent:%@\n"
                  "                                            account:%@\n"
                  "                                          loginHint:%@\n"
                  "                                         uiBehavior:%@\n"
                  "                               extraQueryParameters:%@\n"
                  "                                          authority:%@\n"
                  "                                      correlationId:%@\n"
                  "                                       capabilities:%@\n"
                  "                                             claims:%@]",
                 scopes, extraScopesToConsent, account.homeAccountId, loginHint, MSALStringForMSALUIBehavior(uiBehavior), extraQueryParameters, authority, correlationId, _clientCapabilities, claims);
    
    MSALCompletionBlock block = ^(MSALResult *result, NSError *msidError)
    {
        NSError *msalError = [MSALErrorConverter msalErrorFromMsidError:msidError];
        [MSALPublicClientApplication logOperation:@"acquireToken" result:result error:msalError context:params];

        if ([NSThread isMainThread])
        {
            completionBlock(result, msalError);
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(result, msalError);
            });
        }
    };
    
    NSError *claimsError = nil;

    // Configure claims
    if (![params setClaimsFromJSON:claims error:&claimsError])
    {
        block(nil, claimsError);
        return;
    }

    NSError *requestError = nil;

    MSIDOauth2Factory *oauth2Factory = [MSALOauth2FactoryProducer msidOauth2FactoryForAuthority:_authority.url context:nil error:&requestError];

    if (!oauth2Factory)
    {
        block(nil, requestError);
        return;
    }

    MSIDDefaultTokenRequestProvider *tokenRequestProvider = [[MSIDDefaultTokenRequestProvider alloc] initWithOauthFactory:oauth2Factory
                                                                                                          defaultAccessor:_tokenCache
                                                                                                   tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];

    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory interactiveControllerForParameters:params tokenRequestProvider:tokenRequestProvider error:&requestError];

    if (!controller)
    {
        block(nil, requestError);
        return;
    }

    [controller acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        if (error)
        {
            block(nil, error);
            return;
        }

        NSError *resultError = nil;
        MSALResult *msalResult = [MSALResult resultWithTokenResult:result error:&resultError];
        block(msalResult, resultError);
    }];
}

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                            account:(MSALAccount *)account
                          authority:(MSALAuthority *)authority
                             claims:(NSString *)claims
                       forceRefresh:(BOOL)forceRefresh
                      correlationId:(NSUUID *)correlationId
                              apiId:(MSALTelemetryApiId)apiId
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    MSIDAuthority *msidAuthority = authority.msidAuthority;

    if (!msidAuthority)
    {
        msidAuthority = self.authority.msidAuthority;
    }

    /*
     In the acquire token silent call we assume developer wants to get access token for account's home tenant,
     if authority is a common, organizations or consumers authority.
     */
    msidAuthority = [MSIDAuthorityFactory authorityFromUrl:msidAuthority.url rawTenant:account.homeAccountId.tenantId context:nil error:nil];

    NSOrderedSet *requestScopes = [[NSOrderedSet alloc] initWithArray:scopes copyItems:YES];
    NSOrderedSet *requestOIDCScopes = [self.class defaultOIDCScopes];
    NSString *requestTelemetryId = [NSString stringWithFormat:@"%ld", (long)apiId];

    NSError *msidError = nil;

    MSIDRequestParameters *params = [[MSIDRequestParameters alloc] initWithAuthority:msidAuthority
                                                                         redirectUri:_redirectUri.url.absoluteString
                                                                            clientId:_clientId
                                                                              scopes:requestScopes
                                                                          oidcScopes:requestOIDCScopes
                                                                       correlationId:correlationId
                                                                      telemetryApiId:requestTelemetryId
                                                                               error:&msidError];

    if (!params)
    {
        completionBlock(nil, [MSALErrorConverter msalErrorFromMsidError:msidError]);
        return;
    }

    // Set optional params
    params.accountIdentifier = account.lookupAccountIdentifier;
    params.validateAuthority = _validateAuthority;
    params.extendedLifetimeEnabled = _extendedLifetimeEnabled;
    params.clientCapabilities = _clientCapabilities;
    params.extraURLQueryParameters = _sliceParameters;
    params.tokenExpirationBuffer = _expirationBuffer;
    
    MSID_LOG_INFO(params,
             @"-[MSALPublicClientApplication acquireTokenSilentForScopes:%@\n"
              "                                                  account:%@\n"
              "                                                authority:%@\n"
              "                                             forceRefresh:%@\n"
              "                                            correlationId:%@\n"
              "                                             capabilities:%@\n"
              "                                                   claims:%@]",
             _PII_NULLIFY(scopes), _PII_NULLIFY(account), _PII_NULLIFY(authority), forceRefresh ? @"Yes" : @"No", correlationId, _clientCapabilities, claims);
    
    
    MSID_LOG_INFO_PII(params,
                 @"-[MSALPublicClientApplication acquireTokenSilentForScopes:%@\n"
                  "                                                  account:%@\n"
                  "                                                authority:%@\n"
                  "                                             forceRefresh:%@\n"
                  "                                            correlationId:%@\n"
                  "                                             capabilities:%@\n"
                  "                                                   claims:%@]",
                 scopes, account, _PII_NULLIFY(authority), forceRefresh ? @"Yes" : @"No", correlationId, _clientCapabilities, claims);
    
    MSALCompletionBlock block = ^(MSALResult *result, NSError *msidError)
    {
        NSError *msalError = [MSALErrorConverter msalErrorFromMsidError:msidError];
        [MSALPublicClientApplication logOperation:@"acquireTokenSilent" result:result error:msalError context:params];
        completionBlock(result, msalError);
    };

    NSError *claimsError = nil;

    // Set claims
    if (![params setClaimsFromJSON:claims error:&claimsError])
    {
        block(nil, claimsError);
        return;
    }

    NSError *requestError = nil;
    MSIDOauth2Factory *oauth2Factory = [MSALOauth2FactoryProducer msidOauth2FactoryForAuthority:_authority.url context:nil error:&requestError];

    if (!oauth2Factory)
    {
        block(nil, requestError);
        return;
    }

    MSIDDefaultTokenRequestProvider *tokenRequestProvider = [[MSIDDefaultTokenRequestProvider alloc] initWithOauthFactory:oauth2Factory
                                                                                                          defaultAccessor:_tokenCache
                                                                                                   tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];

    id<MSIDRequestControlling> requestController = [MSIDRequestControllerFactory silentControllerForParameters:params forceRefresh:forceRefresh tokenRequestProvider:tokenRequestProvider error:&requestError];

    if (!requestController)
    {
        block(nil, requestError);
        return;
    }

    [requestController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        if (error)
        {
            block(nil, error);
            return;
        }

        NSError *resultError = nil;
        MSALResult *msalResult = [MSALResult resultWithTokenResult:result error:&resultError];
        block(msalResult, resultError);
    }];
}

#pragma mark -
#pragma mark remove account from cache

- (BOOL)removeAccount:(MSALAccount *)account
                error:(NSError * __autoreleasing *)error
{
    if (!account)
    {
        return YES;
    }

    NSError *msidError = nil;

    BOOL result = [self.tokenCache clearCacheForAccount:account.lookupAccountIdentifier
                                              authority:nil
                                               clientId:self.clientId
                                               familyId:nil
                                                context:nil
                                                  error:&msidError];
    if (!result)
    {
        if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
        return NO;
    }

    NSError *metadataError = nil;
    // If we remove account, we want this app to be also disassociated from foci token, so that user cannot sign in silently again after signing out
    // Therefore, we update app metadata to not have family id for this app after signout

    NSURL *authorityURL = [NSURL msidURLWithEnvironment:account.environment tenant:account.homeAccountId.tenantId];
    MSIDAuthority *authority = [MSIDAuthorityFactory authorityFromUrl:authorityURL context:nil error:nil];

    BOOL metadataResult = [self.tokenCache updateAppMetadataWithFamilyId:@""
                                                                clientId:self.clientId
                                                               authority:authority
                                                                 context:nil
                                                                   error:&metadataError];

    if (!metadataResult)
    {
        MSID_LOG_WARN(nil, @"Failed to update app metadata when removing account %ld, %@", (long)metadataError.code, metadataError.domain);
        MSID_LOG_WARN(nil, @"Failed to update app metadata when removing account %@", metadataError);
    }

    return result;
}

@end


@implementation MSALPublicClientApplication (Internal)

+ (NSOrderedSet *)defaultOIDCScopes
{
    return [NSOrderedSet orderedSetWithObjects:MSID_OAUTH2_SCOPE_OPENID_VALUE,
                                               MSID_OAUTH2_SCOPE_PROFILE_VALUE,
                                               MSID_OAUTH2_SCOPE_OFFLINE_ACCESS_VALUE, nil];
}

+ (NSDictionary *)defaultSliceParameters
{
    return @{ DEFAULT_SLICE_PARAMS };
}

@end
