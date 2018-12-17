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
#import "MSIDAutomationTestRequest.h"
#import "MSIDTestConfigurationProvider.h"
#import "NSString+MSIDAutomationUtils.h"

@interface MSALAADBasicInteractiveTests : MSALBaseAADUITest

@end

@implementation MSALAADBasicInteractiveTests

#pragma mark - Setup

- (void)setUp
{
    [super setUp];

    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    [self loadTestConfiguration:configurationRequest];
}

#pragma mark - Different apps/scopes

/*
 Test matrix:

 App                Scopes              Endpoint
 Converged          MS graph            common
 Non-Converged      .default            organizations
                    3P resource*        consumers
                                        tenanted

 *not available yet
 */

// Converged app tests
- (void)testInteractiveAADLogin_withConvergedApp_andMicrosoftGraphScopes_andCommonEndpoint_andForceLogin
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultConvergedAppRequest:environment];
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];

    // 1. Run interactive
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);
    XCTAssertEqualObjects(homeAccountId, self.primaryAccount.homeAccountId);

    // 2. Run auth UI appears
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    // 3. Run silent wiht common authority
    NSString *scopes = [self.class.confProvider scopesForEnvironment:environment type:@"ms_graph"];
    NSOrderedSet *scopesSet = [scopes msidScopeSet];
    NSString *firstScope = [scopesSet objectAtIndex:0];
    request.acquireTokenAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:@"common"];
    request.requestScopes = firstScope;
    request.homeAccountIdentifier = homeAccountId;
    [self runSharedSilentAADLoginWithTestRequest:request];

    // 4. Run silent with tenant authority
    request.acquireTokenAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.requestScopes = firstScope;
    [self runSharedSilentAADLoginWithTestRequest:request];

    // 5. Run silent with invalid scopes
    request.requestScopes = [self.class.confProvider scopesForEnvironment:environment type:@"unsupported"];
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireTokenSilent:config];
    [self assertErrorCode:@"MSALErrorInvalidScope"];
    [self closeResultView];

    // 6. Run silent with not consented scopes
    request.requestScopes = [self.class.confProvider scopesForEnvironment:environment type:@"not_consented"];
    config = [self configWithTestRequest:request];
    [self acquireTokenSilent:config];
    [self assertErrorCode:@"MSALErrorInteractionRequired"];
    [self assertErrorSubcode:@"consent_required"];
    [self closeResultView];

    // 7. Invalidate refresh token and expire access token
    request.requestScopes = firstScope;
    config = [self configWithTestRequest:request];
    [self invalidateRefreshToken:config];
    [self assertRefreshTokenInvalidated];
    [self closeResultView];

    [self expireAccessToken:config];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // 8. Assert invalid grant, because RT is invalid
    [self acquireTokenSilent:config];
    [self assertErrorCode:@"MSALErrorInteractionRequired"];
}

- (void)testInteractiveAADLogin_withConvergedApp_andMicrosoftGraphScopes_andCommonEndpoint_andDifferentAuthorityAliases
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultConvergedAppRequest:environment];
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];

    // 1. Run interactive
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];

    XCTAssertNotNil(homeAccountId);

    [self.testApp terminate];
    [self.testApp launch];

    NSDictionary *configuration = [self configWithTestRequest:request];
    [self readAccounts:configuration];

    NSDictionary *result = [self resultDictionary];
    XCTAssertEqual([result[@"account_count"] integerValue], 1);
    NSArray *accounts = result[@"accounts"];
    NSDictionary *firstAccount = accounts[0];
    XCTAssertEqualObjects(firstAccount[@"home_account_id"], homeAccountId);
    [self closeResultView];

    // 2. Run silent with a different authority alias
    request.homeAccountIdentifier = homeAccountId;
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:@"ww-alias"];
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:@"ww-alias" tenantId:self.primaryAccount.targetTenantId];
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultConvergedAppRequest:environment];
    request.uiBehavior = @"force";
    request.requestScopes = [self.class.confProvider scopesForEnvironment:environment type:@"ms_graph_static"];
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:[self.class.confProvider scopesForEnvironment:environment type:@"oidc"]];
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];

    // 1. Run interactive
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2. Run silent
    request.homeAccountIdentifier = homeAccountId;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withConvergedApp_andMicrosoftGraphScopes_andTenantedEndpoint_andForceLogin
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultConvergedAppRequest:environment];
    request.uiBehavior = @"force";
    request.requestScopes = [self.class.confProvider scopesForEnvironment:environment type:@"ms_graph_prefixed"];
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:[self.class.confProvider scopesForEnvironment:environment type:@"oidc"]];
    request.testAccount = self.primaryAccount;
    NSString *tenantedAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.configurationAuthority = tenantedAuthority;
    request.expectedResultAuthority = tenantedAuthority;
    request.cacheAuthority = tenantedAuthority;

    // 1. Run Interactive
    [self runSharedAADLoginWithTestRequest:request];
}

// Non-converged app tests
- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andCommonEndpoint_andForceLogin
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.requestScopes = [self.class.confProvider scopesForEnvironment:environment type:@"ms_graph_static"];
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:[self.class.confProvider scopesForEnvironment:environment type:@"oidc"]];
    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.username;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];

    // 1. Run Interactive
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];

    // 2. Run silent
    request.homeAccountIdentifier = homeAccountId;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:@"organizations"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:environment type:@"ms_graph_static"];
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:[self.class.confProvider scopesForEnvironment:environment type:@"oidc"]];
    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.username;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];

    // 1. Run Interactive
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];

    // 2. Run silent
    request.homeAccountIdentifier = homeAccountId;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andMicrosoftGraphScopes_andTenantedEndpoint_andForceLogin
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:environment type:@"ms_graph"];
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:[self.class.confProvider scopesForEnvironment:environment type:@"oidc"]];
    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.username;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];

    // 1. Run Interactive
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];

    // 2. Run silent
    request.homeAccountIdentifier = homeAccountId;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andInsufficientScopes_andForceLogin
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    NSString *ignoredScope = [self.class.confProvider scopesForEnvironment:environment type:@"ignored"];
    NSString *supportedScope = [self.class.confProvider scopesForEnvironment:environment type:@"ms_graph"];
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:@"organizations"];
    NSString *requestScopes = [NSString msidCombinedScopes:supportedScope withScopes:ignoredScope];
    request.requestScopes = requestScopes;
    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.username;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];

    // Run interactive
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];
    [self acceptAuthSessionDialog];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept" embeddedWebView:NO];

    // Verify error and granted/declined scopes contents
    [self assertErrorCode:@"MSALErrorServerDeclinedScopes"];
    NSDictionary *resultContent = [self resultDictionary];
    NSArray *declinedScopes = resultContent[@"user_info"][MSALDeclinedScopesKey];
    XCTAssertEqualObjects(declinedScopes, @[ignoredScope]);

    NSArray *grantedScopes = resultContent[@"user_info"][MSALGrantedScopesKey];
    NSOrderedSet *expectedGrantedScopes = [supportedScope msidScopeSet];
    XCTAssertTrue([expectedGrantedScopes isSubsetOfOrderedSet:[NSOrderedSet orderedSetWithArray:grantedScopes]]);

    [self closeResultView];

    // Now run silent with insufficient scopes
    request.homeAccountIdentifier = self.primaryAccount.homeAccountId;
    config = [self configWithTestRequest:request];
    [self acquireTokenSilent:config];

    // Verify error and granted/declined scopes contents
    [self assertErrorCode:@"MSALErrorServerDeclinedScopes"];
    resultContent = [self resultDictionary];
    declinedScopes = resultContent[@"user_info"][MSALDeclinedScopesKey];
    XCTAssertEqualObjects(declinedScopes, @[ignoredScope]);

    grantedScopes = resultContent[@"user_info"][MSALGrantedScopesKey];
    XCTAssertTrue([expectedGrantedScopes isSubsetOfOrderedSet:[NSOrderedSet orderedSetWithArray:grantedScopes]]);

    [self closeResultView];

    // Now run silent with correct scopes
    request.requestScopes = supportedScope;
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:[self.class.confProvider scopesForEnvironment:environment type:@"oidc"]];
    [self runSharedSilentAADLoginWithTestRequest:request];
}

#pragma mark - Prompt behavior

- (void)testInteractiveAADLogin_withNonConvergedApp_andMicrosoftGraphScopes_andTenantedEndpoint_andSelectAccount
{
    // Sign in first time to ensure account will be there
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:environment type:@"ms_graph"];
    request.expectedResultScopes = request.requestScopes;
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    
    [self runSharedAADLoginWithTestRequest:request];

    // Now call acquire token with select account
    request.uiBehavior = @"select_account";
    NSDictionary *config = [self configWithTestRequest:request];

    [self acquireToken:config];
    [self acceptAuthSessionDialog];

    [self selectAccountWithTitle:self.primaryAccount.account];

    [self assertAccessTokenNotNil];
    [self closeResultView];
}

#pragma mark - Errors

- (void)testInteractiveAADLogin_withConvergedApp_andForceConsent_andLoginHint_andRejectConsent
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultConvergedAppRequest:environment];
    request.uiBehavior = @"consent";
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.loginHint = self.primaryAccount.username;
    request.webViewType = MSIDWebviewTypeWKWebView;

    // 1. Sign in interactively
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];
    [self aadEnterPassword];

    XCUIElement *permissionText = self.testApp.staticTexts[@"Permissions requested"];
    [self waitForElement:permissionText];

    XCUIElement *acceptButton = [self.testApp.webViews elementBoundByIndex:0].buttons[@"Cancel"];
    [acceptButton msidTap];

    [self assertErrorCode:@"MSALErrorAuthorizationFailed"];
}

#pragma mark - MDM

// 296732: Company Portal Install Prompt
- (void)testCompanyPortalInstallPrompt_withNonConvergedApp_withSystemWebView
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.requestScopes = [self.class.confProvider scopesForEnvironment:environment type:@"ms_graph"];
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:[self.class.confProvider scopesForEnvironment:environment type:@"oidc"]];
    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.username;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];

    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    configurationRequest.accountFeatures = @[MSIDTestAccountFeatureMDMEnabled];
    [self loadTestConfiguration:configurationRequest];

    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.username;

    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];
    [self acceptAuthSessionDialog];
    [self aadEnterPassword];

    XCUIElement *enrollButton = self.testApp.buttons[@"Enroll now"];
    [self waitForElement:enrollButton];
    [enrollButton msidTap];

    XCUIElement *getTheAppButton = self.testApp.staticTexts[@"GET THE APP"];
    [self waitForElement:getTheAppButton];
    [self.testApp activate];
}

// 296732: Company Portal Install Prompt
- (void)testCompanyPortalInstallPrompt_withConvergedApp_withEmbeddedWebview
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultConvergedAppRequest:environment];
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.username;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];

    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    configurationRequest.accountFeatures = @[MSIDTestAccountFeatureMDMEnabled];
    [self loadTestConfiguration:configurationRequest];

    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.username;
    request.webViewType = MSIDWebviewTypeWKWebView;

    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];
    [self aadEnterPassword];

    XCUIElement *enrollButton = self.testApp.buttons[@"Enroll now"];
    [self waitForElement:enrollButton];
    [enrollButton msidTap];

    XCUIApplication *safari = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.mobilesafari"];

    BOOL result = [safari waitForState:XCUIApplicationStateRunningForeground timeout:20];
    XCTAssertTrue(result);

    XCUIElement *getTheAppButton = safari.staticTexts[@"GET THE APP"];
    [self waitForElement:getTheAppButton];
    [self.testApp activate];

    [self assertErrorCode:@"MSALErrorSessionCanceled"];
}

#pragma mark - Login hint

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin_andLoginHint
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:@"organizations"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:environment type:@"aad_graph_static"];
    request.expectedResultScopes = request.requestScopes;
    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.username;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];

    [self runSharedAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin_andAccount
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:@"organizations"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:environment type:@"aad_graph_static"];
    request.expectedResultScopes = request.requestScopes;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];

    // 1. Sign in interactively first
    [self runSharedAADLoginWithTestRequest:request];

    // 2. Sign in with home account id now
    request.homeAccountIdentifier = self.primaryAccount.homeAccountId;
    [self runSharedAADLoginWithTestRequest:request];
}

// TODO: this test will be failing until server side fixes the bug of returning .default
- (void)DISABLED_testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin_andLoginHint_andResourceGUID
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:@"organizations"];
    NSString *scope = [self.class.confProvider resourceForEnvironment:environment type:@"aad_graph_guid"];
    request.requestScopes = [scope stringByAppendingString:@"/.default"];
    request.expectedResultScopes = request.requestScopes;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.loginHint = self.primaryAccount.account;

    [self runSharedAADLoginWithTestRequest:request];
}

// TODO: this test will be failing until server side fixes the bug of returning just user.read back
- (void)DISABLED_testInteractiveAADLogin_withConvergedApp_andOrganizationsEndpoint_andForceLogin_andLoginHint_andResourceGUID
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultConvergedAppRequest:environment];
    request.uiBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:@"common"];
    NSString *scope = [self.class.confProvider resourceForEnvironment:environment type:@"ms_graph_guid"];
    request.requestScopes = [scope stringByAppendingString:@"/.default"];
    request.expectedResultScopes = request.requestScopes;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.loginHint = self.primaryAccount.account;

    [self runSharedAADLoginWithTestRequest:request];
}

#pragma mark - Embedded webview

- (void)testInteractiveAADLogin_withNonConvergedApp_andMicrosoftGraphScopes_andTenantedEndpoint_andPassedInWebView_andSelectAccount
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:environment type:@"ms_graph"];
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:[self.class.confProvider scopesForEnvironment:environment type:@"oidc"]];
    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.username;
    request.usePassedWebView = YES;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];

    // 1. Sign in first time to ensure account will be there
    [self runSharedAADLoginWithTestRequest:request];

    request.uiBehavior = @"select_account";
    request.loginHint = nil;
    NSDictionary *config = [self configWithTestRequest:request];

    // 2. Now call acquire token with select account
    [self acquireToken:config];

    [self selectAccountWithTitle:self.primaryAccount.account];

    [self assertAccessTokenNotNil];
    [self closeResultView];
}

- (void)testInteractiveAADLogin_withConvergedApp_andMicrosoftGraphScopes_andCommonEndpoint_andPassedInEmbeddedWebView_andForceLogin
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultConvergedAppRequest:environment];
    request.uiBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:environment type:@"aad_graph_static"];
    request.expectedResultScopes = request.requestScopes;
    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.username;
    request.usePassedWebView = YES;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];

    // 1. Run interactive
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2. Run UI appears (will also cancel)
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    request.homeAccountIdentifier = homeAccountId;
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.windows.net/%@", self.primaryAccount.targetTenantId];
    // 3. Run silent
    [self runSharedSilentAADLoginWithTestRequest:request];
}

#pragma mark - SafariViewController

- (void)testInteractiveAADLogin_withNonConvergedApp_andMSGraphScopes_andOrganizationsEndpoint_andSafariViewController_andForceConsent
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:environment type:@"ms_graph"];
    request.expectedResultScopes = request.requestScopes;
    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.username;
    request.webViewType = MSIDWebviewTypeSafariViewController;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];

    // 1. Sign in first time to ensure account will be there
    [self runSharedAADLoginWithTestRequest:request];

    // 2. Run UI appears
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    request.uiBehavior = @"consent";
    request.loginHint = nil;
    NSDictionary *config = [self configWithTestRequest:request];

    // 3. Now call acquire token with force consent
    [self acquireToken:config];

    [self selectAccountWithTitle:self.primaryAccount.account];

    XCUIElement *permissionText = self.testApp.staticTexts[@"Permissions requested"];
    [self waitForElement:permissionText];

    XCUIElement *acceptButton = self.testApp.buttons[@"Accept"];
    [acceptButton msidTap];

    [self assertAccessTokenNotNil];
    [self closeResultView];
}

- (void)testClaimsChallenge_withConvergedApp_withEmbeddedWebview
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultConvergedAppRequest:environment];
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.webViewType = MSIDWebviewTypeWKWebView;
    
    // 1. Run interactive without claims, which should succeed
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    request.homeAccountIdentifier = homeAccountId;
    request.claims = @"{\"access_token\":{\"deviceid\":{\"essential\":true}}}";
    
    // 2. Run interactive with claims, which should prompt for Intune/Broker installation
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];
    [self assertAuthUIAppearsUsingEmbeddedWebView:request.usesEmbeddedWebView];
    [self aadEnterPassword];
    
    XCUIElement *registerButton = self.testApp.buttons[@"Get the app"];
    [self waitForElement:registerButton];
}

- (void)testClaimsChallenge_withNonConvergedApp_withSystemWebview
{
    NSString *environment = self.class.confProvider.wwEnvironment;
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:@"organizations"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:environment type:@"ms_graph_static"];
    request.expectedResultScopes = request.requestScopes;
    request.expectedResultAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:environment tenantId:self.primaryAccount.targetTenantId];
    
    // 1. Run interactive without claims, which should succeed
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    
    XCTAssertNotNil(homeAccountId);
    
    request.homeAccountIdentifier = homeAccountId;
    request.claims = @"{\"access_token\":{\"deviceid\":{\"essential\":true}}}";
    
    // 2. Run interactive with claims, which should prompt for Intune/Broker installation
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];
    [self acceptAuthSessionDialogIfNecessary:request];
    [self assertAuthUIAppearsUsingEmbeddedWebView:request.usesEmbeddedWebView];
    [self aadEnterPassword];
    
    XCUIElement *registerButton = self.testApp.buttons[@"Get the app"];
    [self waitForElement:registerButton];
}

@end
