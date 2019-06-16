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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSALLegacySharedAccountsProvider.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDCacheKey.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSALLegacySharedAccountFactory.h"
#import "MSIDJsonObject.h"
#import "MSALLegacySharedAccount.h"
#import "MSALAccountEnumerationParameters.h"
#import "MSIDConstants.h"

@interface MSALLegacySharedAccountsProvider()

@property (nonatomic) MSIDKeychainTokenCache *keychainTokenCache;
@property (nonatomic) NSString *serviceIdentifier;
@property (nonatomic) NSString *applicationIdentifier;

@end

@implementation MSALLegacySharedAccountsProvider

#pragma mark - Init

- (instancetype)initWithSharedKeychainAccessGroup:(NSString *)sharedGroup
                                serviceIdentifier:(NSString *)serviceIdentifier
                            applicationIdentifier:(NSString *)applicationIdentifier
{
    self = [super init];
    
    if (self)
    {
        self.keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:sharedGroup];
        self.serviceIdentifier = serviceIdentifier;
        self.applicationIdentifier = applicationIdentifier;
    }
    
    return self;
}

#pragma mark - MSALExternalAccountProviding
#pragma mark - Update

- (BOOL)updateAccount:(MSALAccount *)account idTokenClaims:(NSDictionary *)idTokenClaims error:(NSError **)error
{
    if (self.sharedAccountMode != MSALLegacySharedAccountModeReadWrite)
    {
        return YES;
    }
    
    MSALAccountEnumerationParameters *parameters = [MSALLegacySharedAccountFactory parametersForAccount:account claims:idTokenClaims];
    
    if (!parameters)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Unsupported account found, skipping update");
        
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unsupported account found, skipping update", nil, nil, nil, nil, nil);
        }
        
        return NO;
    }
    
    NSTimeInterval writeTimeStamp = [[NSDate date] timeIntervalSince1970];
    
    for (int version = MSALLegacySharedAccountVersionV1; version <= MSALLegacySharedAccountVersionV3; version++)
    {
        NSString *versionIdentifier = [self accountVersionIdentifier:version];
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Updating accounts with version %@", versionIdentifier);
        
        NSError *versionError = nil;
        MSIDJsonObject *jsonObject = [self jsonObjectWithVersion:version error:&versionError];
        
        if (versionError)
        {
            NSString *logLine = [NSString stringWithFormat:@"Failed to retrieve accounts with version %@", versionIdentifier];
            [self fillAndLogError:error withError:versionError logLine:logLine];
            return NO;
        }
        
        if (!jsonObject)
        {
            jsonObject = [[MSIDJsonObject alloc] initWithJSONDictionary:[NSDictionary new] error:nil];
        }
        
        NSMutableDictionary *jsonDictionary = [[jsonObject jsonDictionary] mutableCopy];
        NSArray<MSALLegacySharedAccount *> *accounts = [self accountsFromJsonObject:jsonDictionary
                                                                     forMSALAccount:account
                                                                      idTokenClaims:idTokenClaims
                                                                   lookupParameters:parameters
                                                                            version:version
                                                                              error:&versionError];
        
        if (!accounts)
        {
            NSString *logLine = [NSString stringWithFormat:@"Failed to parse accounts with version %@", versionIdentifier];
            [self fillAndLogError:error withError:versionError logLine:logLine];
            return NO;
        }
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Updating accounts %@", MSID_PII_LOG_MASKABLE(accounts));
        
        for (MSALLegacySharedAccount *sharedAccount in accounts)
        {
            NSError *updateError = nil;
            BOOL updateResult = [sharedAccount updateAccountWithMSALAccount:account
                                                            applicationName:self.applicationIdentifier
                                                             accountVersion:version
                                                                      error:&updateError];
            
            if (!updateResult)
            {
                NSString *logLine = [NSString stringWithFormat:@"Failed to update accounts with version %@", versionIdentifier];
                [self fillAndLogError:error withError:updateError logLine:logLine];
                return NO;
            }
            
            jsonDictionary[sharedAccount.accountIdentifier] = [sharedAccount jsonDictionary];
        }
        
        jsonDictionary[@"lastWriteTimestamp"] = @(writeTimeStamp);
        writeTimeStamp += 1.0;
        
        BOOL saveResult = [self saveJSONDictionary:jsonDictionary
                                           version:version
                                             error:error];
        
        if (!saveResult)
        {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)removeAccount:(MSALAccount *)account error:(NSError * _Nullable * _Nullable)error
{
    if (self.sharedAccountMode != MSALLegacySharedAccountModeReadWrite)
    {
        return YES;
    }
    
    NSTimeInterval writeTimeStamp = [[NSDate date] timeIntervalSince1970];
    
    for (int version = MSALLegacySharedAccountVersionV2; version <= MSALLegacySharedAccountVersionV3; version++)
    {
        NSString *versionIdentifier = [self accountVersionIdentifier:version];
        NSError *versionError = nil;
        MSIDJsonObject *jsonObject = [self jsonObjectWithVersion:version error:&versionError];
        
        if (versionError)
        {
            NSString *logLine = [NSString stringWithFormat:@"Failed to retrieve accounts with version %@", versionIdentifier];
            [self fillAndLogError:error withError:versionError logLine:logLine];
            return NO;
        }
        
        NSMutableDictionary *jsonDictionary = [[jsonObject jsonDictionary] mutableCopy];
        
        NSError *readError = nil;
        NSArray<MSALLegacySharedAccount *> *accounts = [self accountsFromJsonObject:jsonDictionary fromMSALAccount:account error:&readError];
        
        if (!accounts)
        {
            NSString *logLine = [NSString stringWithFormat:@"Failed to parse accounts with version %@", versionIdentifier];
            [self fillAndLogError:error withError:readError logLine:logLine];
            return NO;
        }
        
        for (MSALLegacySharedAccount *account in accounts)
        {
            NSError *updateError = nil;
            BOOL updateResult = [account removeAccountWithApplicationName:self.applicationIdentifier
                                                           accountVersion:version
                                                                    error:&updateError];
            
            if (!updateResult)
            {
                NSString *logLine = [NSString stringWithFormat:@"Failed to update accounts with version %@", versionIdentifier];
                [self fillAndLogError:error withError:updateError logLine:logLine];
                return NO;
            }
            
            jsonDictionary[account.accountIdentifier] = [account jsonDictionary];
        }
        
        jsonDictionary[@"lastWriteTimestamp"] = @(writeTimeStamp);
        writeTimeStamp += 1.0;
        
        BOOL saveResult = [self saveJSONDictionary:jsonDictionary
                                           version:version
                                             error:error];
        
        if (!saveResult)
        {
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - Read

- (nullable NSArray<id<MSALAccount>> *)accountsWithParameters:(MSALAccountEnumerationParameters *)parameters
                                                        error:(NSError * _Nullable * _Nullable)error
{
    NSMutableSet *allAccounts = [NSMutableSet new];
    NSTimeInterval lastWrite = [[NSDate distantPast] timeIntervalSince1970];
    
    for (int version = MSALLegacySharedAccountVersionV3; version == MSALLegacySharedAccountVersionV1; version--)
    {
        NSString *versionIdentifier = [self accountVersionIdentifier:version];
        NSError *versionError = nil;
        MSIDJsonObject *jsonObject = [self jsonObjectWithVersion:version error:&versionError];
        
        if (!jsonObject)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to retrieve accounts with version %@, error %@", versionIdentifier, MSID_PII_LOG_MASKABLE(versionError));
            
            if (error && versionError)
            {
                *error = versionError;
            }
        }
        else
        {
            NSDictionary *jsonDictionary = [jsonObject jsonDictionary];
            NSNumber *lastWriteForVersion = [jsonDictionary msidObjectForKey:@"lastWriteTimestamp" ofClass:[NSNumber class]];
            
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Reading accounts with version %@, last write time stamp %@", versionIdentifier, lastWriteForVersion);
            
            if ([lastWriteForVersion floatValue] > lastWrite)
            {
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Accounts with version %@ are latest", versionIdentifier);
                
                NSArray *accounts = [self accountsFromJsonObject:jsonDictionary withParameters:parameters error:&versionError];
                
                if (!accounts)
                {
                    MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Failed to deserialize accounts with version %@, error %@", versionIdentifier, MSID_PII_LOG_MASKABLE(versionError));
                    continue;
                }
                
                lastWrite = [lastWriteForVersion floatValue];
                [allAccounts addObjectsFromArray:accounts];
            }
            else
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Older accounts dictionary found with version %@, skipping...", versionIdentifier);
            }
        }
    }
    
    NSArray *results = [allAccounts allObjects];
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, nil, @"Finished reading external accounts with results %@", MSID_PII_LOG_MASKABLE(results));
    return results;
}

- (nullable NSArray<MSALLegacySharedAccount *> *)accountsFromJsonObject:(NSDictionary *)jsonDictionary
                                                         withParameters:(MSALAccountEnumerationParameters *)parameters
                                                                  error:(NSError **)error
{
    NSMutableArray *resultAccounts = [NSMutableArray new];
    
    for (NSString *accountId in [jsonDictionary allKeys])
    {
        NSDictionary *singleAccountDictionary = [jsonDictionary msidObjectForKey:accountId ofClass:[NSDictionary class]];
        
        if (!singleAccountDictionary)
        {
            continue;
        }
        
        NSError *singleAccountError = nil;
        MSALLegacySharedAccount *account = [MSALLegacySharedAccountFactory accountWithJSONDictionary:singleAccountDictionary error:&singleAccountError];
        
        if (!account)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"Failed to create account with error %@", MSID_PII_LOG_MASKABLE(singleAccountError));
            continue;
        }
        
        if ([account matchesParameters:parameters])
        {
            [resultAccounts addObject:account];
        }
    }
    
    return resultAccounts;
}

- (nullable NSArray<MSALLegacySharedAccount *> *)accountsFromJsonObject:(NSDictionary *)jsonDictionary
                                                        fromMSALAccount:(MSALAccount *)account
                                                                  error:(NSError **)error
{
    NSMutableArray *allAccounts = [NSMutableArray new];
    
    for (MSALTenantProfile *tenantProfile in account.tenantProfiles)
    {
        MSALAccountEnumerationParameters *parameters = [MSALLegacySharedAccountFactory parametersForAccount:account claims:tenantProfile.claims];
        
        if (!parameters)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create parameters for the account");
            
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unable to create parameters for the account", nil, nil, nil, nil, nil);
            }
            
            return nil;
        }
        
        NSArray<MSALLegacySharedAccount *> *accounts = [self accountsFromJsonObject:jsonDictionary withParameters:parameters error:error];
        [allAccounts addObjectsFromArray:accounts];
    }
    
    return allAccounts;
}

- (nullable NSArray<MSALLegacySharedAccount *> *)accountsFromJsonObject:(NSDictionary *)jsonDictionary
                                                         forMSALAccount:(MSALAccount *)msalAccount
                                                          idTokenClaims:(NSDictionary *)idTokenClaims
                                                       lookupParameters:(MSALAccountEnumerationParameters *)parameters
                                                                version:(MSALLegacySharedAccountVersion)version
                                                                  error:(NSError **)error
{
    NSError *versionError = nil;
    NSArray<MSALLegacySharedAccount *> *accounts = [self accountsFromJsonObject:jsonDictionary withParameters:parameters error:&versionError];
    
    if (versionError)
    {
        if (error)
        {
            *error = versionError;
        }
        return nil;
    }
    
    if (![accounts count])
    {
        NSError *accountError = nil;
        MSALLegacySharedAccount *sharedAccount = [MSALLegacySharedAccountFactory accountWithMSALAccount:msalAccount
                                                                                                 claims:idTokenClaims
                                                                                        applicationName:self.applicationIdentifier
                                                                                         accountVersion:version
                                                                                                  error:&accountError];
        if (!sharedAccount)
        {
            if (error)
            {
                *error = accountError;
            }
            return nil;
        }
        
        accounts = @[sharedAccount];
    }
    
    return accounts;
}

#pragma mark - Keychain read

- (nullable MSIDJsonObject *)jsonObjectWithVersion:(MSALLegacySharedAccountVersion)version
                                             error:(NSError **)error
{
    NSString *versionIdentifier = [self accountVersionIdentifier:version];
    MSIDCacheKey *cacheKey = [[MSIDCacheKey alloc] initWithAccount:versionIdentifier
                                                           service:self.serviceIdentifier
                                                           generic:nil
                                                              type:nil];
    
    NSError *readError = nil;
    NSArray<MSIDJsonObject *> *jsonAccounts = [self.keychainTokenCache jsonObjectsWithKey:cacheKey
                                                                               serializer:[MSIDCacheItemJsonSerializer new]
                                                                                  context:nil
                                                                                    error:&readError];
    
    if (readError)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Failed to read external accounts with error %@, version %@", MSID_PII_LOG_MASKABLE(readError), versionIdentifier);
        
        if (error)
        {
            *error = readError;
        }
        
        return nil;
    }
    
    if ([jsonAccounts count] != 1)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Ambigious query for external accounts, found multiple accounts.");
        
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Ambigious query for external accounts, found multiple accounts.", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    return jsonAccounts[0];
}

- (BOOL)saveJSONDictionary:(NSDictionary *)jsonDictionary
                   version:(MSALLegacySharedAccountVersion)version
                     error:(NSError **)error
{
    NSString *versionIdentifier = [self accountVersionIdentifier:version];
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Saving accounts with version %@", versionIdentifier);
    
    MSIDCacheKey *cacheKey = [[MSIDCacheKey alloc] initWithAccount:versionIdentifier
                                                           service:self.serviceIdentifier
                                                           generic:nil
                                                              type:nil];
    
    NSError *saveError = nil;
    MSIDJsonObject *jsonObject = [[MSIDJsonObject alloc] initWithJSONDictionary:jsonDictionary error:&saveError];
    BOOL saveResult = [self.keychainTokenCache saveJsonObject:jsonObject
                                                   serializer:[MSIDCacheItemJsonSerializer new]
                                                          key:cacheKey
                                                      context:nil
                                                        error:&saveError];
    
    if (!saveResult)
    {
        NSString *logLine = [NSString stringWithFormat:@"Failed to save accounts with version %@", versionIdentifier];
        [self fillAndLogError:error withError:saveError logLine:logLine];
        return NO;
    }
    
    return YES;
}

#pragma mark - Helpers

- (void)fillAndLogError:(NSError **)error withError:(NSError *)resultError logLine:(NSString *)logLine
{
    MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@, error %@", logLine, MSID_PII_LOG_MASKABLE(resultError));
    
    if (error)
    {
        *error = resultError;
    }
}

- (NSString *)accountVersionIdentifier:(MSALLegacySharedAccountVersion)version
{
    return [NSString stringWithFormat:@"AccountsV%d", (int)version];
}

@end
