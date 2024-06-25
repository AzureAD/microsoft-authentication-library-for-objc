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

@interface MSALCIAMAuthorityTests : MSALBaseAADUITest

@property (nonatomic) NSString *testEnvironment;

@end

@implementation MSALCIAMAuthorityTests

- (void)setUp
{
    [super setUp];
    
    self.testEnvironment = self.class.confProvider.wwEnvironment;
    
    MSIDTestAutomationAccountConfigurationRequest *accountConfigurationRequest = [MSIDTestAutomationAccountConfigurationRequest new];
<<<<<<< HEAD
    accountConfigurationRequest.federationProviderType = MSIDTestAccountFederationProviderTypeCIAMCUD;
    accountConfigurationRequest.additionalQueryParameters = @{@"signInAudience": @"azureadmyorg"};
=======
    accountConfigurationRequest.federationProviderType = MSIDTestAccountFederationProviderTypeCIAM;
>>>>>>> 68b97f350c58274aabdfd24eddb3b35bca524124
    
    [self loadTestAccount:accountConfigurationRequest];
    
    MSIDTestAutomationAppConfigurationRequest *appConfigurationRequest = [MSIDTestAutomationAppConfigurationRequest new];
    appConfigurationRequest.testAppAudience = MSIDTestAppAudienceMyOrg;
    appConfigurationRequest.testAppEnvironment = self.testEnvironment;
    appConfigurationRequest.appId = self.primaryAccount.associatedAppID;
    
    [self loadTestApp:appConfigurationRequest];
}

#pragma mark - Tests

-
    (void)testInteractiveAndSilentCIAMLogin_withPromptAlways_noLoginHint_andSystemWebView
{
    MSIDAutomationTestRequest *request = [self.class.confProvider defaultAppRequest:self.testEnvironment targetTenantId:self.primaryAccount.targetTenantId];
    request.configurationAuthority = @"https://msidlabciam6.ciamlogin.com";
    request.expectedResultAuthority = @"https://msidlabciam6.ciamlogin.com/fe362aec-5d43-45d1-b730-9755e60dc3b9";
    request.cacheAuthority = @"https://msidlabciam6.ciamlogin.com/fe362aec-5d43-45d1-b730-9755e60dc3b9";
    request.acquireTokenAuthority = request.cacheAuthority;
    request.requestScopes = self.testApplication.defaultScopes.msidToString;
    request.promptBehavior = @"force";
    request.redirectUri = @"msauth.com.microsoft.msalautomationapp://auth";
   
    // 1. Do interactive login
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);
    
    // 2. Now do silent login
    request.testAccount = self.primaryAccount;
    request.homeAccountIdentifier = homeAccountId;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

@end
