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
#import "MSALBaseAADUITest.h"
#import "NSOrderedSet+MSIDExtensions.h"

@interface MSALCIAMTest : MSALBaseAADUITest

@property (nonatomic) NSString *testEnvironment;

@end

@implementation MSALCIAMTest

- (void)setUp
{
    [super setUp];
    
    self.testEnvironment = self.class.confProvider.wwEnvironment;
    
    MSIDTestAutomationAccountConfigurationRequest *accountConfigurationRequest = [MSIDTestAutomationAccountConfigurationRequest new];
    accountConfigurationRequest.environmentType = self.testEnvironment;
    accountConfigurationRequest.federationProviderType = MSIDTestAccountFederationProviderTypeCIAM;
    accountConfigurationRequest.additionalQueryParameters = @{@"signInAudience": @"azureadmyorg",@"PublicClient": @"No"};
    
    [self loadTestAccount:accountConfigurationRequest];
    
    MSIDTestAutomationAppConfigurationRequest *appConfigurationRequest = [MSIDTestAutomationAppConfigurationRequest new];
    appConfigurationRequest.testAppAudience = MSIDTestAppAudienceMyOrg;
    appConfigurationRequest.testAppEnvironment = self.testEnvironment;
    appConfigurationRequest.appId = self.primaryAccount.associatedAppID;;
    
    [self loadTestApp:appConfigurationRequest];
}

#pragma mark - Tests

-
    (void)testInteractiveAndSilentCIAMLogin_withPromptAlways_noLoginHint_andSystemWebView
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.requestScopes = self.testApplication.defaultScopes.msidToString;
    request.promptBehavior = @"force";
    request.redirectUri = @"msauth.com.microsoft.msalautomationapp://auth";
    
    // 1. Do interactive login
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);
    
    // 2. Now do silent login
    request.homeAccountIdentifier = homeAccountId;
    request.cacheAuthority = [self.class.confProvider defaultAuthorityForIdentifier:self.testEnvironment tenantId:self.primaryAccount.targetTenantId];
    [self runSharedSilentAADLoginWithTestRequest:request];
}

@end
