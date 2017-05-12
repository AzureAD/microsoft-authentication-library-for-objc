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
#import "MSALWebFingerRequest.h"
#import "MSALWebAuthRequest.h"
#import "MSALTestURLSession.h"
#import "MSALWebFingerResponse.h"

#import "MSALTestSwizzle.h"

@interface MSALWebFingerRequestTests : MSALTestCase

@end

@implementation MSALWebFingerRequestTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testUrlForWebFinger_whenNoAuthenticationEndpoint_shouldReturnNil
{
    XCTAssertNil([MSALWebFingerRequest urlForWebFinger:nil absoluteAuthority:@"https://login.microsoftonline.com/common"]);
}

- (void)testUrlForWebFinger_whenNoAuthority_shouldReturnNil
{
    XCTAssertNil([MSALWebFingerRequest urlForWebFinger:@"https://someUrl.com" absoluteAuthority:nil]);
}

- (void)testUrlForWebFinger_whenAuthenticationEndpointAndAuthority_shouldReturnUrl
{
    NSString *authenticationEndpoint = @"https://someauthendpoint.com";
    NSString *authority = @"https://someauthority.com";
    
    NSString *expectedUrlString = @"https://someauthendpoint.com/.well-known/webfinger?resource=https://someauthority.com";
    
    NSURL *url = [MSALWebFingerRequest urlForWebFinger:authenticationEndpoint absoluteAuthority:authority];
    
    XCTAssertNotNil(url);
    XCTAssertEqualObjects(url.absoluteString, expectedUrlString);
}

- (void)testRequestForAuthenticationEndpoint_whenNoAuthenticationEndpoint_shouldReturnError
{
    [MSALWebFingerRequest requestForAuthenticationEndpoint:nil
                                                 authority:[NSURL URLWithString:@"https://someauthority.com"]
                                                   context:nil
                                           completionBlock:^(MSALWebFingerResponse *response, NSError *error)
    {
        XCTAssertNil(response);
        XCTAssertNotNil(error);
        
        XCTAssertTrue(error.code == MSALErrorInvalidParameter);
        XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"AuthenticationEndpoint"]);
    }];
}


- (void)testRequestForAuthenticationEndpoint_whenNoAuthority_shouldReturnError
{
    [MSALWebFingerRequest requestForAuthenticationEndpoint:@"https://someauthendpoint.com"
                                                 authority:nil
                                                   context:nil
                                           completionBlock:^(MSALWebFingerResponse *response, NSError *error)
     {
         XCTAssertNil(response);
         XCTAssertNotNil(error);
         
         XCTAssertTrue(error.code == MSALErrorInvalidParameter);
         XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"authority"]);
     }];
}

- (void)testRequestForAuthenticationEndpoint_whenAllParamsEnteredAndValidResponse_shouldReturnResponse
{
    __block NSUUID *correlationId = [NSUUID new];
    
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSALTestURLSession createMockSession];
    parameters.correlationId = correlationId;
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];
    
    MSALTestURLResponse *response =
    [MSALTestURLResponse requestURLString:@"https://someauthendpoint.com/.well-known/webfinger?resource=https://someauthority.com"
                           requestHeaders:reqHeaders
                        requestParamsBody:nil
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"links" : @[@{ @"rel" : @"https://somerel.com", @"href" : @"https://somehref"}]}];
    [MSALTestURLSession addResponse:response];
    
    [MSALWebFingerRequest requestForAuthenticationEndpoint:@"https://someauthendpoint.com"
                                                 authority:[NSURL URLWithString:@"https://someauthority.com"]
                                                   context:parameters
                                           completionBlock:^(MSALWebFingerResponse *response, NSError *error)
     {
         XCTAssertNil(error);
         XCTAssertNotNil(response);
         
         XCTAssertTrue(response.links.count == 1);
     }];
}

- (void)testRequestForAuthenticationEndpoint_whenAllParamsEnteredAndResponseError_shouldReturnError
{
    __block NSUUID *correlationId = [NSUUID new];
    
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSALTestURLSession createMockSession];
    parameters.correlationId = correlationId;
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];
    
    MSALTestURLResponse *response =
    [MSALTestURLResponse serverNotFoundResponseForURLString:@"https://someauthendpoint.com/.well-known/webfinger?resource=https://someauthority.com"
                                             requestHeaders:reqHeaders
                                          requestParamsBody:nil];
    [MSALTestURLSession addResponse:response];
    
    [MSALWebFingerRequest requestForAuthenticationEndpoint:@"https://someauthendpoint.com"
                                                 authority:[NSURL URLWithString:@"https://someauthority.com"]
                                                   context:parameters
                                           completionBlock:^(MSALWebFingerResponse *response, NSError *error)
     {
         XCTAssertNotNil(error);
         XCTAssertNil(response);
     }];
}

@end
