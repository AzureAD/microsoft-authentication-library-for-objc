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
#import "MSIDTestConfigurationProvider.h"
#import "XCUIElement+MSALiOSUITests.h"
#import "MSIDTestAutomationConfiguration.h"
#import "MSIDAutomationConfigurationRequest.h"
#import "MSIDAutomationTestRequest.h"
#import "MSIDAutomationErrorResult.h"
#import "MSIDAutomationSuccessResult.h"
#import "MSIDAutomationAccountsResult.h"

@interface MSALBaseUITest : XCTestCase

@property (nonatomic) XCUIApplication *testApp;
@property (nonatomic, class) MSIDTestConfigurationProvider *confProvider;
@property (nonatomic) MSIDTestAccount *primaryAccount;
@property (nonatomic) MSIDTestAutomationConfiguration *testConfiguration;

// Common checks/assertions
- (void)assertRefreshTokenInvalidated;
- (void)assertAccessTokenExpired;
- (void)assertAuthUIAppearsUsingEmbeddedWebView:(BOOL)useEmbedded;
- (void)assertErrorCode:(NSInteger)expectedErrorCode;
- (void)assertInternalErrorCode:(NSInteger)internalErrorCode;
- (void)assertErrorDescription:(NSString *)errorDescription;
- (void)assertErrorSubcode:(NSString *)errorSubcode;
- (void)assertAccessTokenNotNil;
- (void)assertScopesReturned:(NSArray *)expectedScopes;
- (void)assertAuthorityReturned:(NSString *)expectedAuthority;
- (NSDictionary *)resultIDTokenClaims;

- (void)closeResultView;
- (void)invalidateRefreshToken:(NSDictionary *)config;
- (void)expireAccessToken:(NSDictionary *)config;
- (void)acquireToken:(NSDictionary *)config;
- (void)acquireTokenSilent:(NSDictionary *)config;
- (void)clearKeychain;
- (void)clearCookies;

- (void)aadEnterEmail;
- (void)aadEnterEmail:(NSString *)email app:(XCUIApplication *)app;

- (void)aadEnterPassword;
- (void)aadEnterPassword:(NSString *)password app:(XCUIApplication *)app;

- (void)adfsEnterPassword;
- (void)adfsEnterPassword:(NSString *)password app:(XCUIApplication *)app;

- (void)acceptMSSTSConsentIfNecessary:(NSString *)acceptButtonTitle embeddedWebView:(BOOL)embeddedWebView;
- (void)acceptSpeedBump;
- (void)closeAuthUIUsingWebViewType:(MSIDWebviewType)webViewType
                    passedInWebView:(BOOL)usesPassedInWebView;
- (void)openURL:(NSDictionary *)config;
- (void)signout:(NSDictionary *)config;
- (void)readAccounts:(NSDictionary *)config;

- (void)waitForElement:(id)object;
- (void)loadTestConfiguration:(MSIDAutomationConfigurationRequest *)request;
- (void)loadPasswordForAccount:(MSIDTestAccount *)account;

- (MSIDAutomationErrorResult *)automationErrorResult;
- (MSIDAutomationSuccessResult *)automationSuccessResult;
- (MSIDAutomationAccountsResult *)automationAccountsResult;

- (NSDictionary *)configWithTestRequest:(MSIDAutomationTestRequest *)request;
- (NSDictionary *)automationResultDictionary;
- (void)performAction:(NSString *)action
           withConfig:(NSDictionary *)config;

@end
