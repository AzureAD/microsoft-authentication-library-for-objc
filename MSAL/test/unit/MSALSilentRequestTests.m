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
    
    // TODO: Add clear cache
}

- (void)testInit
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];
    
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:@"x-msauth-com-microsoft-unittests://com.microsoft.unittests/msal"];
    parameters.clientId = @"b92e0ba5-f86e-4411-8e18-6b5f928d968a";
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    
    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO error:&error];
    
    XCTAssertNotNil(request);
    XCTAssertNil(error);
}


- (void)testAcquireTokenSilentNoUser
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];
    
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:@"x-msauth-com-microsoft-unittests://com.microsoft.unittests/msal"];
    parameters.clientId = @"b92e0ba5-f86e-4411-8e18-6b5f928d968a";
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


- (void)testAcquireTokenSilentAccessTokenFound
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];
    
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:@"x-msauth-com-microsoft-unittests://com.microsoft.unittests/msal"];
    parameters.clientId = @"b92e0ba5-f86e-4411-8e18-6b5f928d968a";
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"utid" : @"0287f963-2d72-4363-9e3a-5705c5b0f031"};
    MSALClientInfo *clientInfo = [[MSALClientInfo alloc] initWithJson:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.host];
    parameters.tokenCache = [[MSALTokenCacheAccessor alloc] initWithDataSource:[MSALTestTokenCache new]];

    //store an access token in cache
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msalBase64EncodeData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msalBase64EncodeData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];
    MSALAccessTokenCacheItem *at = [[MSALAccessTokenCacheItem alloc] initWithJson:@{
                                                                                   @"authority" : @"https://login.microsoftonline.com/common",
                                                                                   @"scope": @"fakescope1 fakescope2",
                                                                                   @"client_id": @"b92e0ba5-f86e-4411-8e18-6b5f928d968a",
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

- (void)testAcquireTokenSilentSuccess
{
    NSError *error = nil;
    NSUUID *correlationId = [NSUUID new];
    
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSALTestURLSession createMockSession];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:@"x-msauth-com-microsoft-unittests://com.microsoft.unittests/msal"];
    parameters.clientId = @"b92e0ba5-f86e-4411-8e18-6b5f928d968a";
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97"};
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims error:nil];
    NSDictionary* clientInfoClaims = @{ @"uid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"utid" : @"0287f963-2d72-4363-9e3a-5705c5b0f031"};
    MSALClientInfo *clientInfo = [[MSALClientInfo alloc] initWithJson:clientInfoClaims error:nil];
    parameters.user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:parameters.unvalidatedAuthority.host];
    parameters.tokenCache = [[MSALTokenCacheAccessor alloc] initWithDataSource:[MSALTestTokenCache new]];

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:parameters forceRefresh:NO error:&error];
    
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    
    //store a refresh token in cache
    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msalBase64EncodeData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msalBase64EncodeData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];
    MSALRefreshTokenCacheItem *rt = [[MSALRefreshTokenCacheItem alloc] initWithJson:@{
                                                                                      @"environment" : @"login.microsoftonline.com",
                                                                                      @"client_id": @"b92e0ba5-f86e-4411-8e18-6b5f928d968a",
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
                        requestParamsBody:@{ @"client_id" : @"b92e0ba5-f86e-4411-8e18-6b5f928d968a",
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
                                             @"id_token_expires_in" : @"1200"}];
    [MSALTestURLSession addResponse:response];
    
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

@end
