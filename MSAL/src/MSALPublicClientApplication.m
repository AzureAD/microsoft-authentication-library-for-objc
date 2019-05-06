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
#import "MSALPromptType_Internal.h"
#import "MSALError.h"

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
#if TARGET_OS_IPHONE
#import "MSIDBrokerInteractiveController.h"
#endif
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
#import "MSALInteractiveTokenParameters.h"
#import "MSALSilentTokenParameters.h"
#import "MSALSliceConfig.h"
#import "MSALGlobalConfig.h"
#import "MSALPublicClientApplicationConfig+Internal.h"
#import "MSALCacheConfig.h"
#import "MSALADFSAuthority.h"
#import "MSALExtraQueryParameters.h"
#import "MSIDAADAuthority.h"
#import "MSALCacheConfig.h"
#import "MSALClaimsRequest+Internal.h"

@interface MSALPublicClientApplication()
{
    WKWebView *_customWebview;
    NSString *_defaultKeychainGroup;
}

@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;
@property (nonatomic) MSALPublicClientApplicationConfig *internalConfig;

@end


@implementation MSALPublicClientApplication

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

#pragma mark - Properties

- (MSALAuthority *)authority { return self.internalConfig.authority; }
- (NSString *)clientId { return self.internalConfig.clientId; }
- (MSALRedirectUri *)redirectUri { return self.internalConfig.verifiedRedirectUri; }

- (NSDictionary<NSString *,NSString *> *)sliceParameters { return self.internalConfig.sliceConfig.sliceDictionary; }
- (void)setSliceParameters:(NSDictionary<NSString *,NSString *> *)sliceParameters
{
    if (!sliceParameters) MSID_LOG_WARN(nil, @"setting slice parameter with nil object.");
    if (!sliceParameters[@"slice"] && !sliceParameters[@"dc"]) MSID_LOG_WARN(nil, @"slice parameter does not contain slice nor dc");
    
    self.internalConfig.sliceConfig = [MSALSliceConfig configWithSlice:sliceParameters[@"slice"] dc:sliceParameters[@"dc"]];
}

- (MSALWebviewType)webviewType { return MSALGlobalConfig.defaultWebviewType; }
- (void)setWebviewType:(MSALWebviewType)webviewType { MSALGlobalConfig.defaultWebviewType = webviewType; }

#if TARGET_OS_IPHONE
- (NSString *)keychainGroup { return self.internalConfig.cacheConfig.keychainSharingGroup; }
#endif

#pragma mark - Initializers
- (id)initWithClientId:(NSString *)clientId
                 error:(NSError * __autoreleasing *)error
{
    return [self initWithClientId:clientId
                    keychainGroup:MSALCacheConfig.defaultKeychainSharingGroup
                        authority:nil
                      redirectUri:nil
                            error:error];
}

- (id)initWithClientId:(NSString *)clientId
             authority:(MSALAuthority *)authority
                 error:(NSError **)error
{
    return [self initWithClientId:clientId
                    keychainGroup:MSALCacheConfig.defaultKeychainSharingGroup
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
                    keychainGroup:MSALCacheConfig.defaultKeychainSharingGroup
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

- (nullable instancetype)initWithConfiguration:(nonnull MSALPublicClientApplicationConfig *)config
                                         error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _validateAuthority = YES;
    
    // Verify required fields
    if ([NSString msidIsStringNilOrBlank:config.clientId])
    {
        NSError *msidError;
        MSIDFillAndLogError(&msidError, MSIDErrorInvalidDeveloperParameter, @"clientId is a required parameter and must not be nil or empty.", nil);
        
        if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
        
        return nil;
    }

    NSError *msidError = nil;
    MSALRedirectUri *msalRedirectUri = [MSALRedirectUriVerifier msalRedirectUriWithCustomUri:config.redirectUri
                                                                                    clientId:config.clientId
                                                                                       error:&msidError];
    
    if (!msalRedirectUri)
    {
        if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
        return nil;
    }
    
    config.verifiedRedirectUri = msalRedirectUri;
    
#if TARGET_OS_IPHONE
    // Optional Paramater
    MSIDKeychainTokenCache *dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:config.cacheConfig.keychainSharingGroup];
    
    MSIDLegacyTokenCacheAccessor *legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    MSIDDefaultTokenCacheAccessor *defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:@[legacyAccessor]];
    
    self.tokenCache = defaultAccessor;
#else
    __auto_type dataSource = MSIDMacTokenCache.defaultCache;
    
    MSIDDefaultTokenCacheAccessor *defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    self.tokenCache = defaultAccessor;
#endif
    // Maintain an internal copy of config.
    // Developers shouldn't be able to change any properties on config after PCA has been created
    _configuration = config;
    _internalConfig = [config copy];
    
    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = @"v2.0";
    
    return self;
}

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
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:clientId redirectUri:redirectUri authority:authority];
    
#if TARGET_OS_IPHONE
    config.cacheConfig.keychainSharingGroup = keychainGroup ?: [[NSBundle mainBundle] bundleIdentifier];
#endif
    
    return [self initWithConfiguration:config error:error];
}

#pragma mark - Accounts

- (NSArray <MSALAccount *> *)allAccounts:(NSError * __autoreleasing *)error
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                            clientId:self.internalConfig.clientId];
    NSError *msidError = nil;
    NSArray *accounts = [request allAccounts:&msidError];
    if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];

    return accounts;
}

- (MSALAccount *)accountForHomeAccountId:(NSString *)homeAccountId
                                   error:(NSError * __autoreleasing *)error
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                            clientId:self.internalConfig.clientId];
    NSError *msidError = nil;
    MSALAccount *account = [request accountForHomeAccountId:homeAccountId error:&msidError];

    if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];

    return account;
}

- (MSALAccount *)accountForUsername:(NSString *)username
                              error:(NSError * __autoreleasing *)error
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                            clientId:self.internalConfig.clientId];
    NSError *msidError = nil;
    MSALAccount *account = [request accountForUsername:username error:&msidError];

    if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];

    return account;
}


- (void)allAccountsFilteredByAuthority:(MSALAccountsCompletionBlock)completionBlock
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                            clientId:self.internalConfig.clientId];

    [request allAccountsFilteredByAuthority:self.internalConfig.authority
                            completionBlock:^(NSArray<MSALAccount *> *accounts, NSError *msidError) {
        completionBlock(accounts, [MSALErrorConverter msalErrorFromMsidError:msidError]);
    }];
}

#pragma mark - SafariViewController Support

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

    if ([MSIDCertAuthHandler completeCertAuthChallenge:response error:nil])
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

#pragma mark - Acquire Token

- (void)acquireTokenWithParameters:(MSALInteractiveTokenParameters *)parameters
                   completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:parameters.scopes
           extraScopesToConsent:parameters.extraScopesToConsent
                        account:parameters.account
                      loginHint:parameters.loginHint
                     promptType:parameters.promptType
           extraQueryParameters:parameters.extraQueryParameters
                  claimsRequest:parameters.claimsRequest
                      authority:parameters.authority
                    webviewType:parameters.webviewType
                  customWebview:parameters.customWebview
                  correlationId:parameters.correlationId
                          apiId:MSALTelemetryApiIdAcquireWithTokenParameters
                completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                        account:nil
                      loginHint:nil
                     promptType:MSALPromptTypeDefault
           extraQueryParameters:nil
                  claimsRequest:nil
                      authority:nil
                    webviewType:MSALGlobalConfig.defaultWebviewType
                  customWebview:nil
                  correlationId:nil
                          apiId:MSALTelemetryApiIdAcquire
                completionBlock:completionBlock];
}

#pragma mark - Login Hint

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                    loginHint:(NSString *)loginHint
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                        account:nil
                      loginHint:loginHint
                     promptType:MSALPromptTypeDefault
           extraQueryParameters:nil
                  claimsRequest:nil
                      authority:nil
                    webviewType:MSALGlobalConfig.defaultWebviewType
                  customWebview:nil
                  correlationId:nil
                          apiId:MSALTelemetryApiIdAcquireWithHint
                completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                    loginHint:(NSString *)loginHint
                   promptType:(MSALPromptType)promptType
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                        account:nil
                      loginHint:loginHint
                     promptType:promptType
           extraQueryParameters:extraQueryParameters
                  claimsRequest:nil
                      authority:nil
                    webviewType:MSALGlobalConfig.defaultWebviewType
                  customWebview:nil
                  correlationId:nil
                          apiId:MSALTelemetryApiIdAcquireWithHintPromptTypeAndParameters
                completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
         extraScopesToConsent:(NSArray<NSString *> *)extraScopesToConsent
                    loginHint:(NSString *)loginHint
                   promptType:(MSALPromptType)promptType
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
                    authority:(MSALAuthority *)authority
                correlationId:(NSUUID *)correlationId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:extraScopesToConsent
                        account:nil
                      loginHint:loginHint
                     promptType:promptType
           extraQueryParameters:extraQueryParameters
                  claimsRequest:nil
                      authority:authority
                    webviewType:MSALGlobalConfig.defaultWebviewType
                  customWebview:nil
                  correlationId:correlationId
                          apiId:MSALTelemetryApiIdAcquireWithHintPromptTypeParametersAuthorityAndCorrelationId
                completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(nonnull NSArray<NSString *> *)scopes
         extraScopesToConsent:(nullable NSArray<NSString *> *)extraScopesToConsent
                    loginHint:(nullable NSString *)loginHint
                   promptType:(MSALPromptType)promptType
         extraQueryParameters:(nullable NSDictionary <NSString *, NSString *> *)extraQueryParameters
                claimsRequest:(nullable MSALClaimsRequest *)claimsRequest
                    authority:(nullable MSALAuthority *)authority
                correlationId:(nullable NSUUID *)correlationId
              completionBlock:(nonnull MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:extraScopesToConsent
                        account:nil
                      loginHint:loginHint
                     promptType:promptType
           extraQueryParameters:extraQueryParameters
                  claimsRequest:claimsRequest
                      authority:authority
                    webviewType:MSALGlobalConfig.defaultWebviewType
                  customWebview:nil
                  correlationId:correlationId
                          apiId:MSALTelemetryApiIdAcquireWithHintPromptTypeParametersAuthorityAndClaimsAndCorrelationId
                completionBlock:completionBlock];
}

#pragma mark - Account

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                      account:(MSALAccount *)account
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                        account:account
                      loginHint:nil
                     promptType:MSALPromptTypeDefault
           extraQueryParameters:nil
                  claimsRequest:nil
                      authority:nil
                    webviewType:MSALGlobalConfig.defaultWebviewType
                  customWebview:nil
                  correlationId:nil
                          apiId:MSALTelemetryApiIdAcquireWithUserPromptTypeAndParameters
                completionBlock:completionBlock];
    
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                      account:(MSALAccount *)account
                   promptType:(MSALPromptType)promptType
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                        account:account
                      loginHint:nil
                     promptType:promptType
           extraQueryParameters:extraQueryParameters
                  claimsRequest:nil
                      authority:nil
                    webviewType:MSALGlobalConfig.defaultWebviewType
                  customWebview:nil
                  correlationId:nil
                          apiId:MSALTelemetryApiIdAcquireWithUserPromptTypeAndParameters
                completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
         extraScopesToConsent:(NSArray<NSString *> *)extraScopesToConsent
                      account:(MSALAccount *)account
                   promptType:(MSALPromptType)promptType
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
                    authority:(MSALAuthority *)authority
                correlationId:(NSUUID *)correlationId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:extraScopesToConsent
                        account:account
                      loginHint:nil
                     promptType:promptType
           extraQueryParameters:extraQueryParameters
                  claimsRequest:nil
                      authority:authority
                    webviewType:MSALGlobalConfig.defaultWebviewType
                  customWebview:nil
                  correlationId:correlationId
                          apiId:MSALTelemetryApiIdAcquireWithUserPromptTypeParametersAuthorityAndCorrelationId
                completionBlock:completionBlock];
    
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
         extraScopesToConsent:(NSArray<NSString *> *)extraScopesToConsent
                      account:(MSALAccount *)account
                   promptType:(MSALPromptType)promptType
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
                claimsRequest:(MSALClaimsRequest *)claimsRequest
                    authority:(MSALAuthority *)authority
                correlationId:(NSUUID *)correlationId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:extraScopesToConsent
                        account:account
                      loginHint:nil
                     promptType:promptType
           extraQueryParameters:extraQueryParameters
                  claimsRequest:claimsRequest
                      authority:authority
                    webviewType:MSALGlobalConfig.defaultWebviewType
                  customWebview:nil
                  correlationId:correlationId
                          apiId:MSALTelemetryApiIdAcquireWithUserPromptTypeParametersAuthorityAndCorrelationId
                completionBlock:completionBlock];
    
}

#pragma mark - Silent

- (void)acquireTokenSilentWithParameters:(MSALSilentTokenParameters *)parameters
                         completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenSilentForScopes:parameters.scopes
                              account:parameters.account
                            authority:parameters.authority
                        claimsRequest:parameters.claimsRequest
                         forceRefresh:parameters.forceRefresh
                        correlationId:parameters.correlationId
                                apiId:MSALTelemetryApiIdAcquireSilentWithTokenParameters
                      completionBlock:completionBlock];
}

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                            account:(MSALAccount *)account
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenSilentForScopes:scopes
                              account:account
                            authority:nil
                        claimsRequest:nil
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
                        claimsRequest:nil
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
                        claimsRequest:nil
                         forceRefresh:forceRefresh
                        correlationId:correlationId
                                apiId:MSALTelemetryApiIdAcquireSilentWithUserAuthorityForceRefreshAndCorrelationId
                      completionBlock:completionBlock];
}

- (void)acquireTokenSilentForScopes:(nonnull NSArray<NSString *> *)scopes
                            account:(nonnull MSALAccount *)account
                          authority:(nullable MSALAuthority *)authority
                      claimsRequest:(nullable MSALClaimsRequest *)claimsRequest
                       forceRefresh:(BOOL)forceRefresh
                      correlationId:(nullable NSUUID *)correlationId
                    completionBlock:(nonnull MSALCompletionBlock)completionBlock
{
    [self acquireTokenSilentForScopes:scopes
                              account:account
                            authority:authority
                        claimsRequest:claimsRequest
                         forceRefresh:forceRefresh
                        correlationId:correlationId
                                apiId:MSALTelemetryApiIdAcquireSilentWithUserAuthorityForceRefreshAndCorrelationId
                      completionBlock:completionBlock];
}

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
        MSID_LOG_NO_PII(MSIDLogLevelError, nil, ctx, @"%@ returning with error: (%@, %ld)", operation, error.domain, (long)error.code);
        MSID_LOG_PII(MSIDLogLevelError, nil, ctx, @"%@ returning with error: (%@, %ld) %@", operation, error.domain, (long)error.code, errorDescription);
    }
    
    if (result)
    {
        NSString *hashedAT = [result.accessToken msidTokenHash];
        MSID_LOG_NO_PII(MSIDLogLevelInfo, nil, ctx, @"%@ returning with at: %@ scopes:%@ expiration:%@", operation, _PII_NULLIFY(hashedAT), _PII_NULLIFY(result.scopes), result.expiresOn);
        MSID_LOG_PII(MSIDLogLevelInfo, nil, ctx, @"%@ returning with at: %@ scopes:%@ expiration:%@", operation, hashedAT, result.scopes, result.expiresOn);
    }
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
         extraScopesToConsent:(NSArray<NSString *> *)extraScopesToConsent
                      account:(MSALAccount *)account
                    loginHint:(NSString *)loginHint
                   promptType:(MSALPromptType)promptType
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
                claimsRequest:(MSALClaimsRequest *)claimsRequest
                    authority:(MSALAuthority *)authority
                  webviewType:(MSALWebviewType)webviewType
                customWebview:(WKWebView *)customWebview
                correlationId:(NSUUID *)correlationId
                        apiId:(MSALTelemetryApiId)apiId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    MSIDAuthority *requestAuthority = authority.msidAuthority ?: self.internalConfig.authority.msidAuthority;
    NSOrderedSet *requestScopes = [[NSOrderedSet alloc] initWithArray:scopes copyItems:YES];
    NSOrderedSet *requestExtraScopes = extraScopesToConsent ? [[NSOrderedSet alloc] initWithArray:extraScopesToConsent copyItems:YES] : nil;
    NSOrderedSet *requestOIDCScopes = [self.class defaultOIDCScopes];
    NSString *requestTelemetryId = [NSString stringWithFormat:@"%ld", (long)apiId];

    NSError *msidError = nil;

    MSIDInteractiveRequestType interactiveRequestType = MSIDInteractiveRequestBrokeredType;

#if TARGET_OS_IPHONE
    if (MSALGlobalConfig.brokerAvailability == MSALBrokeredAvailabilityNone)
    {
        interactiveRequestType = MSIDInteractiveRequestLocalType;
    }
    else if (!self.internalConfig.verifiedRedirectUri.brokerCapable)
    {
        interactiveRequestType = MSIDInteractiveRequestLocalType;
    }
#endif
    MSIDInteractiveRequestParameters *params = [[MSIDInteractiveRequestParameters alloc] initWithAuthority:requestAuthority
                                                                                               redirectUri:self.internalConfig.verifiedRedirectUri.url.absoluteString
                                                                                                  clientId:self.internalConfig.clientId
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
    if (accountHintPresent && promptType == MSALPromptTypeSelectAccount)
    {
        params.promptType = MSIDPromptTypePromptIfNecessary;
    }
    else
    {
        params.promptType = MSIDPromptTypeForPromptType(promptType);
    }

    params.loginHint = loginHint;
    params.extraAuthorizeURLQueryParameters = extraQueryParameters;
    params.accountIdentifier = account.lookupAccountIdentifier;
    
    params.extraURLQueryParameters = self.internalConfig.extraQueryParameters.extraURLQueryParameters;

    NSMutableDictionary *extraAuthorizeURLQueryParameters = [self.internalConfig.extraQueryParameters.extraAuthorizeURLQueryParameters mutableCopy];
    [extraAuthorizeURLQueryParameters addEntriesFromDictionary:extraQueryParameters];
    params.extraAuthorizeURLQueryParameters = extraAuthorizeURLQueryParameters;
    params.extraTokenRequestParameters = self.internalConfig.extraQueryParameters.extraTokenURLParameters;
    
    params.tokenExpirationBuffer = self.internalConfig.tokenExpirationBuffer;
    params.extendedLifetimeEnabled = self.internalConfig.extendedLifetimeEnabled;
    params.clientCapabilities = self.internalConfig.clientApplicationCapabilities;

    params.validateAuthority = _validateAuthority;
    
    if (params.validateAuthority
        && [self shouldDisableValidationForAuthority:requestAuthority])
    {
        params.validateAuthority = NO;
    }
    
    // Configure webview
    NSError *msidWebviewError = nil;
    MSIDWebviewType msidWebViewType = MSIDWebviewTypeFromMSALType(webviewType, &msidWebviewError);

    if (msidWebviewError)
    {
        completionBlock(nil, [MSALErrorConverter msalErrorFromMsidError:msidWebviewError]);
        return;
    }

    params.webviewType = msidWebViewType;
    params.telemetryWebviewType = MSALStringForMSALWebviewType(webviewType);
    params.customWebview = customWebview ?: self.customWebview;
    params.claimsRequest = claimsRequest.msidClaimsRequest;
    
    MSID_LOG_NO_PII(MSIDLogLevelInfo, nil, params,
             @"-[MSALPublicClientApplication acquireTokenForScopes:%@\n"
              "                               extraScopesToConsent:%@\n"
              "                                            account:%@\n"
              "                                          loginHint:%@\n"
              "                                         promptType:%@\n"
              "                               extraQueryParameters:%@\n"
              "                                          authority:%@\n"
              "                                        webviewType:%@\n"
              "                                      customWebview:%@\n"
              "                                      correlationId:%@\n"
              "                                       capabilities:%@\n"
              "                                      claimsRequest:%@]",

             _PII_NULLIFY(scopes), _PII_NULLIFY(extraScopesToConsent), _PII_NULLIFY(account.homeAccountId), _PII_NULLIFY(loginHint), MSALStringForPromptType(promptType), extraQueryParameters, _PII_NULLIFY(authority), MSALStringForMSALWebviewType(webviewType), params.customWebview, correlationId, self.internalConfig.clientApplicationCapabilities, claimsRequest);
    MSID_LOG_PII(MSIDLogLevelInfo, nil, params,
                 @"-[MSALPublicClientApplication acquireTokenForScopes:%@\n"
                  "                               extraScopesToConsent:%@\n"
                  "                                            account:%@\n"
                  "                                          loginHint:%@\n"
                  "                                         promptType:%@\n"
                  "                               extraQueryParameters:%@\n"
                  "                                          authority:%@\n"
                  "                                        webviewType:%@\n"
                  "                                      customWebview:%@\n"
                  "                                      correlationId:%@\n"
                  "                                       capabilities:%@\n"
                  "                                      claimsRequest:%@]",
                 scopes, extraScopesToConsent, account.homeAccountId, loginHint, MSALStringForPromptType(promptType), extraQueryParameters, authority, MSALStringForMSALWebviewType(webviewType), params.customWebview, correlationId, self.internalConfig.clientApplicationCapabilities, claimsRequest);

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

    NSError *requestError = nil;

    MSIDOauth2Factory *oauth2Factory = [MSALOauth2FactoryProducer msidOauth2FactoryForAuthority:self.internalConfig.authority.url context:nil error:&requestError];

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
                      claimsRequest:(MSALClaimsRequest *)claimsRequest
                       forceRefresh:(BOOL)forceRefresh
                      correlationId:(NSUUID *)correlationId
                              apiId:(MSALTelemetryApiId)apiId
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    
    MSIDAuthority *msidAuthority = authority.msidAuthority ?: self.internalConfig.authority.msidAuthority;
    
    BOOL shouldValidate = _validateAuthority;
    
    if (shouldValidate && [self shouldDisableValidationForAuthority:msidAuthority])
    {
        shouldValidate = NO;
    }

    /*
     In the acquire token silent call we assume developer wants to get access token for account's home tenant,
     if authority is a common, organizations or consumers authority.
     */
    NSError *authorityError = nil;
    msidAuthority = [MSIDAuthorityFactory authorityWithRawTenant:account.homeAccountId.tenantId msidAuthority:msidAuthority context:nil error:&authorityError];
    
    if (!msidAuthority)
    {
        MSID_LOG_ERROR(nil, @"Encountered an error when updating authority: %ld, %@", (long)authorityError.code, authorityError.domain);
        
        if (completionBlock)
        {
            NSError *msalError = [MSALErrorConverter msalErrorFromMsidError:authorityError];
            completionBlock(nil, msalError);
        }
        
        return;
    }
    
    NSOrderedSet *requestScopes = [[NSOrderedSet alloc] initWithArray:scopes copyItems:YES];
    NSOrderedSet *requestOIDCScopes = [self.class defaultOIDCScopes];
    NSString *requestTelemetryId = [NSString stringWithFormat:@"%ld", (long)apiId];

    NSError *msidError = nil;

    // add known authorities here.
    MSIDRequestParameters *params = [[MSIDRequestParameters alloc] initWithAuthority:msidAuthority
                                                                         redirectUri:self.internalConfig.verifiedRedirectUri.url.absoluteString
                                                                            clientId:self.internalConfig.clientId
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
    params.validateAuthority = shouldValidate;
    params.extendedLifetimeEnabled = self.internalConfig.extendedLifetimeEnabled;
    params.clientCapabilities = self.internalConfig.clientApplicationCapabilities;
    params.extraURLQueryParameters = self.internalConfig.extraQueryParameters.extraURLQueryParameters;
    params.extraTokenRequestParameters = self.internalConfig.extraQueryParameters.extraTokenURLParameters;
    params.tokenExpirationBuffer = self.internalConfig.tokenExpirationBuffer;
    params.claimsRequest = claimsRequest.msidClaimsRequest;
    
    MSID_LOG_NO_PII(MSIDLogLevelInfo, nil, params,
             @"-[MSALPublicClientApplication acquireTokenSilentForScopes:%@\n"
              "                                                  account:%@\n"
              "                                                authority:%@\n"
              "                                             forceRefresh:%@\n"
              "                                            correlationId:%@\n"
              "                                             capabilities:%@\n"
              "                                            claimsRequest:%@]",
             _PII_NULLIFY(scopes), _PII_NULLIFY(account), _PII_NULLIFY(authority), forceRefresh ? @"Yes" : @"No", correlationId, self.internalConfig.clientApplicationCapabilities, claimsRequest);

    MSID_LOG_PII(MSIDLogLevelInfo, nil, params,
                 @"-[MSALPublicClientApplication acquireTokenSilentForScopes:%@\n"
                  "                                                  account:%@\n"
                  "                                                authority:%@\n"
                  "                                             forceRefresh:%@\n"
                  "                                            correlationId:%@\n"
                  "                                             capabilities:%@\n"
                  "                                            claimsRequest:%@]",
                 scopes, account, _PII_NULLIFY(authority), forceRefresh ? @"Yes" : @"No", correlationId, self.internalConfig.clientApplicationCapabilities, claimsRequest);

    MSALCompletionBlock block = ^(MSALResult *result, NSError *msidError)
    {
        NSError *msalError = [MSALErrorConverter msalErrorFromMsidError:msidError];
        [MSALPublicClientApplication logOperation:@"acquireTokenSilent" result:result error:msalError context:params];
        completionBlock(result, msalError);
    };

    NSError *requestError = nil;
    MSIDOauth2Factory *oauth2Factory = [MSALOauth2FactoryProducer msidOauth2FactoryForAuthority:self.internalConfig.authority.url context:nil error:&requestError];

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

#pragma mark - Remove account from cache

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
                                               clientId:self.internalConfig.clientId
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
                                                                clientId:self.internalConfig.clientId
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

- (BOOL)shouldDisableValidationForAuthority:(MSIDAuthority *)authority
{
    if (self.internalConfig.knownAuthorities)
    {
        for (MSALAuthority *knownAuthority in self.internalConfig.knownAuthorities)
        {
            if ([authority isKindOfClass:knownAuthority.msidAuthority.class]
                // Treat  AAD authorities differently, since they should always succeed validation
                // Therefore, even if they are added to known authorities, still do validation
                && ![authority isKindOfClass:[MSIDAADAuthority class]]
                && [knownAuthority.url isEqual:authority.url])
            {
                return YES;
            }
        }
    }
    
    return NO;
}

+ (NSOrderedSet *)defaultOIDCScopes
{
    return [NSOrderedSet orderedSetWithObjects:MSID_OAUTH2_SCOPE_OPENID_VALUE,
                                               MSID_OAUTH2_SCOPE_PROFILE_VALUE,
                                               MSID_OAUTH2_SCOPE_OFFLINE_ACCESS_VALUE, nil];
}

@end
