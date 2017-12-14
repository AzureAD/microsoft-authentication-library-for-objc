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

#import <XCTest/XCTest.h>
#include "MSALErrorConverter.h"
#include "MSIDError.h"

@interface MSALErrorConverterTests : XCTestCase

@end

@implementation MSALErrorConverterTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testErrorConversion_whenPassInNil_ShouldReturnNil {
    NSError *msalError = [MSALErrorConverter MSALErrorFromMSIDError:nil];
    XCTAssertNil(msalError);
}

- (void)testErrorConversion_whenOnlyErrorDomainIsMapped_ErrorCodeShouldBeKept {
    NSInteger errorCode = -9999;
    NSString *errorDescription = @"a fake error description.";
    NSString *oauthError = @"a fake oauth error message.";
    NSString *subError = @"a fake suberror";
    NSError *underlyingError = [NSError errorWithDomain:NSOSStatusErrorDomain code:errSecItemNotFound userInfo:nil];
    NSUUID *correlationId = [NSUUID UUID];
    NSDictionary *httpHeaders = @{@"fake header key" : @"fake header value"};
    NSString *httpResponseCode = @"-99999";
    
    NSError *msidError = MSIDCreateError(MSIDErrorDomain,
                                         errorCode,
                                         errorDescription,
                                         oauthError,
                                         subError,
                                         underlyingError,
                                         correlationId,
                                         @{MSIDHTTPHeadersKey : httpHeaders,
                                           MSIDHTTPResponseCodeKey : httpResponseCode
                                           });
    NSError *msalError = [MSALErrorConverter MSALErrorFromMSIDError:msidError];
    
    XCTAssertNotNil(msalError);
    XCTAssertEqualObjects(msalError.domain, MSALErrorDomain);
    XCTAssertEqual(msalError.code, errorCode);
    XCTAssertEqualObjects(msalError.userInfo[MSALErrorDescriptionKey], errorDescription);
    XCTAssertEqualObjects(msalError.userInfo[MSALOAuthErrorKey], oauthError);
    XCTAssertEqualObjects(msalError.userInfo[MSALOAuthSubErrorKey], subError);
    XCTAssertEqualObjects(msalError.userInfo[NSUnderlyingErrorKey], underlyingError);
    XCTAssertEqualObjects(msalError.userInfo[MSALHTTPHeadersKey], httpHeaders);
    XCTAssertEqualObjects(msalError.userInfo[MSALHTTPResponseCodeKey], httpResponseCode);
}

@end
