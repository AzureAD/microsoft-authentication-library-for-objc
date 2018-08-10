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
#import "MSIDTestAccountsProvider.h"
#import "XCUIElement+MSALiOSUITests.h"
#import "MSIDTestAutomationConfiguration.h"
#import "MSIDTestAutomationConfigurationRequest.h"

@interface MSALBaseUITest : XCTestCase

@property (nonatomic) XCUIApplication *testApp;
@property (nonatomic, class) MSIDTestAccountsProvider *accountsProvider;
@property (nonatomic) MSIDTestAccount *primaryAccount;
@property (nonatomic) MSIDTestAutomationConfiguration *testConfiguration;

- (void)assertRefreshTokenInvalidated;
- (void)assertAccessTokenExpired;
- (void)assertAuthUIAppearWithEmbedded:(BOOL)embedded safariViewController:(BOOL)safariViewController;
- (void)assertErrorCode:(NSString *)expectedErrorCode;
- (void)assertErrorDescription:(NSString *)errorDescription;
- (void)assertAccessTokenNotNil;
- (void)assertScopesReturned:(NSArray *)expectedScopes;
- (NSDictionary *)resultIDTokenClaims;
- (void)assertRefreshTokenNotNil;

- (void)closeResultView;
- (void)invalidateRefreshToken:(NSDictionary *)config;
- (void)expireAccessToken:(NSDictionary *)config;
- (void)acquireToken:(NSDictionary *)config;
- (void)acquireTokenSilent:(NSDictionary *)config;
- (void)acquireTokenWithRefreshToken:(NSDictionary *)config;
- (void)clearCache;
- (void)clearKeychain;
- (void)clearCookies;
- (void)aadEnterEmail:(NSString *)email;
- (void)aadEnterEmail;
- (void)aadEnterEmailInApp:(XCUIApplication *)app;
- (void)aadEnterPassword;
- (void)aadEnterPassword:(NSString *)password;
- (void)aadEnterPasswordInApp:(XCUIApplication *)app;
- (void)aadEnterPassword:(NSString *)password testApp:(XCUIApplication *)testApp;
- (void)adfsEnterPassword;
- (void)adfsEnterPasswordInApp:(XCUIApplication *)app;
- (void)adfsEnterPassword:(NSString *)password;
- (void)adfsEnterPassword:(NSString *)password testApp:(XCUIApplication *)testApp;
- (void)acceptMSSTSConsentIfNecessary:(NSString *)acceptButtonTitle;
- (void)closeAuthUIWithEmbedded:(BOOL)embedded safariViewController:(BOOL)safariViewController;
- (void)openURL:(NSDictionary *)config;

- (void)waitForElement:(id)object;
- (NSDictionary *)resultDictionary;
- (void)loadTestConfiguration:(MSIDTestAutomationConfigurationRequest *)request;
- (void)loadPasswordForAccount:(MSIDTestAccount *)account;

- (NSDictionary *)configDictionaryWithClientId:(NSString *)clientId
                                        scopes:(NSString *)scopes
                                   redirectUri:(NSString *)redirectUri
                                     authority:(NSString *)authority
                                    uiBehavior:(NSString *)uiBehavior
                                     loginHint:(NSString *)loginHint
                             validateAuthority:(BOOL)validateAuthority
                            useEmbeddedWebView:(BOOL)useEmbedded
                       useSafariViewController:(BOOL)useSFController
                              usePassedWebView:(BOOL)usePassedWebView
                             accountIdentifier:(NSString *)accountIdentifier;

@end
