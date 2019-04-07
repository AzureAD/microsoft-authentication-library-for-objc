//
//  AcquireTokenViewController.m
//  MSALMacTestApp
//
//  Created by Rohit Narula on 4/3/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "AcquireTokenViewController.h"
#import <MSAL/MSAL.h>
#import "MSALTestAppSettings.h"
#import "ScopesViewController.h"
#import "MSALInteractiveTokenParameters.h"
#import "MSALConstants.h"
#import "MSALPublicClientApplication+Internal.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSALSilentTokenParameters.h"

static NSString * const clientId = @"clientId";
static NSString * const redirectUri = @"redirectUri";
static NSString * const defaultScope = @"User.Read";


@interface AcquireTokenViewController ()

@property (weak) IBOutlet NSPopUpButton *profiles;
@property (weak) IBOutlet NSTextField *clientId;
@property (weak) IBOutlet NSTextField *redirectUri;
@property (weak) IBOutlet NSTextField *scopesLabel;
@property (weak) IBOutlet NSSegmentedControl *promptBehavior;
@property MSALTestAppSettings *settings;
@property (weak) IBOutlet NSTextField *loginHintField;
@property (weak) IBOutlet NSTextView *resultView;
@property (weak) IBOutlet NSTextField *extraQueryParamsField;
@property (weak) IBOutlet NSSegmentedControl *webViewType;
@property (weak) IBOutlet NSSegmentedControl *validateAuthority;

@end

@implementation AcquireTokenViewController

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
    
    MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:[settings.scopes allObjects]];
    parameters.loginHint = [self.loginHintField stringValue];
    parameters.account = settings.currentAccount;
    parameters.uiBehavior = [self uiBehavior];
    parameters.extraQueryParameters = extraQueryParameters;
    
    [application acquireTokenWithParameters:parameters completionBlock:completionBlock];
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _settings = [MSALTestAppSettings settings];
    [self populateProfiles];
    // Do view setup here.
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
    }
    else
    {
        [self.scopesLabel setStringValue:defaultScope];
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

- (MSALUIBehavior)uiBehavior
{
    NSString *promptBehavior = [self.promptBehavior labelForSegment:[self.promptBehavior selectedSegment]];
    
    if ([promptBehavior isEqualToString:@"Select"])
        return MSALSelectAccount;
    if ([promptBehavior isEqualToString:@"Login"])
        return MSALForceLogin;
    if ([promptBehavior isEqualToString:@"Consent"])
        return MSALForceConsent;
    
    @throw @"Do not recognize prompt behavior";
}

- (BOOL)embeddedWebView
{
    NSString* webViewType = [self.webViewType labelForSegment:[_webViewType selectedSegment]];
    
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
    
    __auto_type scopes = [settings.scopes allObjects];
    __auto_type account = settings.currentAccount;
    MSALSilentTokenParameters *parameters = [[MSALSilentTokenParameters alloc] initWithScopes:scopes account:account];
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

- (IBAction)clearCookies:(id)sender
{
    NSHTTPCookieStorage* cookieStore = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray* cookies = cookieStore.cookies;
    for (NSHTTPCookie* cookie in cookies)
    {
        [cookieStore deleteCookie:cookie];
    }
    
    [_resultView setString:[NSString stringWithFormat:@"Cleared %lu cookies.", (unsigned long)cookies.count]];
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

@end
