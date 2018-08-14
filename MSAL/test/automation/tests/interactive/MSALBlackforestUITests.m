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

@interface MSALBlackforestUITests : MSALBaseAADUITest

@end

@implementation MSALBlackforestUITests

#pragma mark - Setup

- (void)setUp
{
    [super setUp];

    MSIDTestAutomationConfigurationRequest *configurationRequest = [MSIDTestAutomationConfigurationRequest new];
    configurationRequest.accountProvider = MSIDTestAccountProviderBlackForest;
    configurationRequest.appVersion = MSIDAppVersionV1;
    configurationRequest.needsMultipleUsers = NO;
    configurationRequest.accountFeatures = @[];
    [self loadTestConfiguration:configurationRequest];
}

#pragma mark - Interactive tests

/*
// #290995 iteration 13
- (void)testInteractiveAADLogin_withBlackforestUser_withPromptAlways_withLoginHint_SystemWebView
{
    MSALTestRequest *request = [MSALTestRequest nonConvergedAppRequest];
    request.uiBehavior = @"force";
    request.loginHint = self.primaryAccount.account;


    // Do interactive login
    NSDictionary *params = @{
                             @"prompt_behavior" : @"always",
                             @"validate_authority" : @YES,
                             @"user_identifier" : self.primaryAccount.account,
                             @"user_identifier_type" : @"optional_displayable",
                             @"extra_qp": @"instance_aware=true",
                             @"authority" : @"https://login.microsoftonline.com/common"
                             };
    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];

    [self acquireToken:config];

    [self blackForestWaitForNextButton:self.testApp];
    [self blackforestComEnterPassword];

    [self assertAccessTokenNotNil];
    [self closeResultView];

    NSMutableDictionary *mutableConfig = [config mutableCopy];
    [mutableConfig removeObjectForKey:@"user_identifier"];

    // Acquire token again.
    [self acquireToken:mutableConfig];
    [self assertAuthUIAppear];

    [self closeAuthUI];
    [self assertError:@"AD_ERROR_UI_USER_CANCEL"];
    [self closeResultView];

    // First try silent with WW authority
    NSDictionary *silentParams = @{
                                   @"user_identifier" : self.primaryAccount.account,
                                   @"client_id" : self.testConfiguration.clientId,
                                   @"resource" : self.testConfiguration.resource,
                                   @"authority" : @"https://login.microsoftonline.com/common"
                                   };

    config = [self.testConfiguration configWithAdditionalConfiguration:silentParams];
    [self acquireTokenSilent:config];

    [self assertError:@"AD_ERROR_SERVER_USER_INPUT_NEEDED"];
    [self closeResultView];

    // Now try silent with correct authority - #296889
    silentParams = @{
                     @"user_identifier" : self.primaryAccount.account,
                     @"client_id" : self.testConfiguration.clientId,
                     @"authority" : self.testConfiguration.authority,
                     @"resource" : self.testConfiguration.resource
                     };

    config = [self.testConfiguration configWithAdditionalConfiguration:silentParams];
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Now expire access token
    [self expireAccessToken:config];
    [self assertAccessTokenExpired];
    [self closeResultView];

    // Now do access token refresh
    [self acquireTokenSilent:config];
    [self assertAccessTokenNotNil];
}

// #290995 iteration 14
- (void)testInteractiveAADLogin_withBlackforestUser_withPromptAlways_noLoginHint_ADALWebView
{
    NSDictionary *params = @{
                             @"prompt_behavior" : @"always",
                             @"validate_authority" : @YES,
                             @"extra_qp": @"instance_aware=true",
                             @"authority" : @"https://login.microsoftonline.com/common"
                             };
    NSDictionary *config = [self.testConfiguration configWithAdditionalConfiguration:params];

    [self acquireToken:config];

    [self blackforestComEnterEmail];
    [self blackforestComEnterPassword];

    [self assertAccessTokenNotNil];
    [self closeResultView];

    // Acquire token again.
    [self acquireToken:config];
    [self assertAuthUIAppear];
}

#pragma mark - Private

- (void)blackforestComEnterEmail
{
    XCUIElement *emailTextField = self.testApp.textFields[@"Enter your email, phone, or Skype."];
    [self waitForElement:emailTextField];
    [self tapElementAndWaitForKeyboardToAppear:emailTextField];
    [emailTextField typeText:[NSString stringWithFormat:@"%@\n", self.primaryAccount.account]];
}

- (void)blackforestComEnterPassword
{
    XCUIElement *passwordTextField = self.testApp.secureTextFields[@"Enter password"];
    [self waitForElement:passwordTextField];
    [self tapElementAndWaitForKeyboardToAppear:passwordTextField];
    [passwordTextField typeText:[NSString stringWithFormat:@"%@\n", self.primaryAccount.password]];
}*/

@end
