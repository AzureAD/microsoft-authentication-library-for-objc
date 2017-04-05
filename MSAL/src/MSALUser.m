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

#import "MSALUser.h"
#import "MSALIdToken.h"
#import "MSALClientInfo.h"

@implementation MSALUser

- (id)initWithIdToken:(MSALIdToken *)idToken
           clientInfo:(MSALClientInfo *)clientInfo
{
    NSString *uid;
    NSString *utid;
    if (clientInfo)
    {
        uid = clientInfo.uniqueIdentifier;
        utid = clientInfo.uniqueTenantIdentifier;
    }
    else
    {
        uid = idToken.uniqueId;
        utid = idToken.tenantId;
    }
    
    return [self initWithDisplayableId:idToken.preferredUsername
                                  name:idToken.name
                      identityProvider:idToken.issuer
                                   uid:uid
                                  utid:utid];
}

- (id)initWithDisplayableId:(NSString *)displayableId
                       name:(NSString *)name
           identityProvider:(NSString *)identityProvider
                        uid:(NSString *)uid
                       utid:(NSString *)utid
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _displayableId = displayableId;
    _name = name;
    _identityProvider = identityProvider;
    _uid = uid;
    _utid = utid;
    
    return self;
}

- (NSString *)userIdentifier
{
    return [NSString stringWithFormat:@"%@.%@", [self.uid msalBase64UrlEncode], [self.utid msalBase64UrlEncode]];
}

- (void)signOut
{
    // TODO
}

- (id)copyWithZone:(NSZone*) zone
{
    MSALUser* user = [[MSALUser allocWithZone:zone] init];

    user->_displayableId = [_displayableId copyWithZone:zone];
    user->_name = [_name copyWithZone:zone];
    user->_identityProvider = [_identityProvider copyWithZone:zone];
    user->_uid = [_uid copyWithZone:zone];
    user->_utid = [_utid copyWithZone:zone];
    
    return user;
}

@end
