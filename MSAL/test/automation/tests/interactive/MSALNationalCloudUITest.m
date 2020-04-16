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

#import "MSALNationalCloudUITest.h"
#import "XCUIElement+CrossPlat.h"

@implementation MSALNationalCloudUITest

#pragma mark - Interactive tests

- (void)runInstanceAwareTestWithNationalCloud
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:environment targetTenantId:self.primaryAccount.targetTenantId];
    request.promptBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.nationalCloudEnvironment type:@"ms_graph_userread"];
    request.expectedResultScopes = request.requestScopes;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.nationalCloudEnvironment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.nationalCloudEnvironment tenantId:self.primaryAccount.targetTenantId];
    request.webViewType = MSIDWebviewTypeWKWebView;
    request.instanceAware = YES;

    // 1. Run interactive
    NSString *homeAccountID = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountID);

    // 2. Run auth UI appears step
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    // 3. Run silent with wrong authority
    request.homeAccountIdentifier = homeAccountID;
    request.acquireTokenAuthority = request.configurationAuthority;
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self runSharedResultAssertionWithTestRequest:request];
    [self closeResultView];

    // 4. Run silent with correct authority
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.nationalCloudEnvironment];
    request.acquireTokenAuthority = request.configurationAuthority;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)runInstanceAwareTestWithNationalCloud_withOrganizationsAuthority
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:environment targetTenantId:self.primaryAccount.targetTenantId];
    request.promptBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.nationalCloudEnvironment tenantId:@"organizations"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.nationalCloudEnvironment type:@"ms_graph_static"];
    request.expectedResultScopes = request.requestScopes;
    request.testAccount = self.primaryAccount;
    request.instanceAware = YES;
    request.webViewType = MSIDWebviewTypeWKWebView;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.nationalCloudEnvironment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.nationalCloudEnvironment tenantId:self.primaryAccount.targetTenantId];

    // 1. Run interactive
    NSString *homeAccountID = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountID);

    // 2. Run auth UI appears step
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    // 3. Run silent with wrong authority
    request.homeAccountIdentifier = homeAccountID;
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self runSharedResultAssertionWithTestRequest:request];
    [self closeResultView];

    // 4. Run silent with correct authority
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.nationalCloudEnvironment];
    request.acquireTokenAuthority = request.configurationAuthority;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)runInstanceAwareTestWithNationalCloud_withOrganizationsAuthority_withLoginHintPresent_andEQP
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:environment targetTenantId:self.primaryAccount.targetTenantId];
    request.clientId = self.testApplication.appId;
    request.promptBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:@"organizations"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.nationalCloudEnvironment type:@"ms_graph_static"];
    request.expectedResultScopes = request.requestScopes;
    request.testAccount = self.primaryAccount;
    request.extraQueryParameters = @{@"instance_aware": @"true"};
    request.webViewType = MSIDWebviewTypeWKWebView;
    request.loginHint = self.primaryAccount.domainUsername;

    // 1. Run interactive
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];
    [self nationalCloudWaitForNextButton:self.testApp];
    [self aadEnterPassword];
    [self assertAccessTokenNotNil];
}

// The following test needs slice parameter to be sent to instance discovery endpoint to work.
// Therefore disable the it for now as that is not happening.
- (void)runNonInstanceAwareTestWithNationalCloud_withSystemWebView
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:self.nationalCloudEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.promptBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.nationalCloudEnvironment tenantId:@"organizations"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.nationalCloudEnvironment type:@"aad_graph_static"];
    request.expectedResultScopes = request.requestScopes;
    request.testAccount = self.primaryAccount;
    request.webViewType = MSIDWebviewTypeSafariViewController;
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
- (void)nationalCloudWaitForNextButton:(XCUIApplication *)application
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
