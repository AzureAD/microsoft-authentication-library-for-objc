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
#import "XCTestCase+TextFieldTap.h"
#import "XCUIElement+CrossPlat.h"

@interface MSALPingUITests : MSALBaseAADUITest

@end

@implementation MSALPingUITests

- (void)setUp
{
    [super setUp];

    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderPing;
    configurationRequest.appVersion = MSIDAppVersionV1;
    [self loadTestConfiguration:configurationRequest];
}

#pragma mark - Shared

- (NSString *)runSharedPingInteractiveLoginWithRequest:(MSALTestRequest *)request
{
    // 1. Do interactive login
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];

    [self acceptAuthSessionDialogIfNecessary:request];

    if (!request.loginHint)
    {
        [self aadEnterEmail];
    }

    [self pingEnterUsername];
    [self pingEnterPassword];

    [self acceptMSSTSConsentIfNecessary:@"Accept"
                        embeddedWebView:request.usesEmbeddedWebView];

    [self assertAccessTokenNotNil];
    [self assertScopesReturned:request.expectedResultScopes];

    NSString *homeAccountId = [self runSharedResultAssertionWithTestRequest:request guestTenantScenario:NO];
    [self closeResultView];
    return homeAccountId;
}

#pragma mark - Tests

// #290995 iteration 9
- (void)testInteractivePingLogin_withNonConvergedApp_withPromptAlways_noLoginHint_andEmbeddedWebView
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.scopes = @"https://graph.windows.net/.default";
    request.expectedResultScopes = @[@"https://graph.windows.net/.default"];
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.testAccount = self.primaryAccount;
    request.webViewType = MSALWebviewTypeWKWebView;

    // 1. Run interactive
    NSString *homeAccountId = [self runSharedPingInteractiveLoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2. Run UI appears step
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    // 3. Run silent
    request.accountIdentifier = homeAccountId;
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    [self runSharedSilentAADLoginWithTestRequest:request];
}

// #290995 iteration 10
- (void)testInteractivePingLogin_withConvergedApp_withPromptAlways_withLoginHint_andSystemWebView
{
    MSALTestRequest *request = [MSALTestRequest convergedAppRequest];
    request.uiBehavior = @"force";
    request.scopes = @"user.read";
    request.expectedResultScopes = @[@"user.read", @"profile", @"openid"];
    request.authority = @"https://login.microsoftonline.com/common";
    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.account;

    // 1. Run interactive
    NSString *homeAccountId = [self runSharedPingInteractiveLoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);
}

- (void)testInteractivePingLogin_withConvergedApp_withPromptAlways_withLoginHint_andPassedInWebView
{
    MSALTestRequest *request = [MSALTestRequest convergedAppRequest];
    request.uiBehavior = @"force";
    request.scopes = @"user.read";
    request.expectedResultScopes = @[@"user.read", @"profile", @"openid"];
    request.authority = @"https://login.microsoftonline.com/common";
    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.account;
    request.usePassedWebView = YES;

    // 1. Run interactive
    NSString *homeAccountId = [self runSharedPingInteractiveLoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);
}

#pragma mark - Private

- (void)pingEnterUsername
{
    XCUIElement *usernameTextField = [self.testApp.textFields elementBoundByIndex:0];
    [self waitForElement:usernameTextField];
    [self tapElementAndWaitForKeyboardToAppear:usernameTextField];
    [usernameTextField activateTextField];
    [usernameTextField typeText:self.primaryAccount.username];
}

- (void)pingEnterPassword
{
    XCUIElement *passwordTextField = [self.testApp.secureTextFields elementBoundByIndex:0];
    [self waitForElement:passwordTextField];
    [self tapElementAndWaitForKeyboardToAppear:passwordTextField];
    [passwordTextField activateTextField];
    [passwordTextField typeText:[NSString stringWithFormat:@"%@\n", self.primaryAccount.password]];
}


@end
