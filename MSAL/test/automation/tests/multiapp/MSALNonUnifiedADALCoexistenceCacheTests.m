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
#import "NSString+MSIDAutomationUtils.h"

@interface MSALNonUnifiedADALCoexistenceCacheTests : MSALBaseAADUITest

@property (nonatomic) NSString *testEnvironment;

@end

@implementation MSALNonUnifiedADALCoexistenceCacheTests

static BOOL adalAppInstalled = NO;

- (void)setUp
{
    [super setUp];
    
    self.testEnvironment = self.class.confProvider.wwEnvironment;

    // We only need to install app once for all the tests
    // It would be better to use +(void)setUp here, but XCUIApplication launch doesn't work then, so using this mechanism instead
    if (!adalAppInstalled)
    {
        adalAppInstalled = YES;
        [self installAppWithId:@"adal_n_minus_1_ver"];
        [self.testApp activate];
        [self closeResultPipeline:self.testApp];
    }

    MSIDTestAutomationAppConfigurationRequest *appConfigurationRequest = [MSIDTestAutomationAppConfigurationRequest new];
    appConfigurationRequest.testAppAudience = MSIDTestAppAudienceMultipleOrgs;
    appConfigurationRequest.testAppEnvironment = self.testEnvironment;
    
    [self loadTestApp:appConfigurationRequest];
    
    MSIDTestAutomationAccountConfigurationRequest *accountConfigurationRequest = [MSIDTestAutomationAccountConfigurationRequest new];
    accountConfigurationRequest.environmentType = self.testEnvironment;
    
    [self loadTestAccount:accountConfigurationRequest];
}

- (void)testCoexistenceWithNonUnifiedADAL_startSigninInOlderADAL_withAADAccount_andDoTokenRefresh
{
    // 1. Install previous ADAL version and signin
    self.testApp = [self olderADALApp];
    
    MSIDAutomationTestRequest *adalRequest = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    adalRequest.promptBehavior = @"always";
    adalRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"common"];

    NSDictionary *config = [self configWithTestRequest:adalRequest];

    [self acquireToken:config];
    [self aadEnterEmail:self.testApp];
    [self aadEnterPassword:self.testApp];

    NSDictionary *olderAppResult = [self automationResultDictionary:self.testApp];
    XCTAssertNotNil(olderAppResult[@"access_token"]);
    [self closeResultPipeline:self.testApp];

    // 2. Switch to MSAL and acquire token silently with organizations authority
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    MSIDAutomationTestRequest *msalRequest = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    msalRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"organizations"];
    msalRequest.legacyAccountIdentifier = self.primaryAccount.upn;
    msalRequest.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"aad_graph_static"];
    msalRequest.expectedResultScopes = msalRequest.requestScopes;

    // 3. Check accounts are correctly returned
    NSDictionary *configuration = [self configWithTestRequest:msalRequest];
    [self readAccounts:configuration];
    
    MSIDAutomationAccountsResult *legacyAccountsResult = [self automationAccountsResult:self.testApp];
    XCTAssertNotNil(legacyAccountsResult);
    XCTAssertEqual(legacyAccountsResult.accounts.count, 1);
    MSIDAutomationUserInformation *firstAccount = legacyAccountsResult.accounts[0];
    XCTAssertEqualObjects(firstAccount.username, self.primaryAccount.upn);
    [self closeResultPipeline:self.testApp];

    // 4. Run silent tests
    [self runSharedSilentAADLoginWithTestRequest:msalRequest];

    // 5. Check accounts are correctly updated
    [self readAccounts:configuration];
    MSIDAutomationAccountsResult *msalAccountsResult = [self automationAccountsResult:self.testApp];
    XCTAssertNotNil(msalAccountsResult);
    XCTAssertEqual(msalAccountsResult.accounts.count, 1);
    MSIDAutomationUserInformation *firstMSALAccount = msalAccountsResult.accounts[0];
    XCTAssertEqualObjects(firstMSALAccount.username, self.primaryAccount.upn);
    XCTAssertEqualObjects(firstMSALAccount.homeAccountId, self.primaryAccount.homeAccountId);
    [self closeResultPipeline:self.testApp];

    // 6. Switch back to ADAL and make sure ADAL still works
    adalRequest.legacyAccountIdentifier = self.primaryAccount.upn;
    NSDictionary *adalSilentConfig = [self configWithTestRequest:adalRequest];
    self.testApp = [self olderADALApp];
    [self acquireTokenSilent:adalSilentConfig];
    XCTAssertNotNil([self automationResultDictionary:self.testApp][@"access_token"]);
    [self closeResultPipeline:self.testApp];

    [self performAction:@"expireAccessToken" config:adalSilentConfig application:self.testApp];
    [self closeResultPipeline:self.testApp];

    [self acquireTokenSilent:adalSilentConfig];
    XCTAssertNotNil([self automationResultDictionary:self.testApp][@"access_token"]);
    [self closeResultPipeline:self.testApp];
}

- (void)testCoexistenceWithNonUnifiedADAL_startSigninInOlderADAL_andDoAuthorityMigration_andDoTokenRefresh
{
    // 1. Install previous ADAL version and signin
    self.testApp = [self olderADALApp];
    
    MSIDAutomationTestRequest *adalRequest = [self.class.confProvider defaultAppRequest:@"ww-alias" targetTenantId:self.primaryAccount.targetTenantId];
    adalRequest.promptBehavior = @"always";
    adalRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:@"ww-alias" tenantId:@"common"];

    NSDictionary *adalConfig = [self configWithTestRequest:adalRequest];

    [self acquireToken:adalConfig];
    [self aadEnterEmail:self.testApp];
    [self aadEnterPassword:self.testApp];

    NSDictionary *olderAppResult = [self automationResultDictionary:self.testApp];
    XCTAssertNotNil(olderAppResult[@"access_token"]);
    [self closeResultPipeline:self.testApp];

    // 2. Switch to MSAL and acquire token silently with organizations authority
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    // 2. Switch to MSAL and acquire token silently with organizations authority
    self.testApp = [XCUIApplication new];
    [self.testApp activate];
    
    MSIDAutomationTestRequest *msalRequest = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    msalRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"common"];
    msalRequest.legacyAccountIdentifier = self.primaryAccount.upn;
    msalRequest.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"ms_graph"];
    msalRequest.expectedResultScopes = [NSString msidCombinedScopes:msalRequest.requestScopes withScopes:self.class.confProvider.oidcScopes];

    [self runSharedSilentAADLoginWithTestRequest:msalRequest];
}

// TODO: FOCI for MSAL

- (XCUIApplication *)olderADALApp
{
    return [self openAppWithAppId:@"adal_n_minus_1_ver"];
}

@end
