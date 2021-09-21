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

#import "MSALTestAppAcquireTokenViewController.h"
#import "MSALTestAppSettings.h"
#import "MSALTestAppAcquireLayoutBuilder.h"
#import "MSALTestAppAuthorityViewController.h"
#import "MSALTestAppUserViewController.h"
#import "MSALTestAppScopesViewController.h"
#import "MSALTestAppTelemetryViewController.h"
#import "MSALStressTestHelper.h"
#import "MSALPublicClientApplication+Internal.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import <WebKit/WebKit.h>
#import "MSALTestAppAuthorityTypeViewController.h"
#import "MSALTestAppProfileViewController.h"
#import "MSALResult.h"
#import "MSALDefinitions.h"
#import "MSALInteractiveTokenParameters.h"
#import "MSALSilentTokenParameters.h"
#import "MSALAuthority.h"
#import <MSAL/MSAL.h>
#import "MSALHTTPConfig.h"
#import "MSALWebviewParameters.h"
#import "MSALAuthenticationSchemePop.h"
#import "MSALAuthenticationSchemeBearer.h"
#import "MSIDAssymetricKeyKeychainGenerator.h"
#import "MSIDAssymetricKeyLookupAttributes.h"
#import "MSIDConstants.h"

#define TEST_EMBEDDED_WEBVIEW_TYPE_INDEX 0
#define TEST_SYSTEM_WEBVIEW_TYPE_INDEX 1
#define TEST_EMBEDDED_WEBVIEW_MSAL 0
#define TEST_EMBEDDED_WEBVIEW_CUSTOM 1

@interface MSALTestAppAcquireTokenViewController () <UITextFieldDelegate>

@property (nonatomic) IBOutlet UIButton *profileButton;
@property (nonatomic) IBOutlet UIButton *authorityButton;
@property (nonatomic) IBOutlet UISegmentedControl *validateAuthoritySegmentControl;
@property (nonatomic) IBOutlet UISegmentedControl *instanceAwareSegmentControl;
@property (nonatomic) IBOutlet UITextField *loginHintTextField;
@property (nonatomic) IBOutlet UITextField *extraQueryParamsTextField;
@property (nonatomic) IBOutlet UIButton *userButton;
@property (nonatomic) IBOutlet UIButton *scopesButton;
@property (nonatomic) IBOutlet UIButton *acquireSilentButton;
@property (nonatomic) IBOutlet UISegmentedControl *promptTypeSegmentControl;
@property (nonatomic) IBOutlet UISegmentedControl *webviewTypeSegmentControl;
@property (nonatomic) IBOutlet UISegmentedControl *customWebviewTypeSegmentControl;
@property (nonatomic) IBOutlet UISegmentedControl *systemWebviewSSOSegmentControl;
@property (nonatomic) IBOutlet UITextView *resultTextView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *acquireButtonsViewBottomConstraint;
@property (nonatomic) IBOutlet UIView *customWebviewContainer;
@property (nonatomic) IBOutlet UIView *wkWebViewContainer;
@property (nonatomic) WKWebView *customWebview;
@property (weak, nonatomic) IBOutlet UISegmentedControl *authSchemeSegmentControl;
@property (nonatomic) NSString *accountIdentifier;
@end

@implementation MSALTestAppAcquireTokenViewController

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self)
    {
        UITabBarItem *tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Acquire" image:nil tag:0];
        [self setTabBarItem:tabBarItem];
        
        [self setEdgesForExtendedLayout:UIRectEdgeTop];
        
        [[MSALTestAppTelemetryViewController sharedController] startTracking];
    }
    return self;
}

- (void)dealloc
{
    [[MSALTestAppTelemetryViewController sharedController] stopTracking];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    WKWebViewConfiguration *defaultWKWebConfig = [MSALWebviewParameters defaultWKWebviewConfiguration];
    self.customWebview = [[WKWebView alloc] initWithFrame:self.wkWebViewContainer.frame configuration:defaultWKWebConfig];

    [self.wkWebViewContainer addSubview:self.customWebview];
    self.customWebview.translatesAutoresizingMaskIntoConstraints = NO;
    [self.customWebview.leftAnchor constraintEqualToAnchor:self.wkWebViewContainer.leftAnchor].active = YES;
    [self.customWebview.rightAnchor constraintEqualToAnchor:self.wkWebViewContainer.rightAnchor].active = YES;
    [self.customWebview.topAnchor constraintEqualToAnchor:self.wkWebViewContainer.topAnchor].active = YES;
    [self.customWebview.bottomAnchor constraintEqualToAnchor:self.wkWebViewContainer.bottomAnchor].active = YES;
    self.customWebviewContainer.hidden = YES;
    [self.view bringSubviewToFront:self.customWebviewContainer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onKeyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onKeyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    NSString *loginHint = settings.loginHint;
    if (![NSString msidIsStringNilOrBlank:loginHint])
    {
        self.loginHintTextField.text = loginHint;
    }
    
    self.navigationController.navigationBarHidden = YES;
    self.validateAuthoritySegmentControl.selectedSegmentIndex = settings.validateAuthority ? 0 : 1;
    self.instanceAwareSegmentControl.selectedSegmentIndex = 1; // NO.
    
    [_profileButton setTitle:[MSALTestAppProfileViewController currentTitle]
                    forState:UIControlStateNormal];
    [_authorityButton setTitle:[MSALTestAppAuthorityViewController currentTitle]
                      forState:UIControlStateNormal];
    [_userButton setTitle:[MSALTestAppUserViewController currentTitle]
                 forState:UIControlStateNormal];

    [_scopesButton setTitle:(settings.scopes.count == 0) ? @"select scopes" : [settings.scopes.allObjects componentsJoinedByString:@","]
                   forState:UIControlStateNormal];
    
    [super viewWillAppear:animated];
    
}

#pragma mark - Helper

- (MSALPublicClientApplication *)msalTestPublicClientApplication
{
    return [self msalTestPublicClientApplicationWithSSOSeeding:NO];
}

- (MSALPublicClientApplication *)msalTestPublicClientApplicationWithSSOSeeding:(BOOL)ssoSeedingCall
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    NSDictionary *currentProfile = [MSALTestAppSettings currentProfile];
    NSString *clientId = [currentProfile objectForKey:MSAL_APP_CLIENT_ID];
    NSString *redirectUri = [currentProfile objectForKey:MSAL_APP_REDIRECT_URI];
    MSALAuthority *authority = [settings authority];
    MSALPublicClientApplicationConfig *pcaConfig = [[MSALPublicClientApplicationConfig alloc] initWithClientId:clientId
                                                                                                   redirectUri:redirectUri
                                                                                                     authority:authority];
    if (self.validateAuthoritySegmentControl.selectedSegmentIndex == 1)
    {
        pcaConfig.knownAuthorities = @[pcaConfig.authority];
    }
    
    pcaConfig.multipleCloudsSupported = self.instanceAwareSegmentControl.selectedSegmentIndex == 0;
    if (ssoSeedingCall)
    {
        pcaConfig.cacheConfig.keychainSharingGroup = @"com.microsoft.ssoseeding";
        pcaConfig.bypassRedirectURIValidation = YES;
    }
    NSError *error;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:pcaConfig error:&error];
    
    if (!application)
    {
        NSString *resultText = [NSString stringWithFormat:@"Failed to create PublicClientApplication:\n%@", error];
        [self.resultTextView setText:resultText];
        return nil;
    }
    
    return application;
}

- (MSALInteractiveTokenParameters *)tokenParams:(BOOL)isSSOSeedingCall
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:isSSOSeedingCall ? [MSALTestAppSettings getScopes] : [settings.scopes allObjects]
                                                                                      webviewParameters:[self msalTestWebViewParameters]];
    
    if (self.authSchemeSegmentControl.selectedSegmentIndex == 0 || isSSOSeedingCall)
    {
        parameters.authenticationScheme = [MSALAuthenticationSchemeBearer new];
    }
    else
    {
        NSURL *requestUrl = [NSURL URLWithString:@"https://signedhttprequest.azurewebsites.net/api/validateSHR"];
        parameters.authenticationScheme = [[MSALAuthenticationSchemePop alloc] initWithHttpMethod:MSALHttpMethodPOST requestUrl:requestUrl nonce:nil additionalParameters:nil];
    }
    
    parameters.loginHint = self.loginHintTextField.text;
    parameters.account = settings.currentAccount;
    parameters.promptType = isSSOSeedingCall ? MSALPromptTypeDefault : [self promptTypeValue];
    
    parameters.extraQueryParameters = isSSOSeedingCall ? [NSDictionary msidDictionaryFromWWWFormURLEncodedString:@"prompt=none"] : [NSDictionary msidDictionaryFromWWWFormURLEncodedString:self.extraQueryParamsTextField.text];

    return parameters;
}

- (MSALWebviewParameters *)msalTestWebViewParameters
{
    MSALWebviewParameters *webviewParameters = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:self];
    webviewParameters.webviewType = self.webviewTypeSegmentControl.selectedSegmentIndex == 0 ? MSALWebviewTypeWKWebView : MSALWebviewTypeDefault;
    
    if (webviewParameters.webviewType == MSALWebviewTypeWKWebView
        && self.customWebviewTypeSegmentControl.selectedSegmentIndex == TEST_EMBEDDED_WEBVIEW_CUSTOM)
    {
        webviewParameters.customWebview = self.customWebview;
        self.customWebviewContainer.hidden = NO;
    }
    
    if (@available(iOS 13.0, *))
    {
        webviewParameters.parentViewController = self;
        webviewParameters.prefersEphemeralWebBrowserSession = self.systemWebviewSSOSegmentControl.selectedSegmentIndex == 1; // 0 - Yes, 1 - No.
    }
    
    return webviewParameters;
}

- (BOOL)checkAccountSelected
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    if (!settings.currentAccount)
    {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error!"
                                                                       message:@"User needs to be selected for acquire token silent call"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return NO;
    }
    
    return YES;
}

- (void)showCompletionBlockHitMultipleTimesAlert
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error!"
                                                                       message:@"Completion block was hit multiple times!"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)acquireSSOSeeding
{
    MSALPublicClientApplication *application = [self msalTestPublicClientApplicationWithSSOSeeding:YES];
    
    if (!application)
    {
        return;
    }
    
    __block BOOL fBlockHit = NO;
    void (^completionBlock)(MSALResult *result, NSError *error) = ^(MSALResult *result, NSError *error) {
        
        if (fBlockHit)
        {
            [self showCompletionBlockHitMultipleTimesAlert];
            return;
        }
        
        fBlockHit = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (!result)
            {
                [self updateResultViewError:error];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:MSALTestAppCacheChangeNotification object:self];
        });
        [self hideCustomeWebViewIfNeed];
    };
    
    MSALInteractiveTokenParameters *parameters = [self tokenParams:YES];
    [application acquireTokenWithParameters:parameters completionBlock:completionBlock];
}

#pragma mark - IBAction
- (IBAction)onSignoutTapped:(__unused id)sender
{
    if (![self checkAccountSelected])
    {
        return;
    }

    MSALPublicClientApplication *application = [self msalTestPublicClientApplication];

    if (!application)
    {
        return;
    }

    __block BOOL fBlockHit = NO;

    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    MSALSignoutParameters *signoutParameters = [[MSALSignoutParameters alloc] initWithWebviewParameters:[self msalTestWebViewParameters]];

    [application signoutWithAccount:settings.currentAccount
                  signoutParameters:signoutParameters
                    completionBlock:^(BOOL success, NSError * _Nullable error) {

        if (fBlockHit)
        {
            [self showCompletionBlockHitMultipleTimesAlert];
            return;
        }

        fBlockHit = YES;
        dispatch_async(dispatch_get_main_queue(), ^{

            if (!success)
            {
                NSString *errorString = [NSString stringWithFormat:@"ssoSeeding sign out error %@", error];
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"%@", errorString);
            }
            else
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"ssoSeeding clear succesfully");
            }
        });
    }];
}

- (IBAction)onAcquireTokenInteractiveButtonTapped:(__unused id)sender
{
    MSALPublicClientApplication *application = [self msalTestPublicClientApplication];
    if (!application)
    {
        return;
    }
        
    __block BOOL fBlockHit = NO;
    void (^completionBlock)(MSALResult *result, NSError *error) = ^(MSALResult *result, NSError *error) {

        if (fBlockHit)
        {
            [self showCompletionBlockHitMultipleTimesAlert];
            return;
        }
        
        fBlockHit = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (result)
            {
                if ([MSALTestAppSettings isSSOSeeding])
                {
                    [self acquireSSOSeeding];
                }
                else
                {
                    [self updateResultView:result];
                    [self hideCustomeWebViewIfNeed];
                }
            }
            else
            {
                [self updateResultViewError:error];
                [self hideCustomeWebViewIfNeed];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:MSALTestAppCacheChangeNotification object:self];
        });
    };
    
    [application acquireTokenWithParameters:[self tokenParams:NO] completionBlock:completionBlock];
}

- (IBAction)onAcquireTokenSilentButtonTapped:(__unused id)sender
{
    if (![self checkAccountSelected])
    {
        return;
    }
    
    MSALPublicClientApplication *application = [self msalTestPublicClientApplication];
    
    if (!application)
    {
        return;
    }
    
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    
    __auto_type scopes = [settings.scopes allObjects];
    __auto_type account = settings.currentAccount;
    MSALSilentTokenParameters *parameters = [[MSALSilentTokenParameters alloc] initWithScopes:scopes account:account];
    
    if (self.authSchemeSegmentControl.selectedSegmentIndex == 0)
    {
        parameters.authenticationScheme = [MSALAuthenticationSchemeBearer new];
    }
    else
    {
        NSURL *requestUrl = [NSURL URLWithString:@"https://signedhttprequest.azurewebsites.net/api/validateSHR"];
        parameters.authenticationScheme = [[MSALAuthenticationSchemePop alloc] initWithHttpMethod:MSALHttpMethodPOST requestUrl:requestUrl nonce:nil additionalParameters:nil];
    }
    
    parameters.authority = settings.authority;
    __block BOOL fBlockHit = NO;
    self.acquireSilentButton.enabled = NO;
    [application acquireTokenSilentWithParameters:parameters completionBlock:^(MSALResult *result, NSError *error)
    {
        if (fBlockHit)
        {
            [self showCompletionBlockHitMultipleTimesAlert];
            return;
        }
        
        fBlockHit = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.acquireSilentButton.enabled = YES;
            if (result)
            {
                [self updateResultView:result];
            }
            else
            {
                [self updateResultViewError:error];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:MSALTestAppCacheChangeNotification object:self];
        });
    }];
}

- (IBAction)onClearCacheButtonTapped:(id)sender
{
    (void)sender;
    
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    
    // Delete accounts.
    NSDictionary *currentProfile = [MSALTestAppSettings currentProfile];
    NSString *clientId = [currentProfile objectForKey:MSAL_APP_CLIENT_ID];
    NSString *redirectUri = [currentProfile objectForKey:MSAL_APP_REDIRECT_URI];
    __auto_type authority = [settings authority];
    
    NSError *error = nil;
    MSALPublicClientApplicationConfig *pcaConfig = [[MSALPublicClientApplicationConfig alloc] initWithClientId:clientId
                                                                                                   redirectUri:redirectUri
                                                                                                     authority:authority];
    if ([MSALTestAppSettings isSSOSeeding]) pcaConfig.bypassRedirectURIValidation = YES;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:pcaConfig
                                                                                                    error:&error];
    
    BOOL result = [application.tokenCache clearWithContext:nil error:&error];
    result &= [self clearAllTokenKeysForAccessGroup:pcaConfig.cacheConfig.keychainSharingGroup];
       
    if (result)
    {
        self.resultTextView.text = @"Successfully cleared cache.";
        
        settings.currentAccount = nil;
        
        [_userButton setTitle:[MSALTestAppUserViewController currentTitle]
                     forState:UIControlStateNormal];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:MSALTestAppCacheChangeNotification object:self];
    }
    else
    {
        self.resultTextView.text = [NSString stringWithFormat:@"Failed to clear cache, error = %@", error];
    }
    // we clear sso Seeding without updating the result
    if ([MSALTestAppSettings isSSOSeeding])
    {
        BOOL resultSSOClear = TRUE;
        MSALPublicClientApplication *ssoSeedingApplication = [self msalTestPublicClientApplicationWithSSOSeeding:YES];
        resultSSOClear &=[ssoSeedingApplication.tokenCache clearWithContext:nil error:&error];
        resultSSOClear &=[self clearAllTokenKeysForAccessGroup:ssoSeedingApplication.configuration.cacheConfig.keychainSharingGroup];
        NSString *resultString ;
        resultString = resultSSOClear ? @"successfully" : @"failed";
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"%@", resultString);
    }
}

- (BOOL)clearAllTokenKeysForAccessGroup:(NSString *)accessGroup
{
    MSIDAssymetricKeyKeychainGenerator *keyGenerator = [[MSIDAssymetricKeyKeychainGenerator alloc] initWithGroup:accessGroup error:nil];
    NSDictionary *query = @{(__bridge id)kSecClass: (__bridge id)kSecClassKey};
    return [keyGenerator deleteItemWithAttributes:query error:nil];
}

- (IBAction)onShowTelemetryButtonTapped:(id)sender
{
    (void)sender;
    [self.navigationController pushViewController:[MSALTestAppTelemetryViewController sharedController] animated:YES];
}

- (IBAction)onSelectAuthorityButtonTapped:(id)sender
{
    (void)sender;
    [self.navigationController pushViewController:[MSALTestAppAuthorityTypeViewController sharedController] animated:YES];
}

- (IBAction)onSelectProfileButtonTapped:(id)sender
{
    (void)sender;
    [self.navigationController pushViewController:[MSALTestAppProfileViewController sharedController] animated:YES];
}

- (IBAction)onSelectUserButtonTapped:(id)sender
{
    (void)sender;
    [self.navigationController pushViewController:[MSALTestAppUserViewController sharedController] animated:YES];
}

- (IBAction)onSelectScopeButtonTapped:(id)sender
{
    (void)sender;
    [self.navigationController pushViewController:[MSALTestAppScopesViewController sharedController] animated:YES];
}

- (IBAction)onRunStressTestButtonTapped:(id)sender
{
    (void)sender;
    
    UIAlertController *stressTestController = [UIAlertController alertControllerWithTitle:@"Select stress test type"
                                                                                  message:nil
                                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    [stressTestController addAction:[UIAlertAction actionWithTitle:@"Acquire token silent (no expiring)"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                                                               
                                                               (void)action;
                                                               [self runStressTestWithType:MSALStressTestWithSameToken];
                                                           }]];
    
    [stressTestController addAction:[UIAlertAction actionWithTitle:@"Acquire token silent (with expiring)"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                                                               
                                                               (void)action;
                                                               [self runStressTestWithType:MSALStressTestWithExpiredToken];
                                                           }]];
    
    [stressTestController addAction:[UIAlertAction actionWithTitle:@"Acquire token silent (with multiple users)"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                                                               
                                                               (void)action;
                                                               [self runStressTestWithType:MSALStressTestWithMultipleUsers];
                                                           }]];
    
    [stressTestController addAction:[UIAlertAction actionWithTitle:@"Acquire token silent (until success)"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                                                               
                                                               (void)action;
                                                               [self runStressTestWithType:MSALStressTestOnlyUntilSuccess];
                                                           }]];
    
    [stressTestController addAction:[UIAlertAction actionWithTitle:@"Stop stress test"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                                                               
                                                               (void)action;
                                                               [self stopStressTest];
                                                           }]];
    
    [stressTestController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                             style:UIAlertActionStyleCancel
                                                           handler:nil]];
    
    [self presentViewController:stressTestController animated:YES completion:nil];
}

- (IBAction)onWebviewTypeChanged:(UISegmentedControl *)sender
{
    self.customWebviewTypeSegmentControl.enabled = sender.selectedSegmentIndex == TEST_EMBEDDED_WEBVIEW_TYPE_INDEX;
    self.systemWebviewSSOSegmentControl.enabled = sender.selectedSegmentIndex == TEST_SYSTEM_WEBVIEW_TYPE_INDEX;
}

- (IBAction)onCancelCustomWebviewButtonTapped:(id)sender
{
    (void)sender;
    
    [MSALPublicClientApplication cancelCurrentWebAuthSession];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    
    return YES;
}

#pragma mark - Private

- (void)onKeyboardWillShow:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    
    CGRect keyboardFrameEnd = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    keyboardFrameEnd = [self.view convertRect:keyboardFrameEnd fromView:nil];
    
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState | curve animations:^{
        self.acquireButtonsViewBottomConstraint.constant = keyboardFrameEnd.size.height - 49.0; // 49.0 is the height of a tab bar
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)onKeyboardWillHide:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState | curve animations:^{
        self.acquireButtonsViewBottomConstraint.constant = 0;
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)stopStressTest
{
    [MSALStressTestHelper stopStressTest];
    
    self.resultTextView.text = [NSString stringWithFormat:@"Stopped the currently running stress test at %@", [NSDate date]];
    
    [[MSALTestAppTelemetryViewController sharedController] startTracking];
    MSALGlobalConfig.loggerConfig.logLevel = MSALLogLevelVerbose;
}

- (void)updateResultViewError:(NSError *)error
{
    NSString *resultText = [NSString stringWithFormat:@"%@", error];
    [self.resultTextView setText:resultText];
}

- (void)updateResultView:(MSALResult *)result
{
    NSString *resultText = [NSString stringWithFormat:@"{\n\taccessToken = %@\n\texpiresOn = %@\n\ttenantId = %@\n\tuser = %@\n\tscopes = %@\n\tauthority = %@\n\tcorrelationId = %@\n}",
                            [result.accessToken msidTokenHash], result.expiresOn, result.tenantProfile.tenantId, result.account, result.scopes, result.authority,result.correlationId];
    
    [self.resultTextView setText:resultText];
   
}

- (MSALPromptType)promptTypeValue
{
    NSString *label = [self.promptTypeSegmentControl titleForSegmentAtIndex:self.promptTypeSegmentControl.selectedSegmentIndex];
    
    if ([label isEqualToString:@"Select"]) return MSALPromptTypeSelectAccount;
    if ([label isEqualToString:@"Login"]) return MSALPromptTypeLogin;
    if ([label isEqualToString:@"Consent"]) return MSALPromptTypeConsent;
    if ([label isEqualToString:@"Create"]) return MSALPromptTypeCreate;
    if ([label isEqualToString:@"Default"]) return MSALPromptTypeDefault;
    
    @throw @"Do not recognize prompt behavior";
}

- (void)runStressTestWithType:(MSALStressTestType)type
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    
    if (![[settings.scopes allObjects] count])
    {
        self.resultTextView.text = @"Please select the scope!";
        return;
    }
    
    NSDictionary *currentProfile = [MSALTestAppSettings currentProfile];
    NSString *clientId = [currentProfile objectForKey:MSAL_APP_CLIENT_ID];
    NSString *redirectUri = [currentProfile objectForKey:MSAL_APP_REDIRECT_URI];
    __auto_type authority = [settings authority];
    
    MSALPublicClientApplicationConfig *pcaConfig = [[MSALPublicClientApplicationConfig alloc] initWithClientId:clientId
                                                                                                   redirectUri:redirectUri
                                                                                                     authority:authority];
    
    MSALLegacySharedAccountsProvider *provider = [[MSALLegacySharedAccountsProvider alloc] initWithSharedKeychainAccessGroup:@"com.microsoft.adalcache" serviceIdentifier:@"legacy-accounts-service" applicationIdentifier:@"my.msal.testapp"];
    provider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    [pcaConfig.cacheConfig addExternalAccountProvider:provider];
    
    NSError *error;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:pcaConfig error:&error];
    
    if (!application)
    {
        self.resultTextView.text = [NSString stringWithFormat:@"Failed to create PublicClientApplication:\n%@", error];
        return;
    }
    
    NSArray<MSALAccount *> *accounts = [application allAccounts:nil];
    
    NSUInteger existingUserCount = [accounts count];
    NSUInteger requiredUserCount = [MSALStressTestHelper numberOfUsersNeededForTestType:type];
    
    if (existingUserCount != requiredUserCount)
    {
        self.resultTextView.text = [NSString stringWithFormat:@"Wrong number of users in cache (existing %ld, required %ld)", (unsigned long)existingUserCount, (unsigned long)requiredUserCount];
        return;
    }
    
    [[MSALTestAppTelemetryViewController sharedController] stopTracking];
    MSALGlobalConfig.loggerConfig.logLevel = MSALLogLevelNothing;
    
    if ([MSALStressTestHelper runStressTestWithType:type application:application])
    {
        self.resultTextView.text = [NSString stringWithFormat:@"Started running a stress test at %@", [NSDate date]];
    }
    else
    {
        self.resultTextView.text = @"Cannot start test, because other test is currently running!";
    }
}

- (void)hideCustomeWebViewIfNeed
{
    if (self.webviewTypeSegmentControl.selectedSegmentIndex == 0 &&
        self.customWebviewTypeSegmentControl.selectedSegmentIndex == TEST_EMBEDDED_WEBVIEW_CUSTOM)
    {
       [self.customWebview loadHTMLString:@"<html><head></head></html>" baseURL:nil];
       self.customWebviewContainer.hidden = YES;
    }
}

@end
