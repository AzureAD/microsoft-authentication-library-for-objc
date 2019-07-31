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
#import "MSIDAutomationConfigurationRequest.h"
#import "MSIDTestConfigurationProvider.h"
#import "XCTestCase+TextFieldTap.h"
#import "NSDictionary+MSALiOSUITests.h"
#import "MSIDAADV1IdTokenClaims.h"
#import "XCUIElement+CrossPlat.h"
#import "MSIDAADIdTokenClaimsFactory.h"
#import "MSIDAutomationActionConstants.h"
#import "MSIDTestConfigurationProvider.h"

static MSIDTestConfigurationProvider *s_confProvider;

@implementation MSALBaseUITest

+ (void)setUp
{
    [super setUp];
    
    MSIDTestAutomationConfiguration.defaultRegisteredScheme = @"x-msauth-msalautomationapp";
    
    NSString *confPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"conf" ofType:@"json"];
    self.class.confProvider = [[MSIDTestConfigurationProvider alloc] initWithConfigurationPath:confPath];
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

+ (MSIDTestConfigurationProvider *)confProvider
{
    return s_confProvider;
}

+ (void)setConfProvider:(MSIDTestConfigurationProvider *)accountsProvider
{
    s_confProvider = accountsProvider;
}

#pragma mark - Asserts

- (void)assertRefreshTokenInvalidated
{
    MSIDAutomationSuccessResult *result = [self automationSuccessResult];
    XCTAssertTrue(result.success);
}

- (void)assertAccessTokenExpired
{
    MSIDAutomationSuccessResult *result = [self automationSuccessResult];
    XCTAssertTrue(result.success);
    XCTAssertEqual(result.actionCount, 1);
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

- (void)assertErrorCode:(NSInteger)expectedErrorCode
{
    MSIDAutomationErrorResult *result = [self automationErrorResult];
    XCTAssertEqual(expectedErrorCode, result.errorCode);
}

- (void)assertInternalErrorCode:(NSInteger)internalErrorCode
{
    MSIDAutomationErrorResult *result = [self automationErrorResult];
    XCTAssertEqual(internalErrorCode, [result.errorUserInfo[MSALInternalErrorCodeKey] integerValue]);
}

- (void)assertErrorDescription:(NSString *)errorDescription
{
    MSIDAutomationErrorResult *result = [self automationErrorResult];
    NSString *actualContent = result.errorDescription;
    XCTAssertNotEqual([actualContent length], 0);
    XCTAssertTrue([actualContent containsString:errorDescription]);
}

- (void)assertErrorSubcode:(NSString *)errorSubcode
{
    MSIDAutomationErrorResult *result = [self automationErrorResult];
    NSString *actualSubCode = result.errorUserInfo[@"MSALOAuthSubErrorKey"];
    XCTAssertEqualObjects(errorSubcode, actualSubCode);
}

- (void)assertAccessTokenNotNil
{
    MSIDAutomationSuccessResult *result = [self automationSuccessResult];

    XCTAssertTrue([result.accessToken length] > 0);
    XCTAssertTrue(result.success);
}

- (void)assertScopesReturned:(NSArray *)expectedScopes
{
    MSIDAutomationSuccessResult *result = [self automationSuccessResult];
    NSOrderedSet *resultScopes = [NSOrderedSet msidOrderedSetFromString:result.target normalize:YES];

    for (NSString *expectedScope in expectedScopes)
    {
        XCTAssertTrue([resultScopes containsObject:expectedScope.lowercaseString]);
    }
}

- (void)assertAuthorityReturned:(NSString *)expectedAuthority
{
    if (!expectedAuthority) return;

    MSIDAutomationSuccessResult *result = [self automationSuccessResult];
    NSString *resultAuthority = result.authority;
    
    XCTAssertEqualObjects(expectedAuthority, resultAuthority);
}

- (NSDictionary *)resultIDTokenClaims
{
    MSIDAutomationSuccessResult *result = [self automationSuccessResult];

    NSString *idToken = result.idToken;
    XCTAssertTrue([idToken length] > 0);

    MSIDIdTokenClaims *idTokenClaims = [MSIDAADIdTokenClaimsFactory claimsFromRawIdToken:idToken error:nil];
    return [idTokenClaims jsonDictionary];
}

#pragma mark - API fetch

- (void)loadTestConfiguration:(MSIDAutomationConfigurationRequest *)request
{
    __block MSIDTestAutomationConfiguration *testConfig = nil;

    XCTestExpectation *expectation = [self expectationWithDescription:@"Get configuration"];
    
    [self.class.confProvider.userAPIRequestHandler executeAPIRequest:request
                                                   completionHandler:^(MSIDTestAutomationConfiguration *result, NSError *error) {

                                                       XCTAssertNil(error);
                                                       testConfig = result;
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
    
    [self.class.confProvider.passwordRequestHandler loadPasswordForAccount:account
                                                         completionHandler:^(NSString *password, NSError *error) {
        
                                                             XCTAssertNil(error);
                                                             XCTAssertNotNil(password);
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
    XCUIElement *emailTextField = [app.textFields elementBoundByIndex:0];
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
    XCUIElement *passwordTextField = app.secureTextFields.firstMatch;
    [self waitForElement:passwordTextField];
    [self tapElementAndWaitForKeyboardToAppear:passwordTextField app:app];
    [passwordTextField typeText:password];
}

- (void)acceptMSSTSConsentIfNecessary:(NSString *)acceptButtonTitle embeddedWebView:(BOOL)embeddedWebView
{
    [self acceptConsentIfNecessary:self.testApp.buttons[acceptButtonTitle]
                     consentButton:acceptButtonTitle
                   embeddedWebView:embeddedWebView];
}

- (void)acceptSpeedBump
{
    [self acceptConsentIfNecessary:self.testApp.staticTexts[@"Only continue if you downloaded the app from a store or website that you trust."]
                     consentButton:@"Continue"
                   embeddedWebView:NO];
}

- (void)acceptConsentIfNecessary:(XCUIElement *)elementToCheck
                   consentButton:(NSString *)consentButton
                 embeddedWebView:(BOOL)embeddedWebView
{
    int i = 0;
    
    while (i < 20) {
        
        // If consent button found, tap it and return
        if (elementToCheck.exists)
        {
            XCUIElement *button = self.testApp.buttons[consentButton];
            [button msidTap];
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

- (void)closeAuthUIUsingWebViewType:(MSIDWebviewType)webViewType
                    passedInWebView:(BOOL)usesPassedInWebView
{
    NSString *buttonTitle = @"Cancel";

    CGFloat osVersion = [[[UIDevice currentDevice] systemVersion] floatValue];

    if (webViewType == MSIDWebviewTypeSafariViewController
        || (webViewType == MSIDWebviewTypeDefault && osVersion < 11.0f && !usesPassedInWebView))
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
    [self performAction:MSID_AUTO_INVALIDATE_RT_ACTION_IDENTIFIER withConfig:config];
}

- (void)expireAccessToken:(NSDictionary *)config
{
    [self performAction:MSID_AUTO_EXPIRE_AT_ACTION_IDENTIFIER withConfig:config];
}

- (void)acquireToken:(NSDictionary *)config
{
    [self performAction:MSID_AUTO_ACQUIRE_TOKEN_ACTION_IDENTIFIER withConfig:config];
}

- (void)acquireTokenSilent:(NSDictionary *)config
{
    [self performAction:MSID_AUTO_ACQUIRE_TOKEN_SILENT_ACTION_IDENTIFIER withConfig:config];
}

- (void)clearKeychain
{
    [self.testApp.buttons[MSID_AUTO_CLEAR_CACHE_ACTION_IDENTIFIER] msidTap];
    [self waitForElement:self.testApp.buttons[@"Done"]];
    [self.testApp.buttons[@"Done"] msidTap];
}

- (void)clearCookies
{
    [self.testApp.buttons[MSID_AUTO_CLEAR_COOKIES_ACTION_IDENTIFIER] msidTap];
    [self waitForElement:self.testApp.buttons[@"Done"]];
    [self.testApp.buttons[@"Done"] msidTap];
}

- (void)openURL:(NSDictionary *)config
{
    [self performAction:MSID_AUTO_OPEN_URL_ACTION_IDENTIFIER withConfig:config];
}

- (void)signout:(NSDictionary *)config
{
    [self performAction:MSID_AUTO_REMOVE_ACCOUNT_ACTION_IDENTIFIER withConfig:config];
}

- (void)readAccounts:(NSDictionary *)config
{
    [self performAction:MSID_AUTO_READ_ACCOUNTS_ACTION_IDENTIFIER withConfig:config];
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

- (MSIDAutomationErrorResult *)automationErrorResult
{
    MSIDAutomationErrorResult *result = [[MSIDAutomationErrorResult alloc] initWithJSONDictionary:[self automationResultDictionary] error:nil];
    XCTAssertNotNil(result);
    XCTAssertFalse(result.success);
    return result;
}

- (MSIDAutomationSuccessResult *)automationSuccessResult
{
    MSIDAutomationSuccessResult *result = [[MSIDAutomationSuccessResult alloc] initWithJSONDictionary:[self automationResultDictionary] error:nil];
    XCTAssertNotNil(result);
    XCTAssertTrue(result.success);
    return result;
}

- (MSIDAutomationAccountsResult *)automationAccountsResult
{
    MSIDAutomationAccountsResult *result = [[MSIDAutomationAccountsResult alloc] initWithJSONDictionary:[self automationResultDictionary] error:nil];
    XCTAssertNotNil(result);
    XCTAssertTrue(result.success);
    return result;
}

- (NSDictionary *)automationResultDictionary
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

- (NSDictionary *)configWithTestRequest:(MSIDAutomationTestRequest *)request
{
    MSIDAutomationTestRequest *updatedRequest = [self.class.confProvider fillDefaultRequestParams:request config:self.testConfiguration account:self.primaryAccount];
    return updatedRequest.jsonDictionary;
}

@end
