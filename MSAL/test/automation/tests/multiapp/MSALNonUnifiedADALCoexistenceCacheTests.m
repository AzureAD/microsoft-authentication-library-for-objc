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
    // Install previous ADAL version
    self.testApp = [self olderADALApp];

    NSDictionary *params = @{
                             @"prompt_behavior" : @"always",
                             @"validate_authority" : @YES
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];

    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];

    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Switch to MSAL
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.authority = @"https://login.microsoftonline.com/organizations";
    

    // Acquire token silent

    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Expire access token
    [self expireAccessToken:config];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // Now do token refresh
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];
}

- (void)testCoexistenceWithNonUnifiedADAL_startSigninInUnifiedADAL_withAADAccount_andDoTokenRefresh
{
    // Sign in the new test app
    NSDictionary *params = @{
                             @"prompt_behavior" : @"always",
                             @"validate_authority" : @YES
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];

    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];

    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Switch to the previous version
    self.testApp = [self olderADALApp];

    // Acquire token silent
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Expire access token
    NSDictionary *expireParams = @{
                                   @"authority": @"https://login.windows.net/common"
                                   };

    NSDictionary *expireConfig = [self.testConfiguration configWithAdditionalConfiguration:expireParams];

    [self expireAccessToken:expireConfig];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // Now do token refresh
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];
}

- (void)testCoexistenceWithNonUnifiedADAL_startSigninInOlderADAL_withADFSOnPremAccount_andDoTokenRefresh
{
    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.appVersion = MSIDAppVersionOnPrem;
    configurationRequest.accountProvider = MSIDTestAccountProviderADfsv3;
    configurationRequest.accountFeatures = @[];
    [self loadTestConfiguration:configurationRequest];

    // Sign into the current version
    NSDictionary *params = @{
                             @"prompt_behavior" : @"always",
                             @"user_identifier": self.primaryAccount.account,
                             @"validate_authority" : @NO
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];

    [self acquireToken:config];
    [self enterADFSPassword];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Switch to the previous version
    self.testApp = [self olderADALApp];

    // Do silent first
    config = [self.testConfiguration configWithAdditionalConfiguration:@{@"validate_authority" : @NO}];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Now expire access token
    [self expireAccessToken:config];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // Now do access token refresh
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Switch back to the current version and do silent again
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Now expire access token
    [self expireAccessToken:config];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // Now do access token refresh
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];
}

- (void)testCoexistenceWithNonUnifiedADAL_startSigninInOlderADAL_withAADAccount_andDoAuthorityMigration
{
    // Sign in the new test app
    NSDictionary *params = @{
                             @"prompt_behavior" : @"always",
                             @"validate_authority" : @YES,
                             @"authority": @"https://login.windows.net/common"
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];

    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];

    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Switch to the previous version
    self.testApp = [self olderADALApp];

    params = @{@"prompt_behavior" : @"always", @"validate_authority" : @YES};
    NSDictionary *config2 = [self.testConfiguration configWithAdditionalConfiguration:params];

    [self acquireTokenSilent:config2];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    [self expireAccessToken:config];
    [self assertAccessTokenExpired];
    [self closeResultView];

    [self acquireTokenSilent:config2];
    [self assertAccessTokenNotNil];
    [self closeResultView];
}

- (void)testCoexistenceWithNonUnifiedADAL_startSigninInOlderADAL_withAADAccount_andUseFociToken
{
    self.testApp = [self olderADALApp];

    NSDictionary *params = @{
                             @"prompt_behavior" : @"always",
                             @"validate_authority" : @YES,
                             @"client_id": @"d3590ed6-52b3-4102-aeff-aad2292ab01c",
                             @"redirect_uri": @"urn:ietf:wg:oauth:2.0:oob",
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];
    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Switch back to the new ADAL app
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    params = @{
               @"prompt_behavior" : @"always",
               @"validate_authority" : @YES,
               @"client_id": @"af124e86-4e96-495a-b70a-90f90ab96707",
               @"redirect_uri": @"ms-onedrive://com.microsoft.skydrive"
               };

    NSDictionary *config2 = [self.testConfiguration configWithAdditionalConfiguration:params];

    [self acquireTokenSilent:config2];
    [self assertAccessTokenNotNil];
}

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
