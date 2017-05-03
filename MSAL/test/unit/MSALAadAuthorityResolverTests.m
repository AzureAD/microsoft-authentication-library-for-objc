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
#import "MSALAuthority.h"
#import "MSALAadAuthorityResolver.h"
#import "MSALTestURLSession.h"
#import "MSALTestSwizzle.h"

@interface MSALAadAuthorityResolverTests : MSALTestCase

@end

@implementation MSALAadAuthorityResolverTests

// From MSALAadAuthorityResolver.m
#define AAD_INSTANCE_DISCOVERY_ENDPOINT @"https://login.microsoftonline.com/common/discovery/instance"

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDefaultOpenIdConfigurationEndpoint
{
    MSALAadAuthorityResolver *aadResolver = [MSALAadAuthorityResolver new];
    NSURL *authority = [NSURL URLWithString:@"https://www.somehost.com/sometenant.com"];
    
    // Test with authority
    NSString *endpoint = [aadResolver defaultOpenIdConfigurationEndpointForAuthority:authority];
    XCTAssertEqualObjects(endpoint, @"https://www.somehost.com/sometenant.com/v2.0/.well-known/openid-configuration");
    
    // Test with no authority
    XCTAssertNil([aadResolver defaultOpenIdConfigurationEndpointForAuthority:nil]);
}

- (void)testOpenIdConfigEndpointSucess
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    MSALRequestParameters *params = [MSALRequestParameters new];
    params.urlSession = [MSALTestURLSession createMockSession];
    
    NSString *authorityString = @"https://login.microsoftonline.in/mytenant.com";
    NSString *responseEndpoint = @"https://login.microsoftonline.in/mytenant.com/v2.0/.well-known/openid-configuration";
    NSString *authorizationEndpoint = @"https://login.microsoftonline.in/mytenant.com/oauth2/v2.0/authorize";
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    
    NSString *requestURLString = [NSString stringWithFormat:@"%@?api-version=1.0&authorization_endpoint=%@", AAD_INSTANCE_DISCOVERY_ENDPOINT, authorizationEndpoint];
    
    MSALTestURLResponse *response = [MSALTestURLResponse requestURLString:requestURLString
                                                           requestHeaders:reqHeaders
                                                        requestParamsBody:nil
                                                        responseURLString:@"https://someresponseurl.com"
                                                             responseCode:200
                                                         httpHeaderFields:nil
                                                         dictionaryAsJSON:@{@"tenant_discovery_endpoint":responseEndpoint}];
    [MSALTestURLSession addResponse:response];
    
    [[MSALAadAuthorityResolver new] openIDConfigurationEndpointForAuthority:[NSURL URLWithString:authorityString]
                                                          userPrincipalName:nil
                                                                   validate:YES
                                                                    context:params
                                                            completionBlock:^(NSString *endpoint, NSError *error)
     {
         XCTAssertEqualObjects(endpoint, responseEndpoint);
         XCTAssertNil(error);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testOpenIdConfigEndpointNoValidationNeeded
{
    NSString *authorityString = @"https://login.microsoftonline.in/mytenant.com";
    NSString *responseEndpoint = @"https://login.microsoftonline.in/mytenant.com/v2.0/.well-known/openid-configuration";
    
    // Swizzle defaultOpenId...
    [MSALTestSwizzle instanceMethod:@selector(defaultOpenIdConfigurationEndpointForAuthority:)
                              class:[MSALAadAuthorityResolver class]
                              block:(id)^(id obj, NSURL *authority)
     {
         (void)obj;
         (void)authority;
         return responseEndpoint;
     }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    [[MSALAadAuthorityResolver new] openIDConfigurationEndpointForAuthority:[NSURL URLWithString:authorityString]
                                                          userPrincipalName:nil
                                                                   validate:NO
                                                                    context:nil
                                                            completionBlock:^(NSString *endpoint, NSError *error)
     {
         XCTAssertEqualObjects(endpoint, responseEndpoint);
         XCTAssertNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testOpenIdConfigEndpointMissingFields
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    MSALRequestParameters *params = [MSALRequestParameters new];
    params.urlSession = [MSALTestURLSession createMockSession];
    
    NSString *authorityString = @"https://somehost.com/sometenant.com";
    NSString *authorizationEndpoint = @"https://somehost.com/sometenant.com/oauth2/v2.0/authorize";
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    
    NSString *requestURLString = [NSString stringWithFormat:@"%@?api-version=1.0&authorization_endpoint=%@", AAD_INSTANCE_DISCOVERY_ENDPOINT, authorizationEndpoint];
    
    MSALTestURLResponse *response = [MSALTestURLResponse requestURLString:requestURLString
                                                           requestHeaders:reqHeaders
                                                        requestParamsBody:nil
                                                        responseURLString:@"https://someresponseurl.com"
                                                             responseCode:200
                                                         httpHeaderFields:nil
                                                         dictionaryAsJSON:@{}];
    
    [MSALTestURLSession addResponse:response];
    
    [[MSALAadAuthorityResolver new] openIDConfigurationEndpointForAuthority:[NSURL URLWithString:authorityString]
                                                          userPrincipalName:nil
                                                                   validate:YES
                                                                    context:params
                                                            completionBlock:^(NSString *endpoint, NSError *error)
     {
         XCTAssertNil(endpoint);
         XCTAssertNotNil(error);
         
         [expectation fulfill];
     }];
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testOpenIdConfigEndpointErrorResponse
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    MSALRequestParameters *params = [MSALRequestParameters new];
    params.urlSession = [MSALTestURLSession createMockSession];
    
    NSString *authorizationEndpoint = @"https://somehost.com/sometenant.com/oauth2/v2.0/authorize";
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    
    NSString *requestURLString = [NSString stringWithFormat:@"%@?api-version=1.0&authorization_endpoint=%@", AAD_INSTANCE_DISCOVERY_ENDPOINT, authorizationEndpoint];
    
    MSALTestURLResponse *response = [MSALTestURLResponse request:[NSURL URLWithString:requestURLString]
                                                  requestHeaders:reqHeaders
                                               requestParamsBody:nil
                                                respondWithError:[NSError errorWithDomain:NSURLErrorDomain
                                                                                     code:NSURLErrorCannotFindHost
                                                                                 userInfo:nil]];
    
    [MSALTestURLSession addResponse:response];
    
    [[MSALAadAuthorityResolver new] openIDConfigurationEndpointForAuthority:[NSURL URLWithString:@"https://somehost.com/sometenant.com"]
                                                          userPrincipalName:nil
                                                                   validate:YES
                                                                    context:params
                                                            completionBlock:^(NSString *endpoint, NSError *error)
     {
         XCTAssertNil(endpoint);
         XCTAssertNotNil(error);
         
         XCTAssertEqual(error.code, NSURLErrorCannotFindHost);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}



@end
