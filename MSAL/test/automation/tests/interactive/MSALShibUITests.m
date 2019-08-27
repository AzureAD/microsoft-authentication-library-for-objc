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
#import "NSString+MSIDAutomationUtils.h"

@interface MSALShibUITests : MSALBaseAADUITest

@property (nonatomic) NSString *testEnvironment;

@end

@implementation MSALShibUITests

- (void)setUp
{
    [super setUp];
    
    self.testEnvironment = self.class.confProvider.wwEnvironment;

    MSIDAutomationConfigurationRequest *configurationRequest = [MSIDAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderShibboleth;
    [self loadTestConfiguration:configurationRequest];
}

#pragma mark - Shared

- (NSString *)runSharedShibbolethInteractiveLoginWithRequest:(MSIDAutomationTestRequest *)request
{
    // 1. Do interactive login
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];

    [self acceptAuthSessionDialogIfNecessary:request];

    if (!request.loginHint)
    {
        [self aadEnterEmail];
    }

    [self shibEnterUsername];
    [self shibEnterPassword];

    [self acceptMSSTSConsentIfNecessary:@"Accept"
                        embeddedWebView:request.usesEmbeddedWebView];
    
    if (!request.usesEmbeddedWebView)
    {
        [self acceptSpeedBump];
    }

    NSString *homeAccountId = [self runSharedResultAssertionWithTestRequest:request];
    [self closeResultView];
    return homeAccountId;
}

#pragma mark - Tests

// #290995 iteration 5
- (void)testInteractiveShibLogin_withNonConvergedApp_withPromptAlways_noLoginHint_andEmbeddedWebView
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"organizations"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"aad_graph_static"];
    request.expectedResultScopes = request.requestScopes;
    request.promptBehavior = @"force";
    request.webViewType = MSIDWebviewTypeWKWebView;

    // 1. Run interactive
    NSString *homeAccountId = [self runSharedShibbolethInteractiveLoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2. Run UI appears step
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    // 3. Run silent
    request.homeAccountIdentifier = homeAccountId;
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    [self runSharedSilentAADLoginWithTestRequest:request];
}

// #290995 iteration 6
- (void)testInteractiveShibLogin_withConvergedApp_withPromptAlways_withLoginHint_andSystemWebView
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultConvergedAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"common"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"ms_graph"];
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:self.class.confProvider.oidcScopes];
    request.promptBehavior = @"force";
    request.loginHint = self.primaryAccount.account;
    request.testAccount = self.primaryAccount;

    // 1. Run interactive
    NSString *homeAccountId = [self runSharedShibbolethInteractiveLoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);
}

- (void)testInteractiveShibLogin_withConvergedApp_withPromptAlways_withLoginHint_andPassedInWebView
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultConvergedAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"common"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"ms_graph"];
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:self.class.confProvider.oidcScopes];
    request.promptBehavior = @"force";
    request.loginHint = self.primaryAccount.account;
    request.testAccount = self.primaryAccount;
    request.usePassedWebView = YES;

    // 1. Run interactive
    NSString *homeAccountId = [self runSharedShibbolethInteractiveLoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);
}

#pragma mark - Private

- (void)shibEnterUsername
{
    XCUIElement *usernameTextField = [self.testApp.textFields elementBoundByIndex:0];
    [self waitForElement:usernameTextField];
    [self tapElementAndWaitForKeyboardToAppear:usernameTextField];
    [usernameTextField activateTextField];
    [usernameTextField typeText:self.primaryAccount.username];
}

- (void)shibEnterPassword
{
    XCUIElement *passwordTextField = [self.testApp.secureTextFields elementBoundByIndex:0];
    [self waitForElement:passwordTextField];
    [self tapElementAndWaitForKeyboardToAppear:passwordTextField];
    [passwordTextField activateTextField];
    [passwordTextField typeText:[NSString stringWithFormat:@"%@\n", self.primaryAccount.password]];
}


@end
