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

#import "MSALTestTokenCacheItemUtil.h"
#import "MSALAccessTokenCacheItem.h"
#import "MSALRefreshTokenCacheItem.h"
#import "MSALClientInfo.h"

#define RETURN_NO_ON_OBJECT_UNEQUAL(OBJ1, OBJ2) \
{ \
    if ((OBJ1) == nil && (OBJ2) != nil) \
    { \
        return NO; \
    } \
    else if ((OBJ1) != nil && ![(OBJ1) isEqual:(OBJ2)]) \
    { \
        return NO; \
    } \
}

@implementation MSALTestTokenCacheItemUtil

+ (BOOL)areAccessTokensEqual:(MSALAccessTokenCacheItem *)tokenA
                      tokenB:(MSALAccessTokenCacheItem *)tokenB
{
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.jsonDictionary, tokenB.jsonDictionary);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.authority, tokenB.authority);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.rawIdToken, tokenB.rawIdToken);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.tokenType, tokenB.tokenType);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.accessToken, tokenB.accessToken);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.expiresOn.description, tokenB.expiresOn.description);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.scope.msalToString, tokenB.scope.msalToString);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.user.displayableId, tokenB.user.displayableId);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.user.name, tokenB.user.name);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.user.identityProvider, tokenB.user.identityProvider);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.user.uid, tokenB.user.uid);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.user.utid, tokenB.user.utid);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.user.environment, tokenB.user.environment);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.user.userIdentifier, tokenB.user.userIdentifier);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.tenantId, tokenB.tenantId);
    RETURN_NO_ON_OBJECT_UNEQUAL([NSNumber numberWithBool:tokenA.isExpired], [NSNumber numberWithBool:tokenB.isExpired]);
    RETURN_NO_ON_OBJECT_UNEQUAL([tokenA tokenCacheKey:nil].service, [tokenB tokenCacheKey:nil].service);
    RETURN_NO_ON_OBJECT_UNEQUAL([tokenA tokenCacheKey:nil].account, [tokenB tokenCacheKey:nil].account);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.clientId, tokenB.clientId);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.clientInfo.uniqueIdentifier, tokenB.clientInfo.uniqueIdentifier);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.clientInfo.uniqueTenantIdentifier, tokenB.clientInfo.uniqueTenantIdentifier);
    
    return YES;
}

+ (BOOL)areRefreshTokensEqual:(MSALRefreshTokenCacheItem *)tokenA
                       tokenB:(MSALRefreshTokenCacheItem *)tokenB
{
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.jsonDictionary, tokenB.jsonDictionary);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.environment, tokenB.environment);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.refreshToken, tokenB.refreshToken);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.user.displayableId, tokenB.user.displayableId);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.user.name, tokenB.user.name);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.user.identityProvider, tokenB.user.identityProvider);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.user.uid, tokenB.user.uid);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.user.utid, tokenB.user.utid);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.user.environment, tokenB.user.environment);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.user.userIdentifier, tokenB.user.userIdentifier);
    RETURN_NO_ON_OBJECT_UNEQUAL([tokenA tokenCacheKey:nil].service, [tokenB tokenCacheKey:nil].service);
    RETURN_NO_ON_OBJECT_UNEQUAL([tokenA tokenCacheKey:nil].account, [tokenB tokenCacheKey:nil].account);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.clientId, tokenB.clientId);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.clientInfo.uniqueIdentifier, tokenB.clientInfo.uniqueIdentifier);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.clientInfo.uniqueTenantIdentifier, tokenB.clientInfo.uniqueTenantIdentifier);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.displayableId, tokenB.displayableId);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.name, tokenB.name);
    RETURN_NO_ON_OBJECT_UNEQUAL(tokenA.identityProvider, tokenB.identityProvider);
    
    return YES;
}

@end
