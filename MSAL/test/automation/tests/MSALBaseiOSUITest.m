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

#import "MSALBaseiOSUITest.h"
#import "XCTestCase+TextFieldTap.h"

@implementation MSALBaseiOSUITest

#pragma mark - Broker

- (XCUIApplication *)brokerApp
{
    NSDictionary *appConfiguration = [self.class.confProvider appInstallForConfiguration:@"broker"];
    NSString *appBundleId = appConfiguration[@"app_bundle_id"];

    XCUIApplication *brokerApp = [[XCUIApplication alloc] initWithBundleIdentifier:appBundleId];
    BOOL result = [brokerApp waitForState:XCUIApplicationStateRunningForeground timeout:30.0f];
    XCTAssertTrue(result);

    if ([brokerApp.alerts.buttons[@"Ok"] exists])
    {
        [brokerApp.alerts.buttons[@"Ok"] tap];
    }

    return brokerApp;
}

- (void)registerDeviceInAuthenticator
{
    __auto_type brokerApp = [self openDeviceRegistrationMenuInAuthenticator];

    __auto_type emailTextField = brokerApp.tables.textFields[@"Organization email"];
    [self waitForElement:emailTextField];
    [self tapElementAndWaitForKeyboardToAppear:emailTextField app:brokerApp];
    [emailTextField typeText:[NSString stringWithFormat:@"%@\n", self.primaryAccount.account]];

    __auto_type registerButton = brokerApp.tables.buttons[@"Register device"];
    [registerButton tap];

    NSString *password = [NSString stringWithFormat:@"%@\n", self.primaryAccount.password];

    [self adfsEnterPassword:password app:brokerApp];
}

- (void)unregisterDeviceInAuthenticator
{
    __auto_type brokerApp = [self openDeviceRegistrationMenuInAuthenticator];
    __auto_type unregisterButton = brokerApp.tables.buttons[@"Unregister device"];
    [self waitForElement:unregisterButton];
    [unregisterButton tap];

    [brokerApp.alerts.buttons[@"Continue"] tap];

    __auto_type registerButton = brokerApp.tables.buttons[@"Register device"];
    [self waitForElement:registerButton];
}

- (XCUIApplication *)openDeviceRegistrationMenuInAuthenticator
{
    NSDictionary *appConfiguration = [self.class.confProvider appInstallForConfiguration:@"broker"];
    NSString *appBundleId = appConfiguration[@"app_bundle_id"];
    XCUIApplication *brokerApp = [[XCUIApplication alloc] initWithBundleIdentifier:appBundleId];
    [brokerApp terminate];
    [brokerApp activate];

    if ([brokerApp.buttons[@"Skip"] exists])
    {
        [brokerApp.buttons[@"Skip"] tap];
    }

    [brokerApp.navigationBars[@"Accounts"].buttons[@"Menu"] tap];

    __auto_type settingsMenuItem = brokerApp.tables.staticTexts[@"Settings"];
    [self waitForElement:settingsMenuItem];
    [settingsMenuItem tap];

    __auto_type deviceRegistrationMenu = brokerApp.tables.staticTexts[@"Device Registration"];

    if (deviceRegistrationMenu.exists)
    {
        [deviceRegistrationMenu tap];
    }

    return brokerApp;
}

#pragma mark - Multi app

- (void)openAppInstallURLForAppId:(NSString *)appId
{
    XCTAssertNotNil(appId);

    NSDictionary *appConfiguration = [self.class.confProvider appInstallForConfiguration:appId];
    XCTAssertNotNil(appConfiguration);

    NSString *appInstallUrl = appConfiguration[@"install_url"];

    MSIDAutomationTestRequest *request = [MSIDAutomationTestRequest new];
    request.extraQueryParameters = @{@"url": appInstallUrl};
    [self openURL:request.jsonDictionary];

    XCUIApplication *safariApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.mobilesafari"];

    XCTAssertTrue([safariApp waitForState:XCUIApplicationStateRunningForeground timeout:30]);
    [safariApp tap];
}

- (XCUIApplication *)openAppWithAppId:(NSString *)appId
{
    NSDictionary *appConfiguration = [self.class.confProvider appInstallForConfiguration:appId];
    NSString *appBundleId = appConfiguration[@"app_bundle_id"];

    XCUIApplication *otherApp = [[XCUIApplication alloc] initWithBundleIdentifier:appBundleId];
    [otherApp activate];
    BOOL result = [otherApp waitForState:XCUIApplicationStateRunningForeground timeout:30.0f];
    XCTAssertTrue(result);
    return otherApp;
}

- (void)acceptNotificationsSystemDialog
{
    XCUIApplication *springBoardApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.springboard"];
    __auto_type allowButton = [springBoardApp.alerts.buttons elementBoundByIndex:0];
    [self waitForElement:allowButton];
    [allowButton tap];
}

- (void)acceptAuthSessionDialogIfNecessary:(MSIDAutomationTestRequest *)request
{
    if (request.webViewType == MSALWebviewTypeDefault
        && !request.usesEmbeddedWebView)
    {
        [self acceptAuthSessionDialog];
    }
}

- (void)acceptAuthSessionDialog
{
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 11.0f)
    {
        XCUIApplication *springBoardApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.springboard"];
        __auto_type allowButton = springBoardApp.alerts.buttons[@"Continue"];
        [self waitForElement:allowButton];
        sleep(1);
        [allowButton tap];
    }
}

- (void)waitForRedirectToTheTestApp
{
    BOOL result = [self.testApp waitForState:XCUIApplicationStateRunningForeground timeout:30.0f];
    XCTAssertTrue(result);
}

- (XCUIApplication *)installAppWithId:(NSString *)appId
{
    /* Because for certain tests we want to install app after running some preliminary operations,
     we split the operation into 2 parts: opening the install URL in Safari and actually installing the app */
    [self openAppInstallURLForAppId:appId];
    return [self installAppWithIdWithSafariOpen:appId];
}

- (XCUIApplication *)installAppWithIdWithSafariOpen:(NSString *)appId
{
    XCUIApplication *safariApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.mobilesafari"];
    [safariApp activate];

    XCTAssertTrue([safariApp waitForState:XCUIApplicationStateRunningForeground timeout:30]);
    [safariApp tap];
    __auto_type installButton = safariApp.links[@"Install"];
    [self waitForElement:installButton];
    [installButton tap];

    sleep(1);

    XCUIApplication *springBoardApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.springboard"];
    [springBoardApp.alerts.buttons[@"Install"] tap];

    [springBoardApp activate];
    BOOL result = [springBoardApp waitForState:XCUIApplicationStateRunningForeground timeout:30];
    XCTAssertTrue(result);

    sleep(3);

    NSDictionary *appConfiguration = [self.class.confProvider appInstallForConfiguration:appId];
    NSString *appName = appConfiguration[@"app_name"];

    __auto_type appIcon = springBoardApp.icons[appName];
    [self waitForElement:appIcon];
    [appIcon tap];

    NSString *appBundleId = appConfiguration[@"app_bundle_id"];

    XCUIApplication *installedApp = [[XCUIApplication alloc] initWithBundleIdentifier:appBundleId];
    // Give app enough time to install
    result = [installedApp waitForState:XCUIApplicationStateRunningForeground timeout:60];
    XCTAssertTrue(result);

    return installedApp;
}

- (void)removeAppWithId:(NSString *)appId
{
    XCTAssertNotNil(appId);

    NSDictionary *appConfiguration = [self.class.confProvider appInstallForConfiguration:appId];
    XCTAssertNotNil(appConfiguration);

    XCUIApplication *springBoardApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.springboard"];
    [springBoardApp activate];
    BOOL result = [springBoardApp waitForState:XCUIApplicationStateRunningForeground timeout:30];
    XCTAssertTrue(result);

    NSString *appName = appConfiguration[@"app_name"];

    __auto_type appIcon = springBoardApp.icons[appName];

    if (appIcon.exists)
    {
        [appIcon pressForDuration:1.0f];

        XCUIElement *deleteButton = nil;

        if ([[[UIDevice currentDevice] systemVersion] floatValue] < 10.0f)
        {
            deleteButton = springBoardApp.otherElements[appName].buttons[@"DeleteButton"];
        }
        else
        {
            deleteButton = appIcon.buttons[@"DeleteButton"];
        }
        [self waitForElement:deleteButton];
        [deleteButton forceTap];

        __auto_type deleteConfirmationButton = springBoardApp.alerts.buttons[@"Delete"];
        [self waitForElement:deleteConfirmationButton];
        [deleteConfirmationButton tap];

        NSPredicate *appDeletedPredicate = [NSPredicate predicateWithFormat:@"exists == 0"];
        [self expectationForPredicate:appDeletedPredicate evaluatedWithObject:appIcon handler:nil];
        [self waitForExpectationsWithTimeout:30 handler:nil];

        [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
    }
}

@end
