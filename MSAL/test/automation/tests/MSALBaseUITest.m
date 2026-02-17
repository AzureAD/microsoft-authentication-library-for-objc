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
static NSString *s_testLogFilePath = nil;

#pragma mark - Log file path helpers

static NSDictionary *_ReadEnvConfigFile(void)
{
    NSString *configPath = @"/tmp/test_logs/env_config.txt";
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:configPath encoding:NSUTF8StringEncoding error:&error];
    if (!content || error) return nil;

    NSMutableDictionary *config = [NSMutableDictionary dictionary];
    for (NSString *line in [content componentsSeparatedByString:@"\n"])
    {
        NSArray *parts = [line componentsSeparatedByString:@"="];
        if (parts.count == 2)
        {
            config[[parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]]
                = [parts[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
    }
    return config;
}

static NSString *_TestLogFilePath(void)
{
    if (!s_testLogFilePath)
    {
        NSString *buildId = [[[NSProcessInfo processInfo] environment] objectForKey:@"BUILD_BUILDID"];
        NSString *jobName = [[[NSProcessInfo processInfo] environment] objectForKey:@"AGENT_JOBNAME"];
        NSString *logDir  = [[[NSProcessInfo processInfo] environment] objectForKey:@"TEST_LOG_DIR"];

        if (!buildId || !logDir)
        {
            NSDictionary *config = _ReadEnvConfigFile();
            if (config)
            {
                buildId = config[@"BUILD_BUILDID"];
                jobName = config[@"AGENT_JOBNAME"];
                logDir  = config[@"TEST_LOG_DIR"];
            }
        }

        if (buildId && logDir)
        {
            NSString *sanitizedJobName = [jobName stringByReplacingOccurrencesOfString:@" " withString:@"_"] ?: @"default_job";
            NSString *logFileName = [NSString stringWithFormat:@"test_account_log_%@_%@.txt", buildId, sanitizedJobName];
            s_testLogFilePath = [logDir stringByAppendingPathComponent:logFileName];
        }
        else
        {
            s_testLogFilePath = @"/tmp/test_logs/msal_test_account_log.txt";
        }

        NSString *logDirectory = [s_testLogFilePath stringByDeletingLastPathComponent];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:logDirectory])
        {
            [fm createDirectoryAtPath:logDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    return s_testLogFilePath;
}

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

#pragma mark - Account logging

- (void)flushLogBlock:(NSString *)block
{
    NSString *logFilePath = _TestLogFilePath();
    if (!logFilePath) return;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *logDir = [logFilePath stringByDeletingLastPathComponent];
    if (![fm fileExistsAtPath:logDir])
    {
        [fm createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    if (![fm fileExistsAtPath:logFilePath])
    {
        [block writeToFile:logFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    else
    {
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
        if (fh)
        {
            [fh seekToEndOfFile];
            [fh writeData:[block dataUsingEncoding:NSUTF8StringEncoding]];
            [fh closeFile];
        }
    }
}

- (void)logAndFlushBlock:(NSString *)block
{
    for (NSString *line in [block componentsSeparatedByString:@"\n"])
    {
        if (line.length > 0)
        {
            NSLog(@"[TEST_ACCOUNT_INFO] %@", line);
        }
    }
    [self flushLogBlock:block];
}

- (NSString *)accountInfoString:(MSIDTestAutomationAccount *)account
                      withLabel:(NSString *)label
{
    if (!account)
    {
        return [NSString stringWithFormat:@"[%@] Account is nil - no account loaded\n", label];
    }

    return [NSString stringWithFormat:
        @"--- %@ ---\n"
        @"  UPN: %@\n"
        @"  Object ID: %@\n"
        @"  User Type: %@\n"
        @"  Domain Username: %@\n"
        @"  KeyVault Name: %@\n"
        @"  Associated App ID: %@\n"
        @"  Target Tenant ID: %@\n"
        @"  Home Tenant ID: %@\n"
        @"  Tenant Name: %@\n"
        @"  Home Tenant Name: %@\n"
        @"  Home Object ID: %@\n"
        @"  Home Account ID: %@\n"
        @"  Is Home Account: %@\n"
        @"  Has Password: %@\n"
        @"--- End %@ ---\n",
        label,
        account.upn ?: @"(nil)",
        account.objectId ?: @"(nil)",
        account.userType ?: @"(nil)",
        account.domainUsername ?: @"(nil)",
        account.keyvaultName ?: @"(nil)",
        account.associatedAppID ?: @"(nil)",
        account.targetTenantId ?: @"(nil)",
        account.homeTenantId ?: @"(nil)",
        account.tenantName ?: @"(nil)",
        account.homeTenantName ?: @"(nil)",
        account.homeObjectId ?: @"(nil)",
        account.homeAccountId ?: @"(nil)",
        account.isHomeAccount ? @"YES" : @"NO",
        account.password ? @"YES" : @"NO",
        label];
}

- (void)loadTestAccount:(MSIDTestAutomationAccountConfigurationRequest *)accountRequest
{
    [super loadTestAccount:accountRequest];

    NSMutableString *logBlock = [NSMutableString string];
    [logBlock appendString:@"=== loadTestAccount ===\n"];
    [logBlock appendString:@"  API Query Parameters:\n"];
    [logBlock appendFormat:@"    Account Type: %@\n", accountRequest.accountType ?: @"N/A"];
    [logBlock appendFormat:@"    Environment: %@\n", accountRequest.environmentType ?: @"N/A"];
    [logBlock appendFormat:@"    Protection Policy: %@\n", accountRequest.protectionPolicyType ?: @"None"];
    [logBlock appendFormat:@"    MFA Type: %@\n", accountRequest.mfaType ?: @"N/A"];
    [logBlock appendFormat:@"    Federation Provider: %@\n", accountRequest.federationProviderType ?: @"N/A"];
    [logBlock appendFormat:@"    B2C Provider: %@\n", accountRequest.b2cProviderType ?: @"N/A"];
    [logBlock appendFormat:@"    User Role: %@\n", accountRequest.userRole ?: @"N/A"];
    if (accountRequest.additionalQueryParameters.count > 0) {
        [logBlock appendFormat:@"    Additional Params: %@\n", accountRequest.additionalQueryParameters];
    }
    [logBlock appendString:[self accountInfoString:self.primaryAccount withLabel:@"Primary Account"]];

    if (self.testAccounts.count > 1)
    {
        for (NSUInteger i = 1; i < self.testAccounts.count; i++)
        {
            NSString *label = [NSString stringWithFormat:@"Additional Account %lu", (unsigned long)i];
            [logBlock appendString:[self accountInfoString:self.testAccounts[i] withLabel:label]];
        }
    }

    [self logAndFlushBlock:logBlock];
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
        sleep(10);
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
