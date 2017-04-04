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

#import "MSALKeychainTokenCache.h"
#import "MSALKeychainTokenCache+Internal.h"
#import "MSALTokenResponse.h"
#import "MSALAccessTokenCacheItem.h"
#import "MSALRefreshTokenCacheItem.h"
#import "MSALTokenCacheKey.h"

static NSString* s_defaultKeychainGroup = @"com.microsoft.msalcache";
static NSString* s_accessTokenFlag = @"MSOpenTech.MSAL.AccessToken";
static NSString* s_refreshTokenFlag = @"MSOpenTech.MSAL.RefreshToken";
static MSALKeychainTokenCache* s_defaultCache = nil;

@implementation MSALKeychainTokenCache
{
    NSString* _sharedGroup;
    NSDictionary* _default;
}

+ (MSALKeychainTokenCache *)defaultKeychainCache
{
    static dispatch_once_t s_once;
    
    dispatch_once(&s_once, ^{
        s_defaultCache = [[MSALKeychainTokenCache alloc] initWithGroup:s_defaultKeychainGroup];
    });
    
    return s_defaultCache;
}

// Shouldn't be called.
- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithGroup:(NSString *)sharedGroup
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    if (!sharedGroup)
    {
        sharedGroup = [[NSBundle mainBundle] bundleIdentifier];
    }
    
    NSString* teamId = [MSALKeychainTokenCache keychainTeamId:nil];
#if !TARGET_OS_SIMULATOR
    // If we didn't find a team ID and we're on device then the rest of ADAL not only will not work
    // particularly well, we'll probably induce other issues by continuing.
    if (!teamId)
    {
        return nil;
    }
#endif
    if (teamId)
    {
        _sharedGroup = [[NSString alloc] initWithFormat:@"%@.%@", teamId, sharedGroup];
    }
    
    NSMutableDictionary* defaultQuery =
    [@{
       (id)kSecClass : (id)kSecClassGenericPassword,
       } mutableCopy];
    
    if (_sharedGroup)
    {
        [defaultQuery setObject:_sharedGroup forKey:(id)kSecAttrAccessGroup];
    }
    
    _default = defaultQuery;
    
    return self;
}

+ (NSString*)keychainTeamId:(NSError * __autoreleasing *)error
{
    static dispatch_once_t s_once;
    static NSString* s_keychainTeamId = nil;
    
    dispatch_once(&s_once, ^{
        s_keychainTeamId = [self retrieveTeamIDFromKeychain:error];
        LOG_INFO(nil, @"Using \"%@\" Team ID for Keychain.", s_keychainTeamId);
        LOG_INFO_PII(nil, @"Using \"%@\" Team ID for Keychain.", s_keychainTeamId);
    });
    
    return s_keychainTeamId;
}

+ (NSString*)retrieveTeamIDFromKeychain:(NSError * __autoreleasing *)error
{
    NSDictionary *query = @{ (id)kSecClass : (id)kSecClassGenericPassword,
                             (id)kSecAttrAccount : @"teamIDHint",
                             (id)kSecAttrService : @"teamIDHint",
                             (id)kSecReturnAttributes : @YES };
    CFDictionaryRef result = nil;
    
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    
    if (status == errSecItemNotFound)
    {
        NSMutableDictionary* addQuery = [query mutableCopy];
        [addQuery setObject:(id)kSecAttrAccessibleAlways forKey:(id)kSecAttrAccessible];
        status = SecItemAdd((__bridge CFDictionaryRef)addQuery, (CFTypeRef *)&result);
    }
    
    if (status != errSecSuccess)
    {
        MSAL_KEYCHAIN_ERROR_PARAM(nil, status, @"Keychain failed when fetching team ID.");
        return nil;
    }
    
    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge id)(kSecAttrAccessGroup)];
    NSArray *components = [accessGroup componentsSeparatedByString:@"."];
    NSString *bundleSeedID = [components firstObject];
    
    CFRelease(result);
    
    return [bundleSeedID length] ? bundleSeedID : nil;
}

@end

@implementation MSALKeychainTokenCache (Internal)

- (nullable NSArray <MSALAccessTokenCacheItem *> *)getAccessTokenItemsWithKey:(nullable MSALTokenCacheKey *)key
                                                                correlationId:(nullable NSUUID * )correlationId
                                                                        error:(NSError * __autoreleasing *)error
{
    (void)correlationId;
    NSMutableDictionary* query = [self queryDictionaryForKey:key
                                                  additional:@{
                                                               (id)kSecAttrGeneric : [s_accessTokenFlag dataUsingEncoding:NSUTF8StringEncoding],
                                                               (id)kSecMatchLimit : (id)kSecMatchLimitAll,
                                                               (id)kSecReturnData : @YES,
                                                               (id)kSecReturnAttributes : @YES
                                                               }];
    CFTypeRef items = nil;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &items);
    if (status != errSecSuccess && status != errSecItemNotFound)
    {
        MSAL_KEYCHAIN_ERROR_PARAM(nil, status, @"Keychain failed when retrieving access tokens.");
        return nil;
    }
    NSArray *accessTokenitems = CFBridgingRelease(items);
    NSMutableArray<MSALAccessTokenCacheItem *> *accessTokens = [NSMutableArray<MSALAccessTokenCacheItem *> new];
    
    for (NSDictionary *attrs in accessTokenitems)
    {
        MSALAccessTokenCacheItem *item = [self accessTokenItemFromKeychainAttributes:attrs error:nil];
        if (!item)
        {
            continue;
        }
        [accessTokens addObject:item];
    }
    
    return accessTokens;
}

- (nullable NSArray <MSALRefreshTokenCacheItem *> *)getRefreshTokenItemsWithKey:(nullable MSALTokenCacheKey *)key
                                                                  correlationId:(nullable NSUUID * )correlationId
                                                                          error:(NSError * __autoreleasing *)error
{
    (void)correlationId;
    
    NSMutableDictionary* query = [self queryDictionaryForKey:key
                                                  additional:@{
                                                               (id)kSecAttrGeneric : [s_refreshTokenFlag dataUsingEncoding:NSUTF8StringEncoding],
                                                               (id)kSecMatchLimit : (id)kSecMatchLimitAll,
                                                               (id)kSecReturnData : @YES,
                                                               (id)kSecReturnAttributes : @YES
                                                               }];
    CFTypeRef items = nil;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &items);
    if (status != errSecSuccess && status != errSecItemNotFound)
    {
        MSAL_KEYCHAIN_ERROR_PARAM(nil, status, @"Keychain failed when retrieving refresh tokens.");
        return nil;
    }
    NSArray *refreshTokenitems = CFBridgingRelease(items);
    NSMutableArray<MSALRefreshTokenCacheItem *> *refreshTokens = [NSMutableArray<MSALRefreshTokenCacheItem *> new];
    
    for (NSDictionary *attrs in refreshTokenitems)
    {
        MSALRefreshTokenCacheItem *item = [self refreshTokenItemFromKeychainAttributes:attrs error:nil];
        if (!item)
        {
            continue;
        }
        [refreshTokens addObject:item];
    }
    
    return refreshTokens;
    
}

- (BOOL)addOrUpdateAccessTokenItem:(nonnull MSALAccessTokenCacheItem *)atItem
                     correlationId:(nullable NSUUID *)correlationId
                             error:(NSError * __autoreleasing *)error
{
    (void)correlationId;
    @synchronized(self)
    {
        MSALTokenCacheKey *key = [atItem tokenCacheKey:error];
        if (!key)
        {
            return NO;
        }
        
        NSMutableDictionary* query = [self queryDictionaryForKey:key
                                                      additional:@{
                                                                   (id)kSecAttrGeneric : [s_accessTokenFlag dataUsingEncoding:NSUTF8StringEncoding]
                                                                   }];
        
        NSData* itemData = [atItem serialize:error];
        if (!itemData)
        {
            LOG_ERROR(nil, @"Failed to archive keychain item.");
            LOG_ERROR_PII(nil, @"Failed to archive keychain item.");
            return NO;
        }
        
        NSDictionary* attrToUpdate = @{ (id)kSecValueData : itemData };
        OSStatus status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)attrToUpdate);
        if (status == errSecSuccess)
        {
            return YES;
        }
        else if (status != errSecItemNotFound)
        {
            MSAL_KEYCHAIN_ERROR_PARAM(nil, status, @"Keychain failed when saving access token item during update operation.");
            return NO;
        }
        
        // If the item wasn't found that means we need to add it instead.
        [query addEntriesFromDictionary:@{ (id)kSecValueData : itemData,
                                           (id)kSecAttrAccessible : (id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly}];
        status = SecItemAdd((CFDictionaryRef)query, NULL);
        if (status != errSecSuccess)
        {
            MSAL_KEYCHAIN_ERROR_PARAM(nil, status, @"Keychain failed when saving access token item during add operation.");
            return NO;
        }
        return YES;
    }
}

- (BOOL)addOrUpdateRefreshTokenItem:(nonnull MSALRefreshTokenCacheItem *)rtItem
                      correlationId:(nullable NSUUID *)correlationId
                              error:(NSError * __autoreleasing *)error
{
    (void)correlationId;
    @synchronized(self)
    {
        MSALTokenCacheKey *key = [rtItem tokenCacheKey:error];
        if (!key)
        {
            return NO;
        }
        
        NSMutableDictionary* query = [self queryDictionaryForKey:key
                                                      additional:@{
                                                                   (id)kSecAttrGeneric : [s_refreshTokenFlag dataUsingEncoding:NSUTF8StringEncoding]
                                                                   }];
        
        NSData* itemData = [rtItem serialize:error];
        if (!itemData)
        {
            LOG_ERROR(nil, @"Failed to archive keychain item.");
            LOG_ERROR_PII(nil, @"Failed to archive keychain item.");
            return NO;
        }
        
        NSDictionary* attrToUpdate = @{ (id)kSecValueData : itemData };
        OSStatus status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)attrToUpdate);
        if (status == errSecSuccess)
        {
            return YES;
        }
        else if (status != errSecItemNotFound)
        {
            MSAL_KEYCHAIN_ERROR_PARAM(nil,status, @"Keychain failed when saving refresh token item during update operation.");
            return NO;
        }
        
        // If the item wasn't found that means we need to add it instead.
        [query addEntriesFromDictionary:@{ (id)kSecValueData : itemData,
                                           (id)kSecAttrAccessible : (id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly}];
        status = SecItemAdd((CFDictionaryRef)query, NULL);
        if (status != errSecSuccess)
        {
            MSAL_KEYCHAIN_ERROR_PARAM(nil, status, @"Keychain failed when saving refresh token item during add operation.");
            return NO;
        }
        return YES;
    }
}

- (BOOL)removeAccessTokenItem:(nonnull MSALAccessTokenCacheItem *)atItem
                        error:(NSError * __autoreleasing *)error
{
    MSALTokenCacheKey *key = [atItem tokenCacheKey:error];
    if (!key)
    {
        return NO;
    }
    NSMutableDictionary* query = [self queryDictionaryForKey:key
                                                  additional:@{
                                                               (id)kSecAttrGeneric : [s_accessTokenFlag dataUsingEncoding:NSUTF8StringEncoding]
                                                               }];
    OSStatus deleteStatus =  SecItemDelete((CFDictionaryRef)query);
    
    if (deleteStatus != errSecSuccess)
    {
        MSAL_KEYCHAIN_ERROR_PARAM(nil, deleteStatus, @"Keychain failed when deleting access token.");
        return NO;
    }
    return YES;
}

- (BOOL)removeRefreshTokenItem:(nonnull MSALRefreshTokenCacheItem *)rtItem
                         error:(NSError * __autoreleasing *)error
{
    MSALTokenCacheKey *key = [rtItem tokenCacheKey:error];
    if (!key)
    {
        return NO;
    }
    NSMutableDictionary* query = [self queryDictionaryForKey:key
                                                  additional:@{
                                                               (id)kSecAttrGeneric : [s_refreshTokenFlag dataUsingEncoding:NSUTF8StringEncoding]
                                                               }];
    OSStatus deleteStatus =  SecItemDelete((CFDictionaryRef)query);
    
    if (deleteStatus != errSecSuccess)
    {
        MSAL_KEYCHAIN_ERROR_PARAM(nil, deleteStatus, @"Keychain failed when deleting refresh token.");
        return NO;
    }
    return YES;
}

- (NSMutableDictionary*)queryDictionaryForKey:(MSALTokenCacheKey *)key
                                   additional:(NSDictionary *)additional
{
    NSMutableDictionary* query = [_default mutableCopy];
    if (key.service)
    {
        [query setObject:key.service forKey:(NSString*)kSecAttrService];
    }
    if (key.account)
    {
        [query setObject:key.account forKey:(NSString*)kSecAttrAccount];
    }
    
    if (additional)
    {
        [query addEntriesFromDictionary:additional];
    }
    
    return query;
}

- (MSALAccessTokenCacheItem *)accessTokenItemFromKeychainAttributes:(NSDictionary*)attrs
                                                              error:(NSError * __autoreleasing *)error
{
    NSData* data = [attrs objectForKey:(id)kSecValueData];
    if (!data)
    {
        LOG_WARN(nil, @"Retrieved item with key that did not have generic item data!");
        LOG_WARN_PII(nil, @"Retrieved item with key that did not have generic item data!");
        return nil;
    }
    @try
    {
        MSALAccessTokenCacheItem *item = [[MSALAccessTokenCacheItem alloc] initWithData:data error:error];
        if (!item)
        {
            LOG_ERROR(nil, @"Unable to decode item from data stored in keychain.");
            LOG_ERROR_PII(nil, @"Unable to decode item from data stored in keychain.");
            return nil;
        }
        
        return item;
    }
    @catch (NSException *exception)
    {
        LOG_WARN(nil, @"Failed to deserialize data from keychain");
        LOG_WARN_PII(nil, @"Failed to deserialize data from keychain");
        return nil;
    }
}

- (MSALRefreshTokenCacheItem *)refreshTokenItemFromKeychainAttributes:(NSDictionary*)attrs
                                                                error:(NSError * __autoreleasing *)error
{
    NSData* data = [attrs objectForKey:(id)kSecValueData];
    if (!data)
    {
        LOG_WARN(nil, @"Retrieved item with key that did not have generic item data!");
        LOG_WARN_PII(nil, @"Retrieved item with key that did not have generic item data!");
        return nil;
    }
    @try
    {
        MSALRefreshTokenCacheItem *item = [[MSALRefreshTokenCacheItem alloc] initWithData:data error:error];
        if (!item)
        {
            LOG_ERROR(nil, @"Unable to decode item from data stored in keychain.");
            LOG_ERROR_PII(nil, @"Unable to decode item from data stored in keychain.");
            return nil;
        }
        
        return item;
    }
    @catch (NSException *exception)
    {
        LOG_WARN(nil, @"Failed to deserialize data from keychain");
        LOG_WARN_PII(nil, @"Failed to deserialize data from keychain");
        return nil;
    }
}

- (void)testRemoveAll
{
    LOG_ERROR(nil, @"******** -testRemoveAll: being called in ADKeychainTokenCache. This method should NEVER be called in production code. ********");
    @synchronized(self)
    {
        NSMutableDictionary* query = [self queryDictionaryForKey:nil additional:nil];
        OSStatus status = SecItemDelete((CFDictionaryRef)query);
        (void)status;
    }
}

@end
