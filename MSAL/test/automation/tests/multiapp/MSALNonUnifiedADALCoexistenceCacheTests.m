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

#import "MSALBaseAADUITest.h"
#import "XCTestCase+TextFieldTap.h"

@interface MSALNonUnifiedADALCoexistenceCacheTests : MSALBaseAADUITest

@end

@implementation MSALNonUnifiedADALCoexistenceCacheTests

static BOOL adalAppInstalled = NO;

- (void)setUp
{
    [super setUp];

    // We only need to install app once for all the tests
    // It would be better to use +(void)setUp here, but XCUIApplication launch doesn't work then, so using this mechanism instead
    if (!adalAppInstalled)
    {
        adalAppInstalled = YES;
        [self installAppWithId:@"adal_n_minus_1_ver"];
        [self.testApp activate];
        [self closeResultView];
    }

    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    configurationRequest.appVersion = MSIDAppVersionV1;
    [self loadTestConfiguration:configurationRequest];
}

- (void)testCoexistenceWithNonUnifiedADAL_startSigninInOlderADAL_withAADAccount_andDoTokenRefresh
{
    // 1. Install previous ADAL version and signin
    self.testApp = [self olderADALApp];

    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.validateAuthority = YES;
    request.additionalParameters = @{@"prompt_behavior": @"always"};

    NSDictionary *config = [self configWithTestRequest:request];

    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];

    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 2. Switch to MSAL and acquire token silently with organizations authority
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    request.authority = @"https://login.microsoftonline.com/organizations";
    request.additionalParameters = @{@"user_legacy_identifier": self.primaryAccount.account};
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.windows.net/%@", self.primaryAccount.targetTenantId];
    request.scopes = @"https://graph.windows.net/.default";
    request.expectedResultScopes = @[@"https://graph.windows.net/.default"];

    // 3. Check accounts are correctly returned
    NSDictionary *configuration = [self configWithTestRequest:request];
    [self readAccounts:configuration];

    NSDictionary *result = [self resultDictionary];
    XCTAssertEqual([result[@"account_count"] integerValue], 1);
    NSArray *accounts = result[@"accounts"];
    NSDictionary *firstAccount = accounts[0];
    XCTAssertEqualObjects(firstAccount[@"username"], self.primaryAccount.account);
    [self closeResultView];

    // 4. Run silent tests
    [self runSharedSilentAADLoginWithTestRequest:request];

    // 5. Check accounts are correctly updated
    configuration = [self configWithTestRequest:request];
    [self readAccounts:configuration];

    result = [self resultDictionary];
    XCTAssertEqual([result[@"account_count"] integerValue], 1);
    accounts = result[@"accounts"];
    firstAccount = accounts[0];
    XCTAssertEqualObjects(firstAccount[@"username"], self.primaryAccount.account);
    XCTAssertEqualObjects(firstAccount[@"home_account_id"], self.primaryAccount.homeAccountId);
    [self closeResultView];

    // 6. Switch back to ADAL and make sure ADAL still works
    request.authority = @"https://login.windows.net/common";
    request.additionalParameters = @{@"user_identifier": self.primaryAccount.account};
    config = [self configWithTestRequest:request];
    self.testApp = [self olderADALApp];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    [self expireAccessToken:config];
    [self assertAccessTokenExpired];
    [self closeResultView];

    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];
}

- (void)testCoexistenceWithNonUnifiedADAL_startSigninInOlderADAL_andDoAuthorityMigration_andDoTokenRefresh
{
    // 1. Install previous ADAL version and signin
    self.testApp = [self olderADALApp];

    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.validateAuthority = YES;
    request.additionalParameters = @{@"prompt_behavior": @"always"};
    request.authority = @"https://login.windows.net/common";

    NSDictionary *config = [self configWithTestRequest:request];

    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];

    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 2. Switch to MSAL and acquire token silently with organizations authority
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    // 2. Switch to MSAL and acquire token silently with organizations authority
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    request.authority = @"https://login.microsoftonline.com/organizations";
    request.additionalParameters = @{@"user_legacy_identifier": self.primaryAccount.account};
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.windows.net/%@", self.primaryAccount.targetTenantId];
    request.scopes = @"https://graph.windows.net/.default";
    request.expectedResultScopes = @[@"https://graph.windows.net/.default"];

    [self runSharedSilentAADLoginWithTestRequest:request];
}

// TODO: FOCI for MSAL

- (XCUIApplication *)olderADALApp
{
    return [self openAppWithAppId:@"adal_n_minus_1_ver"];
}

@end
