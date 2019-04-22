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

@interface MSALMultiAppCacheCoexistenceTests : MSALBaseAADUITest

@property (nonatomic, strong) NSString *testEnvironment;

@end

@implementation MSALMultiAppCacheCoexistenceTests

static BOOL msalAppInstalled = NO;

#pragma mark - Setup

- (void)setUp
{
    [super setUp];
    
    self.testEnvironment = self.class.confProvider.wwEnvironment;

    // We only need to install app once for all the tests
    // It would be better to use +(void)setUp here, but XCUIApplication launch doesn't work then, so using this mechanism instead
    if (!msalAppInstalled)
    {
        msalAppInstalled = YES;
        [self installAppWithId:@"msal_unified"];
        [self.testApp activate];
        [self closeResultView];
    }

    MSIDAutomationConfigurationRequest *configurationRequest = [MSIDAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    [self loadTestConfiguration:configurationRequest];
}

#pragma mark - Tests

- (void)testCoexistenceWithAnotherMSAL_startSigninInOtherMSAL_withAADAccount_andDoTokenRefresh
{
    // 1. Install other MSAL version and signin
    self.testApp = [self otherMSALApp];
    
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.promptBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"ms_graph_static"];
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:self.class.confProvider.oidcScopes];
    request.configurationAuthority = request.cacheAuthority;

    NSDictionary *config = [self configWithTestRequest:request];

    [self acquireToken:config];
    [self acceptAuthSessionDialog];
    [self aadEnterEmail];
    [self aadEnterPassword];

    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 2. Switch to current MSAL and acquire token silently with organizations authority
    self.testApp = [XCUIApplication new];
    [self.testApp activate];
    
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"organizations"];
    request.homeAccountIdentifier = self.primaryAccount.homeAccountId;
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"ms_graph"];
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:self.class.confProvider.oidcScopes];
    
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testCoexistenceWithOtherMSAL_startSigninInCurrentMSAL_withAADAccount_andUseDifferentAuthorities
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultConvergedAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.promptBehavior = @"force";
    request.loginHint = self.primaryAccount.account;
    request.testAccount = self.primaryAccount;
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"organizations"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"ms_graph"];
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:self.class.confProvider.oidcScopes];

    // 1. Sign into the MSAL test app
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2.Switch to other MSAL app and acquire token silently with common authority
    self.testApp = [self otherMSALApp];
    request.homeAccountIdentifier = homeAccountId;
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:@"ww-alias" tenantId:@"organizations"];
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 3. Now expire token in other MSAL app
    NSDictionary *silentConfig = [self configWithTestRequest:request];
    [self expireAccessToken:silentConfig];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // 4. Now acquire token silently
    [self acquireTokenSilent:silentConfig];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 5. Run token refresh in current MSAL again
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"common"];
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (XCUIApplication *)otherMSALApp
{
    return [self openAppWithAppId:@"msal_unified"];
}

- (void)testCoexistenceWithOtherMSAL_startSigninInCurrentMSAL_withAADAccount_OtherMSALUsesFRTToRefreshAccessToken
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultFociRequestWithBroker];
    request.promptBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"common"];
    request.loginHint = self.primaryAccount.account;
    request.testAccount = self.primaryAccount;
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"aad_graph_static"];
    request.expectedResultScopes = request.requestScopes;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.targetTenantId];
    
    // 1. Sign into the MSAL test app
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);
    
    // 2.Switch to other MSAL app and acquire token silently using FRT
    self.testApp = [self otherMSALApp];
    [self.testApp launch];
    XCTAssertTrue([self.testApp waitForState:XCUIApplicationStateRunningForeground timeout:60]);
    MSIDAutomationTestRequest *secondAppRequest = [self.class.confProvider sharepointFociRequestWithBroker];
    secondAppRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"common"];
    secondAppRequest.homeAccountIdentifier = homeAccountId;
    secondAppRequest.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"ms_graph_static"];
    secondAppRequest.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:self.class.confProvider.oidcScopes];
    
    NSDictionary *secondSilentConfig = [self configWithTestRequest:secondAppRequest];
    
    //It should refresh access token using family refresh token saved by onedrive app
    [self acquireTokenSilent:secondSilentConfig];
    [self assertAccessTokenNotNil];
    [self closeResultView];
}
@end
