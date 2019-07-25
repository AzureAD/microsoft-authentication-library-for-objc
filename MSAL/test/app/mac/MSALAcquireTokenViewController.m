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

static NSString * const clientId = @"clientId";
static NSString * const redirectUri = @"redirectUri";
static NSString * const defaultScope = @"User.Read";

@interface MSALAcquireTokenViewController ()

@property (weak) IBOutlet NSPopUpButton *profilesPopUp;
@property (weak) IBOutlet NSTextField *clientIdTextField;
@property (weak) IBOutlet NSTextField *redirectUriTextField;
@property (weak) IBOutlet NSTextField *scopesTextField;
@property (weak) IBOutlet NSSegmentedControl *promptSegment;
@property (weak) IBOutlet NSTextField *loginHintTextField;
@property (weak) IBOutlet NSTextView *resultTextView;
@property (weak) IBOutlet NSTextField *extraQueryParamsTextField;
@property (weak) IBOutlet NSSegmentedControl *webViewSegment;
@property (weak) IBOutlet NSSegmentedControl *validateAuthoritySegment;
@property (weak) IBOutlet NSStackView *acquireTokenView;
@property (weak) IBOutlet WKWebView *webView;
@property (weak) IBOutlet NSPopUpButton *userPopup;


@property MSALTestAppSettings *settings;
@property NSArray *selectedScopes;
@property NSArray<MSALAccount *> *accounts;

@end

@implementation MSALAcquireTokenViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
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
        self.accounts = [application allAccounts:&error];
        
        for (MSALAccount *account in self.accounts)
        {
            [self.userPopup addItemWithTitle:account.username];
        }
    }
}

- (IBAction)selectedProfileChanged:(id)sender
{
    [self.settings setCurrentProfile:[self.profilesPopUp indexOfSelectedItem]];
    self.clientIdTextField.stringValue = [[MSALTestAppSettings currentProfile] objectForKey:clientId];
    self.redirectUriTextField.stringValue = [[MSALTestAppSettings currentProfile] objectForKey:redirectUri];
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender
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
    NSString *resultText = [NSString stringWithFormat:@"{\n\taccessToken = %@\n\texpiresOn = %@\n\ttenantId = %@\n\tuser = %@\n\tscopes = %@\n\tauthority = %@\n}",
                            [result.accessToken msidTokenHash], result.expiresOn, result.tenantProfile.tenantId, result.account, result.scopes, result.authority];
    
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
    
    @throw @"Do not recognize prompt behavior";
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

- (IBAction)clearCache:(id)sender
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

- (IBAction)clearCookies:(id)sender
{
    // Clear WKWebView cookies
    if (@available(macOS 10.11, *)) {
        NSSet *allTypes = [WKWebsiteDataStore allWebsiteDataTypes];
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:allTypes
                                                   modifiedSince:[NSDate dateWithTimeIntervalSince1970:0]
                                               completionHandler:^{}];
        
        [_resultTextView setString:[NSString stringWithFormat:@"Successfully Cleared cookies."]];
    }
}

- (MSALPublicClientApplication *)createPublicClientApplication:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    NSDictionary *currentProfile = [MSALTestAppSettings currentProfile];
    NSString *clientId = [currentProfile objectForKey:MSAL_APP_CLIENT_ID];
    NSString *redirectUri = [currentProfile objectForKey:MSAL_APP_REDIRECT_URI];
    MSALAuthority *authority = [self.settings authority];
    
    MSALPublicClientApplicationConfig *pcaConfig = [[MSALPublicClientApplicationConfig alloc] initWithClientId:clientId
                                                                                                   redirectUri:redirectUri
                                                                                                     authority:authority];
    if (self.validateAuthoritySegment.selectedSegment == 1)
    {
        pcaConfig.knownAuthorities = @[pcaConfig.authority];
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
                [self updateResultView:result];
                [self populateUsers];
            }
            else
            {
                [self updateResultViewError:error];
            }
            
            [self.webView setHidden:YES];
            [self.acquireTokenView setHidden:NO];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:MSALTestAppCacheChangeNotification object:self];
        });
    };
    
    MSALWebviewParameters *webviewParameters = [MSALWebviewParameters new];
    if ([self passedInWebview])
    {
        webviewParameters.customWebview = self.webView;
        [self.acquireTokenView setHidden:YES];
        [self.webView setHidden:NO];
    }
    
    NSDictionary *extraQueryParameters = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:[self.extraQueryParamsTextField stringValue]];
    MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:self.selectedScopes
                                                                                      webviewParameters:webviewParameters];
    parameters.loginHint = [self.loginHintTextField stringValue];
    parameters.account = self.settings.currentAccount;
    parameters.promptType = [self promptType];
    parameters.extraQueryParameters = extraQueryParameters;
    
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
    
    NSString *userName = [self.userPopup titleOfSelectedItem];
    MSALAccount *currentAccount = nil;
    
    if (!self.accounts)
    {
        self.accounts = [application allAccounts:nil];
    }
    
    for (MSALAccount *account in self.accounts)
    {
        if ([account.username isEqualToString:userName])
        {
            currentAccount = account;
        }
    }
    
    if (!currentAccount)
    {
        [self showAlert:@"Error!" informativeText:@"User needs to be selected for acquire token silent call"];
        return;
    }
    
    MSALSilentTokenParameters *parameters = [[MSALSilentTokenParameters alloc] initWithScopes:self.selectedScopes account:currentAccount];
    parameters.authority = self.settings.authority;
    
    [application acquireTokenSilentWithParameters:parameters completionBlock:^(MSALResult *result, NSError *error)
     {
         if (fBlockHit)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 [self showAlert:@"Error!" informativeText:@"Completion block was hit multiple times!"];
             });
             
             return;
         }
         fBlockHit = YES;
         
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
}


@end
