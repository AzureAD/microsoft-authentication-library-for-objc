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

#import "MSALBaseAADUITest.h"

@interface MSALMultiAppCacheCoexistenceTests : MSALBaseAADUITest

@end

@implementation MSALMultiAppCacheCoexistenceTests

static BOOL msalAppInstalled = NO;

#pragma mark - Setup

- (void)setUp
{
    [super setUp];

    // We only need to install app once for all the tests
    // It would be better to use +(void)setUp here, but XCUIApplication launch doesn't work then, so using this mechanism instead
    if (!msalAppInstalled)
    {
        msalAppInstalled = YES;
        [self installAppWithId:@"msal_unified"];
        [self.testApp activate];
        [self closeResultView];
    }

    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    configurationRequest.appVersion = MSIDAppVersionV1;
    [self loadTestConfiguration:configurationRequest];
}

#pragma mark - Tests

- (void)testCoexistenceWithAnotherMSAL_startSigninInOtherMSAL_withAADAccount_andDoTokenRefresh
{
    // 1. Install other MSAL version and signin
    self.testApp = [self otherMSALApp];

    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.validateAuthority = YES;
    request.scopes = @"https://graph.windows.net/.default";
    request.expectedResultScopes = @[@"https://graph.windows.net/.default"];
    request.authority = [NSString stringWithFormat:@"https://login.windows.net/%@", self.primaryAccount.targetTenantId];
    request.uiBehavior = @"force";

    NSDictionary *config = [self configWithTestRequest:request];

    [self acquireToken:config];
    [self acceptAuthSessionDialog];
    [self aadEnterEmail];
    [self aadEnterPassword];

    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 2. Switch to current MSAL and acquire token silently with organizations authority
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    request.authority = @"https://login.windows.net/organizations";
    request.accountIdentifier = self.primaryAccount.homeAccountId;
    request.scopes = @"user.read";
    request.expectedResultScopes = @[@"user.read", @"openid", @"profile"];
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.windows.net/%@", self.primaryAccount.targetTenantId];

    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testCoexistenceWithOtherMSAL_startSigninInCurrentMSAL_withAADAccount_andUseDifferentAuthorities
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.loginHint = self.primaryAccount.account;
    request.testAccount = self.primaryAccount;
    request.scopes = @"user.read";
    request.expectedResultScopes = @[@"user.read", @"openid", @"profile"];

    // 1. Sign into the MSAL test app
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2.Switch to other MSAL app and acquire token silently with common authority
    self.testApp = [self otherMSALApp];
    request.accountIdentifier = homeAccountId;
    request.authority = @"https://login.windows.net/organizations";
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.windows.net/%@", self.primaryAccount.targetTenantId];
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 3. Now expire token in other MSAL Aapp
    request.authority = [NSString stringWithFormat:@"https://login.windows.net/%@", self.primaryAccount.targetTenantId];
    request.additionalParameters = @{@"user_identifier": self.primaryAccount.account,
                                     @"resource": @"https://graph.windows.net",
                                     @"user_identifier_type" : @"optional_displayable"
                                     };
    config = [self configWithTestRequest:request];
    [self expireAccessToken:config];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // 4. Now acquire token silently
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 5. Run token refresh in current MSAL again
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    request.accountIdentifier = homeAccountId;
    request.authority = @"https://login.microsoftonline.com/organizations";
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (XCUIApplication *)otherMSALApp
{
    return [self openAppWithAppId:@"msal_unified"];
}

@end
