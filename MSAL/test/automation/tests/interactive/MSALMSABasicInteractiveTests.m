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
    MSALTestRequest *request = [MSALTestRequest convergedAppRequest];
    request.scopes = @"user.read tasks.read";
    request.expectedResultScopes =  @[@"user.read",
                                      @"tasks.read",
                                      @"openid", @"profile"];
    request.authority = @"https://login.microsoftonline.com/common";
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    // 1. Do interactive login
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2. Run UI appears step
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    request.accountIdentifier = homeAccountId;
    request.authority = nil;

    // 3. Run silent
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveMSALogin_withConvergedApp_andMicrosoftGraphScopes_andConsumersEndpoint_andSafariViewController_andForceLogin
{
    MSALTestRequest *request = [MSALTestRequest convergedAppRequest];
    request.scopes = @"user.read tasks.read";
    request.expectedResultScopes =   @[@"user.read",
                                       @"tasks.read",
                                       @"openid", @"profile"];
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.authority = @"https://login.microsoftonline.com/consumers";
    request.webViewType = MSALWebviewTypeSafariViewController;

    // 1. Run interactive login
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];

    XCTAssertNotNil(homeAccountId);

    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    request.accountIdentifier = homeAccountId;

    // 2. Run silent login
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveMSALogin_withConvergedApp_andMicrosoftGraphScopes_andConsumersEndpoint_andSystemWebView_andForceLogin_angLoginHint
{
    MSALTestRequest *request = [MSALTestRequest convergedAppRequest];
    request.scopes = @"user.read tasks.read";
    request.expectedResultScopes =   @[@"user.read",
                                       @"tasks.read",
                                       @"openid", @"profile"];
    request.uiBehavior = @"force";
    request.loginHint = self.primaryAccount.account;
    request.testAccount = self.primaryAccount;
    request.authority = @"https://login.microsoftonline.com/consumers";

    // 1. Run interactive login
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];

    XCTAssertNotNil(homeAccountId);

    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    request.accountIdentifier = homeAccountId;

    // 2. Run silent login
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveMSALogin_withConvergedApp_andMicrosoftGraphScopes_andConsumersEndpoint_andEmbeddedWebview_andForceLogin_andLoginHint
{
    MSALTestRequest *request = [MSALTestRequest convergedAppRequest];
    request.scopes = @"user.read tasks.read";
    request.expectedResultScopes =   @[@"user.read",
                                       @"tasks.read",
                                       @"openid", @"profile"];
    request.uiBehavior = @"force";
    request.loginHint = self.primaryAccount.account;
    request.testAccount = self.primaryAccount;
    request.authority = @"https://login.microsoftonline.com/consumers";
    request.webViewType = MSALWebviewTypeWKWebView;

    // 1. Run interactive login
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];

    XCTAssertNotNil(homeAccountId);

    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    request.accountIdentifier = homeAccountId;

    // 2. Run silent login
    [self runSharedSilentAADLoginWithTestRequest:request];
}

// TODO: consumers doesn't support select account?
- (void)testInteractiveAADLogin_withConvergedApp_andMicrosoftGraphScopes_andCommonEndpoint_andSelectAccount
{
    // 1. Sign in first time to ensure account will be there
    MSALTestRequest *request = [MSALTestRequest convergedAppRequest];
    request.authority = @"https://login.microsoftonline.com/common";
    request.scopes = @"tasks.read";
    request.expectedResultScopes = @[@"tasks.read", @"openid", @"profile"];
    request.uiBehavior = @"force";
    request.loginHint = self.primaryAccount.username;
    request.testAccount = self.primaryAccount;
    [self runSharedAADLoginWithTestRequest:request];

    request.uiBehavior = @"select_account";
    request.loginHint = nil;

    NSDictionary *config = [self configWithTestRequest:request];
    // 2. Now call acquire token with select account
    [self acquireToken:config];
    [self acceptAuthSessionDialog];

    XCUIElement *pickAccount = self.testApp.staticTexts[@"Pick an account"];
    [self waitForElement:pickAccount];

    NSPredicate *accountPredicate = [NSPredicate predicateWithFormat:@"label CONTAINS[c] %@", self.primaryAccount.account];
    XCUIElement *element = [[self.testApp.buttons containingPredicate:accountPredicate] elementBoundByIndex:0];
    XCTAssertNotNil(element);

    [element msidTap];
    // TODO: why am I asked to enter my password again in system webview?
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Yes" embeddedWebView:NO];

    [self assertAccessTokenNotNil];
    [self closeResultView];
}

#pragma mark - Non-converged app

// TODO: server side bug here
- (void)DISABLED_testInteractiveAADLogin_withNonConvergedApp_andMicrosoftGraphScopes_andConsumersEndpoint_andSystemWebView_andForceLogin
{
    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.appVersion = MSIDAppVersionV1;
    configurationRequest.accountFeatures = @[];
    [self loadTestConfiguration:configurationRequest];

    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.authority = @"https://login.microsoftonline.com/consumers";
    request.uiBehavior = @"force";
    request.scopes = @"https://graph.microsoft.com/.default";
    request.testAccount = self.primaryAccount;

    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];
    [self acceptAuthSessionDialog];
    [self aadEnterEmail];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Yes" embeddedWebView:NO];
    [self assertErrorCode:@"MSALErrorInvalidRequest"];
    [self assertErrorDescription:@"Please use the /organizations or tenant-specific endpoint."];
    [self closeResultView];
}

// TODO: fix account selection bug

@end
