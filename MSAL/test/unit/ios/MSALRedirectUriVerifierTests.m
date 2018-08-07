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
#import "MSALTestBundle.h"
#import "MSALRedirectUriVerifier.h"

@interface MSALRedirectUriVerifierTests : MSALTestCase

@end

@implementation MSALRedirectUriVerifierTests

- (void)setUp
{
    [super setUp];
    NSArray *urlTypes = @[@{@"CFBundleURLSchemes": @[@"msalclient"]}];
    [MSALTestBundle overrideObject:urlTypes forKey:@"CFBundleURLTypes"];
    [MSALTestBundle overrideBundleId:@"test.bundle.identifier"];
}

- (void)testGenerateRedirectUri_whenNilInputClientId_shouldReturnNilAndFillError
{
    NSError *outError = nil;
    NSURL *result = [MSALRedirectUriVerifier generateRedirectUri:@"" clientId:nil brokerEnabled:NO error:&outError];
    XCTAssertNil(result);
    XCTAssertNotNil(outError);
}

- (void)testGenerateRedirectUri_whenNonNilInputRedirectUri_shouldReturnRedirectUriNilError
{
    NSError *outError = nil;
    NSURL *result = [MSALRedirectUriVerifier generateRedirectUri:@"https://localhost" clientId:@"client" brokerEnabled:NO error:&outError];
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result, [NSURL URLWithString:@"https://localhost"]);
    XCTAssertNil(outError);
}

- (void)testGenerateRedirectUri_whenNilInputRedirectUri_brokerEnabledNO_shouldGenerateNonBrokerUrl
{
    NSError *outError = nil;
    NSURL *result = [MSALRedirectUriVerifier generateRedirectUri:nil clientId:@"client" brokerEnabled:NO error:&outError];
    XCTAssertEqualObjects(result, [NSURL URLWithString:@"msalclient://auth"]);
    XCTAssertNil(outError);
}

- (void)testGenerateRedirectUri_whenNilInputRedirectUri_brokerEnabledYES_shouldGenerateBrokerRedirectUri
{
    NSError *outError = nil;
    NSURL *result = [MSALRedirectUriVerifier generateRedirectUri:nil clientId:@"client" brokerEnabled:YES error:&outError];
    XCTAssertEqualObjects(result, [NSURL URLWithString:@"msalclient://test.bundle.identifier"]);
    XCTAssertNil(outError);
}

- (void)testVerifyRedirectUri_whenSchemeIsRegistered_brokerEnabledNO_shouldReturnYESNilError
{
    NSURL *inputURL = [NSURL URLWithString:@"msalclient://auth"];
    NSError *outError = nil;
    BOOL result = [MSALRedirectUriVerifier verifyRedirectUri:inputURL brokerEnabled:NO error:&outError];
    XCTAssertTrue(result);
    XCTAssertNil(outError);
}

- (void)testVerifyRedirectUri_whenSchemeIsHttpsScheme_brokerEnabledNO_shouldReturnYESNilError
{
    NSURL *inputURL = [NSURL URLWithString:@"https://auth"];
    NSError *outError = nil;
    BOOL result = [MSALRedirectUriVerifier verifyRedirectUri:inputURL brokerEnabled:NO error:&outError];
    XCTAssertTrue(result);
    XCTAssertNil(outError);
}


- (void)testVerifyRedirectUri_whenSchemeIsNotRegistered_brokerEnabledNO_shouldReturnNOAndFillError
{
    NSURL *inputURL = [NSURL URLWithString:@"msalclient2://auth"];
    NSError *outError = nil;
    BOOL result = [MSALRedirectUriVerifier verifyRedirectUri:inputURL brokerEnabled:NO error:&outError];
    XCTAssertFalse(result);
    XCTAssertNotNil(outError);
}


- (void)testVerifyRedirectUri_whenSchemeIsRegistered_brokerEnabledYES_andInvalidHost_shouldReturnNOAndFillError
{
    NSURL *inputURL = [NSURL URLWithString:@"msalclient://auth"];
    NSError *outError = nil;
    BOOL result = [MSALRedirectUriVerifier verifyRedirectUri:inputURL brokerEnabled:YES error:&outError];
    XCTAssertFalse(result);
    XCTAssertNotNil(outError);
}

- (void)testVerifyRedirectUri_whenSchemeIsRegistered_brokerEnabledYES_andValidHost_shouldReturnYESNilError
{
    NSURL *inputURL = [NSURL URLWithString:@"msalclient://test.bundle.identifier"];
    NSError *outError = nil;
    BOOL result = [MSALRedirectUriVerifier verifyRedirectUri:inputURL brokerEnabled:YES error:&outError];
    XCTAssertTrue(result);
    XCTAssertNil(outError);
}


@end
