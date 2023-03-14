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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  


#import <XCTest/XCTest.h>
#import "MSIDTestAutomationAppConfigurationRequest.h"
#import "MSIDTestAutomationAccountConfigurationRequest.h"
#import "MSALADFSBaseUITest.h"
#import "NSString+MSIDAutomationUtils.h"

@interface MSALCIAMTest : MSALADFSBaseUITest

@property (nonatomic) NSString *testEnvironment;

@end

//@implementation MSALCIAMTest
//
//- (void)setUp
//{
//    [super setUp];
//
//    self.testEnvironment = self.class.confProvider.wwEnvironment;
//
//    MSIDTestAutomationAccountConfigurationRequest *accountConfigurationRequest = [MSIDTestAutomationAccountConfigurationRequest new];
////    accountConfigurationRequest.environmentType = self.testEnvironment;
////    accountConfigurationRequest.accountType = MSIDTestAccountTypeFederated;
//    accountConfigurationRequest.federationProviderType = MSIDTestAccountFederationProviderTypeCIAM;
//    accountConfigurationRequest.accountAudience = MSIDTestAccountAudienceMyOrg;
//    accountConfigurationRequest.publicClient = MSIDTestAccountPublicClientTypeNone;
//
//    [self loadTestAccount:accountConfigurationRequest];
//
//    MSIDTestAutomationAppConfigurationRequest *appConfigurationRequest = [MSIDTestAutomationAppConfigurationRequest new];
//    appConfigurationRequest.appId = @"b8e9d222-c4ee-414c-ac29-b0eff1f32400";
////    appConfigurationRequest.testAppEnvironment = self.testEnvironment;
//
//    [self loadTestApp:appConfigurationRequest];
//}
//
//#pragma mark - Tests
//
//- (void)testInteractiveLogin
//{
//
////    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
////    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"organizations"];
////    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"aad_graph_static"];
////    request.expectedResultScopes = request.requestScopes;
////    request.promptBehavior = @"force";
////    request.testAccount = self.primaryAccount;
////
////    // 1. Do interactive login
////    NSString *homeAccountId = [self runSharedADFSInteractiveLoginWithRequest:request];
////    XCTAssertNotNil(homeAccountId);
//
//    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
////    request.requestScopes = @"https://graph.windows.net/.default";
//    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"ms_graph"];
//    request.expectedResultScopes = request.requestScopes;
//    request.promptBehavior = @"force";
//    request.testAccount = self.primaryAccount;
//    request.configurationAuthority = @"https://login.microsoftonline.com/organizations";
////    request.webViewType = MSIDWebviewTypeDefault;
//
//    NSDictionary *config = [self configWithTestRequest:request];
//    [self acquireToken:config];
//
//    [self acceptAuthSessionDialogIfNecessary:request];
//
//    if (!request.loginHint)
//    {
//        [self aadEnterEmail:self.testApp];
//    }
//
//    sleep(1);
//    [self aadEnterPassword:self.testApp];
//    [self acceptMSSTSConsentIfNecessary:@"Accept" embeddedWebView:request.usesEmbeddedWebView];
//
//    if (!request.usesEmbeddedWebView)
//    {
//        [self acceptSpeedBump];
//    }
//
//    NSString *homeAccountId = [self runSharedResultAssertionWithTestRequest:request];
//    XCTAssertNotNil(homeAccountId);
//}
//
//- (void)testSilentLogin
//{
//    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
//    request.testAccount = self.primaryAccount;
//
//    NSDictionary *config = [self configWithTestRequest:request];
//    [self acquireTokenSilent:config];
//}
//
//- (void)tearDown {
//    // Put teardown code here. This method is called after the invocation of each test method in the class.
//}
//
//@end


@implementation MSALCIAMTest

- (void)setUp

{
    [super setUp];
    
    self.testEnvironment = self.class.confProvider.wwEnvironment;
    
    MSIDTestAutomationAccountConfigurationRequest *accountConfigurationRequest = [MSIDTestAutomationAccountConfigurationRequest new];
    
    accountConfigurationRequest.environmentType = self.testEnvironment;
    accountConfigurationRequest.federationProviderType = @"ciam";
    accountConfigurationRequest.additionalQueryParameters = @{@"signInAudience": @"azureadmyorg",@"PublicClient": @"No"};
    
    [self loadTestAccount:accountConfigurationRequest];
    
    MSIDTestAutomationAppConfigurationRequest *appConfigurationRequest = [MSIDTestAutomationAppConfigurationRequest new];
    appConfigurationRequest.testAppAudience = MSIDTestAppAudienceMyOrg;
    appConfigurationRequest.testAppEnvironment = self.testEnvironment;
    appConfigurationRequest.appId = self.primaryAccount.associatedAppID;
    
    [self loadTestApp:appConfigurationRequest];
    
}

#pragma mark - Tests
- (void)testInteractiveCIAMLogin_withPromptAlways_noLoginHint_andSystemWebView
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    
    request.configurationAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:@"organizations"];
    
    request.requestScopes = [self.class.confProvider scopesForEnvironment:self.testEnvironment type:@"ms_graph"];
    
    request.expectedResultScopes = [NSString msidCombinedScopes:request.requestScopes withScopes:self.class.confProvider.oidcScopes];
    
    request.promptBehavior = @"force";
    
    request.redirectUri = @"msauth.com.microsoft.MSALAutomationApp://auth";
    
    // 1. Do interactive login
    NSString *homeAccountId = [self runSharedADFSInteractiveLoginWithRequest:request];
    
    XCTAssertNotNil(homeAccountId);
    
    // 2. Now do silent login #296725
    request.homeAccountIdentifier = homeAccountId;
    
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.targetTenantId];
    
    [self runSharedSilentAADLoginWithTestRequest:request];
    
}

@end
