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
#import "NSString+MSIDAutomationUtils.h"

@interface MSALAADMultiUserTests : MSALBaseAADUITest

@property (nonatomic) NSString *testEnvironment;

@end

@implementation MSALAADMultiUserTests

#pragma mark - Setup

- (void)setUp
{
    [super setUp];
    
    self.testEnvironment = self.class.confProvider.wwEnvironment;
    
    // Load multiple accounts conf
    MSIDAutomationConfigurationRequest *configurationRequest = [MSIDAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    configurationRequest.needsMultipleUsers = YES;
    // TODO: no other app returns multiple accounts
    configurationRequest.appName = @"IDLABSAPP";
    [self loadTestConfiguration:configurationRequest];

    XCTAssertTrue([self.testConfiguration.accounts count] >= 2);
}

#pragma mark - Different accounts

- (void)testInteractiveAADLogin_withNonConvergedApp_andDefaultScopes_andOrganizationsEndpoint_andMultipleAccounts
{
    MSIDTestAccount *firstAccount = self.testConfiguration.accounts[0];
    MSIDTestAccount *secondaryAccount = self.testConfiguration.accounts[1];

    // 1. Sign in with first account
    self.primaryAccount = firstAccount;

    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.promptBehavior = @"force";
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"aad_graph_static"];
    request.expectedResultScopes = request.requestScopes;
    request.testAccount = self.primaryAccount;
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"organizations"];

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

    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.targetTenantId];
    request.homeAccountIdentifier = firstHomeAccountId;
    request.testAccount = self.primaryAccount;

    [self runSharedSilentAADLoginWithTestRequest:request];

    // 4. Do silent for user 2 now
    self.primaryAccount = secondaryAccount;

    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.targetTenantId];
    request.homeAccountIdentifier = secondHomeAccountId;
    request.testAccount = self.primaryAccount;

    [self runSharedSilentAADLoginWithTestRequest:request];

    // 5. Make sure there're 2 accounts in cache
    NSDictionary *configuration = [self configWithTestRequest:request];
    [self readAccounts:configuration];

    MSIDAutomationAccountsResult *result = [self automationAccountsResult];
    XCTAssertEqual([result.accounts count], 2);
    [self closeResultView];
}

- (void)testInteractiveAADLogin_withNonConvergedApp_whenWrongAccountReturned
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultNonConvergedAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.targetTenantId];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"aad_graph_static"];
    request.expectedResultScopes = request.requestScopes;
    request.promptBehavior = @"force";
    request.webViewType = MSIDWebviewTypeWKWebView;

    // 1. Sign in first time to ensure account will be there
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    [self.testApp terminate];
    [self.testApp launch];

    // 2. Now call acquire token again with home account ID
    request.promptBehavior = @"select_account";
    request.homeAccountIdentifier = homeAccountId;
    NSDictionary *config = [self configWithTestRequest:request];

    [self acquireToken:config];
    
    [self selectAccountWithTitle:@"Use another account"];

    self.primaryAccount = self.testConfiguration.accounts[1];
    [self loadPasswordForAccount:self.primaryAccount];
    [self aadEnterEmail];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept" embeddedWebView:NO];
    [self assertErrorCode:MSALErrorInternal];
    [self assertInternalErrorCode:MSALInternalErrorMismatchedUser];
}

@end
