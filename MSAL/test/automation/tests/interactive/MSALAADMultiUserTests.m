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

@interface MSALAADMultiUserTests : MSALBaseUITest

@end

@implementation MSALAADMultiUserTests

#pragma mark - Setup

- (void)setUp
{
    [super setUp];
    
    // Load multiple accounts conf
    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    configurationRequest.appVersion = MSIDAppVersionV1;
    configurationRequest.needsMultipleUsers = YES;
    configurationRequest.appName = @"IDLABSAPP";
    [self loadTestConfiguration:configurationRequest];

    XCTAssertTrue([self.testConfiguration.accounts count] >= 2);
}

#pragma mark - Different accounts

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andMultipleAccounts
{
    // Load multiple accounts conf
    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    configurationRequest.appVersion = MSIDAppVersionV1;
    configurationRequest.needsMultipleUsers = YES;
    configurationRequest.appName = @"IDLABSAPP";
    [self loadTestConfiguration:configurationRequest];

    XCTAssertTrue([self.testConfiguration.accounts count] >= 2);

    MSIDTestAccount *firstAccount = self.testConfiguration.accounts[0];
    MSIDTestAccount *secondaryAccount = self.testConfiguration.accounts[1];

    // Sign in with first account
    self.primaryAccount = firstAccount;

    NSDictionary *params = @{
                             @"ui_behavior" : @"force",
                             @"validate_authority" : @YES,
                             @"authority": @"https://login.microsoftonline.com/organizations",
                             @"scopes": @"https://graph.windows.net/.default"
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];
    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept"];
    [self assertScopesReturned:@[@"https://graph.windows.net/.default"]];
    [self closeResultView];

    // Sign in with second account
    self.primaryAccount = secondaryAccount;
    [self loadPasswordForAccount:self.primaryAccount];

    NSMutableDictionary *mutableConfig = [config mutableCopy];
    mutableConfig[@"login_hint"] = self.primaryAccount.account;
    [self acquireToken:mutableConfig];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept"];
    [self assertScopesReturned:@[@"https://graph.windows.net/.default"]];
    [self closeResultView];

    // Now do silent token refresh for first account
    self.primaryAccount = firstAccount;
    NSDictionary *silentParams = @{
                                   @"home_account_identifier": self.primaryAccount.homeAccountId,
                                   @"scopes": @"user.read"
                                   };

    config = [self.testConfiguration configWithAdditionalConfiguration:silentParams];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self assertScopesReturned:@[@"user.read"]];
    NSString *resultAccount = [self resultDictionary][@"user"][@"home_account_id"];
    XCTAssertEqualObjects(resultAccount, self.primaryAccount.homeAccountId);
    [self closeResultView];

    mutableConfig = [config mutableCopy];
    NSString *authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    mutableConfig[@"authority"] = authority;

    // Now expire access token for the first account
    [self expireAccessToken:mutableConfig];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // Now do access token refresh for the first account
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self assertScopesReturned:@[@"user.read"]];
    resultAccount = [self resultDictionary][@"user"][@"home_account_id"];
    XCTAssertEqualObjects(resultAccount, self.primaryAccount.homeAccountId);
    [self closeResultView];

    // Do silent for user 2
    silentParams = @{
                     @"home_account_identifier": secondaryAccount.homeAccountId,
                     @"scopes": @"https://graph.windows.net/.default"
                     };

    config = [self.testConfiguration configWithAdditionalConfiguration:silentParams];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self assertScopesReturned:@[@"https://graph.windows.net/.default"]];
    resultAccount = [self resultDictionary][@"user"][@"home_account_id"];
    XCTAssertEqualObjects(resultAccount, secondaryAccount.homeAccountId);
    [self closeResultView];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_whenWrongAccountReturned
{
    // Load multiple accounts conf
    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    configurationRequest.appVersion = MSIDAppVersionV1;
    configurationRequest.needsMultipleUsers = YES;
    configurationRequest.appName = @"IDLABSAPP";
    [self loadTestConfiguration:configurationRequest];

    XCTAssertTrue([self.testConfiguration.accounts count] >= 2);

    // Sign in first time to ensure account will be there
    NSString *authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    NSDictionary *params = @{
                             @"ui_behavior" : @"force",
                             @"validate_authority" : @YES,
                             @"authority": authority,
                             @"scopes": @"https://graph.windows.net/.default"
                             };

    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];
    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept"];
    [self assertScopesReturned:@[@"https://graph.windows.net/.default"]];

    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Now call acquire token with select account
    NSMutableDictionary *mutableConfig = [config mutableCopy];
    mutableConfig[@"ui_behavior"] = @"force";
    mutableConfig[@"home_account_identifier"] = self.primaryAccount.homeAccountId;
    [self acquireToken:mutableConfig];

    XCUIElement *signIn = self.testApp.staticTexts[@"Sign in with another account"];
    [self waitForElement:signIn];
    [signIn msidTap];

    // Select to enter different account
    XCUIElement *pickAccount = self.testApp.staticTexts[@"Pick an account"];
    [self waitForElement:pickAccount];

    NSPredicate *accountPredicate = [NSPredicate predicateWithFormat:@"label CONTAINS[c] %@", @"Use another account, Use another account"];
    XCUIElement *element = [[self.testApp.buttons containingPredicate:accountPredicate] elementBoundByIndex:0];
    XCTAssertNotNil(element);

    [element msidTap];

    self.primaryAccount = self.testConfiguration.accounts[1];
    [self loadPasswordForAccount:self.primaryAccount];
    [self aadEnterEmail];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept"];
    [self assertErrorCode:@"MSALErrorMismatchedUser"];
}

@end
