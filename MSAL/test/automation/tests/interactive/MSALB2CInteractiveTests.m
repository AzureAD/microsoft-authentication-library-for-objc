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

@interface MSALB2CInteractiveTests : MSALBaseAADUITest

@property (nonatomic) NSString *testEnvironment;

@end

@implementation MSALB2CInteractiveTests

#pragma mark - Setup

- (void)setUp
{
    [super setUp];
    self.testEnvironment = self.class.confProvider.wwEnvironment;
    self.consentTitle = @"Yes";
    
    MSIDTestAutomationAppConfigurationRequest *appConfigurationRequest = [MSIDTestAutomationAppConfigurationRequest new];
    appConfigurationRequest.testAppEnvironment = MSIDTestAppEnvironmentAzureB2C;
    appConfigurationRequest.testAppAudience = MSIDTestAppAudienceMultipleOrgs;
    
    [self loadTestApp:appConfigurationRequest];
    [self.testApplication setRedirectUriPrefix:[NSString stringWithFormat:@"msal%@", self.testApplication.appId]];
    
    MSIDTestAutomationAccountConfigurationRequest *accountConfigurationRequest = [MSIDTestAutomationAccountConfigurationRequest new];
    accountConfigurationRequest.environmentType = self.testEnvironment;
    accountConfigurationRequest.accountType = MSIDTestAccountTypeB2C;
    accountConfigurationRequest.b2cProviderType = MSIDTestAccountB2CProviderTypeMSA;
    
    [self loadTestAccount:accountConfigurationRequest];
}

#pragma mark - Shared

- (void)runSharedB2CLoginStartWithTestRequest:(MSIDAutomationTestRequest *)request
{
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];

    [self acceptAuthSessionDialogIfNecessary:request];

    [self assertAuthUIAppearsUsingEmbeddedWebView:request.usesEmbeddedWebView];

    if (!request.loginHint && !request.homeAccountIdentifier)
    {
        [self b2cSelectProvider:request.requestIDP];
    }
}

- (void)b2cSelectProvider:(NSString *)identityProvider
{
    XCUIElement *idpButton = self.testApp.buttons[identityProvider];
    [self waitForElement:idpButton];
    [idpButton msidTap];
}

- (NSString *)runSharedB2CMSALoginWithRequest:(MSIDAutomationTestRequest *)request
                              closeResultView:(BOOL)closeResultView
                          shouldEnterPassword:(BOOL)shouldEnterPassword
{
    if (!request.loginHint && !request.homeAccountIdentifier)
    {
        [self aadEnterEmail];
    }

    if (shouldEnterPassword) [self aadEnterPassword];
    
    // Consent
    [self acceptMSSTSConsentIfNecessary:self.consentTitle ? self.consentTitle : @"Accept" embeddedWebView:request.usesEmbeddedWebView];

    [self assertAccessTokenNotNil];
    [self assertScopesReturned:[request.expectedResultScopes msidScopeSet].array];

    MSIDAutomationSuccessResult *result = [self automationSuccessResult];
    NSString *homeAccountId = result.userInformation.homeAccountId;
    XCTAssertNotNil(homeAccountId);

    if (closeResultView)
    {
        [self closeResultView];
    }
    return homeAccountId;
}

#pragma mark - Interactive login

- (void)testInteractiveB2CLogin_withEmbeddedWebView_withoutLoginHint_withSigninPolicy_withTenantName_withMSAAccount
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.requestScopes = self.testApplication.defaultScopes.msidToString;
    request.testAccount = self.primaryAccount;
    request.webViewType = MSALWebviewTypeWKWebView;
    request.requestIDP = @"Microsoft";
    request.promptBehavior = @"force";
    request.configurationAuthority = [self.testApplication b2cAuthorityForPolicy:@"SignInPolicy" tenantId:nil];
    request.expectedResultScopes = request.requestScopes;
    
    // 1. Start B2C login
    [self runSharedB2CLoginStartWithTestRequest:request];

    // 2. Sign in with MSA
    NSString *homeAccountId = [self runSharedB2CMSALoginWithRequest:request closeResultView:NO shouldEnterPassword:YES];
    XCTAssertNotNil(homeAccountId);
    
    MSIDAutomationSuccessResult *result = [self automationSuccessResult];
    NSString *homeTenantId = result.userInformation.tenantId;
    
    [self closeResultView];

    // 3. Run UI appeared step
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    request.homeAccountIdentifier = homeAccountId;
    request.cacheAuthority = [self.testApplication b2cAuthorityForPolicy:@"SignInPolicy" tenantId:homeTenantId];
    // 4. Run silent login
    request.testAccount = nil;
    request.expectedResultAuthority = request.cacheAuthority;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveB2CLogin_withEmbeddedWebView_withoutLoginHint_withSigninPolicy_withGUIDTenantId_withMSAAccount
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.requestScopes = self.testApplication.defaultScopes.msidToString;
    request.testAccount = self.primaryAccount;
    request.webViewType = MSALWebviewTypeWKWebView;
    request.requestIDP = @"Microsoft";
    request.promptBehavior = @"force";
    request.configurationAuthority = [self.testApplication b2cAuthorityForPolicy:@"SignInPolicy" tenantId:nil];
    request.expectedResultScopes = request.requestScopes;
    
    // 1. Start B2C login
    [self runSharedB2CLoginStartWithTestRequest:request];

    // 2. Sign in with MSA
    NSString *homeAccountId = [self runSharedB2CMSALoginWithRequest:request closeResultView:NO shouldEnterPassword:YES];
    XCTAssertNotNil(homeAccountId);
    
    MSIDAutomationSuccessResult *result = [self automationSuccessResult];
    NSString *homeTenantId = result.userInformation.tenantId;
    
    [self closeResultView];
    [self clearCookies];
        
    request.configurationAuthority = [self.testApplication b2cAuthorityForPolicy:@"SignInPolicy" tenantId:homeTenantId];
    request.usePassedWebView = YES;
    [self runSharedB2CLoginStartWithTestRequest:request];
    NSString *homeAccountId2 = [self runSharedB2CMSALoginWithRequest:request closeResultView:YES shouldEnterPassword:YES];
    XCTAssertEqualObjects(homeAccountId, homeAccountId2);
}

- (void)testInteractiveB2CLogin_withSafariViewController_withoutLoginHint_withSigninPolicy_withMSAAccount
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.requestScopes = self.testApplication.defaultScopes.msidToString;
    request.testAccount = self.primaryAccount;
    request.webViewType = MSIDWebviewTypeSafariViewController;
    request.requestIDP = @"Microsoft";
    request.promptBehavior = @"force";
    request.configurationAuthority = [self.testApplication b2cAuthorityForPolicy:@"SignInPolicy" tenantId:nil];
    request.expectedResultScopes = request.requestScopes;
    
    // 1. Start B2C login
    [self runSharedB2CLoginStartWithTestRequest:request];

    // 2. Sign in with MSA
    NSString *homeAccountId = [self runSharedB2CMSALoginWithRequest:request closeResultView:NO shouldEnterPassword:YES];
    XCTAssertNotNil(homeAccountId);
    
    MSIDAutomationSuccessResult *result = [self automationSuccessResult];
    NSString *homeTenantId = result.userInformation.tenantId;
    
    [self closeResultView];

    request.homeAccountIdentifier = homeAccountId;
    request.cacheAuthority = [self.testApplication b2cAuthorityForPolicy:@"SignInPolicy" tenantId:homeTenantId];
    request.expectedResultAuthority = request.cacheAuthority;
    // 3. Run silent login
    request.testAccount = nil;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

#pragma mark - Multi policy

- (void)testInteractiveB2CLogin_withPassedInWebView_withoutLoginHint_withSigninAndProfilePolicies_withTenantName_withMSAAccount
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.requestScopes = self.testApplication.defaultScopes.msidToString;
    request.testAccount = self.primaryAccount;
    request.webViewType = MSIDWebviewTypeWKWebView;
    request.usePassedWebView = YES;
    request.requestIDP = @"Microsoft";
    request.promptBehavior = @"force";
    request.configurationAuthority = [self.testApplication b2cAuthorityForPolicy:@"SignInPolicy" tenantId:nil];
    request.expectedResultScopes = request.requestScopes;
    
    // 1. Start B2C login
    [self runSharedB2CLoginStartWithTestRequest:request];

    // 2. Sign in with MSA
    NSString *homeAccountId = [self runSharedB2CMSALoginWithRequest:request closeResultView:NO shouldEnterPassword:YES];
    XCTAssertNotNil(homeAccountId);
    
    MSIDAutomationSuccessResult *result = [self automationSuccessResult];
    NSString *homeTenantId = result.userInformation.tenantId;
    
    [self closeResultView];

    // 3. Start profile policy
    MSIDAutomationTestRequest *profileRequest = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    profileRequest.requestScopes = self.testApplication.defaultScopes.msidToString;
    profileRequest.extraScopes = profileRequest.requestScopes;
    profileRequest.testAccount = self.primaryAccount;
    profileRequest.usePassedWebView = YES;
    profileRequest.loginHint = self.primaryAccount.upn;
    profileRequest.requestIDP = @"Microsoft";
    profileRequest.configurationAuthority = [self.testApplication b2cAuthorityForPolicy:@"ProfileEditPolicy" tenantId:nil];
    profileRequest.expectedResultScopes = request.requestScopes;
    profileRequest.cacheAuthority = [self.testApplication b2cAuthorityForPolicy:@"ProfileEditPolicy" tenantId:homeTenantId];
    profileRequest.expectedResultAuthority = profileRequest.cacheAuthority;

    [self runSharedB2CLoginStartWithTestRequest:profileRequest];

    // 4. Edit profile with MSA
    XCUIElement *profileEditButton = self.testApp.buttons[@"Continue"];
    [self waitForElement:profileEditButton];
    [profileEditButton msidTap];
    [self assertAccessTokenNotNil];

    result = [self automationSuccessResult];
    NSString *profileHomeAccountId = result.userInformation.homeAccountId;
    XCTAssertNotNil(profileHomeAccountId);
    [self closeResultView];

    // 5. Get token silently for the first request
    request.homeAccountIdentifier = homeAccountId;
    request.testAccount = nil;
    request.cacheAuthority = [self.testApplication b2cAuthorityForPolicy:@"SignInPolicy" tenantId:homeTenantId];
    request.expectedResultAuthority = request.cacheAuthority;
    [self runSharedSilentAADLoginWithTestRequest:request];

    // 6. Get token silently for the second request
    profileRequest.homeAccountIdentifier = profileHomeAccountId;
    profileRequest.testAccount = nil;
    [self runSharedSilentAADLoginWithTestRequest:profileRequest];

    // 7. Restart the test app and make sure we're still able to retrieve the token
    [self.testApp terminate];
    [self.testApp launch];

    [self runSharedSilentAADLoginWithTestRequest:profileRequest];
}

// TODO: B2C ignores login_hint?
// TODO: B2C ignores prompt_type?

@end
