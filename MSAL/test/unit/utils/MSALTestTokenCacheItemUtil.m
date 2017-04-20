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

@implementation MSALAccessTokenCacheItem (TestExtensions)

- (BOOL)isEqual:(id)object
{
    if (!object)
    {
        return NO;
    }
    
    if (![object isKindOfClass:[MSALAccessTokenCacheItem class]])
    {
        return NO;
    }
    
    MSALAccessTokenCacheItem* item = (MSALAccessTokenCacheItem*)object;
    
    RETURN_NO_ON_OBJECT_UNEQUAL(self.jsonDictionary, item.jsonDictionary);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.authority, item.authority);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.rawIdToken, item.rawIdToken);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.tokenType, item.tokenType);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.accessToken, item.accessToken);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.expiresOn.description, item.expiresOn.description);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.scope.msalToString, item.scope.msalToString);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.user.displayableId, item.user.displayableId);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.user.name, item.user.name);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.user.identityProvider, item.user.identityProvider);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.user.uid, item.user.uid);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.user.utid, item.user.utid);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.user.environment, item.user.environment);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.user.userIdentifier, item.user.userIdentifier);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.tenantId, item.tenantId);
    RETURN_NO_ON_OBJECT_UNEQUAL([NSNumber numberWithBool:self.isExpired], [NSNumber numberWithBool:item.isExpired]);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.clientId, item.clientId);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.clientInfo.uid, item.clientInfo.uid);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.clientInfo.utid, item.clientInfo.utid);
    
    return YES;
}

- (NSUInteger)hash
{
    return [self.jsonDictionary hash];
}

@end

@implementation MSALRefreshTokenCacheItem (TestExtensions)

- (BOOL)isEqual:(id)object
{
    if (!object)
    {
        return NO;
    }
    
    if (![object isKindOfClass:[MSALRefreshTokenCacheItem class]])
    {
        return NO;
    }
    
    MSALRefreshTokenCacheItem* item = (MSALRefreshTokenCacheItem*)object;
    
    RETURN_NO_ON_OBJECT_UNEQUAL(self.jsonDictionary, item.jsonDictionary);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.environment, item.environment);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.refreshToken, item.refreshToken);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.user.displayableId, item.user.displayableId);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.user.name, item.user.name);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.user.identityProvider, item.user.identityProvider);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.user.uid, item.user.uid);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.user.utid, item.user.utid);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.user.environment, item.user.environment);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.user.userIdentifier, item.user.userIdentifier);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.clientId, item.clientId);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.clientInfo.uid, item.clientInfo.uid);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.clientInfo.utid, item.clientInfo.utid);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.displayableId, item.displayableId);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.name, item.name);
    RETURN_NO_ON_OBJECT_UNEQUAL(self.identityProvider, item.identityProvider);
    
    return YES;
}

- (NSUInteger)hash
{
    return [self.jsonDictionary hash];
}

@end
