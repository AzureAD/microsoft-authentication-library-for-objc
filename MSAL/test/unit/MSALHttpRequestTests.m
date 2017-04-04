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
#import "MSALHttpRequest.h"
#import "MSALHttpResponse.h"
#import "MSALTestURLSession.h"

@interface MSALHttpRequestTests : MSALTestCase

@end

@implementation MSALHttpRequestTests


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

- (void)testHeaderManipulation
{
    NSURL *testURL = [NSURL URLWithString:@"http://sometesturl"];
    MSALHttpRequest *request = [[MSALHttpRequest alloc] initWithURL:testURL context:nil];
    
    [request setValue:@"value1" forHTTPHeaderField:@"header1"];
    [request setValue:@"value2" forHTTPHeaderField:@"header2"];
    
    [request addValue:@"moreValue" forHTTPHeaderField:@"header1"];
    
    XCTAssertEqualObjects(@"value2", [[request headers] objectForKey:@"header2"]);
    XCTAssertEqualObjects(@"value1,moreValue", [[request headers] objectForKey:@"header1"]);
    
    XCTAssertNil([[request headers] objectForKey:@"nonExistingValue"]);
    
}

- (void)testBodyParameters
{
    NSURL *testURL = [NSURL URLWithString:@"http://sometesturl"];
    MSALHttpRequest *request = [[MSALHttpRequest alloc] initWithURL:testURL context:nil];
    
    [request setValue:@"value1" forBodyParameter:@"bodyParam1"];
    
    XCTAssertEqualObjects(@"value1", [[request bodyParameters] objectForKey:@"bodyParam1"]);
    
    [request removeBodyParameter:@"bodyParam1"];
    
    XCTAssertNil([[request bodyParameters] objectForKey:@"bodyParam1"]);
    
    
}

- (void)testHttpGetRequest
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    MSALRequestParameters *params = [MSALRequestParameters new];
    params.urlSession = [MSALTestURLSession createMockSession];
    
    NSString *testURLString = @"https://somehttprequest.com";
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    
    MSALTestURLResponse *response = [MSALTestURLResponse requestURLString:testURLString
                                                           requestHeaders:reqHeaders
                                                        requestParamsBody:nil
                                                        responseURLString:@"https://someresponsestring.com"
                                                             responseCode:200
                                                         httpHeaderFields:nil
                                                         dictionaryAsJSON:@{@"endpoint" : @"valid"}];
    
    [MSALTestURLSession addResponse:response];
    
    MSALHttpRequest *request = [[MSALHttpRequest alloc] initWithURL:[NSURL URLWithString:testURLString]
                                                            context:params];
    
    [request sendGet:^(MSALHttpResponse *response, NSError *error) {
        XCTAssertNil(error);
        
        XCTAssertEqual(response.statusCode, 200);
        
        NSError *er = nil;
        id json = [NSJSONSerialization JSONObjectWithData:response.body
                                                  options:NSJSONReadingAllowFragments error:&er];
        XCTAssertNil(er);
        XCTAssertNotNil(json);
        
        XCTAssertEqualObjects(@"valid", json[@"endpoint"]);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10.0 handler:^(NSError * _Nullable error) {
        XCTAssertNil(error);
    }];
}

- (void)testHttpResponseInit
{
    NSDictionary *headers = @{ @"ImAHeader" : @"Yes you are"};
    NSHTTPURLResponse *urlResponse =
    [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://fakeurl"]
                                statusCode:200
                               HTTPVersion:@"4.2"
                              headerFields:headers];
    
    
    NSError *error = nil;
    MSALHttpResponse *response = [[MSALHttpResponse alloc] initWithResponse:urlResponse data:nil error:&error];
    XCTAssertNotNil(response);
    XCTAssertNil(error);
    
    XCTAssertEqual(response.statusCode, 200);
    XCTAssertEqualObjects(response.headers, headers);
}

- (void)testHttpNilResponseInit
{
    NSError *error = nil;
    MSALHttpResponse *response = [[MSALHttpResponse alloc] initWithResponse:nil data:nil error:&error];
    XCTAssertNil(response);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInternal);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"MSALHttpResponse"]);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"nil"]);
}


@end
