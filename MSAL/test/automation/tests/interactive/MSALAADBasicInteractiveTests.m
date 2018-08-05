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
#import "XCUIElement+CrossPlat.h"

@interface MSALAADBasicInteractiveTests : MSALBaseUITest

@end

@implementation MSALAADBasicInteractiveTests

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
    NSDictionary *params = @{
                             @"ui_behavior" : @"force",
                             @"validate_authority" : @YES,
                             @"authority": @"https://login.microsoftonline.com/common",
                             @"scopes": @"user.read tasks.read",
                             @"redirect_uri": @"msal3c62ac97-29eb-4aed-a3c8-add0298508da://auth",
                             @"client_id": @"3c62ac97-29eb-4aed-a3c8-add0298508da"
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];

    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept"];

    [self assertAccessTokenNotNil];
    [self assertScopesReturned:@[@"user.read",
                                 @"tasks.read",
                                 @"openid",
                                 @"profile"]];

    NSDictionary *resultDictionary = [self resultDictionary];
    NSString *homeAccountId = resultDictionary[@"user"][@"home_account_id"];
    XCTAssertNotNil(homeAccountId);

    [self closeResultView];

    // Assert UI appears again
    [self acquireToken:config];
    [self assertAuthUIAppear];
    [self closeAuthUIWithSystemWebView];
    [self assertErrorCode:@"MSALErrorUserCanceled"];

    [self closeResultView];

    // Now do acquiretoken silent request without authority
    NSDictionary *silentParams = @{
                                   @"home_account_identifier": homeAccountId,
                                   @"client_id": @"3c62ac97-29eb-4aed-a3c8-add0298508da",
                                   @"scopes": @"user.read"
                                   };

    config = [self.testConfiguration configWithAdditionalConfiguration:silentParams];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    NSMutableDictionary *mutableConfig = [config mutableCopy];
    NSString *authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    mutableConfig[@"authority"] = authority;

    // Now expire access token
    [self expireAccessToken:mutableConfig];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // Now do access token refresh
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Now lookup access token without authority
    [mutableConfig removeObjectForKey:@"authority"];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];

    [self assertScopesReturned:@[@"user.read",
                                 @"tasks.read",
                                 @"openid",
                                 @"profile"]];

    [self closeResultView];
}

- (void)testInteractiveAADLogin_withConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin
{
    NSDictionary *params = @{
                             @"ui_behavior" : @"force",
                             @"validate_authority" : @YES,
                             @"authority": @"https://login.microsoftonline.com/organizations",
                             @"scopes": @"https://graph.microsoft.com/.default",
                             @"redirect_uri": @"msal3c62ac97-29eb-4aed-a3c8-add0298508da://auth",
                             @"client_id": @"3c62ac97-29eb-4aed-a3c8-add0298508da"
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];

    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept"];
    [self assertScopesReturned:@[@"https://graph.microsoft.com/user.read",
                                 @"https://graph.microsoft.com/.default",
                                 @"openid", @"profile"]];

    [self assertAccessTokenNotNil];

    NSDictionary *resultDictionary = [self resultDictionary];
    NSString *homeAccountId = resultDictionary[@"user"][@"home_account_id"];
    XCTAssertNotNil(homeAccountId);

    [self closeResultView];

    // Now do acquiretoken silent request
    NSDictionary *silentParams = @{
                                   @"home_account_identifier": homeAccountId,
                                   @"client_id": @"3c62ac97-29eb-4aed-a3c8-add0298508da",
                                   @"scopes": @"https://graph.microsoft.com/.default"
                                   };

    config = [self.testConfiguration configWithAdditionalConfiguration:silentParams];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    NSMutableDictionary *mutableConfig = [config mutableCopy];
    NSString *authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    mutableConfig[@"authority"] = authority;

    // Now expire access token
    [self expireAccessToken:mutableConfig];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // Now do access token refresh
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];

    [self assertScopesReturned:@[@"https://graph.microsoft.com/user.read",
                                 @"https://graph.microsoft.com/.default",
                                 @"openid", @"profile"]];

    [self closeResultView];
}

// TODO: server side bug!
- (void)testInteractiveAADLogin_withConvergedApp_andMicrosoftGraphScopes_andTenantedEndpoint_andForceLogin
{
    NSString *authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    NSDictionary *params = @{
                             @"ui_behavior" : @"force",
                             @"validate_authority" : @YES,
                             @"authority": authority,
                             @"scopes": @"00000003-0000-0000-c000-000000000000/user.read",
                             @"redirect_uri": @"msal3c62ac97-29eb-4aed-a3c8-add0298508da://auth",
                             @"client_id": @"3c62ac97-29eb-4aed-a3c8-add0298508da"
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];

    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept"];
    [self assertScopesReturned:@[@"00000003-0000-0000-c000-000000000000/user.read",
                                 @"openid", @"profile"]];

    [self assertAccessTokenNotNil];

    NSDictionary *result = [self resultDictionary];
    NSString *resultTenantId = result[@"tenantId"];
    XCTAssertEqualObjects(resultTenantId, self.primaryAccount.targetTenantId);

    [self closeResultView];
}

// Non-converged app tests
- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andCommonEndpoint_andForceLogin
{
    NSDictionary *params = @{
                             @"ui_behavior" : @"force",
                             @"validate_authority" : @YES,
                             @"authority": @"https://login.microsoftonline.com/common",
                             @"scopes": @"https://graph.microsoft.com/.default",
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];

    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept"];
    [self assertErrorCode:@"MSALErrorInvalidRequest"];
    [self assertErrorDescription:@"Please use the /organizations or tenant-specific endpoint."];
    [self closeResultView];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin
{
    NSDictionary *params = @{
                             @"ui_behavior" : @"force",
                             @"validate_authority" : @YES,
                             @"authority": @"https://login.microsoftonline.com/organizations",
                             @"scopes": @"https://graph.microsoft.com/.default",
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];

    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept"];

    [self assertScopesReturned:@[@"https://graph.microsoft.com/user.read",
                                 @"https://graph.microsoft.com/.default",
                                 @"openid", @"profile"]];

    [self assertAccessTokenNotNil];

    NSDictionary *resultDictionary = [self resultDictionary];
    NSString *homeAccountId = resultDictionary[@"user"][@"home_account_id"];
    XCTAssertNotNil(homeAccountId);

    [self closeResultView];

    // Now do acquiretoken silent request
    NSDictionary *silentParams = @{
                                   @"home_account_identifier": homeAccountId,
                                   @"scopes": @"https://graph.microsoft.com/.default"
                                   };

    config = [self.testConfiguration configWithAdditionalConfiguration:silentParams];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    NSMutableDictionary *mutableConfig = [config mutableCopy];
    NSString *authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    mutableConfig[@"authority"] = authority;

    // Now expire access token
    [self expireAccessToken:mutableConfig];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // Now do access token refresh
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];

    [self assertScopesReturned:@[@"https://graph.microsoft.com/user.read",
                                 @"https://graph.microsoft.com/.default",
                                 @"openid", @"profile"]];

    [self closeResultView];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_andMicrosoftGraphScopes_andTenantedEndpoint_andForceLogin
{
    NSString *authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    NSDictionary *params = @{
                             @"ui_behavior" : @"force",
                             @"validate_authority" : @YES,
                             @"authority": authority,
                             @"scopes": @"user.read tasks.read",
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];

    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept"];

    [self assertScopesReturned:@[@"user.read",
                                 @"tasks.read"]];

    [self assertAccessTokenNotNil];

    NSDictionary *result = [self resultDictionary];
    NSString *resultTenantId = result[@"tenantId"];
    XCTAssertEqualObjects(resultTenantId, self.primaryAccount.targetTenantId);

    NSDictionary *resultDictionary = [self resultDictionary];
    NSString *homeAccountId = resultDictionary[@"user"][@"home_account_id"];
    XCTAssertNotNil(homeAccountId);

    [self closeResultView];

    // Now do acquiretoken silent request
    NSDictionary *silentParams = @{
                                   @"home_account_identifier": homeAccountId,
                                   @"scopes": @"tasks.read"
                                   };

    config = [self.testConfiguration configWithAdditionalConfiguration:silentParams];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    NSMutableDictionary *mutableConfig = [config mutableCopy];
    mutableConfig[@"authority"] = authority;

    // Now expire access token
    [self expireAccessToken:mutableConfig];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // Now do access token refresh
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];
}

#pragma mark - Prompt behavior

- (void)testInteractiveAADLogin_withNonConvergedApp_andMicrosoftGraphScopes_andTenantedEndpoint_andSelectAccount
{
    // Sign in first time to ensure account will be there
    NSString *authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    NSDictionary *params = @{
                             @"ui_behavior" : @"force",
                             @"validate_authority" : @YES,
                             @"authority": authority,
                             @"scopes": @"user.read"
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];
    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept"];
    [self assertScopesReturned:@[@"user.read"]];

    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Now call acquire token with select account
    NSMutableDictionary *mutableConfig = [config mutableCopy];
    mutableConfig[@"ui_behavior"] = @"select_account";
    [self acquireToken:mutableConfig];

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
    NSString *authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    NSDictionary *params = @{
                             @"ui_behavior" : @"force",
                             @"validate_authority" : @YES,
                             @"authority": authority,
                             @"scopes": @"user.read"
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];
    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept"];
    [self assertScopesReturned:@[@"user.read"]];

    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Now call acquire token with force consent
    NSMutableDictionary *mutableConfig = [config mutableCopy];
    mutableConfig[@"ui_behavior"] = @"consent";
    [self acquireToken:mutableConfig];

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
    NSDictionary *params = @{
                             @"ui_behavior" : @"force",
                             @"validate_authority" : @YES,
                             @"authority": @"https://login.microsoftonline.com/organizations",
                             @"scopes": @"https://graph.windows.net/.default",
                             @"login_hint": self.primaryAccount.account
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];

    [self acquireToken:config];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept"];

    [self assertScopesReturned:@[@"https://graph.windows.net/user.read",
                                 @"https://graph.windows.net/.default"]];

    [self assertAccessTokenNotNil];
}

// TODO: server side bug!
- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andForceLogin_andLoginHint_andResourceGUID
{
    NSDictionary *params = @{
                             @"ui_behavior" : @"force",
                             @"validate_authority" : @YES,
                             @"authority": @"https://login.microsoftonline.com/organizations",
                             @"scopes": @"00000002-0000-0000-c000-000000000000/.default",
                             @"login_hint": self.primaryAccount.account
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];

    [self acquireToken:config];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept"];

    [self assertScopesReturned:@[@"00000002-0000-0000-c000-000000000000/user.read",
                                 @"00000002-0000-0000-c000-000000000000/.default"]];

    [self assertAccessTokenNotNil];
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

#pragma mark - SafariViewController/Session

// TODO

@end
