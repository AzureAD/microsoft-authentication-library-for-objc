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
#import "MSIDKeyVaultAccountProvider.h"
#import "MSIDKeyVaultAppConfigProvider.h"
#import "MSIDKeyVaultCredentialProvider.h"

static MSIDTestConfigurationProvider *s_confProvider;
static MSIDKeyVaultAccountProvider *s_keyVaultAccountProvider;
static MSIDKeyVaultAppConfigProvider *s_keyVaultAppConfigProvider;

@implementation MSALBaseUITest

+ (void)setUp
{
    [super setUp];
        
    NSString *confPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"conf" ofType:@"json"];
    self.class.confProvider = [[MSIDTestConfigurationProvider alloc] initWithConfigurationPath:confPath testsConfig:self.testsConfig];
    
    // Initialize Key Vault account provider if configured
    [self initializeKeyVaultAccountProviderWithConfigPath:confPath];

    // Initialize Key Vault app config provider if configured
    [self initializeKeyVaultAppConfigProviderWithConfigPath:confPath];
}

+ (void)initializeKeyVaultAccountProviderWithConfigPath:(NSString *)confPath
{
    // Read config to get Key Vault accounts URL
    NSData *configData = [NSData dataWithContentsOfFile:confPath];
    if (!configData) {
        NSLog(@"[MSALBaseUITest] Could not read config file for Key Vault setup");
        return;
    }
    
    NSError *jsonError = nil;
    NSDictionary *config = [NSJSONSerialization JSONObjectWithData:configData options:0 error:&jsonError];
    if (!config) {
        if (jsonError) {
            NSLog(@"[MSALBaseUITest] Could not parse config JSON: %@", jsonError.localizedDescription);
        }
        else {
            NSLog(@"[MSALBaseUITest] Could not parse config JSON");
        }
        return;
    }
    
    // Get Key Vault accounts URL
    NSString *keyVaultAccountsURL = config[@"keyvault_accounts_url"];
    
    if (!keyVaultAccountsURL || keyVaultAccountsURL.length == 0) {
        NSLog(@"[MSALBaseUITest] No keyvault_accounts_url configured, using Lab API only");
        return;
    }
    
    NSLog(@"[MSALBaseUITest] Initializing Key Vault account provider with URL: %@", keyVaultAccountsURL);
    
    // Get certificate credentials from root config (used as fallback after Pipeline Cert and Azure CLI)
    NSString *certData = config[@"certificate_data"];
    NSString *certPassword = config[@"certificate_password"];
    
    // Create credential provider
    // Credential chain: Pipeline Cert (env vars) → Azure CLI → Config Cert (fallback)
    MSIDKeyVaultCredentialProvider *credentialProvider = [[MSIDKeyVaultCredentialProvider alloc] initWithCertificateContents:certData
                                                                                                         certificatePassword:certPassword];
    
    // Create account provider
    s_keyVaultAccountProvider = [[MSIDKeyVaultAccountProvider alloc] initWithKeyVaultURL:keyVaultAccountsURL
                                                                      credentialProvider:credentialProvider];
    
    // Fetch accounts synchronously during setup
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSError *fetchError = nil;
    
    [s_keyVaultAccountProvider fetchAccountsWithCompletionHandler:^(NSError * _Nullable error) {
        fetchError = error;
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Wait up to 30 seconds for accounts to load
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC);
    if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
        NSLog(@"[MSALBaseUITest] Timeout loading Key Vault accounts, will use Lab API");
        s_keyVaultAccountProvider = nil;
        return;
    }
    
    if (fetchError) {
        NSLog(@"[MSALBaseUITest] Failed to load Key Vault accounts: %@. Will use Lab API.", fetchError.localizedDescription);
        s_keyVaultAccountProvider = nil;
        return;
    }
    
    NSLog(@"[MSALBaseUITest] Key Vault accounts loaded successfully");
    
    // Set on the base class so MSIDBaseUITest can use it
    self.class.keyVaultAccountProvider = s_keyVaultAccountProvider;
}

+ (void)initializeKeyVaultAppConfigProviderWithConfigPath:(NSString *)confPath
{
    // Read config to get Key Vault app configs URL
    NSData *configData = [NSData dataWithContentsOfFile:confPath];
    if (!configData) {
        NSLog(@"[MSALBaseUITest] Could not read config file for Key Vault app config setup");
        return;
    }

    NSError *jsonError = nil;
    NSDictionary *config = [NSJSONSerialization JSONObjectWithData:configData options:0 error:&jsonError];
    if (!config) {
        if (jsonError) {
            NSLog(@"[MSALBaseUITest] Could not parse config JSON: %@", jsonError.localizedDescription);
        }
        else {
            NSLog(@"[MSALBaseUITest] Could not parse config JSON");
        }
        return;
    }

    // Get Key Vault app configs URL
    NSString *keyVaultAppConfigsURL = config[@"keyvault_app_configs_url"];

    if (!keyVaultAppConfigsURL || keyVaultAppConfigsURL.length == 0) {
        NSLog(@"[MSALBaseUITest] No keyvault_app_configs_url configured, using Lab API only");
        return;
    }

    NSLog(@"[MSALBaseUITest] Initializing Key Vault app config provider with URL: %@", keyVaultAppConfigsURL);

    // Get certificate credentials from root config (used as fallback after Pipeline Cert and Azure CLI)
    NSString *certData = config[@"certificate_data"];
    NSString *certPassword = config[@"certificate_password"];

    // Create credential provider
    // Credential chain: Pipeline Cert (env vars) → Azure CLI → Config Cert (fallback)
    MSIDKeyVaultCredentialProvider *credentialProvider = [[MSIDKeyVaultCredentialProvider alloc] initWithCertificateContents:certData
                                                                                                         certificatePassword:certPassword];

    // Create app config provider
    s_keyVaultAppConfigProvider = [[MSIDKeyVaultAppConfigProvider alloc] initWithKeyVaultURL:keyVaultAppConfigsURL
                                                                          credentialProvider:credentialProvider];

    // Fetch app configs synchronously during setup
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSError *fetchError = nil;

    [s_keyVaultAppConfigProvider fetchAppConfigsWithCompletionHandler:^(NSError * _Nullable error) {
        fetchError = error;
        dispatch_semaphore_signal(semaphore);
    }];

    // Wait up to 30 seconds for app configs to load
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC);
    if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
        NSLog(@"[MSALBaseUITest] Timeout loading Key Vault app configs, will use Lab API");
        s_keyVaultAppConfigProvider = nil;
        return;
    }

    if (fetchError) {
        NSLog(@"[MSALBaseUITest] Failed to load Key Vault app configs: %@. Will use Lab API.", fetchError.localizedDescription);
        s_keyVaultAppConfigProvider = nil;
        return;
    }

    NSLog(@"[MSALBaseUITest] Key Vault app configs loaded successfully");

    // Set on the base class so MSIDBaseUITest can use it
    self.class.keyVaultAppConfigProvider = s_keyVaultAppConfigProvider;
}

- (void)setUp
{
    [super setUp];
    
    self.continueAfterFailure = NO;
    self.redirectUriPrefix = @"x-msauth-msalautomationapp";
    
    self.testApp = [XCUIApplication new];
    self.testApp.launchArguments = @[@"Clear cache", @"Clear cookies"]; // Clean on 1st launch
    [self.testApp launch];
    self.testApp.launchArguments = @[]; // Clear arguments in case we launch the same app a 2nd time.
    
    [self cleanPipelines];
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
    else
    {
        XCUIElement *registerButton = self.testApp.buttons[@"Allow"];
        XCUIElement *result = [self waitForEitherElements:registerButton and:webElement];
        [result msidTap];
    }
    
    BOOL result = [webElement waitForExistenceWithTimeout:15.0];
    
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
        sleep(1);
        // Check if title exists
        if (elementToCheck.exists)
        {
            // The MSA "Verify your email" interstitial auto-focuses the email
            // text field, raising the iOS keyboard. The keyboard covers the
            // lower part of the page including the in-page consent button
            // ("Use your password" / "Use your password instead"). The button
            // matches via self.testApp.buttons[…] but synthesized taps on it
            // land on the keyboard's hit area and get absorbed, so the page
            // never progresses and the next test step times out.
            //
            // Dismiss the keyboard by tapping the "Verify your email" header
            // — a static text in the webview, tapping it is a no-op for the
            // page but defocuses the email field and dismisses the keyboard.
            // This is more reliable than chasing the keyboard's "Done"
            // accessory button, which lives under different parent element
            // types across iOS versions and surface owners (SafariVC vs
            // WKWebView). After the tap we poll briefly for the keyboard to
            // actually collapse, otherwise the consent-button tap below can
            // land on the still-collapsing keyboard's hit area.
            XCUIElement *keyboard = self.testApp.keyboards.firstMatch;
            if (keyboard.exists)
            {
                XCUIElement *header = self.testApp.webViews.staticTexts[@"Verify your email"];
                if (header.exists)
                {
                    [header msidTap];

                    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
                    while (keyboard.exists && deadline.timeIntervalSinceNow > 0)
                    {
                        [NSThread sleepForTimeInterval:0.1];
                    }
                }
            }

            XCUIElement *button = self.testApp.buttons[consentButton];
            // If consent button found, tap it and return
            if (button.exists)
            {
                [button msidTap];
                return;
            }
            else
            {
                // The title is there, but consent button not found. Return and continue.
                // Depending on the test, will try with another consent button.
                return;
            }
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
    } 
    else
    {
        if (webViewType == MSIDWebviewTypeSafariViewController)
        {
            // We take the first one and force tap it, for some reason tap doesn't work
            XCUIElement *firstButton = [elementQuery elementBoundByIndex:0];
            
            __auto_type coordinate = [firstButton coordinateWithNormalizedOffset:CGVectorMake(1, 1)];
            [coordinate tap];
        }
        else
        {
            [self.testApp.buttons[buttonTitle] msidTap];
        }
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
