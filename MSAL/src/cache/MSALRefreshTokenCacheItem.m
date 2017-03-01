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

#import "MSALRefreshTokenCacheItem.h"
#import "MSALTokenCacheKey.h"
#import "MSALTokenResponse.h"

@implementation MSALRefreshTokenCacheItem

MSAL_JSON_RW(@"refresh_token", refreshToken, setRefreshToken)

- (id)initWithAuthority:(NSString *)authority
               clientId:(NSString *)clientId
               response:(MSALTokenResponse *)response
{
    if (!response.refreshToken)
    {
        return nil;
    }
    
    if (!(self = [super initWithAuthority:authority clientId:clientId response:response]))
    {
        return nil;
    }
    
    self.refreshToken = response.refreshToken;
    
    return self;
}

- (MSALTokenCacheKey *)tokenCacheKey
{
    return [[MSALTokenCacheKey alloc] initWithAuthority:nil
                                               clientId:self.clientId
                                                  scope:nil
                                               uniqueId:nil
                                          displayableId:nil
                                           homeObjectId:self.user.homeObjectId];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

//Serializer
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_json forKey:@"json"];
}

//Deserializer
- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _json = [aDecoder decodeObjectOfClass:[NSMutableDictionary class] forKey:@"json"];
    
    return self;
}

@end
