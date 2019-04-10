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

#import "AcquireTokenViewController.h"
#import <MSAL/MSAL.h>
#import "MSALTestAppSettings.h"
#import "ScopesViewController.h"
#import "MSALInteractiveTokenParameters.h"
#import "MSALConstants.h"
#import "MSALPublicClientApplication+Internal.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSALSilentTokenParameters.h"
#import "WebKit/WebKit.h"

static NSString * const clientId = @"clientId";
static NSString * const redirectUri = @"redirectUri";
static NSString * const defaultScope = @"User.Read";

@interface AcquireTokenViewController ()

@property (weak) IBOutlet NSPopUpButton *profiles;
@property (weak) IBOutlet NSTextField *clientId;
@property (weak) IBOutlet NSTextField *redirectUri;
@property (weak) IBOutlet NSTextField *scopesLabel;
@property (weak) IBOutlet NSSegmentedControl *promptBehavior;
@property (weak) IBOutlet NSTextField *loginHintField;
@property (weak) IBOutlet NSTextView *resultView;
@property (weak) IBOutlet NSTextField *extraQueryParamsField;
@property (weak) IBOutlet NSSegmentedControl *webViewType;
@property (weak) IBOutlet NSSegmentedControl *validateAuthority;

@property MSALTestAppSettings *settings;
@property NSArray *selectedScopes;

@end

@implementation AcquireTokenViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.settings = [MSALTestAppSettings settings];
    [self populateProfiles];
    self.selectedScopes = @[defaultScope];
}

- (void)populateProfiles
{
    [self.profiles removeAllItems];
    [self.profiles setTarget:self];
    [self.profiles setAction:@selector(selectedProfileChanged:)];
    [[MSALTestAppSettings profiles] enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
        [self.profiles addItemWithTitle:key];
    }];
    
    [self.profiles selectItemWithTitle:[MSALTestAppSettings currentProfileName]];
    self.clientId.stringValue = [[MSALTestAppSettings currentProfile] objectForKey:clientId];
    self.redirectUri.stringValue = [[MSALTestAppSettings currentProfile] objectForKey:redirectUri];
}

- (IBAction)selectedProfileChanged:(id)sender
{
    [self.settings setCurrentProfile:[self.profiles indexOfSelectedItem]];
    self.clientId.stringValue = [[MSALTestAppSettings currentProfile] objectForKey:clientId];
    self.redirectUri.stringValue = [[MSALTestAppSettings currentProfile] objectForKey:redirectUri];
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"addScopesSegue"])
    {
        ScopesViewController *scopesController = (ScopesViewController *)segue.destinationController;
        scopesController.delegate = self;
    }
}

- (void)setScopes:(NSMutableArray *)scopes
{
    if ([scopes count])
    {
        NSString *selectedScopes = [scopes componentsJoinedByString:@","];
        [self.scopesLabel setStringValue:selectedScopes];
        self.selectedScopes = scopes;
    }
    else
    {
        [self.scopesLabel setStringValue:defaultScope];
        self.selectedScopes = @[defaultScope];
    }
}

- (void)updateResultView:(MSALResult *)result
{
    NSString *resultText = [NSString stringWithFormat:@"{\n\taccessToken = %@\n\texpiresOn = %@\n\ttenantId = %@\n\tuser = %@\n\tscopes = %@\n\tauthority = %@\n}",
                            [result.accessToken msidTokenHash], result.expiresOn, result.tenantId, result.account, result.scopes, result.authority];
    
    [self.resultView setString:resultText];
    
    NSLog(@"%@", resultText);
}

- (void)updateResultViewError:(NSError *)error
{
    NSString *resultText = [NSString stringWithFormat:@"%@", error];
    [self.resultView setString:resultText];
    NSLog(@"%@", resultText);
}

- (MSALPromptType)promptType
{
    NSString *promptType = [self.promptBehavior labelForSegment:[self.promptBehavior selectedSegment]];
    
    if ([promptType isEqualToString:@"Select"])
        return MSALPromptTypeSelectAccount;
    if ([promptType isEqualToString:@"Login"])
        return MSALPromptTypeLogin;
    if ([promptType isEqualToString:@"Consent"])
        return MSALPromptTypeConsent;
    
    @throw @"Do not recognize prompt behavior";
}

- (BOOL)embeddedWebView
{
    NSString* webViewType = [self.webViewType labelForSegment:[self.webViewType selectedSegment]];
    
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
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:clientId
                                                                                           authority:authority
                                                                                         redirectUri:redirectUri
                                                                                               error:&error];
    
    BOOL result = [application.tokenCache clearWithContext:nil error:&error];
    
    if (result)
    {
        [self.resultView setString:@"Successfully cleared cache."];
        
        settings.currentAccount = nil;
        
//        [_userButton setTitle:[MSALTestAppUserViewController currentTitle]
//                     forState:UIControlStateNormal];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:MSALTestAppCacheChangeNotification object:self];
    }
    else
    {
        [self.resultView setString:[NSString stringWithFormat:@"Failed to clear cache, error = %@", error]];
    }
}

- (IBAction)clearCookies:(id)sender
{
    NSHTTPCookieStorage* cookieStore = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray* cookies = cookieStore.cookies;
    for (NSHTTPCookie* cookie in cookies)
    {
        [cookieStore deleteCookie:cookie];
    }
    
    [_resultView setString:[NSString stringWithFormat:@"Cleared %lu cookies.", (unsigned long)cookies.count]];
    
    // Clear WKWebView cookies
    if (@available(macOS 10.11, *)) {
        NSSet *allTypes = [WKWebsiteDataStore allWebsiteDataTypes];
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:allTypes
                                                   modifiedSince:[NSDate dateWithTimeIntervalSince1970:0]
                                               completionHandler:^{}];
    }
}

- (void)queryAccounts
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    NSDictionary *currentProfile = [MSALTestAppSettings currentProfile];
    NSString *clientId = [currentProfile objectForKey:MSAL_APP_CLIENT_ID];
    NSString *redirectUri = [currentProfile objectForKey:MSAL_APP_REDIRECT_URI];
    MSALAuthority *authority = [settings authority];
    NSError *error = nil;
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:clientId
                                                                                           authority:authority
                                                                                         redirectUri:redirectUri
                                                                                               error:&error];
    
    
    if (!application)
    {
        MSID_LOG_ERROR(nil, @"Failed to create public client application: %@", error);
        return;
    }
    
    [application allAccountsFilteredByAuthority:^(NSArray<MSALAccount *> *accounts, NSError *error) {
        
//        _accounts = accounts;
//
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [super refresh];
//        });
    }];
}

- (IBAction)acquireTokenInteractive:(id)sender
{
    (void)sender;
    
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    NSDictionary *currentProfile = [MSALTestAppSettings currentProfile];
    NSString *clientId = [currentProfile objectForKey:MSAL_APP_CLIENT_ID];
    NSString *redirectUri = [currentProfile objectForKey:MSAL_APP_REDIRECT_URI];
    MSALAuthority *authority = [settings authority];
    NSDictionary *extraQueryParameters = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:[self.extraQueryParamsField stringValue]];
    
    NSError *error = nil;
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:clientId
                                                                                           authority:authority
                                                                                         redirectUri:redirectUri
                                                                                               error:&error];
    
    if (!application)
    {
        NSString *resultText = [NSString stringWithFormat:@"Failed to create PublicClientApplication:\n%@", error];
        [self.resultView setString:resultText];
        return;
    }
    
    application.validateAuthority = [self.validateAuthority selectedSegment] == 0;
    
    __block BOOL fBlockHit = NO;
    
    void (^completionBlock)(MSALResult *result, NSError *error) = ^(MSALResult *result, NSError *error) {
        
        [self queryAccounts];
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
            }
            else
            {
                [self updateResultViewError:error];
            }
            
            //            [_webView loadHTMLString:@"<html><head></head></html>" baseURL:nil];
            //            [_authView setHidden:YES];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:MSALTestAppCacheChangeNotification object:self];
        });
    };
    
    if ([self embeddedWebView])
    {
        //        [_webview loadHTMLString:@"<html><head></head><body>Loading...</body></html>" baseURL:nil];
        //        [context setWebView:_webview];
        //        [_authView setFrame:self.window.contentView.frame];
        //
        //        [_acquireSettingsView setHidden:YES];
        //        [_authView setHidden:NO];
    }
    
    MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:self.selectedScopes];
    parameters.loginHint = [self.loginHintField stringValue];
    parameters.account = settings.currentAccount;
    parameters.promptType = [self promptType];
    parameters.extraQueryParameters = extraQueryParameters;
    
    [application acquireTokenWithParameters:parameters completionBlock:completionBlock];
    
}

- (IBAction)acquireTokenSilent:(id)sender
{
    (void)sender;
    
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    
    if (!settings.currentAccount)
    {
        [self showAlert:@"Error!" informativeText:@"User needs to be selected for acquire token silent call"];
        return;
    }
    
    NSDictionary *currentProfile = [MSALTestAppSettings currentProfile];
    NSString *clientId = [currentProfile objectForKey:MSAL_APP_CLIENT_ID];
    NSString *redirectUri = [currentProfile objectForKey:MSAL_APP_REDIRECT_URI];
    __auto_type authority = [settings authority];
    
    NSError *error = nil;
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:clientId
                                                                                           authority:authority
                                                                                         redirectUri:redirectUri
                                                                                               error:&error];
    if (!application)
    {
        NSString *resultText = [NSString stringWithFormat:@"Failed to create PublicClientApplication:\n%@", error];
        [self.resultView setString:resultText];
        return;
    }
    
    application.validateAuthority = [self.validateAuthority selectedSegment] == 0;
    
    __block BOOL fBlockHit = NO;
    //    _acquireSilentButton.enabled = NO;
    
    __auto_type account = settings.currentAccount;
    MSALSilentTokenParameters *parameters = [[MSALSilentTokenParameters alloc] initWithScopes:self.selectedScopes account:account];
    parameters.authority = settings.authority;
    
    [application acquireTokenSilentWithParameters:parameters completionBlock:^(MSALResult *result, NSError *error)
     {
         if (fBlockHit)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 //                 _acquireSilentButton.enabled = YES;
                 [self showAlert:@"Error!" informativeText:@"Completion block was hit multiple times!"];
             });
             
             return;
         }
         fBlockHit = YES;
         
         dispatch_async(dispatch_get_main_queue(), ^{
             //             _acquireSilentButton.enabled = YES;
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
