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
    
    NSError *msidError = MSIDCreateError(MSIDKeychainErrorDomain,
                                         errorCode,
                                         errorDescription,
                                         oauthError,
                                         subError,
                                         underlyingError,
                                         correlationId,
                                         @{MSIDHTTPHeadersKey : httpHeaders,
                                           MSIDHTTPResponseCodeKey : httpResponseCode,
                                           @"additional_user_info": @"unmapped_userinfo"
                                           });
    NSError *msalError = [MSALErrorConverter MSALErrorFromMSIDError:msidError];
    
    NSString *expectedErrorDomain = NSOSStatusErrorDomain;
    XCTAssertNotNil(msalError);
    XCTAssertEqualObjects(msalError.domain, expectedErrorDomain);
    XCTAssertEqual(msalError.code, errorCode);
    XCTAssertEqualObjects(msalError.userInfo[MSALErrorDescriptionKey], errorDescription);
    XCTAssertNil(msalError.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertEqualObjects(msalError.userInfo[MSALOAuthErrorKey], oauthError);
    XCTAssertNil(msalError.userInfo[MSIDOAuthErrorKey]);
    XCTAssertEqualObjects(msalError.userInfo[MSALOAuthSubErrorKey], subError);
    XCTAssertNil(msalError.userInfo[MSIDOAuthSubErrorKey]);
    XCTAssertEqualObjects(msalError.userInfo[NSUnderlyingErrorKey], underlyingError);
    XCTAssertEqualObjects(msalError.userInfo[MSALHTTPHeadersKey], httpHeaders);
    XCTAssertNil(msalError.userInfo[MSIDHTTPHeadersKey]);
    XCTAssertEqualObjects(msalError.userInfo[MSALHTTPResponseCodeKey], httpResponseCode);
    XCTAssertNil(msalError.userInfo[MSIDHTTPResponseCodeKey]);
    XCTAssertEqualObjects(msalError.userInfo[@"additional_user_info"], @"unmapped_userinfo");
}

- (void)testErrorConversion_whenBothErrorDomainAndCodeAreMapped_shouldMapBoth {
    NSInteger errorCode = MSIDErrorInteractionRequired;
    NSString *errorDescription = @"a fake error description.";
    NSString *oauthError = @"a fake oauth error message.";
    NSString *subError = @"a fake suberror";
    NSError *underlyingError = [NSError errorWithDomain:NSOSStatusErrorDomain code:errSecItemNotFound userInfo:nil];
    NSUUID *correlationId = [NSUUID UUID];
    NSDictionary *httpHeaders = @{@"fake header key" : @"fake header value"};
    NSString *httpResponseCode = @"-99999";
    
    NSError *msidError = MSIDCreateError(MSIDOAuthErrorDomain,
                                         errorCode,
                                         errorDescription,
                                         oauthError,
                                         subError,
                                         underlyingError,
                                         correlationId,
                                         @{MSIDHTTPHeadersKey : httpHeaders,
                                           MSIDHTTPResponseCodeKey : httpResponseCode,
                                           @"additional_user_info": @"unmapped_userinfo"
                                           });
    NSError *msalError = [MSALErrorConverter MSALErrorFromMSIDError:msidError];
    
    NSString *expectedErrorDomain = MSALErrorDomain;
    NSInteger expectedErrorCode = MSALErrorInteractionRequired;
    XCTAssertNotNil(msalError);
    XCTAssertEqualObjects(msalError.domain, expectedErrorDomain);
    XCTAssertEqual(msalError.code, expectedErrorCode);
    XCTAssertEqualObjects(msalError.userInfo[MSALErrorDescriptionKey], errorDescription);
    XCTAssertNil(msalError.userInfo[MSIDErrorDescriptionKey]);
    XCTAssertEqualObjects(msalError.userInfo[MSALOAuthErrorKey], oauthError);
    XCTAssertNil(msalError.userInfo[MSIDOAuthErrorKey]);
    XCTAssertEqualObjects(msalError.userInfo[MSALOAuthSubErrorKey], subError);
    XCTAssertNil(msalError.userInfo[MSIDOAuthSubErrorKey]);
    XCTAssertEqualObjects(msalError.userInfo[NSUnderlyingErrorKey], underlyingError);
    XCTAssertEqualObjects(msalError.userInfo[MSALHTTPHeadersKey], httpHeaders);
    XCTAssertNil(msalError.userInfo[MSIDHTTPHeadersKey]);
    XCTAssertEqualObjects(msalError.userInfo[MSALHTTPResponseCodeKey], httpResponseCode);
    XCTAssertNil(msalError.userInfo[MSIDHTTPResponseCodeKey]);
    XCTAssertEqualObjects(msalError.userInfo[@"additional_user_info"], @"unmapped_userinfo");
}

/*!
 It's very easy to add an additional error in MSID space, but forget to map it to appropriate AD error.
 This test is just making sure that each error under MSIDErrorDomain is mapped to a different AD error
 and will fail if new error is added and left unmapped.
 
 This test doesn't test that the error has been mapped correctly.
 */
- (void)testErrorConversion_whenErrorConverterInitialized_shouldMapAllMSIDErrors
{
    NSDictionary *domainsAndCodes = MSIDErrorDomainsAndCodes();
    
    for (NSString *domain in domainsAndCodes)
    {
        NSArray *codes = domainsAndCodes[domain];
        for (NSNumber *code in codes)
        {
            MSIDErrorCode errorCode = [code integerValue];
            NSError *msidError = MSIDCreateError(domain, errorCode, @"test", nil, nil, nil, nil, nil);
            NSError *error = [MSALErrorConverter MSALErrorFromMSIDError:msidError];
            
            XCTAssertNotEqual(error.code, errorCode);
            
        }
    }
}

@end
