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
    
    [self cleanPipelines];
    [self clearCache:self.testApp];
    [self clearCookies:self.testApp];
}

- (void)tearDown
{
    [self.testApp terminate];
    [super tearDown];
}

#pragma mark - Asserts

- (void)assertRefreshTokenInvalidated
{
    MSIDAutomationSuccessResult *result = [self automationSuccessResult:self.testApp];
    XCTAssertTrue(result.success);
}

- (void)assertAccessTokenExpired
{
    MSIDAutomationSuccessResult *result = [self automationSuccessResult:self.testApp];
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
    MSIDAutomationErrorResult *result = [self automationErrorResult:self.testApp];
    XCTAssertEqual(expectedErrorCode, result.errorCode);
}

- (void)assertInternalErrorCode:(NSInteger)internalErrorCode
{
    MSIDAutomationErrorResult *result = [self automationErrorResult:self.testApp];
    XCTAssertEqual(internalErrorCode, [result.errorUserInfo[MSALInternalErrorCodeKey] integerValue]);
}

- (void)assertErrorDescription:(NSString *)errorDescription
{
    MSIDAutomationErrorResult *result = [self automationErrorResult:self.testApp];
    NSString *actualContent = result.errorDescription;
    XCTAssertNotEqual([actualContent length], 0);
    XCTAssertTrue([actualContent containsString:errorDescription]);
}

- (void)assertErrorSubcode:(NSString *)errorSubcode
{
    MSIDAutomationErrorResult *result = [self automationErrorResult:self.testApp];
    NSString *actualSubCode = result.errorUserInfo[@"MSALOAuthSubErrorKey"];
    XCTAssertEqualObjects(errorSubcode, actualSubCode);
}

- (void)assertScopesReturned:(NSArray *)expectedScopes
{
    MSIDAutomationSuccessResult *result = [self automationSuccessResult:self.testApp];
    NSOrderedSet *resultScopes = [NSOrderedSet msidOrderedSetFromString:result.target normalize:YES];

    for (NSString *expectedScope in expectedScopes)
    {
        XCTAssertTrue([resultScopes containsObject:expectedScope.lowercaseString]);
    }
}

- (void)assertAuthorityReturned:(NSString *)expectedAuthority
{
    if (!expectedAuthority) return;

    MSIDAutomationSuccessResult *result = [self automationSuccessResult:self.testApp];
    NSString *resultAuthority = result.authority;
    
    XCTAssertEqualObjects(expectedAuthority, resultAuthority);
}

#pragma mark - Actions

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

- (void)invalidateRefreshToken:(NSDictionary *)config
{
    [self performAction:MSID_AUTO_INVALIDATE_RT_ACTION_IDENTIFIER config:config application:self.testApp];
}

- (void)expireAccessToken:(NSDictionary *)config
{
    [self performAction:MSID_AUTO_EXPIRE_AT_ACTION_IDENTIFIER config:config application:self.testApp];
}

- (void)acquireToken:(NSDictionary *)config
{
    [self performAction:MSID_AUTO_ACQUIRE_TOKEN_ACTION_IDENTIFIER config:config application:self.testApp];
}

- (void)acquireTokenSilent:(NSDictionary *)config
{
    [self performAction:MSID_AUTO_ACQUIRE_TOKEN_SILENT_ACTION_IDENTIFIER config:config application:self.testApp];
}

- (void)openURL:(NSDictionary *)config
{
    [self performAction:MSID_AUTO_OPEN_URL_ACTION_IDENTIFIER config:config application:self.testApp];
}

- (void)signout:(NSDictionary *)config
{
    [self performAction:MSID_AUTO_REMOVE_ACCOUNT_ACTION_IDENTIFIER config:config application:self.testApp];
}

- (void)readAccounts:(NSDictionary *)config
{
    [self performAction:MSID_AUTO_READ_ACCOUNTS_ACTION_IDENTIFIER config:config application:self.testApp];
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
