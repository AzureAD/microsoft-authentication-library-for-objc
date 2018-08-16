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

@end

@implementation MSALB2CInteractiveTests

#pragma mark - Setup

- (void)setUp
{
    [super setUp];
}

#pragma mark - Shared

- (void)runSharedB2CLoginStartWithTestRequest:(MSALTestRequest *)request
{
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];

    [self acceptAuthSessionDialogIfNecessary:request];

    [self assertAuthUIAppearWithEmbeddedWebView:request.usesEmbeddedWebView];

    if (!request.loginHint && !request.accountIdentifier)
    {
        [self b2cSelectProvider:request.b2cProvider];
    }
}

- (void)b2cSelectProvider:(NSString *)identityProvider
{
    XCUIElement *idpButton = self.testApp.buttons[identityProvider];
    [self waitForElement:idpButton];
    [idpButton msidTap];
}

- (NSString *)runSharedB2CMSALoginWithRequest:(MSALTestRequest *)request
{
    if (!request.loginHint && !request.accountIdentifier)
    {
        [self aadEnterEmail];
    }

    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:self.consentTitle ? self.consentTitle : @"Accept" embeddedWebView:request.usesEmbeddedWebView];

    [self assertAccessTokenNotNil];
    [self assertScopesReturned:request.expectedResultScopes];

    NSDictionary *resultDictionary = [self resultDictionary];
    NSString *homeAccountId = resultDictionary[@"user"][@"home_account_id"];
    XCTAssertNotNil(homeAccountId);

    if (request.testAccount)
    {
        XCTAssertEqualObjects(homeAccountId, request.testAccount.homeAccountId);
    }

    [self closeResultView];
    return homeAccountId;
}

#pragma mark - Interactive login

- (void)testInteractiveB2CLogin_withEmbeddedWebView_withoutLoginHint_withSigninPolicy_withTenantName_withMSAAccount
{
    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderB2CMSA;
    configurationRequest.appVersion = MSIDAppVersionV1;
    configurationRequest.accountFeatures = @[];
    [self loadTestConfiguration:configurationRequest];

    MSALTestRequest *request = [MSALTestRequest b2CRequestWithSigninPolicyWithAccount:self.primaryAccount];
    request.scopes = [NSString stringWithFormat:@"%@/user.read", self.testConfiguration.resource];
    request.expectedResultScopes = @[request.scopes];
    request.uiBehavior = @"force";
    request.testAccount = [self.primaryAccount copy];
    request.testAccount.homeObjectId = [NSString stringWithFormat:@"%@-b2c_1_signin", self.primaryAccount.homeObjectId];
    request.webViewType = MSALWebviewTypeWKWebView;
    request.b2cProvider = @"Microsoft";

    // 1. Start B2C login
    [self runSharedB2CLoginStartWithTestRequest:request];

    // 2. Sign in with MSA
    NSString *homeAccountId = [self runSharedB2CMSALoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 3. Run UI appeared step
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    request.accountIdentifier = homeAccountId;
    // B2C currently doesn't return "tid" claim in the id_token, so MSAL will use tenantId from the provided authority
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.tenantName];
    // 4. Run silent login
    request.testAccount = nil;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveB2CLogin_withEmbeddedWebView_withoutLoginHint_withSigninPolicy_withGUIDTenantId_withMSAAccount
{
    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderB2CMSA;
    configurationRequest.appVersion = MSIDAppVersionV1;
    configurationRequest.accountFeatures = @[];
    [self loadTestConfiguration:configurationRequest];

    MSALTestRequest *request = [MSALTestRequest b2CRequestWithSigninPolicyWithAccount:self.primaryAccount];
    request.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/tfp/%@/B2C_1_Signin", self.primaryAccount.targetTenantId];
    request.scopes = [NSString stringWithFormat:@"%@/user.read", self.testConfiguration.resource];
    request.expectedResultScopes = @[request.scopes];
    request.uiBehavior = @"force";
    request.testAccount = [self.primaryAccount copy];
    request.testAccount.homeObjectId = [NSString stringWithFormat:@"%@-b2c_1_signin", self.primaryAccount.homeObjectId];
    request.webViewType = MSALWebviewTypeWKWebView;
    request.b2cProvider = @"Microsoft";

    // 1. Start B2C login
    [self runSharedB2CLoginStartWithTestRequest:request];

    // 2. Sign in with MSA
    NSString *homeAccountId = [self runSharedB2CMSALoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 3. Run UI appeared step
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    request.accountIdentifier = homeAccountId;
    // B2C currently doesn't return "tid" claim in the id_token, so MSAL will use tenantId from the provided authority
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    // 4. Run silent login
    request.testAccount = nil;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveB2CLogin_withSafariViewController_withoutLoginHint_withSigninPolicy_withMSAAccount
{
    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderB2CMSA;
    configurationRequest.appVersion = MSIDAppVersionV1;
    configurationRequest.accountFeatures = @[];
    [self loadTestConfiguration:configurationRequest];

    MSALTestRequest *request = [MSALTestRequest b2CRequestWithSigninPolicyWithAccount:self.primaryAccount];
    request.scopes = [NSString stringWithFormat:@"%@/user.read", self.testConfiguration.resource];
    request.expectedResultScopes = @[request.scopes];
    request.uiBehavior = @"force";
    request.testAccount = [self.primaryAccount copy];
    request.testAccount.homeObjectId = [NSString stringWithFormat:@"%@-b2c_1_signin", self.primaryAccount.homeObjectId];
    request.b2cProvider = @"Microsoft";
    request.webViewType = MSALWebviewTypeSafariViewController;

    // 1. Start B2C login
    [self runSharedB2CLoginStartWithTestRequest:request];

    // 2. Sign in with MSA
    NSString *homeAccountId = [self runSharedB2CMSALoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 3. Run UI appeared step
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    request.accountIdentifier = homeAccountId;
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.tenantName];
    // 4. Run silent login
    request.testAccount = nil;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

#pragma mark - Multi policy

- (void)testInteractiveB2CLogin_withPassedInWebView_withoutLoginHint_withSigninAndProfilePolicies_withTenantName_withMSAAccount
{
    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderB2CMSA;
    configurationRequest.appVersion = MSIDAppVersionV1;
    configurationRequest.accountFeatures = @[];
    [self loadTestConfiguration:configurationRequest];

    MSALTestRequest *request = [MSALTestRequest b2CRequestWithSigninPolicyWithAccount:self.primaryAccount];
    request.scopes = [NSString stringWithFormat:@"%@/user.read", self.testConfiguration.resource];
    request.expectedResultScopes = @[request.scopes];
    request.uiBehavior = @"force";
    request.testAccount = [self.primaryAccount copy];
    request.testAccount.homeObjectId = [NSString stringWithFormat:@"%@-b2c_1_signin", self.primaryAccount.homeObjectId];
    request.usePassedWebView = YES;
    request.b2cProvider = @"Microsoft";

    // 1. Start B2C login
    [self runSharedB2CLoginStartWithTestRequest:request];

    // 2. Sign in with MSA
    NSString *homeAccountId = [self runSharedB2CMSALoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 3. Start profile policy
    MSALTestRequest *profileRequest = [MSALTestRequest b2CRequestWithProfilePolicyWithAccount:self.primaryAccount];
    profileRequest.scopes = [NSString stringWithFormat:@"%@/user.read", self.testConfiguration.resource];
    profileRequest.expectedResultScopes = @[profileRequest.scopes];
    profileRequest.uiBehavior = @"force";
    profileRequest.testAccount = [self.primaryAccount copy];
    profileRequest.testAccount.homeObjectId = [NSString stringWithFormat:@"%@-b2c_1_profile", self.primaryAccount.homeObjectId];
    profileRequest.usePassedWebView = YES;
    profileRequest.b2cProvider = @"Microsoft";

    [self runSharedB2CLoginStartWithTestRequest:profileRequest];

    // 4. Edit profile with MSA
    XCUIElement *profileEditButton = self.testApp.buttons[@"Continue"];
    [self waitForElement:profileEditButton];
    [profileEditButton msidTap];
    [self assertAccessTokenNotNil];

    NSDictionary *resultDictionary = [self resultDictionary];
    NSString *profileHomeAccountId = resultDictionary[@"user"][@"home_account_id"];
    XCTAssertNotNil(profileHomeAccountId);
    XCTAssertEqualObjects(profileHomeAccountId, profileRequest.testAccount.homeAccountId);
    [self closeResultView];

    // 5. Get token silently for the first request
    request.accountIdentifier = homeAccountId;
    // B2C currently doesn't return "tid" claim in the id_token, so MSAL will use tenantId from the provided authority
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.tenantName];
    request.testAccount = nil;
    [self runSharedSilentAADLoginWithTestRequest:request];

    // 6. Get token silently for the second request
    profileRequest.accountIdentifier = profileHomeAccountId;
    // B2C currently doesn't return "tid" claim in the id_token, so MSAL will use tenantId from the provided authority
    profileRequest.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.tenantName];
    profileRequest.testAccount = nil;
    [self runSharedSilentAADLoginWithTestRequest:profileRequest];
}

// TODO: B2C ignores login_hint?
// TODO: B2C ignores prompt_type?

@end
