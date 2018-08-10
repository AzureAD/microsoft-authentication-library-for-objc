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

#import "MSALBaseUITest.h"
#import "MSALBaseAADUITest.h"

@interface MSALMSABasicInteractiveTests : MSALBaseAADUITest

@end

@implementation MSALMSABasicInteractiveTests

#pragma mark - Setup

- (void)setUp
{
    [super setUp];

    self.consentTitle = @"Yes";

    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderMSA;
    configurationRequest.appVersion = MSIDAppVersionV1;
    configurationRequest.accountFeatures = @[];
    [self loadTestConfiguration:configurationRequest];
}

#pragma mark - Converged app

- (void)testInteractiveMSALogin_withConvergedApp_andMicrosoftGraphScopes_andCommonEndpoint_andSystemWebView_andForceLogin
{
    NSArray *expectedScopes = @[@"user.read",
                                @"tasks.read",
                                @"openid", @"profile"];

    NSString *homeAccountId = [self runSharedAADLoginWithClientId:@"3c62ac97-29eb-4aed-a3c8-add0298508da"
                                                           scopes:@"user.read tasks.read"
                                             expectedResultScopes:expectedScopes
                                                      redirectUri:@"msal3c62ac97-29eb-4aed-a3c8-add0298508da://auth"
                                                        authority:@"https://login.microsoftonline.com/common"
                                                       uiBehavior:@"force"
                                                        loginHint:self.primaryAccount.account
                                                accountIdentifier:nil
                                                validateAuthority:YES
                                               useEmbeddedWebView:NO
                                          useSafariViewController:NO
                                                 usePassedWebView:NO
                                                  expectedAccount:self.primaryAccount];
    XCTAssertNotNil(homeAccountId);

    [self runSharedAuthUIAppearsStepWithClientId:@"3c62ac97-29eb-4aed-a3c8-add0298508da"
                                          scopes:@"user.read tasks.read"
                                     redirectUri:@"msal3c62ac97-29eb-4aed-a3c8-add0298508da://auth"
                                       authority:@"https://login.microsoftonline.com/common"
                                      uiBehavior:@"force"
                                       loginHint:self.primaryAccount.account
                               accountIdentifier:nil
                               validateAuthority:YES
                              useEmbeddedWebView:NO
                         useSafariViewController:NO
                                usePassedWebView:NO];

    NSString *authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    [self runSharedSilentAADLoginWithClientId:@"3c62ac97-29eb-4aed-a3c8-add0298508da"
                                       scopes:@"user.read tasks.read"
                         expectedResultScopes:expectedScopes
                              silentAuthority:authority
                               cacheAuthority:authority
                            accountIdentifier:homeAccountId
                            validateAuthority:YES
                              expectedAccount:self.primaryAccount];
}

- (void)testInteractiveMSALogin_withConvergedApp_andMicrosoftGraphScopes_andConsumersEndpoint_andSystemWebView_andForceLogin
{
    NSArray *expectedScopes = @[@"user.read",
                                @"tasks.read",
                                @"openid", @"profile"];

    NSString *homeAccountId = [self runSharedAADLoginWithClientId:@"3c62ac97-29eb-4aed-a3c8-add0298508da"
                                                           scopes:@"user.read tasks.read"
                                             expectedResultScopes:expectedScopes
                                                      redirectUri:@"msal3c62ac97-29eb-4aed-a3c8-add0298508da://auth"
                                                        authority:@"https://login.microsoftonline.com/consumers"
                                                       uiBehavior:@"force"
                                                        loginHint:self.primaryAccount.account
                                                accountIdentifier:nil
                                                validateAuthority:YES
                                               useEmbeddedWebView:NO
                                          useSafariViewController:NO
                                                 usePassedWebView:NO
                                                  expectedAccount:self.primaryAccount];

    XCTAssertNotNil(homeAccountId);

    NSString *authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/%@", self.primaryAccount.targetTenantId];

    [self runSharedSilentAADLoginWithClientId:@"3c62ac97-29eb-4aed-a3c8-add0298508da"
                                       scopes:@"user.read tasks.read"
                         expectedResultScopes:expectedScopes
                              silentAuthority:authority
                               cacheAuthority:authority
                            accountIdentifier:homeAccountId
                            validateAuthority:YES
                              expectedAccount:self.primaryAccount];
}

#pragma mark - Non-converged app

// TODO: server side bug here
- (void)testInteractiveAADLogin_withNonConvergedApp_andMicrosoftGraphScopes_andConsumersEndpoint_andSystemWebView_andForceLogin
{
    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.appVersion = MSIDAppVersionV1;
    configurationRequest.accountFeatures = @[];
    [self loadTestConfiguration:configurationRequest];

    NSDictionary *config = [self configDictionaryWithClientId:nil
                                                       scopes:@"https://graph.microsoft.com/.default"
                                                  redirectUri:nil
                                                    authority:@"https://login.microsoftonline.com/consumers"
                                                   uiBehavior:@"force"
                                                    loginHint:nil
                                            validateAuthority:YES
                                           useEmbeddedWebView:NO
                                      useSafariViewController:NO
                                             usePassedWebView:NO
                                            accountIdentifier:nil];
    [self acquireToken:config];
    [self allowSFAuthenticationSessionAlert];
    [self aadEnterEmail];
    [self aadEnterPassword];
    [self acceptMSSTSConsentIfNecessary:@"Yes"];
    [self assertErrorCode:@"MSALErrorInvalidRequest"];
    [self assertErrorDescription:@"Please use the /organizations or tenant-specific endpoint."];
    [self closeResultView];
}

@end
