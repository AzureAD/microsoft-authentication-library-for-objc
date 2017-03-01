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

static NSString* const s_nilKey = @"CC3513A0-0E69-4B4D-97FC-DFB6C91EE132";//A special attribute to write, instead of nil/empty one.
static NSString* const s_delimiter = @"|";
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
    
    NSString* teamId = [MSALKeychainTokenCache keychainTeamId];
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
       //(id)kSecAttrGeneric : [s_libraryString dataUsingEncoding:NSUTF8StringEncoding]
       } mutableCopy];
    
    if (_sharedGroup)
    {
        [defaultQuery setObject:_sharedGroup forKey:(id)kSecAttrAccessGroup];
    }
    
    _default = defaultQuery;
    
    return self;
}

+ (NSString*)keychainTeamId
{
    static dispatch_once_t s_once;
    static NSString* s_keychainTeamId = nil;
    
    dispatch_once(&s_once, ^{
        s_keychainTeamId = [self retrieveTeamIDFromKeychain];
        LOG_INFO(nil, @"Using \"%@\" Team ID for Keychain.", s_keychainTeamId);
    });
    
    return s_keychainTeamId;
}

+ (NSString*)retrieveTeamIDFromKeychain
{
    NSDictionary *query = @{ (id)kSecClass : (id)kSecClassGenericPassword,
                             (id)kSecAttrAccount : @"teamIDHint",
                             (id)kSecAttrService : @"",
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

- (MSALAccessTokenCacheItem *)saveAccessAndRefreshToken:(NSString *)authority
                                               clientId:(NSString *)clientId
                                               response:(MSALTokenResponse *)response
{
    MSALAccessTokenCacheItem *accessToken = [[MSALAccessTokenCacheItem alloc] initWithAuthority:authority
                                                                                       clientId:clientId
                                                                                       response:response];
    [self saveAccessToken:accessToken];
    
    if (response.refreshToken)
    {
        MSALRefreshTokenCacheItem *refreshToken = [[MSALRefreshTokenCacheItem alloc] initWithAuthority:nil
                                                                                              clientId:clientId
                                                                                              response:response];
        [self saveRefreshToken:refreshToken];
    }
    
    return accessToken;
}

- (MSALAccessTokenCacheItem *)findAccessToken:(MSALRequestParameters *)requestParam
{
    MSALTokenCacheKey *key = [[MSALTokenCacheKey alloc] initWithAuthority:requestParam.unvalidatedAuthority.absoluteString//?
                                                                 clientId:requestParam.clientId
                                                                    scope:requestParam.scopes
                                                                     user:requestParam.user];
    
    NSArray<MSALAccessTokenCacheItem *> *allAccessTokens = [self allAccessTokens];
    NSMutableArray<MSALAccessTokenCacheItem *> *matchedTokens = [NSMutableArray<MSALAccessTokenCacheItem *> new];
    
    for (MSALAccessTokenCacheItem *tokenItem in allAccessTokens)
    {
        if ([key matches:tokenItem.tokenCacheKey])
        {
            [matchedTokens addObject:tokenItem];
        }
    }
    
    if (matchedTokens.count != 1)
    {
        return nil;
    }
    
    return matchedTokens[0];
}

- (MSALRefreshTokenCacheItem *)findRefreshToken:(MSALRequestParameters *)requestParam
{
    MSALTokenCacheKey *key = [[MSALTokenCacheKey alloc] initWithAuthority:nil
                                                                 clientId:requestParam.clientId
                                                                    scope:nil
                                                                 uniqueId:nil
                                                            displayableId:nil
                                                             homeObjectId:requestParam.user.homeObjectId];
    
    NSArray<MSALRefreshTokenCacheItem *> *allRefreshTokens = [self allRefreshTokens];
    NSMutableArray<MSALRefreshTokenCacheItem *> *matchedTokens = [NSMutableArray<MSALRefreshTokenCacheItem *> new];
    
    for (MSALRefreshTokenCacheItem *tokenItem in allRefreshTokens)
    {
        if ([key matches:tokenItem.tokenCacheKey])
        {
            [matchedTokens addObject:tokenItem];
        }
    }
    
    if (matchedTokens.count != 1)
    {
        return nil;
    }
    
    return matchedTokens[0];
}

- (BOOL)deleteAccessToken:(MSALAccessTokenCacheItem *)atItem
{
    MSALTokenCacheKey *key = [atItem tokenCacheKey];
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
        return NO;
    }
    return YES;
}

- (BOOL)deleteRefreshToken:(MSALRefreshTokenCacheItem *)rtItem
{
    MSALTokenCacheKey *key = [rtItem tokenCacheKey];
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
        return NO;
    }
    return YES;
}

- (BOOL)saveAccessToken:(MSALAccessTokenCacheItem *)atItem
{
    @synchronized(self)
    {
        MSALTokenCacheKey *key = [atItem tokenCacheKey];
        if (!key)
        {
            return NO;
        }
        
        NSMutableDictionary* query = [self queryDictionaryForKey:key
                                                      additional:@{
                                                                   (id)kSecAttrGeneric : [s_accessTokenFlag dataUsingEncoding:NSUTF8StringEncoding]
                                                                   }];
        
        NSData* itemData = [NSKeyedArchiver archivedDataWithRootObject:atItem];
        if (!itemData)
        {
            LOG_ERROR(nil, @"Failed to archive keychain item.");
            return NO;
        }
        
        NSDictionary* attrToUpdate = @{ (id)kSecValueData : itemData };
        OSStatus status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)attrToUpdate);
        if (status == errSecSuccess)
        {
            return YES;
        }
        else if (status == errSecItemNotFound)
        {
            // If the item wasn't found that means we need to add it instead.
            [query addEntriesFromDictionary:@{ (id)kSecValueData : itemData,
                                               (id)kSecAttrAccessible : (id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly}];
            status = SecItemAdd((CFDictionaryRef)query, NULL);
            if (status == errSecSuccess)
            {
                return YES;
            }
        }
    }
    
    return NO;
}

- (BOOL)saveRefreshToken:(MSALRefreshTokenCacheItem *)rtItem
{
    @synchronized(self)
    {
        MSALTokenCacheKey *key = [rtItem tokenCacheKey];
        if (!key)
        {
            return NO;
        }
        
        NSMutableDictionary* query = [self queryDictionaryForKey:key
                                                      additional:@{
                                                                   (id)kSecAttrGeneric : [s_refreshTokenFlag dataUsingEncoding:NSUTF8StringEncoding]
                                                                   }];
        
        NSData* itemData = [NSKeyedArchiver archivedDataWithRootObject:rtItem];
        if (!itemData)
        {
            LOG_ERROR(nil, @"Failed to archive keychain item.");
            return NO;
        }
        
        NSDictionary* attrToUpdate = @{ (id)kSecValueData : itemData };
        OSStatus status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)attrToUpdate);
        if (status == errSecSuccess)
        {
            return YES;
        }
        else if (status == errSecItemNotFound)
        {
            // If the item wasn't found that means we need to add it instead.
            [query addEntriesFromDictionary:@{ (id)kSecValueData : itemData,
                                               (id)kSecAttrAccessible : (id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly}];
            status = SecItemAdd((CFDictionaryRef)query, NULL);
            if (status == errSecSuccess)
            {
                return YES;
            }
        }
    }
    
    return NO;
}

- (NSArray<MSALAccessTokenCacheItem *> *)allAccessTokens
{
    NSMutableDictionary* query = [self queryDictionaryForKey:nil
                                                  additional:@{
                                                               (id)kSecAttrGeneric : [s_accessTokenFlag dataUsingEncoding:NSUTF8StringEncoding],
                                                               (id)kSecMatchLimit : (id)kSecMatchLimitAll,
                                                               (id)kSecReturnData : @YES,
                                                               (id)kSecReturnAttributes : @YES
                                                               }];
    CFTypeRef items = nil;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &items);
    if (status == errSecItemNotFound)
    {
        return @[];
    }
    NSArray *accessTokenitems = CFBridgingRelease(items);
    NSMutableArray<MSALAccessTokenCacheItem *> *accessTokens = [NSMutableArray<MSALAccessTokenCacheItem *> new];
    
    for (NSDictionary *attrs in accessTokenitems)
    {
        MSALAccessTokenCacheItem *item = [self accessTokenItemFromKeychainAttributes:attrs];
        if (!item)
        {
            continue;
        }
        
        [accessTokens addObject:item];
    }
    
    return accessTokens;
    
}

- (NSArray<MSALRefreshTokenCacheItem *> *)allRefreshTokens
{
    NSMutableDictionary* query = [self queryDictionaryForKey:nil
                                                  additional:@{
                                                               (id)kSecAttrGeneric : [s_refreshTokenFlag dataUsingEncoding:NSUTF8StringEncoding],
                                                               (id)kSecMatchLimit : (id)kSecMatchLimitAll,
                                                               (id)kSecReturnData : @YES,
                                                               (id)kSecReturnAttributes : @YES
                                                               }];
    CFTypeRef items = nil;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &items);
    if (status == errSecItemNotFound)
    {
        return @[];
    }
    NSArray *refreshTokenitems = CFBridgingRelease(items);
    NSMutableArray<MSALRefreshTokenCacheItem *> *refreshTokens = [NSMutableArray<MSALRefreshTokenCacheItem *> new];
    
    for (NSDictionary *attrs in refreshTokenitems)
    {
        MSALRefreshTokenCacheItem *item = [self refreshTokenItemFromKeychainAttributes:attrs];
        if (!item)
        {
            continue;
        }
        
        [refreshTokens addObject:item];
    }
    
    return refreshTokens;
    
}

- (NSMutableDictionary*)queryDictionaryForKey:(MSALTokenCacheKey *)key
                                   additional:(NSDictionary *)additional
{
    NSMutableDictionary* query = [NSMutableDictionary dictionaryWithDictionary:_default];
    if (key)
    {
        [query setObject:key.toString forKey:(NSString*)kSecAttrService];
    }
    
    if (additional)
    {
        [query addEntriesFromDictionary:additional];
    }
    
    return query;
}

- (MSALAccessTokenCacheItem *)accessTokenItemFromKeychainAttributes:(NSDictionary*)attrs
{
    NSData* data = [attrs objectForKey:(id)kSecValueData];
    if (!data)
    {
        LOG_WARN(nil, @"Retrieved item with key that did not have generic item data!");
        return nil;
    }
    @try
    {
        MSALAccessTokenCacheItem *item = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        if (!item)
        {
            LOG_WARN(nil, @"Unable to decode item from data stored in keychain.");
            return nil;
        }
        if (![item isKindOfClass:[MSALAccessTokenCacheItem class]])
        {
            LOG_WARN(nil, @"Unarchived Item was not of expected class");
            return nil;
        }
        
        return item;
    }
    @catch (NSException *exception)
    {
        LOG_WARN(nil, @"Failed to deserialize data from keychain");
        return nil;
    }
}

- (MSALRefreshTokenCacheItem *)refreshTokenItemFromKeychainAttributes:(NSDictionary*)attrs
{
    NSData* data = [attrs objectForKey:(id)kSecValueData];
    if (!data)
    {
        LOG_WARN(nil, @"Retrieved item with key that did not have generic item data!");
        return nil;
    }
    @try
    {
        MSALRefreshTokenCacheItem *item = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        if (!item)
        {
            LOG_WARN(nil, @"Unable to decode item from data stored in keychain.");
            return nil;
        }
        if (![item isKindOfClass:[MSALRefreshTokenCacheItem class]])
        {
            LOG_WARN(nil, @"Unarchived Item was not of expected class");
            return nil;
        }
        
        return item;
    }
    @catch (NSException *exception)
    {
        LOG_WARN(nil, @"Failed to deserialize data from keychain");
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
