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

#import <XCTest/XCTest.h>
#import "MSALHttpRequest.h"
#import "MSALHttpResponse.h"

@interface MSALHttpRequestTests : XCTestCase

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
    NSURLSession *session = [[NSURLSession alloc] init];
    
    MSALHttpRequest *request = [[MSALHttpRequest alloc] initWithURL:testURL session:session];
    
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
    NSURLSession *session = [[NSURLSession alloc] init];
    
    MSALHttpRequest *request = [[MSALHttpRequest alloc] initWithURL:testURL session:session];
    
    [request setValue:@"value1" forBodyParameter:@"bodyParam1"];
    
    XCTAssertEqualObjects(@"value1", [[request bodyParameters] objectForKey:@"bodyParam1"]);
    
    [request removeBodyParameter:@"bodyParam1"];
    
    XCTAssertNil([[request bodyParameters] objectForKey:@"bodyParam1"]);
    
    
}

- (void)testToBeDeleted
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"High Expectations"];

    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURL *testURL = [NSURL URLWithString:@"https://enterpriseregistration.windows.net/ngctest.com/EnrollmentServer/Contract?api-version=1.2"];
    
    MSALHttpRequest *request = [[MSALHttpRequest alloc] initWithURL:testURL session:session];
    
    [request sendGet:^(NSError *error, MSALHttpResponse *response) {
        NSLog(@"%@", error);
        NSLog(@"%lu", (long)response.statusCode);
        
        NSLog(@"%@", response.body);
        
        NSError *er = nil;
        id json = [NSJSONSerialization JSONObjectWithData:response.body
                                                  options:NSJSONReadingAllowFragments error:&er];
        
        NSLog(@"%@", er);
        NSLog(@"%@", json);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10.0 handler:^(NSError * _Nullable error) {
        if (error)
        {
            NSLog(@"TIMEOUT");
        }
    }];
    
    
}


@end
