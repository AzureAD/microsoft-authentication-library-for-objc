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

#import "MSALADFSBaseUITest.h"
#import "XCTestCase+TextFieldTap.h"
#import "NSString+MSIDAutomationUtils.h"

@interface MSALGuestUserTests : MSALADFSBaseUITest

@end

@implementation MSALGuestUserTests

- (void)setUp
{
    [super setUp];

    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    configurationRequest.accountFeatures = @[MSIDTestAccountFeatureGuestUser];
    [self loadTestConfiguration:configurationRequest];
}

// #347620
- (void)testInteractiveAndSilentAADLogin_withNonConvergedApp_withPromptAlways_noLoginHint_SystemWebView_signinIntoGuestTenantFirst
{
    NSString *environment = self.class.accountsProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.accountsProvider defaultNonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.requestScopes = [self.class.accountsProvider scopesForEnvironment:environment type:@"ms_graph"];
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:[self.class.accountsProvider scopesForEnvironment:environment type:@"oidc"]];
    request.configurationAuthority = [self.class.accountsProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.expectedResultAuthority = request.configurationAuthority;
    request.cacheAuthority = request.configurationAuthority;

    // 1. Run interactive in the guest tenant
    NSString *homeAccountId = [self runSharedGuestInteractiveLoginWithRequest:request closeResultView:NO];
    NSString *resultTenantId = [self resultDictionary][@"tenantId"];
    XCTAssertEqualObjects(resultTenantId, self.primaryAccount.targetTenantId);
    XCTAssertNotNil(homeAccountId);
    XCTAssertTrue([homeAccountId hasSuffix:self.primaryAccount.homeTenantId]);
    [self closeResultView];

    // 2. Run silent for the guest tenant
    request.homeAccountIdentifier = homeAccountId;

    [self runSharedSilentAADLoginWithTestRequest:request];

    // 3. Run silent for the home tenant
    request.configurationAuthority = [self.class.accountsProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.homeTenantId];
    request.expectedResultAuthority = request.configurationAuthority;
    request.cacheAuthority = request.configurationAuthority;
    request.testAccount.targetTenantId = request.testAccount.homeTenantId;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAndSilentAADLogin_withNonConvergedApp_withPromptAlways_noLoginHint_EmbeddedWebView_signinIntoHomeTenantFirst
{
    NSString *environment = self.class.accountsProvider.wwEnvironment;
    MSIDAutomationTestRequest *homeRequest = [self.class.accountsProvider defaultNonConvergedAppRequest];
    homeRequest.uiBehavior = @"force";
    homeRequest.requestScopes = [self.class.accountsProvider scopesForEnvironment:environment type:@"ms_graph"];
    homeRequest.expectedResultScopes = [NSString msidCombinedScopes:homeRequest.requestScopes withScopes:[self.class.accountsProvider scopesForEnvironment:environment type:@"oidc"]];
    homeRequest.configurationAuthority = [self.class.accountsProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.homeTenantId];
    homeRequest.expectedResultAuthority = homeRequest.configurationAuthority;
    homeRequest.cacheAuthority = homeRequest.configurationAuthority;
    homeRequest.webViewType = MSIDWebviewTypeWKWebView;
    homeRequest.testAccount = [self.primaryAccount copy];
    homeRequest.testAccount.targetTenantId = homeRequest.testAccount.homeTenantId;

    // 1. Run interactive in the home tenant
    NSString *homeAccountId = [self runSharedGuestInteractiveLoginWithRequest:homeRequest closeResultView:NO];
    NSString *resultTenantId = [self resultDictionary][@"tenantId"];
    XCTAssertEqualObjects(resultTenantId, self.primaryAccount.homeTenantId);
    XCTAssertNotNil(homeAccountId);
    XCTAssertTrue([homeAccountId hasSuffix:self.primaryAccount.homeTenantId]);
    [self closeResultView];

    // 2. Run silent for the home tenant
    homeRequest.homeAccountIdentifier = homeAccountId;
    [self runSharedSilentAADLoginWithTestRequest:homeRequest];

    // 3. Run silent for the guest tenant
    MSIDAutomationTestRequest *guestRequest = [self.class.accountsProvider defaultNonConvergedAppRequest];
    guestRequest.uiBehavior = @"force";
    guestRequest.testAccount = self.primaryAccount;
    guestRequest.requestScopes = [self.class.accountsProvider scopesForEnvironment:environment type:@"ms_graph"];
    guestRequest.expectedResultScopes = [NSString msidCombinedScopes:guestRequest.requestScopes withScopes:[self.class.accountsProvider scopesForEnvironment:environment type:@"oidc"]];
    guestRequest.configurationAuthority = [self.class.accountsProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    guestRequest.expectedResultAuthority = guestRequest.configurationAuthority;
    guestRequest.cacheAuthority = guestRequest.configurationAuthority;
    guestRequest.homeAccountIdentifier = homeAccountId;
    guestRequest.testAccount.homeObjectId = [[homeAccountId componentsSeparatedByString:@"."] firstObject];
    guestRequest.webViewType = MSIDWebviewTypeWKWebView;
    [self runSharedSilentAADLoginWithTestRequest:guestRequest];
}

// Test #347622
- (void)testInteractiveAndSilentAADLogin_withConvergedApp_withPromptAlways_noLoginHint_SystemWebView_andGuestUserInHomeAndGuestTenant
{
    NSString *environment = self.class.accountsProvider.wwEnvironment;
    MSIDAutomationTestRequest *guestRequest = [self.class.accountsProvider defaultConvergedAppRequest:environment];
    guestRequest.uiBehavior = @"force";
    guestRequest.configurationAuthority = [self.class.accountsProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    guestRequest.expectedResultAuthority = guestRequest.configurationAuthority;
    guestRequest.cacheAuthority = guestRequest.configurationAuthority;

    // 1. Run interactive in the guest tenant
    NSString *homeAccountId = [self runSharedGuestInteractiveLoginWithRequest:guestRequest closeResultView:NO];
    NSString *resultTenantId = [self resultDictionary][@"tenantId"];
    XCTAssertEqualObjects(resultTenantId, self.primaryAccount.targetTenantId);
    XCTAssertNotNil(homeAccountId);
    XCTAssertTrue([homeAccountId hasSuffix:self.primaryAccount.homeTenantId]);
    [self closeResultView];

    // 2. Run interactive in the home tenant
    MSIDAutomationTestRequest *homeRequest = [self.class.accountsProvider defaultConvergedAppRequest:environment];
    homeRequest.uiBehavior = @"force";
    homeRequest.configurationAuthority = [self.class.accountsProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.homeTenantId];
    homeRequest.expectedResultAuthority = homeRequest.configurationAuthority;
    homeRequest.cacheAuthority = homeRequest.configurationAuthority;
    homeRequest.testAccount = [self.primaryAccount copy];
    homeRequest.testAccount.targetTenantId = self.primaryAccount.homeTenantId;
    [self runSharedGuestInteractiveLoginWithRequest:homeRequest closeResultView:YES];

    // 3. Run silent for the guest tenant
    guestRequest.homeAccountIdentifier = homeAccountId;
    guestRequest.testAccount.targetTenantId = self.primaryAccount.targetTenantId;
    [self runSharedSilentAADLoginWithTestRequest:guestRequest];

    // 4. Run silent for the home tenant
    homeRequest.homeAccountIdentifier = homeAccountId;
    homeRequest.testAccount.targetTenantId = self.primaryAccount.homeTenantId;
    [self runSharedSilentAADLoginWithTestRequest:homeRequest];
}

- (NSString *)runSharedGuestInteractiveLoginWithRequest:(MSIDAutomationTestRequest *)request
                                        closeResultView:(BOOL)closeResultView
{
    // 1. Do interactive login
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];

    [self acceptAuthSessionDialogIfNecessary:request];

    if (!request.loginHint)
    {
        [self aadEnterEmail];
    }

    [self enterGuestUsername];
    [self enterGuestPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept" embeddedWebView:request.usesEmbeddedWebView];

    NSString *homeAccountId = [self runSharedResultAssertionWithTestRequest:request];

    if (closeResultView)
    {
        [self closeResultView];
    }

    return homeAccountId;
}

- (void)enterGuestUsername
{
    XCUIElement *passwordTextField = [self.testApp.textFields elementBoundByIndex:0];
    [self waitForElement:passwordTextField];
    [self tapElementAndWaitForKeyboardToAppear:passwordTextField];
    [passwordTextField typeText:[NSString stringWithFormat:@"%@\n", self.primaryAccount.username]];
}

- (void)enterGuestPassword
{
    XCUIElement *passwordTextField = [self.testApp.secureTextFields elementBoundByIndex:0];
    [self waitForElement:passwordTextField];
    [self tapElementAndWaitForKeyboardToAppear:passwordTextField];
    [passwordTextField typeText:[NSString stringWithFormat:@"%@\n", self.primaryAccount.password]];
}

@end
