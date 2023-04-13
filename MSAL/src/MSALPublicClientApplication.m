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
#import "MSIDCIAMAuthority.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSALRedirectUriVerifier.h"
#import "MSIDWebviewAuthorization.h"
#import "MSALAccountsProvider.h"
#import "MSALResult+Internal.h"
#import "MSIDRequestControllerFactory.h"
#import "MSIDRequestParameters.h"
#import "MSIDInteractiveTokenRequestParameters.h"
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
#import "MSALWebviewParameters.h"
#import "MSIDAccountIdentifier.h"
#if TARGET_OS_IPHONE
#import "MSIDCertAuthHandler+iOS.h"
#import "MSIDBrokerInteractiveController.h"
#import <UIKit/UIKit.h>
#else
#import "MSIDMacKeychainTokenCache.h"
#endif

#import "MSIDInteractiveRequestParameters+MSALRequest.h"
#import "MSIDTokenResult.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDSignoutController.h"
#import "MSALSignoutParameters.h"
#import "MSALPublicClientApplication+SingleAccount.h"
#import "MSALDeviceInfoProvider.h"
#import "MSALAuthenticationSchemeProtocol.h"
#import "MSALAuthenticationSchemeProtocolInternal.h"
#import "MSIDCurrentRequestTelemetry.h"
#import "MSIDCacheConfig.h"
#import "MSIDDevicePopManager.h"
#import "MSIDAssymetricKeyLookupAttributes.h"
#import "MSIDRequestTelemetryConstants.h"
#import "MSALWipeCacheForAllAccountsConfig.h"

@interface MSALPublicClientApplication()
{
    WKWebView *_customWebview;
    NSString *_defaultKeychainGroup;
}

@property (nonatomic) MSALPublicClientApplicationConfig *internalConfig;
@property (nonatomic) MSIDExternalAADCacheSeeder *externalCacheSeeder;
@property (nonatomic) MSIDCacheConfig *msidCacheConfig;
@property (nonatomic) MSIDDevicePopManager *popManager;
@property (nonatomic) MSIDAssymetricKeyLookupAttributes *keyPairAttributes;

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
    MSIDNotifications.webAuthDidReceiveResponseFromBrokerNotificationName = MSALWebAuthDidReceiveResponseFromBroker;
    #if TARGET_OS_IPHONE && !AD_BROKER
        [MSIDCertAuthHandler setUseAuthSession:YES];
    #endif
}

#pragma mark - Properties

- (MSALWebviewType)webviewType { return MSALGlobalConfig.defaultWebviewType; }
- (void)setWebviewType:(MSALWebviewType)webviewType { MSALGlobalConfig.defaultWebviewType = webviewType; }

#pragma mark - Initializers

- (id)initWithClientId:(NSString *)clientId
                 error:(NSError * __autoreleasing *)error
{
    return [self initPrivateWithClientId:clientId
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

- (instancetype)initWithConfiguration:(MSALPublicClientApplicationConfig *)config
                                error:(NSError **)error
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
                                                                    bypassRedirectValidation:config.bypassRedirectURIValidation
                                                                                       error:&msidError];
    
    if (!msalRedirectUri)
    {
        if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
        return nil;
    }
        
#if TARGET_OS_IPHONE
    if (MSALGlobalConfig.brokerAvailability == MSALBrokeredAvailabilityAuto
        && msalRedirectUri.brokerCapable
        && ![MSALRedirectUriVerifier verifyAdditionalRequiredSchemesAreRegistered:&msidError])
    {
        if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
        return nil;
    }
#endif
    
    config.verifiedRedirectUri = msalRedirectUri;
    
    BOOL cacheResult = [self setupTokenCacheWithConfiguration:config error:error];
    
    if (!cacheResult)
    {
        return nil;
    }
    
    _keyPairAttributes = [MSIDAssymetricKeyLookupAttributes new];
    _keyPairAttributes.privateKeyIdentifier = MSID_POP_TOKEN_PRIVATE_KEY;
    _keyPairAttributes.keyDisplayableLabel = MSID_POP_TOKEN_KEY_LABEL;
    
    _popManager = [[MSIDDevicePopManager alloc] initWithCacheConfig:self.msidCacheConfig keyPairAttributes:_keyPairAttributes];
        
    // Maintain an internal copy of config.
    // Developers shouldn't be able to change any properties on config after PCA has been created
    _configuration = config;
    _internalConfig = [config copy];
    
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
                 error:(NSError **)error
{
    return [self initPrivateWithClientId:clientId
                           keychainGroup:keychainGroup
                               authority:authority
                             redirectUri:redirectUri
                                   error:error];
}

#pragma mark - Keychain

#if TARGET_OS_IPHONE
- (BOOL)setupTokenCacheWithConfiguration:(MSALPublicClientApplicationConfig *)config error:(NSError **)error
{
    NSError *dataSourceError = nil;
    MSIDKeychainTokenCache *dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:config.cacheConfig.keychainSharingGroup error:&dataSourceError];
    
    if (!dataSource)
    {
        if (error) *error = [MSALErrorConverter msalErrorFromMsidError:dataSourceError];
        return NO;
    }
    
    MSIDLegacyTokenCacheAccessor *legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    NSArray *otherAccessors = legacyAccessor ? @[legacyAccessor] : nil;
    MSIDDefaultTokenCacheAccessor *defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:otherAccessors];
    self.tokenCache = defaultAccessor;
    self.accountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
    self.msidCacheConfig = [[MSIDCacheConfig alloc] initWithKeychainGroup:config.cacheConfig.keychainSharingGroup];
    return YES;
}
#else
- (BOOL)setupTokenCacheWithConfiguration:(MSALPublicClientApplicationConfig *)config error:(NSError **)error
{
    id<MSIDExtendedTokenCacheDataSource> dataSource = nil;
    id<MSIDExtendedTokenCacheDataSource> secondaryDataSource = nil;
    NSError *dataSourceError = nil;
    
    if (@available(macOS 10.15, *)) {
        dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:config.cacheConfig.keychainSharingGroup error:&dataSourceError];
        
        self.msidCacheConfig = [[MSIDCacheConfig alloc] initWithKeychainGroup:config.cacheConfig.keychainSharingGroup];
        
        NSError *secondaryDataSourceError = nil;
        secondaryDataSource = [[MSIDMacKeychainTokenCache alloc] initWithGroup:config.cacheConfig.keychainSharingGroup
                                                           trustedApplications:config.cacheConfig.trustedApplications
                                                                         error:&secondaryDataSourceError];
        
        if (secondaryDataSourceError)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"Failed to create secondary data source with error %@", MSID_PII_LOG_MASKABLE(secondaryDataSourceError));
        }
    }
    else
    {
        MSIDMacKeychainTokenCache *macDataSource = [[MSIDMacKeychainTokenCache alloc] initWithGroup:config.cacheConfig.keychainSharingGroup
                                                  trustedApplications:config.cacheConfig.trustedApplications
                                                                error:&dataSourceError];
        
        dataSource = macDataSource;
        self.msidCacheConfig = [[MSIDCacheConfig alloc] initWithKeychainGroup:config.cacheConfig.keychainSharingGroup accessRef:(__bridge SecAccessRef _Nullable)(macDataSource.accessControlForNonSharedItems)];
    }
    
    if (!dataSource)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"Failed to create primary data source with error %@", MSID_PII_LOG_MASKABLE(dataSourceError));
        if (error) *error = [MSALErrorConverter msalErrorFromMsidError:dataSourceError];
        return NO;
    }
    
    NSMutableArray *legacyAccessors = [NSMutableArray new];
    
    // Setup backward compatibility with ADAL's macOS cache
    id<MSIDTokenCacheDataSource> externalDataSource = config.cacheConfig.serializedADALCache.msidTokenCacheDataSource;
    if (externalDataSource)
    {
        __auto_type legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:externalDataSource otherCacheAccessors:nil];
        __auto_type defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
        _externalCacheSeeder = [[MSIDExternalAADCacheSeeder alloc] initWithDefaultAccessor:defaultAccessor
                                                                    externalLegacyAccessor:legacyAccessor];
        if (legacyAccessor) [legacyAccessors addObject:legacyAccessor];
    }
    
    // Setup backward compatibility on pre-10.15 devices with login keychain
    if (secondaryDataSource)
    {
        __auto_type secondaryAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:secondaryDataSource otherCacheAccessors:nil];
        if (secondaryAccessor) [legacyAccessors addObject:secondaryAccessor];
    }
    
    MSIDDefaultTokenCacheAccessor *defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:legacyAccessors];
    self.tokenCache = defaultAccessor;
    self.accountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
    return YES;
}
#endif

#pragma mark - Accounts

- (NSArray <MSALAccount *> *)allAccounts:(NSError * __autoreleasing *)error
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                accountMetadataCache:self.accountMetadataCache
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
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Querying MSAL account for identifier %@", MSID_PII_LOG_TRACKABLE(identifier));
    
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                accountMetadataCache:self.accountMetadataCache
                                                                            clientId:self.internalConfig.clientId
                                                             externalAccountProvider:self.externalAccountHandler];
    NSError *msidError = nil;
    
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:identifier];
    
    MSALAccount *account = [request accountForParameters:parameters error:&msidError];
    
    if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Found MSAL account with identifier %@, username %@", MSID_PII_LOG_TRACKABLE(account.identifier), MSID_PII_LOG_EMAIL(account.username));
    
    return account;
}

- (NSArray<MSALAccount *> *)accountsForParameters:(MSALAccountEnumerationParameters *)parameters
                                            error:(NSError **)error
{
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Querying MSAL accounts with parameters (identifier=%@, tenantProfileId=%@, username=%@, return only signed in accounts %d)", MSID_PII_LOG_TRACKABLE(parameters.identifier), MSID_PII_LOG_MASKABLE(parameters.tenantProfileIdentifier), MSID_PII_LOG_EMAIL(parameters.username), parameters.returnOnlySignedInAccounts);
    
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                accountMetadataCache:self.accountMetadataCache
                                                                            clientId:self.internalConfig.clientId
                                                             externalAccountProvider:self.externalAccountHandler];
    NSError *msidError = nil;
    NSArray *accounts = [request accountsForParameters:parameters error:&msidError];
    
    if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Found MSAL accounts with count %ld", (long)accounts.count);
    
    return accounts;
}

- (MSALAccount *)accountForUsername:(NSString *)username
                              error:(NSError * __autoreleasing *)error
{
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Querying MSAL account for username %@", MSID_PII_LOG_EMAIL(username));
    if ([NSString msidIsStringNilOrBlank:username])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"No username is provided", nil, nil, nil, nil, nil, YES);
        }
     
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"username is nil or empty which is unexpected");
        return nil;
    }
    
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                accountMetadataCache:self.accountMetadataCache
                                                                            clientId:self.internalConfig.clientId
                                                             externalAccountProvider:self.externalAccountHandler];
    NSError *msidError = nil;
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:nil username:username];
    MSALAccount *account = [request accountForParameters:parameters error:&msidError];

    if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Found MSAL account with identifier %@, username %@", MSID_PII_LOG_TRACKABLE(account.identifier), MSID_PII_LOG_EMAIL(account.username));

    return account;
}

- (void)allAccountsFilteredByAuthority:(MSALAccountsCompletionBlock)completionBlock
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                accountMetadataCache:self.accountMetadataCache
                                                                            clientId:self.internalConfig.clientId
                                                             externalAccountProvider:self.externalAccountHandler];

    [request allAccountsFilteredByAuthority:self.internalConfig.authority
                            completionBlock:^(NSArray<MSALAccount *> *accounts, NSError *msidError) {
        completionBlock(accounts, [MSALErrorConverter msalErrorFromMsidError:msidError]);
    }];
}

- (void)accountsFromDeviceForParameters:(nonnull MSALAccountEnumerationParameters *)parameters
                        completionBlock:(nonnull MSALAccountsCompletionBlock)completionBlock
{
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Querying MSAL accounts with parameters (identifier=%@, tenantProfileId=%@, username=%@, return only signed in accounts %d)", MSID_PII_LOG_MASKABLE(parameters.identifier), MSID_PII_LOG_MASKABLE(parameters.tenantProfileIdentifier), MSID_PII_LOG_EMAIL(parameters.username), parameters.returnOnlySignedInAccounts);
    
    __auto_type block = ^(NSArray<MSALAccount *> * _Nullable accounts, NSError * _Nullable msidError)
    {
        NSError *msalError = nil;
        
        if (msidError)
        {
            msalError = [MSALErrorConverter msalErrorFromMsidError:msidError classifyErrors:YES msalOauth2Provider:self.msalOauth2Provider];
        }
        else
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Found MSAL accounts with count %ld", (long)accounts.count);
        }
        
        [MSALPublicClientApplication logOperation:@"getAccountsFromDevice" result:nil error:msalError context:nil];
        
        if (!completionBlock) return;
        
        if (parameters.completionBlockQueue)
        {
            dispatch_async(parameters.completionBlockQueue, ^{
                completionBlock(accounts, msalError);
            });
        }
        else
        {
            completionBlock(accounts, msalError);
        }
    };
    
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                accountMetadataCache:self.accountMetadataCache
                                                                            clientId:self.internalConfig.clientId
                                                             externalAccountProvider:self.externalAccountHandler];
    
    NSError *requestParamsError;
    MSIDRequestParameters *requestParams = [self defaultRequestParametersWithError:&requestParamsError];
    
    if (!requestParams)
    {
        block(nil, requestParamsError);
        return;
    }
        
    [request allAccountsFromDevice:parameters
                 requestParameters:requestParams
                   completionBlock:block];
}

#pragma mark - Single Account

- (void)getCurrentAccountWithParameters:(MSALParameters *)parameters
                        completionBlock:(nonnull MSALCurrentAccountCompletionBlock)completionBlock
{
    __auto_type block = ^(MSALAccount *account, MSALAccount *previousAccount, NSError *msidError)
    {
        NSError *msalError = nil;
        
        if (msidError)
        {
            msalError = [MSALErrorConverter msalErrorFromMsidError:msidError classifyErrors:YES msalOauth2Provider:self.msalOauth2Provider];
        }
        else
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Found MSAL account with current account %@, previous account %@", MSID_PII_LOG_EMAIL(account.username), MSID_PII_LOG_EMAIL(previousAccount.username));
        }
        
        [MSALPublicClientApplication logOperation:@"getAccountsFromDevice" result:nil error:msalError context:nil];
        
        if (!completionBlock) return;
        
        if (parameters.completionBlockQueue)
        {
            dispatch_async(parameters.completionBlockQueue, ^{
                completionBlock(account, previousAccount, msalError);
            });
        }
        else
        {
            completionBlock(account, previousAccount, msalError);
        }
    };
    
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                accountMetadataCache:self.accountMetadataCache
                                                                            clientId:self.internalConfig.clientId
                                                             externalAccountProvider:self.externalAccountHandler];
    
    NSError *localError;
    MSALAccount *previousAccount = [request currentPrincipalAccount:&localError];
    
    if (localError)
    {
        block(nil, nil, localError);
        return;
    }
    
    MSALAccountEnumerationParameters *accountParameters = [MSALAccountEnumerationParameters new];
    accountParameters.returnOnlySignedInAccounts = YES;
    
    [self accountsFromDeviceForParameters:accountParameters
                          completionBlock:^(NSArray<MSALAccount *> * _Nullable accounts, NSError * _Nullable error) {
        
        if (error)
        {
            block(nil, nil, error);
            return;
        }
        
        if ([accounts count] > 1)
        {
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorCacheMultipleUsers, @"Multiple accounts found in cache.", nil, nil, nil, nil, nil, YES);
            block(nil, nil, error);
            return;
        }
        
        MSALAccount *newAccount = [accounts count] ? accounts[0] : nil;
        MSIDAccountIdentifier *newIdentifier = newAccount.lookupAccountIdentifier ?: nil;
        
        NSError *accountUpdateError;
        BOOL result = [request setCurrentPrincipalAccountId:newIdentifier accountEnvironment:newAccount.environment error:&accountUpdateError];
        
        if (!result)
        {
            block(nil, nil, accountUpdateError);
            return;
        }
        
        block(newAccount, previousAccount, nil);
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

    if ([MSIDCertAuthHandler completeCertAuthChallenge:response])
    {
        return YES;
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
    return [self acquireTokenWithParameters:parameters
             useWebviewTypeFromGlobalConfig:NO
                            completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
              completionBlock:(MSALCompletionBlock)completionBlock
{
    MSALWebviewParameters *webviewParameters = [MSALWebviewParameters new];
    __auto_type parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes
                                                                  webviewParameters:webviewParameters];
    parameters.telemetryApiId = MSALTelemetryApiIdAcquire;
    
    return [self acquireTokenWithParameters:parameters
             useWebviewTypeFromGlobalConfig:YES
                            completionBlock:completionBlock];
}

#pragma mark - Login Hint

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                    loginHint:(NSString *)loginHint
              completionBlock:(MSALCompletionBlock)completionBlock
{
    MSALWebviewParameters *webviewParameters = [MSALWebviewParameters new];
    __auto_type parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes
                                                                  webviewParameters:webviewParameters];
    parameters.loginHint = loginHint;
    parameters.telemetryApiId = MSALTelemetryApiIdAcquireWithHint;
    
    return [self acquireTokenWithParameters:parameters
             useWebviewTypeFromGlobalConfig:YES
                            completionBlock:completionBlock];
}

#pragma mark - Account

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                      account:(MSALAccount *)account
              completionBlock:(MSALCompletionBlock)completionBlock
{
    MSALWebviewParameters *webviewParameters = [MSALWebviewParameters new];
    __auto_type parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes
                                                                  webviewParameters:webviewParameters];
    parameters.account = account;
    parameters.telemetryApiId = MSALTelemetryApiIdAcquireWithUserPromptTypeAndParameters;
    
    return [self acquireTokenWithParameters:parameters
             useWebviewTypeFromGlobalConfig:YES
                            completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                      account:(MSALAccount *)account
                   promptType:(MSALPromptType)promptType
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
              completionBlock:(MSALCompletionBlock)completionBlock
{
    MSALWebviewParameters *webviewParameters = [MSALWebviewParameters new];
    __auto_type parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes
                                                                  webviewParameters:webviewParameters];
    parameters.account = account;
    parameters.promptType = promptType;
    parameters.extraQueryParameters = extraQueryParameters;
    parameters.telemetryApiId = MSALTelemetryApiIdAcquireWithUserPromptTypeAndParameters;
    
    return [self acquireTokenWithParameters:parameters
             useWebviewTypeFromGlobalConfig:YES
                            completionBlock:completionBlock];
}

#pragma mark - Silent

- (void)acquireTokenSilentWithParameters:(MSALSilentTokenParameters *)parameters
                         completionBlock:(MSALCompletionBlock)completionBlock
{
    __auto_type block = ^(MSALResult *result, NSError *msidError, id<MSIDRequestContext> context)
    {
        NSError *msalError = [MSALErrorConverter msalErrorFromMsidError:msidError classifyErrors:YES msalOauth2Provider:self.msalOauth2Provider correlationId:context.correlationId authScheme:parameters.authenticationScheme popManager:self.popManager];
        [MSALPublicClientApplication logOperation:@"acquireTokenSilent" result:result error:msalError context:context];
        
        if (!completionBlock) return;
        
        if (parameters.completionBlockQueue)
        {
            dispatch_async(parameters.completionBlockQueue, ^{
                completionBlock(result, msalError);
            });
        }
        else
        {
            completionBlock(result, msalError);
        }
    };
    
    if (!parameters.account)
    {
        NSError *noAccountError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired, @"No account provided for the silent request. Please call interactive acquireToken request to get an account identifier before calling acquireTokenSilent.", nil, nil, nil, nil, nil, YES);
        block(nil, noAccountError, nil);
        return;
    }
    
    MSIDAuthority *providedAuthority = parameters.authority.msidAuthority ?: self.internalConfig.authority.msidAuthority;
    MSIDAuthority *requestAuthority = providedAuthority;
    
    // This is meant to avoid developer error, when they configure PCA with e.g. AAD authority, but pass B2C authority here
    // Authority type in PCA and parameters should match
    if (![self.msalOauth2Provider isSupportedAuthority:requestAuthority])
    {
        NSError *msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Unsupported authority type. Please configure MSALPublicClientApplication with the same authority type", nil, nil, nil, nil, nil, YES);
        block(nil, msidError, nil);
        
        return;
    }
    
    BOOL shouldValidate = _validateAuthority;
    BOOL isDeveloperKnownAuthority = [self shouldExcludeValidationForAuthority:requestAuthority];
    
    if (shouldValidate && isDeveloperKnownAuthority)
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
                                                             instanceAware:self.internalConfig.multipleCloudsSupported
                                                                     error:&authorityError];
    
    if (!requestAuthority)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Encountered an error when updating authority: %ld, %@", (long)authorityError.code, authorityError.domain);
        
        block(nil, authorityError, nil);
        
        return;
    }
    
    requestAuthority.isDeveloperKnown = isDeveloperKnownAuthority;
    
    NSError *msidError = nil;
    
    MSIDRequestType requestType = [self requestType];
    
    id<MSALAuthenticationSchemeProtocol, MSALAuthenticationSchemeProtocolInternal>authenticationScheme = [self getInternalAuthenticationSchemeProtocolForScheme:parameters.authenticationScheme withError:&msidError];
    
    if (msidError)
    {
        block(nil, msidError, nil);
        return;
    }
    
    NSDictionary *schemeParams = [authenticationScheme getSchemeParameters:self.popManager];
    MSIDAuthenticationScheme *msidAuthScheme = [authenticationScheme createMSIDAuthenticationSchemeWithParams:schemeParams];
    
    // add known authorities here.
    MSIDRequestParameters *msidParams = [[MSIDRequestParameters alloc] initWithAuthority:requestAuthority
                                                                              authScheme:msidAuthScheme
                                                                         redirectUri:self.internalConfig.verifiedRedirectUri.url.absoluteString
                                                                            clientId:self.internalConfig.clientId
                                                                              scopes:[[NSOrderedSet alloc] initWithArray:parameters.scopes copyItems:YES]
                                                                          oidcScopes:[self.class defaultOIDCScopes]
                                                                       correlationId:parameters.correlationId
                                                                      telemetryApiId:[NSString stringWithFormat:@"%ld", (long)parameters.telemetryApiId]
                                                                 intuneAppIdentifier:[[NSBundle mainBundle] bundleIdentifier]
                                                                             requestType:requestType
                                                                               error:&msidError];
    
    if (!msidParams)
    {
        block(nil, msidError, nil);
        return;
    }
    
    // Set optional params
    msidParams.accountIdentifier = parameters.account.lookupAccountIdentifier;
    msidParams.validateAuthority = shouldValidate;
    msidParams.extendedLifetimeEnabled = self.internalConfig.extendedLifetimeEnabled;
    msidParams.clientCapabilities = self.internalConfig.clientApplicationCapabilities;
        
    // Extra parameters to be added to the /token endpoint.
    msidParams.extraTokenRequestParameters = self.internalConfig.extraQueryParameters.extraTokenURLParameters;
    
    NSMutableDictionary *extraURLQueryParameters = [self.internalConfig.extraQueryParameters.extraURLQueryParameters mutableCopy];
    [extraURLQueryParameters addEntriesFromDictionary:parameters.extraQueryParameters];
    msidParams.extraURLQueryParameters = extraURLQueryParameters;

    msidParams.tokenExpirationBuffer = self.internalConfig.tokenExpirationBuffer;
    msidParams.claimsRequest = parameters.claimsRequest.msidClaimsRequest;
    msidParams.providedAuthority = providedAuthority;
    msidParams.instanceAware = self.internalConfig.multipleCloudsSupported;
    msidParams.keychainAccessGroup = self.internalConfig.cacheConfig.keychainSharingGroup;
    msidParams.currentRequestTelemetry = [MSIDCurrentRequestTelemetry new];
    msidParams.currentRequestTelemetry.schemaVersion = HTTP_REQUEST_TELEMETRY_SCHEMA_VERSION;
    msidParams.currentRequestTelemetry.apiId = [msidParams.telemetryApiId integerValue];
    msidParams.currentRequestTelemetry.tokenCacheRefreshType = parameters.forceRefresh ? TokenCacheRefreshTypeForceRefresh : TokenCacheRefreshTypeNoCacheLookupInvolved;
    msidParams.allowUsingLocalCachedRtWhenSsoExtFailed = parameters.allowUsingLocalCachedRtWhenSsoExtFailed;
     
    // Nested auth protocol
    msidParams.nestedAuthBrokerClientId = self.internalConfig.nestedAuthBrokerClientId;
    msidParams.nestedAuthBrokerRedirectUri = self.internalConfig.nestedAuthBrokerRedirectUri;
    
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
    
    // Return early if account is in signed out state
    NSError *signInStateError;
    MSIDAccountMetadataState signInState = [self accountStateForParameters:msidParams error:&signInStateError];
    
    if (signInStateError)
    {
        block(nil, signInStateError, msidParams);
        return;
    }
    
    if (signInState == MSIDAccountMetadataStateSignedOut)
    {
        NSError *interactionError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired, @"Account is signed out, user interaction is required.", nil, nil, nil, msidParams.correlationId, nil, YES);
        block(nil, interactionError, msidParams);
        return;
    }
    
    MSIDDefaultTokenRequestProvider *tokenRequestProvider = [[MSIDDefaultTokenRequestProvider alloc] initWithOauthFactory:self.msalOauth2Provider.msidOauth2Factory
                                                                                                          defaultAccessor:self.tokenCache
                                                                                                  accountMetadataAccessor:self.accountMetadataCache
                                                                                                   tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
#if TARGET_OS_OSX
    tokenRequestProvider.externalCacheSeeder = self.externalCacheSeeder;
#endif
    
    NSError *requestError = nil;
    id<MSIDRequestControlling> requestController = [MSIDRequestControllerFactory silentControllerForParameters:msidParams
                                                                                                  forceRefresh:parameters.forceRefresh
                                                                                                   skipLocalRt:MSIDSilentControllerUndefinedLocalRtUsage
                                                                                          tokenRequestProvider:tokenRequestProvider
                                                                                                         error:&requestError];
    
    if (!requestController)
    {
        block(nil, requestError, msidParams);
        return;
    }
        
    [requestController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
        
        if (error)
        {
            block(nil, error, msidParams);
            return;
        }
        
        NSError *resultError = nil;
        MSALResult *msalResult = [self.msalOauth2Provider resultWithTokenResult:result authScheme:parameters.authenticationScheme popManager:self.popManager error:&resultError];
        
        if (result.tokenResponse)
        {
            // Only update external accounts if we got new result from network as an optimization
            [self updateExternalAccountsWithResult:msalResult context:msidParams];
        }
        
        block(msalResult, resultError, msidParams);
    }];
}

- (MSIDAccountMetadataState)accountStateForParameters:(MSIDRequestParameters *)msidParams error:(NSError **)signInStateError
{
    if (!msidParams.accountIdentifier.homeAccountId)
    {
        return MSIDAccountMetadataStateUnknown;
    }
    
    MSALAccountsProvider *accountsProvider = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                         accountMetadataCache:self.accountMetadataCache
                                                                                     clientId:self.internalConfig.clientId
                                                                      externalAccountProvider:self.externalAccountHandler];

    MSIDAccountMetadataState signInState = [accountsProvider signInStateForHomeAccountId:msidParams.accountIdentifier.homeAccountId
                                                                                 context:msidParams
                                                                                   error:signInStateError];
    
    return signInState;
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

- (id)initPrivateWithClientId:(NSString *)clientId
         keychainGroup:(__unused NSString *)keychainGroup
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

- (void)acquireTokenWithParameters:(MSALInteractiveTokenParameters *)parameters
    useWebviewTypeFromGlobalConfig:(BOOL)useWebviewTypeFromGlobalConfig
                   completionBlock:(MSALCompletionBlock)completionBlock
{
    __auto_type block = ^(MSALResult *result, NSError *msidError, id<MSIDRequestContext> context)
    {
        NSError *msalError = [MSALErrorConverter msalErrorFromMsidError:msidError classifyErrors:YES msalOauth2Provider:self.msalOauth2Provider correlationId:context.correlationId authScheme:parameters.authenticationScheme popManager:self.popManager];
        [MSALPublicClientApplication logOperation:@"acquireToken" result:result error:msalError context:context];
        
        if (!completionBlock) return;
        
        if ([NSThread isMainThread] && !parameters.completionBlockQueue)
        {
            completionBlock(result, msalError);
        }
        else
        {
            dispatch_async(parameters.completionBlockQueue ? parameters.completionBlockQueue : dispatch_get_main_queue(), ^{
                completionBlock(result, msalError);
            });
        }
    };
    
    NSError *authorityError;
    MSIDAuthority *requestAuthority = [self interactiveRequestAuthorityWithCustomAuthority:parameters.authority.msidAuthority error:&authorityError];
    
    if (!requestAuthority)
    {
        block(nil, authorityError, nil);
        return;
    }
    
    requestAuthority.isDeveloperKnown = [self shouldExcludeValidationForAuthority:requestAuthority];
    
    NSError *msidError = nil;
    
    MSIDBrokerInvocationOptions *brokerOptions = nil;
    
    MSIDRequestType requestType = [self requestType];
    
#if TARGET_OS_IPHONE
    MSIDBrokerProtocolType brokerProtocol = MSIDBrokerProtocolTypeCustomScheme;
    MSIDRequiredBrokerType requiredBrokerType = MSIDRequiredBrokerTypeWithV2Support;
    
    requiredBrokerType = MSIDRequiredBrokerTypeWithNonceSupport;
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Requiring default broker type due to app being built with iOS 13 SDK");
    
    if ([self.internalConfig.verifiedRedirectUri.url.absoluteString hasPrefix:@"https"])
    {
        brokerProtocol = MSIDBrokerProtocolTypeUniversalLink;
    }
    
    brokerOptions = [[MSIDBrokerInvocationOptions alloc] initWithRequiredBrokerType:requiredBrokerType
                                                                       protocolType:brokerProtocol
                                                                  aadRequestVersion:MSIDBrokerAADRequestVersionV2];

#endif
    
    id<MSALAuthenticationSchemeProtocol, MSALAuthenticationSchemeProtocolInternal>authenticationScheme = [self getInternalAuthenticationSchemeProtocolForScheme:parameters.authenticationScheme withError:&msidError];
    
    if (msidError)
    {
        block(nil, msidError, nil);
        return;
    }
    
    NSDictionary *schemeParams = [authenticationScheme getSchemeParameters:self.popManager];
    MSIDAuthenticationScheme *msidAuthScheme = [authenticationScheme createMSIDAuthenticationSchemeWithParams:schemeParams];
    
    MSIDInteractiveTokenRequestParameters *msidParams =
    [[MSIDInteractiveTokenRequestParameters alloc] initWithAuthority:requestAuthority
                                                          authScheme:msidAuthScheme
                                                         redirectUri:self.internalConfig.verifiedRedirectUri.url.absoluteString
                                                            clientId:self.internalConfig.clientId
                                                              scopes:[[NSOrderedSet alloc] initWithArray:parameters.scopes copyItems:YES]
                                                          oidcScopes:[self.class defaultOIDCScopes]
                                                extraScopesToConsent:parameters.extraScopesToConsent ? [[NSOrderedSet alloc]        initWithArray:parameters.extraScopesToConsent copyItems:YES] : nil
                                                       correlationId:parameters.correlationId
                                                      telemetryApiId:[NSString stringWithFormat:@"%ld", (long)parameters.telemetryApiId]
                                                       brokerOptions:brokerOptions
                                                         requestType:requestType
                                                 intuneAppIdentifier:[[NSBundle mainBundle] bundleIdentifier]
                                                               error:&msidError];
    
    if (!msidParams)
    {
        block(nil, msidError, nil);
        return;
    }
    
    // Nested auth protocol
    msidParams.nestedAuthBrokerClientId = self.internalConfig.nestedAuthBrokerClientId;
    msidParams.nestedAuthBrokerRedirectUri = self.internalConfig.nestedAuthBrokerRedirectUri;
    
    NSError *webViewParamsError;
    BOOL webViewParamsResult = [msidParams fillWithWebViewParameters:parameters.webviewParameters
                                      useWebviewTypeFromGlobalConfig:useWebviewTypeFromGlobalConfig
                                                       customWebView:_customWebview
                                                               error:&webViewParamsError];
    
    if (!webViewParamsResult)
    {
        block(nil, webViewParamsError, nil);
        return;
    }
        
    [msidParams setAccountIdentifierFromMSALAccount:parameters.account];
    
    msidParams.promptType = MSIDPromptTypeForPromptType(parameters.promptType);
    msidParams.loginHint = parameters.loginHint;
    
    // Extra parameters to be added to the /authorize endpoint.
    msidParams.extraAuthorizeURLQueryParameters = self.internalConfig.extraQueryParameters.extraAuthorizeURLQueryParameters;
    
    // Extra parameters to be added to the /token endpoint.
    msidParams.extraTokenRequestParameters = self.internalConfig.extraQueryParameters.extraTokenURLParameters;
    
    // Extra parameters to be added to both: /authorize and /token endpoints.
    NSMutableDictionary *extraURLQueryParameters = [self.internalConfig.extraQueryParameters.extraURLQueryParameters mutableCopy];
    [extraURLQueryParameters addEntriesFromDictionary:parameters.extraQueryParameters];
    msidParams.extraURLQueryParameters = extraURLQueryParameters;
    
    msidParams.tokenExpirationBuffer = self.internalConfig.tokenExpirationBuffer;
    msidParams.extendedLifetimeEnabled = self.internalConfig.extendedLifetimeEnabled;
    msidParams.clientCapabilities = self.internalConfig.clientApplicationCapabilities;
    
    msidParams.validateAuthority = [self shouldValidateAuthorityForRequestAuthority:requestAuthority];
    msidParams.instanceAware = self.internalConfig.multipleCloudsSupported;
    msidParams.keychainAccessGroup = self.internalConfig.cacheConfig.keychainSharingGroup;
    msidParams.claimsRequest = parameters.claimsRequest.msidClaimsRequest;
    msidParams.providedAuthority = requestAuthority;
    msidParams.shouldValidateResultAccount = NO;
    msidParams.currentRequestTelemetry = [MSIDCurrentRequestTelemetry new];
    msidParams.currentRequestTelemetry.schemaVersion = HTTP_REQUEST_TELEMETRY_SCHEMA_VERSION;
    msidParams.currentRequestTelemetry.apiId = [msidParams.telemetryApiId integerValue];
    msidParams.currentRequestTelemetry.tokenCacheRefreshType = TokenCacheRefreshTypeNoCacheLookupInvolved;
    
    MSIDAccountMetadataState signInState = [self accountStateForParameters:msidParams error:nil];
    
    if (signInState == MSIDAccountMetadataStateSignedOut && msidParams.promptType != MSIDPromptTypeConsent)
    {
        msidParams.promptType = MSIDPromptTypeLogin;
    }
    
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
                          MSID_PII_LOG_TRACKABLE(parameters.account.homeAccountId),
                          MSID_PII_LOG_EMAIL(parameters.loginHint),
                          MSALStringForPromptType(parameters.promptType),
                          parameters.extraQueryParameters,
                          parameters.authority,
                          MSALStringForMSALWebviewType(parameters.webviewParameters.webviewType),
                          parameters.webviewParameters.customWebview ? @"Yes" : @"No",
                          parameters.correlationId,
                          self.internalConfig.clientApplicationCapabilities,
                          parameters.claimsRequest);
    
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
        block(nil, requestError, msidParams);
        return;
    }
        
    [controller acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error)
    {
        if (error)
        {
            block(nil, error, msidParams);
            return;
        }
        
        NSError *resultError = nil;
        MSALResult *msalResult = [self.msalOauth2Provider resultWithTokenResult:result authScheme:parameters.authenticationScheme popManager:self.popManager error:&resultError];
        [self updateExternalAccountsWithResult:msalResult context:msidParams];
        
        block(msalResult, resultError, msidParams);
    }];
}

#pragma mark - Remove account from cache

- (BOOL)removeAccount:(MSALAccount *)account
                error:(NSError * __autoreleasing *)error
{
    return [self removeAccountImpl:account wipeAccount:NO error:error];
}

- (BOOL)removeAccountImpl:(MSALAccount *)account
              wipeAccount:(BOOL)wipeAccount
                    error:(NSError * __autoreleasing *)error
{
    if (!account)
    {
        return YES;
    }

    NSError *msidError = nil;
    
    // If developer is passing a wipeAccount flag, we want to wipe cache for any clientId
    NSString *clientId = wipeAccount ? nil : self.internalConfig.clientId;

    BOOL result = [self.tokenCache clearCacheForAccount:account.lookupAccountIdentifier
                                              authority:nil
                                               clientId:clientId
                                               familyId:nil
                                          clearAccounts:wipeAccount
                                                context:nil
                                                  error:&msidError];
    if (!result)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Clearing MSAL token cache for the specified account failed with error %@", MSID_PII_LOG_MASKABLE(msidError));
        if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
        return NO;
    }
    
    if (self.externalAccountHandler)
    {
        NSError *externalError = nil;
        result &= [self.externalAccountHandler removeAccount:account wipeAccount:wipeAccount error:&externalError];
        
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"External account removed with result %d", (int)result);
        
        if (externalError && error)
        {
            *error = [MSALErrorConverter msalErrorFromMsidError:externalError];
        }
    }

    if (!self.accountMetadataCache)
    {
        NSError *noAccountMetadataCacheError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"accountMetadataCache is nil when removing account!.", nil, nil, nil, nil, nil, YES);
        if (error) *error = [MSALErrorConverter msalErrorFromMsidError:noAccountMetadataCacheError];
        return NO;
    }
    
    msidError = nil;
    if (![self.accountMetadataCache updateSignInStateForHomeAccountId:account.identifier
                                                             clientId:self.internalConfig.clientId
                                                                state:MSIDAccountMetadataStateSignedOut
                                                              context:nil
                                                                error:&msidError])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Clearing account metadata cache failed");
        if (error) *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
        return NO;
    }
    
    return YES;
}

- (void)signoutWithAccount:(nonnull MSALAccount *)account
         signoutParameters:(nonnull MSALSignoutParameters *)signoutParameters
           completionBlock:(nonnull MSALSignoutCompletionBlock)signoutCompletionBlock
{
    __auto_type block = ^(BOOL result, NSError *msidError, id<MSIDRequestContext> context)
    {
        NSError *msalError = [MSALErrorConverter msalErrorFromMsidError:msidError classifyErrors:YES msalOauth2Provider:self.msalOauth2Provider correlationId:context.correlationId authScheme:nil popManager:nil];
        
        if (!result)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, context, @"Failed to complete signout operation for account %@ with error %@", MSID_PII_LOG_EMAIL(account.username), MSID_PII_LOG_MASKABLE(msalError));
        }
        else
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, @"Successfully completed signout operation for account %@", MSID_PII_LOG_EMAIL(account.username));
        }
        
        if (!signoutCompletionBlock) return;
        
        if ([NSThread isMainThread] && !signoutParameters.completionBlockQueue)
        {
            signoutCompletionBlock(result, msalError);
        }
        else
        {
            dispatch_async(signoutParameters.completionBlockQueue ? signoutParameters.completionBlockQueue : dispatch_get_main_queue(), ^{
                signoutCompletionBlock(result, msalError);
            });
        }
    };
    
    if (!account)
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Account is required", nil, nil, nil, nil, nil, NO);
        block(NO, error, nil);
        return;
    }
    
    NSError *authorityError;
    MSIDAuthority *requestAuthority = [self interactiveRequestAuthorityWithCustomAuthority:nil error:&authorityError];
    
    if (!requestAuthority)
    {
        block(NO, authorityError, nil);
        return;
    }
    
    NSError *paramsError;
    MSIDInteractiveRequestParameters *msidParams = [[MSIDInteractiveRequestParameters alloc] initWithAuthority:requestAuthority
                                                                                                    authScheme:nil
                                                                                                   redirectUri:self.internalConfig.verifiedRedirectUri.url.absoluteString
                                                                                                      clientId:self.internalConfig.clientId
                                                                                                        scopes:nil
                                                                                                    oidcScopes:nil
                                                                                                 correlationId:[NSUUID UUID]
                                                                                                telemetryApiId:nil
                                                                                           intuneAppIdentifier:nil
                                                                                                   requestType:[self requestType]
                                                                                                         error:&paramsError];
    
    if (!msidParams)
    {
        block(NO, paramsError, nil);
        return;
    }
    
    [msidParams setAccountIdentifierFromMSALAccount:account];
    
    if (signoutParameters.webviewParameters)
    {
        NSError *webViewParamsError;
        BOOL webViewParamsResult = [msidParams fillWithWebViewParameters:signoutParameters.webviewParameters
                                          useWebviewTypeFromGlobalConfig:NO
                                                           customWebView:_customWebview
                                                                   error:&webViewParamsError];
        
        if (!webViewParamsResult)
        {
            block(NO, webViewParamsError, msidParams);
            return;
        }
    }
    else if (signoutParameters.signoutFromBrowser)
    {
        NSError *browserError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Valid MSALWebviewParameters are required if signoutFromBrowser is requested. Please use [MSALSignoutParameters initWithWebviewParameters:] initializer", nil, nil, nil, nil, nil, YES);
        block(NO, browserError, msidParams);
        return;
    }
    
    msidParams.validateAuthority = [self shouldValidateAuthorityForRequestAuthority:requestAuthority];
    msidParams.keychainAccessGroup = self.internalConfig.cacheConfig.keychainSharingGroup;
    msidParams.providedAuthority = requestAuthority;
    
    NSError *localError;
    BOOL localRemovalResult = [self removeAccountImpl:account wipeAccount:signoutParameters.wipeAccount error:&localError];
    
    if (!localRemovalResult)
    {
        block(NO, localError, nil);
        return;
    }

    if (signoutParameters.wipeCacheForAllAccounts)
    {
        BOOL result = YES;
        NSError *localError;
        
        result = [self.tokenCache clearCacheForAllAccountsWithContext:nil error:&localError];
        
        if (!result)
        {
            block(NO, localError, nil);
            return;
        }

#if !TARGET_OS_IPHONE
        // Clear additional cache locations
        NSDictionary<NSString *, NSDictionary *> *additionalPartnerLocations = MSALWipeCacheForAllAccountsConfig.additionalPartnerLocations;
        if (additionalPartnerLocations && additionalPartnerLocations.count > 0)
        {
            NSError *removePartnerLocationError = nil;
            NSMutableArray <NSString *> *locationErrors = nil;
            MSIDMacACLKeychainAccessor *keychainAccessor = [[MSIDMacACLKeychainAccessor alloc] initWithTrustedApplications:nil accessLabel:@"Microsoft Credentials" error:nil];
            for (NSString* locationName in additionalPartnerLocations)
            {
                localError = nil;
                NSDictionary *cacheLocation = additionalPartnerLocations[locationName];
                
                // Try to read the keychain data in order to trigger the prompt asking for login password, user HAS TO click 'Always Allow' to then be able to delete it.
                [keychainAccessor getDataWithAttributes:cacheLocation
                                                context:nil
                                                  error:&localError];
                
                if (localError)
                {
                    result = NO;
                    if (!locationErrors)
                    {
                        locationErrors = [[NSMutableArray alloc] init];
                    }
                    [locationErrors addObject:[NSString stringWithFormat:@"'%@'", locationName]];
                    NSError *additionalLocationError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, [NSString stringWithFormat:@"WipeCacheForAllAccounts - error when reading cache for the item: %@.", locationName], nil, nil, localError, nil, nil, YES);
                    removePartnerLocationError = additionalLocationError;
                    continue;
                }
                
                BOOL removeResult = [keychainAccessor removeItemWithAttributes:cacheLocation
                                                                       context:nil
                                                                         error:&localError];

                if (!removeResult)
                {
                    result = NO;
                    if (!locationErrors)
                    {
                        locationErrors = [[NSMutableArray alloc] init];
                    }
                    [locationErrors addObject:[NSString stringWithFormat:@"'%@'", locationName]];
                    removePartnerLocationError = localError;
                }
            }
            
            if (!result && locationErrors)
            {
                NSError *additionalLocationError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, [NSString stringWithFormat:@"WipeCacheForAllAccounts - error when removing cache for the item(s): %@. User might need to select 'Always Allow' when prompted the login password to access keychain.", [locationErrors componentsJoinedByString:@", "]], nil, nil, removePartnerLocationError, nil, @{@"locationErrors":locationErrors}, YES);
                block(NO, additionalLocationError, nil);
                return;
            }
        }
#endif
    }
    
    NSError *controllerError;
    MSIDSignoutController *controller = [MSIDRequestControllerFactory signoutControllerForParameters:msidParams
                                                                                        oauthFactory:self.msalOauth2Provider.msidOauth2Factory
                                                                            shouldSignoutFromBrowser:signoutParameters.signoutFromBrowser
                                                                                   shouldWipeAccount:signoutParameters.wipeAccount
                                                                       shouldWipeCacheForAllAccounts:signoutParameters.wipeCacheForAllAccounts
                                                                                               error:&controllerError];
    
    if (!controller)
    {
        block(NO, controllerError, msidParams);
        return;
    }
    
    [controller executeRequestWithCompletion:^(BOOL success, NSError * _Nullable error) {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, msidParams, @"Finished executing signout request with type %@", [controller class]);
        block(success, error, msidParams);
    }];
}

#pragma mark - Device information

- (void)getDeviceInformationWithParameters:(MSALParameters *)parameters
                           completionBlock:(MSALDeviceInformationCompletionBlock)completionBlock
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Querying device info");
    
    NSError *requestParamsError;
    MSIDRequestParameters *requestParams = [self defaultRequestParametersWithError:&requestParamsError];

    __auto_type block = ^(MSALDeviceInformation * _Nullable deviceInformation, NSError * _Nullable msidError)
    {
        NSError *msalError = nil;
        
        if (msidError)
        {
            msalError = [MSALErrorConverter msalErrorFromMsidError:msidError classifyErrors:YES msalOauth2Provider:self.msalOauth2Provider];
        }
        else
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, requestParams, @"Retrieved device info %@", MSID_PII_LOG_MASKABLE(deviceInformation));
        }
        
        [MSALPublicClientApplication logOperation:@"getDeviceInformation" result:nil error:msalError context:nil];
        
        if (!completionBlock) return;
        
        if (parameters.completionBlockQueue)
        {
            dispatch_async(parameters.completionBlockQueue, ^{
                completionBlock(deviceInformation, msalError);
            });
        }
        else
        {
            completionBlock(deviceInformation, msalError);
        }
    };
    
    if (!requestParams)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, requestParams, @"GetDeviceInfo: Error when creating requestParams: %@", requestParamsError);
        block(nil, requestParamsError);
        return;
    }
    
    MSALDeviceInfoProvider *deviceInfoProvider = [MSALDeviceInfoProvider new];
    [deviceInfoProvider deviceInfoWithRequestParameters:requestParams completionBlock:block];
}

- (void)getWPJMetaDataDeviceWithParameters:(nullable MSALParameters *)parameters
                               forTenantId:(nullable NSString *)tenantId
                           completionBlock:(nonnull MSALWPJMetaDataCompletionBlock)completionBlock
{;

    NSError *requestParamsError;
    MSIDRequestParameters *requestParams = [self defaultRequestParametersWithError:&requestParamsError];

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, requestParams, @"Querying WPJ MetaData for tenantId: %@", MSID_PII_LOG_MASKABLE(tenantId));

    __auto_type block = ^(MSALWPJMetaData * _Nullable wpjMetaData, NSError * _Nullable msidError)
    {
        NSError *msalError = nil;
        
        if (msidError)
        {
            msalError = [MSALErrorConverter msalErrorFromMsidError:msidError classifyErrors:YES msalOauth2Provider:self.msalOauth2Provider];
        }
        else
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, requestParams, @"Retrieved metadata device info %@", MSID_PII_LOG_MASKABLE(wpjMetaData));
        }
        
        [MSALPublicClientApplication logOperation:@"getWPJMetaDataDeviceWithParameters" result:nil error:msalError context:requestParams];
        
        if (!completionBlock) return;
        
        if (parameters.completionBlockQueue)
        {
            dispatch_async(parameters.completionBlockQueue, ^{
                completionBlock(wpjMetaData, msalError);
            });
        }
        else
        {
            completionBlock(wpjMetaData, msalError);
        }
    };
            
    if (!requestParams)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, requestParams, @"getWPJMetaDataDeviceWithParameters: Error when creating requestParams: %@", requestParamsError);
        block(nil, requestParamsError);
        return;
    }
    
    MSALDeviceInfoProvider *deviceInfoProvider = [MSALDeviceInfoProvider new];
    [deviceInfoProvider wpjMetaDataDeviceInfoWithRequestParameters:requestParams tenantId:tenantId completionBlock:block];
}

- (BOOL)isCompatibleAADBrokerAvailable
{
#if TARGET_OS_IPHONE
    MSIDRequiredBrokerType requiredBrokerType = MSIDRequiredBrokerTypeWithV2Support;
    
    requiredBrokerType = MSIDRequiredBrokerTypeWithNonceSupport;
    
    // Parameter protocolType does not matter here
    MSIDBrokerInvocationOptions *brokerOptions = [[MSIDBrokerInvocationOptions alloc] initWithRequiredBrokerType:requiredBrokerType
                                                                                                    protocolType:MSIDBrokerProtocolTypeCustomScheme
                                                                                               aadRequestVersion:MSIDBrokerAADRequestVersionV2];
    
    return [brokerOptions isRequiredBrokerPresent];
    
#else
    return NO;
#endif

    
}

#pragma mark - Authority validation

- (BOOL)shouldValidateAuthorityForRequestAuthority:(MSIDAuthority *)requestAuthority
{
    BOOL validateAuthority = _validateAuthority;
    
    if (validateAuthority
        && [self shouldExcludeValidationForAuthority:requestAuthority])
    {
        return NO;
    }
    
    return validateAuthority;
}

- (BOOL)shouldExcludeValidationForAuthority:(MSIDAuthority *)authority
{
    if (self.internalConfig.knownAuthorities)
    {
        for (MSALAuthority *knownAuthority in self.internalConfig.knownAuthorities)
        {
            if ([authority isKindOfClass:knownAuthority.msidAuthority.class]
                && [knownAuthority.url isEqual:authority.url])
            {
                return YES;
            }
        }
    }
    
    if (authority.excludeFromAuthorityValidation)
    {
        return YES;
    }
    
    return NO;
}

+ (NSOrderedSet *)defaultOIDCScopes
{
    return [NSOrderedSet orderedSetWithObjects:MSID_OAUTH2_SCOPE_OPENID_VALUE,
                                               MSID_OAUTH2_SCOPE_PROFILE_VALUE,
                                               MSID_OAUTH2_SCOPE_OFFLINE_ACCESS_VALUE, nil];
}

+ (NSString *)sdkVersion
{
    return @MSAL_VERSION_STRING;
}


#pragma mark - Private

- (id<MSALAuthenticationSchemeProtocol, MSALAuthenticationSchemeProtocolInternal>)getInternalAuthenticationSchemeProtocolForScheme:(id<MSALAuthenticationSchemeProtocol>)authenticationScheme
                                                                                                                         withError:(NSError **)error
{
    if (![authenticationScheme conformsToProtocol:@protocol(MSALAuthenticationSchemeProtocolInternal)])
    {
        NSError *msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"authenticationScheme doesn't support MSALAuthenticationSchemeProtocolInternal protocol.", nil, nil, nil, nil, nil, YES);
        if (error) *error = msidError;
        
        return nil;
    }
    
    return (id<MSALAuthenticationSchemeProtocol, MSALAuthenticationSchemeProtocolInternal>)authenticationScheme;
}

- (MSIDRequestType)requestType
{
    MSIDRequestType requestType = MSIDRequestBrokeredType;
            
    if (MSALGlobalConfig.brokerAvailability == MSALBrokeredAvailabilityNone)
    {
        requestType = MSIDRequestLocalType;
    }
    else if (!self.internalConfig.verifiedRedirectUri.brokerCapable)
    {
        requestType = MSIDRequestLocalType;
    }
    
    return requestType;
}

- (MSIDAuthority *)interactiveRequestAuthorityWithCustomAuthority:(MSIDAuthority *)customAuthority
                                                            error:(NSError **)error
{
    MSIDAuthority *requestAuthority = customAuthority ?: self.internalConfig.authority.msidAuthority;
    
    if (![self.msalOauth2Provider isSupportedAuthority:requestAuthority])
    {
        NSError *msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Unsupported authority type. Please configure MSALPublicClientApplication with the same authority type", nil, nil, nil, nil, nil, YES);
        if (error) *error = msidError;
        return nil;
    }
    
    return requestAuthority;
}

- (MSIDRequestParameters *)defaultRequestParametersWithError:(NSError **)requestParamsError
{
    MSIDRequestParameters *requestParams = [[MSIDRequestParameters alloc] initWithAuthority:self.internalConfig.authority.msidAuthority
                                                                                 authScheme:nil
                                                                                redirectUri:self.internalConfig.redirectUri
                                                                                   clientId:self.internalConfig.clientId
                                                                                     scopes:nil
                                                                                 oidcScopes:nil
                                                                              correlationId:nil
                                                                             telemetryApiId:nil
                                                                        intuneAppIdentifier:nil
                                                                                requestType:[self requestType]
                                                                                      error:requestParamsError];
    
    requestParams.validateAuthority = [self shouldValidateAuthorityForRequestAuthority:self.internalConfig.authority.msidAuthority];
    return requestParams;
}

@end
