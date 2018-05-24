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

#import "MSIDTestURLResponse+MSAL.h"
#import "MSIDDeviceId.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSALTestIdTokenUtil.h"
#import "MSALTestConstants.h"

@implementation MSIDTestURLResponse (MSAL)

+ (MSIDTestURLResponse *)oidcResponseForAuthority:(NSString *)authority
{
    NSMutableDictionary *oidcReqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [oidcReqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [oidcReqHeaders setObject:[MSIDTestRequireValueSentinel new] forKey:@"client-request-id"];
    
    NSDictionary *oidcJson =
    @{ @"token_endpoint" : [NSString stringWithFormat:@"%@/v2.0/oauth/token", authority],
       @"authorization_endpoint" : [NSString stringWithFormat:@"%@/v2.0/oauth/authorize", authority],
       @"issuer" : @"issuer"
       };
    
    MSIDTestURLResponse *oidcResponse =
    [MSIDTestURLResponse requestURLString:[NSString stringWithFormat:@"%@/v2.0/.well-known/openid-configuration", authority]
                           requestHeaders:oidcReqHeaders
                        requestParamsBody:nil
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:oidcJson];
    
    return oidcResponse;
}

+ (MSIDTestURLResponse *)oidcResponseForAuthority:(NSString *)authority
                                      responseUrl:(NSString *)responseAuthority
                                            query:(NSString *)query
{
    NSMutableDictionary *oidcReqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [oidcReqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [oidcReqHeaders setObject:[MSIDTestRequireValueSentinel new] forKey:@"client-request-id"];
    
    NSDictionary *oidcJson =
    @{ @"token_endpoint" : [NSString stringWithFormat:@"%@/v2.0/oauth/token?%@", responseAuthority, query],
       @"authorization_endpoint" : [NSString stringWithFormat:@"%@/v2.0/oauth/authorize?%@", responseAuthority, query],
       @"issuer" : @"issuer"
       };
    
    MSIDTestURLResponse *oidcResponse =
    [MSIDTestURLResponse requestURLString:[NSString stringWithFormat:@"%@/v2.0/.well-known/openid-configuration", authority]
                           requestHeaders:oidcReqHeaders
                        requestParamsBody:nil
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:oidcJson];
    
    return oidcResponse;
}

+ (MSIDTestURLResponse *)rtResponseForScopes:(MSALScopes *)scopes
                                   authority:(NSString *)authority
                                    tenantId:(NSString *)tid
                                        user:(MSALAccount *)user
{
    NSMutableDictionary *tokenReqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [tokenReqHeaders setObject:@"application/json" forKey:@"Accept"];
    [tokenReqHeaders setObject:[MSIDTestRequireValueSentinel new] forKey:@"client-request-id"];
    [tokenReqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [tokenReqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    
    MSIDTestURLResponse *tokenResponse =
    [MSIDTestURLResponse requestURLString:[NSString stringWithFormat:@"%@/v2.0/oauth/token" UT_SLICE_PARAMS_QUERY, authority]
                           requestHeaders:tokenReqHeaders
                        requestParamsBody:@{ MSID_OAUTH2_CLIENT_ID : UNIT_TEST_CLIENT_ID,
                                             MSID_OAUTH2_SCOPE : [scopes msalToString],
                                             MSID_OAUTH2_REFRESH_TOKEN : @"i am a refresh token!",
                                             @"client_info" : @"1",
                                             @"grant_type" : @"refresh_token" }
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"access_token" : @"i am an updated access token!",
                                             @"expires_in" : @"600",
                                             @"refresh_token" : @"i am a refresh token",
                                             @"id_token" : [MSALTestIdTokenUtil idTokenWithName:user.name
                                                                              preferredUsername:user.displayableId
                                                                                       tenantId:tid ? tid : user.utid],
                                             @"id_token_expires_in" : @"1200",
                                             @"client_info" : [@{ @"uid" : user.uid, @"utid" : user.utid} msidBase64UrlJson] } ];
    
    [tokenResponse->_requestHeaders removeObjectForKey:@"Content-Length"];
    
    return tokenResponse;
}

+ (MSIDTestURLResponse *)authCodeResponse:(NSString *)authcode
                                authority:(NSString *)authority
                                    query:(NSString *)query
                                   scopes:(MSALScopes *)scopes
{
    return [self authCodeResponse:authcode
                        authority:authority
                            query:query
                           scopes:scopes
                       clientInfo:@{ @"uid" : @"1", @"utid" : [MSALTestIdTokenUtil defaultTenantId]}]; // Use default client info here
}

+ (MSIDTestURLResponse *)authCodeResponse:(NSString *)authcode
                                authority:(NSString *)authority
                                    query:(NSString *)query
                                   scopes:(MSALScopes *)scopes
                               clientInfo:(NSDictionary *)clientInfo
{
    NSMutableDictionary *tokenReqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [tokenReqHeaders setObject:@"application/json" forKey:@"Accept"];
    [tokenReqHeaders setObject:[MSIDTestRequireValueSentinel new] forKey:@"client-request-id"];
    [tokenReqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [tokenReqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    
    NSMutableDictionary *tokenQPs = [NSMutableDictionary new];
    [tokenQPs addEntriesFromDictionary:@{UT_SLICE_PARAMS_DICT}];
    if (query)
    {
        [tokenQPs addEntriesFromDictionary:[NSDictionary msidURLFormDecode:query]];
    }
    
    NSString *requestUrlStr = nil;
    if (tokenQPs.count > 0)
    {
        requestUrlStr = [NSString stringWithFormat:@"%@/v2.0/oauth/token?%@", authority, [tokenQPs msidURLFormEncode]];
    }
    else
    {
        requestUrlStr = [NSString stringWithFormat:@"%@/v2.0/oauth/token", authority];
    }
    
    MSIDTestURLResponse *tokenResponse =
    [MSIDTestURLResponse requestURLString:requestUrlStr
                           requestHeaders:tokenReqHeaders
                        requestParamsBody:@{ MSID_OAUTH2_CLIENT_ID : UNIT_TEST_CLIENT_ID,
                                             MSID_OAUTH2_SCOPE : [scopes msalToString],
                                             @"client_info" : @"1",
                                             @"grant_type" : @"authorization_code",
                                             @"code_verifier" : [MSIDTestRequireValueSentinel sentinel],
                                             MSID_OAUTH2_REDIRECT_URI : UNIT_TEST_DEFAULT_REDIRECT_URI,
                                             MSID_OAUTH2_CODE : authcode }
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"access_token" : @"i am an updated access token!",
                                             @"expires_in" : @"600",
                                             @"refresh_token" : @"i am a refresh token",
                                             @"id_token" : [MSALTestIdTokenUtil defaultIdToken],
                                             @"id_token_expires_in" : @"1200",
                                             @"client_info" : [clientInfo msidBase64UrlJson] } ];
    
    [tokenResponse->_requestHeaders removeObjectForKey:@"Content-Length"];
    
    return tokenResponse;
}

+ (MSIDTestURLResponse *)serverNotFoundResponseForURLString:(NSString *)requestUrlString
                                             requestHeaders:(NSDictionary *)requestHeaders
                                          requestParamsBody:(id)requestParams
{
    
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:[NSURL URLWithString:requestUrlString] respondWithError:[NSError errorWithDomain:NSURLErrorDomain
                                                                                                                                             code:NSURLErrorCannotFindHost
                                                                                                                                         userInfo:nil]];
    [response setRequestHeaders:requestHeaders];
    response->_requestParamsBody = requestParams;
    
    return response;
}

@end
