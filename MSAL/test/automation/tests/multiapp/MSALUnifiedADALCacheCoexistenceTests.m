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

@interface MSALUnifiedADALCacheCoexistenceTests : MSALBaseAADUITest

@end

@implementation MSALUnifiedADALCacheCoexistenceTests

static BOOL adalAppInstalled = NO;

#pragma mark - Setup

- (void)setUp
{
    [super setUp];

    // We only need to install app once for all the tests
    // It would be better to use +(void)setUp here, but XCUIApplication launch doesn't work then, so using this mechanism instead
    if (!adalAppInstalled)
    {
        adalAppInstalled = YES;
        [self installAppWithId:@"adal_unified"];
        [self.testApp activate];
        [self closeResultView];
    }

    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    configurationRequest.appVersion = MSIDAppVersionV1;
    [self loadTestConfiguration:configurationRequest];
}

#pragma mark - Tests

- (void)testCoexistenceWithUnifiedADAL_startSigninInADAL_withAADAccount_andDoTokenRefresh
{
    // 1. Install previous ADAL version and signin
    self.testApp = [self adalUnifiedApp];

    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.validateAuthority = YES;
    request.additionalParameters = @{@"prompt_behavior": @"always"};

    NSDictionary *config = [self configWithTestRequest:request];

    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];

    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 2. Switch to MSAL and acquire token silently with organizations authority
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    request.authority = @"https://login.windows.net/organizations";
    request.additionalParameters = @{@"user_legacy_identifier": self.primaryAccount.account};
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.windows.net/%@", self.primaryAccount.targetTenantId];
    request.scopes = @"https://graph.windows.net/.default";
    request.expectedResultScopes = @[@"https://graph.windows.net/.default"];

    // 3. Check accounts are correctly returned
    NSDictionary *configuration = [self configWithTestRequest:request];
    [self readAccounts:configuration];

    NSDictionary *result = [self resultDictionary];
    XCTAssertEqual([result[@"account_count"] integerValue], 1);
    NSArray *accounts = result[@"accounts"];
    NSDictionary *firstAccount = accounts[0];
    XCTAssertEqualObjects(firstAccount[@"username"], self.primaryAccount.account);
    [self closeResultView];

    // 4. Run silent tests
    [self runSharedSilentAADLoginWithTestRequest:request];

    // 5. Check accounts are correctly updated
    configuration = [self configWithTestRequest:request];
    [self readAccounts:configuration];

    result = [self resultDictionary];
    XCTAssertEqual([result[@"account_count"] integerValue], 1);
    accounts = result[@"accounts"];
    firstAccount = accounts[0];
    XCTAssertEqualObjects(firstAccount[@"username"], self.primaryAccount.account);
    [self closeResultView];
}

- (void)testCoexistenceWithUnifiedADAL_startSigninInMSAL_withAADAccount_andDoTokenRefresh
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.authority = @"https://login.windows.net/organizations";
    request.loginHint = self.primaryAccount.account;
    request.testAccount = self.primaryAccount;
    request.scopes = @"https://graph.windows.net/.default";
    request.expectedResultScopes = @[@"https://graph.windows.net/.default"];

    // 1. Sign into the MSAL test app
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2.Switch to unified ADAL and acquire token silently with common authority
    self.testApp = [self adalUnifiedApp];
    request.additionalParameters = @{@"prompt_behavior": @"always",
                                     @"resource": @"https://graph.windows.net",
                                     @"user_identifier": self.primaryAccount.account
                                     };

    request.authority = @"https://login.microsoftonline.com/common";
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 3. Now expire token in non-unified ADAL
    request.authority = @"https://login.windows.net/common";
    request.additionalParameters = @{@"user_identifier": self.primaryAccount.account,
                                     @"resource": @"https://graph.windows.net"
                                     };
    config = [self configWithTestRequest:request];
    [self expireAccessToken:config];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // 4. Now acquire token silently
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 5. Run token refresh in MSAL again
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    request.accountIdentifier = homeAccountId;
    request.cacheAuthority = [NSString stringWithFormat:@"https://login.windows.net/%@", self.primaryAccount.targetTenantId];
    [self runSharedSilentAADLoginWithTestRequest:request];
}

- (void)testCoexistenceWithUnifiedADAL_startSigninInMSAL_withAADAccount_andDoTokenRefresh_withFOCIToken
{
    MSALTestRequest *firstAppRequest = [MSALTestRequest fociRequestWithOnedriveApp];
    firstAppRequest.uiBehavior = @"force";
    firstAppRequest.authority = @"https://login.windows.net/organizations";
    firstAppRequest.loginHint = self.primaryAccount.account;
    firstAppRequest.testAccount = self.primaryAccount;
    firstAppRequest.scopes = @"https://graph.windows.net/.default";
    firstAppRequest.expectedResultScopes = @[@"https://graph.windows.net/.default"];

    // 1. Sign into the MSAL test app
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:firstAppRequest];
    XCTAssertNotNil(homeAccountId);

    // 2.Switch to unified ADAL and acquire token silently with common authority
    self.testApp = [self adalUnifiedApp];
    MSALTestRequest *secondAppRequest = [MSALTestRequest fociRequestWithOfficeApp];
    secondAppRequest.additionalParameters = @{@"prompt_behavior": @"always",
                                              @"resource": @"https://graph.windows.net",
                                              @"user_identifier": self.primaryAccount.account
                                              };

    secondAppRequest.authority = @"https://login.microsoftonline.com/common";
    NSDictionary *config = [self configWithTestRequest:secondAppRequest];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 3. Now expire token in non-unified ADAL
    secondAppRequest.authority = @"https://login.windows.net/common";
    config = [self configWithTestRequest:secondAppRequest];
    [self expireAccessToken:config];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // 4. Now acquire token silently
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // 5. Run token refresh in MSAL again
    self.testApp = [XCUIApplication new];
    [self.testApp activate];

    secondAppRequest.accountIdentifier = homeAccountId;
    secondAppRequest.cacheAuthority = [NSString stringWithFormat:@"https://login.windows.net/%@", self.primaryAccount.targetTenantId];
    secondAppRequest.redirectUri = MSAL_TEST_DEFAULT_NON_CONVERGED_REDIRECT_URI;
    secondAppRequest.scopes = @"https://graph.windows.net/.default";
    secondAppRequest.expectedResultScopes = @[@"https://graph.windows.net/.default"];
    [self runSharedSilentAADLoginWithTestRequest:secondAppRequest];
}

- (XCUIApplication *)adalUnifiedApp
{
    return [self openAppWithAppId:@"adal_unified"];
}

- (void)testMSALCoexistenceWithUnifiedADAL_startSigninInADAL_withAADAccount_andDoTokenRefreshInMSAL_withFOCIToken
{
    // 1. Install previous ADAL version and signin
    self.testApp = [self adalUnifiedApp];
    
    MSALTestRequest *request = [MSALTestRequest fociRequestWithOfficeApp];
    request.additionalParameters = @{@"prompt_behavior": @"always",
                                              @"resource": @"https://graph.windows.net"};
    
    request.authority = @"https://login.microsoftonline.com/common";
    NSDictionary *config = [self configWithTestRequest:request];
    
    [self acquireToken:config];
    [self aadEnterEmail];
    [self aadEnterPassword];
    
    [self assertAccessTokenNotNil];
    [self closeResultView];
    
    // 5. Run token refresh using FRT in MSAL
    self.testApp = [XCUIApplication new];
    [self.testApp activate];
    
    MSALTestRequest *secondAppRequest = [MSALTestRequest fociRequestWithOnedriveApp];
    secondAppRequest.accountIdentifier = self.primaryAccount.homeAccountId;
    secondAppRequest.scopes = @"https://graph.windows.net/.default";
    
    NSDictionary *msalConfig = [self configWithTestRequest:secondAppRequest];
    //It should refresh access token using family refresh token saved by office app using Adal
    [self acquireTokenSilent:msalConfig];
    [self assertAccessTokenNotNil];
    [self closeResultView];
}

@end
