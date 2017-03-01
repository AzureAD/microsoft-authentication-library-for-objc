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

#import "MSALAccessTokenCacheItem.h"
#import "MSALTokenCacheKey.h"
#import "MSALTokenResponse.h"
#import "MSALJsonObject.h"

@implementation MSALAccessTokenCacheItem

MSAL_JSON_RW(OAUTH2_TOKEN_TYPE, tokenType, setTokenType)
MSAL_JSON_RW(OAUTH2_ACCESS_TOKEN, accessToken, setAccessToken)
MSAL_JSON_RW(@"msalscope", scope, setScope)
MSAL_JSON_RW(@"expires_on", expiresOn, setExpiresOn)

- (id)initWithAuthority:(NSString *)authority
               clientId:(NSString *)clientId
               response:(MSALTokenResponse *)response
{
    if (!response.accessToken)
    {
        return nil;
    }
    
    if (!(self = [super initWithAuthority:authority clientId:clientId response:response]))
    {
        return nil;
    }
    
    self.accessToken = response.accessToken;
    self.tokenType = response.tokenType;
    self.expiresOn = response.expiresOn;
    self.scope = [self scopeFromString:response.scope];
    
    return self;
}

- (BOOL)isExpired
{
    return [self.expiresOn timeIntervalSinceNow] > 0;
}

- (MSALTokenCacheKey *)tokenCacheKey
{
    return [[MSALTokenCacheKey alloc] initWithAuthority:self.authority
                                               clientId:self.clientId
                                                  scope:self.scope
                                                   user:self.user];
}

- (MSALScopes *)scopeFromString:(NSString *)scopeString
{
    NSMutableOrderedSet<NSString *> *scope = [NSMutableOrderedSet<NSString *> new];
    NSArray* parts = [scopeString componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
    for (NSString *part in parts)
    {
        if (![NSString msalIsStringNilOrBlank:part])
        {
            [scope addObject:part.msalTrimmedString];
        }
    }
    return scope;
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
