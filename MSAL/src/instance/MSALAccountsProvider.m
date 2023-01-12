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

#import "MSALAccountsProvider.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSALAuthority.h"
#import "MSALAuthority_Internal.h"
#import "MSIDAuthority.h"
#import "MSALAccount+Internal.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDAccount.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDConfiguration.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDConstants.h"
#import "MSIDAADAuthority.h"
#import "MSIDB2CAuthority.h"
#import "MSIDADFSAuthority.h"
#import "MSIDIdTokenClaims.h"
#import "MSALAccount+Internal.h"
#import "MSIDIdToken.h"
#import "MSALExternalAccountHandler.h"
#import "MSALAccountEnumerationParameters.h"
#import "MSALErrorConverter.h"
#import "MSALTenantProfile.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSALAccount+MultiTenantAccount.h"
#import "MSIDSSOExtensionGetAccountsRequest.h"
#import "MSIDRequestParameters+Broker.h"
#import "MSALAccount+Internal.h"
#import "MSALAccountId+Internal.h"
#import "MSIDAccountMetadataCacheItem.h"

@interface MSALAccountsProvider()

@property (nullable, nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;
@property (nullable, nonatomic) MSIDAccountMetadataCacheAccessor *accountMetadataCache;
@property (nullable, nonatomic) NSString *clientId;
@property (nullable, nonatomic) MSALExternalAccountHandler *externalAccountProvider;
@property (nullable, nonatomic) NSPredicate *homeTenantFilterPredicate;

@end

@implementation MSALAccountsProvider

#pragma mark - Init

- (instancetype)initWithTokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
              accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
                          clientId:(NSString *)clientId
{
    return [self initWithTokenCache:tokenCache
               accountMetadataCache:accountMetadataCache
                           clientId:clientId
            externalAccountProvider:nil];
}

- (instancetype)initWithTokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
              accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
                          clientId:(NSString *)clientId
           externalAccountProvider:(MSALExternalAccountHandler *)externalAccountProvider
{
    self = [super init];

    if (self)
    {
        _tokenCache = tokenCache;
        _accountMetadataCache = accountMetadataCache;
        _clientId = clientId;
        _externalAccountProvider = externalAccountProvider;
        _homeTenantFilterPredicate = [NSPredicate predicateWithFormat:@"isHomeTenantProfile == YES"];
    }

    return self;
}

#pragma mark - Convenience

- (NSArray <MSALAccount *> *)allAccounts:(NSError * __autoreleasing *)error
{
    return [self accountsForParameters:[MSALAccountEnumerationParameters new] authority:nil error:error];
}

- (NSArray<MSALAccount *> *)accountsForParameters:(MSALAccountEnumerationParameters *)parameters
                                            error:(NSError * __autoreleasing *)error
{
    return [self accountsForParameters:parameters authority:nil error:error];
}

- (MSALAccount *)accountForParameters:(MSALAccountEnumerationParameters *)parameters
                                error:(NSError * __autoreleasing *)error
{
    NSError *internalError = nil;
    NSArray<MSALAccount *> *accounts = [self accountsForParameters:parameters authority:nil error:&internalError];
    
    if (internalError)
    {
        if (error) *error = internalError;
        return nil;
    }
    
    if ([accounts count])
    {
        if (accounts.count == 1)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Returning account for parameters with environment %@, identifier %@, username %@", accounts[0].environment, MSID_PII_LOG_TRACKABLE(accounts[0].identifier), MSID_PII_LOG_EMAIL(accounts[0].username));
            return accounts[0];
        }
        else if (accounts.count > 1)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Retrieved more than 1 msal accounts! (More info: environments are equal for first 2 accounts: %@ (%@, %@), homeAccountIds are equal for first 2 accounts: %@, usernames are equal for first 2 accounts: %@)", [accounts[0].environment isEqualToString:accounts[1].environment] ? @"YES" : @"NO", accounts[0].environment, accounts[1].environment, [accounts[0].identifier isEqualToString:accounts[1].identifier] ? @"YES" : @"NO", [accounts[0].username isEqualToString:accounts[1].username] ? @"YES" : @"NO");
            return accounts[0];
        }
    }
    
    return nil;
}

#pragma mark - Filtering

- (NSArray<MSALAccount *> *)accountsForParameters:(MSALAccountEnumerationParameters *)parameters
                                        authority:(MSIDAuthority *)authority
                                            error:(NSError * __autoreleasing *)error
{
    return [self accountsForParameters:parameters
                             authority:authority
                        brokerAccounts:nil
                                 error:error];
}

- (NSArray<MSALAccount *> *)accountsForParameters:(MSALAccountEnumerationParameters *)parameters
                                        authority:(MSIDAuthority *)authority
                                   brokerAccounts:(NSArray<MSIDAccount *> *)brokerAccounts
                                            error:(NSError * __autoreleasing *)error
{
    NSError *msidError = nil;
    
    NSString *queryClientId = nil;
    NSString *queryFamilyId = nil;
    
    if (!parameters || parameters.returnOnlySignedInAccounts)
    {
        MSIDAppMetadataCacheItem *appMetadata = [self appMetadataItem];
        NSString *familyId = appMetadata ? appMetadata.familyId : MSID_DEFAULT_FAMILY_ID;
        
        queryClientId = self.clientId;
        
        queryFamilyId = familyId;
    }
    
    MSIDAccountIdentifier *queryAccountIdentifier = nil;
    
    if (![NSString msidIsStringNilOrBlank:parameters.identifier]
        || ![NSString msidIsStringNilOrBlank:parameters.username])
    {
        queryAccountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:parameters.username homeAccountId:parameters.identifier];
    }
    
    NSMutableArray *allAccounts = [NSMutableArray new];
    
    NSArray *msidAccounts = [self.tokenCache accountsWithAuthority:authority
                                                          clientId:queryClientId
                                                          familyId:queryFamilyId
                                                 accountIdentifier:queryAccountIdentifier
                                              accountMetadataCache:self.accountMetadataCache
                                              signedInAccountsOnly:parameters.returnOnlySignedInAccounts
                                                           context:nil
                                                             error:&msidError];
    
    if (msidError)
    {
        if (error)
        {
            *error = [MSALErrorConverter msalErrorFromMsidError:msidError];
        }
        return nil;
    }
    
    if (msidAccounts) [allAccounts addObjectsFromArray:msidAccounts];
    if (brokerAccounts) [allAccounts addObjectsFromArray:brokerAccounts];
    
    return [self filteredAccountsForParameters:parameters msidAccounts:allAccounts includeExternalAccounts:YES];
}

- (NSArray<MSALAccount *> *)filteredAccountsForParameters:(MSALAccountEnumerationParameters *)parameters
                                             msidAccounts:(NSArray<MSIDAccount *> *)msidAccounts
                                     includeExternalAccounts:(BOOL)includeExternalAccounts
{
    BOOL filterByLocalId = ![NSString msidIsStringNilOrBlank:parameters.tenantProfileIdentifier];
    BOOL filterByUsername = ![NSString msidIsStringNilOrBlank:parameters.username];
    BOOL filterByAccountId = ![NSString msidIsStringNilOrBlank:parameters.identifier];
    
    if (filterByLocalId || filterByUsername || filterByAccountId)
    {
        NSMutableArray *filteredAccounts = [NSMutableArray new];
        
        for (MSIDAccount *account in msidAccounts)
        {
            BOOL accountMatches = !filterByAccountId || (account.accountIdentifier.homeAccountId
                                                        && [account.accountIdentifier.homeAccountId caseInsensitiveCompare:parameters.identifier] == NSOrderedSame);
            
            if (filterByUsername)
            {
                accountMatches &= account.accountIdentifier.displayableId && [account.accountIdentifier.displayableId caseInsensitiveCompare:parameters.username] == NSOrderedSame;
            }
            
            if (filterByLocalId)
            {
                accountMatches &= account.localAccountId && [account.localAccountId caseInsensitiveCompare:parameters.tenantProfileIdentifier] == NSOrderedSame;
            }
            
            if (accountMatches)
            {
                [filteredAccounts addObject:account];
            }
        }
        
        msidAccounts = filteredAccounts;
    }
    
    NSArray *externalAccounts = nil;
    
    if (self.externalAccountProvider && includeExternalAccounts)
    {
        NSError *externalError = nil;
        externalAccounts = [self.externalAccountProvider allExternalAccountsWithParameters:parameters error:&externalError];
        
        if (externalError)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"Failed to read accounts from external cache with error %@. Ignoring error...", MSID_PII_LOG_MASKABLE(externalError));
        }
    }
    
    return [self msalAccountsFromMSIDAccounts:msidAccounts externalAccounts:externalAccounts];
}

#pragma mark - Internal

- (NSArray<MSALAccount *> *)msalAccountsFromMSIDAccounts:(NSArray *)msidAccounts
                                        externalAccounts:(NSArray *)externalAccounts
{
    NSMutableSet *resultAccounts = [NSMutableSet new];
    
    for (MSIDAccount *msidAccount in msidAccounts)
    {
        // if requiresRefreshToken
        // make sure account hasn't been marked as removed explicitly
        // if it has, don't return it
        // also don't flip familyId on account removal anymore
        
        MSALAccount *msalAccount = [[MSALAccount alloc] initWithMSIDAccount:msidAccount createTenantProfile:YES];
        if (!msalAccount) continue;
        
        NSDictionary *accountClaims = msidAccount.isHomeTenantAccount ? msidAccount.idTokenClaims.jsonDictionary : nil;
        [self addMSALAccount:msalAccount toSet:resultAccounts claims:accountClaims];
    }
    
    for (MSALAccount *externalAccount in externalAccounts)
    {
        NSDictionary *accountClaims = nil;
        
        if ([externalAccount.mTenantProfiles count])
        {
            NSArray<MSALTenantProfile *> *homeTenantProfileArray = [externalAccount.tenantProfiles filteredArrayUsingPredicate:self.homeTenantFilterPredicate];
            if ([homeTenantProfileArray count] == 1) accountClaims = homeTenantProfileArray[0].claims;
        }
    
        [self addMSALAccount:externalAccount toSet:resultAccounts claims:accountClaims];
    }
    
    return [resultAccounts allObjects];
}

- (void)addMSALAccount:(MSALAccount *)account toSet:(NSMutableSet *)allAccountsSet claims:(NSDictionary *)accountClaims
{
    MSALAccount *existingAccount = [allAccountsSet member:account];
    
    if (!existingAccount)
    {
        [allAccountsSet addObject:account];
        existingAccount = account;
    }
    else
    {
        [existingAccount addTenantProfiles:account.tenantProfiles];
    }
    
    if (accountClaims)
    {
        existingAccount.accountClaims = accountClaims;
        existingAccount.username = account.username;
    }
    
    if (account.isSSOAccount)
    {
        existingAccount.isSSOAccount = YES;
    }
}

#pragma mark - Authority (deprecated)

- (void)allAccountsFilteredByAuthority:(MSALAuthority *)authority
                       completionBlock:(MSALAccountsCompletionBlock)completionBlock
{
    [authority.msidAuthority resolveAndValidate:NO
                              userPrincipalName:nil
                                        context:nil
                                completionBlock:^(__unused NSURL * _Nullable openIdConfigurationEndpoint, __unused BOOL validated, NSError * _Nullable error) {
                                    
                                    if (error)
                                    {
                                        NSError *msalError = [MSALErrorConverter msalErrorFromMsidError:error];
                                        completionBlock(nil, msalError);
                                        return;
                                    }
                                    
                                    NSError *accountsError = nil;
                                    NSArray *accounts = [self accountsForParameters:nil authority:authority.msidAuthority error:&accountsError];
                                    completionBlock(accounts, accountsError);
                                }];
}

- (void)allAccountsFromDevice:(MSALAccountEnumerationParameters *)parameters
            requestParameters:(MSIDRequestParameters *)requestParameters
              completionBlock:(MSALAccountsCompletionBlock)completionBlock
{
    BOOL shouldCallBroker = NO;
    
    if (@available(macOS 10.15, *))
    {
        shouldCallBroker = [MSIDSSOExtensionGetAccountsRequest canPerformRequest] && [requestParameters shouldUseBroker];
    }
    
    if (!shouldCallBroker)
    {
        NSError *localError;
        NSArray<MSALAccount *> *msalAccounts = [self accountsForParameters:parameters authority:nil brokerAccounts:nil error:&localError];
        completionBlock(msalAccounts, localError);
        return;
    }
    
    if (@available(macOS 10.15, *))
    {
        [self allAccountsFromSSOExtension:parameters
                        requestParameters:requestParameters
                          completionBlock:completionBlock];
    }
}

- (void)allAccountsFromSSOExtension:(MSALAccountEnumerationParameters *)parameters
                  requestParameters:(MSIDRequestParameters *)requestParameters
                    completionBlock:(MSALAccountsCompletionBlock)completionBlock API_AVAILABLE(ios(13.0), macos(10.15))
{
    NSError *requestError;
    MSIDSSOExtensionGetAccountsRequest *ssoExtensionRequest = [[MSIDSSOExtensionGetAccountsRequest alloc] initWithRequestParameters:requestParameters
                                                                                                         returnOnlySignedInAccounts:parameters.returnOnlySignedInAccounts
                                                                                                                              error:&requestError];
    
    if (!ssoExtensionRequest)
    {
        completionBlock(nil, requestError);
        return;
    }
    
    if (![self setCurrentSSOExtensionRequest:ssoExtensionRequest])
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Trying to start a get accounts request while one is already executing", nil, nil, nil, nil, nil, YES);
        completionBlock(nil, error);
        return;
    }
    
    [ssoExtensionRequest executeRequestWithCompletion:^(NSArray<MSIDAccount *> * _Nullable accounts, BOOL returnBrokerAccountsOnly, NSError * _Nullable error)
    {
        [self copyAndClearCurrentSSOExtensionRequest];
        
        if (error)
        {
            completionBlock(nil, error);
            return;
        }
        
        if (returnBrokerAccountsOnly)
        {
            NSArray<MSALAccount *> *msalAccounts = [self filteredAccountsForParameters:parameters msidAccounts:accounts includeExternalAccounts:NO];
            completionBlock(msalAccounts, nil);
            return;
        }
        
        NSError *localError;
        NSArray<MSALAccount *> *msalAccounts = [self accountsForParameters:parameters authority:nil brokerAccounts:accounts error:&localError];
        completionBlock(msalAccounts, localError);
    }];
}

#pragma mark - App metadata

- (MSIDAppMetadataCacheItem *)appMetadataItem
{
    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:nil redirectUri:nil clientId:self.clientId target:nil];

    NSError *error = nil;
    NSArray *appMetadataItems = [self.tokenCache getAppMetadataEntries:configuration context:nil error:&error];

    if (error)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning,nil, @"Failed to retrieve app metadata items with error code %ld, %@", (long)error.code, error.domain);
        return nil;
    }

    if ([appMetadataItems count])
    {
        return appMetadataItems[0];
    }

    return nil;
}

#pragma mark - Account metadata
- (MSIDAccountMetadataState)signInStateForHomeAccountId:(NSString *)homeAccountId
                                                context:(id<MSIDRequestContext>)context
                                                  error:(NSError **)error
{
    if (!self.accountMetadataCache || [NSString msidIsStringNilOrBlank:homeAccountId])
    {
        return MSIDAccountMetadataStateUnknown;
    }
    
    return [self.accountMetadataCache signInStateForHomeAccountId:homeAccountId
                                                         clientId:self.clientId
                                                          context:context
                                                            error:error];
}

#pragma mark - Principal account id

- (MSALAccount *)currentPrincipalAccount:(NSError **)error
{
    MSIDAccountMetadataCacheItem *accountMetadataCacheItem = [self.accountMetadataCache retrieveAccountMetadataCacheItemForClientId:self.clientId context:nil error:error];
        
    if (!accountMetadataCacheItem.principalAccountId)
    {
        return nil;
    }
    
    MSIDAccountIdentifier *principalAccountId = accountMetadataCacheItem.principalAccountId;
    
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:principalAccountId.homeAccountId];
    parameters.returnOnlySignedInAccounts = NO;
    MSALAccount *account = [self accountForParameters:parameters error:error];
    
    if (account)
    {
        return account;
    }
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:principalAccountId.homeAccountId
                                                                       objectId:principalAccountId.uid
                                                                       tenantId:principalAccountId.utid];
    
    account = [[MSALAccount alloc] initWithUsername:principalAccountId.displayableId
                                      homeAccountId:accountId
                                        environment:accountMetadataCacheItem.principalAccountEnvironment
                                     tenantProfiles:nil];
    
    return account;
}

- (BOOL)setCurrentPrincipalAccountId:(MSIDAccountIdentifier *)currentAccountId accountEnvironment:(NSString *)accountEnvironment error:(NSError **)error
{
    return [self.accountMetadataCache updatePrincipalAccountIdForClientId:self.clientId
                                                       principalAccountId:currentAccountId
                                              principalAccountEnvironment:accountEnvironment
                                                                  context:nil
                                                                    error:error];
}

@end
