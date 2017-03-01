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

@implementation MSALUser

- (id)initWithIdToken:(MSALIdToken *)idToken
            authority:(NSString *)authority
             clientId:(NSString *)clientId
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    if (idToken.objectId)
    {
        _uniqueId = idToken.objectId;
    }
    else
    {
        _uniqueId = idToken.subject;
    }
    
    _displayableId = idToken.preferredUsername;
    _homeObjectId = idToken.homeObjectId ? idToken.homeObjectId : _uniqueId;
    _name = idToken.name;
    _identityProvider = idToken.issuer;
    _authority = authority;
    _clientId = clientId;
    
    return self;
}

- (void)signOut
{
    // TODO
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone*) zone
{
    MSALUser* user = [[MSALUser allocWithZone:zone] init];
    
    user->_upn = [_upn copyWithZone:zone];
    user->_uniqueId = [_uniqueId copyWithZone:zone];
    user->_displayableId = [_displayableId copyWithZone:zone];
    user->_name = [_name copyWithZone:zone];
    user->_identityProvider = [_identityProvider copyWithZone:zone];
    user->_clientId = [_clientId copyWithZone:zone];
    user->_authority = [_authority copyWithZone:zone];
    user->_homeObjectId = [_homeObjectId copyWithZone:zone];
    
    return user;
}

//Serializer
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_upn forKey:@"upn"];
    [aCoder encodeObject:_uniqueId forKey:@"uniqueId"];
    [aCoder encodeObject:_displayableId forKey:@"displayableId"];
    [aCoder encodeObject:_name forKey:@"name"];
    [aCoder encodeObject:_identityProvider forKey:@"identityProvider"];
    [aCoder encodeObject:_clientId forKey:@"clientId"];
    [aCoder encodeObject:_authority forKey:@"authority"];
    [aCoder encodeObject:_homeObjectId forKey:@"homeObjectId"];
}

//Deserializer
- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _upn = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"upn"];
    _uniqueId = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"uniqueId"];
    _displayableId = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"displayableId"];
    _name = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"name"];
    _identityProvider = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"identityProvider"];
    _clientId = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"clientId"];
    _authority = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"authority"];
    _homeObjectId = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"homeObjectId"];
    
    return self;
}

@end
