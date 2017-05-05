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
#import "MSALTokenResponse.h"
#import "MSALAccessTokenCacheItem.h"
#import "MSALRefreshTokenCacheItem.h"
#import "MSALAccessTokenCacheKey.h"
#import "MSALRefreshTokenCacheKey.h"
#import "MSALTokenCacheKeyBase.h"

static MSALKeychainTokenCache* s_defaultCache = nil;

typedef NS_ENUM(uint32_t, MSALTokenType)
{
    ACCESS_TOKEN    = 'acTk',
    REFRESH_TOKEN   = 'rfTk'
};

@implementation MSALKeychainTokenCache
{
    NSString* _sharedGroup;
    NSDictionary* _default;
}

+ (MSALKeychainTokenCache *)defaultKeychainCache
{
    static dispatch_once_t s_once;
    
    dispatch_once(&s_once, ^{
        s_defaultCache = [[MSALKeychainTokenCache alloc] initWithGroup:nil];
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
        MSAL_KEYCHAIN_ERROR(nil, status, @"fetching team ID");
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

- (NSDictionary *)defaultKeychainQuery
{
    return _default;
}

- (nullable NSArray <MSALAccessTokenCacheItem *> *)getAccessTokenItemsWithKey:(nullable MSALAccessTokenCacheKey *)key
                                                                      context:(nullable id<MSALRequestContext>)ctx
                                                                        error:(NSError * __autoreleasing *)error
{
    NSMutableDictionary* query = [self queryDictionaryForKey:key
                                                  additional:@{
                                                               (id)kSecAttrType : [NSNumber numberWithUnsignedInt:ACCESS_TOKEN],
                                                               (id)kSecMatchLimit : (id)kSecMatchLimitAll,
                                                               (id)kSecReturnData : @YES,
                                                               (id)kSecReturnAttributes : @YES
                                                               }];
    CFTypeRef items = nil;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &items);
    if (status != errSecSuccess && status != errSecItemNotFound)
    {
        MSAL_KEYCHAIN_ERROR(ctx, status, @"retreieve access tokens");
        return nil;
    }
    NSArray *accessTokenitems = CFBridgingRelease(items);
    NSMutableArray<MSALAccessTokenCacheItem *> *accessTokens = [NSMutableArray<MSALAccessTokenCacheItem *> new];
    
    for (NSDictionary *attrs in accessTokenitems)
    {
        // TODO: Do we want to silently ignore ATs we can't parse? If so should we apply this logic everywhere?
        MSALAccessTokenCacheItem *item = [self accessTokenItemFromKeychainAttributes:attrs context:ctx error:nil];
        if (!item)
        {
            continue;
        }
        [accessTokens addObject:item];
    }
    
    return accessTokens;
}

- (nullable MSALRefreshTokenCacheItem *)getRefreshTokenItemForKey:(nonnull MSALRefreshTokenCacheKey *)key
                                                          context:(nullable id<MSALRequestContext>)ctx
                                                            error:(NSError * __nullable __autoreleasing * __nullable)error
{
    NSMutableDictionary *query =
    [self queryDictionaryForKey:key
                     additional:@{
                                  (id)kSecAttrType : [NSNumber numberWithUnsignedInt:REFRESH_TOKEN],
                                  (id)kSecMatchLimit : (id)kSecMatchLimitOne,
                                  (id)kSecReturnData : @YES,
                                  (id)kSecReturnAttributes : @YES
                                  }];
    CFTypeRef item = nil;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &item);
    if (status == errSecItemNotFound)
    {
        // We don't print out or return errors if we don't find anything, just return nil.
        return nil;
    }
    
    if (status != errSecSuccess)
    {
        MSAL_KEYCHAIN_ERROR(ctx, status, @"retreieve refresh token");
        return nil;
    }
    
    return [MSALKeychainTokenCache refreshTokenItemFromKeychainAttributes:CFBridgingRelease(item) context:ctx error:error];;
}

- (nullable NSArray<MSALRefreshTokenCacheItem *> *)allRefreshTokens:(nullable NSString *)clientId
                                                            context:(id<MSALRequestContext>)ctx
                                                              error:(NSError * __nullable __autoreleasing * __nullable)error
{
    NSMutableDictionary *query = [_default mutableCopy];
    query[(id)kSecAttrType] = [NSNumber numberWithUnsignedInt:REFRESH_TOKEN];
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;
    query[(id)kSecReturnData] = @YES;
    query[(id)kSecReturnAttributes] = @YES;
    if (clientId)
    {
        query[(id)kSecAttrService] = [MSALRefreshTokenCacheKey keyForClientId:clientId];
    }
    
    CFTypeRef items = nil;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &items);
    if (status == errSecItemNotFound)
    {
        return @[];
    }
    
    if (status != errSecSuccess)
    {
        MSAL_KEYCHAIN_ERROR(ctx, status, @"retreieve refresh tokens");
        return nil;
    }
    
    NSMutableArray *refreshTokens = [NSMutableArray new];
    
    for (NSDictionary *attrs in (__bridge NSArray *)items)
    {
        MSALRefreshTokenCacheItem *item =
        [MSALKeychainTokenCache refreshTokenItemFromKeychainAttributes:attrs
                                                               context:ctx
                                                                 error:error];
        if (!item)
        {
            return nil;
        }
        [refreshTokens addObject:item];
    }
    
    CFRelease(items);
    
    return refreshTokens;
}


- (BOOL)addOrUpdateAccessTokenItem:(nonnull MSALAccessTokenCacheItem *)atItem
                           context:(nullable id<MSALRequestContext>)ctx
                             error:(NSError * __autoreleasing *)error
{
    @synchronized(self)
    {
        MSALAccessTokenCacheKey *key = [atItem tokenCacheKey:error];
        if (!key)
        {
            return NO;
        }
        
        NSMutableDictionary* query = [self queryDictionaryForKey:key
                                                      additional:@{
                                                                   (id)kSecAttrType : [NSNumber numberWithUnsignedInt:ACCESS_TOKEN],
                                                                   (id)kSecAttrGeneric : key.clientId.msalBase64UrlEncode,
                                                                   (id)kSecAttrCreator : [NSNumber numberWithUnsignedInt:MSAL_V1]
                                                                   }];
        
        NSData* itemData = [atItem serialize:error];
        if (!itemData)
        {
            LOG_ERROR(ctx, @"Failed to archive keychain item.");
            LOG_ERROR_PII(ctx, @"Failed to archive keychain item.");
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
            MSAL_KEYCHAIN_ERROR(ctx, status, @"updating access token");
            return NO;
        }
        
        // If the item wasn't found that means we need to add it instead.
        [query addEntriesFromDictionary:@{ (id)kSecValueData : itemData,
                                           (id)kSecAttrAccessible : (id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly}];
        status = SecItemAdd((CFDictionaryRef)query, NULL);
        if (status != errSecSuccess)
        {
            MSAL_KEYCHAIN_ERROR(ctx, status, @"adding access token");
            return NO;
        }
        return YES;
    }
}

- (BOOL)addOrUpdateRefreshTokenItem:(nonnull MSALRefreshTokenCacheItem *)rtItem
                            context:(nullable id<MSALRequestContext>)ctx
                              error:(NSError * __autoreleasing *)error
{
    @synchronized(self)
    {
        MSALRefreshTokenCacheKey *key = [rtItem tokenCacheKey:error];
        if (!key)
        {
            return NO;
        }
        
        NSMutableDictionary* query = [self queryDictionaryForKey:key
                                                      additional:@{
                                                                   (id)kSecAttrType : [NSNumber numberWithUnsignedInt:REFRESH_TOKEN],
                                                                   (id)kSecAttrGeneric : key.clientId.msalBase64UrlEncode,
                                                                   (id)kSecAttrCreator : [NSNumber numberWithUnsignedInt:MSAL_V1]
                                                                   }];
        
        NSData* itemData = [rtItem serialize:error];
        if (!itemData)
        {
            LOG_ERROR(ctx, @"Failed to archive keychain item.");
            LOG_ERROR_PII(ctx, @"Failed to archive keychain item.");
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
            MSAL_KEYCHAIN_ERROR(ctx,status, @"updating refresh token");
            return NO;
        }
        
        // If the item wasn't found that means we need to add it instead.
        [query addEntriesFromDictionary:@{ (id)kSecValueData : itemData,
                                           (id)kSecAttrAccessible : (id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly}];
        status = SecItemAdd((CFDictionaryRef)query, NULL);
        if (status != errSecSuccess)
        {
            MSAL_KEYCHAIN_ERROR(ctx, status, @"adding refresh token");
            return NO;
        }
        return YES;
    }
}

- (BOOL)removeAccessTokenItem:(nonnull MSALAccessTokenCacheItem *)atItem
                      context:(nullable id<MSALRequestContext>)ctx
                        error:(NSError * __autoreleasing *)error
{
    MSALAccessTokenCacheKey *key = [atItem tokenCacheKey:error];
    if (!key)
    {
        return NO;
    }
    NSMutableDictionary* query = [self queryDictionaryForKey:key
                                                  additional:@{
                                                               (id)kSecAttrType : [NSNumber numberWithUnsignedInt:ACCESS_TOKEN]
                                                               }];
    OSStatus deleteStatus =  SecItemDelete((CFDictionaryRef)query);
    
    if (deleteStatus != errSecSuccess)
    {
        MSAL_KEYCHAIN_ERROR(ctx, deleteStatus, @"deleting access token");
        return NO;
    }
    return YES;
}

- (BOOL)removeRefreshTokenItem:(nonnull MSALRefreshTokenCacheItem *)rtItem
                       context:(id<MSALRequestContext>)ctx
                         error:(NSError * __autoreleasing *)error
{
    MSALRefreshTokenCacheKey *key = [rtItem tokenCacheKey:error];
    if (!key)
    {
        return NO;
    }
    NSMutableDictionary* query = [self queryDictionaryForKey:key
                                                  additional:@{
                                                               (id)kSecAttrType : [NSNumber numberWithUnsignedInt:REFRESH_TOKEN]
                                                               }];
    OSStatus deleteStatus =  SecItemDelete((CFDictionaryRef)query);
    
    if (deleteStatus != errSecSuccess)
    {
        MSAL_KEYCHAIN_ERROR(ctx, deleteStatus, @"deleting refresh token");
        return NO;
    }
    return YES;
}

- (BOOL)removeAllTokensForUserIdentifier:(NSString *)userIdentifier
                             environment:(NSString *)environment
                                clientId:(NSString *)clientId
                                 context:(nullable id<MSALRequestContext>)ctx
                                   error:(NSError * __autoreleasing *)error
{
    NSString *account = [NSString stringWithFormat:@"%u$%@",
                         MSAL_V1,
                         [MSALTokenCacheKeyBase userIdAtEnvironmentBase64:userIdentifier environment:environment]];
                         
    NSMutableDictionary *query = [self queryDictionaryForKey:nil
                                                  additional:@{
                                                               (id)kSecAttrGeneric : clientId.msalBase64UrlEncode,
                                                               (id)kSecAttrAccount : account
                                                               }];

    OSStatus deleteStatus =  SecItemDelete((CFDictionaryRef)query);
    
    if (deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound)
    {
        MSAL_KEYCHAIN_ERROR(ctx, deleteStatus, @"deleting all user tokens");
        return NO;
    }
    return YES;
}


- (NSMutableDictionary*)queryDictionaryForKey:(MSALTokenCacheKeyBase *)key
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
                                                            context:(nullable id<MSALRequestContext>)ctx
                                                              error:(NSError * __autoreleasing *)error
{
    NSData* data = [attrs objectForKey:(id)kSecValueData];
    if (!data)
    {
        LOG_WARN(ctx, @"Retrieved item with key that did not have generic item data!");
        LOG_WARN_PII(ctx, @"Retrieved item with key that did not have generic item data!");
        return nil;
    }
    @try
    {
        MSALAccessTokenCacheItem *item = [[MSALAccessTokenCacheItem alloc] initWithData:data error:error];
        if (!item)
        {
            LOG_ERROR(ctx, @"Unable to decode item from data stored in keychain.");
            LOG_ERROR_PII(ctx, @"Unable to decode item from data stored in keychain.");
            return nil;
        }
        
        return item;
    }
    @catch (NSException *exception)
    {
        LOG_WARN(ctx, @"Failed to deserialize data from keychain");
        LOG_WARN_PII(ctx, @"Failed to deserialize data from keychain");
        return nil;
    }
}

+ (MSALRefreshTokenCacheItem *)refreshTokenItemFromKeychainAttributes:(NSDictionary*)attrs
                                                              context:(nullable id<MSALRequestContext>)ctx
                                                                error:(NSError * __autoreleasing *)error
{
    NSData* data = [attrs objectForKey:(id)kSecValueData];
    if (!data)
    {
        LOG_WARN(ctx, @"Retrieved item with key that did not have generic item data!");
        LOG_WARN_PII(ctx, @"Retrieved item with key that did not have generic item data!");
        return nil;
    }
    @try
    {
        MSALRefreshTokenCacheItem *item = [[MSALRefreshTokenCacheItem alloc] initWithData:data error:error];
        if (!item)
        {
            LOG_ERROR(ctx, @"Unable to decode item from data stored in keychain.");
            LOG_ERROR_PII(ctx, @"Unable to decode item from data stored in keychain.");
            return nil;
        }
        
        return item;
    }
    @catch (NSException *exception)
    {
        LOG_WARN(ctx, @"Failed to deserialize data from keychain");
        LOG_WARN_PII(ctx, @"Failed to deserialize data from keychain");
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
