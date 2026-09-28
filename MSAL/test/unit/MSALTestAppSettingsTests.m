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
#import "../app/MSALTestAppSettings.h"

@interface MSALTestAppSettingsTests : XCTestCase
@property (nonatomic) NSString *originalProfile;
@end

@implementation MSALTestAppSettingsTests

- (void)setUp
{
    [super setUp];
    self.originalProfile = [MSALTestAppSettings currentProfileName];
}

- (void)tearDown
{
    [[MSALTestAppSettings settings] setCurrentProfileByName:self.originalProfile];
    [super tearDown];
}

- (void)testCustomProfileDoesNotChangeBuiltInConfiguration
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    NSString *builtInName = [MSALTestAppSettings profileNames].firstObject;
    XCTAssertTrue([settings setCurrentProfileByName:builtInName]);
    NSDictionary *builtIn = [[MSALTestAppSettings currentProfile] copy];

    settings.customClientId = @"00000000-0000-4000-8000-000000000001";
    settings.customRedirectUri = @"msauth.test.app://auth";
    XCTAssertTrue([settings setCurrentProfileByName:@"Custom"]);
    XCTAssertEqualObjects([MSALTestAppSettings currentProfile][MSAL_APP_CLIENT_ID],
                          settings.customClientId);
    XCTAssertEqualObjects([MSALTestAppSettings currentProfile][MSAL_APP_REDIRECT_URI],
                          settings.customRedirectUri);
    XCTAssertTrue([settings validateCurrentProfileWithError:nil]);

    XCTAssertTrue([settings setCurrentProfileByName:builtInName]);
    XCTAssertEqualObjects([MSALTestAppSettings currentProfile], builtIn);
    XCTAssertFalse([settings setCurrentProfileByName:@"Unknown profile"]);
}

- (void)testCustomProfileRejectsMalformedFields
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    XCTAssertTrue([settings setCurrentProfileByName:@"Custom"]);
    settings.customClientId = @"not-a-uuid";
    settings.customRedirectUri = @"msauth.test.app://auth";
    NSError *error = nil;
    XCTAssertFalse([settings validateCurrentProfileWithError:&error]);
    XCTAssertNotNil(error.localizedDescription);

    settings.customClientId = @"00000000-0000-4000-8000-000000000001";
    settings.customRedirectUri = @"not a redirect uri";
    error = nil;
    XCTAssertFalse([settings validateCurrentProfileWithError:&error]);
    XCTAssertNotNil(error.localizedDescription);
}

- (void)testArbitraryScopesAreAtomicAndValidated
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    NSError *error = nil;
    XCTAssertTrue([settings setScopesFromString:@"User.Read, api://example.test/read" error:&error]);
    NSSet *expectedScopes = [NSSet setWithArray:@[@"User.Read", @"api://example.test/read"]];
    XCTAssertEqualObjects(settings.scopes, expectedScopes);
    XCTAssertFalse([settings setScopesFromString:@"User.Read,,Mail.Read" error:&error]);
    XCTAssertNotNil(error.localizedDescription);
    XCTAssertEqual(settings.scopes.count, 2u);
    XCTAssertFalse([settings setScopesFromString:@"https:/malformed" error:&error]);
    XCTAssertEqual(settings.scopes.count, 2u);
}

- (void)testPresetsArePlatformFilteredAndDoNotContainIdentity
{
    NSArray *ios = [MSALTestAppSettings configurationPresetsForPlatform:@"ios"];
    NSArray *mac = [MSALTestAppSettings configurationPresetsForPlatform:@"mac"];
    XCTAssertEqual(ios.count, 5u);
    XCTAssertEqual(mac.count, 1u);
    NSUInteger tenantAuthorityPresets = 0;
    NSUInteger chinaAuthorityPresets = 0;
    for (NSDictionary *preset in [ios arrayByAddingObjectsFromArray:mac])
    {
        XCTAssertNotNil(preset[@"sources"]);
        XCTAssertNil(preset[@"clientId"]);
        XCTAssertNil(preset[@"redirectUri"]);
        XCTAssertNil(preset[@"loginHint"]);
        XCTAssertNil(preset[@"account"]);
        XCTAssertNil(preset[@"action"]);
        XCTAssertFalse([preset[@"sources"] containsString:@"3417087"]);
        if ([preset[@"requiresTenantAuthority"] boolValue])
        {
            tenantAuthorityPresets++;
            XCTAssertNil(preset[@"authority"]);
        }
        if ([preset[@"authority"] isEqualToString:@"https://login.partner.microsoftonline.cn/common"])
        {
            chinaAuthorityPresets++;
            XCTAssertEqualObjects(preset[@"scope"], @"https://microsoftgraph.chinacloudapi.cn/.default");
        }
    }
    XCTAssertEqual(tenantAuthorityPresets, 1u);
    XCTAssertEqual(chinaAuthorityPresets, 1u);
}

@end
