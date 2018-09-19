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

    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderBlackForest;
    configurationRequest.appVersion = MSIDAppVersionV1;
    configurationRequest.needsMultipleUsers = NO;
    configurationRequest.accountFeatures = @[];
    [self loadTestConfiguration:configurationRequest];

    self.continueAfterFailure = YES;
}

#pragma mark - Interactive tests

- (void)testInteractiveAADLogin_withConvergedApp_withWWAuthority_withNoLoginHint_EmbeddedWebView_withInstanceAware
{
    MSALTestRequest *request = [MSALTestRequest convergedAppRequest];
    request.uiBehavior = @"force";
    request.authority = @"https://login.microsoftonline.com/common";
    request.scopes = @"email";
    request.expectedResultScopes = @[@"email", @"openid", @"profile"];
    request.testAccount = self.primaryAccount;
    request.additionalParameters = @{@"extra_qp": @{@"instance_aware": @"true"}};
    request.webViewType = MSALWebviewTypeWKWebView;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.de/", self.primaryAccount.targetTenantId];

    // 1. Run interactive
    NSString *homeAccountID = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountID);

    // 2. Run auth UI appears step
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    // 3. Run silent with wrong authority
    request.accountIdentifier = homeAccountID;
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireTokenSilent:config];
    [self assertErrorCode:@"MSALErrorInteractionRequired"];
    [self closeResultView];

    // 4. Run silent with correct authority
    request.authority = @"https://login.microsoftonline.de/common";
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.de/%@", self.primaryAccount.targetTenantId];
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_withWWAuthority_withNoLoginHint_EmbeddedWebView_withInstanceAware
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.scopes = @"https://graph.cloudapi.de/.default";
    // TODO: German cloud doesn't currently return openid and profile scopes for Microsoft graph, so commenting this out until it's fixed
    // request.expectedResultScopes = @[@"https://graph.cloudapi.de/.default", @"openid", @"profile"];
    request.expectedResultScopes = @[@"https://graph.cloudapi.de/.default"];
    request.testAccount = self.primaryAccount;
    request.additionalParameters = @{@"extra_qp": @{@"instance_aware": @"true"}};
    request.webViewType = MSALWebviewTypeWKWebView;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.de/", self.primaryAccount.targetTenantId];

    // 1. Run interactive
    NSString *homeAccountID = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountID);

    // 2. Run auth UI appears step
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    // 3. Run silent with wrong authority
    request.accountIdentifier = homeAccountID;
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireTokenSilent:config];
    [self assertErrorCode:@"MSALErrorInteractionRequired"];
    [self closeResultView];

    // 4. Run silent with correct authority
    request.authority = @"https://login.microsoftonline.de/common";
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.de/%@", self.primaryAccount.targetTenantId];
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_withWWAuthority_withLoginHint_EmbeddedWebView_withInstanceAware
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.scopes = @"https://graph.cloudapi.de/.default";
    request.expectedResultScopes = @[@"https://graph.cloudapi.de/.default", @"openid", @"profile"];
    request.testAccount = self.primaryAccount;
    request.additionalParameters = @{@"extra_qp": @{@"instance_aware": @"true"}};
    request.webViewType = MSALWebviewTypeWKWebView;
    request.loginHint = self.primaryAccount.account;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.de/", self.primaryAccount.targetTenantId];

    // 1. Run interactive
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];
    [self blackForestWaitForNextButton:self.testApp];
    [self aadEnterPassword];
    [self assertAccessTokenNotNil];
}

// The following test needs slice parameter to be sent to instance discovery endpoint to work.
// Therefore disable the it for now as that is not happening.
- (void)DISABLED_testInteractiveAADLogin_withNonConvergedApp_withBlackforestAuthority_withNoLoginHint_SystemWebView
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.authority = @"https://login.microsoftonline.de/organizations";
    request.scopes = @"https://graph.cloudapi.de/.default";
    request.expectedResultScopes = @[@"https://graph.cloudapi.de/.default", @"openid", @"profile"];
    request.testAccount = self.primaryAccount;
    request.additionalParameters = @{@"extra_qp": @{@"instance_aware": @"true"}};
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.de/", self.primaryAccount.targetTenantId];

    // 1. Run interactive
    NSString *homeAccountID = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountID);

    // 2. Run silent with correct authority
    request.accountIdentifier = homeAccountID;
    request.authority = @"https://login.microsoftonline.de/common";
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.de/%@", self.primaryAccount.targetTenantId];
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
