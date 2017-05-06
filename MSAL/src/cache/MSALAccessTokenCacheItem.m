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

#import <Foundation/Foundation.h>
#import "MSALAccessTokenCacheItem.h"
#import "MSALAccessTokenCacheKey.h"
#import "MSALTokenResponse.h"
#import "MSALJsonObject.h"
#import "MSALIdToken.h"
#import "MSALClientInfo.h"
#import "NSURL+MSALExtensions.h"
#import "MSALAuthority.h"

static uint64_t s_expirationBuffer = 300; //in seconds, ensures catching of clock differences between the server and the device

@implementation MSALAccessTokenCacheItem
{
    MSALIdToken *_idToken;
}

MSAL_JSON_RW(OAUTH2_AUTHORITY, authority, setAuthority)
MSAL_JSON_RW(OAUTH2_ID_TOKEN, rawIdToken, setRawIdToken)
MSAL_JSON_RW(OAUTH2_TOKEN_TYPE, tokenType, setTokenType)
MSAL_JSON_RW(OAUTH2_ACCESS_TOKEN, accessToken, setAccessToken)
MSAL_JSON_RW(OAUTH2_SCOPE, scopeString, setScopeString)
MSAL_JSON_RW(@"expires_on", expiresOnString, setExpiresOnString)
MSAL_JSON_RW(@"unique_id", uniqueId, setUniqueId)

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
    
    //store needed data to _json
    _idToken = [[MSALIdToken alloc] initWithRawIdToken:response.idToken];
    self.authority = [[MSALAuthority cacheUrlForAuthority:authority tenantId:_idToken.tenantId] absoluteString];
    self.rawIdToken = response.idToken;
    self.uniqueId = [_idToken uniqueId];
    self.accessToken = response.accessToken;
    self.tokenType = response.tokenType;
    self.expiresOnString = [NSString stringWithFormat:@"%qu", (uint64_t)[response.expiresOn timeIntervalSince1970]];
    self.scopeString = response.scope;
    
    //init data derived from _json
    [self initDerivedPropertiesFromJson];
    
    return self;
}

//init method for deserialization
- (id)initWithJson:(NSDictionary *)json
             error:(NSError * __autoreleasing *)error
{
    if (!(self = [super initWithJson:json error:error]))
    {
        return nil;
    }
    
    [self initDerivedPropertiesFromJson];
    
    return self;
}

- (id)initWithData:(NSData *)data
             error:(NSError * __autoreleasing *)error
{
    if (!(self = [super initWithData:data error:error]))
    {
        return nil;
    }
    
    [self initDerivedPropertiesFromJson];
    
    return self;
}

- (void)initDerivedPropertiesFromJson
{
    _expiresOn = [NSDate dateWithTimeIntervalSince1970:[self.expiresOnString doubleValue]];
    _scope = [self scopeFromString:self.scopeString];
    _idToken = [[MSALIdToken alloc] initWithRawIdToken:self.rawIdToken];
    _user = [[MSALUser alloc] initWithIdToken:_idToken
                                   clientInfo:self.clientInfo
                                  environment:self.authority ? [NSURL URLWithString:self.authority].msalHostWithPort : nil];
    _tenantId = _idToken.tenantId;
}

- (BOOL)isExpired
{
    return [self.expiresOn compare:[NSDate dateWithTimeIntervalSinceNow:s_expirationBuffer]] == NSOrderedAscending;
}

- (MSALAccessTokenCacheKey *)tokenCacheKey:(NSError * __autoreleasing *)error
{
    MSALAccessTokenCacheKey *key = [[MSALAccessTokenCacheKey alloc] initWithAuthority:self.authority
                                                                             clientId:self.clientId
                                                                                scope:self.scope
                                                                       userIdentifier:self.user.userIdentifier
                                                                          environment:self.environment];
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

- (NSString *)environment
{
    if (!self.authority)
    {
        return nil;
    }
    return [NSURL URLWithString:self.authority].msalHostWithPort;
}

- (id)copyWithZone:(NSZone*) zone
{
    MSALAccessTokenCacheItem *item = [[MSALAccessTokenCacheItem allocWithZone:zone] initWithJson:[_json copyWithZone:zone] error:nil];
    
    return item;
}

@end
