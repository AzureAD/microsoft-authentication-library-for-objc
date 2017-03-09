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

#import "MSALWrapperTokenCache.h"
#import "MSALWrapperTokenCache+Internal.h"
#import "MSALAccessTokenCacheItem.h"
#import "MSALTokenCacheKey.h"
#import "MSALRefreshTokenCacheItem.h"

#include <pthread.h>

@implementation MSALWrapperTokenCache

+ (MSALWrapperTokenCache *)defaultCache
{
    static dispatch_once_t once;
    static MSALWrapperTokenCache *cache = nil;
    
    dispatch_once(&once, ^{
        cache = [MSALWrapperTokenCache new];
    });
    
    return cache;
}

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    pthread_rwlock_init(&_lock, NULL);
    
    return self;
}

- (void)dealloc
{
    _cache = nil;
    _delegate = nil;
    
    pthread_rwlock_destroy(&_lock);
}

- (void)setDelegate:(nullable id<MSALTokenCacheDelegate>)delegate
{
    if (_delegate == delegate)
    {
        return;
    }
    
    int err = pthread_rwlock_wrlock(&_lock);
    if (err != 0)
    {
        LOG_ERROR(nil, @"pthread_rwlock_wrlock failed in setDelegate");
        LOG_ERROR_PII(nil, @"pthread_rwlock_wrlock failed in setDelegate");
        return;
    }
    
    _delegate = delegate;
    _cache = nil;
    
    pthread_rwlock_unlock(&_lock);
    
    if (!delegate)
    {
        return;
    }
    
    [_delegate willAccessCache:self];
    
    [_delegate didAccessCache:self];
}

- (nullable NSData *)serialize
{
    if (!_cache)
    {
        return nil;
    }
    
    int err = pthread_rwlock_rdlock(&_lock);
    if (err != 0)
    {
        LOG_ERROR(nil, @"pthread_rwlock_rdlock failed in serialize");
        LOG_ERROR_PII(nil, @"pthread_rwlock_rdlock failed in serialize");
        return nil;
    }
    NSDictionary *cacheCopy = [_cache mutableCopy];
    pthread_rwlock_unlock(&_lock);
    
    @try
    {
        return [NSJSONSerialization dataWithJSONObject:cacheCopy options:0 error:nil];
    }
    @catch (id exception)
    {
        // This should be exceedingly rare as all of the objects in the cache we placed there.
        LOG_ERROR(nil, @"Failed to serialize the cache!");
        LOG_ERROR_PII(nil, @"Failed to serialize the cache!");
        return nil;
    }
}

- (id)unarchive:(NSData*)data
          error:(NSError * __autoreleasing *)error
{
    @try
    {
        return [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    @catch (id expection)
    {
        if (error)
        {
            MSALFillAndLogError(error, nil, MSALErrorWrapperCacheFailure, nil, nil, nil, __FUNCTION__, __LINE__, @"Failed to unarchive data blob from -deserialize!");
        }
        
        return nil;
    }
}


- (BOOL)deserialize:(nullable NSData*)data
              error:(NSError * __autoreleasing *)error
{
    pthread_rwlock_wrlock(&_lock);
    BOOL ret = [self deserializeImpl:data error:error];
    pthread_rwlock_unlock(&_lock);
    return ret;
}

- (BOOL)deserializeImpl:(nullable NSData*)data
                  error:(NSError * __autoreleasing *)error
{
    // If they pass in nil on deserialize that means to drop the cache
    if (!data)
    {
        _cache = nil;
        return YES;
    }
    
    id cache = [NSJSONSerialization JSONObjectWithData:data
                                    options:NSJSONReadingAllowFragments error:error];
    if (!cache)
    {
        return NO;
    }
    
    //TODO
    //    if (![self validateCache:cache error:error])
    //    {
    //        return NO;
    //    }
    
    _cache = cache;
    return YES;
}

@end

@implementation MSALWrapperTokenCache (Internal)

- (id<MSALTokenCacheDelegate>)delegate
{
    return _delegate;
}

- (nullable NSArray <MSALAccessTokenCacheItem *> *)getAccessTokenItemsWithKey:(nullable MSALTokenCacheKey *)key
                                                                correlationId:(nullable NSUUID * )correlationId
                                                                        error:(NSError * __autoreleasing *)error
{
    (void)error;
    (void)correlationId;
    
    [_delegate willAccessCache:self];
    int err = pthread_rwlock_rdlock(&_lock);
    if (err != 0)
    {
        LOG_ERROR(nil, @"pthread_rwlock_rdlock failed in getItemsWithKey");
        LOG_ERROR_PII(nil, @"pthread_rwlock_rdlock failed in getItemsWithKey");
        return nil;
    }
    NSArray<MSALAccessTokenCacheItem *> *result = [self getAccessTokenImpl:key];
    pthread_rwlock_unlock(&_lock);
    
    [_delegate didAccessCache:self];
    
    return result;
}

- (NSArray<MSALAccessTokenCacheItem *> *)getAccessTokenImpl:(nullable MSALTokenCacheKey *)key
{
    if (!_cache)
    {
        return nil;
    }
    
    NSDictionary *tokens = [_cache objectForKey:@"access_tokens"];
    if (!tokens)
    {
        return nil;
    }
    
    NSMutableArray *items = [NSMutableArray new];
    
    NSString *userId = key.service;
    if (userId)
    {
        // If we have a specified userId then we only look for that one
        [self addToItems:items tokens:[tokens objectForKey:userId] key:key];
    }
    else
    {
        // Otherwise we have to traverse all of the users in the cache
        for (NSString *userId in tokens)
        {
            [self addToItems:items tokens:[tokens objectForKey:userId] key:key];
        }
    }
    
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
    if (key.account)
    {
        id item = [userTokens objectForKey:key.account];
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
    
    [_delegate willAccessCache:self];
    int err = pthread_rwlock_rdlock(&_lock);
    if (err != 0)
    {
        LOG_ERROR(nil, @"pthread_rwlock_rdlock failed in getItemsWithKey");
        LOG_ERROR_PII(nil, @"pthread_rwlock_rdlock failed in getItemsWithKey");
        return nil;
    }
    NSArray<MSALRefreshTokenCacheItem *> *result = [self getRefreshTokenImpl:key];
    pthread_rwlock_unlock(&_lock);
    
    [_delegate didAccessCache:self];
    
    return result;
}

- (NSArray<MSALRefreshTokenCacheItem *> *)getRefreshTokenImpl:(nullable MSALTokenCacheKey *)key
{
    if (!_cache)
    {
        return nil;
    }
    
    NSDictionary *tokens = [_cache objectForKey:@"refresh_tokens"];
    if (!tokens)
    {
        return nil;
    }
    
    NSMutableArray *items = [NSMutableArray new];
    
    NSString *userId = key.service;
    if (userId)
    {
        // If we have a specified userId then we only look for that one
        [self addToItems:items tokens:[tokens objectForKey:userId] key:key];
    }
    else
    {
        // Otherwise we have to traverse all of the users in the cache
        for (NSString *userId in tokens)
        {
            [self addToItems:items tokens:[tokens objectForKey:userId] key:key];
        }
    }
    
    return items;
}

- (BOOL)addOrUpdateAccessTokenItem:(MSALAccessTokenCacheItem *)item
                     correlationId:(nullable NSUUID *)correlationId
                             error:(NSError * __autoreleasing *)error
{
    [_delegate willWriteCache:self];
    int err = pthread_rwlock_wrlock(&_lock);
    if (err != 0)
    {
        LOG_ERROR(nil, @"pthread_rwlock_wrlock failed in addOrUpdateItem");
        LOG_ERROR_PII(nil, @"pthread_rwlock_wrlock failed in addOrUpdateItem");
        return NO;
    }
    BOOL result = [self addOrUpdateAccessTokenImpl:item correlationId:correlationId error:error];
    pthread_rwlock_unlock(&_lock);
    [_delegate didWriteCache:self];
    
    return result;
}

- (BOOL)addOrUpdateAccessTokenImpl:(MSALAccessTokenCacheItem *)item
                     correlationId:(NSUUID *)correlationId
                             error:(NSError * __autoreleasing *)error
{
    (void)correlationId;
    if (!item)
    {
        if (error)
        {
            MSALFillAndLogError(error, nil, MSALErrorInvalidParameter, nil, nil, nil, __FUNCTION__, __LINE__, @"nil item for addOrUpdate operation.");
        }
        return NO;
    }
    
    // Copy the item to make sure it doesn't change under us.
    item = [item copy];
    
    MSALTokenCacheKey *key = item.tokenCacheKey;
    if (!key)
    {
        return NO;
    }
    
    NSMutableDictionary *tokens = nil;
    
    if (!_cache)
    {
        // If we don't have a cache that means we need to create one.
        _cache = [NSMutableDictionary new];
    }
    
    tokens = [_cache objectForKey:@"access_tokens"];
    if (!tokens)
    {
        tokens = [NSMutableDictionary new];
        [_cache setObject:tokens forKey:@"access_tokens"];
    }

    
    // Grab the userId first
    NSString *userId = key.account;
    if (!userId)
    {
        userId = @"";
    }
    
    // Grab the token dictionary for this user id.
    NSMutableDictionary *userDict = [tokens objectForKey:userId];
    if (!userDict)
    {
        userDict = [NSMutableDictionary new];
        [tokens setObject:userDict forKey:userId];
    }
    
    [userDict setObject:item forKey:key.service];
    return YES;
}

- (BOOL)addOrUpdateRefreshTokenItem:(nonnull MSALRefreshTokenCacheItem *)item
                      correlationId:(nullable NSUUID *)correlationId
                              error:(NSError * __autoreleasing *)error
{
    [_delegate willWriteCache:self];
    int err = pthread_rwlock_wrlock(&_lock);
    if (err != 0)
    {
        LOG_ERROR(nil, @"pthread_rwlock_wrlock failed in addOrUpdateItem");
        LOG_ERROR_PII(nil, @"pthread_rwlock_wrlock failed in addOrUpdateItem");
        return NO;
    }
    BOOL result = [self addOrUpdateRefreshTokenImpl:item correlationId:correlationId error:error];
    pthread_rwlock_unlock(&_lock);
    [_delegate didWriteCache:self];
    
    return result;
}

- (BOOL)addOrUpdateRefreshTokenImpl:(MSALRefreshTokenCacheItem *)item
                      correlationId:(NSUUID *)correlationId
                              error:(NSError * __autoreleasing *)error
{
    (void)correlationId;
    if (!item)
    {
        if (error)
        {
            MSALFillAndLogError(error, nil, MSALErrorInvalidParameter, nil, nil, nil, __FUNCTION__, __LINE__, @"nil item for addOrUpdate operation.");
        }
        return NO;
    }
    
    // Copy the item to make sure it doesn't change under us.
    item = [item copy];
    
    MSALTokenCacheKey *key = item.tokenCacheKey;
    if (!key)
    {
        return NO;
    }
    
    NSMutableDictionary *tokens = nil;
    
    if (!_cache)
    {
        // If we don't have a cache that means we need to create one.
        _cache = [NSMutableDictionary new];
    }
    
    tokens = [_cache objectForKey:@"refresh_tokens"];
    if (!tokens)
    {
        tokens = [NSMutableDictionary new];
        [_cache setObject:tokens forKey:@"refresh_tokens"];
    }
    
    // Grab the userId first
    NSString *userId = key.account;
    if (!userId)
    {
        userId = @"";
    }
    
    // Grab the token dictionary for this user id.
    NSMutableDictionary *userDict = [tokens objectForKey:userId];
    if (!userDict)
    {
        userDict = [NSMutableDictionary new];
        [tokens setObject:userDict forKey:userId];
    }
    
    [userDict setObject:item forKey:key.service];
    return YES;
}

- (BOOL)removeAccessTokenItem:(nonnull MSALAccessTokenCacheItem *)item
                        error:(NSError * __autoreleasing *)error
{
    [_delegate willWriteCache:self];
    int err = pthread_rwlock_wrlock(&_lock);
    if (err != 0)
    {
        LOG_ERROR(nil, @"pthread_rwlock_wrlock failed in removeItem");
        LOG_ERROR_PII(nil, @"pthread_rwlock_wrlock failed in removeItem");
        return NO;
    }
    BOOL result = [self removeAccessTokenImpl:item error:error];
    pthread_rwlock_unlock(&_lock);
    [_delegate didWriteCache:self];
    return result;
}

- (BOOL)removeAccessTokenImpl:(MSALAccessTokenCacheItem *)item
                        error:(NSError * __autoreleasing *)error
{
    (void)error;
    MSALTokenCacheKey *key = item.tokenCacheKey;
    if (!key)
    {
        return NO;
    }
    
    NSString *userId = key.account;
    if (!userId)
    {
        userId = @"";
    }
    
    NSMutableDictionary *tokens = [_cache objectForKey:@"access_tokens"];
    if (!tokens)
    {
        return YES;
    }
    
    NSMutableDictionary *userTokens = [tokens objectForKey:userId];
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
        [tokens removeObjectForKey:userId];
    }
    
    return YES;
}


- (BOOL)removeRefreshTokenItem:(nonnull MSALRefreshTokenCacheItem *)item
                         error:(NSError * __autoreleasing *)error
{
    [_delegate willWriteCache:self];
    int err = pthread_rwlock_wrlock(&_lock);
    if (err != 0)
    {
        LOG_ERROR(nil, @"pthread_rwlock_wrlock failed in removeItem");
        LOG_ERROR_PII(nil, @"pthread_rwlock_wrlock failed in removeItem");
        return NO;
    }
    BOOL result = [self removeRefreshTokenImpl:item error:error];
    pthread_rwlock_unlock(&_lock);
    [_delegate didWriteCache:self];
    return result;
}

- (BOOL)removeRefreshTokenImpl:(MSALRefreshTokenCacheItem *)item
                         error:(NSError * __autoreleasing *)error
{
    (void)error;
    MSALTokenCacheKey *key = item.tokenCacheKey;
    if (!key)
    {
        return NO;
    }
    
    NSString *userId = key.account;
    if (!userId)
    {
        userId = @"";
    }
    
    NSMutableDictionary *tokens = [_cache objectForKey:@"refresh_tokens"];
    if (!tokens)
    {
        return YES;
    }
    
    NSMutableDictionary *userTokens = [tokens objectForKey:userId];
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
        [tokens removeObjectForKey:userId];
    }
    
    return YES;
}

- (void)testRemoveAll
{
    [_delegate willWriteCache:self];
    int err = pthread_rwlock_wrlock(&_lock);
    if (err != 0)
    {
        LOG_ERROR(nil, @"pthread_rwlock_wrlock failed in testRemoveAll");
        LOG_ERROR_PII(nil, @"pthread_rwlock_wrlock failed in testRemoveAll");
    }
    
    _cache = [NSMutableDictionary new];
    
    pthread_rwlock_unlock(&_lock);
    [_delegate didWriteCache:self];
}

@end
