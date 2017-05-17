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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSALTestCase.h"
#import "MSALDrsDiscoveryRequest.h"
#import "MSALTestURLSession.h"
#import "MSALDrsDiscoveryResponse.h"

@interface MSALDrsDiscoveryRequestTests : MSALTestCase

@end

@implementation MSALDrsDiscoveryRequestTests

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


- (void)testUrlForDrsDiscoveryForDomain_whenNoDomain_shouldReturnNil
{
    XCTAssertNil([MSALDrsDiscoveryRequest urlForDrsDiscoveryForDomain:nil adfsType:MSAL_ADFS_CLOUD]);
    XCTAssertNil([MSALDrsDiscoveryRequest urlForDrsDiscoveryForDomain:nil adfsType:MSAL_ADFS_ON_PREMS]);
}

- (void)testUrlForDrsDiscoveryForDomain_whenDomainAndOnPrems_shouldReturnUrl
{
    NSString *expectedUrlString = @"https://enterpriseregistration.somedomain.com/enrollmentserver/contract?api-version=1.0";
    NSURL *resultUrl = [MSALDrsDiscoveryRequest urlForDrsDiscoveryForDomain:@"somedomain.com" adfsType:MSAL_ADFS_ON_PREMS];
    XCTAssertNotNil(resultUrl);
    XCTAssertEqualObjects(resultUrl.absoluteString, expectedUrlString);
}

- (void)testUrlForDrsDiscoveryForDomain_whenDomainAndOnCloud_shouldReturnUrl
{
    NSString *expectedUrlString = @"https://enterpriseregistration.windows.net/somedomain.com/enrollmentserver/contract?api-version=1.0";
    NSURL *resultUrl = [MSALDrsDiscoveryRequest urlForDrsDiscoveryForDomain:@"somedomain.com" adfsType:MSAL_ADFS_CLOUD];
    XCTAssertNotNil(resultUrl);
    XCTAssertEqualObjects(resultUrl.absoluteString, expectedUrlString);
}

- (void)testQueryEnrollmentServerEndpointForDomain_whenDomainNil_shouldReturnError
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [MSALDrsDiscoveryRequest queryEnrollmentServerEndpointForDomain:nil
                                                           adfsType:MSAL_ADFS_CLOUD
                                                            context:nil
                                                    completionBlock:^(MSALDrsDiscoveryResponse *response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNotNil(error);
         
         XCTAssertTrue(error.code == MSALErrorInvalidParameter);
         XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"Domain"]);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testQueryEnrollmentServerEndpointForDomain_whenValidResponse_shouldReturnResponse
{
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSALTestURLSession createMockSession];
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];

    MSALTestURLResponse *response =
    [MSALTestURLResponse requestURLString:@"https://enterpriseregistration.windows.net/somedomain.com/enrollmentserver/contract?api-version=1.0"
                           requestHeaders:reqHeaders
                        requestParamsBody:nil
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"IdentityProviderService" :
                                                 @{ @"PassiveAuthEndpoint" : @"https://fs.fabrikam.com/adfs/ls" }}];
    [MSALTestURLSession addResponse:response];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    [MSALDrsDiscoveryRequest queryEnrollmentServerEndpointForDomain:@"somedomain.com"
                                                           adfsType:MSAL_ADFS_CLOUD
                                                            context:parameters
                                                    completionBlock:^(MSALDrsDiscoveryResponse *response, NSError *error)
     {
         XCTAssertNil(error);
         XCTAssertNotNil(response);
         
         XCTAssertEqualObjects(response.passiveAuthEndpoint, @"https://fs.fabrikam.com/adfs/ls");
         
         [expectation fulfill];
     }];
     
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testQueryEnrollmentServerEndpointForDomain_whenResponseError_shouldReturnError
{
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSALTestURLSession createMockSession];
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    
    MSALTestURLResponse *response =
    [MSALTestURLResponse serverNotFoundResponseForURLString:@"https://enterpriseregistration.windows.net/somedomain.com/enrollmentserver/contract?api-version=1.0"
                                             requestHeaders:reqHeaders
                                          requestParamsBody:nil];
    [MSALTestURLSession addResponse:response];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    [MSALDrsDiscoveryRequest queryEnrollmentServerEndpointForDomain:@"somedomain.com"
                                                           adfsType:MSAL_ADFS_CLOUD
                                                            context:parameters
                                                    completionBlock:^(MSALDrsDiscoveryResponse *response, NSError *error)
     {
         XCTAssertNotNil(error);
         XCTAssertNil(response);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

@end
