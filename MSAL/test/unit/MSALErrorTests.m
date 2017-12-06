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
#import "MSALTestCase.h"
#import "MSALError_Internal.h"

@interface MSALErrorTests : MSALTestCase

@end

@implementation MSALErrorTests

- (void)testCreateError_withDomainCodeDescription_noAdditionalUserInfo_shouldReturnErrorWithCodeDomainUserInfo
{
    NSError *error = MSALCreateError(@"TestDomain", -1000, @"Test description", nil, nil, nil, nil);
    
    XCTAssertEqualObjects(error.domain, @"TestDomain");
    XCTAssertEqual(error.code, -1000);
    XCTAssertNotNil(error.userInfo);
    XCTAssertEqualObjects(error.userInfo[MSALErrorDescriptionKey], @"Test description");
}

- (void)testCreateError_withDomainCodeDescription_withAdditionalUserInfo_shouldReturnErrorWithCodeDomainUserInfo
{
    NSDictionary *userInfo = @{MSALHTTPHeadersKey : @{@"Retry-After": @"120"}};
    
    NSError *error = MSALCreateError(@"TestDomain", -1000, @"Test description", nil, nil, nil, userInfo);
    
    XCTAssertEqualObjects(error.domain, @"TestDomain");
    XCTAssertEqual(error.code, -1000);
    XCTAssertNotNil(error.userInfo);
    XCTAssertEqualObjects(error.userInfo[MSALErrorDescriptionKey], @"Test description");
    XCTAssertNotNil(error.userInfo[MSALHTTPHeadersKey]);
    XCTAssertEqualObjects(error.userInfo[MSALHTTPHeadersKey][@"Retry-After"], @"120");
}

@end
