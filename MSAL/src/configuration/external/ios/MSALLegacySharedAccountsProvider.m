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
#import "MSALErrorConverter.h"
#import "MSALAccount.h"
#import "MSALTenantProfile.h"

@interface MSALLegacySharedAccountsProvider()

@property (nonatomic) MSIDKeychainTokenCache *keychainTokenCache;
@property (nonatomic) NSString *serviceIdentifier;
@property (nonatomic) NSString *applicationIdentifier;
@property (nonatomic) dispatch_queue_t synchronizationQueue;

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
        self.keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:sharedGroup error:nil];
        self.serviceIdentifier = serviceIdentifier;
        self.applicationIdentifier = applicationIdentifier;
        
        NSString *queueName = [NSString stringWithFormat:@"com.microsoft.legacysharedaccountsprovider-%@", [NSUUID UUID].UUIDString];
        _synchronizationQueue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    }
    
    return self;
}

#pragma mark - MSALExternalAccountProviding
#pragma mark - Read

- (nullable NSArray<id<MSALAccount>> *)accountsWithParameters:(MSALAccountEnumerationParameters *)parameters
                                                        error:(NSError * _Nullable * _Nullable)error
{
    __block NSArray *results = nil;
    __block NSError *readError = nil;
    
    dispatch_sync(self.synchronizationQueue, ^{
        results = [self accountsWithParametersImpl:parameters error:&readError];
    });
    
    if (error && readError)
    {
        *error = readError;
    }
    
    return results;
}

- (nullable NSArray<id<MSALAccount>> *)accountsWithParametersImpl:(MSALAccountEnumerationParameters *)parameters
                                                            error:(NSError * _Nullable * _Nullable)error
{
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Reading accounts with parameters %@", MSID_PII_LOG_MASKABLE(parameters));
    
    NSMutableSet *allAccounts = [NSMutableSet new];
    NSTimeInterval lastWrite = [[NSDate distantPast] timeIntervalSince1970];
    
    for (int version = MSALLegacySharedAccountVersionV3; version >= MSALLegacySharedAccountVersionV1; version--)
    {
        NSString *versionIdentifier = [self accountVersionIdentifier:version];
        NSError *readError = nil;
        MSIDJsonObject *jsonObject = [self jsonObjectWithVersion:version error:&readError];
        
        if (!jsonObject)
        {
            if (readError)
            {
                NSString *logLine = [NSString stringWithFormat:@"Failed to retrieve accounts with version %@", versionIdentifier];
                [self fillAndLogError:error withError:readError logLine:logLine];
                return nil;
            }
            
            continue;
        }
        
        NSDictionary *jsonDictionary = [jsonObject jsonDictionary];
        NSNumber *lastWriteForVersion = [jsonDictionary msidObjectForKey:@"lastWriteTimestamp" ofClass:[NSNumber class]];
        
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Reading accounts with version %@, last write time stamp %@", versionIdentifier, lastWriteForVersion);
        
        if ([lastWriteForVersion floatValue] > lastWrite)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Accounts with version %@ are latest", versionIdentifier);
            
            NSArray *accounts = [self accountsFromJsonObject:jsonDictionary withParameters:parameters error:&readError];
            
            if (!accounts)
            {
                [self fillAndLogError:error withError:readError logLine:@"Failed to deserialize accounts"];
                return nil;
            }
            
            lastWrite = [lastWriteForVersion floatValue];
            [allAccounts addObjectsFromArray:accounts];
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Older accounts dictionary found with version %@, skipping...", versionIdentifier);
            break;
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

#pragma mark - Update

- (BOOL)updateAccount:(id<MSALAccount>)account idTokenClaims:(NSDictionary *)idTokenClaims error:(NSError **)error
{
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Updating account %@", MSID_PII_LOG_MASKABLE(account));
    
    return [self updateAccount:account
                 idTokenClaims:idTokenClaims
                tenantProfiles:nil
                     operation:MSALLegacySharedAccountUpdateOperation
                         error:error];
}

- (nullable NSArray<MSALLegacySharedAccount *> *)updatableAccountsFromJsonObject:(NSDictionary *)jsonDictionary
                                                                     msalAccount:(id<MSALAccount>)msalAccount
                                                                   idTokenClaims:(NSDictionary *)idTokenClaims
                                                                         version:(MSALLegacySharedAccountVersion)version
                                                                           error:(NSError **)error
{
    MSALAccountEnumerationParameters *parameters = [MSALLegacySharedAccountFactory parametersForAccount:msalAccount tenantProfileIdentifier:idTokenClaims[@"oid"]];
    
    if (!parameters)
    {
        NSError *parameterError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unsupported account found, skipping update", nil, nil, nil, nil, nil);
        [self fillAndLogError:error withError:parameterError logLine:@"Unsupported account found, skipping update"];
        return nil;
    }
    
    NSError *parseError = nil;
    NSArray<MSALLegacySharedAccount *> *accounts = [self accountsFromJsonObject:jsonDictionary withParameters:parameters error:&parseError];
    
    if (parseError)
    {
        [self fillAndLogError:error withError:parseError logLine:@"Failed to parse accounts"];
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
            if (accountError)
            {
                [self fillAndLogError:error withError:accountError logLine:@"Failed to create account"];
                return nil;
            }
            
            return @[];
        }
        
        accounts = @[sharedAccount];
    }
    
    return accounts;
}

#pragma mark - Removal

- (BOOL)removeAccount:(id<MSALAccount>)account
       tenantProfiles:(nullable NSArray<MSALTenantProfile *> *)tenantProfiles
                error:(NSError * _Nullable * _Nullable)error
{
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Removing account %@", MSID_PII_LOG_MASKABLE(account));
    return [self updateAccount:account
                 idTokenClaims:nil
                tenantProfiles:tenantProfiles
                     operation:MSALLegacySharedAccountRemoveOperation
                         error:error];
}

- (nullable NSArray<MSALLegacySharedAccount *> *)removableAccountsFromJsonObject:(NSDictionary *)jsonDictionary
                                                                     msalAccount:(id<MSALAccount>)account
                                                                  tenantProfiles:(NSArray<MSALTenantProfile *> *)tenantProfiles
                                                                           error:(NSError **)error
{
    if (![tenantProfiles count])
    {
        MSALAccountEnumerationParameters *parameters = [MSALLegacySharedAccountFactory parametersForAccount:account
                                                                                    tenantProfileIdentifier:account.accountClaims[@"oid"]];
        
        if (!parameters)
        {
            NSError *parameterError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unable to create parameters for the account", nil, nil, nil, nil, nil);
            [self fillAndLogError:error withError:parameterError logLine:@"Failed to create parameters for the account"];
            return nil;
        }
        
        return [self accountsFromJsonObject:jsonDictionary withParameters:parameters error:error];
    }
    
    NSMutableArray *allAccounts = [NSMutableArray new];
    
    for (MSALTenantProfile *tenantProfile in tenantProfiles)
    {
        MSALAccountEnumerationParameters *parameters = [MSALLegacySharedAccountFactory parametersForAccount:account
                                                                                    tenantProfileIdentifier:tenantProfile.identifier];
        
        if (!parameters)
        {
            NSError *parameterError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unable to create parameters for the account", nil, nil, nil, nil, nil);
            [self fillAndLogError:error withError:parameterError logLine:@"Failed to create parameters for the account"];
            return nil;
        }
        
        NSArray<MSALLegacySharedAccount *> *accounts = [self accountsFromJsonObject:jsonDictionary withParameters:parameters error:error];
        
        if (!accounts)
        {
            return nil;
        }
        
        [allAccounts addObjectsFromArray:accounts];
    }
    
    return allAccounts;
}

#pragma mark - Write

- (BOOL)updateAccount:(id<MSALAccount>)account
        idTokenClaims:(NSDictionary *)idTokenClaims
       tenantProfiles:(NSArray<MSALTenantProfile *> *)tenantProfiles
            operation:(MSALLegacySharedAccountWriteOperation)operation
                error:(NSError **)error
{
    __block BOOL result = YES;
    __block NSError *updateError = nil;
    
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        result = [self updateAccountImpl:account
                           idTokenClaims:idTokenClaims
                          tenantProfiles:tenantProfiles
                               operation:operation
                                   error:&updateError];
    });
    
    if (error && updateError)
    {
        *error = updateError;
    }
    
    return result;
}

- (BOOL)updateAccountImpl:(id<MSALAccount>)account
            idTokenClaims:(NSDictionary *)idTokenClaims
           tenantProfiles:(NSArray<MSALTenantProfile *> *)tenantProfiles
                operation:(MSALLegacySharedAccountWriteOperation)operation
                    error:(NSError **)error
{
    if (self.sharedAccountMode != MSALLegacySharedAccountModeReadWrite)
    {
        return YES;
    }
    
    NSTimeInterval writeTimeStamp = [[NSDate date] timeIntervalSince1970];
    
    for (int version = MSALLegacySharedAccountVersionV1; version <= MSALLegacySharedAccountVersionV3; version++)
    {
        NSString *versionIdentifier = [self accountVersionIdentifier:version];
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Updating accounts with version %@", versionIdentifier);
        
        NSError *updateError = nil;
        MSIDJsonObject *jsonObject = [self jsonObjectWithVersion:version error:&updateError];
        
        if (updateError)
        {
            NSString *logLine = [NSString stringWithFormat:@"Failed to retrieve accounts with version %@", versionIdentifier];
            [self fillAndLogError:error withError:updateError logLine:logLine];
            return NO;
        }
        
        NSArray<MSALLegacySharedAccount *> *accounts = nil;
        
        if (operation == MSALLegacySharedAccountRemoveOperation)
        {
            accounts = [self removableAccountsFromJsonObject:[jsonObject jsonDictionary]
                                                 msalAccount:account
                                              tenantProfiles:tenantProfiles
                                                       error:&updateError];
        }
        else
        {
            accounts = [self updatableAccountsFromJsonObject:[jsonObject jsonDictionary]
                                                 msalAccount:account
                                               idTokenClaims:idTokenClaims
                                                     version:version
                                                       error:&updateError];
        }
        
        if (!accounts)
        {
            NSString *logLine = [NSString stringWithFormat:@"Failed to parse accounts with version %@", versionIdentifier];
            [self fillAndLogError:error withError:updateError logLine:logLine];
            return NO;
        }
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Updating accounts %@", MSID_PII_LOG_MASKABLE(accounts));
        
        NSError *saveError = nil;
        BOOL saveResult = [self saveUpdatedAccount:account
                                        jsonObject:jsonObject
                                          accounts:accounts
                                         operation:operation
                                           version:version
                                         writeTime:writeTimeStamp
                                             error:&saveError];
        
        if (!saveResult)
        {
            [self fillAndLogError:error withError:saveError logLine:@"Failed to save accounts"];
            return NO;
        }
        
        writeTimeStamp += 1.0;
    }
    
    return YES;
}

- (BOOL)saveUpdatedAccount:(id<MSALAccount>)account
                jsonObject:(MSIDJsonObject *)jsonObject
                  accounts:(NSArray *)accounts
                 operation:(MSALLegacySharedAccountWriteOperation)operation
                   version:(MSALLegacySharedAccountVersion)version
                 writeTime:(NSTimeInterval)writeTimeStamp
                     error:(NSError **)error
{
    NSString *versionIdentifier = [self accountVersionIdentifier:version];
    NSMutableDictionary *resultDictionary = jsonObject ? [[jsonObject jsonDictionary] mutableCopy] : [NSMutableDictionary new];
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Updating accounts %@", MSID_PII_LOG_MASKABLE(accounts));
    
    for (MSALLegacySharedAccount *sharedAccount in accounts)
    {
        NSError *updateError = nil;
        BOOL updateResult = [sharedAccount updateAccountWithMSALAccount:account
                                                        applicationName:self.applicationIdentifier
                                                              operation:operation
                                                         accountVersion:version
                                                                  error:&updateError];
        
        if (!updateResult)
        {
            NSString *logLine = [NSString stringWithFormat:@"Failed to update accounts with version %@", versionIdentifier];
            [self fillAndLogError:error withError:updateError logLine:logLine];
            return NO;
        }
        
        resultDictionary[sharedAccount.accountIdentifier] = [sharedAccount jsonDictionary];
    }
    
    resultDictionary[@"lastWriteTimestamp"] = @((long)writeTimeStamp);
    
    NSError *saveError = nil;
    BOOL saveResult = [self saveJSONDictionary:resultDictionary
                                       version:version
                                         error:&saveError];
    
    if (!saveResult)
    {
        [self fillAndLogError:error withError:saveError logLine:@"Failed to save accounts"];
        return NO;
    }
    
    return YES;
}

#pragma mark - Keychain operations

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
    
    if (![jsonAccounts count])
    {
        if (readError)
        {
            NSString *logLine = [NSString stringWithFormat:@"Failed to read external accounts with version %@", versionIdentifier];
            [self fillAndLogError:error withError:readError logLine:logLine];
        }
        
        return nil;
    }
    
    if ([jsonAccounts count] > 1)
    {
        NSError *readError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Ambigious query for external accounts, found multiple accounts.", nil, nil, nil, nil, nil);
        [self fillAndLogError:error withError:readError logLine:@"Ambigious query for external accounts, found multiple accounts."];
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
    
    if (error && resultError)
    {
        *error = [MSALErrorConverter msalErrorFromMsidError:resultError];
    }
}

- (NSString *)accountVersionIdentifier:(MSALLegacySharedAccountVersion)version
{
    return [NSString stringWithFormat:@"AccountsV%d", (int)version];
}

@end
