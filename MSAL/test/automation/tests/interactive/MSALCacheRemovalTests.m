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
#import "NSString+MSIDAutomationUtils.h"

@interface MSALCacheRemovalTests : MSALBaseAADUITest

@property (nonatomic) NSString *testEnvironment;

@end

@implementation MSALCacheRemovalTests

- (void)setUp
{
    [super setUp];
    
    self.testEnvironment = self.class.confProvider.wwEnvironment;
    
    MSIDTestAutomationAppConfigurationRequest *appConfigurationRequest = [MSIDTestAutomationAppConfigurationRequest new];
    appConfigurationRequest.testAppAudience = MSIDTestAppAudienceMultipleOrgs;
    appConfigurationRequest.testAppEnvironment = self.testEnvironment;
    
    [self loadTestApp:appConfigurationRequest];
    
    MSIDTestAutomationAccountConfigurationRequest *accountConfigurationRequest = [MSIDTestAutomationAccountConfigurationRequest new];
    accountConfigurationRequest.environmentType = self.testEnvironment;
    
    MSIDTestAutomationAccountConfigurationRequest *secondAccountConfigurationRequest = [MSIDTestAutomationAccountConfigurationRequest new];
    secondAccountConfigurationRequest.environmentType = self.testEnvironment;
    secondAccountConfigurationRequest.protectionPolicyType = MSIDTestAccountProtectionPolicyTypeMAMCASPO;
    
    [self loadTestAccounts:@[accountConfigurationRequest, secondAccountConfigurationRequest]];
}

- (void)testRemoveAADAccount_whenOnlyOneAccountInCache_andConvergedApp
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.promptBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.upn;

    // 1. Run interactive login
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2. Remove account
    request.homeAccountIdentifier = homeAccountId;
    NSDictionary *config = [self configWithTestRequest:request];
    [self signout:config];
    XCTAssertNotNil([self automationSuccessResult:self.testApp]);
    [self closeResultPipeline:self.testApp];

    // 3. Try silent and expect failure
    [self acquireTokenSilent:config];
    [self assertErrorCode:MSALErrorInteractionRequired];
}

- (void)testRemoveAADAccount_whenMultipleAccountsInCache_andConvergedApp
{
    MSIDAutomationTestRequest *firstRequest = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    firstRequest.promptBehavior = @"force";
    firstRequest.testAccount = self.primaryAccount;
    firstRequest.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"aad_graph_static"];
    firstRequest.expectedResultScopes = firstRequest.requestScopes;
    firstRequest.loginHint = self.primaryAccount.upn;
    firstRequest.testAccount = self.primaryAccount;
    firstRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"common"];
    firstRequest.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.targetTenantId];

    // 1. Run interactive login for the first account
    NSString *firstHomeAccountId = [self runSharedAADLoginWithTestRequest:firstRequest];
    XCTAssertNotNil(firstHomeAccountId);

    self.primaryAccount = self.testAccounts[1];

    MSIDAutomationTestRequest *secondRequest = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    secondRequest.promptBehavior = @"force";
    secondRequest.testAccount = self.primaryAccount;
    secondRequest.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"aad_graph_static"];
    secondRequest.expectedResultScopes = secondRequest.requestScopes;
    secondRequest.loginHint = self.primaryAccount.upn;
    secondRequest.testAccount = self.primaryAccount;
    secondRequest.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"common"];
    secondRequest.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.targetTenantId];

    // 2. Run interactive login for the second account
    NSString *secondHomeAccountId = [self runSharedAADLoginWithTestRequest:secondRequest];
    XCTAssertNotNil(secondHomeAccountId);

    // 3. Remove first account
    self.primaryAccount = self.testAccounts[0];
    firstRequest.homeAccountIdentifier = firstHomeAccountId;
    NSDictionary *config = [self configWithTestRequest:firstRequest];
    [self signout:config];
    XCTAssertNotNil([self automationSuccessResult:self.testApp]);
    [self closeResultPipeline:self.testApp];

    // 4. Try silent and expect failure for the first account
    [self acquireTokenSilent:config];
    [self assertErrorCode:MSALErrorInteractionRequired];
    [self closeResultPipeline:self.testApp];

    // 5. Expect silent to still work for the second account
    self.primaryAccount = self.testAccounts[1];
    secondRequest.homeAccountIdentifier = secondHomeAccountId;
    [self runSharedSilentAADLoginWithTestRequest:secondRequest];
}

@end
