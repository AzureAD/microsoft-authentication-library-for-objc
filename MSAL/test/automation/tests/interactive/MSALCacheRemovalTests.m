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

@interface MSALCacheRemovalTests : MSALBaseAADUITest

@end

@implementation MSALCacheRemovalTests

- (void)setUp
{
    [super setUp];
    
    // Load multiple accounts conf
    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderWW;
    configurationRequest.appVersion = MSIDAppVersionV1;
    configurationRequest.needsMultipleUsers = YES;
    // TODO: no other app returns multiple accounts
    configurationRequest.appName = @"IDLABSAPP";
    [self loadTestConfiguration:configurationRequest];

    XCTAssertTrue([self.testConfiguration.accounts count] >= 2);
}

- (void)testRemoveAADAccount_whenOnlyOneAccountInCache_andConvergedApp
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.scopes = @"user.read";
    request.expectedResultScopes = @[@"user.read", @"openid", @"profile"];
    request.authority = @"https://login.microsoftonline.com/organizations";
    request.loginHint = self.primaryAccount.account;
    request.testAccount = self.primaryAccount;

    // 1. Run interactive login
    NSString *homeAccountId = [self runSharedAADLoginWithTestRequest:request];
    XCTAssertNotNil(homeAccountId);

    // 2. Remove account
    request.accountIdentifier = homeAccountId;
    NSDictionary *config = [self configWithTestRequest:request];
    [self signout:config];
    NSDictionary *resultDictionary = [self resultDictionary];
    XCTAssertEqualObjects(resultDictionary[@"user_signout_result"], @"yes");
    [self closeResultView];

    // 3. Try silent and expect failure
    [self acquireTokenSilent:config];
    [self assertErrorCode:@"no_account"];
}

- (void)testRemoveAADAccount_whenMultipleAccountsInCache_andNonConvergedApp
{
    MSALTestRequest *firstRequest = [MSALTestRequest nonConvergedAppRequest];
    firstRequest.uiBehavior = @"force";
    firstRequest.scopes = @"https://graph.windows.net/.default";
    firstRequest.expectedResultScopes = @[@"https://graph.windows.net/.default"];
    firstRequest.authority = @"https://login.microsoftonline.com/organizations";
    firstRequest.loginHint = self.primaryAccount.account;
    firstRequest.testAccount = self.primaryAccount;

    // 1. Run interactive login for the first account
    NSString *firstHomeAccountId = [self runSharedAADLoginWithTestRequest:firstRequest];
    XCTAssertNotNil(firstHomeAccountId);

    self.primaryAccount = self.testConfiguration.accounts[1];
    [self loadPasswordForAccount:self.primaryAccount];

    MSALTestRequest *secondRequest = [MSALTestRequest nonConvergedAppRequest];
    secondRequest.uiBehavior = @"force";
    secondRequest.scopes = @"https://graph.windows.net/.default";
    secondRequest.expectedResultScopes = @[@"https://graph.windows.net/.default"];
    secondRequest.authority = @"https://login.microsoftonline.com/organizations";
    secondRequest.loginHint = self.primaryAccount.account;
    secondRequest.testAccount = self.primaryAccount;
    // 2. Run interactive login for the second account
    NSString *secondHomeAccountId = [self runSharedAADLoginWithTestRequest:secondRequest];
    XCTAssertNotNil(secondHomeAccountId);

    // 3. Remove first account
    self.primaryAccount = self.testConfiguration.accounts[0];
    firstRequest.accountIdentifier = firstHomeAccountId;
    NSDictionary *config = [self configWithTestRequest:firstRequest];
    [self signout:config];
    NSDictionary *resultDictionary = [self resultDictionary];
    XCTAssertEqualObjects(resultDictionary[@"user_signout_result"], @"yes");
    [self closeResultView];

    // 4. Try silent and expect failure for the first account
    [self acquireTokenSilent:config];
    [self assertErrorCode:@"no_account"];
    [self closeResultView];

    // 5. Expect silent to still work for the second account
    self.primaryAccount = self.testConfiguration.accounts[1];
    secondRequest.accountIdentifier = secondHomeAccountId;
    secondRequest.cacheAuthority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];
    [self runSharedSilentAADLoginWithTestRequest:secondRequest];
}

@end
