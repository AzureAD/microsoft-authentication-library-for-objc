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

@interface MSALAADBasicInteractiveTests : MSALBaseAADUITest
{
    id _interruptMonitor;
}

@end

@implementation MSALAADBasicInteractiveTests

#pragma mark - Setup

- (void)setUp
{
    [super setUp];

    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    configurationRequest.appVersion = MSIDAppVersionV1;
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
    NSArray *expectedResultScopes = @[@"user.read",
                                      @"tasks.read",
                                      @"openid",
                                      @"profile"];

    NSString *cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    MSALTestRequest *request = [MSALTestRequest convergedAppRequest];
    request.scopes = @"user.read tasks.read";
    request.expectedResultScopes = expectedResultScopes;
    request.authority = @"https://login.microsoftonline.com/common";
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];

    // 1. Run interactive
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];

    XCTAssertNotNil(homeAccountId);

    // 2. Run auth UI appears
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    request.scopes = @"user.read";
    request.authority = nil;
    request.accountIdentifier = homeAccountId;
    request.cacheAuthority = cacheAuthority;

    // 3. Run silent
    [self runSharedSilentAADLoginWithTestRequest:request];

    // 4. Run silent with invalid scopes
    request.scopes = @"Directory.ReadAll";
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireTokenSilent:config];
    [self assertErrorCode:@"MSALErrorInvalidScope"];
    [self closeResultView];

    // 5. Run silent with not consented scopes
    request.scopes = @"Contacts.Read";
    config = [self configWithTestRequest:request];
    [self acquireTokenSilent:config];
    [self assertErrorCode:@"MSALErrorInteractionRequired"];
    [self assertErrorSubcode:@"consent_required"];
    [self closeResultView];

    // 6. Invalidate refresh token and expire access token
    request.scopes = @"user.read";
    request.authority = cacheAuthority;
    config = [self configWithTestRequest:request];
    [self invalidateRefreshToken:config];
    [self assertRefreshTokenInvalidated];
    [self closeResultView];

    [self expireAccessToken:config];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // 7. Assert invalid grant, because RT is invalid
    [self acquireTokenSilent:config];
    [self assertErrorCode:@"MSALErrorInteractionRequired"];
}

- (void)testInteractiveAADLogin_withConvergedApp_andMicrosoftGraphScopes_andCommonEndpoint_andDifferentAuthorityAliases
{
    NSArray *expectedResultScopes = @[@"user.read",
                                      @"tasks.read",
                                      @"openid",
                                      @"profile"];

    NSString *cacheAuthority = [NSString stringWithFormat:@"https://login.windows.net/%@", self.primaryAccount.targetTenantId];

    MSALTestRequest *request = [MSALTestRequest convergedAppRequest];
    request.scopes = @"user.read tasks.read";
    request.expectedResultScopes = expectedResultScopes;
    request.authority = @"https://login.microsoftonline.com/common";
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];

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

    // Run silent with a different authority
    request.cacheAuthority = cacheAuthority;
    request.accountIdentifier = homeAccountId;
    request.authority = @"https://login.windows.net/common";
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.windows.net/", self.primaryAccount.targetTenantId];
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin
{
    MSALTestRequest *request = [MSALTestRequest convergedAppRequest];
    request.scopes = @"https://graph.microsoft.com/.default";
    request.expectedResultScopes = @[@"https://graph.microsoft.com/user.read",
                                      @"https://graph.microsoft.com/.default",
                                      @"openid", @"profile"];
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];

    // 1. Run interactive
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2. Run silent
    request.accountIdentifier = homeAccountId;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withConvergedApp_andMicrosoftGraphScopes_andTenantedEndpoint_andForceLogin
{
    MSALTestRequest *request = [MSALTestRequest convergedAppRequest];
    request.scopes = @"https://graph.microsoft.com/user.read";
    request.expectedResultScopes = @[@"https://graph.microsoft.com/user.read",
                                      @"openid", @"profile"];
    request.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    request.cacheAuthority = request.authority;
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];

    // 1. Run Interactive
    [self runSharedAADLoginWithTestRequest:request];
}

// Non-converged app tests
- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andCommonEndpoint_andForceLogin
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.scopes = @"https://graph.microsoft.com/.default";
    request.authority = @"https://login.microsoftonline.com/common";
    request.uiBehavior = @"force";
    request.loginHint = self.primaryAccount.username;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];

    // 1. Run Interactive
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];

    // 2. Run silent
    request.accountIdentifier = homeAccountId;
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.scopes = @"https://graph.microsoft.com/.default";
    request.expectedResultScopes = @[@"https://graph.microsoft.com/user.read",
                                     @"https://graph.microsoft.com/.default",
                                     @"openid", @"profile"];
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;

    // 1. Run Interactive
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2. Run silent
    request.accountIdentifier = homeAccountId;
    request.scopes = @"https://graph.microsoft.com/user.read";
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andMicrosoftGraphScopes_andTenantedEndpoint_andForceLogin
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.scopes = @"user.read tasks.read";
    request.expectedResultScopes = @[@"user.read",
                                     @"tasks.read"];
    request.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    request.cacheAuthority = request.authority;
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];

    // 1. Run Interactive
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2. Run silent
    request.accountIdentifier = homeAccountId;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andInsufficientScopes_andForceLogin
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.scopes = @"user.read tasks.read address";
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.account;

    // Run interactive
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];
    [self acceptAuthSessionDialog];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept" embeddedWebView:NO];

    // Verify error and granted/declined scopes contents
    [self assertErrorCode:@"MSALErrorServerDeclinedScopes"];
    NSDictionary *resultContent = [self resultDictionary];
    NSArray *declinedScopes = resultContent[@"user_info"][@"MSALDeclinedScopesKey"];
    XCTAssertEqualObjects(declinedScopes, @[@"address"]);

    NSArray *grantedScopes = resultContent[@"user_info"][@"MSALGrantedScopesKey"];
    XCTAssertTrue([grantedScopes containsObject:@"user.read"]);
    XCTAssertTrue([grantedScopes containsObject:@"tasks.read"]);

    [self closeResultView];

    // Now run silent with insufficient scopes
    request.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    request.accountIdentifier = self.primaryAccount.homeAccountId;
    config = [self configWithTestRequest:request];
    [self acquireTokenSilent:config];

    // Verify error and granted/declined scopes contents
    [self assertErrorCode:@"MSALErrorServerDeclinedScopes"];
    resultContent = [self resultDictionary];
    declinedScopes = resultContent[@"user_info"][@"MSALDeclinedScopesKey"];
    XCTAssertEqualObjects(declinedScopes, @[@"address"]);

    grantedScopes = resultContent[@"user_info"][@"MSALGrantedScopesKey"];
    XCTAssertTrue([grantedScopes containsObject:@"user.read"]);
    XCTAssertTrue([grantedScopes containsObject:@"tasks.read"]);

    [self closeResultView];

    // Now run silent with correct scopes
    request.cacheAuthority = request.authority;
    request.scopes = @"user.read tasks.read";
    request.expectedResultScopes = @[@"user.read", @"tasks.read", @"openid", @"profile"];

    [self runSharedSilentAADLoginWithTestRequest:request];
}

#pragma mark - Prompt behavior

- (void)testInteractiveAADLogin_withNonConvergedApp_andMicrosoftGraphScopes_andTenantedEndpoint_andSelectAccount
{
    // Sign in first time to ensure account will be there
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    request.scopes = @"user.read";
    request.expectedResultScopes = @[@"user.read"];
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];
    
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

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceConsent
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.scopes = @"user.read";
    request.expectedResultScopes = @[@"user.read", @"openid", @"profile"];
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];

    // 1. Run interactive
    [self runSharedAADLoginWithTestRequest:request];

    // 2. Run force consent
    request.uiBehavior = @"consent";
    NSDictionary *config = [self configWithTestRequest:request];

    // Now call acquire token with force consent
    [self acquireToken:config];
    [self acceptAuthSessionDialog];

    [self selectAccountWithTitle:self.primaryAccount.account];

    XCUIElement *permissionText = self.testApp.staticTexts[@"Permissions requested"];
    [self waitForElement:permissionText];

    XCUIElement *acceptButton = self.testApp.buttons[@"Accept"];
    [acceptButton msidTap];

    [self assertAccessTokenNotNil];
    [self closeResultView];
}

#pragma mark - Errors

- (void)testInteractiveAADLogin_withConvergedApp_andForceConsent_andLoginHint_andRejectConsent
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.scopes = @"https://graph.windows.net/.default";
    request.expectedResultScopes = @[@"https://graph.windows.net/.default"];
    request.loginHint = self.primaryAccount.username;
    request.uiBehavior = @"consent";
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];

    // 1. Sign in interactively
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];
    [self acceptAuthSessionDialog];
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
    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    configurationRequest.accountFeatures = @[MSIDTestAccountFeatureMDMEnabled];
    // TODO: remove me once lab is fixed
    configurationRequest.additionalQueryParameters = @{@"AppID": @"4b0db8c2-9f26-4417-8bde-3f0e3656f8e0"};
    [self loadTestConfiguration:configurationRequest];

    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.scopes = @"user.read";
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.loginHint = self.primaryAccount.account;

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
    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    configurationRequest.accountFeatures = @[MSIDTestAccountFeatureMDMEnabled];
    // TODO: remove me once lab is fixed
    configurationRequest.additionalQueryParameters = @{@"AppID": @"4b0db8c2-9f26-4417-8bde-3f0e3656f8e0"};
    [self loadTestConfiguration:configurationRequest];

    MSALTestRequest *request = [MSALTestRequest convergedAppRequest];
    request.uiBehavior = @"force";
    request.scopes = @"user.read";
    request.authority = @"https://login.microsoftonline.com/common";
    request.webViewType = MSALWebviewTypeWKWebView;
    request.loginHint = self.primaryAccount.account;

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
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.scopes = @"https://graph.windows.net/.default";
    request.expectedResultScopes = @[@"https://graph.windows.net/user.read",
                                     @"https://graph.windows.net/.default"];
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.uiBehavior = @"force";
    request.loginHint = self.primaryAccount.account;
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];

    [self runSharedAADLoginWithTestRequest:request];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin_andAccount
{
    // 1. Sign in first to get an account
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.scopes = @"https://graph.windows.net/.default";
    request.expectedResultScopes = @[@"https://graph.windows.net/user.read",
                                     @"https://graph.windows.net/.default"];;
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];

    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2. Now pass the account identifier
    request.accountIdentifier = homeAccountId;
    [self runSharedAADLoginWithTestRequest:request];
}

// TODO: server side bug!
- (void)DISABLED_testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin_andLoginHint_andResourceGUID
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.scopes = @"00000002-0000-0000-c000-000000000000/.default";
    request.expectedResultScopes = @[@"00000002-0000-0000-c000-000000000000/user.read",
                                     @"00000002-0000-0000-c000-000000000000/.default"];
    request.uiBehavior = @"force";
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.loginHint = self.primaryAccount.account;
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];

    [self runSharedAADLoginWithTestRequest:request];
}

#pragma mark - Embedded webview

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andEmbeddedWebView_andForceConsent
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.scopes = @"https://graph.windows.net/.default";
    request.expectedResultScopes = @[@"https://graph.windows.net/.default"];
    request.loginHint = self.primaryAccount.username;
    request.webViewType = MSALWebviewTypeWKWebView;
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];

    // 1. Sign in interactively
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    request.accountIdentifier = homeAccountId;
    request.uiBehavior = @"consent";

    NSDictionary *config = [self configWithTestRequest:request];

    // 2. Sign in with force consent
    [self acquireToken:config];
    [self aadEnterPassword];

    XCUIElement *permissionText = self.testApp.staticTexts[@"Permissions requested"];
    [self waitForElement:permissionText];

    XCUIElement *acceptButton = self.testApp.buttons[@"Accept"];
    [acceptButton msidTap];

    [self assertAccessTokenNotNil];
    [self closeResultView];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andMicrosoftGraphScopes_andTenantedEndpoint_andPassedInWebView_andSelectAccount
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.scopes = @"user.read tasks.read";
    request.expectedResultScopes = @[@"user.read", @"tasks.read", @"openid", @"profile"];
    request.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    request.uiBehavior = @"force";
    request.loginHint = self.primaryAccount.username;
    request.usePassedWebView = YES;
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];

    // 1. Sign in first time to ensure account will be there
    [self runSharedAADLoginWithTestRequest:request];

    request.uiBehavior = @"select_account";
    request.loginHint = nil;
    NSDictionary *config = [self configWithTestRequest:request];

    // 2. Now call acquire token with force consent
    [self acquireToken:config];

    [self selectAccountWithTitle:self.primaryAccount.account];

    [self assertAccessTokenNotNil];
    [self closeResultView];
}

- (void)testInteractiveAADLogin_withConvergedApp_andMicrosoftGraphScopes_andCommonEndpoint_andPassedInEmbeddedWebView_andForceLogin
{
    MSALTestRequest *request = [MSALTestRequest convergedAppRequest];
    request.scopes = @"user.read";
    request.expectedResultScopes = @[@"user.read", @"openid", @"profile"];
    request.authority = @"https://login.windows.net/common";
    request.uiBehavior = @"force";
    request.usePassedWebView = YES;
    request.loginHint = self.primaryAccount.username;
    request.testAccount = self.primaryAccount;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.windows.net/", self.primaryAccount.targetTenantId];

    // 1. Run interactive
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2. Run UI appears (will also cancel)
    [self runSharedAuthUIAppearsStepWithTestRequest:request];

    request.accountIdentifier = homeAccountId;
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.windows.net/%@", self.primaryAccount.targetTenantId];
    // 3. Run silent
    [self runSharedSilentAADLoginWithTestRequest:request];
}

#pragma mark - SafariViewController

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andSafariViewController_andForceConsent
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.scopes = @"https://graph.windows.net/.default";
    request.expectedResultScopes = @[@"https://graph.windows.net/.default"];
    request.uiBehavior = @"force";
    request.loginHint = self.primaryAccount.username;
    request.testAccount = self.primaryAccount;
    request.webViewType = MSALWebviewTypeSafariViewController;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];

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

- (void)testInteractiveAADLogin_withNonConvergedApp_andMicrosoftGraphScopes_andTenantedEndpoint_andSafariViewController_andSelectAccount
{
    // 1. Sign in first time to ensure account will be there
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    request.scopes = @"tasks.read";
    request.expectedResultScopes = @[@"tasks.read", @"openid", @"profile"];
    request.uiBehavior = @"force";
    request.loginHint = self.primaryAccount.username;
    request.testAccount = self.primaryAccount;
    request.webViewType = MSALWebviewTypeSafariViewController;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];

    [self runSharedAADLoginWithTestRequest:request];

    request.uiBehavior = @"select_account";
    request.loginHint = nil;

    NSDictionary *config = [self configWithTestRequest:request];
    // 2. Now call acquire token with force consent
    [self acquireToken:config];

    [self selectAccountWithTitle:self.primaryAccount.account];

    [self assertAccessTokenNotNil];
    [self closeResultView];
}

- (void)testClaimsChallenge_withConvergedApp_withEmbeddedWebview
{
    NSArray *expectedResultScopes = @[@"user.read",
                                      @"tasks.read",
                                      @"openid",
                                      @"profile"];
    
    MSALTestRequest *request = [MSALTestRequest convergedAppRequest];
    request.scopes = @"user.read tasks.read";
    request.expectedResultScopes = expectedResultScopes;
    request.authority = @"https://login.microsoftonline.com/common";
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.webViewType = MSALWebviewTypeWKWebView;
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];
    
    // 1. Run interactive without claims, which should succeed
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    
    XCTAssertNotNil(homeAccountId);

    request.accountIdentifier = homeAccountId;
    request.claims = @"%7B%22access_token%22%3A%7B%22deviceid%22%3A%7B%22essential%22%3Atrue%7D%7D%7D";
    
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
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.scopes = @"https://graph.microsoft.com/.default";
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.uiBehavior = @"force";
    request.expectedResultAuthority = [NSString stringWithFormat:@"%@%@", @"https://login.microsoftonline.com/", self.primaryAccount.targetTenantId];
    
    // 1. Run interactive without claims, which should succeed
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    
    XCTAssertNotNil(homeAccountId);
    
    request.accountIdentifier = homeAccountId;
    request.claims = @"%7B%22access_token%22%3A%7B%22deviceid%22%3A%7B%22essential%22%3Atrue%7D%7D%7D";
    
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
