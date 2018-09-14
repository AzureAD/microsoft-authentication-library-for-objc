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
#import "XCTestCase+TextFieldTap.h"

@interface MSALGuestUserTests : MSALADFSBaseUITest

@end

@implementation MSALGuestUserTests

- (void)setUp
{
    [super setUp];

    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    configurationRequest.accountFeatures = @[MSIDTestAccountFeatureGuestUser];
    [self loadTestConfiguration:configurationRequest];
}

// #347620
- (void)testInteractiveAndSilentAADLogin_withNonConvergedApp_withPromptAlways_noLoginHint_SystemWebView_signinIntoGuestTenantFirst
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.scopes = @"user.read";
    request.expectedResultScopes = @[@"user.read", @"openid", @"profile"];
    request.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    // 1. Run interactive in the guest tenant
    NSString *homeAccountId = [self runSharedADFSInteractiveLoginWithRequest:request closeResultView:NO];
    NSString *resultTenantId = [self resultDictionary][@"tenantId"];
    XCTAssertEqualObjects(resultTenantId, self.primaryAccount.targetTenantId);
    XCTAssertNotNil(homeAccountId);
    // TODO: lab should return homeObjectId
    XCTAssertTrue([homeAccountId hasSuffix:self.primaryAccount.homeTenantId]);
    [self closeResultView];

    // 2. Run silent for the guest tenant
    request.accountIdentifier = homeAccountId;
    request.cacheAuthority = request.authority;
    request.testAccount = [self.primaryAccount copy];
    // TODO: lab doesn't return correct home object ID at the moment, need to follow up on that!
    request.testAccount.homeObjectId = [[homeAccountId componentsSeparatedByString:@"."] firstObject];

    [self runSharedSilentAADLoginWithTestRequest:request guestTenantScenario:YES];

    // 3. Run silent for the home tenant
    request.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.homeTenantId];
    request.testAccount.targetTenantId = request.testAccount.homeTenantId;
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testInteractiveAndSilentAADLogin_withNonConvergedApp_withPromptAlways_noLoginHint_EmbeddedWebView_signinIntoHomeTenantFirst
{
    MSALTestRequest *homeRequest = [MSALTestRequest nonConvergedAppRequest];
    homeRequest.uiBehavior = @"force";
    homeRequest.scopes = @"user.read";
    homeRequest.expectedResultScopes = @[@"user.read", @"openid", @"profile"];
    homeRequest.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.homeTenantId];

    // 1. Run interactive in the home tenant
    NSString *homeAccountId = [self runSharedADFSInteractiveLoginWithRequest:homeRequest closeResultView:NO];
    NSString *resultTenantId = [self resultDictionary][@"tenantId"];
    XCTAssertEqualObjects(resultTenantId, self.primaryAccount.homeTenantId);
    XCTAssertNotNil(homeAccountId);
    // TODO: lab should return homeObjectId
    XCTAssertTrue([homeAccountId hasSuffix:self.primaryAccount.homeTenantId]);
    [self closeResultView];

    // 2. Run silent for the home tenant
    homeRequest.accountIdentifier = homeAccountId;
    homeRequest.cacheAuthority = homeRequest.authority;
    homeRequest.testAccount = [self.primaryAccount copy];
    homeRequest.testAccount.homeObjectId = [[homeAccountId componentsSeparatedByString:@"."] firstObject];
    homeRequest.testAccount.targetTenantId = self.primaryAccount.homeTenantId;
    [self runSharedSilentAADLoginWithTestRequest:homeRequest];

    // 3. Run silent for the guest tenant
    MSALTestRequest *guestRequest = [MSALTestRequest nonConvergedAppRequest];
    guestRequest.uiBehavior = @"force";
    guestRequest.scopes = @"user.read";
    guestRequest.expectedResultScopes = @[@"user.read", @"openid", @"profile"];
    guestRequest.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    guestRequest.testAccount = [self.primaryAccount copy];
    guestRequest.accountIdentifier = homeAccountId;
    guestRequest.testAccount.homeObjectId = [[homeAccountId componentsSeparatedByString:@"."] firstObject];
    [self runSharedSilentAADLoginWithTestRequest:guestRequest guestTenantScenario:YES];
}

// Test #347622
- (void)testInteractiveAndSilentAADLogin_withConvergedApp_withPromptAlways_noLoginHint_SystemWebView_andGuestUserInHomeAndGuestTenant
{
    MSALTestRequest *guestRequest = [MSALTestRequest convergedAppRequest];
    guestRequest.uiBehavior = @"force";
    guestRequest.scopes = @"user.read";
    guestRequest.expectedResultScopes = @[@"user.read", @"openid", @"profile"];
    guestRequest.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    // 1. Run interactive in the guest tenant
    NSString *homeAccountId = [self runSharedADFSInteractiveLoginWithRequest:guestRequest closeResultView:NO];
    NSString *resultTenantId = [self resultDictionary][@"tenantId"];
    XCTAssertEqualObjects(resultTenantId, self.primaryAccount.targetTenantId);
    XCTAssertNotNil(homeAccountId);
    // TODO: lab should return homeObjectId
    XCTAssertTrue([homeAccountId hasSuffix:self.primaryAccount.homeTenantId]);
    [self closeResultView];

    // 2. Run interactive in the home tenant
    MSALTestRequest *homeRequest = [MSALTestRequest convergedAppRequest];
    homeRequest.uiBehavior = @"force";
    homeRequest.scopes = @"user.read";
    homeRequest.expectedResultScopes = @[@"user.read", @"openid", @"profile"];
    homeRequest.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.homeTenantId];
    homeRequest.testAccount = [self.primaryAccount copy];
    // TODO: lab doesn't return correct home object ID at the moment, need to follow up on that!
    homeRequest.testAccount.homeObjectId = [[homeAccountId componentsSeparatedByString:@"."] firstObject];
    homeRequest.testAccount.targetTenantId = self.primaryAccount.homeTenantId;
    [self runSharedADFSInteractiveLoginWithRequest:homeRequest closeResultView:YES];

    // 3. Run silent for the guest tenant
    guestRequest.accountIdentifier = homeAccountId;
    guestRequest.cacheAuthority = guestRequest.authority;
    guestRequest.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    guestRequest.testAccount.targetTenantId = self.primaryAccount.targetTenantId;
    [self runSharedSilentAADLoginWithTestRequest:guestRequest guestTenantScenario:YES];

    // 3. Run silent for the home tenant
    homeRequest.accountIdentifier = homeAccountId;
    homeRequest.cacheAuthority = homeRequest.authority;
    homeRequest.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.homeTenantId];
    homeRequest.testAccount.targetTenantId = self.primaryAccount.homeTenantId;
    [self runSharedSilentAADLoginWithTestRequest:homeRequest];
}

@end
