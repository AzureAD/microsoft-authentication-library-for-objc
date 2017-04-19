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
#import "MSALRefreshTokenCacheKey.h"
#import "MSALTokenResponse.h"
#import "MSALIdToken.h"
#import "MSALClientInfo.h"

@implementation MSALRefreshTokenCacheItem

MSAL_JSON_RW(@"refresh_token", refreshToken, setRefreshToken)
MSAL_JSON_RW(@"environment", environment, setEnvironment)
MSAL_JSON_RW(@"displayable_id", displayableId, setDisplayableId)
MSAL_JSON_RW(@"name", name, setName)
MSAL_JSON_RW(@"identity_provider", identityProvider, setIdentityProvider)

- (id)initWithEnvironment:(NSString *)environment
                 clientId:(NSString *)clientId
                 response:(MSALTokenResponse *)response
{
    if (!response.refreshToken)
    {
        return nil;
    }
    
    if (!(self = [super initWithClientId:clientId response:response]))
    {
        return nil;
    }
    
    //store needed data to _json
    self.refreshToken = response.refreshToken;
    self.environment = environment;
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithRawIdToken:response.idToken];
    MSALUser *user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:self.clientInfo environment:environment];
    self.displayableId = user.displayableId;
    self.name = user.name;
    self.identityProvider = user.identityProvider;
    
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
    _user = [[MSALUser alloc] initWithDisplayableId:self.displayableId
                                               name:self.name
                                   identityProvider:self.identityProvider
                                                uid:self.clientInfo.uid
                                               utid:self.clientInfo.utid
                                        environment:self.environment];
}

- (MSALRefreshTokenCacheKey *)tokenCacheKey:(NSError * __autoreleasing *)error
{
    MSALRefreshTokenCacheKey *key = [[MSALRefreshTokenCacheKey alloc] initWithEnvironment:self.environment
                                                                                 clientId:self.clientId
                                                                           userIdentifier:self.user.userIdentifier];
    if (!key)
    {
        MSAL_ERROR_PARAM(nil, MSALErrorTokenCacheItemFailure, @"failed to create token cache key.");
    }
    return key;
}

- (id)copyWithZone:(NSZone*) zone
{
    MSALRefreshTokenCacheItem *item = [[MSALRefreshTokenCacheItem allocWithZone:zone] initWithJson:[_json copyWithZone:zone] error:nil];
    
    return item;
}

@end
