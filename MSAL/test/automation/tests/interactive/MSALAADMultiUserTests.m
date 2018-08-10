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

@interface MSALAADMultiUserTests : MSALBaseAADUITest

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

    // 1. Sign in with first account
    self.primaryAccount = firstAccount;

    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.scopes = @"https://graph.windows.net/.default";
    request.expectedResultScopes = @[@"https://graph.windows.net/.default"];
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;

    NSString *firstHomeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(firstHomeAccountId);

    // 2. Sign in with second account
    self.primaryAccount = secondaryAccount;
    [self loadPasswordForAccount:self.primaryAccount];

    request.loginHint = self.primaryAccount.account;
    request.testAccount = self.primaryAccount;

    NSString *secondHomeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(secondHomeAccountId);

    // 3. Now do silent token refresh for first account
    self.primaryAccount = firstAccount;

    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    request.accountIdentifier = firstHomeAccountId;
    request.testAccount = self.primaryAccount;

    [self runSharedSilentAADLoginWithTestRequest:request];

    // 4. Do silent for user 2 now
    self.primaryAccount = secondaryAccount;

    request.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    request.accountIdentifier = secondHomeAccountId;
    request.testAccount = self.primaryAccount;

    [self runSharedSilentAADLoginWithTestRequest:request];
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

    // 1. Sign in first time to ensure account will be there
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    request.scopes = @"https://graph.windows.net/.default";
    request.expectedResultScopes = @[@"https://graph.windows.net/.default"];
    request.uiBehavior = @"force";
    request.testAccount = self.primaryAccount;

    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2. Now call acquire token with select account
    request.uiBehavior = @"select_account";
    request.accountIdentifier = homeAccountId;
    NSDictionary *config = [self configWithTestRequest:request];

    [self acquireToken:config];
    [self allowSFAuthenticationSessionAlert];

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
    [self acceptMSSTSConsentIfNecessary:@"Accept" embeddedWebView:NO];
    [self assertErrorCode:@"MSALErrorMismatchedUser"];
}

@end
