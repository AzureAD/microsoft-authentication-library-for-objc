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

#import "NSDictionary+MSALTestUtil.h"

#import "MSALBaseRequest+TestExtensions.h"
#import "MSALTestAuthority.h"
#import "MSALTestSwizzle.h"
#import "MSALTestTokenCache.h"
#import "MSALSilentRequest.h"

#import "MSALIdToken.h"
#import "MSALClientInfo.h"

#import "MSALTestURLSession.h"

#import "NSURL+MSALExtensions.h"

#import "MSALTestConstants.h"

@interface MSALSilentRequestTests : MSALTestCase

@end

@implementation MSALSilentRequestTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
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
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

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
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO error:&error];
    
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
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO error:&error];
    
    XCTAssertNotNil(request);
    XCTAssertNil(error);

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    [request run:^(MSALResult *result, NSError *error)
    {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        
        XCTAssertTrue(error.code == MSALErrorInvalidParameter);
        
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
    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"utid" : @"0287f963-2d72-4363-9e3a-5705c5b0f031"};
    MSALClientInfo *clientInfo = [[MSALClientInfo alloc] initWithJson:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.msalHostWithPort];
    parameters.tokenCache = [MSALTestTokenCache createTestAccessor];

    //store an access token in cache
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msalBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msalBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];
    MSALAccessTokenCacheItem *at = [[MSALAccessTokenCacheItem alloc] initWithJson:@{
                                                                                   @"authority" : @"https://login.microsoftonline.com/common",
                                                                                   @"scope": @"fakescope1 fakescope2",
                                                                                   @"client_id": UNIT_TEST_CLIENT_ID,
                                                                                   @"id_token": rawIdToken,
                                                                                   @"client_info": rawClientInfo,
                                                                                   @"expires_on" : [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate dateWithTimeIntervalSinceNow:6000] timeIntervalSince1970]]
                                                                                   }
                                                                            error:nil];
    [parameters.tokenCache.dataSource addOrUpdateAccessTokenItem:at context:nil error:nil];
    
    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO error:&error];
    
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
    parameters.urlSession = [MSALTestURLSession createMockSession];
    parameters.sliceParameters = @{ @"slice" : @"myslice" };
    
    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSALClientInfo *clientInfo = [[MSALClientInfo alloc] initWithJson:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.msalHostWithPort];
    parameters.tokenCache = [MSALTestTokenCache createTestAccessor];
    
    //store an access token in cache
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msalBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msalBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];
    MSALAccessTokenCacheItem *at = [[MSALAccessTokenCacheItem alloc] initWithJson:@{
                                                                                    @"authority" : @"https://login.microsoftonline.com/common",
                                                                                    @"scope": @"fakescope1 fakescope2",
                                                                                    @"client_id": UNIT_TEST_CLIENT_ID,
                                                                                    @"id_token": rawIdToken,
                                                                                    @"client_info": rawClientInfo,
                                                                                    @"expires_on" : @"0"
                                                                                    }
                                                                            error:nil];
    [parameters.tokenCache.dataSource addOrUpdateAccessTokenItem:at context:nil error:nil];
    
    //store a refresh token in cache
    MSALRefreshTokenCacheItem *rt = [[MSALRefreshTokenCacheItem alloc] initWithJson:@{
                                                                                      @"environment" : @"login.microsoftonline.com",
                                                                                      @"client_id": UNIT_TEST_CLIENT_ID,
                                                                                      @"id_token": rawIdToken,
                                                                                      @"refresh_token": @"fakeRefreshToken",
                                                                                      @"client_info": rawClientInfo,
                                                                                      @"uid" : @"1",
                                                                                      @"utid" : @"1234-5678-90abcdefg"
                                                                                      }
                                                                              error:nil];
    [parameters.tokenCache.dataSource addOrUpdateRefreshTokenItem:rt context:nil error:nil];

    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];
    
    MSALTestURLResponse *response =
    [MSALTestURLResponse requestURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token?slice=myslice"
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
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} base64UrlJson]}];
    [MSALTestURLSession addResponse:response];
    
    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO error:&error];
    
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
    parameters.urlSession = [MSALTestURLSession createMockSession];
    parameters.sliceParameters = @{ UT_SLICE_PARAMS_DICT };
    
    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSALClientInfo *clientInfo = [[MSALClientInfo alloc] initWithJson:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.msalHostWithPort];
    parameters.tokenCache = [MSALTestTokenCache createTestAccessor];
    
    //store an access token in cache
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msalBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msalBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];
    MSALAccessTokenCacheItem *at = [[MSALAccessTokenCacheItem alloc] initWithJson:@{
                                                                                    @"authority" : @"https://login.microsoftonline.com/common",
                                                                                    @"scope": @"fakescope1 fakescope2",
                                                                                    @"client_id": UNIT_TEST_CLIENT_ID,
                                                                                    @"id_token": rawIdToken,
                                                                                    @"client_info": rawClientInfo,
                                                                                    @"expires_on" : @"0"
                                                                                    }
                                                                            error:nil];
    [parameters.tokenCache.dataSource addOrUpdateAccessTokenItem:at context:nil error:nil];
    
    //store a refresh token in cache
    MSALRefreshTokenCacheItem *rt = [[MSALRefreshTokenCacheItem alloc] initWithJson:@{
                                                                                      @"environment" : @"login.microsoftonline.com",
                                                                                      @"client_id": UNIT_TEST_CLIENT_ID,
                                                                                      @"id_token": rawIdToken,
                                                                                      @"refresh_token": @"fakeRefreshToken",
                                                                                      @"client_info": rawClientInfo,
                                                                                      @"uid" : @"1",
                                                                                      @"utid" : @"1234-5678-90abcdefg"
                                                                                      }
                                                                              error:nil];
    [parameters.tokenCache.dataSource addOrUpdateRefreshTokenItem:rt context:nil error:nil];
    
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];
    
    MSALTestURLResponse *response =
    [MSALTestURLResponse requestURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token" UT_SLICE_PARAMS_QUERY
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
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} base64UrlJson]}];
    [MSALTestURLSession addResponse:response];
    
    parameters.unvalidatedAuthority = nil;
    
    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO error:&error];
    
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
    parameters.urlSession = [MSALTestURLSession createMockSession];
    
    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSALClientInfo *clientInfo = [[MSALClientInfo alloc] initWithJson:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.msalHostWithPort];
    parameters.tokenCache = [MSALTestTokenCache createTestAccessor];
    
    //store an access token in cache
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msalBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msalBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];
    MSALAccessTokenCacheItem *at = [[MSALAccessTokenCacheItem alloc] initWithJson:@{
                                                                                    @"authority" : @"https://login.microsoftonline.com/common",
                                                                                    @"scope": @"fakescope1 fakescope2",
                                                                                    @"client_id": UNIT_TEST_CLIENT_ID,
                                                                                    @"id_token": rawIdToken,
                                                                                    @"client_info": rawClientInfo,
                                                                                    @"expires_on" : @"0"
                                                                                    }
                                                                            error:nil];
    [parameters.tokenCache.dataSource addOrUpdateAccessTokenItem:at context:nil error:nil];
    
    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO error:&error];
    
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
    parameters.urlSession = [MSALTestURLSession createMockSession];
    
    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSALClientInfo *clientInfo = [[MSALClientInfo alloc] initWithJson:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.msalHostWithPort];
    parameters.tokenCache = [MSALTestTokenCache createTestAccessor];
    
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msalBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msalBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];
    
    //store a refresh token in cache
    MSALRefreshTokenCacheItem *rt = [[MSALRefreshTokenCacheItem alloc] initWithJson:@{
                                                                                      @"environment" : @"login.microsoftonline.com",
                                                                                      @"client_id": UNIT_TEST_CLIENT_ID,
                                                                                      @"id_token": rawIdToken,
                                                                                      @"refresh_token": @"fakeRefreshToken",
                                                                                      @"client_info": rawClientInfo,
                                                                                      @"uid" : @"1",
                                                                                      @"utid" : @"1234-5678-90abcdefg"
                                                                                      }
                                                                              error:nil];
    [parameters.tokenCache.dataSource addOrUpdateRefreshTokenItem:rt context:nil error:nil];
    
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];
    
    MSALTestURLResponse *response =
    [MSALTestURLResponse requestURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
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
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} base64UrlJson]
                                             }];
    [MSALTestURLSession addResponse:response];
    
    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:YES error:&error];
    
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
    parameters.urlSession = [MSALTestURLSession createMockSession];
    
    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"utid" : @"0287f963-2d72-4363-9e3a-5705c5b0f031"};
    MSALClientInfo *clientInfo = [[MSALClientInfo alloc] initWithJson:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.msalHostWithPort];
    parameters.tokenCache = [MSALTestTokenCache createTestAccessor];
    
    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:YES error:&error];
    
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
    parameters.urlSession = [MSALTestURLSession createMockSession];
    
    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"utid" : @"0287f963-2d72-4363-9e3a-5705c5b0f031"};
    MSALClientInfo *clientInfo = [[MSALClientInfo alloc] initWithJson:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.msalHostWithPort];
    parameters.tokenCache = [MSALTestTokenCache createTestAccessor];
    
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msalBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msalBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];
    
    //store a refresh token in cache
    MSALRefreshTokenCacheItem *rt = [[MSALRefreshTokenCacheItem alloc] initWithJson:@{
                                                                                      @"environment" : @"login.microsoftonline.com",
                                                                                      @"client_id": UNIT_TEST_CLIENT_ID,
                                                                                      @"id_token": rawIdToken,
                                                                                      @"refresh_token": @"fakeRefreshToken",
                                                                                      @"client_info": rawClientInfo,
                                                                                      @"uid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97",
                                                                                      @"utid" : @"0287f963-2d72-4363-9e3a-5705c5b0f031"
                                                                                      }
                                                                              error:nil];
    [parameters.tokenCache.dataSource addOrUpdateRefreshTokenItem:rt context:nil error:nil];
    
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];
    
    MSALTestURLResponse *response =
    [MSALTestURLResponse requestURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
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
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} base64UrlJson]
                                             }];
    [MSALTestURLSession addResponse:response];
    
    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:YES error:&error];
    
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
    parameters.urlSession = [MSALTestURLSession createMockSession];
    
    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"};
    MSALClientInfo *clientInfo = [[MSALClientInfo alloc] initWithJson:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.msalHostWithPort];
    parameters.tokenCache = [MSALTestTokenCache createTestAccessor];
    
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msalBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msalBase64UrlEncodeData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];
    
    //store a refresh token in cache
    MSALRefreshTokenCacheItem *rt = [[MSALRefreshTokenCacheItem alloc] initWithJson:@{
                                                                                      @"environment" : @"login.microsoftonline.com",
                                                                                      @"client_id": UNIT_TEST_CLIENT_ID,
                                                                                      @"id_token": rawIdToken,
                                                                                      @"refresh_token": @"fakeRefreshToken",
                                                                                      @"client_info": rawClientInfo,
                                                                                      @"uid" : @"1",
                                                                                      @"utid" : @"1234-5678-90abcdefg"
                                                                                      }
                                                                              error:nil];
    [parameters.tokenCache.dataSource addOrUpdateRefreshTokenItem:rt context:nil error:nil];
    
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];
    
    MSALTestURLResponse *response =
    [MSALTestURLResponse requestURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
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
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} base64UrlJson]
                                             }];
    [MSALTestURLSession addResponse:response];
    
    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:YES error:&error];
    
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
