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

    // Run interactive
    NSString *homeAccountId = [self runSharedAADLoginWithClientId:@"3c62ac97-29eb-4aed-a3c8-add0298508da"
                                                           scopes:@"user.read tasks.read"
                                             expectedResultScopes:expectedResultScopes
                                                      redirectUri:@"msal3c62ac97-29eb-4aed-a3c8-add0298508da://auth"
                                                        authority:@"https://login.microsoftonline.com/common"
                                                       uiBehavior:@"force"
                                                        loginHint:nil
                                                accountIdentifier:nil
                                                validateAuthority:YES
                                               useEmbeddedWebView:NO
                                          useSafariViewController:NO
                                                  expectedAccount:self.primaryAccount];

    XCTAssertNotNil(homeAccountId);

    [self runSharedAuthUIAppearsStepWithClientId:@"3c62ac97-29eb-4aed-a3c8-add0298508da"
                                          scopes:@"user.read"
                                     redirectUri:@"msal3c62ac97-29eb-4aed-a3c8-add0298508da://auth"
                                       authority:@"https://login.microsoftonline.com/common"
                                      uiBehavior:@"force"
                                       loginHint:nil
                               accountIdentifier:nil
                               validateAuthority:YES
                              useEmbeddedWebView:NO
                         useSafariViewController:NO];

    // Run silent
    [self runSharedSilentAADLoginWithClientId:@"3c62ac97-29eb-4aed-a3c8-add0298508da"
                                       scopes:@"user.read"
                         expectedResultScopes:expectedResultScopes
                              silentAuthority:nil
                               cacheAuthority:cacheAuthority
                            accountIdentifier:homeAccountId
                            validateAuthority:YES
                              expectedAccount:self.primaryAccount];
}

- (void)testInteractiveAADLogin_withConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin
{
    NSArray *expectedResultScopes = @[@"https://graph.microsoft.com/user.read",
                                      @"https://graph.microsoft.com/.default",
                                      @"openid", @"profile"];

    NSString *cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    // Run interactive
    NSString *homeAccountId = [self runSharedAADLoginWithClientId:@"3c62ac97-29eb-4aed-a3c8-add0298508da"
                                                           scopes:@"https://graph.microsoft.com/.default"
                                             expectedResultScopes:expectedResultScopes
                                                      redirectUri:@"msal3c62ac97-29eb-4aed-a3c8-add0298508da://auth"
                                                        authority:@"https://login.microsoftonline.com/organizations"
                                                       uiBehavior:@"force"
                                                        loginHint:nil
                                                accountIdentifier:nil
                                                validateAuthority:YES
                                               useEmbeddedWebView:NO
                                          useSafariViewController:NO
                                                  expectedAccount:self.primaryAccount];

    XCTAssertNotNil(homeAccountId);

    // Run silent
    [self runSharedSilentAADLoginWithClientId:@"3c62ac97-29eb-4aed-a3c8-add0298508da"
                                       scopes:@"https://graph.microsoft.com/.default"
                         expectedResultScopes:expectedResultScopes
                              silentAuthority:nil
                               cacheAuthority:cacheAuthority
                            accountIdentifier:homeAccountId
                            validateAuthority:YES
                              expectedAccount:self.primaryAccount];
}

- (void)testInteractiveAADLogin_withConvergedApp_andMicrosoftGraphScopes_andTenantedEndpoint_andForceLogin
{
    NSArray *expectedResultScopes = @[@"https://graph.microsoft.com/user.read",
                                      @"openid", @"profile"];

    NSString *authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    [self runSharedAADLoginWithClientId:@"3c62ac97-29eb-4aed-a3c8-add0298508da"
                                 scopes:@"https://graph.microsoft.com/user.read"
                   expectedResultScopes:expectedResultScopes
                            redirectUri:@"msal3c62ac97-29eb-4aed-a3c8-add0298508da://auth"
                              authority:authority
                             uiBehavior:@"force"
                              loginHint:nil
                      accountIdentifier:nil
                      validateAuthority:YES
                     useEmbeddedWebView:NO
                useSafariViewController:NO
                        expectedAccount:self.primaryAccount];
}

// Non-converged app tests
- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andCommonEndpoint_andForceLogin
{
    NSDictionary *config = [self configDictionaryWithClientId:nil
                                                       scopes:@"https://graph.microsoft.com/.default"
                                                  redirectUri:nil
                                                    authority:@"https://login.microsoftonline.com/common"
                                                   uiBehavior:@"force"
                                                    loginHint:nil
                                            validateAuthority:YES
                                           useEmbeddedWebView:NO
                                      useSafariViewController:NO
                                            accountIdentifier:nil];
    [self acquireToken:config];

    [self allowSFAuthenticationSessionAlert];

    [self aadEnterEmail];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept"];
    [self assertErrorCode:@"MSALErrorInvalidRequest"];
    [self assertErrorDescription:@"Please use the /organizations or tenant-specific endpoint."];
    [self closeResultView];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin
{
    NSArray *expectedScopes = @[@"https://graph.microsoft.com/user.read",
                                @"https://graph.microsoft.com/.default",
                                @"openid", @"profile"];

    NSString *homeAccountId = [self runSharedAADLoginWithClientId:nil
                                                           scopes:@"https://graph.microsoft.com/.default"
                                             expectedResultScopes:expectedScopes
                                                      redirectUri:nil
                                                        authority:@"https://login.microsoftonline.com/organizations"
                                                       uiBehavior:@"force"
                                                        loginHint:nil
                                                accountIdentifier:nil
                                                validateAuthority:YES
                                               useEmbeddedWebView:NO
                                          useSafariViewController:NO
                                                  expectedAccount:self.primaryAccount];

    XCTAssertNotNil(homeAccountId);

    NSString *authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    [self runSharedSilentAADLoginWithClientId:nil
                                       scopes:@"https://graph.microsoft.com/.default"
                         expectedResultScopes:expectedScopes
                              silentAuthority:nil
                               cacheAuthority:authority
                            accountIdentifier:homeAccountId
                            validateAuthority:YES
                              expectedAccount:self.primaryAccount];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andMicrosoftGraphScopes_andTenantedEndpoint_andForceLogin
{
    NSString *authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    NSArray *expectedScopes = @[@"user.read",
                                @"tasks.read"];

    NSString *homeAccountId = [self runSharedAADLoginWithClientId:nil
                                                           scopes:@"user.read tasks.read"
                                             expectedResultScopes:expectedScopes
                                                      redirectUri:nil
                                                        authority:authority
                                                       uiBehavior:@"force"
                                                        loginHint:nil
                                                accountIdentifier:nil
                                                validateAuthority:YES
                                               useEmbeddedWebView:NO
                                          useSafariViewController:NO
                                                  expectedAccount:self.primaryAccount];

    [self runSharedSilentAADLoginWithClientId:nil
                                       scopes:@"tasks.read"
                         expectedResultScopes:expectedScopes
                              silentAuthority:nil
                               cacheAuthority:authority
                            accountIdentifier:homeAccountId
                            validateAuthority:YES
                              expectedAccount:self.primaryAccount];
}

#pragma mark - Prompt behavior

- (void)testInteractiveAADLogin_withNonConvergedApp_andMicrosoftGraphScopes_andTenantedEndpoint_andSelectAccount
{
    // Sign in first time to ensure account will be there
    NSString *authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    [self runSharedAADLoginWithClientId:nil
                                 scopes:@"user.read"
                   expectedResultScopes:@[@"user.read"]
                            redirectUri:nil
                              authority:authority
                             uiBehavior:@"force"
                              loginHint:nil
                      accountIdentifier:nil
                      validateAuthority:YES
                     useEmbeddedWebView:NO
                useSafariViewController:NO
                        expectedAccount:self.primaryAccount];

    // Now call acquire token with select account
    NSDictionary *config = [self configDictionaryWithClientId:nil
                                                       scopes:@"user.read"
                                                  redirectUri:nil
                                                    authority:authority
                                                   uiBehavior:@"select_account"
                                                    loginHint:nil
                                            validateAuthority:YES
                                           useEmbeddedWebView:NO
                                      useSafariViewController:NO
                                            accountIdentifier:nil];

    [self acquireToken:config];
    [self allowSFAuthenticationSessionAlert];

    XCUIElement *pickAccount = self.testApp.staticTexts[@"Pick an account"];
    [self waitForElement:pickAccount];

    NSPredicate *accountPredicate = [NSPredicate predicateWithFormat:@"label CONTAINS[c] %@", self.primaryAccount.account];
    XCUIElement *element = [[self.testApp.buttons containingPredicate:accountPredicate] elementBoundByIndex:0];
    XCTAssertNotNil(element);

    [element msidTap];
    [self assertAccessTokenNotNil];
    [self closeResultView];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceConsent
{
    // Sign in first time to ensure account will be there
    NSString *authority = @"https://login.microsoftonline.com/organizations";

    [self runSharedAADLoginWithClientId:nil
                                 scopes:@"user.read"
                   expectedResultScopes:@[@"user.read"]
                            redirectUri:nil
                              authority:authority
                             uiBehavior:@"force"
                              loginHint:nil
                      accountIdentifier:nil
                      validateAuthority:YES
                     useEmbeddedWebView:NO
                useSafariViewController:NO
                        expectedAccount:self.primaryAccount];

    NSDictionary *config = [self configDictionaryWithClientId:nil
                                                       scopes:@"user.read"
                                                  redirectUri:nil
                                                    authority:authority
                                                   uiBehavior:@"consent"
                                                    loginHint:nil
                                            validateAuthority:YES
                                           useEmbeddedWebView:NO
                                      useSafariViewController:NO
                                            accountIdentifier:nil];

    // Now call acquire token with force consent
    [self acquireToken:config];
    [self allowSFAuthenticationSessionAlert];

    XCUIElement *pickAccount = self.testApp.staticTexts[@"Pick an account"];
    [self waitForElement:pickAccount];

    NSPredicate *accountPredicate = [NSPredicate predicateWithFormat:@"label CONTAINS[c] %@", self.primaryAccount.account];
    XCUIElement *element = [[self.testApp.buttons containingPredicate:accountPredicate] elementBoundByIndex:0];
    XCTAssertNotNil(element);

    [element msidTap];

    XCUIElement *permissionText = self.testApp.staticTexts[@"Permissions requested"];
    [self waitForElement:permissionText];

    XCUIElement *acceptButton = self.testApp.buttons[@"Accept"];
    [acceptButton msidTap];

    [self assertAccessTokenNotNil];
    [self closeResultView];
}

#pragma mark - Login hint

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin_andLoginHint
{
    NSArray *expectedResultScopes = @[@"https://graph.windows.net/user.read",
                                      @"https://graph.windows.net/.default"];

    [self runSharedAADLoginWithClientId:nil
                                 scopes:@"https://graph.windows.net/.default"
                   expectedResultScopes:expectedResultScopes
                            redirectUri:nil
                              authority:@"https://login.microsoftonline.com/organizations"
                             uiBehavior:@"force"
                              loginHint:self.primaryAccount.account
                      accountIdentifier:nil
                      validateAuthority:YES
                     useEmbeddedWebView:NO
                useSafariViewController:NO
                        expectedAccount:self.primaryAccount];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin_andAccount
{
    // Sign in first to get an account

    NSArray *expectedResultScopes = @[@"https://graph.windows.net/user.read",
                                      @"https://graph.windows.net/.default"];

    NSString *homeAccountId = [self runSharedAADLoginWithClientId:nil
                                                           scopes:@"https://graph.windows.net/.default"
                                             expectedResultScopes:expectedResultScopes
                                                      redirectUri:nil
                                                        authority:@"https://login.microsoftonline.com/organizations"
                                                       uiBehavior:@"force"
                                                        loginHint:nil
                                                accountIdentifier:nil
                                                validateAuthority:YES
                                               useEmbeddedWebView:NO
                                          useSafariViewController:NO
                                                  expectedAccount:self.primaryAccount];

    XCTAssertNotNil(homeAccountId);

    // Now pass the account identifier
    [self runSharedAADLoginWithClientId:nil
                                 scopes:@"https://graph.windows.net/.default"
                   expectedResultScopes:expectedResultScopes
                            redirectUri:nil
                              authority:@"https://login.microsoftonline.com/organizations"
                             uiBehavior:@"force"
                              loginHint:nil
                      accountIdentifier:homeAccountId
                      validateAuthority:YES
                     useEmbeddedWebView:NO
                useSafariViewController:NO
                        expectedAccount:self.primaryAccount];


}

// TODO: server side bug!
- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin_andLoginHint_andResourceGUID
{
    NSArray *expectedResultScopes = @[@"00000002-0000-0000-c000-000000000000/user.read",
                                      @"00000002-0000-0000-c000-000000000000/.default"];

    [self runSharedAADLoginWithClientId:nil
                                 scopes:@"00000002-0000-0000-c000-000000000000/.default"
                   expectedResultScopes:expectedResultScopes
                            redirectUri:nil
                              authority:@"https://login.microsoftonline.com/organizations"
                             uiBehavior:@"force"
                              loginHint:self.primaryAccount.account
                      accountIdentifier:nil
                      validateAuthority:YES
                     useEmbeddedWebView:NO
                useSafariViewController:NO
                        expectedAccount:self.primaryAccount];
}

#pragma mark - Embedded webview

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andEmbeddedWebView_andForceConsent
{
    // TODO: needs embedded webview
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andMicrosoftGraphScopes_andTenantedEndpoint_andEmbeddedWebView_andSelectAccount
{
    // TODO: needs embedded webview
}

- (void)testInteractiveAADLogin_withConvergedApp_andMicrosoftGraphScopes_andCommonEndpoint_andEmbeddedWebView_andForceLogin
{
    // TODO: needs embedded webview
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andTenantedEndpoint_andEmbeddedWebView_andForceLogin
{
    // TODO: needs embedded webview
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andMicrosoftGraphScopes_andOrganizationsEndpoint_andPassedInEmbeddedWebView_andForceLogin
{
    // TODO: needs passed embedded webview
}

#pragma mark - SafariViewController

// TODO

@end
