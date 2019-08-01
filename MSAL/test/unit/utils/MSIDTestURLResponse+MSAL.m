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
#import "MSIDTestIdTokenUtil.h"
#import "MSALTestConstants.h"
#import "MSALAccountId.h"
#import "MSIDConstants.h"
#import "MSIDVersion.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSALAccount.h"

@implementation MSIDTestURLResponse (MSAL)

+ (NSDictionary *)msalDefaultRequestHeaders
{
    static NSDictionary *s_msalHeaders = nil;
    static dispatch_once_t headersOnce;

    dispatch_once(&headersOnce, ^{
        NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
        headers[@"return-client-request-id"] = @"true";
        headers[@"client-request-id"] = [MSIDTestRequireValueSentinel sentinel];
        headers[@"Accept"] = @"application/json";
        headers[@"x-app-name"] = @"MSIDTestsHostApp";
        headers[@"x-app-ver"] = @"1.0";
        headers[@"x-ms-PkeyAuth"] = @"1.0";

        s_msalHeaders = [headers copy];
    });

    return s_msalHeaders;
}

+ (MSIDTestURLResponse *)oidcResponseForAuthority:(NSString *)authority
{
    NSDictionary *oidcReqHeaders = [self msalDefaultRequestHeaders];
    
    NSDictionary *oidcJson =
    @{ @"token_endpoint" : [NSString stringWithFormat:@"%@/oauth2/v2.0/token", authority],
       @"authorization_endpoint" : [NSString stringWithFormat:@"%@/oauth2/v2.0/authorize", authority],
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

+ (MSIDTestURLResponse *)discoveryResponseForAuthority:(NSString *)authority
{
    NSURL *authorityURL = [NSURL URLWithString:authority];

    NSString *requestUrl = [NSString stringWithFormat:@"https://%@/common/discovery/instance?api-version=1.1&authorization_endpoint=%@/oauth2/v2.0/authorize", authorityURL.msidHostWithPortIfNecessary, authority];

    NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:requestUrl]
                                                                  statusCode:200
                                                                 HTTPVersion:@"1.1"
                                                                headerFields:nil];

    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse request:[NSURL URLWithString:requestUrl]
                                                                  reponse:httpResponse];
    NSDictionary *headers = [self msalDefaultRequestHeaders];
    discoveryResponse->_requestHeaders = [headers mutableCopy];

    NSString *tenantDiscoveryEndpoint = [NSString stringWithFormat:@"%@/v2.0/.well-known/openid-configuration", authority];

    __auto_type responseJson = @{
                                 @"tenant_discovery_endpoint" : tenantDiscoveryEndpoint,
                                 @"metadata" : @[
                                         @{
                                             @"preferred_network" : @"login.microsoftonline.com",
                                             @"preferred_cache" : @"login.windows.net",
                                             @"aliases" : @[@"login.microsoftonline.com", @"login.windows.net"]
                                             },
                                         @{
                                             @"preferred_network": @"login.microsoftonline.de",
                                             @"preferred_cache": @"login.microsoftonline.de",
                                             @"aliases": @[@"login.microsoftonline.de"]
                                         }
                                         ]
                                 };
    [discoveryResponse setResponseJSON:responseJson];
    return discoveryResponse;
}

+ (MSIDTestURLResponse *)oidcResponseForAuthority:(NSString *)authority
                                      responseUrl:(NSString *)responseAuthority
                                            query:(NSString *)query
{
    NSDictionary *oidcReqHeaders = [self msalDefaultRequestHeaders];

    NSString *queryString = query ? [NSString stringWithFormat:@"?%@", query] : @"";

    NSDictionary *oidcJson =
    @{ @"token_endpoint" : [NSString stringWithFormat:@"%@/oauth2/v2.0/token%@", responseAuthority, queryString],
       @"authorization_endpoint" : [NSString stringWithFormat:@"%@/oauth2/v2.0/authorize%@", responseAuthority, queryString],
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

+ (MSIDTestURLResponse *)rtResponseForScopes:(NSOrderedSet<NSString *> *)scopes
                                   authority:(NSString *)authority
                                    tenantId:(NSString *)tid
                                         uid:(NSString *)uid
                                        user:(MSALAccount *)user
                                      claims:(NSString *)claims
{
    NSDictionary *tokenReqHeaders = [self msalDefaultRequestHeaders];
    
    NSMutableDictionary *requestBody = [@{ MSID_OAUTH2_CLIENT_ID : UNIT_TEST_CLIENT_ID,
                                           MSID_OAUTH2_SCOPE : [scopes msidToString],
                                           MSID_OAUTH2_REFRESH_TOKEN : @"i am a refresh token!",
                                           @"client_info" : @"1",
                                           @"grant_type" : @"refresh_token" } mutableCopy];
    if (claims) [requestBody setValue:claims forKey:@"claims"];
    
    MSIDTestURLResponse *tokenResponse =
    [MSIDTestURLResponse requestURLString:[NSString stringWithFormat:@"%@/oauth2/v2.0/token", authority]
                           requestHeaders:tokenReqHeaders
                        requestParamsBody:requestBody
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"access_token" : @"i am an updated access token!",
                                             @"expires_in" : @"600",
                                             @"refresh_token" : @"i am a refresh token",
                                             @"id_token" : [MSIDTestIdTokenUtil idTokenWithName:@"Test name"
                                                                              preferredUsername:user.username
                                                                                            oid:nil
                                                                                       tenantId:tid],
                                             @"id_token_expires_in" : @"1200",
                                             @"client_info" : [@{ @"uid" : uid, @"utid" : tid} msidBase64UrlJson],
                                             @"scope": [scopes msidToString]
                                             } ];
    
    [tokenResponse->_requestHeaders removeObjectForKey:@"Content-Length"];
    
    return tokenResponse;
}

+ (MSIDTestURLResponse *)errorRtResponseForScopes:(NSOrderedSet<NSString *> *)scopes
                                        authority:(NSString *)authority
                                         tenantId:(NSString *)tid
                                          account:(MSALAccount *)account
                                        errorCode:(NSString *)errorCode
                                 errorDescription:(NSString *)errorDescription
                                         subError:(NSString *)subError
                                           claims:(NSString *)claims
                                     refreshToken:(NSString *)refreshToken
{
    NSDictionary *tokenReqHeaders = [self msalDefaultRequestHeaders];

    NSMutableDictionary *requestBody = [@{ MSID_OAUTH2_CLIENT_ID : UNIT_TEST_CLIENT_ID,
                                           MSID_OAUTH2_SCOPE : [scopes msidToString],
                                           MSID_OAUTH2_REFRESH_TOKEN : refreshToken ? refreshToken : @"i am a refresh token!",
                                           @"client_info" : @"1",
                                           @"grant_type" : @"refresh_token" } mutableCopy];
    if (claims) [requestBody setValue:claims forKey:@"claims"];
    
    MSIDTestURLResponse *tokenResponse =
    [MSIDTestURLResponse requestURLString:[NSString stringWithFormat:@"%@/oauth2/v2.0/token", authority]
                           requestHeaders:tokenReqHeaders
                        requestParamsBody:requestBody
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:400
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"error": errorCode,
                                             @"error_description": errorDescription,
                                             @"suberror": subError
                                             } ];

    [tokenResponse->_requestHeaders removeObjectForKey:@"Content-Length"];

    return tokenResponse;
}

+ (MSIDTestURLResponse *)authCodeResponse:(NSString *)authcode
                                authority:(NSString *)authority
                                    query:(NSString *)query
                                   scopes:(NSOrderedSet<NSString *> *)scopes
                                   claims:(NSString *)claims
{
    return [self authCodeResponse:authcode
                        authority:authority
                            query:query
                           scopes:scopes
                       clientInfo:@{ @"uid" : @"1", @"utid" : [MSIDTestIdTokenUtil defaultTenantId]} // Use default client info here
                           claims:claims];
}

+ (MSIDTestURLResponse *)authCodeResponse:(NSString *)authcode
                                authority:(NSString *)authority
                                    query:(NSString *)query
                                   scopes:(NSOrderedSet<NSString *> *)scopes
                               clientInfo:(NSDictionary *)clientInfo
                                   claims:(NSString *)claims
{
    NSDictionary *tokenReqHeaders = [self msalDefaultRequestHeaders];
    
    NSMutableDictionary *tokenQPs = [NSMutableDictionary new];
    if (query)
    {
        [tokenQPs addEntriesFromDictionary:[NSDictionary msidDictionaryFromWWWFormURLEncodedString:query]];
    }
    
    NSString *requestUrlStr = nil;
    if (tokenQPs.count > 0)
    {
        requestUrlStr = [NSString stringWithFormat:@"%@/oauth2/v2.0/token?%@", authority, [tokenQPs msidWWWFormURLEncode]];
    }
    else
    {
        requestUrlStr = [NSString stringWithFormat:@"%@/oauth2/v2.0/token", authority];
    }
    
    NSMutableDictionary *requestBody = [@{ MSID_OAUTH2_CLIENT_ID : UNIT_TEST_CLIENT_ID,
                                           MSID_OAUTH2_SCOPE : [scopes msidToString],
                                           @"client_info" : @"1",
                                           @"grant_type" : @"authorization_code",
                                           @"code_verifier" : [MSIDTestRequireValueSentinel sentinel],
                                           MSID_OAUTH2_REDIRECT_URI : UNIT_TEST_DEFAULT_REDIRECT_URI,
                                           MSID_OAUTH2_CODE : authcode} mutableCopy];
    if (claims) [requestBody setValue:claims forKey:@"claims"];
    
    NSMutableDictionary *responseBody = [@{ @"access_token" : @"i am an updated access token!",
                                            @"expires_in" : @"600",
                                            @"refresh_token" : @"i am a refresh token",
                                            @"id_token" : [MSIDTestIdTokenUtil defaultV2IdToken],
                                            @"id_token_expires_in" : @"1200",
                                            @"scope": [scopes msidToString]
                                            } mutableCopy];
    if (clientInfo.msidBase64UrlJson) [responseBody setValue:clientInfo.msidBase64UrlJson forKey:@"client_info"];
    
    MSIDTestURLResponse *tokenResponse =
    [MSIDTestURLResponse requestURLString:requestUrlStr
                           requestHeaders:tokenReqHeaders
                        requestParamsBody:requestBody
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:responseBody];
    
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

+ (NSDictionary *)defaultQueryParameters
{
    return @{MSID_VERSION_KEY:MSIDVersion.sdkVersion};
}

@end
