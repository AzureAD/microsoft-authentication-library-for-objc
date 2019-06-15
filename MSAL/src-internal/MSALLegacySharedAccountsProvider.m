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

@interface MSALLegacySharedAccountsProvider()

@property (nonatomic) MSIDKeychainTokenCache *keychainTokenCache;
@property (nonatomic) NSString *serviceIdentifier;
@property (nonatomic) NSArray *supportedVersions;

@end

@implementation MSALLegacySharedAccountsProvider

#pragma mark - Init

- (instancetype)initWithSharedKeychainAccessGroup:(NSString *)sharedGroup
                                serviceIdentifier:(NSString *)serviceIdentifier
                                supportedVersions:(NSArray *)supportedVersions
                                            error:(NSError **)error
{
    self = [super init];
    
    if (self)
    {
        self.keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:sharedGroup];
        self.serviceIdentifier = serviceIdentifier;
        self.supportedVersions = supportedVersions;
    }
    
    return self;
}

#pragma mark - MSALExternalAccountProviding

- (BOOL)updateAccount:(id<MSALAccount>)account error:(NSError * _Nullable * _Nullable)error
{
    return YES;
}

- (BOOL)removeAccount:(id<MSALAccount>)account error:(NSError * _Nullable * _Nullable)error
{
    return YES;
}

#pragma mark - Read

- (nullable NSArray<id<MSALAccount>> *)accountsWithParameters:(MSALAccountEnumerationParameters *)parameters
                                                        error:(NSError * _Nullable * _Nullable)error
{
    NSMutableSet *allAccounts = [NSMutableSet new];
    NSTimeInterval lastWrite = [[NSDate distantPast] timeIntervalSince1970];
    
    for (NSString *supportedVersion in self.supportedVersions)
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

@end
