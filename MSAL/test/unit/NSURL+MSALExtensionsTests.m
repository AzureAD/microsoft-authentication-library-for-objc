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
#import "NSURL+MSALExtensions.h"

@interface NSURL_MSALExtensionsTests : MSALTestCase

@end

@implementation NSURL_MSALExtensionsTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testHostWithNoPortSpecified
{
    NSURL *urlWithNoPortSpecified = [NSURL URLWithString:@"https://somehost.com"];
    XCTAssertEqualObjects([urlWithNoPortSpecified msalHostWithPort], @"somehost.com");
}

- (void)testHostWithCustomPort
{
    NSURL *urlWithCustomPort = [NSURL URLWithString:@"https://somehost.com:88"];
    XCTAssertEqualObjects([urlWithCustomPort msalHostWithPort], @"somehost.com:88");
}

- (void)testHostWithDefaultPort
{
    NSURL *urlWithDefaultPort = [NSURL URLWithString:@"https://somehost.com:443"];
    XCTAssertEqualObjects([urlWithDefaultPort msalHostWithPort], @"somehost.com");
}

- (void)testHostWithNoHost
{
    NSURL *urlWithNoHost = [NSURL new];
    XCTAssertEqualObjects([urlWithNoHost msalHostWithPort], @"");
}

- (void)testScrubbedHttpPath_whenTenantlessAuthorityPath_shouldReturnSame
{
    NSURL *testUrl = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    NSString *scrubbedPath = [testUrl scrubbedHttpPath];
    XCTAssertEqualObjects([testUrl absoluteString], scrubbedPath);
}

- (void)testScrubbedHttpPath_whenTenantlessTokenPath_shouldReturnSame
{
    NSURL *testUrl = [NSURL URLWithString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"];
    NSString *scrubbedPath = [testUrl scrubbedHttpPath];
    XCTAssertEqualObjects([testUrl absoluteString], scrubbedPath);
}

- (void)testScrubbedHttpPath_whenWithTenantAuthorityPath_shouldScrub
{
    NSURL *testUrl = [NSURL URLWithString:@"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031"];
    NSString *scrubbedPath = [testUrl scrubbedHttpPath];
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/<tenant>", scrubbedPath);
}

- (void)testScrubbedHttpPath_whenWithTenantTokenPath_shouldScrub
{
    NSURL *testUrl = [NSURL URLWithString:@"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031/oauth2/v2.0/token"];
    NSString *scrubbedPath = [testUrl scrubbedHttpPath];
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token", scrubbedPath);
}

- (void)testScrubbedHttpPath_whenWithoutTenantPath_shouldReturnSame
{
    NSURL *testUrl = [NSURL URLWithString:@"https://login.microsoftonline.com"];
    NSString *scrubbedPath = [testUrl scrubbedHttpPath];
    XCTAssertEqualObjects([testUrl absoluteString], scrubbedPath);
}

- (void)testScrubbedHttpPath_whenMalformedB2CPath_shouldReturnSame
{
    NSURL *testUrl = [NSURL URLWithString:@"https://login.microsoftonline.com/tfp"];
    NSString *scrubbedPath = [testUrl scrubbedHttpPath];
    XCTAssertEqualObjects([testUrl absoluteString], scrubbedPath);
}

- (void)testScrubbedHttpPath_whenCorrectB2CPath_shouldScrub
{
    NSURL *testUrl = [NSURL URLWithString:@"https://login.microsoftonline.com/tfp/0287f963-2d72-4363-9e3a-5705c5b0f031/b2c_1_siup/v2.0/"];
    NSString *scrubbedPath = [testUrl scrubbedHttpPath];
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/tfp/<tenant>/b2c_1_siup/v2.0/", scrubbedPath);
}

@end
