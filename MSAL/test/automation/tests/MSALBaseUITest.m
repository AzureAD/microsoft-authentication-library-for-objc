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

#import "MSALBaseUITest.h"
#import "NSDictionary+MSALiOSUITests.h"
#import "MSIDTestAutomationConfigurationRequest.h"
#import "MSIDTestAccountsProvider.h"
#import "XCTestCase+TextFieldTap.h"
#import "NSDictionary+MSALiOSUITests.h"
#import "MSIDAADV1IdTokenClaims.h"
#import "XCUIElement+CrossPlat.h"
#import "MSIDAADIdTokenClaimsFactory.h"

static MSIDTestAccountsProvider *s_accountsProvider;

@implementation MSALBaseUITest

+ (void)setUp
{
    [super setUp];
    NSString *confPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"conf" ofType:@"json"];
    self.class.accountsProvider = [[MSIDTestAccountsProvider alloc] initWithConfigurationPath:confPath];
}

- (void)setUp
{
    [super setUp];
    
    self.continueAfterFailure = NO;
    
    self.testApp = [XCUIApplication new];
    [self.testApp launch];

    [self clearKeychain];
    [self clearCookies];
}

- (void)tearDown
{
    [self.testApp terminate];
    [super tearDown];
}

+ (MSIDTestAccountsProvider *)accountsProvider
{
    return s_accountsProvider;
}

+ (void)setAccountsProvider:(MSIDTestAccountsProvider *)accountsProvider
{
    s_accountsProvider = accountsProvider;
}

#pragma mark - Asserts

- (void)assertRefreshTokenInvalidated
{
    NSDictionary *result = [self resultDictionary];
    XCTAssertTrue([result[@"invalidated_refresh_token"] boolValue] == YES);
}

- (void)assertAccessTokenExpired
{
    NSDictionary *result = [self resultDictionary];
    XCTAssertTrue([result[@"expired_access_token_count"] intValue] == 1);
}

- (void)assertAuthUIAppearsUsingEmbeddedWebView:(BOOL)useEmbedded
{
    XCUIElement *webElement = self.testApp.buttons[@"URL"];

    if (useEmbedded)
    {
        webElement = self.testApp.buttons[@"Cancel"];
    }
    
    BOOL result = [webElement waitForExistenceWithTimeout:5.0];
    
    XCTAssertTrue(result);
}

- (void)assertErrorCode:(NSString *)expectedErrorCode
{
    [self assertErrorContent:expectedErrorCode key:@"error_code"];
}

- (void)assertErrorDescription:(NSString *)errorDescription
{
    NSDictionary *result = [self resultDictionary];
    NSString *actualContent = result[@"error_description"];
    XCTAssertNotEqual([actualContent length], 0);
    XCTAssertTrue([actualContent containsString:errorDescription]);
}

- (void)assertErrorSubcode:(NSString *)errorSubcode
{
    [self assertErrorContent:errorSubcode key:@"subcode"];
}

- (void)assertErrorContent:(NSString *)expectedContent key:(NSString *)key
{
    NSDictionary *result = [self resultDictionary];
    NSString *actualContent = result[key];
    XCTAssertNotEqual([actualContent length], 0);
    XCTAssertEqualObjects(actualContent, expectedContent);
}

- (void)assertAccessTokenNotNil
{
    NSDictionary *result = [self resultDictionary];
    
    XCTAssertTrue([result[@"access_token"] length] > 0);
    XCTAssertEqual([result[@"error"] length], 0);
}

- (void)assertScopesReturned:(NSArray *)expectedScopes
{
    NSDictionary *result = [self resultDictionary];
    NSArray *resultScopes = result[@"scopes"];

    for (NSString *expectedScope in expectedScopes)
    {
        XCTAssertTrue([resultScopes containsObject:expectedScope]);
    }
}

- (void)assertAuthorityReturned:(NSString *)expectedAuthority
{
    if (!expectedAuthority) return;

    NSDictionary *result = [self resultDictionary];
    NSString *resultAuthority = result[@"authority"];
    
    XCTAssertEqualObjects(expectedAuthority, resultAuthority);
}

- (NSDictionary *)resultIDTokenClaims
{
    NSDictionary *result = [self resultDictionary];

    NSString *idToken = result[@"id_token"];
    XCTAssertTrue([idToken length] > 0);

    MSIDIdTokenClaims *idTokenClaims = [MSIDAADIdTokenClaimsFactory claimsFromRawIdToken:idToken error:nil];
    return [idTokenClaims jsonDictionary];
}

- (void)assertRefreshTokenNotNil
{
    NSDictionary *result = [self resultDictionary];
    XCTAssertTrue([result[@"refresh_token"] length] > 0);
}

#pragma mark - API fetch

- (void)loadTestConfiguration:(MSIDTestAutomationConfigurationRequest *)request
{
    __block MSIDTestAutomationConfiguration *testConfig = nil;

    XCTestExpectation *expectation = [self expectationWithDescription:@"Get configuration"];

    [self.class.accountsProvider configurationWithRequest:request
                                        completionHandler:^(MSIDTestAutomationConfiguration *configuration) {

                                      testConfig = configuration;
                                      [expectation fulfill];
                                  }];

    [self waitForExpectationsWithTimeout:60 handler:nil];

    if (!testConfig || ![testConfig.accounts count])
    {
        XCTAssertTrue(NO);
    }

    [self loadPasswordForAccount:testConfig.accounts[0]];

    self.testConfiguration = testConfig;
    XCTAssertTrue([self.testConfiguration.accounts count] >= 1);
    self.primaryAccount = self.testConfiguration.accounts[0];
}

- (void)loadPasswordForAccount:(MSIDTestAccount *)account
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Get password"];

    [self.class.accountsProvider passwordForAccount:account
                                  completionHandler:^(NSString *password) {
                                [expectation fulfill];
                            }];

    [self waitForExpectationsWithTimeout:60 handler:nil];

    if (!account.password)
    {
        XCTAssertTrue(NO);
    }
}

#pragma mark - Actions

- (void)aadEnterEmail
{
    [self aadEnterEmail:[NSString stringWithFormat:@"%@\n", self.primaryAccount.account] app:self.testApp];
}

- (void)aadEnterEmail:(NSString *)email app:(XCUIApplication *)app
{
    XCUIElement *emailTextField = app.textFields[@"Enter your email, phone, or Skype."];
    [self waitForElement:emailTextField];
    if ([email isEqualToString:emailTextField.value])
    {
        return;
    }

    [self tapElementAndWaitForKeyboardToAppear:emailTextField app:app];
    [emailTextField selectTextWithApp:app];
    [emailTextField typeText:email];
}

- (void)aadEnterPassword
{
    [self aadEnterPassword:[NSString stringWithFormat:@"%@\n", self.primaryAccount.password] app:self.testApp];
}

- (void)aadEnterPassword:(NSString *)password app:(XCUIApplication *)app
{
    // Enter password
    XCUIElement *passwordTextField = app.secureTextFields[@"Enter password"];
    [self waitForElement:passwordTextField];
    [self tapElementAndWaitForKeyboardToAppear:passwordTextField app:app];
    [passwordTextField typeText:password];
}

- (void)acceptMSSTSConsentIfNecessary:(NSString *)acceptButtonTitle embeddedWebView:(BOOL)embeddedWebView
{
    XCUIElement *consentAcceptButton = self.testApp.buttons[acceptButtonTitle];

    int i = 0;

    while (i < 20) {

        // If consent button found, tap it and return
        if (consentAcceptButton.exists)
        {
            [consentAcceptButton msidTap];
            return;
        }
        // If consent button is not there, but system webview is still shown, wait for 1 more second
        else if ([self.testApp.buttons[@"URL"] exists] && !embeddedWebView)
        {
            sleep(1);
            i++;
        }
        else if ([self.testApp.buttons[@"Cancel"] exists] && embeddedWebView)
        {
            sleep(1);
            i++;
        }
        else
        {
            // otherwise, flow is likely completed and system webview is gone
            // Stop waiting and go to the next step
            return;
        }
    }
}

- (void)adfsEnterPassword
{
    [self adfsEnterPassword:[NSString stringWithFormat:@"%@\n", self.primaryAccount.password] app:self.testApp];
}

- (void)adfsEnterPassword:(NSString *)password app:(XCUIApplication *)app
{
    XCUIElement *passwordTextField = app.secureTextFields[@"Password"];
    [self waitForElement:passwordTextField];
    [self tapElementAndWaitForKeyboardToAppear:passwordTextField app:app];
    [passwordTextField typeText:password];
}

- (void)closeAuthUIUsingWebViewType:(MSALWebviewType)webViewType
                    passedInWebView:(BOOL)usesPassedInWebView
{
    NSString *buttonTitle = @"Cancel";

    CGFloat osVersion = [[[UIDevice currentDevice] systemVersion] floatValue];

    if (webViewType == MSALWebviewTypeSafariViewController
        || (webViewType == MSALWebviewTypeDefault && osVersion < 11.0f && !usesPassedInWebView))
    {
        buttonTitle = @"Done";
    }

    [self.testApp.buttons[buttonTitle] msidTap];
}

- (void)closeResultView
{
    [self.testApp.buttons[@"Done"] msidTap];
}

- (void)invalidateRefreshToken:(NSDictionary *)config
{
    [self performAction:@"invalidateRefreshToken" withConfig:config];
}

- (void)expireAccessToken:(NSDictionary *)config
{
    [self performAction:@"expireAccessToken" withConfig:config];
}

- (void)acquireToken:(NSDictionary *)config
{
    [self performAction:@"acquireToken" withConfig:config];
}

- (void)acquireTokenSilent:(NSDictionary *)config
{
    [self performAction:@"acquireTokenSilent" withConfig:config];
}

- (void)clearKeychain
{
    [self.testApp.buttons[@"clearKeychain"] msidTap];
    [self.testApp.buttons[@"Done"] msidTap];
}

- (void)clearCookies
{
    [self.testApp.buttons[@"clearCookies"] msidTap];
    [self.testApp.buttons[@"Done"] msidTap];
}

- (void)openURL:(NSDictionary *)config
{
    [self performAction:@"openUrlInSafari" withConfig:config];
}

- (void)signout:(NSDictionary *)config
{
    [self performAction:@"signOut" withConfig:config];
}

- (void)readAccounts:(NSDictionary *)config
{
    [self performAction:@"getAccounts" withConfig:config];
}

#pragma mark - Helpers

- (void)performAction:(NSString *)action
           withConfig:(NSDictionary *)config
{
    NSString *jsonString = [config toJsonString];
    [self.testApp.buttons[action] msidTap];
    [self.testApp.textViews[@"requestInfo"] msidTap];
    [self.testApp.textViews[@"requestInfo"] msidPasteText:jsonString application:self.testApp];
    sleep(1);
    [self.testApp.buttons[@"Go"] msidTap];
}

- (NSDictionary *)resultDictionary
{
    XCUIElement *resultTextView = self.testApp.textViews[@"resultInfo"];
    [self waitForElement:resultTextView];

    NSError *error = nil;
    NSData *data = [resultTextView.value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    return result;
}

- (void)waitForElement:(id)object
{
    NSPredicate *existsPredicate = [NSPredicate predicateWithFormat:@"exists == 1"];
    [self expectationForPredicate:existsPredicate evaluatedWithObject:object handler:nil];
    [self waitForExpectationsWithTimeout:60.0f handler:nil];
}

#pragma mark - Config

- (NSDictionary *)configWithTestRequest:(MSALTestRequest *)request
{
    NSMutableDictionary *additionalConfig = [NSMutableDictionary dictionary];

    if (request.clientId) additionalConfig[@"client_id"] = request.clientId;
    if (request.redirectUri) additionalConfig[@"redirect_uri"] = request.redirectUri;
    if (request.uiBehavior) additionalConfig[@"ui_behavior"] = request.uiBehavior;
    if (request.authority) additionalConfig[@"authority"] = request.authority;
    if (request.scopes) additionalConfig[@"scopes"] = request.scopes;
    if (request.loginHint) additionalConfig[@"login_hint"] = request.loginHint;
    if (request.sliceParameters) additionalConfig[@"slice_params"] = request.sliceParameters;

    if (request.usePassedWebView)
    {
        additionalConfig[@"webview_selection"] = @"passed_webview";
    }
    else
    {
        switch (request.webViewType) {
            case MSALWebviewTypeSafariViewController:
                additionalConfig[@"webview_selection"] = @"webview_safari";
                break;
            case MSALWebviewTypeWKWebView:
                additionalConfig[@"webview_selection"] = @"webview_embedded";
                break;

            default:
                break;
        }
    }

    if (request.accountIdentifier) additionalConfig[@"home_account_identifier"] = request.accountIdentifier;

    additionalConfig[@"validate_authority"] = @(request.validateAuthority);
    [additionalConfig addEntriesFromDictionary:request.additionalParameters];

    return [self.testConfiguration configWithAdditionalConfiguration:additionalConfig];
}

@end
