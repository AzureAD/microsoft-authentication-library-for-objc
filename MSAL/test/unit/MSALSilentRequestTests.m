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
#import "MSALTestAuthority.h"
#import "MSALTestSwizzle.h"
#import "MSALTestTokenCache.h"
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
#import "MSIDSharedTokenCache.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDTestRequestParams.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDAccount.h"
#import "MSIDAccessToken.h"

@interface MSALSilentRequestTests : MSALTestCase

@property (nonatomic) MSIDClientInfo *clientInfo;
@property (nonatomic) MSIDSharedTokenCache *tokenCache;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCacheAccessor;

@end

@implementation MSALSilentRequestTests

- (void)setUp
{
    [super setUp];
    
    [MSIDKeychainTokenCache reset];
    
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    self.clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];
    
    self.tokenCacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache];
    self.tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:self.tokenCacheAccessor otherCacheAccessors:nil];
    
    [MSALTestSwizzle classMethod:@selector(resolveEndpointsForAuthority:userPrincipalName:validate:context:completionBlock:)
                           class:[MSALAuthority class]
                           block:(id)^(id obj, NSURL *unvalidatedAuthority, NSString *userPrincipalName, BOOL validate, id<MSALRequestContext> context, MSALAuthorityCompletion completionBlock)
     
     {
         (void)obj;
         (void)context;
         (void)userPrincipalName;
         (void)validate;
         
         completionBlock([MSALTestAuthority AADAuthority:unvalidatedAuthority], nil);
     }];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Tests

- (void)testInit
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];
    
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:UNIT_TEST_DEFAULT_REDIRECT_URI];
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    
    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO tokenCache:self.tokenCache error:&error];
    
    XCTAssertNotNil(request);
    XCTAssertNil(error);
}

- (void)testAtsNoUser
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:UNIT_TEST_DEFAULT_REDIRECT_URI];
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO tokenCache:self.tokenCache error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
    {
        XCTAssertNil(result);
        XCTAssertNotNil(error);

        XCTAssertTrue(error.code == MSALErrorUserRequired);

        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testAtsATFound
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:UNIT_TEST_DEFAULT_REDIRECT_URI];
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"utid" : @"0287f963-2d72-4363-9e3a-5705c5b0f031"};

    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.msidHostWithPortIfNecessary];

    //store an access token in cache
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];
    
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
    
    BOOL result = [self.tokenCache saveTokensWithRequestParams:parameters.msidParameters response:response context:nil error:nil];
    XCTAssertTrue(result);

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO tokenCache:self.tokenCache error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNotNil(result);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testAtsAuthorityATExpired
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:UNIT_TEST_DEFAULT_REDIRECT_URI];
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];
    parameters.sliceParameters = @{ @"slice" : @"myslice" };

    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.msidHostWithPortIfNecessary];

    //store at & rt in cache
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];
    
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
    
    BOOL result = [self.tokenCache saveTokensWithRequestParams:parameters.msidParameters response:msidResponse context:nil error:nil];
    XCTAssertTrue(result);

    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];

    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token?slice=myslice"
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
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson]}];

    [response->_requestHeaders removeObjectForKey:@"Content-Length"];

    [MSIDTestURLSession addResponse:response];

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO tokenCache:self.tokenCache error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNotNil(result);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testAtsNoAuthorityATExpired
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:UNIT_TEST_DEFAULT_REDIRECT_URI];
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];
    parameters.sliceParameters = @{ UT_SLICE_PARAMS_DICT };

    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.msidHostWithPortIfNecessary];

    //store at & rt in cache
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];
    
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
    
    BOOL result = [self.tokenCache saveTokensWithRequestParams:parameters.msidParameters response:msidResponse context:nil error:nil];
    XCTAssertTrue(result);

    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];

    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token" UT_SLICE_PARAMS_QUERY
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
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson]}];

    [response->_requestHeaders removeObjectForKey:@"Content-Length"];

    [MSIDTestURLSession addResponse:response];

    parameters.unvalidatedAuthority = nil;

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO tokenCache:self.tokenCache error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNotNil(result);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testAtsAuthorityATExpiredAndRTNotFound
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:UNIT_TEST_DEFAULT_REDIRECT_URI];
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];

    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.msidHostWithPortIfNecessary];

    //store an access token in cache
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];
    
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
    
    BOOL result = [self.tokenCache saveTokensWithRequestParams:parameters.msidParameters response:msidResponse context:nil error:nil];
    XCTAssertTrue(result);

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO tokenCache:self.tokenCache error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testAtsAuthorityForceUpdate
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:UNIT_TEST_DEFAULT_REDIRECT_URI];
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];

    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.msidHostWithPortIfNecessary];

    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];

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
    
    BOOL result = [self.tokenCache saveTokensWithRequestParams:parameters.msidParameters response:msidResponse context:nil error:nil];
    XCTAssertTrue(result);
    
    // Delete AT.
    MSIDAccount *account = [[MSIDAccount alloc] initWithTokenResponse:msidResponse request:parameters.msidParameters];
    MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] initWithTokenResponse:msidResponse request:parameters.msidParameters];
    result = [self.tokenCache removeToken:accessToken forAccount:account context:nil error:nil];
    XCTAssertTrue(result);

    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];

    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
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
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson]
                                             }];

    [response->_requestHeaders removeObjectForKey:@"Content-Length"];

    [MSIDTestURLSession addResponse:response];

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:YES tokenCache:self.tokenCache error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNotNil(result);
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testAtsAuthorityForceUpdateRTNotFound
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:UNIT_TEST_DEFAULT_REDIRECT_URI];
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];

    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"utid" : @"0287f963-2d72-4363-9e3a-5705c5b0f031"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.msidHostWithPortIfNecessary];

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:YES tokenCache:self.tokenCache error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testAtsAuthorityForceUpdateUserNotMatch
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:UNIT_TEST_DEFAULT_REDIRECT_URI];
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];

    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"utid" : @"0287f963-2d72-4363-9e3a-5705c5b0f031"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.msidHostWithPortIfNecessary];

    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];

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
    
    BOOL result = [self.tokenCache saveTokensWithRequestParams:parameters.msidParameters response:msidResponse context:nil error:nil];
    XCTAssertTrue(result);
    
    // Delete AT.
    MSIDAccount *account = [[MSIDAccount alloc] initWithTokenResponse:msidResponse request:parameters.msidParameters];
    MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] initWithTokenResponse:msidResponse request:parameters.msidParameters];
    result = [self.tokenCache removeToken:accessToken forAccount:account context:nil error:nil];
    XCTAssertTrue(result);

    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];

    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
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
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson]
                                             }];

    [response->_requestHeaders removeObjectForKey:@"Content-Length"];

    [MSIDTestURLSession addResponse:response];

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:YES tokenCache:self.tokenCache error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);

         XCTAssertEqual(error.code, MSALErrorMismatchedUser);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testSilentRequest_whenForceUpdateAndNoATReturned_shouldReturnError
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:UNIT_TEST_DEFAULT_REDIRECT_URI];
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.urlSession = [MSIDTestURLSession createMockSession];

    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.msidHostWithPortIfNecessary];

    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];

    ///
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
    
    BOOL result = [self.tokenCache saveTokensWithRequestParams:parameters.msidParameters response:msidResponse context:nil error:nil];
    XCTAssertTrue(result);
    
    // Delete AT.
    MSIDAccount *account = [[MSIDAccount alloc] initWithTokenResponse:msidResponse request:parameters.msidParameters];
    MSIDAccessToken *accessToken = [[MSIDAccessToken alloc] initWithTokenResponse:msidResponse request:parameters.msidParameters];
    result = [self.tokenCache removeToken:accessToken forAccount:account context:nil error:nil];
    XCTAssertTrue(result);
    ///

    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];

    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
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
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:YES tokenCache:self.tokenCache error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);

         XCTAssertEqual(error.code, MSALErrorNoAccessTokenInResponse);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

@end
