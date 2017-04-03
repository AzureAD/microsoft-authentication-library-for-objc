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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSALTestTokenCache.h"
#import "MSALTokenCacheKey.h"
#import "MSALAccessTokenCacheItem.h"
#import "MSALRefreshTokenCacheItem.h"

#include <pthread.h>

@implementation MSALTestTokenCache
{
    NSMutableDictionary* _cache;
    pthread_rwlock_t _lock;
}

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _cache = [NSMutableDictionary new];
    
    pthread_rwlock_init(&_lock, NULL);
    
    return self;
}

- (void)dealloc
{
    _cache = nil;
    pthread_rwlock_destroy(&_lock);
}

- (nullable NSArray <MSALAccessTokenCacheItem *> *)getAccessTokenItemsWithKey:(nullable MSALTokenCacheKey *)key
                                                                correlationId:(nullable NSUUID * )correlationId
                                                                        error:(NSError * __autoreleasing *)error
{
    (void)error;
    (void)correlationId;
    
    pthread_rwlock_rdlock(&_lock);
    
    NSDictionary *tokens = [_cache objectForKey:@"access_tokens"];
    if (!tokens)
    {
        pthread_rwlock_unlock(&_lock);
        return nil;
    }
    
    NSMutableArray *items = [NSMutableArray new];
    
    NSString *userKey = key.account;
    if (userKey)
    {
        // If we have a specified user key then we only look for that one
        [self addToItems:items tokens:[tokens objectForKey:userKey] key:key];
    }
    else
    {
        // Otherwise we have to traverse all of the users in the cache
        for (NSString *userKey in tokens)
        {
            [self addToItems:items tokens:[tokens objectForKey:userKey] key:key];
        }
    }
    
    pthread_rwlock_unlock(&_lock);
    
    return items;
}

- (void)addToItems:(nonnull NSMutableArray *)items
            tokens:(nonnull NSDictionary *)userTokens
               key:(MSALTokenCacheKey *)key
{
    if (!userTokens)
    {
        return;
    }
    
    // Add items matching the key for this user
    if (key.service)
    {
        id item = [userTokens objectForKey:key.service];
        if (item)
        {
            item = [item copy];
            [items addObject:item];
        }
    }
    else
    {
        for (id adkey in userTokens)
        {
            id item = [userTokens objectForKey:adkey];
            if (item)
            {
                item = [item copy];
                [items addObject:item];
            }
        }
    }
}

- (nullable NSArray <MSALRefreshTokenCacheItem *> *)getRefreshTokenItemsWithKey:(nullable MSALTokenCacheKey *)key
                                                                  correlationId:(nullable NSUUID * )correlationId
                                                                          error:(NSError * __autoreleasing *)error
{
    (void)error;
    (void)correlationId;
    
    pthread_rwlock_rdlock(&_lock);
    
    NSDictionary *tokens = [_cache objectForKey:@"refresh_tokens"];
    if (!tokens)
    {
        pthread_rwlock_unlock(&_lock);
        return nil;
    }
    
    NSMutableArray *items = [NSMutableArray new];
    
    NSString *userKey = key.account;
    if (userKey)
    {
        // If we have a specified userId then we only look for that one
        [self addToItems:items tokens:[tokens objectForKey:userKey] key:key];
    }
    else
    {
        // Otherwise we have to traverse all of the users in the cache
        for (NSString *userKey in tokens)
        {
            [self addToItems:items tokens:[tokens objectForKey:userKey] key:key];
        }
    }
    
    pthread_rwlock_unlock(&_lock);
    
    return items;
}

- (BOOL)addOrUpdateAccessTokenItem:(MSALAccessTokenCacheItem *)item
                     correlationId:(nullable NSUUID *)correlationId
                             error:(NSError * __autoreleasing *)error
{
    (void)correlationId;
    
    pthread_rwlock_wrlock(&_lock);
    
    // Copy the item to make sure it doesn't change under us.
    item = [item copy];
    MSALTokenCacheKey *key = [item tokenCacheKey:error];
    
    NSMutableDictionary *tokens = [_cache objectForKey:@"access_tokens"];
    if (!tokens)
    {
        tokens = [NSMutableDictionary new];
        [_cache setObject:tokens forKey:@"access_tokens"];
    }
    
    // Grab the userKey first
    NSString *userKey = key.account;
    if (!userKey)
    {
        userKey = @"";
    }
    
    // Grab the token dictionary for this user id.
    NSMutableDictionary *userDict = [tokens objectForKey:userKey];
    if (!userDict)
    {
        userDict = [NSMutableDictionary new];
        [tokens setObject:userDict forKey:userKey];
    }
    
    [userDict setObject:item forKey:key.service];
    
    pthread_rwlock_unlock(&_lock);
    
    return YES;
}

- (BOOL)addOrUpdateRefreshTokenItem:(nonnull MSALRefreshTokenCacheItem *)item
                      correlationId:(nullable NSUUID *)correlationId
                              error:(NSError * __autoreleasing *)error
{
    (void)correlationId;
    pthread_rwlock_wrlock(&_lock);
    
    // Copy the item to make sure it doesn't change under us.
    item = [item copy];
    
    MSALTokenCacheKey *key = [item tokenCacheKey:error];
    
    NSMutableDictionary *tokens = [_cache objectForKey:@"refresh_tokens"];
    if (!tokens)
    {
        tokens = [NSMutableDictionary new];
        [_cache setObject:tokens forKey:@"refresh_tokens"];
    }
    
    // Grab the userId first
    NSString *userKey = key.account;
    if (!userKey)
    {
        userKey = @"";
    }
    
    // Grab the token dictionary for this user id.
    NSMutableDictionary *userDict = [tokens objectForKey:userKey];
    if (!userDict)
    {
        userDict = [NSMutableDictionary new];
        [tokens setObject:userDict forKey:userKey];
    }
    
    [userDict setObject:item forKey:key.service];
    
    pthread_rwlock_unlock(&_lock);
    
    return YES;
}

- (BOOL)removeAccessTokenItem:(nonnull MSALAccessTokenCacheItem *)item
                        error:(NSError * __autoreleasing *)error
{
    pthread_rwlock_wrlock(&_lock);
    BOOL result = [self removeAccessTokenImpl:item error:error];
    pthread_rwlock_unlock(&_lock);
    
    return result;
}

- (BOOL)removeAccessTokenImpl:(MSALAccessTokenCacheItem *)item
                        error:(NSError * __autoreleasing *)error
{
    (void)error;
    MSALTokenCacheKey *key = [item tokenCacheKey:error];
    
    NSString *userKey = key.account;
    if (!userKey)
    {
        userKey = @"";
    }
    
    NSMutableDictionary *tokens = [_cache objectForKey:@"access_tokens"];
    if (!tokens)
    {
        return YES;
    }
    
    NSMutableDictionary *userTokens = [tokens objectForKey:userKey];
    if (!userTokens)
    {
        return YES;
    }
    
    if (![userTokens objectForKey:key.service])
    {
        return YES;
    }
    
    [userTokens removeObjectForKey:key.service];
    
    // Check to see if we need to remove the overall dict
    if (!userTokens.count)
    {
        [tokens removeObjectForKey:userKey];
    }
    
    return YES;
}


- (BOOL)removeRefreshTokenItem:(nonnull MSALRefreshTokenCacheItem *)item
                         error:(NSError * __autoreleasing *)error
{
    pthread_rwlock_wrlock(&_lock);
    BOOL result = [self removeRefreshTokenImpl:item error:error];
    pthread_rwlock_unlock(&_lock);

    return result;
}

- (BOOL)removeRefreshTokenImpl:(MSALRefreshTokenCacheItem *)item
                         error:(NSError * __autoreleasing *)error
{
    (void)error;
    MSALTokenCacheKey *key = [item tokenCacheKey:error];
    
    NSString *userKey = key.account;
    if (!userKey)
    {
        userKey = @"";
    }
    
    NSMutableDictionary *tokens = [_cache objectForKey:@"refresh_tokens"];
    if (!tokens)
    {
        return YES;
    }
    
    NSMutableDictionary *userTokens = [tokens objectForKey:userKey];
    if (!userTokens)
    {
        return YES;
    }
    
    if (![userTokens objectForKey:key.service])
    {
        return YES;
    }
    
    [userTokens removeObjectForKey:key.service];
    
    // Check to see if we need to remove the overall dict
    if (!userTokens.count)
    {
        [tokens removeObjectForKey:userKey];
    }
    
    return YES;
}

@end
