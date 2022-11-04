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
#import "NSString+MSIDAutomationUtils.h"
#import "XCUIElement+CrossPlat.h"

@interface MSALGuestUserTests : MSALADFSBaseUITest

@property (nonatomic) NSString *testEnvironment;

@end

@implementation MSALGuestUserTests

- (void)setUp
{
    [super setUp];
    
    self.testEnvironment = self.class.confProvider.wwEnvironment;
    
    MSIDTestAutomationAppConfigurationRequest *appConfigurationRequest = [MSIDTestAutomationAppConfigurationRequest new];
    appConfigurationRequest.testAppAudience = MSIDTestAppAudienceMultipleOrgs;
    appConfigurationRequest.testAppEnvironment = self.testEnvironment;
    
    [self loadTestApp:appConfigurationRequest];
    
    MSIDTestAutomationAccountConfigurationRequest *accountConfigurationRequest = [MSIDTestAutomationAccountConfigurationRequest new];
    accountConfigurationRequest.environmentType = self.testEnvironment;
    accountConfigurationRequest.accountType = MSIDTestAccountTypeGuest;
    accountConfigurationRequest.federationProviderType = MSIDTestAccountFederationProviderTypeADFSV4;
    
    [self loadTestAccount:accountConfigurationRequest];
}

// #347620
- (void)testInteractiveAndSilentAADLogin_withNonConvergedApp_withPromptAlways_noLoginHint_SystemWebView_signinIntoGuestTenantFirst
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.promptBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"ms_graph"];
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:self.class.confProvider.oidcScopes];
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.targetTenantId];

    // 1. Run interactive in the guest tenant
    NSString *homeAccountId = [self runSharedGuestInteractiveLoginWithRequest:request closeResultView:NO];
    NSString *resultTenantId = [self automationSuccessResult:self.testApp].userInformation.tenantId;
    XCTAssertEqualObjects(resultTenantId, self.primaryAccount.targetTenantId);
    XCTAssertNotNil(homeAccountId);
    XCTAssertTrue([homeAccountId hasSuffix:self.primaryAccount.homeTenantId]);
    [self closeResultPipeline:self.testApp];

    // 2. Run silent for the guest tenant
    request.homeAccountIdentifier = homeAccountId;

    [self runSharedSilentAADLoginWithTestRequest:request];

    // 3. Run silent for the home tenant
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.homeTenantId];
    request.expectedResultAuthority = request.configurationAuthority;
    request.cacheAuthority = request.configurationAuthority;
    request.targetTenantId = self.primaryAccount.homeTenantId;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAndSilentAADLogin_withNonConvergedApp_withPromptAlways_noLoginHint_EmbeddedWebView_signinIntoHomeTenantFirst
{
    MSIDAutomationTestRequest *homeRequest = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    homeRequest.promptBehavior = @"force";
    homeRequest.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"ms_graph"];
    homeRequest.expectedResultScopes = [NSString msidCombinedScopes:homeRequest.requestScopes withScopes:self.class.confProvider.oidcScopes];
    homeRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.homeTenantId];
    homeRequest.expectedResultAuthority = homeRequest.configurationAuthority;
    homeRequest.cacheAuthority = homeRequest.configurationAuthority;
    homeRequest.webViewType = MSIDWebviewTypeWKWebView;
    homeRequest.testAccount = self.primaryAccount;
    homeRequest.targetTenantId = self.primaryAccount.homeTenantId;

    // 1. Run interactive in the home tenant
    NSString *homeAccountId = [self runSharedGuestInteractiveLoginWithRequest:homeRequest closeResultView:NO];
    NSString *resultTenantId = [self automationSuccessResult:self.testApp].userInformation.tenantId;
    XCTAssertEqualObjects(resultTenantId, self.primaryAccount.homeTenantId);
    XCTAssertNotNil(homeAccountId);
    XCTAssertTrue([homeAccountId hasSuffix:self.primaryAccount.homeTenantId]);
    [self closeResultPipeline:self.testApp];

    // 2. Run silent for the home tenant
    homeRequest.homeAccountIdentifier = homeAccountId;
    [self runSharedSilentAADLoginWithTestRequest:homeRequest];

    // 3. Run silent for the guest tenant
    MSIDAutomationTestRequest *guestRequest = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    guestRequest.promptBehavior = @"force";
    guestRequest.testAccount = self.primaryAccount;
    guestRequest.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"ms_graph"];
    guestRequest.expectedResultScopes = [NSString msidCombinedScopes:guestRequest.requestScopes withScopes:self.class.confProvider.oidcScopes];
    guestRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.targetTenantId];
    guestRequest.homeAccountIdentifier = homeAccountId;
    guestRequest.webViewType = MSIDWebviewTypeWKWebView;
    guestRequest.targetTenantId = self.primaryAccount.targetTenantId;
    [self runSharedSilentAADLoginWithTestRequest:guestRequest];
}

// Test #347622
- (void)testInteractiveAndSilentAADLogin_withConvergedApp_withPromptAlways_noLoginHint_SystemWebView_andGuestUserInHomeAndGuestTenant
{
    MSIDAutomationTestRequest *guestRequest = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    guestRequest.promptBehavior = @"force";
    guestRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.targetTenantId];
    guestRequest.expectedResultAuthority = guestRequest.configurationAuthority;
    guestRequest.cacheAuthority = guestRequest.configurationAuthority;
    guestRequest.targetTenantId = self.primaryAccount.targetTenantId;

    // 1. Run interactive in the guest tenant
    NSString *homeAccountId = [self runSharedGuestInteractiveLoginWithRequest:guestRequest closeResultView:NO];
    NSString *resultTenantId = [self automationSuccessResult:self.testApp].userInformation.tenantId;
    XCTAssertEqualObjects(resultTenantId, self.primaryAccount.targetTenantId);
    XCTAssertNotNil(homeAccountId);
    XCTAssertTrue([homeAccountId hasSuffix:self.primaryAccount.homeTenantId]);
    [self closeResultPipeline:self.testApp];

    // 2. Run interactive in the home tenant
    MSIDAutomationTestRequest *homeRequest = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.homeTenantId];
    homeRequest.promptBehavior = @"force";
    homeRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.homeTenantId];
    homeRequest.testAccount = self.primaryAccount;
    homeRequest.targetTenantId = self.primaryAccount.homeTenantId;
    [self runSharedGuestInteractiveLoginWithRequest:homeRequest closeResultView:YES];

    // 3. Run silent for the guest tenant
    guestRequest.homeAccountIdentifier = homeAccountId;
    [self runSharedSilentAADLoginWithTestRequest:guestRequest];

    // 4. Run silent for the home tenant
    homeRequest.homeAccountIdentifier = homeAccountId;
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
        [self aadEnterEmail:self.testApp];
    }

    [self enterGuestPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept" embeddedWebView:request.usesEmbeddedWebView];
    
    if (!request.usesEmbeddedWebView)
    {
        [self acceptSpeedBump];
    }

    NSString *homeAccountId = [self runSharedResultAssertionWithTestRequest:request];

    if (closeResultView)
    {
        [self closeResultPipeline:self.testApp];
    }

    return homeAccountId;
}

- (void)enterGuestUsername
{
    XCUIElement *emailTextField = [self.testApp.textFields elementBoundByIndex:0];
    [self waitForElement:emailTextField];
    [emailTextField msidTap];
    [emailTextField typeText:[NSString stringWithFormat:@"%@\n", self.primaryAccount.upn]];
}

- (void)enterGuestPassword
{
    XCUIElement *passwordTextField = [self.testApp.secureTextFields elementBoundByIndex:0];
    [self waitForElement:passwordTextField];
    [passwordTextField msidTap];
    [passwordTextField typeText:[NSString stringWithFormat:@"%@\n", self.primaryAccount.password]];
}

@end
