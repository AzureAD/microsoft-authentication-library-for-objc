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

#import "MSALBaseUITest.h"
#import "MSALBaseAADUITest.h"
#import "XCUIElement+CrossPlat.h"

@interface MSALMSABasicInteractiveTests : MSALBaseAADUITest

@end

@implementation MSALMSABasicInteractiveTests

#pragma mark - Setup

- (void)setUp
{
    [super setUp];

    self.consentTitle = @"Yes";

    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderMSA;
    configurationRequest.appVersion = MSIDAppVersionV1;
    configurationRequest.accountFeatures = @[];
    [self loadTestConfiguration:configurationRequest];
}

#pragma mark - Converged app

- (void)testInteractiveMSALogin_withConvergedApp_andMicrosoftGraphScopes_andCommonEndpoint_andSystemWebView_andForceLogin
{
    NSString *environment = self.class.accountsProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.accountsProvider defaultConvergedAppRequest:environment];
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.cacheAuthority = [self.class.accountsProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.expectedResultAuthority = request.cacheAuthority;

    // 1. Do interactive login
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2. Run UI appears step
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    request.homeAccountIdentifier = homeAccountId;

    // 3. Run silent
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveMSALogin_withConvergedApp_andMicrosoftGraphScopes_andConsumersEndpoint_andSafariViewController_andForceLogin
{
    NSString *environment = self.class.accountsProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.accountsProvider defaultConvergedAppRequest:environment];
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.configurationAuthority = [self.class.accountsProvider defaultAuthorityForIdentifier:environment tenantId:@"consumers"];
    request.webViewType = MSIDWebviewTypeSafariViewController;
    request.loginHint = self.primaryAccount.username;
    request.cacheAuthority = [self.class.accountsProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.expectedResultAuthority = request.cacheAuthority;

    // 1. Run interactive login
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];

    XCTAssertNotNil(homeAccountId);

    request.homeAccountIdentifier = homeAccountId;

    // 2. Run silent login
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveMSALogin_withConvergedApp_andMicrosoftGraphScopes_andConsumersEndpoint_andSystemWebView_andForceLogin_angLoginHint
{
    NSString *environment = self.class.accountsProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.accountsProvider defaultConvergedAppRequest:environment];
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.configurationAuthority = [self.class.accountsProvider defaultAuthorityForIdentifier:environment tenantId:@"consumers"];
    request.loginHint = self.primaryAccount.account;
    request.cacheAuthority = [self.class.accountsProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.expectedResultAuthority = request.cacheAuthority;

    // 1. Run interactive login
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    request.homeAccountIdentifier = homeAccountId;

    // 2. Run silent login
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveMSALogin_withConvergedApp_andMicrosoftGraphScopes_andConsumersEndpoint_andEmbeddedWebview_andForceLogin_andLoginHint
{
    NSString *environment = self.class.accountsProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.accountsProvider defaultConvergedAppRequest:environment];
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.configurationAuthority = [self.class.accountsProvider defaultAuthorityForIdentifier:environment tenantId:@"consumers"];
    request.loginHint = self.primaryAccount.account;
    request.webViewType = MSIDWebviewTypeWKWebView;
    request.cacheAuthority = [self.class.accountsProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.expectedResultAuthority = request.cacheAuthority;

    // 1. Run interactive login
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    request.homeAccountIdentifier = homeAccountId;

    // 2. Run silent login
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withConvergedApp_andMicrosoftGraphScopes_andCommonEndpoint_andSelectAccount
{
    // 1. Sign in first time to ensure account will be there
    NSString *environment = self.class.accountsProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.accountsProvider defaultConvergedAppRequest:environment];
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.configurationAuthority = [self.class.accountsProvider defaultAuthorityForIdentifier:environment tenantId:@"common"];
    request.requestScopes = [self.class.accountsProvider scopesForEnvironment:environment type:@"ms_graph_prefixed"];
    request.expectedResultScopes = request.requestScopes;
    request.loginHint = self.primaryAccount.account;
    request.cacheAuthority = [self.class.accountsProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.expectedResultAuthority = request.cacheAuthority;
    [self runSharedAADLoginWithTestRequest:request];

    request.uiBehavior = @"select_account";
    request.loginHint = nil;
    request.testAccount = nil;

    NSDictionary *config = [self configWithTestRequest:request];
    // 2. Now call acquire token with select account
    [self acquireToken:config];
    [self acceptAuthSessionDialog];

    [self selectAccountWithTitle:self.primaryAccount.account];
    [self acceptMSSTSConsentIfNecessary:@"Yes" embeddedWebView:NO];

    [self assertAccessTokenNotNil];
    [self closeResultView];
}

@end
