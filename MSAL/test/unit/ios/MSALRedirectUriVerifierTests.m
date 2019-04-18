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
#import "MSALRedirectUri.h"

@interface MSALRedirectUriVerifierTests : MSALTestCase

@end

@implementation MSALRedirectUriVerifierTests

- (void)testMSALRedirectUri_whenCustomRedirectUri_andNotBrokerCapable_shouldReturnUriBrokerCapableNo
{
    NSArray *urlTypes = @[@{@"CFBundleURLSchemes": @[@"myapp"]}];
    [MSALTestBundle overrideObject:urlTypes forKey:@"CFBundleURLTypes"];
    [MSALTestBundle overrideBundleId:@"test.bundle.identifier"];

    NSString *redirectUri = @"myapp://authtest";
    NSString *clientId = @"msalclient";

    NSError *error = nil;
    MSALRedirectUri *result = [MSALRedirectUriVerifier msalRedirectUriWithCustomUri:redirectUri clientId:clientId error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.url.absoluteString, redirectUri);
    XCTAssertFalse(result.brokerCapable);
    XCTAssertNil(error);
}

- (void)testMSALRedirectUri_whenCustomRedirectUri_andBrokerCapable_shouldReturnUriBrokerCapableYes
{
    NSArray *urlTypes = @[@{@"CFBundleURLSchemes": @[@"msauth.test.bundle.identifier"]}];
    [MSALTestBundle overrideObject:urlTypes forKey:@"CFBundleURLTypes"];
    [MSALTestBundle overrideBundleId:@"test.bundle.identifier"];

    NSString *redirectUri = @"msauth.test.bundle.identifier://auth";
    NSString *clientId = @"msalclient";

    NSError *error = nil;
    MSALRedirectUri *result = [MSALRedirectUriVerifier msalRedirectUriWithCustomUri:redirectUri clientId:clientId error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.url.absoluteString, redirectUri);
    XCTAssertTrue(result.brokerCapable);
    XCTAssertNil(error);
}

- (void)testMSALRedirectUri_whenCustomRedirectUri_andLegacyBrokerCapable_shouldReturnUriBrokerCapableYes
{
    NSArray *urlTypes = @[@{@"CFBundleURLSchemes": @[@"myscheme"]}];
    [MSALTestBundle overrideObject:urlTypes forKey:@"CFBundleURLTypes"];
    [MSALTestBundle overrideBundleId:@"test.bundle.identifier"];

    NSString *redirectUri = @"myscheme://test.bundle.identifier";
    NSString *clientId = @"msalclient";

    NSError *error = nil;
    MSALRedirectUri *result = [MSALRedirectUriVerifier msalRedirectUriWithCustomUri:redirectUri clientId:clientId error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.url.absoluteString, redirectUri);
    XCTAssertTrue(result.brokerCapable);
    XCTAssertNil(error);
}

- (void)testMSALRedirectUri_whenCustomRedirectUri_andNotRegistered_shouldReturnNilAndFillError
{
    NSArray *urlTypes = @[@{@"CFBundleURLSchemes": @[@"myscheme"]}];
    [MSALTestBundle overrideObject:urlTypes forKey:@"CFBundleURLTypes"];
    [MSALTestBundle overrideBundleId:@"test.bundle.identifier"];

    NSString *redirectUri = @"notregistered://test.bundle.identifier";
    NSString *clientId = @"msalclient";

    NSError *error = nil;
    MSALRedirectUri *result = [MSALRedirectUriVerifier msalRedirectUriWithCustomUri:redirectUri clientId:clientId error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorRedirectSchemeNotRegistered);
}

- (void)testMSALRedirectUri_whenDefaultRedirectUri_andBrokerCapableUrlRegistered_shouldReturnUriAndBrokerCapableYes
{
    NSArray *urlTypes = @[@{@"CFBundleURLSchemes": @[@"msauth.test.bundle.identifier"]}];
    [MSALTestBundle overrideObject:urlTypes forKey:@"CFBundleURLTypes"];
    [MSALTestBundle overrideBundleId:@"test.bundle.identifier"];

    NSString *clientId = @"msalclient";

    NSError *error = nil;
    MSALRedirectUri *result = [MSALRedirectUriVerifier msalRedirectUriWithCustomUri:nil clientId:clientId error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.url.absoluteString, @"msauth.test.bundle.identifier://auth");
    XCTAssertTrue(result.brokerCapable);
    XCTAssertNil(error);
}

- (void)testMSALRedirectUri_whenDefaultRedirectUri_andDefaultUrlRegistered_shouldReturnUriAndBrokerCapableNo
{
    NSArray *urlTypes = @[@{@"CFBundleURLSchemes": @[@"msalmsalclient"]}];
    [MSALTestBundle overrideObject:urlTypes forKey:@"CFBundleURLTypes"];
    [MSALTestBundle overrideBundleId:@"test.bundle.identifier"];

    NSString *clientId = @"msalclient";

    NSError *error = nil;
    MSALRedirectUri *result = [MSALRedirectUriVerifier msalRedirectUriWithCustomUri:nil clientId:clientId error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.url.absoluteString, @"msalmsalclient://auth");
    XCTAssertFalse(result.brokerCapable);
    XCTAssertNil(error);
}

- (void)testMSALRedirectUri_whenNoRedirectUriRegistered_shouldReturnNilAndFillError
{
    NSArray *urlTypes = @[@{@"CFBundleURLSchemes": @[@"myscheme"]}];
    [MSALTestBundle overrideObject:urlTypes forKey:@"CFBundleURLTypes"];
    [MSALTestBundle overrideBundleId:@"test.bundle.identifier"];
    NSString *clientId = @"msalclient";
    NSError *error = nil;
    
    MSALRedirectUri *result = [MSALRedirectUriVerifier msalRedirectUriWithCustomUri:nil clientId:clientId error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorRedirectSchemeNotRegistered);
    XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:@"\"msauth.test.bundle.identifier\""]);
    XCTAssertTrue([error.userInfo[MSIDErrorDescriptionKey] containsString:@"\"msauth.test.bundle.identifier://auth\""]);
}

@end
