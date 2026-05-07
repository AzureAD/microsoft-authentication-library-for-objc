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

#import <XCTest/XCTest.h>
#import "MSALDeviceTokenResult.h"
#import "MSALDeviceTokenResult+Internal.h"
#import "MSIDTokenResult.h"
#import "MSIDAccessToken.h"
#import "MSIDTokenResponse.h"
#import "MSIDAADAuthority.h"
#import "MSIDRefreshToken.h"

@interface MSALDeviceTokenResultTests : XCTestCase

@end

@implementation MSALDeviceTokenResultTests

- (void)testInitWithAccessToken_shouldSetAllProperties
{
    NSDate *expiresOn = [NSDate dateWithTimeIntervalSince1970:12345];
    NSArray<NSString *> *scopes = @[@"scope.read", @"scope.write"];
    MSALDeviceTokenResult *result = [[MSALDeviceTokenResult alloc] initWithAccessToken:@"access-token"
                                                                       deviceInformation:@"device-info-jwt"
                                                                               expiresOn:expiresOn
                                                                                  scopes:scopes
                                                                               authority:nil];

    XCTAssertEqualObjects(result.accessToken, @"access-token");
    XCTAssertEqualObjects(result.deviceInformation, @"device-info-jwt");
    XCTAssertEqualObjects(result.expiresOn, expiresOn);
    XCTAssertEqualObjects(result.scopes, scopes);
    XCTAssertNil(result.authority);
}

- (void)testResultForDeviceTokenResult_whenTokenResultIsNil_shouldReturnNilAndError
{
    NSError *error = nil;
    MSALDeviceTokenResult *result = [MSALDeviceTokenResult resultForDeviceTokenResult:nil error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testResultForDeviceTokenResult_whenRefreshTokenIsPresent_shouldReturnNilAndError
{
    MSIDTokenResult *tokenResult = [self validTokenResult];
    tokenResult.refreshToken = [MSIDRefreshToken new];

    NSError *error = nil;
    MSALDeviceTokenResult *result = [MSALDeviceTokenResult resultForDeviceTokenResult:tokenResult error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testResultForDeviceTokenResult_whenRawIdTokenIsPresent_shouldReturnNilAndError
{
    MSIDTokenResult *tokenResult = [self validTokenResult];
    tokenResult.rawIdToken = @"non-empty-id-token";

    NSError *error = nil;
    MSALDeviceTokenResult *result = [MSALDeviceTokenResult resultForDeviceTokenResult:tokenResult error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testResultForDeviceTokenResult_whenAccessTokenValueMissing_shouldReturnNilAndError
{
    MSIDTokenResult *tokenResult = [self validTokenResult];
    tokenResult.accessToken.accessToken = nil;

    NSError *error = nil;
    MSALDeviceTokenResult *result = [MSALDeviceTokenResult resultForDeviceTokenResult:tokenResult error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testResultForDeviceTokenResult_whenAccessTokenValueBlank_shouldReturnNilAndError
{
    MSIDTokenResult *tokenResult = [self validTokenResult];
    tokenResult.accessToken.accessToken = @"   ";

    NSError *error = nil;
    MSALDeviceTokenResult *result = [MSALDeviceTokenResult resultForDeviceTokenResult:tokenResult error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
}

- (void)testResultForDeviceTokenResult_whenAuthorityInvalid_shouldReturnNilAndError
{
    MSIDTokenResult *tokenResult = [self validTokenResult];
    tokenResult.authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"invalid-url"]
                                                        rawTenant:@"common"
                                                          context:nil
                                                            error:nil];
    NSError *error = nil;
    MSALDeviceTokenResult *result = [MSALDeviceTokenResult resultForDeviceTokenResult:tokenResult error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
}

- (void)testResultForDeviceTokenResult_whenValidInput_shouldReturnMappedResult
{
    NSDate *expiryDate = [NSDate dateWithTimeIntervalSince1970:123456];
    MSIDTokenResult *tokenResult = [self validTokenResult];
    tokenResult.accessToken.expiresOn = expiryDate;
    tokenResult.accessToken.scopes = [NSOrderedSet orderedSetWithArray:@[@"scope.read", @"scope.write"]];

    MSIDTokenResponse *tokenResponse = [MSIDTokenResponse new];
    tokenResponse.additionalServerInfo = @{@"device_info" : @"device-info-jwt"};
    tokenResult.tokenResponse = tokenResponse;

    NSError *error = nil;
    MSALDeviceTokenResult *result = [MSALDeviceTokenResult resultForDeviceTokenResult:tokenResult error:&error];

    XCTAssertNotNil(result);
    XCTAssertNil(error);
    XCTAssertEqualObjects(result.accessToken, @"access-token");
    XCTAssertEqualObjects(result.deviceInformation, @"device-info-jwt");
    XCTAssertEqualObjects(result.expiresOn, expiryDate);
    XCTAssertEqualObjects(result.scopes, (@[@"scope.read", @"scope.write"]));
    XCTAssertNotNil(result.authority);
}

- (void)testResultForDeviceTokenResult_whenDeviceInfoNotPresent_shouldReturnResultWithNilDeviceInfo
{
    MSIDTokenResult *tokenResult = [self validTokenResult];
    tokenResult.tokenResponse = [MSIDTokenResponse new];

    NSError *error = nil;
    MSALDeviceTokenResult *result = [MSALDeviceTokenResult resultForDeviceTokenResult:tokenResult error:&error];

    XCTAssertNotNil(result);
    XCTAssertNil(error);
    XCTAssertNil(result.deviceInformation);
}

#pragma mark - Helpers

- (MSIDTokenResult *)validTokenResult
{
    MSIDTokenResult *tokenResult = [MSIDTokenResult new];
    tokenResult.accessToken = [MSIDAccessToken new];
    tokenResult.accessToken.accessToken = @"access-token";
    tokenResult.accessToken.scopes = [NSOrderedSet orderedSetWithArray:@[@"scope.read"]];
    tokenResult.authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                         rawTenant:@"common"
                                                           context:nil
                                                             error:nil];

    return tokenResult;
}

@end


