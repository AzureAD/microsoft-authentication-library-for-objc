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
#define AAD_INSTANCE_DISCOVERY_ENDPOINT @"https://login.windows.net/common/discovery/instance"

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

- (void)testValidatedAuthorityCache
{
    MSALAadAuthorityResolver *aadResolver = [MSALAadAuthorityResolver new];
    NSURL *validURL = [NSURL URLWithString:@"https://login.windows.net/common/"];
    
    // Add valid authority
    MSALAuthority *validAuthority = [MSALAuthority new];
    validAuthority.canonicalAuthority = validURL;
    XCTAssertTrue([aadResolver addToValidatedAuthorityCache:validAuthority userPrincipalName:nil]);
    
    // Add non valid authority
    XCTAssertFalse([aadResolver addToValidatedAuthorityCache:nil userPrincipalName:nil]);
    
    // Check if valid authority returned
    MSALAuthority *retrivedAuthority = [aadResolver authorityFromCache:validURL userPrincipalName:nil];
    XCTAssertNotNil(retrivedAuthority);
    XCTAssertTrue([retrivedAuthority.canonicalAuthority isEqual:validURL]);
    
    // Check if non valid authority was not returned
    XCTAssertNil([aadResolver authorityFromCache:[NSURL URLWithString:@"https://notaddedhost.com"] userPrincipalName:nil]);
}

- (void)testDefaultOpenIdConfigurationEndpoint
{
    MSALAadAuthorityResolver *aadResolver = [MSALAadAuthorityResolver new];
    
    // Test with host and tenant
    NSString *endpoint = [aadResolver defaultOpenIdConfigurationEndpointForHost:@"somehost.com" tenant:@"sometenant.com"];
    XCTAssertEqualObjects(endpoint, @"https://somehost.com/sometenant.com/v2.0/.well-known/openid-configuration");
    
    // Test with no host
    XCTAssertNil([aadResolver defaultOpenIdConfigurationEndpointForHost:nil tenant:@"sometenant.com"]);
    XCTAssertNil([aadResolver defaultOpenIdConfigurationEndpointForHost:@"" tenant:@"sometenant.com"]);
    
    // Test with no tenant
    XCTAssertNil([aadResolver defaultOpenIdConfigurationEndpointForHost:@"www.somehost.com" tenant:nil]);
    XCTAssertNil([aadResolver defaultOpenIdConfigurationEndpointForHost:@"www.somehost.com" tenant:@""]);
    
}

- (void)testOpenIdConfigEndpointSucess
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    MSALRequestParameters *params = [MSALRequestParameters new];
    params.urlSession = [NSURLSession new];
    
    NSString *responseEndpoint = @"https://someendpoint.com";
    NSString *authorityString = @"https://somehost.com/sometenant.com";
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"1.0" forKey:@"api-version"];
    [reqHeaders setObject:@"https://somehost.com/sometenant.com/oauth2/v2.0/authorize" forKey:@"authorization_endpoint"];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    
    MSALTestURLResponse *response = [MSALTestURLResponse requestURLString:AAD_INSTANCE_DISCOVERY_ENDPOINT
                                                           requestHeaders:reqHeaders
                                                        requestParamsBody:nil
                                                        responseURLString:@"https://someresponseurl.com"
                                                             responseCode:200
                                                         httpHeaderFields:nil
                                                         dictionaryAsJSON:@{@"tenant_discovery_endpoint":responseEndpoint}];
    [MSALTestURLSession addResponse:response];
    
    [[MSALAadAuthorityResolver new] openIDConfigurationEndpointForURL:[NSURL URLWithString:authorityString]
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
    NSString *responseEndpoint = @"https://someendpoint.com";
    
    // Swizzle defaultOpenId...
    [MSALTestSwizzle instanceMethod:@selector(defaultOpenIdConfigurationEndpointForHost:tenant:)
                              class:[MSALAadAuthorityResolver class]
                              block:(id)^(id obj, NSString *host, NSString *tenant)
     {
         (void)obj;
         (void)host;
         (void)tenant;
         
         return responseEndpoint;
     }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    [[MSALAadAuthorityResolver new] openIDConfigurationEndpointForURL:[NSURL URLWithString:@"https://somehost.com/sometenant.com"]
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

- (void)testOpenIdConfigEndpointInvalidResponse
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    MSALRequestParameters *params = [MSALRequestParameters new];
    params.urlSession = [NSURLSession new];
    
    NSString *authorityString = @"https://somehost.com/sometenant.com";
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"1.0" forKey:@"api-version"];
    [reqHeaders setObject:@"https://somehost.com/sometenant.com/oauth2/v2.0/authorize" forKey:@"authorization_endpoint"];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    
    MSALTestURLResponse *response = [MSALTestURLResponse requestURLString:AAD_INSTANCE_DISCOVERY_ENDPOINT
                                                           requestHeaders:reqHeaders
                                                        requestParamsBody:nil
                                                        responseURLString:@"https://someresponseurl.com"
                                                             responseCode:200
                                                         httpHeaderFields:nil
                                                         dictionaryAsJSON:@{}];
    
    [MSALTestURLSession addResponse:response];
    
    [[MSALAadAuthorityResolver new] openIDConfigurationEndpointForURL:[NSURL URLWithString:authorityString]
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
    params.urlSession = [NSURLSession new];
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"1.0" forKey:@"api-version"];
    [reqHeaders setObject:@"https://somehost.com/sometenant.com/oauth2/v2.0/authorize" forKey:@"authorization_endpoint"];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    
    MSALTestURLResponse *response = [MSALTestURLResponse request:[NSURL URLWithString:AAD_INSTANCE_DISCOVERY_ENDPOINT]
                                                  requestHeaders:reqHeaders
                                               requestParamsBody:nil
                                                respondWithError:[NSError errorWithDomain:NSURLErrorDomain
                                                                                     code:NSURLErrorCannotFindHost
                                                                                 userInfo:nil]];
    
    [MSALTestURLSession addResponse:response];
    
    [[MSALAadAuthorityResolver new] openIDConfigurationEndpointForURL:[NSURL URLWithString:@"https://somehost.com/sometenant.com"]
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



@end
