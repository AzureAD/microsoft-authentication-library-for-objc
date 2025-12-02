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

#import "MSALAcquireTokenViewController.h"
#import <MSAL/MSAL.h>
#import "MSALTestAppSettings.h"
#import "MSALScopesViewController.h"
#import "MSALInteractiveTokenParameters.h"
#import "MSALPublicClientApplication+Internal.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSALSilentTokenParameters.h"
#import "WebKit/WebKit.h"
#import "MSALWebviewParameters.h"
#import "MSALAuthenticationSchemePop.h"
#import "MSALAuthenticationSchemeBearer.h"
#import "MSALAuthenticationSchemeProtocol.h"

static NSString * const clientId = @"clientId";
static NSString * const redirectUri = @"redirectUri";
static NSString * const defaultScope = @"User.Read";

@interface MSALAcquireTokenViewController ()

@property (atomic, weak) IBOutlet NSPopUpButton *profilesPopUp;
@property (atomic, weak) IBOutlet NSPopUpButton *authorityPopUp;
@property (atomic, weak) IBOutlet NSTextField *clientIdTextField;
@property (atomic, weak) IBOutlet NSTextField *redirectUriTextField;
@property (atomic, weak) IBOutlet NSTextField *scopesTextField;
@property (atomic, weak) IBOutlet NSSegmentedControl *promptSegment;
@property (atomic, weak) IBOutlet NSTextField *loginHintTextField;
@property (atomic, weak) IBOutlet NSTextView *resultTextView;
@property (atomic, weak) IBOutlet NSTextField *extraQueryParamsTextField;
@property (atomic, weak) IBOutlet NSSegmentedControl *webViewSegment;
@property (atomic, weak) IBOutlet NSSegmentedControl *validateAuthoritySegment;
@property (atomic, weak) IBOutlet NSView *acquireTokenView;
@property (atomic, weak) IBOutlet NSPopUpButton *userPopup;
@property (atomic, weak) IBOutlet NSSegmentedControl *authSchemeSegment;

@property (atomic) WKWebView *webView;
@property (atomic) MSALTestAppSettings *settings;
@property (atomic) NSArray *selectedScopes;
@property (atomic) NSArray<MSALAccount *> *accounts;
@property (atomic, weak) IBOutlet NSSegmentedControl *xpcModeSegment;
@property (atomic, weak) IBOutlet NSSegmentedControl *xpcPressureTestSegment;
@property (nonatomic) NSTimer *timer;

@end

@implementation MSALAcquireTokenViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    WKWebViewConfiguration *defaultWKWebConfig = [MSALWebviewParameters defaultWKWebviewConfiguration];
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero
                                      configuration:defaultWKWebConfig];

    [self.webView setHidden:YES];
    [self.acquireTokenView addSubview:self.webView];
    
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.webView.leadingAnchor constraintEqualToAnchor:self.acquireTokenView.leadingAnchor constant:0],
        [self.webView.trailingAnchor constraintEqualToAnchor:self.acquireTokenView.trailingAnchor constant:0],
        [self.webView.topAnchor constraintEqualToAnchor:self.acquireTokenView.topAnchor constant:0],
        [self.webView.bottomAnchor constraintEqualToAnchor:self.acquireTokenView.bottomAnchor constant:0],
    ]];
    
    
    self.settings = [MSALTestAppSettings settings];
    [self populateProfiles];
    [self populateUsers];
    self.selectedScopes = @[defaultScope];
    self.validateAuthoritySegment.selectedSegment = self.settings.validateAuthority ? 0 : 1;
}

- (void)populateProfiles
{
    [self.profilesPopUp removeAllItems];
    [self.profilesPopUp addItemsWithTitles:[[MSALTestAppSettings profiles] allKeys]];
    [self.profilesPopUp selectItemWithTitle:[MSALTestAppSettings currentProfileName]];
    [self.authorityPopUp removeAllItems];
    [self.authorityPopUp addItemsWithTitles:[MSALTestAppSettings aadAuthorities]];
    [self.authorityPopUp addItemsWithTitles:[MSALTestAppSettings b2cAuthorities]];
    [self.authorityPopUp selectItemWithTitle:@"https://login.microsoftonline.com/common"];
    self.clientIdTextField.stringValue = [[MSALTestAppSettings currentProfile] objectForKey:clientId];
    self.redirectUriTextField.stringValue = [[MSALTestAppSettings currentProfile] objectForKey:redirectUri];
}

- (void)populateUsers
{
    NSError *error = nil;
    MSALPublicClientApplication *application = [self createPublicClientApplication:&error];
    [self.userPopup removeAllItems];
    
    if (application && !error)
    {
        MSALAccountEnumerationParameters *parameters = [MSALAccountEnumerationParameters new];
        parameters.completionBlockQueue = dispatch_get_main_queue();
        
        [application accountsFromDeviceForParameters:parameters completionBlock:^(NSArray<MSALAccount *> * _Nullable accounts, NSError * _Nullable error)
        {
            if (error)
            {
                [self updateResultViewError:error];
                return;
            }
            
            self.accounts = accounts;
            
            [self.userPopup addItemWithTitle:@""];
            
            for (MSALAccount *account in self.accounts)
            {
                [self.userPopup addItemWithTitle:account.username];
            }
        }];
    }
}

- (IBAction)selectedProfileChanged:(__unused id)sender
{
    [self.settings setCurrentProfile:[self.profilesPopUp indexOfSelectedItem]];
    self.clientIdTextField.stringValue = [[MSALTestAppSettings currentProfile] objectForKey:clientId];
    self.redirectUriTextField.stringValue = [[MSALTestAppSettings currentProfile] objectForKey:redirectUri];
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(__unused id)sender
{
    if ([segue.identifier isEqualToString:@"addScopesSegue"])
    {
        MSALScopesViewController *scopesController = (MSALScopesViewController *)segue.destinationController;
        scopesController.delegate = self;
    }
}

- (void)setScopes:(NSArray *)scopes
{
    if ([scopes count])
    {
        NSString *selectedScopes = [scopes componentsJoinedByString:@","];
        [self.scopesTextField setStringValue:selectedScopes];
        self.selectedScopes = scopes;
    }
    else
    {
        [self.scopesTextField setStringValue:defaultScope];
        self.selectedScopes = @[defaultScope];
    }
}

- (void)updateResultView:(MSALResult *)result
{
    NSString *resultText = [NSString stringWithFormat:@"{\n\taccessToken = %@\n\texpiresOn = %@\n\ttenantId = %@\n\tuser = %@\n\tscopes = %@\n\tauthority = %@\n\tcorrelationId = %@\n}",
                            [result.accessToken msidTokenHash], result.expiresOn, result.tenantProfile.tenantId, result.account, result.scopes, result.authority,result.correlationId];
    
    [self.resultTextView setString:resultText];
    
    NSLog(@"%@", resultText);
}

- (void)updateResultViewError:(NSError *)error
{
    NSString *resultText = [NSString stringWithFormat:@"%@", error];
    [self.resultTextView setString:resultText];
    NSLog(@"%@", resultText);
}

- (MSALPromptType)promptType
{
    NSString *promptType = [self.promptSegment labelForSegment:[self.promptSegment selectedSegment]];
    
    if ([promptType isEqualToString:@"Select"])
        return MSALPromptTypeSelectAccount;
    if ([promptType isEqualToString:@"Login"])
        return MSALPromptTypeLogin;
    if ([promptType isEqualToString:@"Consent"])
        return MSALPromptTypeConsent;
    if ([promptType isEqualToString:@"Create"])
        return MSALPromptTypeCreate;
    if ([promptType isEqualToString:@"Default"])
        return MSALPromptTypeDefault;
    
    @throw @"Do not recognize prompt behavior";
}

- (MSALXpcMode)xpcMode
{
    switch ([self.xpcModeSegment selectedSegment]) {
        case 1:
            return MSALXpcModeSSOExtCompanion;
        case 2:
            return MSALXpcModeSSOExtBackup;
        case 3:
            return MSALXpcModePrimary;
        default:
            return MSALXpcModeDisabled;
    }
}

- (BOOL)xpcPressureTest
{
    switch ([self.xpcPressureTestSegment selectedSegment]) {
        case 0:
            return NO;
        default:
            return YES;
    }
}

- (id<MSALAuthenticationSchemeProtocol>)authScheme
{
    NSString *authSchemeType = [self.authSchemeSegment labelForSegment:[self.authSchemeSegment selectedSegment]];
    
    if ([authSchemeType isEqualToString:@"Pop"])
    {
        NSURL *requestUrl = [NSURL URLWithString:@"https://signedhttprequest.azurewebsites.net/api/validateSHR"];
        return [[MSALAuthenticationSchemePop alloc] initWithHttpMethod:MSALHttpMethodPOST requestUrl:requestUrl nonce:nil additionalParameters:nil];
    }
    
    return [MSALAuthenticationSchemeBearer new];
}

- (BOOL)passedInWebview
{
    NSString* webViewType = [self.webViewSegment labelForSegment:[self.webViewSegment selectedSegment]];
    
    if ([webViewType isEqualToString:@"MSAL"])
    {
        return NO;
    }
    else if ([webViewType isEqualToString:@"Passed In"])
    {
        return YES;
    }
    else
    {
        @throw @"unexpected webview type";
    }
}

- (void)showAlert:(NSString *)messageText informativeText:(NSString *)informativeText
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = messageText;
        [alert addButtonWithTitle:@"OK"];
        alert.informativeText = informativeText;
        [alert runModal];
    });
}

- (IBAction)clearCache:(__unused id)sender
{
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
    if (self.validateAuthoritySegment.selectedSegment == 1)
    {
        pcaConfig.knownAuthorities = @[pcaConfig.authority];
    }
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:pcaConfig error:&error];
    
    if (!application)
    {
        NSString *resultText = [NSString stringWithFormat:@"Failed to create PublicClientApplication:\n%@", error];
        [self.resultTextView setString:resultText];
        return;
    }
    
    BOOL result = [application.tokenCache clearWithContext:nil error:&error];
    
    if (result)
    {
        [self.resultTextView setString:@"Successfully cleared cache."];
        settings.currentAccount = nil;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:MSALTestAppCacheChangeNotification object:self];
    }
    else
    {
        [self.resultTextView setString:[NSString stringWithFormat:@"Failed to clear cache, error = %@", error]];
    }
}

- (IBAction)clearCookies:(__unused id)sender
{
    // Clear WKWebView cookies
    WKWebsiteDataStore *dateStore = [WKWebsiteDataStore defaultDataStore];

    [dateStore fetchDataRecordsOfTypes:[WKWebsiteDataStore allWebsiteDataTypes]
                     completionHandler:^(NSArray<WKWebsiteDataRecord *> *records) {
        for (WKWebsiteDataRecord *record in records) {
            [dateStore removeDataOfTypes:record.dataTypes forDataRecords:@[record] completionHandler:^{}];
        }
    }];

    [_resultTextView setString:[NSString stringWithFormat:@"Successfully Cleared cookies."]];
}

- (IBAction)wipeAllAccounts:(__unused id)sender
{
    NSError *error = nil;
    MSALPublicClientApplication *application = [self createPublicClientApplication:&error];
    if (!application || error)
    {
        NSString *resultText = [NSString stringWithFormat:@"Failed to create PublicClientApplication:\n%@", error];
        [self.resultTextView setString:resultText];
        return;
    }
    
    MSALAccount *currentAccount = [self selectedAccount];
    
    if (!currentAccount)
    {
        [self showAlert:@"Error!" informativeText:@"User needs to be selected for acquire token silent call"];
        return;
    }
    
    MSALWebviewParameters *webviewParameters = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:self];
    MSALSignoutParameters *signoutParameters = [[MSALSignoutParameters alloc] initWithWebviewParameters:webviewParameters];
    signoutParameters.signoutFromBrowser = YES;
    signoutParameters.wipeCacheForAllAccounts = YES;
    signoutParameters.completionBlockQueue = dispatch_get_main_queue();
    
    [application signoutWithAccount:currentAccount
                  signoutParameters:signoutParameters
                    completionBlock:^(BOOL success, NSError * _Nullable error)
    {
        if (!success)
        {
            [self updateResultViewError:error];
        }
        else
        {
            [self.resultTextView setString:@"Signout succeeded"];
            [self populateUsers];
        }
    }];
}

- (MSALPublicClientApplication *)createPublicClientApplication:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    return [self createPublicClientApplication:error SSOSeeding:NO];
}

- (MSALPublicClientApplication *)createPublicClientApplication:(NSError * _Nullable __autoreleasing * _Nullable)error SSOSeeding:(BOOL)ssoSeedingCall
{
    NSDictionary *currentProfile = [MSALTestAppSettings currentProfile];
    NSString *clientId = [currentProfile objectForKey:MSAL_APP_CLIENT_ID];
    NSString *redirectUri = [currentProfile objectForKey:MSAL_APP_REDIRECT_URI];
    NSString *nestedAuthBrokerClientId = [currentProfile objectForKey:MSAL_APP_NESTED_CLIENT_ID];
    NSString *nestedAuthBrokerRedirectUri = [currentProfile objectForKey:MSAL_APP_NESTED_REDIRECT_URI];
    NSString *authorityString = self.authorityPopUp.selectedItem.title ?: @"https://login.microsoftonline.com/common";
    __auto_type authorityUrl =  [NSURL URLWithString:authorityString];
    MSALAuthority *authority = [MSALAuthority authorityWithURL:authorityUrl error:nil];
    
    MSALPublicClientApplicationConfig *pcaConfig = [[MSALPublicClientApplicationConfig alloc] initWithClientId:clientId
                                                                                                   redirectUri:redirectUri
                                                                                                     authority:authority
                                                                                      nestedAuthBrokerClientId:nestedAuthBrokerClientId
                                                                                   nestedAuthBrokerRedirectUri:nestedAuthBrokerRedirectUri];
    if (self.validateAuthoritySegment.selectedSegment == 1)
    {
        pcaConfig.knownAuthorities = @[pcaConfig.authority];
    }
    
    if (ssoSeedingCall)
    {
        pcaConfig.cacheConfig.keychainSharingGroup = @"com.microsoft.ssoseeding";
        pcaConfig.bypassRedirectURIValidation = YES;
    }

    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:pcaConfig error:error];
    
    return application;
}

- (IBAction)acquireTokenInteractive:(id)sender
{
    (void)sender;
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [self createPublicClientApplication:&error];
    
    if (!application || error)
    {
        NSString *resultText = [NSString stringWithFormat:@"Failed to create PublicClientApplication:\n%@", error];
        [self.resultTextView setString:resultText];
        return;
    }
    
    __block BOOL fBlockHit = NO;
    
    void (^completionBlock)(MSALResult *result, NSError *error) = ^(MSALResult *result, NSError *error) {
        
        if (fBlockHit)
        {
            [self showAlert:@"Error!" informativeText:@"Completion block was hit multiple times!"];
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
                    [self populateUsers];
                }
            }
            else
            {
                [self updateResultViewError:error];
            }
            
            [self.webView setHidden:YES];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:MSALTestAppCacheChangeNotification object:self];
        });
    };
    
    MSALWebviewParameters *webviewParameters = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:self];
    if ([self passedInWebview])
    {
        webviewParameters.customWebview = self.webView;
        webviewParameters.webviewType = MSALWebviewTypeWKWebView;
        [self.webView setHidden:NO];
    }
    
    NSDictionary *extraQueryParameters = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:[self.extraQueryParamsTextField stringValue]];
    MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:self.selectedScopes
                                                                                      webviewParameters:webviewParameters];
    parameters.loginHint = [self.loginHintTextField stringValue].length ? [self.loginHintTextField stringValue] : nil;
    parameters.account = [self selectedAccount];
    parameters.promptType = [self promptType];
    parameters.extraQueryParameters = extraQueryParameters;
    parameters.authenticationScheme = [self authScheme];
    parameters.msalXpcMode = [self xpcMode];
    
    [application acquireTokenWithParameters:parameters completionBlock:completionBlock];
}

- (void)acquireSSOSeeding
{
    NSError *error = nil;

    MSALPublicClientApplication *application = [self createPublicClientApplication:&error SSOSeeding:YES];
    
    if (!application)
    {
        return;
    }
    
    __block BOOL fBlockHit = NO;
    void (^completionBlock)(MSALResult *result, NSError *error) = ^(MSALResult *result, NSError *error) {
        
        if (fBlockHit)
        {
            [self showAlert:@"Error!" informativeText:@"Completion block was hit multiple times!"];
            return;
        }
        
        fBlockHit = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (!result)
            {
                [self updateResultViewError:error];
            }
            [self.webView setHidden:YES];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:MSALTestAppCacheChangeNotification object:self];
        });
    };
    
    MSALInteractiveTokenParameters *parameters = [self tokenParamsWithSSOSeeding:YES];
    [application acquireTokenWithParameters:parameters completionBlock:completionBlock];
}

- (IBAction)acquireTokenSilent:(id)sender
{
    (void)sender;
    NSError *error = nil;
    MSALPublicClientApplication *application = [self createPublicClientApplication:&error];
    if (!application || error)
    {
        NSString *resultText = [NSString stringWithFormat:@"Failed to create PublicClientApplication:\n%@", error];
        [self.resultTextView setString:resultText];
        return;
    }
    
    __block BOOL fBlockHit = NO;
    
    MSALAccount *currentAccount = [self selectedAccount];
    
    if (!currentAccount)
    {
        [self showAlert:@"Error!" informativeText:@"User needs to be selected for acquire token silent call"];
        return;
    }

    NSDictionary *extraQueryParameters = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:[self.extraQueryParamsTextField stringValue]];
    MSALSilentTokenParameters *parameters = [[MSALSilentTokenParameters alloc] initWithScopes:self.selectedScopes account:currentAccount];
    parameters.authority = self.settings.authority;
    parameters.authenticationScheme = [self authScheme];
    parameters.msalXpcMode = [self xpcMode];
    parameters.extraQueryParameters = extraQueryParameters;
    
    void (^acquireTokenSilentBlock)(void) = ^{
        NSDate *startTime = [NSDate date];
        BOOL isXpcPressureTest = [self xpcPressureTest];
        [application acquireTokenSilentWithParameters:parameters completionBlock:^(MSALResult *result, NSError *error)
         {
            if (!isXpcPressureTest)
            {
                if (fBlockHit)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showAlert:@"Error!" informativeText:@"Completion block was hit multiple times!"];
                    });
                    
                    return;
                }
                fBlockHit = YES;
            }
             
            NSDate *endTime = [NSDate date];
            NSTimeInterval elapsedTime = [endTime timeIntervalSinceDate:startTime];

            NSLog(@"Benchmarking: %f seconds", elapsedTime);
            
             dispatch_async(dispatch_get_main_queue(), ^{
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
    };
    
    if ([self xpcPressureTest])
    {
        void (^taskBlock)(void) = ^{
            NSLog(@"Task executed at %@", [NSDate date]);
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                int counter = 0;
                while (counter < 5) {
                    NSLog(@"%@ request started", @(counter));
                    [application.tokenCache clearWithContext:nil error:nil];
                    if (acquireTokenSilentBlock) acquireTokenSilentBlock();
                    sleep(1);
                    counter++;
                }
            });
        };
        
        // Schedule a timer every 5 minutes (300 seconds)
        self.timer = [NSTimer scheduledTimerWithTimeInterval:300.0
                                                      target:self
                                                    selector:@selector(handleTimer:)
                                                    userInfo:[taskBlock copy]
                                                     repeats:YES];
        [self.timer fire];
    }
    else
    {
        if (acquireTokenSilentBlock) acquireTokenSilentBlock();
    }
    
}


// Timer handler
- (void)handleTimer:(NSTimer *)timer {
    void (^block)(void) = timer.userInfo;
    if (block) {
        block();
    }
}

- (IBAction)signout:(__unused id)sender
{
    NSError *error = nil;
    MSALPublicClientApplication *application = [self createPublicClientApplication:&error];
    if (!application || error)
    {
        NSString *resultText = [NSString stringWithFormat:@"Failed to create PublicClientApplication:\n%@", error];
        [self.resultTextView setString:resultText];
        return;
    }
    
    MSALAccount *currentAccount = [self selectedAccount];
    
    if (!currentAccount)
    {
        [self showAlert:@"Error!" informativeText:@"User needs to be selected for acquire token silent call"];
        return;
    }
    
    MSALWebviewParameters *webviewParameters = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:self];
    MSALSignoutParameters *signoutParameters = [[MSALSignoutParameters alloc] initWithWebviewParameters:webviewParameters];
    signoutParameters.signoutFromBrowser = YES;
    signoutParameters.completionBlockQueue = dispatch_get_main_queue();
    
    [application signoutWithAccount:currentAccount
                  signoutParameters:signoutParameters
                    completionBlock:^(BOOL success, NSError * _Nullable error)
    {
        if (!success)
        {
            [self updateResultViewError:error];
        }
        else
        {
            [self.resultTextView setString:@"Signout succeeded"];
            [self populateUsers];
        }
    }];
    
}

- (MSALAccount *)selectedAccount
{
    if (self.userPopup.indexOfSelectedItem == 0 || self.userPopup.indexOfSelectedItem > [self.accounts count])
    {
        return nil;
    }
    
    return self.accounts[self.userPopup.indexOfSelectedItem-1];
}

- (MSALInteractiveTokenParameters *)tokenParamsWithSSOSeeding:(BOOL)isSSOSeedingCall
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    NSArray<NSString *> *scopes = isSSOSeedingCall ? [MSALTestAppSettings getScopes] : [settings.scopes allObjects];
    MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes
                                                                                      webviewParameters:[self msalTestWebViewParameters]];
    parameters.loginHint = [self.loginHintTextField stringValue];
    parameters.account = settings.currentAccount;
    parameters.authenticationScheme = [self authScheme];
    parameters.promptType = [self promptType];
    parameters.extraQueryParameters =[NSDictionary msidDictionaryFromWWWFormURLEncodedString:[self.extraQueryParamsTextField stringValue]];
    
    if(isSSOSeedingCall)
    {
        [self fillTokenParamsWithSSOSeedingValue:parameters];
    }
    return parameters;
}

- (void)fillTokenParamsWithSSOSeedingValue:(MSALInteractiveTokenParameters *)parameters
{
    parameters.authenticationScheme = [MSALAuthenticationSchemeBearer new];
    parameters.promptType = MSALPromptTypeDefault;
    parameters.extraQueryParameters = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:@"prompt=none"];
}

- (MSALWebviewParameters *)msalTestWebViewParameters
{
    MSALWebviewParameters *webviewParameters = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:self];
    if ([self passedInWebview])
    {
        webviewParameters.customWebview = self.webView;
        webviewParameters.webviewType = MSALWebviewTypeWKWebView;
        [self.webView setHidden:NO];
    }
    return webviewParameters;
}

@end
