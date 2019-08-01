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
#import "MSIDMacTokenCache.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccount.h"
#import "NSURL+MSIDExtensions.h"
#import "MSALAccount+Internal.h"
#import "MSALAADAuthority.h"
#import "MSALAuthority_Internal.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSALOauth2ProviderFactory.h"
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
#import "MSALErrorConverter.h"
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
#import "MSALTokenParameters+Internal.h"
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
#import "MSALExternalAccountHandler.h"
#import "MSALSerializedADALCacheProvider+Internal.h"
#import "MSIDExternalAADCacheSeeder.h"
#import "NSURL+MSIDAADUtils.h"
#import "MSALOauth2Provider.h"
#import "MSALAccountEnumerationParameters.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDExtendedTokenCacheDataSource.h"

#if TARGET_OS_IPHONE
#import "MSIDKeychainTokenCache.h"
#import "MSIDCertAuthHandler+iOS.h"
#import "MSIDBrokerInteractiveController.h"
#else
#import "MSIDMacKeychainTokenCache.h"
#endif


@interface MSALPublicClientApplication()
{
    WKWebView *_customWebview;
    NSString *_defaultKeychainGroup;
}

@property (nonatomic) MSALPublicClientApplicationConfig *internalConfig;
@property (nonatomic) MSIDExternalAADCacheSeeder *externalCacheSeeder;

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
    if (!sliceParameters) MSID_LOG_WITH_CTX(MSIDLogLevelWarning,nil, @"setting slice parameter with nil object.");
    if (!sliceParameters[@"slice"] && !sliceParameters[@"dc"]) MSID_LOG_WITH_CTX(MSIDLogLevelWarning,nil, @"slice parameter does not contain slice nor dc");
    
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
    NSArray *otherAccessors = legacyAccessor ? @[legacyAccessor] : nil;
    MSIDDefaultTokenCacheAccessor *defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:otherAccessors];
    self.tokenCache = defaultAccessor;
#else
    id<MSIDExtendedTokenCacheDataSource> dataSource = [[MSIDMacKeychainTokenCache alloc] initWithGroup:config.cacheConfig.keychainSharingGroup];
        
    if (!dataSource)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to initialize macOS keychain cache. Please make sure the app you're running is properly signed");
            
        if (error)
        {
            NSError *devError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Failed to initialize macOS keychain cache. Please make sure the app you're running is properly signed", nil, nil, nil, nil, nil);
            *error = [MSALErrorConverter msalErrorFromMsidError:devError];
        }
            
        return nil;
    }
    
    NSMutableArray *legacyAccessors = [NSMutableArray new];
    id<MSIDTokenCacheDataSource> externalDataSource = config.cacheConfig.serializedADALCache.msidTokenCacheDataSource;
    if (externalDataSource)
    {
        __auto_type legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:externalDataSource otherCacheAccessors:nil];
        __auto_type defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
        _externalCacheSeeder = [[MSIDExternalAADCacheSeeder alloc] initWithDefaultAccessor:defaultAccessor
                                                                    externalLegacyAccessor:legacyAccessor];
        if (legacyAccessor) [legacyAccessors addObject:legacyAccessor];
    }
    
    MSIDDefaultTokenCacheAccessor *defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:legacyAccessors];
    self.tokenCache = defaultAccessor;
#endif
    
    _accountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
    
    // Maintain an internal copy of config.
    // Developers shouldn't be able to change any properties on config after PCA has been created
    _configuration = config;
    _internalConfig = [config copy];
    
    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = @"v2.0";
    NSError *oauthProviderError = nil;
    self.msalOauth2Provider = [MSALOauth2ProviderFactory oauthProviderForAuthority:config.authority
                                                                          clientId:config.clientId
                                                                        tokenCache:_tokenCache
                                                              accountMetadataCache:_accountMetadataCache
                                                                           context:nil
                                                                             error:&oauthProviderError];
    
    if (!self.msalOauth2Provider)
    {
        if (error)
        {
            *error = oauthProviderError;
        }
        
        return nil;
    }
    
    if ([_internalConfig.cacheConfig.externalAccountProviders count])
    {
        _externalAccountHandler = [[MSALExternalAccountHandler alloc] initWithExternalAccountProviders:_internalConfig.cacheConfig.externalAccountProviders
                                                                                        oauth2Provider:self.msalOauth2Provider
                                                                                                 error:error];
        
        if (!_externalAccountHandler) return nil;
    }
    
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
    config.cacheConfig.keychainSharingGroup = keychainGroup;
#endif
    
    return [self initWithConfiguration:config error:error];
}

#pragma mark - Accounts

- (NSArray <MSALAccount *> *)allAccounts:(NSError * __autoreleasing *)error
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                            clientId:self.internalConfig.clientId
                                                             externalAccountProvider:self.externalAccountHandler];
    NSError *msidError = nil;
    NSArray *accounts = [request allAccounts:&msidError];
    if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];

    return accounts;
}

- (MSALAccount *)accountForHomeAccountId:(NSString *)homeAccountId
                                   error:(NSError * __autoreleasing *)error
{
    return [self accountForIdentifier:homeAccountId error:error];
}

- (MSALAccount *)accountForIdentifier:(NSString *)identifier
                                error:(NSError **)error
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                            clientId:self.internalConfig.clientId
                                                             externalAccountProvider:self.externalAccountHandler];
    NSError *msidError = nil;
    
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:identifier];
    
    MSALAccount *account = [request accountForParameters:parameters error:&msidError];
    
    if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
    
    return account;
}

- (NSArray<MSALAccount *> *)accountsForParameters:(MSALAccountEnumerationParameters *)parameters
                                            error:(NSError **)error
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                            clientId:self.internalConfig.clientId
                                                             externalAccountProvider:self.externalAccountHandler];
    NSError *msidError = nil;
    NSArray *accounts = [request accountsForParameters:parameters error:&msidError];
    
    if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
    
    return accounts;
}

- (MSALAccount *)accountForUsername:(NSString *)username
                              error:(NSError * __autoreleasing *)error
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                            clientId:self.internalConfig.clientId
                                                             externalAccountProvider:self.externalAccountHandler];
    NSError *msidError = nil;
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:nil username:username];
    MSALAccount *account = [request accountForParameters:parameters error:&msidError];

    if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];

    return account;
}

- (void)allAccountsFilteredByAuthority:(MSALAccountsCompletionBlock)completionBlock
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                            clientId:self.internalConfig.clientId
                                                             externalAccountProvider:self.externalAccountHandler];

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
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning,nil, @"Application doesn't integrate with broker correctly");
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
    MSIDAuthority *requestAuthority = parameters.authority.msidAuthority ?: self.internalConfig.authority.msidAuthority;
    
    if (![self.msalOauth2Provider isSupportedAuthority:requestAuthority])
    {
        if (completionBlock)
        {
            NSError *msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Unsupported authority type. Please configure MSALPublicClientApplication with the same authority type", nil, nil, nil, nil, nil);
            NSError *msalError = [MSALErrorConverter msalErrorFromMsidError:msidError];
            completionBlock(nil, msalError);
        }
        
        return;
    }
    
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
    MSIDInteractiveRequestParameters *msidParams =
    [[MSIDInteractiveRequestParameters alloc] initWithAuthority:requestAuthority
                                                    redirectUri:self.internalConfig.verifiedRedirectUri.url.absoluteString
                                                       clientId:self.internalConfig.clientId
                                                         scopes:[[NSOrderedSet alloc] initWithArray:parameters.scopes copyItems:YES]
                                                     oidcScopes:[self.class defaultOIDCScopes]
                                           extraScopesToConsent:parameters.extraScopesToConsent ? [[NSOrderedSet alloc]     initWithArray:parameters.extraScopesToConsent copyItems:YES] : nil
                                                  correlationId:parameters.correlationId
                                                 telemetryApiId:[NSString stringWithFormat:@"%ld", (long)parameters.telemetryApiId]
                                        supportedBrokerProtocol:MSID_BROKER_MSAL_SCHEME
                                                    requestType:interactiveRequestType
                                                          error:&msidError];
    
    if (!msidParams)
    {
        completionBlock(nil, [MSALErrorConverter msalErrorFromMsidError:msidError]);
        return;
    }
    
    msidParams.promptType = MSIDPromptTypeForPromptType(parameters.promptType);
    msidParams.loginHint = parameters.loginHint;
    msidParams.extraAuthorizeURLQueryParameters = parameters.extraQueryParameters;
    msidParams.accountIdentifier = parameters.account.lookupAccountIdentifier;
    
    msidParams.extraURLQueryParameters = self.internalConfig.extraQueryParameters.extraURLQueryParameters;
    
    NSMutableDictionary *extraAuthorizeURLQueryParameters = [self.internalConfig.extraQueryParameters.extraAuthorizeURLQueryParameters mutableCopy];
    [extraAuthorizeURLQueryParameters addEntriesFromDictionary:parameters.extraQueryParameters];
    msidParams.extraAuthorizeURLQueryParameters = extraAuthorizeURLQueryParameters;
    msidParams.extraTokenRequestParameters = self.internalConfig.extraQueryParameters.extraTokenURLParameters;
    
    msidParams.tokenExpirationBuffer = self.internalConfig.tokenExpirationBuffer;
    msidParams.extendedLifetimeEnabled = self.internalConfig.extendedLifetimeEnabled;
    msidParams.clientCapabilities = self.internalConfig.clientApplicationCapabilities;
    
    msidParams.validateAuthority = _validateAuthority;
    
    if (msidParams.validateAuthority
        && [self shouldExcludeValidationForAuthority:requestAuthority])
    {
        msidParams.validateAuthority = NO;
    }
    
#if TARGET_OS_IPHONE
    msidParams.parentViewController = parameters.parentViewController;
    msidParams.presentationType = parameters.presentationStyle;
#endif
    
    // Configure webview
    NSError *msidWebviewError = nil;
    MSIDWebviewType msidWebViewType = MSIDWebviewTypeFromMSALType(parameters.webviewType, &msidWebviewError);
    
    if (msidWebviewError)
    {
        completionBlock(nil, [MSALErrorConverter msalErrorFromMsidError:msidWebviewError]);
        return;
    }
    
    msidParams.webviewType = msidWebViewType;
    msidParams.telemetryWebviewType = MSALStringForMSALWebviewType(parameters.webviewType);
    msidParams.customWebview = parameters.customWebview ?: self.customWebview;
    msidParams.claimsRequest = parameters.claimsRequest.msidClaimsRequest;
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, msidParams,
                    @"-[MSALPublicClientApplication acquireTokenWithParameters:%@\n"
                    "                                     extraScopesToConsent:%@\n"
                    "                                                  account:%@\n"
                    "                                                loginHint:%@\n"
                    "                                               promptType:%@\n"
                    "                                     extraQueryParameters:%@\n"
                    "                                                authority:%@\n"
                    "                                              webviewType:%@\n"
                    "                                            customWebview:%@\n"
                    "                                            correlationId:%@\n"
                    "                                             capabilities:%@\n"
                    "                                            claimsRequest:%@]",
                    parameters.scopes,
                    parameters.extraScopesToConsent,
                    MSID_PII_LOG_MASKABLE(parameters.account.homeAccountId),
                    MSID_PII_LOG_EMAIL(parameters.loginHint),
                    MSALStringForPromptType(parameters.promptType),
                    parameters.extraQueryParameters,
                    parameters.authority,
                    MSALStringForMSALWebviewType(parameters.webviewType),
                    parameters.customWebview ? @"Yes" : @"No",
                    parameters.correlationId,
                    self.internalConfig.clientApplicationCapabilities,
                    parameters.claimsRequest);
    
    MSALCompletionBlock block = ^(MSALResult *result, NSError *msidError)
    {
        NSError *msalError = [MSALErrorConverter msalErrorFromMsidError:msidError classifyErrors:YES msalOauth2Provider:self.msalOauth2Provider];
        [MSALPublicClientApplication logOperation:@"acquireToken" result:result error:msalError context:msidParams];
        
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
    
    MSIDDefaultTokenRequestProvider *tokenRequestProvider = [[MSIDDefaultTokenRequestProvider alloc] initWithOauthFactory:self.msalOauth2Provider.msidOauth2Factory
                                                                                                          defaultAccessor:self.tokenCache
                                                                                                  accountMetadataAccessor:self.accountMetadataCache
                                                                                                   tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
#if TARGET_OS_OSX
    tokenRequestProvider.externalCacheSeeder = self.externalCacheSeeder;
#endif
    
    NSError *requestError = nil;
    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory interactiveControllerForParameters:msidParams tokenRequestProvider:tokenRequestProvider error:&requestError];
    
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
        MSALResult *msalResult = [self.msalOauth2Provider resultWithTokenResult:result error:&resultError];
        [self updateExternalAccountsWithResult:msalResult context:msidParams];
        
        block(msalResult, resultError);
    }];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
              completionBlock:(MSALCompletionBlock)completionBlock
{
    __auto_type parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes];
    parameters.telemetryApiId = MSALTelemetryApiIdAcquire;
    
    [self acquireTokenWithParameters:parameters completionBlock:completionBlock];
}

#pragma mark - Login Hint

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                    loginHint:(NSString *)loginHint
              completionBlock:(MSALCompletionBlock)completionBlock
{
    __auto_type parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes];
    parameters.loginHint = loginHint;
    parameters.telemetryApiId = MSALTelemetryApiIdAcquireWithHint;
    
    [self acquireTokenWithParameters:parameters completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                    loginHint:(NSString *)loginHint
                   promptType:(MSALPromptType)promptType
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
              completionBlock:(MSALCompletionBlock)completionBlock
{
    __auto_type parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes];
    parameters.loginHint = loginHint;
    parameters.promptType = promptType;
    parameters.extraQueryParameters = extraQueryParameters;
    parameters.telemetryApiId = MSALTelemetryApiIdAcquireWithHintPromptTypeAndParameters;
    
    [self acquireTokenWithParameters:parameters completionBlock:completionBlock];
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
    __auto_type parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes];
    parameters.extraScopesToConsent = extraScopesToConsent;
    parameters.loginHint = loginHint;
    parameters.promptType = promptType;
    parameters.extraQueryParameters = extraQueryParameters;
    parameters.authority = authority;
    parameters.correlationId = correlationId;
    parameters.telemetryApiId = MSALTelemetryApiIdAcquireWithHintPromptTypeParametersAuthorityAndCorrelationId;
    
    [self acquireTokenWithParameters:parameters completionBlock:completionBlock];
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
    __auto_type parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes];
    parameters.extraScopesToConsent = extraScopesToConsent;
    parameters.loginHint = loginHint;
    parameters.promptType = promptType;
    parameters.extraQueryParameters = extraQueryParameters;
    parameters.claimsRequest = claimsRequest;
    parameters.authority = authority;
    parameters.correlationId = correlationId;
    parameters.telemetryApiId = MSALTelemetryApiIdAcquireWithHintPromptTypeParametersAuthorityAndClaimsAndCorrelationId;
    
    [self acquireTokenWithParameters:parameters completionBlock:completionBlock];
}

#pragma mark - Account

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                      account:(MSALAccount *)account
              completionBlock:(MSALCompletionBlock)completionBlock
{
    __auto_type parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes];
    parameters.account = account;
    parameters.telemetryApiId = MSALTelemetryApiIdAcquireWithUserPromptTypeAndParameters;
    
    [self acquireTokenWithParameters:parameters completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                      account:(MSALAccount *)account
                   promptType:(MSALPromptType)promptType
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
              completionBlock:(MSALCompletionBlock)completionBlock
{
    __auto_type parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes];
    parameters.account = account;
    parameters.promptType = promptType;
    parameters.extraQueryParameters = extraQueryParameters;
    parameters.telemetryApiId = MSALTelemetryApiIdAcquireWithUserPromptTypeAndParameters;
    
    [self acquireTokenWithParameters:parameters completionBlock:completionBlock];
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
    __auto_type parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes];
    parameters.extraScopesToConsent = extraScopesToConsent;
    parameters.account = account;
    parameters.promptType = promptType;
    parameters.extraQueryParameters = extraQueryParameters;
    parameters.authority = authority;
    parameters.correlationId = correlationId;
    parameters.telemetryApiId = MSALTelemetryApiIdAcquireWithUserPromptTypeParametersAuthorityAndCorrelationId;
    
    [self acquireTokenWithParameters:parameters completionBlock:completionBlock];
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
    __auto_type parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes];
    parameters.extraScopesToConsent = extraScopesToConsent;
    parameters.account = account;
    parameters.promptType = promptType;
    parameters.extraQueryParameters = extraQueryParameters;
    parameters.claimsRequest = claimsRequest;
    parameters.authority = authority;
    parameters.correlationId = correlationId;
    parameters.telemetryApiId = MSALTelemetryApiIdAcquireWithUserPromptTypeParametersAuthorityAndCorrelationId;
    
    [self acquireTokenWithParameters:parameters completionBlock:completionBlock];
}

#pragma mark - Silent

- (void)acquireTokenSilentWithParameters:(MSALSilentTokenParameters *)parameters
                         completionBlock:(MSALCompletionBlock)completionBlock
{
    MSIDAuthority *providedAuthority = parameters.authority.msidAuthority ?: self.internalConfig.authority.msidAuthority;
    MSIDAuthority *requestAuthority = providedAuthority;
    
    // This is meant to avoid developer error, when they configure PCA with e.g. AAD authority, but pass B2C authority here
    // Authority type in PCA and parameters should match
    if (![self.msalOauth2Provider isSupportedAuthority:requestAuthority])
    {
        if (completionBlock)
        {
            NSError *msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Unsupported authority type. Please configure MSALPublicClientApplication with the same authority type", nil, nil, nil, nil, nil);
            NSError *msalError = [MSALErrorConverter msalErrorFromMsidError:msidError];
            completionBlock(nil, msalError);
        }
        
        return;
    }
    
    BOOL shouldValidate = _validateAuthority;
    
    if (shouldValidate && [self shouldExcludeValidationForAuthority:requestAuthority])
    {
        shouldValidate = NO;
    }
    
    /*
     In the acquire token silent call we assume developer wants to get access token for account's home tenant,
     if authority is a common, organizations or consumers authority.
     TODO: update instanceAware parameter to the instanceAware in config
     */
    NSError *authorityError = nil;
    requestAuthority = [self.msalOauth2Provider issuerAuthorityWithAccount:parameters.account
                                                          requestAuthority:requestAuthority
                                                             instanceAware:NO
                                                                     error:&authorityError];
    
    if (!requestAuthority)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Encountered an error when updating authority: %ld, %@", (long)authorityError.code, authorityError.domain);
        
        if (completionBlock)
        {
            NSError *msalError = [MSALErrorConverter msalErrorFromMsidError:authorityError];
            completionBlock(nil, msalError);
        }
        
        return;
    }
    
    NSError *msidError = nil;
    
    // add known authorities here.
    MSIDRequestParameters *msidParams = [[MSIDRequestParameters alloc] initWithAuthority:requestAuthority
                                                                         redirectUri:self.internalConfig.verifiedRedirectUri.url.absoluteString
                                                                            clientId:self.internalConfig.clientId
                                                                              scopes:[[NSOrderedSet alloc] initWithArray:parameters.scopes copyItems:YES]
                                                                          oidcScopes:[self.class defaultOIDCScopes]
                                                                       correlationId:parameters.correlationId
                                                                          telemetryApiId:[NSString stringWithFormat:@"%ld", (long)parameters.telemetryApiId]
                                                                               error:&msidError];
    
    if (!msidParams)
    {
        completionBlock(nil, [MSALErrorConverter msalErrorFromMsidError:msidError]);
        return;
    }
    
    // Set optional params
    msidParams.accountIdentifier = parameters.account.lookupAccountIdentifier;
    msidParams.validateAuthority = shouldValidate;
    msidParams.extendedLifetimeEnabled = self.internalConfig.extendedLifetimeEnabled;
    msidParams.clientCapabilities = self.internalConfig.clientApplicationCapabilities;
    msidParams.extraURLQueryParameters = self.internalConfig.extraQueryParameters.extraURLQueryParameters;
    msidParams.extraTokenRequestParameters = self.internalConfig.extraQueryParameters.extraTokenURLParameters;
    msidParams.tokenExpirationBuffer = self.internalConfig.tokenExpirationBuffer;
    msidParams.claimsRequest = parameters.claimsRequest.msidClaimsRequest;
    msidParams.providedAuthority = providedAuthority;
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, msidParams,
                 @"-[MSALPublicClientApplication acquireTokenSilentForScopes:%@\n"
                 "                                                  account:%@\n"
                 "                                                authority:%@\n"
                 "                                        validateAuthority:%@\n"
                 "                                             forceRefresh:%@\n"
                 "                                            correlationId:%@\n"
                 "                                             capabilities:%@\n"
                 "                                            claimsRequest:%@]",
                 parameters.scopes,
                 MSID_PII_LOG_EMAIL(parameters.account),
                 parameters.authority,
                 shouldValidate ? @"Yes" : @"No",
                 parameters.forceRefresh ? @"Yes" : @"No",
                 parameters.correlationId,
                 self.internalConfig.clientApplicationCapabilities,
                 parameters.claimsRequest);
    
    MSALCompletionBlock block = ^(MSALResult *result, NSError *msidError)
    {
        NSError *msalError = [MSALErrorConverter msalErrorFromMsidError:msidError classifyErrors:YES msalOauth2Provider:self.msalOauth2Provider];
        [MSALPublicClientApplication logOperation:@"acquireTokenSilent" result:result error:msalError context:msidParams];
        completionBlock(result, msalError);
    };
    
    MSIDDefaultTokenRequestProvider *tokenRequestProvider = [[MSIDDefaultTokenRequestProvider alloc] initWithOauthFactory:self.msalOauth2Provider.msidOauth2Factory
                                                                                                          defaultAccessor:self.tokenCache
                                                                                                  accountMetadataAccessor:self.accountMetadataCache
                                                                                                   tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
#if TARGET_OS_OSX
    tokenRequestProvider.externalCacheSeeder = self.externalCacheSeeder;
#endif
    
    NSError *requestError = nil;
    id<MSIDRequestControlling> requestController = [MSIDRequestControllerFactory silentControllerForParameters:msidParams forceRefresh:parameters.forceRefresh tokenRequestProvider:tokenRequestProvider error:&requestError];
    
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
        MSALResult *msalResult = [self.msalOauth2Provider resultWithTokenResult:result error:&resultError];
        [self updateExternalAccountsWithResult:msalResult context:msidParams];
        block(msalResult, resultError);
    }];
    
}

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                            account:(MSALAccount *)account
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    __auto_type parameters = [[MSALSilentTokenParameters alloc] initWithScopes:scopes account:account];
    parameters.telemetryApiId = MSALTelemetryApiIdAcquireSilentWithUser;
    
    [self acquireTokenSilentWithParameters:parameters completionBlock:completionBlock];
}

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                            account:(MSALAccount *)account
                          authority:(MSALAuthority *)authority
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    __auto_type parameters = [[MSALSilentTokenParameters alloc] initWithScopes:scopes account:account];
    parameters.authority = authority;
    parameters.telemetryApiId = MSALTelemetryApiIdAcquireSilentWithUserAndAuthority;
    
    [self acquireTokenSilentWithParameters:parameters completionBlock:completionBlock];
}

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                            account:(MSALAccount *)account
                          authority:(MSALAuthority *)authority
                       forceRefresh:(BOOL)forceRefresh
                      correlationId:(NSUUID *)correlationId
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    __auto_type parameters = [[MSALSilentTokenParameters alloc] initWithScopes:scopes account:account];
    parameters.authority = authority;
    parameters.forceRefresh = forceRefresh;
    parameters.correlationId = correlationId;
    parameters.telemetryApiId = MSALTelemetryApiIdAcquireSilentWithUserAuthorityForceRefreshAndCorrelationId;
    
    [self acquireTokenSilentWithParameters:parameters completionBlock:completionBlock];
}

- (void)acquireTokenSilentForScopes:(nonnull NSArray<NSString *> *)scopes
                            account:(nonnull MSALAccount *)account
                          authority:(nullable MSALAuthority *)authority
                      claimsRequest:(nullable MSALClaimsRequest *)claimsRequest
                       forceRefresh:(BOOL)forceRefresh
                      correlationId:(nullable NSUUID *)correlationId
                    completionBlock:(nonnull MSALCompletionBlock)completionBlock
{
    __auto_type parameters = [[MSALSilentTokenParameters alloc] initWithScopes:scopes account:account];
    parameters.authority = authority;
    parameters.claimsRequest = claimsRequest;
    parameters.forceRefresh = forceRefresh;
    parameters.correlationId = correlationId;
    parameters.telemetryApiId = MSALTelemetryApiIdAcquireSilentWithUserAuthorityClaimsForceRefreshAndCorrelationId;
    
    [self acquireTokenSilentWithParameters:parameters completionBlock:completionBlock];
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
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, ctx, @"%@ returning with error: (%@, %ld) %@", operation, error.domain, (long)error.code, MSID_PII_LOG_MASKABLE(errorDescription));
    }
    
    if (result)
    {
        NSString *hashedAT = [result.accessToken msidTokenHash];
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, ctx, @"%@ returning with at: %@ scopes:%@ expiration:%@", operation, hashedAT, result.scopes, result.expiresOn);
    }
}

- (void)updateExternalAccountsWithResult:(MSALResult *)result context:(id<MSIDRequestContext>)context
{
    if (result && self.externalAccountHandler)
    {
        NSError *updateError = nil;
        BOOL updateResult = [self.externalAccountHandler updateWithResult:result error:&updateError];
        
        if (!updateResult)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, context, @"Failed to update external account with result %@", MSID_PII_LOG_MASKABLE(updateError));
        }
    }
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
    
    if (self.externalAccountHandler)
    {
        NSError *externalError = nil;
        result &= [self.externalAccountHandler removeAccount:account error:&externalError];
        
        if (externalError && error)
        {
            *error = [MSALErrorConverter msalErrorFromMsidError:externalError];
        }
    }

    if (self.accountMetadataCache && ![self.accountMetadataCache clearForHomeAccountId:account.identifier
                                                                              clientId:self.internalConfig.clientId
                                                                               context:nil
                                                                                 error:error])
    {
        return NO;
    }
    
    return [self.msalOauth2Provider removeAdditionalAccountInfo:account
                                                          error:error];
}

- (BOOL)shouldExcludeValidationForAuthority:(MSIDAuthority *)authority
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
