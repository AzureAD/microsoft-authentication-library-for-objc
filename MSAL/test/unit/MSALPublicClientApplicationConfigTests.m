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
#import "MSALPublicClientApplicationConfig.h"
#import "MSALAADAuthority.h"
#import "MSALSliceConfig.h"
#import "MSALCacheConfig.h"
#import "MSALPublicClientApplicationConfig+Internal.h"
#import "MSALExtraQueryParameters.h"

@interface MSALPublicClientApplicationConfigTests : XCTestCase

@end

@implementation MSALPublicClientApplicationConfigTests

- (void)testInitWithClient_shouldSetClientId_andInitializeDefaultValues
{
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"test_client_id"];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(config.clientId, @"test_client_id");
    XCTAssertNil(config.redirectUri);
    NSURL *expectedAuthorityURL = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    XCTAssertEqualObjects(config.authority.url, expectedAuthorityURL);
    XCTAssertNil(config.knownAuthorities);
    XCTAssertNil(config.clientApplicationCapabilities);
    XCTAssertEqualWithAccuracy(config.tokenExpirationBuffer, 300, 1);
    XCTAssertNil(config.sliceConfig.dc);
    XCTAssertNil(config.sliceConfig.slice);
    XCTAssertNil(config.sliceConfig);
    XCTAssertNotNil(config.cacheConfig);
#if TARGET_OS_IPHONE
    XCTAssertEqualObjects(config.cacheConfig.keychainSharingGroup, @"com.microsoft.adalcache");
#endif
    XCTAssertNil(config.verifiedRedirectUri);
    XCTAssertNotNil(config.extraQueryParameters);
    XCTAssertFalse(config.extendedLifetimeEnabled);
}

- (void)testInitWithClientId_andRedirectUri_andAuthority_shouldSetParameters_andInitializeDefaultValues
{
    MSALAADAuthority *testAuthority = [[MSALAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/mytesttenant"] error:nil];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"test_client_id" redirectUri:@"testredirect" authority:testAuthority];
    XCTAssertNotNil(config);
    XCTAssertEqualObjects(config.clientId, @"test_client_id");
    XCTAssertEqualObjects(config.redirectUri, @"testredirect");
    XCTAssertEqualObjects(config.authority.url, testAuthority.url);
    XCTAssertNil(config.knownAuthorities);
    XCTAssertNil(config.clientApplicationCapabilities);
    XCTAssertEqualWithAccuracy(config.tokenExpirationBuffer, 300, 1);
    XCTAssertNil(config.sliceConfig.dc);
    XCTAssertNil(config.sliceConfig.slice);
    XCTAssertNil(config.sliceConfig);
    XCTAssertNotNil(config.cacheConfig);
#if TARGET_OS_IPHONE
    XCTAssertEqualObjects(config.cacheConfig.keychainSharingGroup, @"com.microsoft.adalcache");
#endif
    XCTAssertNil(config.verifiedRedirectUri);
    XCTAssertNotNil(config.extraQueryParameters);
    XCTAssertFalse(config.extendedLifetimeEnabled);
}

- (void)testCopyConfig_whenNotAllConfigSet_shouldCreateExactCopy
{
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"test_client_id"];
    XCTAssertNotNil(config);
    
    MSALPublicClientApplicationConfig *copiedConfig = [config copy];
    
    XCTAssertEqualObjects(copiedConfig.clientId, @"test_client_id");
    XCTAssertNil(copiedConfig.redirectUri);
    NSURL *expectedAuthorityURL = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    XCTAssertEqualObjects(copiedConfig.authority.url, expectedAuthorityURL);
    XCTAssertNil(copiedConfig.knownAuthorities);
    XCTAssertNil(copiedConfig.clientApplicationCapabilities);
    XCTAssertEqualWithAccuracy(copiedConfig.tokenExpirationBuffer, 300, 1);
    XCTAssertNil(copiedConfig.sliceConfig.dc);
    XCTAssertNil(copiedConfig.sliceConfig.slice);
    XCTAssertNil(copiedConfig.sliceConfig);
    XCTAssertNotNil(copiedConfig.cacheConfig);
#if TARGET_OS_IPHONE
    XCTAssertEqualObjects(copiedConfig.cacheConfig.keychainSharingGroup, @"com.microsoft.adalcache");
#endif
    XCTAssertNil(copiedConfig.verifiedRedirectUri);
    XCTAssertNotNil(copiedConfig.extraQueryParameters);
    XCTAssertFalse(copiedConfig.extendedLifetimeEnabled);
}

- (void)testCopyConfig_whenAllConfigSet_shouldCreateExactCopy
{
    MSALAADAuthority *testAuthority = [[MSALAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/mytesttenant"] error:nil];
    MSALAADAuthority *knownAuthority = [[MSALAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/myknowntenant"] error:nil];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"test_client_id" redirectUri:@"testredirect" authority:testAuthority];
    config.knownAuthorities = @[knownAuthority];
    config.clientApplicationCapabilities = @[@"cp1", @"cp2"];
    config.tokenExpirationBuffer = 333;
    config.sliceConfig = [[MSALSliceConfig alloc] initWithSlice:@"myslice" dc:@"mydc"];
    config.cacheConfig.keychainSharingGroup = @"my.test.group";
    config.extendedLifetimeEnabled = YES;
    
    MSALPublicClientApplicationConfig *copiedConfig = [config copy];
    XCTAssertNotNil(copiedConfig);
    XCTAssertEqualObjects(copiedConfig.clientId, @"test_client_id");
    XCTAssertEqualObjects(copiedConfig.redirectUri, @"testredirect");
    XCTAssertEqualObjects(copiedConfig.authority.url, testAuthority.url);
    XCTAssertEqual([copiedConfig.knownAuthorities count], 1);
    XCTAssertEqualObjects(copiedConfig.knownAuthorities[0].url, knownAuthority.url);
    XCTAssertEqual([copiedConfig.clientApplicationCapabilities count], 2);
    NSArray *expectedCapabilities = @[@"cp1", @"cp2"];
    XCTAssertEqualObjects(copiedConfig.clientApplicationCapabilities, expectedCapabilities);
    XCTAssertEqualWithAccuracy(copiedConfig.tokenExpirationBuffer, 333, 1);
    XCTAssertEqualObjects(copiedConfig.sliceConfig.dc, @"mydc");
    XCTAssertEqualObjects(copiedConfig.sliceConfig.slice, @"myslice");
    XCTAssertNotNil(copiedConfig.sliceConfig);
    XCTAssertNotNil(copiedConfig.cacheConfig);
#if TARGET_OS_IPHONE
    XCTAssertEqualObjects(copiedConfig.cacheConfig.keychainSharingGroup, @"my.test.group");
#endif
    XCTAssertNil(copiedConfig.verifiedRedirectUri);
    XCTAssertNotNil(copiedConfig.extraQueryParameters);
    NSDictionary *expectedQP = @{@"slice":@"myslice", @"dc": @"mydc"};
    XCTAssertEqualObjects(copiedConfig.extraQueryParameters.extraURLQueryParameters, expectedQP);
    XCTAssertEqualObjects(copiedConfig.extraQueryParameters.extraAuthorizeURLQueryParameters, @{});
    XCTAssertEqualObjects(copiedConfig.extraQueryParameters.extraTokenURLParameters, @{});
    XCTAssertTrue(copiedConfig.extendedLifetimeEnabled);
}

@end
