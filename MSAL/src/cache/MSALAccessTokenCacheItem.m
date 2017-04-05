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
#import "MSALAccessTokenCacheKey.h"
#import "MSALTokenResponse.h"
#import "MSALJsonObject.h"
#import "MSALIdToken.h"
#import "MSALClientInfo.h"

@implementation MSALAccessTokenCacheItem

@synthesize expiresOn = _expiresOn;
@synthesize scope = _scope;
@synthesize user = _user;

MSAL_JSON_RW(OAUTH2_AUTHORITY, authority, setAuthority)
MSAL_JSON_RW(OAUTH2_ID_TOKEN, rawIdToken, setRawIdToken)
MSAL_JSON_RW(OAUTH2_TOKEN_TYPE, tokenType, setTokenType)
MSAL_JSON_RW(OAUTH2_ACCESS_TOKEN, accessToken, setAccessToken)
MSAL_JSON_RW(OAUTH2_SCOPE, scopeString, setScopeString)
MSAL_JSON_RW(@"expires_on", expiresOnString, setExpiresOnString)

- (id)initWithAuthority:(NSURL *)authority
               clientId:(NSString *)clientId
               response:(MSALTokenResponse *)response
{
    if (!response.accessToken)
    {
        return nil;
    }
    
    if (!(self = [super initWithClientId:clientId response:response]))
    {
        return nil;
    }
    
    self.authority = authority.absoluteString;
    self.rawIdToken = response.idToken;
    self.accessToken = response.accessToken;
    self.tokenType = response.tokenType;
    self.expiresOnString = [NSString stringWithFormat:@"%d", (uint32_t)[response.expiresOn timeIntervalSince1970]];
    self.scopeString = response.scope;
    
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithRawIdToken:response.idToken];
    MSALClientInfo *clientInfo = [[MSALClientInfo alloc] initWithRawClientInfo:response.clientInfo error:nil];
    _user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo];
    
    return self;
}

- (MSALScopes *)scope
{
    if (!_scope)
    {
        _scope = [self scopeFromString:self.scopeString];
    }
    return _scope;
}

- (NSDate *)expiresOn
{
    if (!_expiresOn && self.expiresOnString)
    {
        _expiresOn = [NSDate dateWithTimeIntervalSince1970:[self.expiresOnString doubleValue]];
    }
    return _expiresOn;
}

- (BOOL)isExpired
{
    return [self.expiresOn timeIntervalSinceNow] > 0;
}

- (MSALAccessTokenCacheKey *)tokenCacheKey:(NSError * __autoreleasing *)error
{
    MSALAccessTokenCacheKey *key = [[MSALAccessTokenCacheKey alloc] initWithAuthority:self.authority
                                                                             clientId:self.clientId
                                                                                scope:self.scope
                                                                       userIdentifier:self.user.userIdentifier];
    if (!key)
    {
        MSAL_ERROR_PARAM(nil, MSALErrorTokenCacheItemFailure, @"failed to create token cache key.");
    }
    return key;
}

- (MSALScopes *)scopeFromString:(NSString *)scopeString
{
    NSMutableOrderedSet<NSString *> *scope = [NSMutableOrderedSet<NSString *> new];
    NSArray* parts = [scopeString componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
    for (NSString *part in parts)
    {
        if (![NSString msalIsStringNilOrBlank:part])
        {
            [scope addObject:part.msalTrimmedString.lowercaseString];
        }
    }
    return scope;
}

- (MSALUser *)user
{
    if (!_user)
    {
        MSALIdToken *idToken = [[MSALIdToken alloc] initWithRawIdToken:self.rawIdToken];
        _user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:self.clientInfo];
    }
    return _user;
}

- (id)copyWithZone:(NSZone*) zone
{
    MSALAccessTokenCacheItem *item = [[MSALAccessTokenCacheItem allocWithZone:zone] init];
    
    item->_json = [_json copyWithZone:zone];
    
    return item;
}

@end
