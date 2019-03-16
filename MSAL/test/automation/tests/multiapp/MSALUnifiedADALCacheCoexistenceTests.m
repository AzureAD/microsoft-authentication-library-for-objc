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

@interface MSALUnifiedADALCacheCoexistenceTests : MSALBaseAADUITest

@property (nonatomic) NSString *testEnvironment;

@end

@implementation MSALUnifiedADALCacheCoexistenceTests

static BOOL adalAppInstalled = NO;

#pragma mark - Setup

- (void)setUp
{
    [super setUp];
    
    self.testEnvironment = self.class.confProvider.wwEnvironment;

    // We only need to install app once for all the tests
    // It would be better to use +(void)setUp here, but XCUIApplication launch doesn't work then, so using this mechanism instead
    if (!adalAppInstalled)
    {
        adalAppInstalled = YES;
        [self installAppWithId:@"adal_unified"];
        [self.testApp activate];
        [self closeResultView];
    }

    MSIDAutomationConfigurationRequest *configurationRequest = [MSIDAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    [self loadTestConfiguration:configurationRequest];
}

#pragma mark - Tests

- (void)testCoexistenceWithUnifiedADAL_startSigninInADAL_withAADAccount_andDoTokenRefresh
{
    // 1. Install previous ADAL version and signin
    self.testApp = [self adalUnifiedApp];
    
    MSIDAutomationTestRequest *adalRequest = [self.class.confProvider defaultNonConvergedAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    adalRequest.promptBehavior = @"always";
    adalRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"common"];

    NSDictionary *adalConfig = [self configWithTestRequest:adalRequest];

    [self acquireToken:adalConfig];
    [self aadEnterEmail];
    [self aadEnterPassword];

    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 2. Switch to MSAL and acquire token silently with organizations authority
    self.testApp = [XCUIApplication new];
    [self.testApp activate];
    
    MSIDAutomationTestRequest *msalRequest = [self.class.confProvider defaultNonConvergedAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    msalRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"organizations"];
    msalRequest.legacyAccountIdentifier = self.primaryAccount.account;
    msalRequest.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"aad_graph_static"];
    msalRequest.expectedResultScopes = msalRequest.requestScopes;
    
    // 3. Check accounts are correctly returned
    [self readAccounts:[self configWithTestRequest:msalRequest]];
    MSIDAutomationAccountsResult *legacyAccountsResult = [self automationAccountsResult];
    XCTAssertNotNil(legacyAccountsResult);
    XCTAssertEqual(legacyAccountsResult.accounts.count, 1);
    MSIDAutomationUserInformation *firstAccount = legacyAccountsResult.accounts[0];
    XCTAssertEqualObjects(firstAccount.username, self.primaryAccount.account);
    [self closeResultView];

    // 4. Run silent tests
    [self runSharedSilentAADLoginWithTestRequest:msalRequest];

    // 5. Check accounts are correctly updated
    [self readAccounts:[self configWithTestRequest:msalRequest]];
    MSIDAutomationAccountsResult *msalAccountsResult = [self automationAccountsResult];
    XCTAssertNotNil(msalAccountsResult);
    XCTAssertEqual(msalAccountsResult.accounts.count, 1);
    MSIDAutomationUserInformation *firstMSALAccount = msalAccountsResult.accounts[0];
    XCTAssertEqualObjects(firstMSALAccount.username, self.primaryAccount.account);
    XCTAssertEqualObjects(firstMSALAccount.homeAccountId, self.primaryAccount.homeAccountId);
    [self closeResultView];
    
    // 6. Switch back to ADAL and make sure ADAL still works
    adalRequest.legacyAccountIdentifier = self.primaryAccount.account;
    adalRequest.cacheAuthority = adalRequest.configurationAuthority;
    NSDictionary *adalSilentConfig = [self configWithTestRequest:adalRequest];
    self.testApp = [self adalUnifiedApp];
    [self acquireTokenSilent:adalSilentConfig];
    [self assertAccessTokenNotNil];
    [self closeResultView];
    
    [self expireAccessToken:adalSilentConfig];
    [self assertAccessTokenExpired];
    [self closeResultView];
    
    [self acquireTokenSilent:adalSilentConfig];
    [self assertAccessTokenNotNil];
    [self closeResultView];
}

- (void)testCoexistenceWithUnifiedADAL_startSigninInMSAL_withAADAccount_andDoTokenRefresh
{
    MSIDAutomationTestRequest *msalRequest = [self.class.confProvider defaultNonConvergedAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    msalRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:nil];
    msalRequest.promptBehavior = @"force";
    msalRequest.loginHint = self.primaryAccount.account;
    msalRequest.testAccount = self.primaryAccount;
    msalRequest.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"aad_graph_static"];
    msalRequest.expectedResultScopes = msalRequest.requestScopes;

    // 1. Sign into the MSAL test app
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:msalRequest];
    XCTAssertNotNil(homeAccountId);

    // 2.Switch to unified ADAL and acquire token silently with common authority
    self.testApp = [self adalUnifiedApp];
    
    MSIDAutomationTestRequest *adalRequest = [self.class.confProvider defaultNonConvergedAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    adalRequest.promptBehavior = @"always";
    adalRequest.requestResource = [self.class.confProvider resourceForEnvironment:self.testEnvironment type:@"aad_graph"];
    adalRequest.legacyAccountIdentifier = self.primaryAccount.account;
    adalRequest.configurationAuthority = msalRequest.configurationAuthority;
    adalRequest.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"common"];
    
    NSDictionary *adalConfig = [self configWithTestRequest:adalRequest];
    [self acquireTokenSilent:adalConfig];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 3. Now expire token in non-unified ADAL
    [self expireAccessToken:adalConfig];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // 4. Now acquire token silently
    [self acquireTokenSilent:adalConfig];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 5. Run token refresh in MSAL again
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    msalRequest.homeAccountIdentifier = homeAccountId;
    [self runSharedSilentAADLoginWithTestRequest:msalRequest];
}

- (void)testCoexistenceWithUnifiedADAL_startSigninInMSAL_withAADAccount_andDoTokenRefresh_withFOCIToken
{
    MSIDAutomationTestRequest *firstAppRequest = [self.class.confProvider defaultFociRequestWithBroker];
    firstAppRequest.promptBehavior = @"force";
    firstAppRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:@"ww-alias" tenantId:@"organizations"];
    firstAppRequest.loginHint = self.primaryAccount.account;
    firstAppRequest.testAccount = self.primaryAccount;
    firstAppRequest.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"aad_graph_static"];
    firstAppRequest.expectedResultScopes = firstAppRequest.requestScopes;
    firstAppRequest.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.targetTenantId];

    // 1. Sign into the MSAL test app
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:firstAppRequest];
    XCTAssertNotNil(homeAccountId);

    // 2.Switch to unified ADAL and acquire token silently with common authority
    self.testApp = [self adalUnifiedApp];
    MSIDAutomationTestRequest *secondAppRequest = [self.class.confProvider defaultFociRequestWithoutBroker];
    secondAppRequest.promptBehavior = @"always";
    secondAppRequest.requestResource = [self.class.confProvider resourceForEnvironment:self.testEnvironment type:@"aad_graph"];
    secondAppRequest.legacyAccountIdentifier = self.primaryAccount.account;
    secondAppRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"common"];
    
    NSDictionary *adalConfig = [self configWithTestRequest:secondAppRequest];
    [self acquireTokenSilent:adalConfig];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 3. Now expire token in non-unified ADAL
    [self expireAccessToken:adalConfig];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // 4. Now acquire token silently
    [self acquireTokenSilent:adalConfig];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 5. Run token refresh in MSAL again
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    firstAppRequest.homeAccountIdentifier = homeAccountId;
    [self runSharedSilentAADLoginWithTestRequest:firstAppRequest];
}

- (XCUIApplication *)adalUnifiedApp
{
    return [self openAppWithAppId:@"adal_unified"];
}

- (void)testMSALCoexistenceWithUnifiedADAL_startSigninInADAL_withAADAccount_andDoTokenRefreshInMSAL_withFOCIToken
{
    // 1. Install previous ADAL version and signin
    self.testApp = [self adalUnifiedApp];
    
    MSIDAutomationTestRequest *adalRequest = [self.class.confProvider defaultFociRequestWithoutBroker];
    adalRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"common"];
    adalRequest.cacheAuthority = adalRequest.configurationAuthority;
    adalRequest.promptBehavior = @"always";
    adalRequest.requestResource = [self.class.confProvider resourceForEnvironment:self.testEnvironment type:@"aad_graph"];
    
    NSDictionary *adalConfig = [self configWithTestRequest:adalRequest];
    
    [self acquireToken:adalConfig];
    [self aadEnterEmail];
    [self aadEnterPassword];
    
    [self assertAccessTokenNotNil];
    [self closeResultView];
    
    // 5. Run token refresh using FRT in MSAL
    self.testApp = [XCUIApplication new];
    [self.testApp activate];
    
    MSIDAutomationTestRequest *msalRequest = [self.class.confProvider defaultFociRequestWithBroker];
    msalRequest.homeAccountIdentifier = self.primaryAccount.homeAccountId;
    msalRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"common"];
    msalRequest.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.targetTenantId];
    msalRequest.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"aad_graph_static"];
    
    NSDictionary *msalConfig = [self configWithTestRequest:msalRequest];
    
    //It should refresh access token using family refresh token saved by office app using Adal
    [self acquireTokenSilent:msalConfig];
    [self assertAccessTokenNotNil];
    [self closeResultView];
}

@end
