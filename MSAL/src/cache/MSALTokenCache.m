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

#import "MSALTokenCache.h"
#import "MSALAccessTokenCacheItem.h"
#import "MSALRefreshTokenCacheItem.h"
#import "MSALRefreshTokenCacheKey.h"
#import "MSALAccessTokenCacheKey.h"
#import "MSALTokenResponse.h"
#import "MSALTelemetry.h"
#import "MSALTelemetry+Internal.h"
#import "MSALTelemetryCacheEvent.h"
#import "MSALTelemetryEventStrings.h"
#import "NSURL+MSALExtensions.h"
#import "NSURL+MSALExtensions.h"

@implementation MSALTokenCache
{
    id<MSALTokenCacheAccessor> _dataSource;
}

- (id)initWithDataSource:(id<MSALTokenCacheAccessor>)dataSource
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _dataSource = dataSource;
    
    return self;
}

- (id<MSALTokenCacheAccessor>)dataSource
{
    return _dataSource;
}

- (MSALAccessTokenCacheItem *)saveAccessTokenWithAuthority:(NSURL *)authority
                                                  clientId:(NSString *)clientId
                                                  response:(MSALTokenResponse *)response
                                                   context:(id<MSALRequestContext>)context
                                                     error:(NSError * __autoreleasing *)error
{
    MSALAccessTokenCacheItem *accessToken = [[MSALAccessTokenCacheItem alloc] initWithAuthority:authority
                                                                                       clientId:clientId
                                                                                       response:response];
    
    //delete all cache entries with intersecting scopes
    //this should not happen but we have this as a safe guard against multiple matches
    NSArray<MSALAccessTokenCacheItem *> *allAccessTokens = [self allAccessTokensForUser:accessToken.user
                                                                               clientId:accessToken.clientId
                                                                                context:context
                                                                                  error:nil];
    
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
        [self deleteAccessToken:itemToDelete context:context error:nil];
    }
    
    [self saveAccessToken:accessToken context:context error:error];
    
    return accessToken;
}

- (MSALRefreshTokenCacheItem *)saveRefreshTokenWithEnvironment:(NSString *)environment
                                                      clientId:(NSString *)clientId
                                                      response:(MSALTokenResponse *)response
                                                       context:(id<MSALRequestContext>)context
                                                         error:(NSError * __autoreleasing *)error
{
    MSALRefreshTokenCacheItem *refreshToken = nil;
    if (response.refreshToken)
    {
        refreshToken = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:environment
                                                                     clientId:clientId
                                                                     response:response];
        [self saveRefreshToken:refreshToken context:context error:error];
    }
    
    return refreshToken;
}

- (BOOL)saveRefreshToken:(MSALRefreshTokenCacheItem *)rtItem
                 context:(nullable id<MSALRequestContext>)ctx
                   error:(NSError * __autoreleasing *)error
{
    [[MSALTelemetry sharedInstance] startEvent:[ctx telemetryRequestId] eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_WRITE];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_WRITE
                                                                           context:ctx];
    [event setTokenType:MSAL_TELEMETRY_VALUE_REFRESH_TOKEN];

    BOOL result = [_dataSource addOrUpdateRefreshTokenItem:rtItem context:ctx error:error];

    [[MSALTelemetry sharedInstance] stopEvent:[ctx telemetryRequestId] event:event];

    return result;
}

- (BOOL)saveAccessToken:(MSALAccessTokenCacheItem *)atItem
                context:(nullable id<MSALRequestContext>)ctx
                  error:(NSError * __autoreleasing *)error
{
    [[MSALTelemetry sharedInstance] startEvent:[ctx telemetryRequestId] eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_WRITE];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_WRITE
                                                                           context:ctx];
    [event setTokenType:MSAL_TELEMETRY_VALUE_ACCESS_TOKEN];
    
    BOOL result = [_dataSource addOrUpdateAccessTokenItem:atItem context:ctx error:error];
    
    [[MSALTelemetry sharedInstance] stopEvent:[ctx telemetryRequestId] event:event];
    
    return result;
}

- (MSALAccessTokenCacheItem *)findAccessTokenWithAuthority:(NSURL *)authority
                                                  clientId:(NSString *)clientId
                                                    scopes:(MSALScopes *)scopes
                                                      user:(MSALUser *)user
                                                   context:(nullable id<MSALRequestContext>)ctx
                                            authorityFound:(NSString * __autoreleasing *)authorityFound
                                                     error:(NSError * __autoreleasing *)error
{
    [[MSALTelemetry sharedInstance] startEvent:[ctx telemetryRequestId] eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                           context:ctx];
    [event setTokenType:MSAL_TELEMETRY_VALUE_ACCESS_TOKEN];
    
    MSALAccessTokenCacheKey *key = [[MSALAccessTokenCacheKey alloc] initWithAuthority:authority.absoluteString
                                                                             clientId:clientId
                                                                                scope:scopes
                                                                       userIdentifier:user.userIdentifier
                                                                          environment:user.environment];
    
    NSArray<MSALAccessTokenCacheItem *> *allAccessTokens = [self allAccessTokensForUser:user
                                                                               clientId:clientId
                                                                                context:ctx
                                                                                  error:error];
    if (!allAccessTokens)
    {
        [[MSALTelemetry sharedInstance] stopEvent:[ctx telemetryRequestId] event:event];
        
        return nil;
    }
    
    NSMutableArray<MSALAccessTokenCacheItem *> *matchedTokens = [NSMutableArray<MSALAccessTokenCacheItem *> new];
    
    for (MSALAccessTokenCacheItem *tokenItem in allAccessTokens)
    {
        if (authority && [key matches:[tokenItem tokenCacheKey:nil]])
        {
            [matchedTokens addObject:tokenItem];
        }
        else if (!authority && [scopes isSubsetOfOrderedSet:tokenItem.scope])
        {
            [matchedTokens addObject:tokenItem];
        }
    }
    
    if (matchedTokens.count == 0)
    {
        LOG_WARN(ctx, @"No access token found.");
        LOG_WARN_PII(ctx, @"No access token found.");
        
        [[MSALTelemetry sharedInstance] stopEvent:[ctx telemetryRequestId] event:event];
        
        if (!authority && authorityFound)
        {
            *authorityFound = [self findUniqueAuthorityInAccessTokens:allAccessTokens];
        }
        
        return nil;
    }
    
    if (matchedTokens.count > 1)
    {
        MSAL_ERROR_PARAM(ctx, MSALErrorMultipleMatchesNoAuthoritySpecified, @"Found multiple access tokens, which token to return is ambiguous! Please pass in authority if not provided.");
        
        [[MSALTelemetry sharedInstance] stopEvent:[ctx telemetryRequestId] event:event];
        
        return nil;
    }
    
    if (matchedTokens[0].isExpired)
    {
        LOG_INFO(ctx, @"Access token found in cache is already expired.");
        LOG_INFO_PII(ctx, @"Access token found in cache is already expired.");
        
        if (authorityFound)
        {
            // if authority is not provided, set authorityFound with the token's authority
            // if not, set authorityFound with the passed in authority
            *authorityFound = authority ? authority.absoluteString : matchedTokens[0].authority;
        }
        
        [[MSALTelemetry sharedInstance] stopEvent:[ctx telemetryRequestId] event:event];
        
        return nil;
    }
    
    [[MSALTelemetry sharedInstance] stopEvent:[ctx telemetryRequestId] event:event];
    
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

- (MSALRefreshTokenCacheItem *)findRefreshTokenWithEnvironment:(NSString *)environment
                                                      clientId:(NSString *)clientId
                                                userIdentifier:(NSString *)userIdentifier
                                                       context:(nullable id<MSALRequestContext>)ctx
                                                         error:(NSError * __autoreleasing *)error
{
    [[MSALTelemetry sharedInstance] startEvent:[ctx telemetryRequestId] eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                           context:ctx];
    [event setTokenType:MSAL_TELEMETRY_VALUE_REFRESH_TOKEN];
    
    MSALRefreshTokenCacheKey *key = [[MSALRefreshTokenCacheKey alloc] initWithEnvironment:environment
                                                                                 clientId:clientId
                                                                           userIdentifier:userIdentifier];
    MSALRefreshTokenCacheItem *item = [_dataSource getRefreshTokenItemForKey:key context:ctx error:error];
    
    [[MSALTelemetry sharedInstance] stopEvent:[ctx telemetryRequestId] event:event];
    
    return item;
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
    
    [[MSALTelemetry sharedInstance] startEvent:[ctx telemetryRequestId] eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_DELETE];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_DELETE
                                                                           context:ctx];
    
    [event setTokenType:MSAL_TELEMETRY_VALUE_ACCESS_TOKEN];
    
    BOOL result = [_dataSource removeAccessTokenItem:atItem context:ctx error:error];
    
    [[MSALTelemetry sharedInstance] stopEvent:[ctx telemetryRequestId] event:event];
    
    return result;
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

- (MSALUser *)getUserForIdentifier:(NSString *)userIdentifier
                          clientId:(NSString *)clientId
                       environment:(NSString *)environment
                             error:(NSError * __autoreleasing *)error
{
    REQUIRED_PARAMETER(userIdentifier, nil);
    REQUIRED_PARAMETER(clientId, nil);
    REQUIRED_PARAMETER(environment, nil);
    
    MSALRefreshTokenCacheKey *key =
    [[MSALRefreshTokenCacheKey alloc] initWithEnvironment:environment
                                                 clientId:clientId
                                           userIdentifier:userIdentifier];
    
    NSError *localError = nil;
    MSALRefreshTokenCacheItem *rtItem =
    [_dataSource getRefreshTokenItemForKey:key context:nil error:&localError];
    if (!rtItem)
    {
        if (!localError)
        {
            MSAL_ERROR_PARAM(nil, MSALErrorUserNotFound, @"No user found matching userIdentifier");
        }
        else if (error)
        {
            *error = localError;
        }
        return nil;
    }
    
    return rtItem.user;
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
