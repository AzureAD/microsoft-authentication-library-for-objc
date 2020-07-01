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

@implementation MSALTestCacheTokenResponse

+(BOOL)msalStoreTokenResponseInCacheWithAuthority:(NSString *)authorityString
                               tokenCacheAccessor:(MSIDDefaultTokenCacheAccessor *)tokenCacheAccessor
                                            error:(NSError **)error
{
    //store at & rt in cache
    MSIDAADV2TokenResponse *msidResponse = [MSALTestCacheTokenResponse msalDefaultTokenResponseWithAuthority:authorityString
                                                                                                    familyId:nil];
    MSIDConfiguration *configuration = [MSALTestCacheTokenResponse msalDefaultConfigurationWithAuthority:authorityString];
    
    return [tokenCacheAccessor saveTokensWithConfiguration:configuration
                                                              response:msidResponse
                                                               factory:[MSIDAADV2Oauth2Factory new]
                                                               context:nil
                                                                 error:error];
}

+ (MSIDAADV2TokenResponse *)msalDefaultTokenResponseWithAuthority:(NSString *)authorityString
                                                         familyId:(NSString *)familyId
{
    NSDictionary* idTokenClaims = @{ @"home_oid" : @"myuid", @"preferred_username": @"fakeuser@contoso.com", @"tid": @"utid"};
    NSDictionary* clientInfoClaims = @{ @"uid" : @"myuid", @"utid" : @"utid"};
    
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];
    
    NSMutableDictionary *responseDict = [@{
                                           @"access_token": @"access_token",
                                           @"refresh_token": @"fakeRefreshToken",
                                           @"authority" : authorityString,
                                           @"scope": @"fakescope1 fakescope2",
                                           @"client_id": UNIT_TEST_CLIENT_ID,
                                           @"id_token": rawIdToken,
                                           @"client_info": rawClientInfo,
                                           @"expires_on" : @"1"
                                           } mutableCopy];
    
    if (familyId)
    {
        responseDict[@"foci"] = familyId;
    }
    
    MSIDAADV2TokenResponse *msidResponse =
    [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:responseDict
                                                     error:nil];
    
    return msidResponse;
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
