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

// #296895
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

    // 2. Switch to MSAL and acquire token silently with common authority
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    request.authority = @"https://login.windows.net/common";
    request.additionalParameters = @{@"user_legacy_identifier": self.primaryAccount.account};
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    [self runSharedSilentAADLoginWithTestRequest:request];

    // 3. Acquire token silently with organizations authority
    request.authority = @"https://login.windows.net/organizations";
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testCoexistenceWithNonUnifiedADAL_startSigninInMSAL_withAADAccount_andDoTokenRefresh
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.authority = @"https://login.windows.net/organizations";
    request.loginHint = self.primaryAccount.account;
    request.testAccount = self.primaryAccount;

    // 1. Sign into the MSAL test app
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2.Switch to non-unified ADAL and acquire token silently with common authority
    self.testApp = [self olderADALApp];
    request.additionalParameters = @{@"prompt_behavior": @"always"};
    request.authority = @"https://login.microsoftonline.com/common";
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 3. Now expire token in non-unified ADAL
    [self expireAccessToken:config];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // 4. Now acquire token silently
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 5. Run token refresh in MSAL again
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    request.accountIdentifier = homeAccountId;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

// TODO: authority migration
// TODO: FOCI

- (XCUIApplication *)olderADALApp
{
    NSDictionary *appConfiguration = [self.class.accountsProvider appInstallForConfiguration:@"adal_n_minus_1_ver"];
    NSString *appBundleId = appConfiguration[@"app_bundle_id"];

    XCUIApplication *olderApp = [[XCUIApplication alloc] initWithBundleIdentifier:appBundleId];
    [olderApp activate];
    BOOL result = [olderApp waitForState:XCUIApplicationStateRunningForeground timeout:30.0f];
    XCTAssertTrue(result);
    return olderApp;
}

#pragma mark - Private

- (void)enterADFSPassword
{
    XCUIElement *passwordTextField = self.testApp.secureTextFields[@"Password"];
    [self waitForElement:passwordTextField];
    [self tapElementAndWaitForKeyboardToAppear:passwordTextField];
    [passwordTextField typeText:[NSString stringWithFormat:@"%@\n", self.primaryAccount.password]];
}

@end
