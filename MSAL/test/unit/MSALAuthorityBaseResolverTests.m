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
#import "MSALAuthorityBaseResolver.h"
#import "MSALTestURLSession.h"
#import "MSALTenantDiscoveryResponse.h"

@interface MSALAuthorityBaseResolverTests : MSALTestCase

@end

@implementation MSALAuthorityBaseResolverTests

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

- (void)testTenantDiscoverySuccess
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    NSString *filePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"OpenIdConfiguration.json"];
    XCTAssertNotNil(filePath);
    
    NSData *data = [NSData dataWithContentsOfFile:filePath options:0 error:nil];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

    MSALRequestParameters *params = [MSALRequestParameters new];
    params.urlSession = [MSALTestURLSession createMockSession];
    
    NSString *tenantDiscoveryEndpoint = @"https://login.windows.net/common/v2.0/.well-known/openid-configuration";
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    
    MSALTestURLResponse *response = [MSALTestURLResponse requestURLString:tenantDiscoveryEndpoint
                                                           requestHeaders:reqHeaders
                                                        requestParamsBody:nil
                                                        responseURLString:@"https://someresponseurl.com"
                                                             responseCode:200
                                                         httpHeaderFields:@{}
                                                         dictionaryAsJSON:json];
    
    [MSALTestURLSession addResponse:response];
    
    MSALAuthorityBaseResolver *resolver = [MSALAuthorityBaseResolver new];
    [resolver tenantDiscoveryEndpoint:[NSURL URLWithString:tenantDiscoveryEndpoint]
                              context:params
                      completionBlock:^(MSALTenantDiscoveryResponse *response, NSError *error)
    {
        XCTAssertNotNil(response);
        XCTAssertNotNil(response.authorization_endpoint);
        XCTAssertNotNil(response.issuer);
        XCTAssertNotNil(response.token_endpoint);
        
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10.0 handler:^(NSError * _Nullable error)
    {
        XCTAssertNil(error);
    }];
}

- (void)testTenantDiscoveryMissingEndpoint
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    NSString *filePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"OpenIdConfigurationMissingFields.json"];
    XCTAssertNotNil(filePath);
    
    NSData *data = [NSData dataWithContentsOfFile:filePath options:0 error:nil];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

    MSALRequestParameters *params = [MSALRequestParameters new];
    params.urlSession = [MSALTestURLSession createMockSession];
    
    NSString *tenantDiscoveryEndpoint = @"https://login.windows.net/common/v2.0/.well-known/openid-configuration";
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    
    MSALTestURLResponse *response = [MSALTestURLResponse requestURLString:tenantDiscoveryEndpoint
                                                           requestHeaders:reqHeaders
                                                        requestParamsBody:nil
                                                        responseURLString:@"https://someresponseurl.com"
                                                             responseCode:200
                                                         httpHeaderFields:@{}
                                                         dictionaryAsJSON:json];
    
    [MSALTestURLSession addResponse:response];
    
    MSALAuthorityBaseResolver *resolver = [MSALAuthorityBaseResolver new];
    [resolver tenantDiscoveryEndpoint:[NSURL URLWithString:tenantDiscoveryEndpoint]
                              context:params
                      completionBlock:^(MSALTenantDiscoveryResponse *response, NSError *error)
     {
         XCTAssertNil(response);
         
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:10.0 handler:^(NSError * _Nullable error)
    {
        XCTAssertNil(error);
    }];
}

@end
