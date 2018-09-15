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

#import "MSALTestCase.h"

#import "MSALBaseRequest+TestExtensions.h"
#import "MSALTestSwizzle.h"
#import "MSALSilentRequest.h"

#import "MSALIdToken.h"
#import "MSIDClientInfo.h"

#import "MSIDTestURLSession+MSAL.h"

#import "NSURL+MSIDExtensions.h"

#import "MSALTestConstants.h"
#import "MSIDDeviceId.h"
#import "MSIDTestURLSession.h"
#import "MSIDTestURLResponse.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDTestConfiguration.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDAccount.h"
#import "MSIDAccessToken.h"
#import "MSIDAADOauth2Factory.h"
#import "MSIDAADV2IdTokenClaims.h"
#import "MSALAccount+Internal.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "NSString+MSALTestUtil.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDTestURLResponse+MSAL.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDTestURLResponse+MSAL.h"
#import "MSIDAuthorityFactory.h"

@interface MSALSilentRequestTests : MSALTestCase

@property (nonatomic) MSIDClientInfo *clientInfo;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCacheAccessor;

@end

@implementation MSALSilentRequestTests

- (void)setUp
{
    [super setUp];

    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    self.clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];

    self.tokenCacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache otherCacheAccessors:nil factory:[MSIDAADV2Oauth2Factory new]];
    [self.tokenCacheAccessor clearWithContext:nil error:nil];
    
    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = @"v2.0";
}

- (void)tearDown
{
    [super tearDown];
    
    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = nil;
}

#pragma mark - Tests

- (void)testInit
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/common" authority];
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO tokenCache:self.tokenCacheAccessor expirationBuffer:300 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);
}

- (void)testAtsNoUser
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/common" authority];
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO tokenCache:self.tokenCacheAccessor expirationBuffer:300 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSString *authority = @"https://login.microsoftonline.com/common";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    [request run:^(MSALResult *result, NSError *error)
    {
        XCTAssertNil(result);
        XCTAssertNotNil(error);

        XCTAssertTrue(error.code == MSALErrorAccountRequired);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAtsATFound
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/common" authority];
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    NSDictionary* clientInfoClaims = @{ @"uid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"utid" : @"0287f963-2d72-4363-9e3a-5705c5b0f031"};

    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];
    parameters.account = [[MSALAccount alloc] initWithUsername:@"fakeuser@contoso.com" name:@"Name" homeAccountId:@"29f3807a-4fb0-42f2-a44a-236aa0cb3f97.0287f963-2d72-4363-9e3a-5705c5b0f031" localAccountId:@"29f3807a-4fb0-42f2-a44a-236aa0cb3f97" environment:parameters.unvalidatedAuthority.environment tenantId:@"0287f963-2d72-4363-9e3a-5705c5b0f031" clientInfo:clientInfo];

    //store an access token in cache
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];

    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{
                                                                                                @"access_token": @"access_token",
                                                                                                @"authority" : @"https://login.microsoftonline.com/common",
                                                                                                @"scope": @"fakescope1 fakescope2",
                                                                                                @"client_id": UNIT_TEST_CLIENT_ID,
                                                                                                @"id_token": rawIdToken,
                                                                                                @"client_info": rawClientInfo,
                                                                                                @"expires_on" : [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate dateWithTimeIntervalSinceNow:6000] timeIntervalSince1970]]
                                                                                                }
                                                                                        error:nil];

    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:parameters.msidConfiguration
                                                              response:response
                                                               context:nil
                                                                 error:nil];
    XCTAssertTrue(result);

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO tokenCache:self.tokenCacheAccessor expirationBuffer:300 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSString *authority = @"https://login.microsoftonline.com/common";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNotNil(result);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testAtsAuthorityATExpired
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/common" authority];
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];
    parameters.sliceParameters = @{ @"slice" : @"myslice" };
    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];

    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:clientInfo];

    parameters.account = account;

    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    //store at & rt in cache
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];

    MSIDAADV2TokenResponse *msidResponse =
    [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{
                                                             @"access_token": @"access_token",
                                                             @"refresh_token": @"fakeRefreshToken",
                                                             @"authority" : @"https://login.microsoftonline.com/common",
                                                             @"scope": @"fakescope1 fakescope2",
                                                             @"client_id": UNIT_TEST_CLIENT_ID,
                                                             @"id_token": rawIdToken,
                                                             @"client_info": rawClientInfo,
                                                             @"expires_on" : @"1"
                                                             }
                                                     error:nil];

    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:parameters.msidConfiguration
                                                              response:msidResponse
                                                               context:nil
                                                                 error:nil];
    XCTAssertTrue(result);

    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];

    NSString *url = @"https://login.microsoftonline.com/common/oauth2/v2.0/token?slice=myslice";
    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:url
                           requestHeaders:reqHeaders
                        requestParamsBody:@{ @"client_id" : UNIT_TEST_CLIENT_ID,
                                             @"scope" : @"fakescope1 fakescope2 openid profile offline_access",
                                             @"grant_type" : @"refresh_token",
                                             @"refresh_token" : @"fakeRefreshToken",
                                             @"client_info" : @"1"}
                        responseURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"access_token" : @"i am a access token!",
                                             @"expires_in" : @"600",
                                             @"refresh_token" : @"i am a refresh token",
                                             @"id_token_expires_in" : @"1200",
                                             @"id_token": rawIdToken,
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson],
                                             @"scope": @"fakescope1 fakescope2"
                                             }];

    [response->_requestHeaders removeObjectForKey:@"Content-Length"];

    [MSIDTestURLSession addResponse:response];

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO tokenCache:self.tokenCacheAccessor expirationBuffer:300 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSString *authority = @"https://login.microsoftonline.com/common";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNotNil(result);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testAtsAuthority_whenATExpiresIn50WithinExpirationBuffer100_shouldReAcquireToken
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];
    
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/common" authority];
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];
    parameters.sliceParameters = @{ @"slice" : @"myslice" };
    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:clientInfo];
    
    parameters.account = account;
    
    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    //store at & rt in cache
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];
    
    MSIDAADV2TokenResponse *msidResponse =
    [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{
                                                             @"access_token": @"access_token",
                                                             @"refresh_token": @"fakeRefreshToken",
                                                             @"authority" : @"https://login.microsoftonline.com/common",
                                                             @"scope": @"fakescope1 fakescope2",
                                                             @"client_id": UNIT_TEST_CLIENT_ID,
                                                             @"id_token": rawIdToken,
                                                             @"client_info": rawClientInfo,
                                                             @"expires_on" : [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate dateWithTimeIntervalSinceNow:50] timeIntervalSince1970]]
                                                             }
                                                     error:nil];
    
    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:parameters.msidConfiguration
                                                              response:msidResponse
                                                               context:nil
                                                                 error:nil];
    XCTAssertTrue(result);
    
    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];
    
    NSString *url = @"https://login.microsoftonline.com/common/oauth2/v2.0/token?slice=myslice";
    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:url
                           requestHeaders:reqHeaders
                        requestParamsBody:@{ @"client_id" : UNIT_TEST_CLIENT_ID,
                                             @"scope" : @"fakescope1 fakescope2 openid profile offline_access",
                                             @"grant_type" : @"refresh_token",
                                             @"refresh_token" : @"fakeRefreshToken",
                                             @"client_info" : @"1"}
                        responseURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"access_token" : @"i am a access token!",
                                             @"expires_in" : @"600",
                                             @"refresh_token" : @"i am a refresh token",
                                             @"id_token_expires_in" : @"1200",
                                             @"id_token": rawIdToken,
                                             @"scope": @"fakescope1 fakescope2",
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson]}];
    
    [response->_requestHeaders removeObjectForKey:@"Content-Length"];
    
    [MSIDTestURLSession addResponse:response];
    
    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO tokenCache:self.tokenCacheAccessor expirationBuffer:100 error:&error];
    
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    
    NSString *authority = @"https://login.microsoftonline.com/common";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNotNil(result);
         XCTAssertNil(error);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testAtsHomeAuthorityATExpired
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/common" authority];
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];
    parameters.sliceParameters = @{ UT_SLICE_PARAMS_DICT };

    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];

    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:clientInfo];

    parameters.account = account;

    //store at & rt in cache
    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];

    MSIDAADV2TokenResponse *msidResponse =
    [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{
                                                             @"access_token": @"access_token",
                                                             @"refresh_token": @"fakeRefreshToken",
                                                             @"scope": @"fakescope1 fakescope2",
                                                             @"client_id": UNIT_TEST_CLIENT_ID,
                                                             @"id_token": rawIdToken,
                                                             @"client_info": rawClientInfo,
                                                             @"expires_on" : @"1"
                                                             }
                                                     error:nil];

    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:parameters.msidConfiguration
                                                              response:msidResponse
                                                               context:nil
                                                                 error:nil];
    XCTAssertTrue(result);

    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];

    NSString *url = @"https://login.microsoftonline.com/1234-5678-90abcdefg/oauth2/v2.0/token";
    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:url UT_SLICE_PARAMS_QUERY
                           requestHeaders:reqHeaders
                        requestParamsBody:@{ @"client_id" : UNIT_TEST_CLIENT_ID,
                                             @"scope" : @"fakescope1 fakescope2 openid profile offline_access",
                                             @"grant_type" : @"refresh_token",
                                             @"refresh_token" : @"fakeRefreshToken",
                                             @"client_info" : @"1"}
                        responseURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"access_token" : @"i am a acces token!",
                                             @"expires_in" : @"600",
                                             @"refresh_token" : @"i am a refresh token",
                                             @"id_token_expires_in" : @"1200",
                                             @"id_token": rawIdToken,
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson],
                                             @"scope": @"fakescope1 fakescope2"
                                             }];

    [response->_requestHeaders removeObjectForKey:@"Content-Length"];

    [MSIDTestURLSession addResponse:response];

    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/1234-5678-90abcdefg" authority];

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO tokenCache:self.tokenCacheAccessor expirationBuffer:300 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNotNil(result);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testAtsAuthorityATExpiredAndRTNotFound
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/common" authority];
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];

    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:clientInfo];

    parameters.account = account;

    NSDictionary *idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    //store an access token in cache
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];

    MSIDAADV2TokenResponse *msidResponse =
    [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{
                                                             @"access_token": @"access_token",
                                                             @"authority" : @"https://login.microsoftonline.com/common",
                                                             @"scope": @"fakescope1 fakescope2",
                                                             @"client_id": UNIT_TEST_CLIENT_ID,
                                                             @"id_token": rawIdToken,
                                                             @"client_info": rawClientInfo,
                                                             @"expires_on" : @"1"
                                                             }
                                                     error:nil];

    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:parameters.msidConfiguration
                                                              response:msidResponse
                                                               context:nil
                                                                 error:nil];
    XCTAssertTrue(result);

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO tokenCache:self.tokenCacheAccessor expirationBuffer:300 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSString *authority = @"https://login.microsoftonline.com/common";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testAtsAuthorityForceUpdate
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/common" authority];
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];

    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:clientInfo];

    parameters.account = account;

    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];

    //store at & rt.
    MSIDAADV2TokenResponse *msidResponse =
    [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{
                                                             @"access_token": @"access_token",
                                                             @"refresh_token": @"fakeRefreshToken",
                                                             @"authority" : @"https://login.microsoftonline.com/common",
                                                             @"scope": @"fakescope1 fakescope2",
                                                             @"client_id": UNIT_TEST_CLIENT_ID,
                                                             @"id_token": rawIdToken,
                                                             @"client_info": rawClientInfo,
                                                             @"expires_on" : @"1"
                                                             }
                                                     error:nil];

    MSIDAADOauth2Factory *factory = [MSIDAADOauth2Factory new];
    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:parameters.msidConfiguration
                                                              response:msidResponse
                                                               context:nil
                                                                 error:nil];
    XCTAssertTrue(result);

    // Delete AT.
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:msidResponse configuration:parameters.msidConfiguration];
    result = [self.tokenCacheAccessor removeToken:accessToken context:nil error:nil];
    XCTAssertTrue(result);

    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];

    NSString *url = @"https://login.microsoftonline.com/common/oauth2/v2.0/token";
    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:url
                           requestHeaders:reqHeaders
                        requestParamsBody:@{ @"client_id" : UNIT_TEST_CLIENT_ID,
                                             @"scope" : @"fakescope1 fakescope2 openid profile offline_access",
                                             @"grant_type" : @"refresh_token",
                                             @"refresh_token" : @"fakeRefreshToken",
                                             @"client_info" : @"1"}
                        responseURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"access_token" : @"i am a acces token!",
                                             @"expires_in" : @"600",
                                             @"refresh_token" : @"i am a refresh token",
                                             @"id_token_expires_in" : @"1200",
                                             @"id_token": rawIdToken,
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson],
                                             @"scope": @"fakescope1 fakescope2"
                                             }];

    [response->_requestHeaders removeObjectForKey:@"Content-Length"];

    [MSIDTestURLSession addResponse:response];

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:YES tokenCache:self.tokenCacheAccessor expirationBuffer:300 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSString *authority = @"https://login.microsoftonline.com/common";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNotNil(result);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testAtsAuthorityForceUpdateRTNotFound
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/common" authority];
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"utid" : @"0287f963-2d72-4363-9e3a-5705c5b0f031"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];

    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:clientInfo];

    parameters.account = account;

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:YES tokenCache:self.tokenCacheAccessor expirationBuffer:300 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSString *authority = @"https://login.microsoftonline.com/common";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testAtsAuthorityForceUpdateUserNotMatch
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/common" authority];
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];

    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];

    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:clientInfo];

    parameters.account = account;

    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];

    //store at & rt.
    MSIDAADV2TokenResponse *msidResponse =
    [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{
                                                             @"access_token": @"access_token",
                                                             @"refresh_token": @"fakeRefreshToken",
                                                             @"authority" : @"https://login.microsoftonline.com/common",
                                                             @"scope": @"fakescope1 fakescope2",
                                                             @"client_id": UNIT_TEST_CLIENT_ID,
                                                             @"id_token": rawIdToken,
                                                             @"client_info": rawClientInfo,
                                                             }
                                                     error:nil];

    MSIDAADOauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:parameters.msidConfiguration
                                                              response:msidResponse
                                                               context:nil
                                                                 error:nil];
    XCTAssertTrue(result);

    // Delete AT.
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:msidResponse configuration:parameters.msidConfiguration];
    result = [self.tokenCacheAccessor removeToken:accessToken context:nil error:nil];
    XCTAssertTrue(result);

    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];

    NSString *url = @"https://login.microsoftonline.com/common/oauth2/v2.0/token";
    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:url
                           requestHeaders:reqHeaders
                        requestParamsBody:@{ @"client_id" : UNIT_TEST_CLIENT_ID,
                                             @"scope" : @"fakescope1 fakescope2 openid profile offline_access",
                                             @"grant_type" : @"refresh_token",
                                             @"refresh_token" : @"fakeRefreshToken",
                                             @"client_info" : @"1"}
                        responseURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"access_token" : @"i am a acces token!",
                                             @"expires_in" : @"600",
                                             @"refresh_token" : @"i am a refresh token",
                                             @"id_token_expires_in" : @"1200",
                                             @"client_info" : [@{ @"uid" : @"2", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson],
                                             @"scope": @"fakescope1 fakescope2"
                                             }];

    [response->_requestHeaders removeObjectForKey:@"Content-Length"];

    [MSIDTestURLSession addResponse:response];

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:YES tokenCache:self.tokenCacheAccessor expirationBuffer:300 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSString *authority = @"https://login.microsoftonline.com/common";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);

         XCTAssertEqual(error.code, MSALErrorMismatchedUser);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testSilentRequest_whenForceUpdateAndNoATReturned_shouldReturnError
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/common" authority];
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];

    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];

    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:clientInfo];

    parameters.account = account;

    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];

    //store at & rt.
    MSIDAADV2TokenResponse *msidResponse =
    [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{
                                                             @"access_token": @"access_token",
                                                             @"refresh_token": @"fakeRefreshToken",
                                                             @"authority" : @"https://login.microsoftonline.com/common",
                                                             @"scope": @"fakescope1 fakescope2",
                                                             @"client_id": UNIT_TEST_CLIENT_ID,
                                                             @"id_token": rawIdToken,
                                                             @"client_info": rawClientInfo,
                                                             }
                                                     error:nil];

    MSIDAADOauth2Factory *factory = [MSIDAADOauth2Factory new];
    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:parameters.msidConfiguration
                                                              response:msidResponse
                                                               context:nil
                                                                 error:nil];
    XCTAssertTrue(result);

    // Delete AT.
    MSIDAccessToken *accessToken = [factory accessTokenFromResponse:msidResponse configuration:parameters.msidConfiguration];

    result = [self.tokenCacheAccessor removeToken:accessToken context:nil error:nil];
    XCTAssertTrue(result);

    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];

    NSString *url = @"https://login.microsoftonline.com/common/oauth2/v2.0/token";
    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:url
                           requestHeaders:reqHeaders
                        requestParamsBody:@{ @"client_id" : UNIT_TEST_CLIENT_ID,
                                             @"scope" : @"fakescope1 fakescope2 openid profile offline_access",
                                             @"grant_type" : @"refresh_token",
                                             @"refresh_token" : @"fakeRefreshToken",
                                             @"client_info" : @"1"}
                        responseURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"refresh_token" : @"i am a refresh token",
                                             @"id_token_expires_in" : @"1200",
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson]
                                             }];

    [response->_requestHeaders removeObjectForKey:@"Content-Length"];

    [MSIDTestURLSession addResponse:response];

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:YES tokenCache:self.tokenCacheAccessor expirationBuffer:300 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    NSString *authority = @"https://login.microsoftonline.com/common";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);

         XCTAssertEqual(error.code, MSALErrorInternal);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testSilentRequest_whenResiliencyErrorReturned_shouldRetryRequestOnceAndSucceed
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];

    MSIDAuthorityFactory *factory = [MSIDAuthorityFactory new];
    MSIDAuthority *authority = [factory authorityFromUrl:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];
    parameters.unvalidatedAuthority = authority;
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];
    parameters.sliceParameters = @{ @"slice" : @"myslice" };
    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];

    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:clientInfo];

    parameters.account = account;

    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    //store at & rt in cache
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];

    MSIDAADV2TokenResponse *msidResponse =
    [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{
                                                             @"access_token": @"access_token",
                                                             @"refresh_token": @"fakeRefreshToken",
                                                             @"authority" : @"https://login.microsoftonline.com/common",
                                                             @"scope": @"fakescope1 fakescope2",
                                                             @"client_id": UNIT_TEST_CLIENT_ID,
                                                             @"id_token": rawIdToken,
                                                             @"client_info": rawClientInfo,
                                                             @"expires_on" : @"1"
                                                             }
                                                     error:nil];

    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:parameters.msidConfiguration
                                                              response:msidResponse
                                                               context:nil
                                                                 error:nil];
    XCTAssertTrue(result);

    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];

    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];

    // Create failing response first
    NSString *url = @"https://login.microsoftonline.com/common/oauth2/v2.0/token?slice=myslice";
    MSIDTestURLResponse *failingResponse =
    [MSIDTestURLResponse requestURLString:url
                           requestHeaders:reqHeaders
                        requestParamsBody:@{ @"client_id" : UNIT_TEST_CLIENT_ID,
                                             @"scope" : @"fakescope1 fakescope2 openid profile offline_access",
                                             @"grant_type" : @"refresh_token",
                                             @"refresh_token" : @"fakeRefreshToken",
                                             @"client_info" : @"1"}
                        responseURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
                             responseCode:500
                         httpHeaderFields:nil
                         dictionaryAsJSON:nil];

    [failingResponse->_requestHeaders removeObjectForKey:@"Content-Length"];
    [MSIDTestURLSession addResponse:failingResponse];

    // Now create successful response
    MSIDTestURLResponse *successfulResponse =
    [MSIDTestURLResponse requestURLString:url
                           requestHeaders:reqHeaders
                        requestParamsBody:@{ @"client_id" : UNIT_TEST_CLIENT_ID,
                                             @"scope" : @"fakescope1 fakescope2 openid profile offline_access",
                                             @"grant_type" : @"refresh_token",
                                             @"refresh_token" : @"fakeRefreshToken",
                                             @"client_info" : @"1"}
                        responseURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{@"access_token": @"I am an updated access token",
                                            @"refresh_token" : @"i am a refresh token",
                                            @"id_token_expires_in" : @"1200",
                                            @"id_token": @"I'm an id token",
                                            @"scope": @"fakescope1 fakescope2",
                                            @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson]
                                            }];

    [successfulResponse->_requestHeaders removeObjectForKey:@"Content-Length"];
    [MSIDTestURLSession addResponse:successfulResponse];

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO tokenCache:self.tokenCacheAccessor expirationBuffer:300 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"I am an updated access token");
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testSilentRequest_when429ThrottledErrorReturned_shouldReturnAllHeadersAnd429ErrorCode
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    MSIDAuthorityFactory *factory = [MSIDAuthorityFactory new];
    MSIDAuthority *authority = [factory authorityFromUrl:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];
    parameters.unvalidatedAuthority = authority;
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];
    parameters.sliceParameters = @{ @"slice" : @"myslice" };
    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];

    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:clientInfo];

    parameters.account = account;

    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    //store at & rt in cache
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];

    MSIDAADV2TokenResponse *msidResponse =
    [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{
                                                             @"access_token": @"access_token",
                                                             @"refresh_token": @"fakeRefreshToken",
                                                             @"authority" : @"https://login.microsoftonline.com/common",
                                                             @"scope": @"fakescope1 fakescope2",
                                                             @"client_id": UNIT_TEST_CLIENT_ID,
                                                             @"id_token": rawIdToken,
                                                             @"client_info": rawClientInfo,
                                                             @"expires_on" : @"1"
                                                             }
                                                     error:nil];

    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:parameters.msidConfiguration
                                                              response:msidResponse
                                                               context:nil
                                                                 error:nil];
    XCTAssertTrue(result);

    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/common"];

    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:@"https://login.microsoftonline.com/common"];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];

    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];

    NSString *url = @"https://login.microsoftonline.com/common/oauth2/v2.0/token?slice=myslice";
    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:url
                           requestHeaders:reqHeaders
                        requestParamsBody:@{ @"client_id" : UNIT_TEST_CLIENT_ID,
                                             @"scope" : @"fakescope1 fakescope2 openid profile offline_access",
                                             @"grant_type" : @"refresh_token",
                                             @"refresh_token" : @"fakeRefreshToken",
                                             @"client_info" : @"1"}
                        responseURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
                             responseCode:429
                         httpHeaderFields:@{@"Retry-After": @"256",
                                            @"Other-Header-Field": @"Other header field"
                                            }
                         dictionaryAsJSON:nil]; 

    [response->_requestHeaders removeObjectForKey:@"Content-Length"];

    [MSIDTestURLSession addResponse:response];

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO tokenCache:self.tokenCacheAccessor expirationBuffer:300 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertEqualObjects(error.domain, MSALErrorDomain);
         XCTAssertEqual(error.code, MSALErrorUnhandledResponse);
         XCTAssertEqualObjects(error.userInfo[MSALHTTPHeadersKey][@"Retry-After"], @"256");
         XCTAssertEqualObjects(error.userInfo[MSALHTTPHeadersKey][@"Other-Header-Field"], @"Other header field");
         XCTAssertEqualObjects(error.userInfo[MSALHTTPResponseCodeKey], @"429");

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

@end
