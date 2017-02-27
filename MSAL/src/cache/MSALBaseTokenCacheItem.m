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

#import "MSALBaseTokenCacheItem.h"
#import "MSALUser.h"
#import "MSAL_Internal.h"
#import "MSALTokenResponse.h"
#import "MSALIdToken.h"

@implementation MSALBaseTokenCacheItem

MSAL_JSON_RW(@"authority", authority, setAuthority)
MSAL_JSON_RW(@"client_id", clientId, setClientId)
MSAL_JSON_RW(@"tenant_id", tenantId, setTenantId)
MSAL_JSON_RW(@"id_token", rawIdToken, setRawIdToken)

- (id)initWithAuthority:(NSString *)authority
               clientId:(NSString *)clientId
               response:(MSALTokenResponse *)response
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    if (response.idToken)
    {
        self.rawIdToken = response.idToken;
        MSALIdToken *idToken = [[MSALIdToken alloc] initWithRawIdToken:response.idToken];
        self.tenantId = idToken.tenantId;
        _user = [[MSALUser alloc] initWithIdToken:idToken authority:authority clientId:clientId];
    }
    
    self.authority = authority;
    self.clientId = clientId;
    
    return self;
}

- (NSString *)uniqueId
{
    return _user.uniqueId;
}

- (NSString *)displayableId
{
    return _user.displayableId;
}

- (NSString *)homeObjectId
{
    return _user.homeObjectId;
}

- (MSALTokenCacheKey *)tokenCacheKey
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

@end
