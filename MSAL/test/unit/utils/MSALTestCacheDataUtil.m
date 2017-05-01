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

#import "MSALTestCacheDataUtil.h"

#import "MSALIdToken.h"
#import "MSALClientInfo.h"
#import "MSALTokenCache.h"

#import "MSALTestConstants.h"
#import "MSALTestIdTokenUtil.h"
#import "MSALTestTokenCache.h"

#import "NSDictionary+MSALTestUtil.h"
#import "NSOrderedSet+MSALExtensions.h"

@implementation MSALTestCacheDataUtil
{
    MSALTokenCache *_cache;
}

+ (instancetype)defaultUtil
{
    static MSALTestCacheDataUtil *s_util = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        s_util = [MSALTestCacheDataUtil new];
        s_util->_cache = [MSALTestTokenCache createTestAccessor];
    });
    
    return s_util;
}

+ (NSString *)defaultClientId
{
    return UNIT_TEST_CLIENT_ID;
}

- (void)reset
{
    _cache = [MSALTestTokenCache createTestAccessor];
}

- (MSALUser *)addUserWithDisplayId:(NSString *)displayId
{
    return [self addUserWithDisplayId:displayId uid:nil utid:nil];
}

- (MSALUser *)addUserWithDisplayId:(NSString *)displayId
                               uid:(NSString *)uid
                              utid:(NSString *)utid
{
    uid = uid ? uid : @"1";
    utid = utid ? utid : @"1234-5678-90abcdefg";
    
    NSString *idTokenString = [MSALTestIdTokenUtil idTokenWithName:@"User" preferredUsername:displayId];
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithRawIdToken:idTokenString];
    NSString *clientInfo = [@{ @"uid" : uid, @"utid" : utid } base64UrlJson];
    NSString *environment = @"login.microsoftonline.com";
    
    
    NSDictionary *rtJson =
    @{ @"refresh_token" : @"i am a refresh token!",
       @"environment" : environment,
       @"displayable_id" : displayId,
       @"name" : idToken.name,
       @"identity_provider" : idToken.issuer,
       @"client_id" : [MSALTestCacheDataUtil defaultClientId],
       @"client_info" : clientInfo
       };
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithJson:rtJson error:nil];
    if (!rtItem)
    {
        return nil;
    }
    
    if (![_cache.dataSource addOrUpdateRefreshTokenItem:rtItem context:nil error:nil])
    {
        return nil;
    }

    return rtItem.user;
}

- (MSALAccessTokenCacheItem *)addATforScopes:(NSArray *)scopes
                                      tenant:(NSString *)tenant
                                        user:(MSALUser *)user
{
    NSString *clientInfo = [@{ @"uid" : user.uid, @"utid" : user.utid } base64UrlJson];
    
    NSOrderedSet *scopesSet = [NSOrderedSet orderedSetWithArray:scopes];
    NSString *authority = [NSString stringWithFormat:@"https://%@/%@", user.environment, tenant];
    
    NSDictionary *atJson =
    @{ @"access_token" : @"i am a access token!",
       @"authority" : authority,
       @"displayable_id" : user.displayableId,
       @"scope" : [scopesSet msalToString],
       @"token_type" : @"Bearer",
       @"expires_on" : [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate date] timeIntervalSince1970]+600],
       @"client_id" : [MSALTestCacheDataUtil defaultClientId],
       @"client_info" : clientInfo };
    
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithJson:atJson error:nil];
    if (!atItem)
    {
        return nil;
    }
    
    if (![_cache.dataSource addOrUpdateAccessTokenItem:atItem context:nil error:nil])
    {
        return nil;
    }
    
    return atItem;
}

- (MSALTestTokenCache *)dataSource
{
    return (MSALTestTokenCache *)_cache.dataSource;
}

- (NSArray<MSALAccessTokenCacheItem *> *)allAccessTokens
{
    return [self.dataSource accessTokens];
}
- (NSArray<MSALRefreshTokenCacheItem *> *)allRefreshTokens
{
    return [self.dataSource refreshTokens];
}

@end
