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

#import "MSALBaseAADUITest.h"
#import "XCUIElement+CrossPlat.h"

@interface MSALBlackforestUITests : MSALBaseAADUITest

@end

@implementation MSALBlackforestUITests

#pragma mark - Setup

- (void)setUp
{
    [super setUp];

    MSIDAutomationConfigurationRequest *configurationRequest = [MSIDAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderBlackForest;
    configurationRequest.needsMultipleUsers = NO;
    [self loadTestConfiguration:configurationRequest];
}

#pragma mark - Interactive tests

- (void)testInteractiveAADLogin_withConvergedApp_withWWAuthority_withNoLoginHint_EmbeddedWebView_withInstanceAware
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultConvergedAppRequest:environment targetTenantId:self.primaryAccount.targetTenantId];
    request.promptBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.requestScopes = [self.class.confProvider scopesForEnvironment:@"de" type:@"ms_graph"];
    request.expectedResultScopes = request.requestScopes;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:@"de" tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:@"de" tenantId:self.primaryAccount.targetTenantId];
    request.webViewType = MSIDWebviewTypeWKWebView;
    request.extraQueryParameters = @{@"instance_aware": @"true"};

    // 1. Run interactive
    NSString *homeAccountID = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountID);

    // 2. Run auth UI appears step
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    // 3. Run silent with wrong authority
    // In 0.5.0+ it should succeed
    // TODO: verify expected behavior for this in 0.6.0 MSAL release
    request.homeAccountIdentifier = homeAccountID;
    request.acquireTokenAuthority = request.configurationAuthority;
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self runSharedResultAssertionWithTestRequest:request];
    [self closeResultView];

    // 4. Run silent with correct authority
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:@"de"];
    request.acquireTokenAuthority = request.configurationAuthority;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_withWWAuthority_withNoLoginHint_EmbeddedWebView_withInstanceAware
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest:environment targetTenantId:self.primaryAccount.targetTenantId];
    request.clientId = self.testConfiguration.clientId;
    request.promptBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:@"organizations"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:@"de" type:@"ms_graph_static"];
    request.expectedResultScopes = request.requestScopes;
    request.testAccount = self.primaryAccount;
    request.extraQueryParameters = @{@"instance_aware": @"true"};
    request.webViewType = MSIDWebviewTypeWKWebView;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:@"de" tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:@"de" tenantId:self.primaryAccount.targetTenantId];

    // 1. Run interactive
    NSString *homeAccountID = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountID);

    // 2. Run auth UI appears step
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    // 3. Run silent with wrong authority
    // In 0.5.0+ it should succeed
    // TODO: verify expected behavior for this in 0.6.0 MSAL release
    request.homeAccountIdentifier = homeAccountID;
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self runSharedResultAssertionWithTestRequest:request];
    [self closeResultView];

    // 4. Run silent with correct authority
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:@"de"];
    request.acquireTokenAuthority = request.configurationAuthority;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_withWWAuthority_withLoginHint_EmbeddedWebView_withInstanceAware
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest:environment targetTenantId:self.primaryAccount.targetTenantId];
    request.clientId = self.testConfiguration.clientId;
    request.promptBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:@"organizations"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:@"de" type:@"ms_graph_static"];
    request.expectedResultScopes = request.requestScopes;
    request.testAccount = self.primaryAccount;
    request.extraQueryParameters = @{@"instance_aware": @"true"};
    request.webViewType = MSIDWebviewTypeWKWebView;
    request.loginHint = self.primaryAccount.account;

    // 1. Run interactive
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];
    [self blackForestWaitForNextButton:self.testApp];
    [self aadEnterPassword];
    [self assertAccessTokenNotNil];
}


// The following test needs slice parameter to be sent to instance discovery endpoint to work.
// Therefore disable the it for now as that is not happening.
- (void)testInteractiveAADLogin_withNonConvergedApp_withBlackforestAuthority_withNoLoginHint_SystemWebView
{
    NSString *environment = @"de";
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest:environment targetTenantId:self.primaryAccount.targetTenantId];
    request.clientId = self.testConfiguration.clientId;
    request.promptBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:@"organizations"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:environment type:@"aad_graph_static"];
    request.expectedResultScopes = request.requestScopes;
    request.testAccount = self.primaryAccount;
    request.extraQueryParameters = @{@"instance_aware": @"true"};

    // 1. Run interactive
    NSString *homeAccountID = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountID);

    // 2. Run silent with correct authority
    request.homeAccountIdentifier = homeAccountID;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

/*
 There seems to be some flakiness around sovereign user with login hint provided,
 where ESTS sometimes shows the username page with next button and sometimes redirects to the password page correctly. This portion of code waits for the "Next" button for 10 seconds if it appears.
 */
- (void)blackForestWaitForNextButton:(XCUIApplication *)application
{
    XCUIElement *emailTextField = application.textFields[@"Enter your email, phone, or Skype."];

    for (int i = 0; i < 10; i++)
    {
        if (emailTextField.exists)
        {
            [application.buttons[@"Next"] msidTap];
            break;
        }
        else
        {
            sleep(1);
        }
    }
}

@end
