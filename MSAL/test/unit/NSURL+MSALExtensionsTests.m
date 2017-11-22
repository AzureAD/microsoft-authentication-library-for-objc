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

- (void)testMsalHostWithPort_whenNoPortSpecified_shouldHaveNoPort
{
    NSURL *urlWithNoPortSpecified = [NSURL URLWithString:@"https://somehost.com"];
    XCTAssertEqualObjects([urlWithNoPortSpecified msalHostWithPort], @"somehost.com");
}

- (void)testMsalHostWithPort_whenCustomPort_shouldHavePort
{
    NSURL *urlWithCustomPort = [NSURL URLWithString:@"https://somehost.com:88"];
    XCTAssertEqualObjects([urlWithCustomPort msalHostWithPort], @"somehost.com:88");
}

- (void)testMsalHostWithPort_when443DefaultPort_shouldHaveNoPort
{
    NSURL *urlWithDefaultPort = [NSURL URLWithString:@"https://somehost.com:443"];
    XCTAssertEqualObjects([urlWithDefaultPort msalHostWithPort], @"somehost.com");
}

- (void)testMsalHostWithPort_whenNoHost_shouldReturnBlank
{
    NSURL *urlWithNoHost = [NSURL new];
    XCTAssertEqualObjects([urlWithNoHost msalHostWithPort], @"");
}

- (void)testIsEquivalentAuthority_whenMatch_shouldReturnTrue
{
    NSURL *url1 = [NSURL URLWithString:@"https://host.com/"];
    NSURL *url2 = [url1 copy];
    
    XCTAssertTrue([url1 isEquivalentAuthority:url2]);
}

- (void)testIsEquivalentAuthority_whenOneSchemeIsNil_shouldReturnFalse
{
    NSURL *url1 = [NSURL URLWithString:@"https://host.com/"];
    NSURL *url2 = [NSURL URLWithString:@"host.com/"];

    XCTAssertFalse([url1 isEquivalentAuthority:url2]);
}

- (void)testIsEquivalentAuthority_whenBothSchemesAreNil_shouldReturnTrue
{
    NSURL *url1 = [NSURL URLWithString:@"host.com/path1"];
    NSURL *url2 = [NSURL URLWithString:@"host.com/path2"];
    
    XCTAssertTrue([url1 isEquivalentAuthority:url2]);
}

- (void)testIsEquivalentAuthority_whenSchemesDontMatch_shouldReturnFalse
{
    NSURL *url1 = [NSURL URLWithString:@"https://host.com/"];
    NSURL *url2 = [NSURL URLWithString:@"http://host.com/"];
    
    XCTAssertFalse([url1 isEquivalentAuthority:url2]);
}

- (void)testIsEquivalentAuthority_whenOneHostIsNil_shouldReturnFalse
{
    NSURL *url1 = [NSURL URLWithString:@"https://host.com/"];
    NSURL *url2 = [NSURL URLWithString:@"https://"];
    
    XCTAssertFalse([url1 isEquivalentAuthority:url2]);
}

- (void)testIsEquivalentAuthority_whenBothHostsAreNil_shouldReturnTrue
{
    NSURL *url1 = [NSURL URLWithString:@"https://"];
    NSURL *url2 = [NSURL URLWithString:@"https://"];
    
    XCTAssertTrue([url1 isEquivalentAuthority:url2]);
}

- (void)testIsEquivalentAuthority_whenHostsDontMatch_shouldReturnFalse
{
    NSURL *url1 = [NSURL URLWithString:@"https://host1.com/"];
    NSURL *url2 = [NSURL URLWithString:@"https://host2.com/"];
    
    XCTAssertFalse([url1 isEquivalentAuthority:url2]);
}

- (void)testIsEquivalentAuthority_whenPortsDontMatch_shouldReturnFalse
{
    NSURL *url1 = [NSURL URLWithString:@"https://host.com:123/"];
    NSURL *url2 = [NSURL URLWithString:@"https://host.com:456/"];
    
    XCTAssertFalse([url1 isEquivalentAuthority:url2]);
}

- (void)testIsEquivalentAuthority_whenPortsNilAndCustom_shouldReturnFalse
{
    NSURL *url1 = [NSURL URLWithString:@"https://host.com/"];
    NSURL *url2 = [NSURL URLWithString:@"https://host.com:123/"];
    
    XCTAssertFalse([url1 isEquivalentAuthority:url2]);
}

- (void)testIsEquivalentAuthority_whenPortsNilAnd443_shouldReturnTrue
{
    NSURL *url1 = [NSURL URLWithString:@"https://host.com:443/"];
    NSURL *url2 = [NSURL URLWithString:@"https://host.com/"];
    
    XCTAssertTrue([url1 isEquivalentAuthority:url2]);
}

- (void)testIsEquivalentAuthority_whenPortsBothNil_shouldReturnTrue
{
    NSURL *url1 = [NSURL URLWithString:@"https://host.com/path1"];
    NSURL *url2 = [NSURL URLWithString:@"https://host.com/path2"];
    
    XCTAssertTrue([url1 isEquivalentAuthority:url2]);
}

- (void)testIsEquivalentAuthority_whenTrailingPathsExistOthersMatch_shouldReturnTrue
{
    NSURL *url1 = [NSURL URLWithString:@"https://host.com/path1"];
    NSURL *url2 = [NSURL URLWithString:@"https://host.com/path2"];
    
    XCTAssertTrue([url1 isEquivalentAuthority:url2]);
}

- (void)testIsEquivalentAuthority_whenTrailingPathsExistOthersMatchCustomPorts_shouldReturnTrue
{
    NSURL *url1 = [NSURL URLWithString:@"https://host.com:123/path1"];
    NSURL *url2 = [NSURL URLWithString:@"https://host.com:123/path2"];
    
    XCTAssertTrue([url1 isEquivalentAuthority:url2]);
}


- (void)testIsEquivalentAuthority_whenTrailingPathsExistOthersMatchWithOne443Port_shouldReturnTrue
{
    NSURL *url1 = [NSURL URLWithString:@"https://host.com:443/path1"];
    NSURL *url2 = [NSURL URLWithString:@"https://host.com/path2"];
    
    XCTAssertTrue([url1 isEquivalentAuthority:url2]);
}

@end
