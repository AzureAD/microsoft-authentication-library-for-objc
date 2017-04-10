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
#import "MSALTokenCacheKey.h"
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
                                                  error:(NSError * __autoreleasing *)error
{
    MSALAccessTokenCacheItem *accessToken = [[MSALAccessTokenCacheItem alloc] initWithAuthority:requestParam.unvalidatedAuthority
                                                                                       clientId:requestParam.clientId
                                                                                       response:response];
    //delete all cache entries with intersecting scopes
    //this should not happen but we have this as a safe guard against multiple matches
    NSArray<MSALAccessTokenCacheItem *> *allAccessTokens = [self allAccessTokensForUser:accessToken.user clientId:accessToken.clientId error:nil];
    NSMutableArray<MSALAccessTokenCacheItem *> *overlappingTokens = [NSMutableArray<MSALAccessTokenCacheItem *> new];
    for (MSALAccessTokenCacheItem *tokenItem in allAccessTokens)
    {
        if ([tokenItem.authority isEqualToString:accessToken.authority]
            && [tokenItem.homeObjectId isEqualToString:accessToken.user.homeObjectId]
            && [tokenItem.scope intersectsOrderedSet:accessToken.scope])
        {
            [overlappingTokens addObject:tokenItem];
        }
    }
    for (MSALAccessTokenCacheItem *itemToDelete in overlappingTokens)
    {
        [self deleteAccessToken:itemToDelete telemetryRequestId:requestParam.telemetryRequestId error:nil];
    }
    
    
    [self saveAccessToken:accessToken telemetryRequestId:requestParam.telemetryRequestId error:error];
    
    if (response.refreshToken)
    {
        MSALRefreshTokenCacheItem *refreshToken = [[MSALRefreshTokenCacheItem alloc] initWithAuthority:requestParam.unvalidatedAuthority
                                                                                              clientId:requestParam.clientId
                                                                                              response:response];
        [self saveRefreshToken:refreshToken telemetryRequestId:requestParam.telemetryRequestId error:error];
    }
    
    return accessToken;
}

- (BOOL)saveRefreshToken:(MSALRefreshTokenCacheItem *)rtItem
      telemetryRequestId:(NSString *)telemetryRequestId
                   error:(NSError * __autoreleasing *)error
{
    [[MSALTelemetry sharedInstance] startEvent:telemetryRequestId eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_WRITE];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_WRITE
                                                                         requestId:telemetryRequestId
                                                                     correlationId:nil];
    [event setTokenType:MSAL_TELEMETRY_VALUE_REFRESH_TOKEN];
    
    BOOL result = [_dataSource addOrUpdateRefreshTokenItem:rtItem correlationId:nil error:error];
    
    [event setStatus:result ? MSAL_TELEMETRY_VALUE_SUCCEEDED : MSAL_TELEMETRY_VALUE_FAILED];
    [[MSALTelemetry sharedInstance] stopEvent:telemetryRequestId event:event];
    
    return result;
}

- (BOOL)saveAccessToken:(MSALAccessTokenCacheItem *)atItem
     telemetryRequestId:(NSString *)telemetryRequestId
                  error:(NSError * __autoreleasing *)error
{
    [[MSALTelemetry sharedInstance] startEvent:telemetryRequestId eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_WRITE];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_WRITE
                                                                         requestId:telemetryRequestId
                                                                     correlationId:nil];
    [event setTokenType:MSAL_TELEMETRY_VALUE_ACCESS_TOKEN];
    
    BOOL result = [_dataSource addOrUpdateAccessTokenItem:atItem correlationId:nil error:error];
    
    [event setStatus:result ? MSAL_TELEMETRY_VALUE_SUCCEEDED : MSAL_TELEMETRY_VALUE_FAILED];
    [[MSALTelemetry sharedInstance] stopEvent:telemetryRequestId event:event];
    
    return result;
}

- (MSALAccessTokenCacheItem *)findAccessToken:(MSALRequestParameters *)requestParam
                                        error:(NSError * __autoreleasing *)error
{
    [[MSALTelemetry sharedInstance] startEvent:[requestParam telemetryRequestId] eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                         requestId:[requestParam telemetryRequestId]
                                                                     correlationId:[requestParam correlationId]];
    [event setTokenType:MSAL_TELEMETRY_VALUE_ACCESS_TOKEN];
    
    MSALTokenCacheKey *key = [[MSALTokenCacheKey alloc] initWithAuthority:requestParam.unvalidatedAuthority.absoluteString
                                                                 clientId:requestParam.clientId
                                                                    scope:requestParam.scopes
                                                                     user:requestParam.user];
    
    NSArray<MSALAccessTokenCacheItem *> *allAccessTokens = [self allAccessTokensForUser:requestParam.user clientId:requestParam.clientId error:error];
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
                                          error:(NSError * __autoreleasing *)error
{
    [[MSALTelemetry sharedInstance] startEvent:[requestParam telemetryRequestId] eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                     requestId:[requestParam telemetryRequestId]
                                                                 correlationId:[requestParam correlationId]];
    [event setTokenType:MSAL_TELEMETRY_VALUE_REFRESH_TOKEN];
    
    MSALTokenCacheKey *key = [[MSALTokenCacheKey alloc] initWithAuthority:requestParam.unvalidatedAuthority.absoluteString
                                                                 clientId:requestParam.clientId
                                                                    scope:nil
                                                             homeObjectId:requestParam.user.homeObjectId];
    
    NSArray<MSALRefreshTokenCacheItem *> *allRefreshTokens = [self allRefreshTokensForUser:requestParam.user clientId:requestParam.clientId error:error];
    NSMutableArray<MSALRefreshTokenCacheItem *> *matchedTokens = [NSMutableArray<MSALRefreshTokenCacheItem *> new];
    
    for (MSALRefreshTokenCacheItem *tokenItem in allRefreshTokens)
    {
        if ([key matches:[tokenItem tokenCacheKey:nil]])
        {
            [matchedTokens addObject:tokenItem];
        }
    }
    
    if (matchedTokens.count != 1)
    {
        [event setRTStatus:MSAL_TELEMETRY_VALUE_NOT_FOUND];
        [[MSALTelemetry sharedInstance] stopEvent:[requestParam telemetryRequestId] event:event];
        return nil;
    }
    
    [event setIsRT:MSAL_TELEMETRY_VALUE_YES];
    [event setRTStatus:MSAL_TELEMETRY_VALUE_TRIED];
    [[MSALTelemetry sharedInstance] stopEvent:[requestParam telemetryRequestId] event:event];
    
    return matchedTokens[0];
}

- (BOOL)deleteAccessToken:(MSALAccessTokenCacheItem *)atItem
       telemetryRequestId:(NSString *)telemetryRequestId
                    error:(NSError * __autoreleasing *)error
{
    MSALTokenCacheKey *key = [atItem tokenCacheKey:error];
    if (!key)
    {
        return NO;
    }
    
    [[MSALTelemetry sharedInstance] startEvent:telemetryRequestId eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_DELETE];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_DELETE
                                                                         requestId:telemetryRequestId
                                                                     correlationId:nil];
    [event setTokenType:MSAL_TELEMETRY_VALUE_ACCESS_TOKEN];
    
    BOOL result=  [_dataSource removeAccessTokenItem:atItem error:error];
    
    [event setStatus:result ? MSAL_TELEMETRY_VALUE_SUCCEEDED : MSAL_TELEMETRY_VALUE_FAILED];
    [[MSALTelemetry sharedInstance] stopEvent:telemetryRequestId event:event];
    
    return result;
}

- (BOOL)deleteRefreshToken:(MSALRefreshTokenCacheItem *)rtItem
        telemetryRequestId:(NSString *)telemetryRequestId
                     error:(NSError * __autoreleasing *)error
{
    MSALTokenCacheKey *key = [rtItem tokenCacheKey:error];
    if (!key)
    {
        return NO;
    }
    
    [[MSALTelemetry sharedInstance] startEvent:telemetryRequestId eventName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_DELETE];
    MSALTelemetryCacheEvent *event = [[MSALTelemetryCacheEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_TOKEN_CACHE_DELETE
                                                                         requestId:telemetryRequestId
                                                                     correlationId:nil];
    [event setTokenType:MSAL_TELEMETRY_VALUE_REFRESH_TOKEN];
    
    BOOL result=  [_dataSource removeRefreshTokenItem:rtItem error:error];
    
    [event setStatus:result ? MSAL_TELEMETRY_VALUE_SUCCEEDED : MSAL_TELEMETRY_VALUE_FAILED];
    [[MSALTelemetry sharedInstance] stopEvent:telemetryRequestId event:event];
    
    return result;

    
    return result;
}

- (BOOL)deleteAllTokensForUser:(MSALUser *)user
                      clientId:(NSString *)clientId
                         error:(NSError * __autoreleasing *)error
{
    if (!user)
    {
        return YES;
    }
    
    NSString *environment = [NSString stringWithFormat:@"%@://%@", user.authority.scheme, user.authority.host];
    
    return [_dataSource removeAllTokensForHomeObjectId:user.homeObjectId
                                           environment:environment
                                              clientId:clientId
                                                 error:error];
}


- (NSArray<MSALUser *> *)getUsers:(NSString *)clientId
{
    NSArray<MSALRefreshTokenCacheItem *> *allRefreshTokens = [self allRefreshTokensForUser:nil clientId:clientId error:nil];
    NSMutableDictionary<NSString *, MSALUser *> *allUsers = [NSMutableDictionary<NSString *, MSALUser *> new];
    
    for (MSALRefreshTokenCacheItem *tokenItem in allRefreshTokens)
    {
        [allUsers setValue:tokenItem.user forKey:tokenItem.homeObjectId];
    }
    return allUsers.allValues;
}

- (NSArray<MSALAccessTokenCacheItem *> *)allAccessTokensForUser:(MSALUser *)user
                                                       clientId:(NSString *)clientId
                                                          error:(NSError * __autoreleasing *)error
{
    MSALTokenCacheKey *key = [[MSALTokenCacheKey alloc] initWithAuthority:user.authority.absoluteString clientId:nil scope:nil user:user];
    NSArray *accessTokens = [_dataSource getAccessTokenItemsWithKey:key correlationId:nil error:error];
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

- (NSArray<MSALRefreshTokenCacheItem *> *)allRefreshTokensForUser:(MSALUser *)user
                                                         clientId:(NSString *)clientId
                                                            error:(NSError * __autoreleasing *)error
{
    MSALTokenCacheKey *key = nil;
    if (user)
    {
        key = [[MSALTokenCacheKey alloc] initWithAuthority:user.authority.absoluteString clientId:nil scope:nil user:user];
    }
    
    NSArray *refreshTokens = [_dataSource getRefreshTokenItemsWithKey:key correlationId:nil error:error];
    NSMutableArray *matchedRefreshTokens = [NSMutableArray new];
    
    for (MSALRefreshTokenCacheItem *token in refreshTokens)
    {
        if (!clientId || [clientId isEqualToString:token.clientId])
        {
            [matchedRefreshTokens addObject:token];
        }
    }
    
    return matchedRefreshTokens;
}

@end
