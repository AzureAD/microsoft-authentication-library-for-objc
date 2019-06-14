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

- (nullable NSArray<id<MSALAccount>> *)accountsWithParameters:(MSALAccountEnumerationParameters *)parameters
                                                        error:(NSError * _Nullable * _Nullable)error
{
    NSMutableSet *allAccounts = [NSMutableSet new];
    
    for (NSString *supportedVersion in self.supportedVersions)
    {
        NSError *versionError = nil;
        NSArray *versionAccounts = [self accountsWithVersion:supportedVersion parameters:parameters error:&versionError];
        
        if (!versionAccounts)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to retrieve accounts with version %@", supportedVersion);
            
            if (error)
            {
                *error = versionError;
            }
        }
        else
        {
            [allAccounts addObjectsFromArray:versionAccounts];
        }
    }
    
    return [allAccounts allObjects];
}

- (nullable NSArray<id<MSALAccount>> *)accountsWithVersion:(NSString *)accountsVersion
                                                parameters:(MSALAccountEnumerationParameters *)parameters
                                                     error:(NSError **)error
{
    MSIDCacheKey *cacheKey = [[MSIDCacheKey alloc] initWithAccount:accountsVersion service:self.serviceIdentifier generic:nil type:nil];
    NSError *readError = nil;
    NSArray<MSIDJsonObject *> *jsonAccounts = [self.keychainTokenCache jsonObjectsWithKey:cacheKey
                                                                               serializer:[MSIDCacheItemJsonSerializer new]
                                                                                  context:nil
                                                                                    error:&readError];
    
    if (readError)
    {
        if (error)
        {
            *error = readError;
        }
        
        return nil;
    }
    
    if ([jsonAccounts count] != 1)
    {
        return nil;
    }
    
    NSDictionary *jsonDictionary = [jsonAccounts[0] jsonDictionary];
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
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to create account with error %@", singleAccountError);
        }
        else if ([account matchesParameters:parameters])
        {
            [resultAccounts addObject:account];
        }
    }
    
    return resultAccounts;
}

@end
