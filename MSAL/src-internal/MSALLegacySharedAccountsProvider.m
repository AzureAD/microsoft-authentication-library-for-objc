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

@interface MSALLegacySharedAccountsProvider()

@property (nonatomic) MSIDKeychainTokenCache *keychainTokenCache;
@property (nonatomic) NSString *serviceIdentifier;
@property (nonatomic) NSArray *supportedReadVersions;
@property (nonatomic) NSArray *supportedWriteVersions;
@property (nonatomic) NSString *applicationIdentifier;

@end

@implementation MSALLegacySharedAccountsProvider

#pragma mark - Init

// TODO: update this API
- (instancetype)initWithSharedKeychainAccessGroup:(NSString *)sharedGroup
                                serviceIdentifier:(NSString *)serviceIdentifier
                            applicationIdentifier:(NSString *)applicationIdentifier
                                            error:(NSError **)error
{
    self = [super init];
    
    if (self)
    {
        self.keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:sharedGroup];
        self.serviceIdentifier = serviceIdentifier;
        self.supportedReadVersions = @[@"AccountsV3", @"AccountsV2", @"AccountsV1"];
        self.supportedWriteVersions = @[@"AccountsV2", @"AccountsV3"];
        self.applicationIdentifier = applicationIdentifier;
    }
    
    return self;
}

#pragma mark - MSALExternalAccountProviding

- (BOOL)updateAccount:(id<MSALAccount>)account idTokenClaims:(NSDictionary *)idTokenClaims error:(NSError **)error
{
    NSTimeInterval writeTimeStamp = [[NSDate date] timeIntervalSince1970];
    
    for (NSString *supportedVersion in self.supportedWriteVersions)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Updating accounts with version %@", supportedVersion);
        
        NSError *versionError = nil;
        MSIDJsonObject *jsonObject = [self jsonObjectWithIdentifier:supportedVersion error:&versionError];
        
        if (versionError)
        {
            NSString *logLine = [NSString stringWithFormat:@"Failed to retrieve accounts with version %@", supportedVersion];
            [self fillAndLogError:error withError:versionError logLine:logLine];
            continue;
        }
        
        if (!jsonObject)
        {
            jsonObject = [[MSIDJsonObject alloc] initWithJSONDictionary:[NSDictionary new] error:nil];
        }
        
        NSString *oid = idTokenClaims[@"oid"]; // TODO: what about MSA?
        MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithTenantProfileIdentifier:oid];
        NSMutableDictionary *jsonDictionary = [[jsonObject jsonDictionary] mutableCopy];
        NSArray<MSALLegacySharedAccount *> *accounts = [self accountsFromJsonObject:jsonDictionary withParameters:parameters error:&versionError];
        
        if (versionError)
        {
            NSString *logLine = [NSString stringWithFormat:@"Failed to parse accounts with version %@", supportedVersion];
            [self fillAndLogError:error withError:versionError logLine:logLine];
            continue;
        }
        
        if (![accounts count])
        {
            NSError *accountError = nil;
            MSALLegacySharedAccount *sharedAccount = [MSALLegacySharedAccountFactory accountsWithMSALAccount:account
                                                                                                      claims:idTokenClaims
                                                                                             applicationName:self.applicationIdentifier
                                                                                                       error:&accountError];
            if (!sharedAccount)
            {
                NSString *logLine = [NSString stringWithFormat:@"Failed to create account with version %@", supportedVersion];
                [self fillAndLogError:error withError:accountError logLine:logLine];
                continue;
            }
            
            accounts = @[sharedAccount];
        }
        
        for (MSALLegacySharedAccount *sharedAccount in accounts)
        {
            NSError *updateError = nil;
            BOOL updateResult = [sharedAccount updateAccountWithMSALAccount:account applicationName:self.applicationIdentifier error:&updateError];
            
            if (!updateResult)
            {
                NSString *logLine = [NSString stringWithFormat:@"Failed to update accounts with version %@", supportedVersion];
                [self fillAndLogError:error withError:updateError logLine:logLine];
                continue;
            }
            
            jsonDictionary[sharedAccount.accountIdentifier] = [sharedAccount jsonDictionary];
        }
        
        jsonDictionary[@"lastWriteTimestamp"] = @(writeTimeStamp);
        writeTimeStamp += 1.0;
        
        MSIDCacheKey *cacheKey = [[MSIDCacheKey alloc] initWithAccount:supportedVersion
                                                               service:self.serviceIdentifier
                                                               generic:nil
                                                                  type:nil];
        
        NSError *saveError = nil;
        BOOL saveResult = [self.keychainTokenCache saveJsonObject:jsonObject
                                                       serializer:[MSIDCacheItemJsonSerializer new]
                                                              key:cacheKey
                                                          context:nil
                                                            error:&saveError];
        
        if (!saveResult)
        {
            NSString *logLine = [NSString stringWithFormat:@"Failed to save accounts with version %@", supportedVersion];
            [self fillAndLogError:error withError:saveError logLine:logLine];
            continue;
        }
    }
    
    // TODO: what about v1?
    
    // Read JSON object
    // Find the one with same oid
    // Update fields if necessary (only update the ones we understand + signin state)
    // Should we go through all supported versions here?
    // Don't touch MSA!????
    return YES;
}

// Pass tenant profiles here?
- (BOOL)removeAccount:(MSALAccount *)account error:(NSError * _Nullable * _Nullable)error
{
    // Read JSON object
    // Find the one with same oid
    // Update fields if necessary (only update the signin state)
    return YES;
}

#pragma mark - Read

- (nullable NSArray<id<MSALAccount>> *)accountsWithParameters:(MSALAccountEnumerationParameters *)parameters
                                                        error:(NSError * _Nullable * _Nullable)error
{
    NSMutableSet *allAccounts = [NSMutableSet new];
    NSTimeInterval lastWrite = [[NSDate distantPast] timeIntervalSince1970];
    
    for (NSString *supportedVersion in self.supportedReadVersions)
    {
        NSError *versionError = nil;
        MSIDJsonObject *jsonObject = [self jsonObjectWithIdentifier:supportedVersion error:&versionError];
        
        if (!jsonObject)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to retrieve accounts with version %@, error %@", supportedVersion, MSID_PII_LOG_MASKABLE(versionError));
            
            if (error && versionError)
            {
                *error = versionError;
            }
        }
        else
        {
            NSDictionary *jsonDictionary = [jsonObject jsonDictionary];
            NSNumber *lastWriteForVersion = [jsonDictionary msidObjectForKey:@"lastWriteTimestamp" ofClass:[NSNumber class]];
            
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Reading accounts with version %@, last write time stamp %@", supportedVersion, lastWriteForVersion);
            
            if ([lastWriteForVersion floatValue] > lastWrite)
            {
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Accounts with version %@ are latest", supportedVersion);
                
                NSArray *accounts = [self accountsFromJsonObject:jsonDictionary withParameters:parameters error:&versionError];
                
                if (!accounts)
                {
                    MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Failed to deserialize accounts with version %@, error %@", supportedVersion, MSID_PII_LOG_MASKABLE(versionError));
                    continue;
                }
                
                lastWrite = [lastWriteForVersion floatValue];
                [allAccounts addObjectsFromArray:accounts];
            }
            else
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Older accounts dictionary found with version %@, skipping...", supportedVersion);
            }
        }
    }
    
    NSArray *results = [allAccounts allObjects];
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, nil, @"Finished reading external accounts with results %@", MSID_PII_LOG_MASKABLE(results));
    
    return results;
}

- (nullable NSArray<id<MSALAccount>> *)accountsFromJsonObject:(NSDictionary *)jsonDictionary
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

#pragma mark - Keychain read

- (nullable MSIDJsonObject *)jsonObjectWithIdentifier:(NSString *)accountsVersionIdentifier
                                                error:(NSError **)error
{
    MSIDCacheKey *cacheKey = [[MSIDCacheKey alloc] initWithAccount:accountsVersionIdentifier
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
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Failed to read external accounts with error %@", MSID_PII_LOG_MASKABLE(readError));
        
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

#pragma mark - Helpers

- (void)fillAndLogError:(NSError **)error withError:(NSError *)resultError logLine:(NSString *)logLine
{
    MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@, error %@", logLine, MSID_PII_LOG_MASKABLE(resultError));
    
    if (error)
    {
        *error = resultError;
    }
}

@end
