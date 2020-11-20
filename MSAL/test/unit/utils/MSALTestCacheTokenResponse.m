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
#import "MSALTestCacheTokenResponse.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDConfiguration.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSALTestConstants.h"
#import "MSIDTestTokenResponse.h"

@implementation MSALTestCacheTokenResponse

+ (BOOL)msalStoreTokenResponseInCacheWithAuthority:(NSString *)authorityString
                                               uid:(NSString *)uid
                                              utid:(NSString *)utid
                               tokenCacheAccessor:(MSIDDefaultTokenCacheAccessor *)tokenCacheAccessor
                                            error:(NSError **)error
{
    //store at & rt in cache
    MSIDAADV2TokenResponse *msidResponse = [MSALTestCacheTokenResponse msalDefaultTokenResponseWithFamilyId:nil uid:uid utid:utid];
    MSIDConfiguration *configuration = [MSALTestCacheTokenResponse msalDefaultConfigurationWithAuthority:authorityString];
    
    return [tokenCacheAccessor saveTokensWithConfiguration:configuration
                                                  response:msidResponse
                                                   factory:[MSIDAADV2Oauth2Factory new]
                                                   context:nil
                                                     error:error];
}

+ (MSIDAADV2TokenResponse *)msalDefaultTokenResponseWithFamilyId:(NSString *)familyId
{
    return [self msalDefaultTokenResponseWithFamilyId:familyId uid:@"myuid" utid:@"utid"];
}

+ (MSIDAADV2TokenResponse *)msalDefaultTokenResponseWithFamilyId:(NSString *)familyId uid:(NSString *)uid utid:(NSString *)utid
{
    NSDictionary *idTokenClaims = @{ @"home_oid" : @"myuid", @"preferred_username": @"fakeuser@contoso.com", @"tid": @"utid"};
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    
    return [MSIDTestTokenResponse v2TokenResponseWithAT:@"access_token"
                                                     RT:@"fakeRefreshToken"
                                                 scopes:[[NSOrderedSet alloc] initWithArray:@[@"fakescope1 fakescope2"]]
                                                idToken:rawIdToken
                                                    uid:uid
                                                   utid:utid
                                               familyId:familyId];
}

+ (MSIDConfiguration *)msalDefaultConfigurationWithAuthority:(NSString *)authorityString
{
    MSIDAuthority *authority = [authorityString aadAuthority];
    
    return [[MSIDConfiguration alloc] initWithAuthority:authority
                                            redirectUri:UNIT_TEST_DEFAULT_REDIRECT_URI
                                               clientId:UNIT_TEST_CLIENT_ID
                                                 target:@"fakescope1 fakescope2"];
}

@end
