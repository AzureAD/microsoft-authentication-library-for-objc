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

#import "MSALADFSBaseUITest.h"
#import "NSString+MSIDAutomationUtils.h"

@interface MSALADFSv4FederatedTests : MSALADFSBaseUITest

@property (nonatomic) NSString *testEnvironment;

@end

@implementation MSALADFSv4FederatedTests

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
    accountConfigurationRequest.accountType = MSIDTestAccountTypeFederated;
    accountConfigurationRequest.federationProviderType = MSIDTestAccountFederationProviderTypeADFSV4;
    
    [self loadTestAccount:accountConfigurationRequest];
}

#pragma mark - Tests

#ifdef FEDERATION_TESTS_ENABLED
- (void)testInteractiveADFSv4Login_withPromptAlways_noLoginHint_andSystemWebView
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"organizations"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"ms_graph"];
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:self.class.confProvider.oidcScopes];
    request.promptBehavior = @"force";

    // 1. Do interactive login
    NSString *homeAccountId = [self runSharedADFSInteractiveLoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2. Now do silent login #296725
    request.homeAccountIdentifier = homeAccountId;
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.targetTenantId];
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveADFSv4Login_withPromptAlways_withLoginHint_andSafariViewController
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"organizations"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"aad_graph_static"];
    request.expectedResultScopes = request.requestScopes;
    request.promptBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.upn;
    request.webViewType = MSIDWebviewTypeSafariViewController;

    // Do interactive login
    NSString *homeAccountId = [self runSharedADFSInteractiveLoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);
}

- (void)testInteractiveADFSv4Login_withPromptAlways_withLoginHint_andEmbeddedWebView
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"common"];
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"ms_graph_prefixed"];
    request.expectedResultScopes = request.requestScopes;
    request.promptBehavior = @"force";
    request.testAccount = self.primaryAccount;
    request.loginHint = self.primaryAccount.upn;
    request.webViewType = MSIDWebviewTypeWKWebView;

    // Do interactive login
    NSString *homeAccountId = [self runSharedADFSInteractiveLoginWithRequest:request];
    XCTAssertNotNil(homeAccountId);
}
#endif // FEDERATION_TESTS_ENABLED

@end
