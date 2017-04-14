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

#import "MSALTokenCacheAccessor.h"
#import "MSALAccessTokenCacheItem.h"
#import "MSALRefreshTokenCacheItem.h"
#import "MSALRefreshTokenCacheKey.h"
#import "MSALAccessTokenCacheKey.h"
#import "MSALTokenResponse.h"
#import "NSURL+MSALExtensions.h"

@implementation MSALTokenCacheAccessor
{
    id<MSALTokenCacheDataSource> _dataSource;
}

- (id)initWithDataSource:(id<MSALTokenCacheDataSource>)dataSource
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _dataSource = dataSource;
    
    return self;
}

- (id<MSALTokenCacheDataSource>)dataSource
{
    return _dataSource;
}

- (MSALAccessTokenCacheItem *)saveAccessAndRefreshToken:(MSALRequestParameters *)requestParam
                                               response:(MSALTokenResponse *)response
                                                context:(nullable id<MSALRequestContext>)ctx
                                                  error:(NSError * __autoreleasing *)error
{
    MSALAccessTokenCacheItem *accessToken = [[MSALAccessTokenCacheItem alloc] initWithAuthority:requestParam.unvalidatedAuthority
                                                                                       clientId:requestParam.clientId
                                                                                       response:response];
    //delete all cache entries with intersecting scopes
    //this should not happen but we have this as a safe guard against multiple matches
    NSArray<MSALAccessTokenCacheItem *> *allAccessTokens = [self allAccessTokensForUser:accessToken.user clientId:accessToken.clientId context:ctx error:nil];
    NSMutableArray<MSALAccessTokenCacheItem *> *overlappingTokens = [NSMutableArray<MSALAccessTokenCacheItem *> new];
    for (MSALAccessTokenCacheItem *tokenItem in allAccessTokens)
    {
        if ([tokenItem.authority isEqualToString:accessToken.authority]
            && [tokenItem.user.userIdentifier isEqualToString:accessToken.user.userIdentifier]
            && [tokenItem.scope intersectsOrderedSet:accessToken.scope])
        {
            [overlappingTokens addObject:tokenItem];
        }
    }
    for (MSALAccessTokenCacheItem *itemToDelete in overlappingTokens)
    {
        [self deleteAccessToken:itemToDelete context:ctx error:nil];
    }
    
    
    [self saveAccessToken:accessToken context:ctx error:error];
    
    if (response.refreshToken)
    {
        MSALRefreshTokenCacheItem *refreshToken = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:requestParam.unvalidatedAuthority.host
                                                                                                clientId:requestParam.clientId
                                                                                                response:response];
        [self saveRefreshToken:refreshToken context:ctx error:error];
    }
    
    return accessToken;
}

- (BOOL)saveRefreshToken:(MSALRefreshTokenCacheItem *)rtItem
                 context:(nullable id<MSALRequestContext>)ctx
                   error:(NSError * __autoreleasing *)error
{
    return [_dataSource addOrUpdateRefreshTokenItem:rtItem context:ctx error:error];
}

- (BOOL)saveAccessToken:(MSALAccessTokenCacheItem *)atItem
                context:(nullable id<MSALRequestContext>)ctx
                  error:(NSError * __autoreleasing *)error
{
    return [_dataSource addOrUpdateAccessTokenItem:atItem context:ctx error:error];
}

- (MSALAccessTokenCacheItem *)findAccessToken:(MSALRequestParameters *)requestParam
                                      context:(nullable id<MSALRequestContext>)ctx
                               authorityFound:(NSString * __autoreleasing *)authorityFound
                                        error:(NSError * __autoreleasing *)error
{
    MSALAccessTokenCacheKey *key = [[MSALAccessTokenCacheKey alloc] initWithAuthority:requestParam.unvalidatedAuthority.absoluteString
                                                                             clientId:requestParam.clientId
                                                                                scope:requestParam.scopes
                                                                       userIdentifier:requestParam.user.userIdentifier
                                                                          environment:requestParam.user.environment];
    
    NSArray<MSALAccessTokenCacheItem *> *allAccessTokens = [self allAccessTokensForUser:requestParam.user clientId:requestParam.clientId context:ctx error:error];
    if (!allAccessTokens)
    {
        return nil;
    }
    
    NSMutableArray<MSALAccessTokenCacheItem *> *matchedTokens = [NSMutableArray<MSALAccessTokenCacheItem *> new];
    
    for (MSALAccessTokenCacheItem *tokenItem in allAccessTokens)
    {
        if (requestParam.unvalidatedAuthority && [key matches:[tokenItem tokenCacheKey:nil]])
        {
            [matchedTokens addObject:tokenItem];
        }
        else if (!requestParam.unvalidatedAuthority && [requestParam.scopes isSubsetOfOrderedSet:tokenItem.scope])
        {
            [matchedTokens addObject:tokenItem];
        }
    }
    
    if (matchedTokens.count == 0)
    {
        LOG_WARN(ctx, @"No access token found.");
        LOG_WARN_PII(ctx, @"No access token found.");
        
        if (!requestParam.unvalidatedAuthority && authorityFound)
        {
            *authorityFound = [self findUniqueAuthorityInAccessTokens:allAccessTokens];
        }
        
        return nil;
    }
    
    if (matchedTokens.count > 1)
    {
        MSAL_ERROR_PARAM(ctx, MSALErrorMultipleMatchesNoAuthoritySpecified, @"Found multiple access tokens, which token to return is ambiguous! Please pass in authority if not provided.");
        return nil;
    }
    
    // if the token is expired, we still return it as we need the authority stored in it
    if (matchedTokens[0].isExpired)
    {
        LOG_INFO(ctx, @"Access token found in cache is already expired.");
        LOG_INFO_PII(ctx, @"Access token found in cache is already expired.");
        
        if (!requestParam.unvalidatedAuthority && authorityFound)
        {
            *authorityFound = matchedTokens[0].authority;
        }
        
        return nil;
    }
    
    return matchedTokens[0];
}

- (NSString *)findUniqueAuthorityInAccessTokens:(NSArray<MSALAccessTokenCacheItem *> *)accessTokens
{
    NSMutableSet<NSString *> *authorities = [[NSMutableSet<NSString *> alloc] init];
    for (MSALAccessTokenCacheItem *accessToken in accessTokens)
    {
        if (accessToken.authority)
        {
            [authorities addObject:accessToken.authority];
        }
    }
    
    if (authorities.count > 1 || authorities.count == 0)
    {
        return nil;
    }
    return authorities.allObjects[0];
}

- (MSALRefreshTokenCacheItem *)findRefreshToken:(MSALRequestParameters *)requestParam
                                        context:(nullable id<MSALRequestContext>)ctx
                                          error:(NSError * __autoreleasing *)error
{
    MSALRefreshTokenCacheKey *key = [[MSALRefreshTokenCacheKey alloc] initWithEnvironment:requestParam.unvalidatedAuthority.host
                                                                                 clientId:requestParam.clientId
                                                                           userIdentifier:requestParam.user.userIdentifier];
    return [_dataSource getRefreshTokenItemForKey:key context:ctx error:error];
}

- (BOOL)deleteAccessToken:(MSALAccessTokenCacheItem *)atItem
                  context:(nullable id<MSALRequestContext>)ctx
                    error:(NSError * __autoreleasing *)error
{
    MSALAccessTokenCacheKey *key = [atItem tokenCacheKey:error];
    if (!key)
    {
        return NO;
    }
    
    return [_dataSource removeAccessTokenItem:atItem context:ctx error:error];
}

- (BOOL)deleteAllTokensForUser:(MSALUser *)user
                      clientId:(NSString *)clientId
                       context:(id<MSALRequestContext>)ctx
                         error:(NSError * __autoreleasing *)error
{
    if (!user)
    {
        return YES;
    }
    
    return [_dataSource removeAllTokensForUserIdentifier:user.userIdentifier
                                             environment:user.environment
                                                clientId:clientId
                                                 context:ctx
                                                   error:error];
}


- (NSArray<MSALUser *> *)getUsers:(NSString *)clientId
                          context:(id<MSALRequestContext>)ctx
                            error:(NSError * __autoreleasing *)error
{
    NSArray<MSALRefreshTokenCacheItem *> *allRefreshTokens = [_dataSource allRefreshTokens:clientId context:ctx error:error];
    if (!allRefreshTokens)
    {
        return nil;
    }
    
    NSMutableArray *allUsers = [NSMutableArray new];
    for (MSALRefreshTokenCacheItem *tokenItem in allRefreshTokens)
    {
        [allUsers addObject:tokenItem.user];
    }
    
    return allUsers;
}

- (NSArray<MSALAccessTokenCacheItem *> *)allAccessTokensForUser:(MSALUser *)user
                                                       clientId:(NSString *)clientId
                                                        context:(id<MSALRequestContext>)ctx
                                                          error:(NSError * __autoreleasing *)error
{
    MSALAccessTokenCacheKey *key = [[MSALAccessTokenCacheKey alloc] initWithAuthority:nil
                                                                             clientId:nil
                                                                                scope:nil
                                                                       userIdentifier:user.userIdentifier
                                                                          environment:user.environment];
    
    NSArray *accessTokens = [_dataSource getAccessTokenItemsWithKey:key context:ctx error:error];
    if (!accessTokens)
    {
        return nil;
    }
    
    NSMutableArray *matchedAccessTokens = [NSMutableArray new];
    
    for (MSALAccessTokenCacheItem *token in accessTokens)
    {
        if (!clientId || [clientId isEqualToString:token.clientId])
        {
            [matchedAccessTokens addObject:token];
        }
    }
    
    return matchedAccessTokens;
}

@end
