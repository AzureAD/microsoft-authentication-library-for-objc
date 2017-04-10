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
#import "MSALTelemetry.h"
#import "MSALTelemetry+Internal.h"
#import "MSALTelemetryCacheEvent.h"
#import "MSALTelemetryEventStrings.h"

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
        [self deleteAccessToken:itemToDelete context:ctx telemetryRequestId:requestParam.telemetryRequestId error:nil];
    }
    
    [self saveAccessToken:accessToken context:ctx telemetryRequestId:requestParam.telemetryRequestId error:error];
    
    if (response.refreshToken)
    {
        MSALRefreshTokenCacheItem *refreshToken = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:requestParam.unvalidatedAuthority.host
                                                                                                clientId:requestParam.clientId
                                                                                                response:response];
        [self saveRefreshToken:refreshToken context:ctx telemetryRequestId:requestParam.telemetryRequestId error:error];
    }
    
    return accessToken;
}

- (BOOL)saveRefreshToken:(MSALRefreshTokenCacheItem *)rtItem
                 context:(nullable id<MSALRequestContext>)ctx
      telemetryRequestId:(NSString *)telemetryRequestId
                   error:(NSError * __autoreleasing *)error
{
    [[MSALTelemetry sharedInstance] startEvent:telemetryRequestId eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_WRITE];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_WRITE
                                                                         requestId:telemetryRequestId
                                                                     correlationId:nil];
    [event setTokenType:MSAL_TELEMETRY_VALUE_REFRESH_TOKEN];

    BOOL result = [_dataSource addOrUpdateRefreshTokenItem:rtItem context:ctx error:error];
    
    [event setStatus:result ? MSAL_TELEMETRY_VALUE_SUCCEEDED : MSAL_TELEMETRY_VALUE_FAILED];
    [[MSALTelemetry sharedInstance] stopEvent:telemetryRequestId event:event];
    
    return result;
}

- (BOOL)saveAccessToken:(MSALAccessTokenCacheItem *)atItem
                context:(nullable id<MSALRequestContext>)ctx
     telemetryRequestId:(NSString *)telemetryRequestId
                  error:(NSError * __autoreleasing *)error
{
    [[MSALTelemetry sharedInstance] startEvent:telemetryRequestId eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_WRITE];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_WRITE
                                                                         requestId:telemetryRequestId
                                                                     correlationId:nil];
    [event setTokenType:MSAL_TELEMETRY_VALUE_ACCESS_TOKEN];
    
    BOOL result = [_dataSource addOrUpdateAccessTokenItem:atItem context:ctx error:error];
    
    [event setStatus:result ? MSAL_TELEMETRY_VALUE_SUCCEEDED : MSAL_TELEMETRY_VALUE_FAILED];
    [[MSALTelemetry sharedInstance] stopEvent:telemetryRequestId event:event];
    
    return result;
}

- (MSALAccessTokenCacheItem *)findAccessToken:(MSALRequestParameters *)requestParam
                                      context:(nullable id<MSALRequestContext>)ctx
                                        error:(NSError * __autoreleasing *)error
{
    [[MSALTelemetry sharedInstance] startEvent:[requestParam telemetryRequestId] eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                         requestId:[requestParam telemetryRequestId]
                                                                     correlationId:[requestParam correlationId]];
    [event setTokenType:MSAL_TELEMETRY_VALUE_ACCESS_TOKEN];

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
        if ([key matches:[tokenItem tokenCacheKey:nil]])
        {
            [matchedTokens addObject:tokenItem];
        }
    }
    
    if (matchedTokens.count != 1)
    {
        [event setStatus:MSAL_TELEMETRY_VALUE_NOT_FOUND];
        [[MSALTelemetry sharedInstance] stopEvent:[requestParam telemetryRequestId] event:event];

        return nil;
    }
    
    [event setIsRT:MSAL_TELEMETRY_VALUE_NO];
    [event setStatus:MSAL_TELEMETRY_VALUE_TRIED];
    [[MSALTelemetry sharedInstance] stopEvent:[requestParam telemetryRequestId] event:event];

    return matchedTokens[0];
}

- (MSALRefreshTokenCacheItem *)findRefreshToken:(MSALRequestParameters *)requestParam
                                        context:(nullable id<MSALRequestContext>)ctx
                                          error:(NSError * __autoreleasing *)error
{
    [[MSALTelemetry sharedInstance] startEvent:[requestParam telemetryRequestId] eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                         requestId:[requestParam telemetryRequestId]
                                                                     correlationId:[requestParam correlationId]];
    [event setTokenType:MSAL_TELEMETRY_VALUE_REFRESH_TOKEN];

    MSALRefreshTokenCacheKey *key = [[MSALRefreshTokenCacheKey alloc] initWithEnvironment:requestParam.unvalidatedAuthority.host
                                                                                 clientId:requestParam.clientId
                                                                           userIdentifier:requestParam.user.userIdentifier];
    MSALRefreshTokenCacheItem *item = [_dataSource getRefreshTokenItemForKey:key context:ctx error:error];
    
    [event setIsRT:MSAL_TELEMETRY_VALUE_YES];
    [event setRTStatus:item ? MSAL_TELEMETRY_VALUE_TRIED : MSAL_TELEMETRY_VALUE_NOT_FOUND];
    [[MSALTelemetry sharedInstance] stopEvent:[requestParam telemetryRequestId] event:event];

    return item;
}

- (BOOL)deleteAccessToken:(MSALAccessTokenCacheItem *)atItem
                  context:(nullable id<MSALRequestContext>)ctx
       telemetryRequestId:(NSString *)telemetryRequestId
                    error:(NSError * __autoreleasing *)error
{
    MSALAccessTokenCacheKey *key = [atItem tokenCacheKey:error];
    if (!key)
    {
        return NO;
    }
    
    [[MSALTelemetry sharedInstance] startEvent:telemetryRequestId eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_DELETE];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_DELETE
                                                                         requestId:telemetryRequestId
                                                                     correlationId:nil];
    [event setTokenType:MSAL_TELEMETRY_VALUE_ACCESS_TOKEN];
    
    BOOL result=  [_dataSource removeAccessTokenItem:atItem context:ctx error:error];
    
    [event setStatus:result ? MSAL_TELEMETRY_VALUE_SUCCEEDED : MSAL_TELEMETRY_VALUE_FAILED];
    [[MSALTelemetry sharedInstance] stopEvent:telemetryRequestId event:event];
    
    return result;
}

- (BOOL)deleteRefreshToken:(MSALRefreshTokenCacheItem *)rtItem
        telemetryRequestId:(NSString *)telemetryRequestId
                   context:(nullable id<MSALRequestContext>)ctx
                     error:(NSError * __autoreleasing *)error
{
    MSALRefreshTokenCacheKey *key = [rtItem tokenCacheKey:error];
    if (!key)
    {
        return NO;
    }
    [[MSALTelemetry sharedInstance] startEvent:telemetryRequestId eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_DELETE];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_DELETE
                                                                         requestId:telemetryRequestId
                                                                     correlationId:nil];
    [event setTokenType:MSAL_TELEMETRY_VALUE_REFRESH_TOKEN];
    
    BOOL result=  [_dataSource removeRefreshTokenItem:rtItem context:ctx error:error];
    
    [event setStatus:result ? MSAL_TELEMETRY_VALUE_SUCCEEDED : MSAL_TELEMETRY_VALUE_FAILED];
    [[MSALTelemetry sharedInstance] stopEvent:telemetryRequestId event:event];
    
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

- (MSALRefreshTokenCacheItem *)refreshTokenForUser:(MSALUser *)user
                                          clientId:(NSString *)clientId
                                           context:(id<MSALRequestContext>)ctx
                                             error:(NSError * __autoreleasing *)error
{
    MSALRefreshTokenCacheKey *key = [[MSALRefreshTokenCacheKey alloc] initWithEnvironment:user.environment
                                                                                 clientId:clientId
                                                                           userIdentifier:user.userIdentifier];
    
    return [_dataSource getRefreshTokenItemForKey:key context:ctx error:error];;
}

@end
