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
#import "MSIDTestConfigurationProvider.h"
#import "XCTestCase+TextFieldTap.h"
#import "NSDictionary+MSALiOSUITests.h"
#import "MSIDAADV1IdTokenClaims.h"
#import "XCUIElement+CrossPlat.h"
#import "MSIDAADIdTokenClaimsFactory.h"
#import "MSIDAutomationActionConstants.h"
#import "MSIDTestConfigurationProvider.h"
#import "MSIDTestAutomationAppConfigurationRequest.h"
#import "MSIDTestAutomationApplication.h"
#import "MSIDAutomationOperationResponseHandler.h"

static MSIDTestConfigurationProvider *s_confProvider;

@implementation MSALBaseUITest

+ (void)setUp
{
    [super setUp];
        
    NSString *confPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"conf" ofType:@"json"];
    self.class.confProvider = [[MSIDTestConfigurationProvider alloc] initWithConfigurationPath:confPath testsConfig:self.testsConfig];
}

- (void)setUp
{
    [super setUp];
    
    self.continueAfterFailure = NO;
    self.redirectUriPrefix = @"x-msauth-msalautomationapp";
    
    self.testApp = [XCUIApplication new];
    [self.testApp launch];

    [self clearKeychain];
    [self closeResultView];
    
    [self clearCookies];
    [self closeResultView];
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

- (void)loadTestApp:(MSIDTestAutomationAppConfigurationRequest *)appRequest
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Get configuration"];
    
    MSIDAutomationOperationResponseHandler *responseHandler = [[MSIDAutomationOperationResponseHandler alloc] initWithClass:MSIDTestAutomationApplication.class];
    
    [self.class.confProvider.operationAPIRequestHandler executeAPIRequest:appRequest
                                                          responseHandler:responseHandler
                                                        completionHandler:^(id result, __unused NSError *error)
    {
        XCTAssertNotNil(result);
        XCTAssertTrue([result isKindOfClass:[NSArray class]]);
        
        NSArray *results = (NSArray *)result;
        XCTAssertTrue(results.count >= 1);
        self.testApplication = results[0];
        self.testApplication.redirectUriPrefix = self.redirectUriPrefix;
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)loadTestAccount:(MSIDTestAutomationAccountConfigurationRequest *)accountRequest
{
    NSArray *accounts = [self loadTestAccountRequest:accountRequest];
    self.primaryAccount = accounts[0];
    self.testAccounts = accounts;
}

- (NSArray *)loadTestAccountRequest:(MSIDTestAutomationAccountConfigurationRequest *)accountRequest
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Get account"];
    
    MSIDAutomationOperationResponseHandler *responseHandler = [[MSIDAutomationOperationResponseHandler alloc] initWithClass:MSIDTestAutomationAccount.class];
    
    __block NSArray *results = nil;
    
    [self.class.confProvider.operationAPIRequestHandler executeAPIRequest:accountRequest
                                                          responseHandler:responseHandler
                                                        completionHandler:^(id result, __unused NSError *error)
    {
        XCTAssertNotNil(result);
        XCTAssertTrue([result isKindOfClass:[NSArray class]]);
        
        results = (NSArray *)result;
        XCTAssertTrue(results.count >= 1);
        
        XCTestExpectation *passwordLoadExpecation = [self expectationWithDescription:@"Get password"];
        passwordLoadExpecation.expectedFulfillmentCount = results.count;
        
        for (MSIDTestAutomationAccount *account in results)
        {
            [self.class.confProvider.passwordRequestHandler loadPasswordForTestAccount:account
                                                                     completionHandler:^(NSString *password, __unused NSError *error)
            {
                XCTAssertNotNil(password);
                [passwordLoadExpecation fulfill];
            }];
        }
        
        [self waitForExpectations:@[passwordLoadExpecation] timeout:60];
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:120];
    return results;
}

- (void)loadTestAccounts:(NSArray<MSIDTestAutomationAccountConfigurationRequest *> *)accountRequests
{
    NSMutableArray *allAccounts = [NSMutableArray new];
    
    for (MSIDTestAutomationAccountConfigurationRequest *request in accountRequests)
    {
        NSArray *accounts = [self loadTestAccountRequest:request];
        if (accounts)
        {
            [allAccounts addObjectsFromArray:accounts];
        }
    }
    
    XCTAssertTrue(allAccounts.count >= 1);
    
    self.primaryAccount = allAccounts[0];
    self.testAccounts = allAccounts;
}

#pragma mark - Actions

- (void)aadEnterEmail
{
    [self aadEnterEmail:[NSString stringWithFormat:@"%@\n", self.primaryAccount.upn] app:self.testApp];
}

- (void)aadEnterEmail:(NSString *)email app:(XCUIApplication *)app
{
    XCUIElement *emailTextField = [app.textFields elementBoundByIndex:0];
    [self waitForElement:emailTextField];
    if ([email isEqualToString:emailTextField.value])
    {
        return;
    }

    [emailTextField msidTap];
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
    sleep(0.1f);
    [passwordTextField msidTap];
    sleep(0.1f);
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

    XCUIElementQuery *elementQuery = [self.testApp.buttons matchingIdentifier:buttonTitle];
    if(elementQuery.count > 1)
    {
        // We take the second one and tap it
        XCUIElement *secondButton = [elementQuery elementBoundByIndex:1];
        [secondButton msidTap];
    } else
    {
        [self.testApp.buttons[buttonTitle] msidTap];
    }
}

- (void)closeResultView
{
    // TODO:
    NSString *simulatorSharedDir = [NSProcessInfo processInfo].environment[@"SIMULATOR_SHARED_RESOURCES_DIRECTORY"];
    NSURL *simulatorHomeDirUrl = [[NSURL alloc] initFileURLWithPath:simulatorSharedDir];
    NSURL *cachesDirUrl = [simulatorHomeDirUrl URLByAppendingPathComponent:@"Library/Caches"];
    NSURL *fileUrl = [cachesDirUrl URLByAppendingPathComponent:@"ui_atomation_result_pipeline.txt"];
    
    if (![NSFileManager.defaultManager fileExistsAtPath:fileUrl.path]) return;
    
    // Delete file.
    NSError *error;
    BOOL fileRemoved = [NSFileManager.defaultManager removeItemAtPath:fileUrl.path error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(fileRemoved);
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
}

- (void)clearCookies
{
    [self.testApp.buttons[MSID_AUTO_CLEAR_COOKIES_ACTION_IDENTIFIER] msidTap];
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
    NSString *simulatorSharedDir = [NSProcessInfo processInfo].environment[@"SIMULATOR_SHARED_RESOURCES_DIRECTORY"];
    NSURL *simulatorHomeDirUrl = [[NSURL alloc] initFileURLWithPath:simulatorSharedDir];
    NSURL *cachesDirUrl = [simulatorHomeDirUrl URLByAppendingPathComponent:@"Library/Caches"];
    NSURL *fileUrl = [cachesDirUrl URLByAppendingPathComponent:@"ui_atomation_request_pipeline.txt"];

    NSString *jsonString = [config toJsonString];
    
    [jsonString writeToFile:fileUrl.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    sleep(1);
    
    [self.testApp.buttons[action] msidTap];
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
    NSString *simulatorSharedDir = [NSProcessInfo processInfo].environment[@"SIMULATOR_SHARED_RESOURCES_DIRECTORY"];
    NSURL *simulatorHomeDirUrl = [[NSURL alloc] initFileURLWithPath:simulatorSharedDir];
    NSURL *cachesDirUrl = [simulatorHomeDirUrl URLByAppendingPathComponent:@"Library/Caches"];
    NSURL *fileUrl = [cachesDirUrl URLByAppendingPathComponent:@"ui_atomation_result_pipeline.txt"];
    
    int timeout = 1000;
    __auto_type resultPipelineExpectation = [[XCTestExpectation alloc] initWithDescription:@"Wait for result pipeline."];
    
    // Wait till file appears.
    int i = 0;
    while (i < timeout)
    {
        if ([NSFileManager.defaultManager fileExistsAtPath:fileUrl.path])
        {
            [resultPipelineExpectation fulfill];
            break;
        }
        
        sleep(1);
        i++;
    }
    
    [self waitForExpectations:@[resultPipelineExpectation] timeout:timeout];

    // Read json from file.
    NSString *jsonString = [NSString stringWithContentsOfFile:fileUrl.path encoding:NSUTF8StringEncoding error:nil];

    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
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
    MSIDAutomationTestRequest *updatedRequest = [self.class.confProvider fillDefaultRequestParams:request appConfig:self.testApplication];
    return updatedRequest.jsonDictionary;
}

+ (MSIDTestsConfig *)testsConfig
{
    __auto_type config = [MSIDTestsConfig new];
    config.scopesSupported = YES;
    config.tenantSpecificResultAuthoritySupported = YES;
    
    return config;
}

@end
