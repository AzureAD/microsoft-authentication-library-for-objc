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
#import "MSALAccessTokenCacheKey.h"
#import "MSALRefreshTokenCacheKey.h"
#import "MSALRefreshTokenCacheItem.h"

#include <pthread.h>

@implementation MSALWrapperTokenCache
{
    NSMutableDictionary* _cache;
    id<MSALTokenCacheDelegate> _delegate;
    pthread_rwlock_t _lock;
}

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
    NSData *data = [self serializeImpl];
    pthread_rwlock_unlock(&_lock);
    
    return data;
}

- (BOOL)deserialize:(nullable NSData*)data
              error:(NSError * __autoreleasing *)error
{
    pthread_rwlock_wrlock(&_lock);
    BOOL ret = [self deserializeImpl:data error:error];
    pthread_rwlock_unlock(&_lock);
    return ret;
}

@end

@implementation MSALWrapperTokenCache (Internal)

- (id<MSALTokenCacheDelegate>)delegate
{
    return _delegate;
}

- (nullable NSArray <MSALAccessTokenCacheItem *> *)getAccessTokenItemsWithKey:(nullable MSALAccessTokenCacheKey *)key
                                                                      context:(nullable id<MSALRequestContext>)ctx
                                                                        error:(NSError * __autoreleasing *)error
{
    (void)error;
    
    [_delegate willAccessCache:self];
    int err = pthread_rwlock_rdlock(&_lock);
    if (err != 0)
    {
        LOG_ERROR(ctx, @"pthread_rwlock_rdlock failed in getAccessTokenItemsWithKey");
        LOG_ERROR_PII(ctx, @"pthread_rwlock_rdlock failed in getAccessTokenItemsWithKey");
        
        // TODO pass through error object
        return nil;
    }
    NSArray<MSALAccessTokenCacheItem *> *result = [self getAccessTokenImpl:key];
    pthread_rwlock_unlock(&_lock);
    
    [_delegate didAccessCache:self];
    
    return result;
}

- (NSArray<MSALAccessTokenCacheItem *> *)getAccessTokenImpl:(nullable MSALAccessTokenCacheKey *)key
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
    
    return items;
}

- (void)addToItems:(nonnull NSMutableArray *)items
            tokens:(nonnull NSDictionary *)userTokens
               key:(MSALTokenCacheKeyBase *)key
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

- (nullable MSALRefreshTokenCacheItem *)getRefreshTokenItemForKey:(nonnull MSALRefreshTokenCacheKey *)key
                                                          context:(nullable id<MSALRequestContext>)ctx
                                                            error:(NSError * __nullable __autoreleasing * __nullable)error
{
    (void)error;
    
    [_delegate willAccessCache:self];
    int err = pthread_rwlock_rdlock(&_lock);
    if (err != 0)
    {
        LOG_ERROR(ctx, @"pthread_rwlock_rdlock failed in getRefreshTokenItemsWithKey");
        LOG_ERROR_PII(ctx, @"pthread_rwlock_rdlock failed in getRefreshTokenItemsWithKey");
        // TODO pass through error object
        return nil;
    }
    NSDictionary *tokens = [_cache objectForKey:@"refresh_tokens"];
    MSALRefreshTokenCacheItem *item = [[tokens objectForKey:key.account] objectForKey:key.clientId];
    pthread_rwlock_unlock(&_lock);
    
    [_delegate didAccessCache:self];
    
    return item;
}

- (nullable NSArray<MSALRefreshTokenCacheItem *> *)allRefreshTokens:(nullable NSString *)clientId
                                                            context:(nullable id<MSALRequestContext>)ctx
                                                              error:(NSError * __nullable __autoreleasing * __nullable)error
{
    (void)error;
    (void)ctx;
    
    [_delegate willAccessCache:self];
    pthread_rwlock_rdlock(&_lock);
    
    NSDictionary<NSString *, NSMutableDictionary *> *tokens = [_cache objectForKey:@"refresh_tokens"];
    if (!tokens)
    {
        pthread_rwlock_unlock(&_lock);
        return nil;
    }
    
    NSMutableArray *items = [NSMutableArray new];
    
    // Otherwise we have to traverse all of the users in the cache
    for (NSString *userKey in tokens)
    {
        if (!clientId)
        {
            [items addObjectsFromArray:tokens[userKey].allValues];
            continue;
        }
        
        if (tokens[userKey][clientId])
        {
            [items addObject:tokens[userKey][clientId]];
        }
    }
    
    pthread_rwlock_unlock(&_lock);
    
    [_delegate didAccessCache:self];
    
    return items;
}

- (NSArray<MSALRefreshTokenCacheItem *> *)getRefreshTokenImpl:(nullable MSALRefreshTokenCacheKey *)key
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
    
    return items;
}

- (BOOL)addOrUpdateAccessTokenItem:(MSALAccessTokenCacheItem *)item
                           context:(nullable id<MSALRequestContext>)ctx
                             error:(NSError * __autoreleasing *)error
{
    [_delegate willWriteCache:self];
    int err = pthread_rwlock_wrlock(&_lock);
    if (err != 0)
    {
        LOG_ERROR(ctx, @"pthread_rwlock_wrlock failed in addOrUpdateAccessTokenItem");
        LOG_ERROR_PII(ctx, @"pthread_rwlock_wrlock failed in addOrUpdateAccessTokenItem");
        return NO;
    }
    BOOL result = [self addOrUpdateAccessTokenImpl:item context:ctx error:error];
    pthread_rwlock_unlock(&_lock);
    [_delegate didWriteCache:self];
    
    return result;
}

- (BOOL)addOrUpdateAccessTokenImpl:(MSALAccessTokenCacheItem *)item
                           context:(nullable id<MSALRequestContext>)ctx
                             error:(NSError * __autoreleasing *)error
{
    if (!item)
    {
        REQUIRED_PARAMETER_ERROR(item, ctx);
        return NO;
    }
    
    // Copy the item to make sure it doesn't change under us.
    item = [item copy];
    
    MSALAccessTokenCacheKey *key = [item tokenCacheKey:error];
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
    return YES;
}

- (BOOL)addOrUpdateRefreshTokenItem:(nonnull MSALRefreshTokenCacheItem *)item
                            context:(nullable id<MSALRequestContext>)ctx
                              error:(NSError * __autoreleasing *)error
{
    [_delegate willWriteCache:self];
    int err = pthread_rwlock_wrlock(&_lock);
    if (err != 0)
    {
        LOG_ERROR(ctx, @"pthread_rwlock_wrlock failed in addOrUpdateRefreshTokenItem");
        LOG_ERROR_PII(ctx, @"pthread_rwlock_wrlock failed in addOrUpdateRefreshTokenItem");
        return NO;
    }
    BOOL result = [self addOrUpdateRefreshTokenImpl:item context:ctx error:error];
    pthread_rwlock_unlock(&_lock);
    [_delegate didWriteCache:self];
    
    return result;
}

- (BOOL)addOrUpdateRefreshTokenImpl:(MSALRefreshTokenCacheItem *)item
                            context:(nullable id<MSALRequestContext>)ctx
                              error:(NSError * __autoreleasing *)error
{
    if (!item)
    {
        REQUIRED_PARAMETER_ERROR(item, ctx);
        return NO;
    }
    
    // Copy the item to make sure it doesn't change under us.
    item = [item copy];
    
    MSALRefreshTokenCacheKey *key = [item tokenCacheKey:error];
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
    return YES;
}

- (BOOL)removeAccessTokenItem:(nonnull MSALAccessTokenCacheItem *)item
                      context:(nullable id<MSALRequestContext>)ctx
                        error:(NSError * __autoreleasing *)error
{
    [_delegate willWriteCache:self];
    int err = pthread_rwlock_wrlock(&_lock);
    if (err != 0)
    {
        LOG_ERROR(ctx, @"pthread_rwlock_wrlock failed in removeAccessTokenItem");
        LOG_ERROR_PII(ctx, @"pthread_rwlock_wrlock failed in removeAccessTokenItem");
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
    MSALAccessTokenCacheKey *key = [item tokenCacheKey:error];
    if (!key)
    {
        return NO;
    }
    
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
                       context:(nullable id<MSALRequestContext>)ctx
                         error:(NSError * __autoreleasing *)error
{
    [_delegate willWriteCache:self];
    int err = pthread_rwlock_wrlock(&_lock);
    if (err != 0)
    {
        LOG_ERROR(ctx, @"pthread_rwlock_wrlock failed in removeRefreshTokenItem");
        LOG_ERROR_PII(ctx, @"pthread_rwlock_wrlock failed in removeRefreshTokenItem");
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
    MSALRefreshTokenCacheKey *key = [item tokenCacheKey:error];
    if (!key)
    {
        return NO;
    }
    
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


- (BOOL)removeAllTokensForUserIdentifier:(NSString *)userIdentifier
                             environment:(NSString *)environment
                                clientId:(NSString *)clientId
                                 context:(nullable id<MSALRequestContext>)ctx
                                   error:(NSError * __autoreleasing *)error
{
    [_delegate willWriteCache:self];
    int err = pthread_rwlock_wrlock(&_lock);
    if (err != 0)
    {
        LOG_ERROR(ctx, @"pthread_rwlock_wrlock failed in removeRefreshTokenItem");
        LOG_ERROR_PII(ctx, @"pthread_rwlock_wrlock failed in removeRefreshTokenItem");
        return NO;
    }
    BOOL result = [self removeAllTokensForUserIdentifierImp:userIdentifier
                                                environment:environment
                                                   clientId:clientId
                                                      error:error];
    
    pthread_rwlock_unlock(&_lock);
    [_delegate didWriteCache:self];
    return result;
}


- (BOOL)removeAllTokensForUserIdentifierImp:(NSString *)userIdentifier
                                environment:(NSString *)environment
                                   clientId:(NSString *)clientId
                                      error:(NSError * __autoreleasing *)error
{
    (void)userIdentifier;
    (void)clientId;
    (void)error;
    (void)environment;
    
    // TODO: implement
    @throw @"Todo";
    
    return YES;
}


- (NSData *)serializeImpl
{
    @try
    {
        NSMutableDictionary *data = [NSMutableDictionary new];
        [data setValue:[self jsonAccessTokens] forKey:@"access_tokens"];
        [data setValue:[self jsonRefreshTokens] forKey:@"refresh_tokens"];
        
        return [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
    }
    @catch (id exception)
    {
        // This should be exceedingly rare as all of the objects in the cache we placed there.
        LOG_ERROR(nil, @"Failed to serialize the cache!");
        LOG_ERROR_PII(nil, @"Failed to serialize the cache!");
        return nil;
    }
}

- (NSArray<NSDictionary *> *)jsonAccessTokens
{
    NSArray *accessTokens = [self getAccessTokenImpl:nil];
    NSMutableArray<NSDictionary *> *jsonTokens = [NSMutableArray<NSDictionary *> new];
    
    for (MSALAccessTokenCacheItem *item in accessTokens)
    {
        NSDictionary *jsonToken = [item jsonDictionary];
        if (jsonToken)
        {
            [jsonTokens addObject:jsonToken];
        }
    }
    return jsonTokens;
}

- (NSArray<NSDictionary *> *)jsonRefreshTokens
{
    NSArray *refreshTokens = [self getRefreshTokenImpl:nil];
    NSMutableArray<NSDictionary *> *jsonTokens = [NSMutableArray<NSDictionary *> new];
    
    for (MSALRefreshTokenCacheItem *item in refreshTokens)
    {
        NSDictionary *jsonToken = [item jsonDictionary];
        if (jsonToken)
        {
            [jsonTokens addObject:jsonToken];
        }
    }
    return jsonTokens;
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
    
    NSMutableDictionary *dataJson = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:error];
    if (!dataJson)
    {
        return NO;
    }
    
    //TODO
    //    if (![self validateCache:cache error:error])
    //    {
    //        return NO;
    //    }
    
    _cache = [NSMutableDictionary new];
    
    NSArray<NSDictionary *> *jsonAccessTokens = dataJson[@"access_tokens"];
    for (NSDictionary *jsonToken in jsonAccessTokens)
    {
        MSALAccessTokenCacheItem *item = [[MSALAccessTokenCacheItem alloc] initWithJson:jsonToken error:nil];
        [self addOrUpdateAccessTokenImpl:item context:nil error:error];
    }
    
    NSArray<NSDictionary *> *jsonRefreshTokens = dataJson[@"refresh_tokens"];
    for (NSDictionary *jsonToken in jsonRefreshTokens)
    {
        MSALRefreshTokenCacheItem *item = [[MSALRefreshTokenCacheItem alloc] initWithJson:jsonToken error:nil];
        [self addOrUpdateRefreshTokenImpl:item context:nil error:error];
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
