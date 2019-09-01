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
{
    if (!request.loginHint && !request.homeAccountIdentifier)
    {
        [self aadEnterEmail];
    }

    [self aadEnterPassword];
    
    // Keep me signed in
    [self acceptMSSTSConsentIfNecessary:@"Yes" embeddedWebView:request.usesEmbeddedWebView];
    
    // Consent
    [self acceptMSSTSConsentIfNecessary:self.consentTitle ? self.consentTitle : @"Accept" embeddedWebView:request.usesEmbeddedWebView];

    [self assertAccessTokenNotNil];
    [self assertScopesReturned:[request.expectedResultScopes msidScopeSet].array];

    MSIDAutomationSuccessResult *result = [self automationSuccessResult];
    NSString *homeAccountId = result.userInformation.homeAccountId;
    XCTAssertNotNil(homeAccountId);

    [self closeResultView];
    return homeAccountId;
}

#pragma mark - Interactive login

- (void)testInteractiveB2CLogin_withEmbeddedWebView_withoutLoginHint_withSigninPolicy_withTenantName_withMSAAccount
{
    MSIDAutomationConfigurationRequest *configurationRequest = [MSIDAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderB2CMSA;
    [self loadTestConfiguration:configurationRequest];

    MSIDAutomationTestRequest *request = [MSIDAutomationTestRequest new];
    request.clientId = self.testConfiguration.clientId;
    request.redirectUri = self.testConfiguration.redirectUri;
    request.requestScopes = self.testConfiguration.resource;
    request.extraScopes = request.requestScopes;
    request.testAccount = [self.primaryAccount copy];
    request.webViewType = MSALWebviewTypeWKWebView;
    request.requestIDP = @"Microsoft";
    request.promptBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider b2cAuthorityForIdentifier:self.testEnvironment tenantName:self.primaryAccount.tenantName policy:self.testConfiguration.policies[@"signin"]];
    request.expectedResultAuthority = [self.class.confProvider b2cAuthorityForIdentifier:self.testEnvironment tenantName:self.primaryAccount.homeTenantId policy:self.testConfiguration.policies[@"signin"]];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.homeTenantId];

    // 1. Start B2C login
    [self runSharedB2CLoginStartWithTestRequest:request];

    // 2. Sign in with MSA
    NSString *homeAccountId = [self runSharedB2CMSALoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 3. Run UI appeared step
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    request.homeAccountIdentifier = homeAccountId;
    // 4. Run silent login
    request.testAccount = nil;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveB2CLogin_withEmbeddedWebView_withoutLoginHint_withSigninPolicy_withGUIDTenantId_withMSAAccount
{
    MSIDAutomationConfigurationRequest *configurationRequest = [MSIDAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderB2CMSA;
    [self loadTestConfiguration:configurationRequest];

    MSIDAutomationTestRequest *request = [MSIDAutomationTestRequest new];
    request.clientId = self.testConfiguration.clientId;
    request.redirectUri = self.testConfiguration.redirectUri;
    request.requestScopes = self.testConfiguration.resource;
    request.extraScopes = request.requestScopes;
    request.testAccount = [self.primaryAccount copy];
    request.webViewType = MSALWebviewTypeWKWebView;
    request.requestIDP = @"Microsoft";
    request.promptBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider b2cAuthorityForIdentifier:self.testEnvironment tenantName:self.primaryAccount.targetTenantId policy:self.testConfiguration.policies[@"signin"]];
    request.expectedResultAuthority = [self.class.confProvider b2cAuthorityForIdentifier:self.testEnvironment tenantName:self.primaryAccount.homeTenantId policy:self.testConfiguration.policies[@"signin"]];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.homeTenantId];

    // 1. Start B2C login
    [self runSharedB2CLoginStartWithTestRequest:request];

    // 2. Sign in with MSA
    NSString *homeAccountId = [self runSharedB2CMSALoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 3. Run UI appeared step
    [self runSharedAuthUIAppearsStepWithTestRequest:request];
    request.homeAccountIdentifier = homeAccountId;
    // 4. Run silent login
    request.testAccount = nil;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveB2CLogin_withSafariViewController_withoutLoginHint_withSigninPolicy_withMSAAccount
{
    MSIDAutomationConfigurationRequest *configurationRequest = [MSIDAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderB2CMSA;
    [self loadTestConfiguration:configurationRequest];

    MSIDAutomationTestRequest *request = [MSIDAutomationTestRequest new];
    request.clientId = self.testConfiguration.clientId;
    request.redirectUri = self.testConfiguration.redirectUri;
    request.requestScopes = self.testConfiguration.resource;
    request.extraScopes = request.requestScopes;
    request.testAccount = [self.primaryAccount copy];
    request.webViewType = MSIDWebviewTypeSafariViewController;
    request.requestIDP = @"Microsoft";
    request.configurationAuthority = [self.class.confProvider b2cAuthorityForIdentifier:self.testEnvironment tenantName:self.primaryAccount.targetTenantId policy:self.testConfiguration.policies[@"signin"]];
    request.expectedResultAuthority = [self.class.confProvider b2cAuthorityForIdentifier:self.testEnvironment tenantName:self.primaryAccount.homeTenantId policy:self.testConfiguration.policies[@"signin"]];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.homeTenantId];

    // 1. Start B2C login
    [self runSharedB2CLoginStartWithTestRequest:request];

    // 2. Sign in with MSA
    NSString *homeAccountId = [self runSharedB2CMSALoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);

    request.homeAccountIdentifier = homeAccountId;
    // 3. Run silent login
    request.testAccount = nil;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

#pragma mark - Multi policy

- (void)testInteractiveB2CLogin_withPassedInWebView_withoutLoginHint_withSigninAndProfilePolicies_withTenantName_withMSAAccount
{
    MSIDAutomationConfigurationRequest *configurationRequest = [MSIDAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderB2CMSA;
    [self loadTestConfiguration:configurationRequest];

    MSIDAutomationTestRequest *request = [MSIDAutomationTestRequest new];
    request.clientId = self.testConfiguration.clientId;
    request.redirectUri = self.testConfiguration.redirectUri;
    request.requestScopes = self.testConfiguration.resource;
    request.extraScopes = request.requestScopes;
    request.testAccount = self.primaryAccount;
    request.usePassedWebView = YES;
    request.requestIDP = @"Microsoft";
    request.configurationAuthority = [self.class.confProvider b2cAuthorityForIdentifier:self.testEnvironment tenantName:self.primaryAccount.targetTenantId policy:self.testConfiguration.policies[@"signin"]];
    request.expectedResultAuthority = [self.class.confProvider b2cAuthorityForIdentifier:self.testEnvironment tenantName:self.primaryAccount.homeTenantId policy:self.testConfiguration.policies[@"signin"]];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.homeTenantId];

    // 1. Start B2C login
    [self runSharedB2CLoginStartWithTestRequest:request];

    // 2. Sign in with MSA
    NSString *homeAccountId = [self runSharedB2CMSALoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 3. Start profile policy
    MSIDAutomationTestRequest *profileRequest = [MSIDAutomationTestRequest new];
    profileRequest.clientId = self.testConfiguration.clientId;
    profileRequest.redirectUri = self.testConfiguration.redirectUri;
    profileRequest.requestScopes = self.testConfiguration.resource;
    profileRequest.extraScopes = profileRequest.requestScopes;
    profileRequest.testAccount = self.primaryAccount;
    profileRequest.usePassedWebView = YES;
    profileRequest.loginHint = self.primaryAccount.username;
    profileRequest.requestIDP = @"Microsoft";
    profileRequest.configurationAuthority = [self.class.confProvider b2cAuthorityForIdentifier:self.testEnvironment tenantName:self.primaryAccount.targetTenantId policy:self.testConfiguration.policies[@"profile"]];
    profileRequest.expectedResultAuthority = [self.class.confProvider b2cAuthorityForIdentifier:self.testEnvironment tenantName:self.primaryAccount.homeTenantId policy:self.testConfiguration.policies[@"profile"]];
    profileRequest.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.homeTenantId];

    [self runSharedB2CLoginStartWithTestRequest:profileRequest];

    // 4. Edit profile with MSA
    XCUIElement *profileEditButton = self.testApp.buttons[@"Continue"];
    [self waitForElement:profileEditButton];
    [profileEditButton msidTap];
    [self assertAccessTokenNotNil];

    MSIDAutomationSuccessResult *result = [self automationSuccessResult];
    NSString *profileHomeAccountId = result.userInformation.homeAccountId;
    XCTAssertNotNil(profileHomeAccountId);
    [self closeResultView];

    // 5. Get token silently for the first request
    request.homeAccountIdentifier = homeAccountId;
    request.testAccount = nil;
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
