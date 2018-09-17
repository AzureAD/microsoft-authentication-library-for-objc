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

#import "MSAL.h"
#import "MSIDLogger+Internal.h"
#import "MSALAutoMainViewController.h"
#import "MSALAutoResultViewController.h"
#import "MSALAutoRequestViewController.h"
#import "MSIDTokenCacheItem+Automation.h"
#import "MSALUser+Automation.h"
#import "MSALResult+Automation.h"
#import "MSALAutomationConstants.h"
#import "MSAL.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDAccount.h"
#import "MSIDConfiguration.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSALAuthorityFactory.h"
#import "MSALAuthority.h"
#import "MSALAuthority_Internal.h"
#import "NSString+MSIDExtensions.h"
#import "MSAL_Internal.h"
#import "MSALPassedInWebController.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDAuthorityFactory.h"

@interface MSALAutoMainViewController ()
{
    NSMutableString *_resultLogs;
}

@property (nonatomic) MSIDDefaultTokenCacheAccessor *defaultAccessor;
@property (nonatomic) MSIDLegacyTokenCacheAccessor *legacyAccessor;
@property (nonatomic) MSIDAccountCredentialCache *accountCredentialCache;
@property (nonatomic) MSALPassedInWebController *passedInController;

@end

@implementation MSALAutoMainViewController

#define SHOW_REQUEST_SEGUE          @"showRequest"
#define SHOW_RESULT_SEGUE           @"showResult"

#define RESULT_INFO_PARAM           @"resultInfo"
#define RESULT_LOGS_PARAM           @"resultLogs"
#define COMPLETION_BLOCK_PARAM      @"completionBlock"

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [MSALLogger sharedLogger].PiiLoggingEnabled = YES;
    [[MSALLogger sharedLogger] setCallback:^(MSALLogLevel level, NSString *message, BOOL containsPII) {
        (void)level;
        if (!containsPII)
        {
            return;
        }
        
        if (_resultLogs)
        {
            [_resultLogs appendString:message];
        }
    }];
    
    [[MSALLogger sharedLogger] setLevel:MSALLogLevelVerbose];
    
    MSIDOauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    self.legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache otherCacheAccessors:nil factory:factory];
    self.defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache otherCacheAccessors:@[self.legacyAccessor] factory:factory];
    self.accountCredentialCache = [[MSIDAccountCredentialCache alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache];
    
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    self.passedInController = (MSALPassedInWebController *) [sb instantiateViewControllerWithIdentifier:@"passed_in_controller"];
    [self.passedInController loadViewIfNeeded];
}

#pragma mark - Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    (void)sender;
    
    if ([segue.identifier isEqualToString:SHOW_REQUEST_SEGUE])
    {
        MSALAutoRequestViewController *requestVC = segue.destinationViewController;
        requestVC.completionBlock = sender[COMPLETION_BLOCK_PARAM];
    }
    
    if ([segue.identifier isEqualToString:SHOW_RESULT_SEGUE])
    {
        MSALAutoResultViewController *resultVC = segue.destinationViewController;
        resultVC.resultInfoString = sender[RESULT_INFO_PARAM];
        resultVC.resultLogsString = sender[RESULT_LOGS_PARAM];
    }
}

#pragma mark - Utils

- (BOOL)checkParametersError:(NSDictionary<NSString *, NSString *> *)parameters
{
    _resultLogs = [NSMutableString new];
    
    if (parameters[MSAL_AUTOMATION_ERROR_PARAM])
    {
        [self displayOperationResultString:parameters[MSAL_AUTOMATION_ERROR_PARAM]];
        
        return NO;
    }
    
    return YES;
}

- (MSALPublicClientApplication *)applicationWithParameters:(NSDictionary *)parameters
{
    BOOL validateAuthority = parameters[MSAL_VALIDATE_AUTHORITY_PARAM] ? [parameters[MSAL_VALIDATE_AUTHORITY_PARAM] boolValue] : YES;
    
    MSALAuthority *authority = nil;
    
    if (parameters[MSAL_AUTHORITY_PARAM])
    {
        __auto_type authorityUrl = [[NSURL alloc] initWithString:parameters[MSAL_AUTHORITY_PARAM]];
        __auto_type authorityFactory = [MSALAuthorityFactory new];
        
        authority = [authorityFactory authorityFromUrl:authorityUrl context:nil error:nil];
    }
    
    NSError *error = nil;
    
    MSALPublicClientApplication *clientApplication =
    [[MSALPublicClientApplication alloc] initWithClientId:parameters[MSAL_CLIENT_ID_PARAM]
                                                authority:authority
                                              redirectUri:parameters[MSAL_REDIRECT_URI_PARAM]
                                                    error:&error];
    
    clientApplication.validateAuthority = validateAuthority;
    clientApplication.sliceParameters = parameters[MSAL_SLICE_PARAMS];
    
    if (error)
    {
        [self displayError:error];
        return nil;
    }
    
    return clientApplication;
}

- (MSALAccount *)accountWithParameters:(NSDictionary<NSString *, NSString *> *)parameters
                           application:(MSALPublicClientApplication *)application
{
    NSString *accountIdentifier = parameters[MSAL_ACCOUNT_IDENTIFIER_PARAM];
    MSALAccount *account = nil;
    
    NSError *error = nil;
    
    if (accountIdentifier)
    {
        account = [application accountForHomeAccountId:accountIdentifier error:&error];
        
        if (error)
        {
            [self displayResultJson:[self createJsonStringFromError:error]
                               logs:_resultLogs];
            return nil;
        }
    }
    else if (parameters[MSAL_LEGACY_USER_PARAM])
    {
        account = [application accountForUsername:parameters[MSAL_LEGACY_USER_PARAM] error:&error];
        
        if (error)
        {
            [self displayResultJson:[self createJsonStringFromError:error]
                               logs:_resultLogs];
            return nil;
        }
    }
    
    return account;
}

- (void)handleMSALResult:(MSALResult *)result error:(NSError *)error
{
    [self dismissViewControllerAnimated:NO
                             completion:^{
                                 
                                 NSString *resultString = error ? [self createJsonStringFromError:error] : [self createJsonFromResult:result];
                                 
                                 [self displayResultJson:resultString
                                                    logs:_resultLogs];
                             }];
}

#pragma mark - AcquireToken

- (IBAction)acquireToken:(id)sender
{
    (void)sender;
    
    MSALAutoParamBlock completionBlock = ^void (NSDictionary<NSString *, NSString *> * parameters)
    {
        if (![self checkParametersError:parameters])
        {
            return;
        }
        
        MSALPublicClientApplication *application = [self applicationWithParameters:parameters];
        
        if (!application)
        {
            return;
        }
        
        MSALAccount *account = [self accountWithParameters:parameters application:application]; // User is not required for acquiretoken
        
        NSOrderedSet *scopes = [NSOrderedSet msidOrderedSetFromString:parameters[MSAL_SCOPES_PARAM]];

        NSArray *extraScopes = (NSArray *)parameters[MSAL_EXTRA_SCOPES_PARAM];
        NSDictionary *extraQueryParameters = (NSDictionary *)parameters[MSAL_EXTRA_QP_PARAM];
        NSUUID *correlationId = parameters[MSAL_CORRELATION_ID_PARAM] ? [[NSUUID alloc] initWithUUIDString:parameters[MSAL_CORRELATION_ID_PARAM]] : nil;
        NSString *claims = parameters[MSAL_CLAIMS_PARAM];
        
        MSALUIBehavior uiBehavior = MSALUIBehaviorDefault;
        
        if ([parameters[MSAL_UI_BEHAVIOR] isEqualToString:@"force"])
        {
            uiBehavior = MSALForceLogin;
        }
        else if ([parameters[MSAL_UI_BEHAVIOR] isEqualToString:@"consent"])
        {
            uiBehavior = MSALForceConsent;
        }
        
        NSString *webviewSelection = parameters[MSAL_AUTOMATION_WEBVIEWSELECTION_PARAM];
        if ([webviewSelection isEqualToString:MSAL_AUTOMATION_WEBVIEWSELECTION_VALUE_EMBEDDED])
        {
            application.webviewType = MSALWebviewTypeWKWebView;
        }
        else if ([webviewSelection isEqualToString:MSAL_AUTOMATION_WEBVIEWSELECTION_VALUE_SYSTEM])
        {
            application.webviewType = MSALWebviewTypeDefault;
        }
        else if ([webviewSelection isEqualToString:MSAL_AUTOMATION_WEBVIEWSELECTION_VALUE_SAFARI])
        {
            application.webviewType = MSALWebviewTypeSafariViewController;
        }
        else if ([webviewSelection isEqualToString:MSAL_AUTOMATION_WEBVIEWSELECTION_VALUE_PASSED])
        {
            application.webviewType = MSALWebviewTypeWKWebView;
            application.customWebview = self.passedInController.webView;
            [self.presentedViewController presentViewController:self.passedInController animated:NO completion:nil];
        }
        
        if (account)
        {
            [application acquireTokenForScopes:[scopes array]
                          extraScopesToConsent:extraScopes
                                       account:account
                                    uiBehavior:uiBehavior
                          extraQueryParameters:extraQueryParameters
                                        claims:claims
                                     authority:nil // Will use the authority passed in with the application object
                                 correlationId:correlationId
                               completionBlock:^(MSALResult *result, NSError *error)
             {
                 [self handleMSALResult:result error:error];
             }];
        }
        else
        {
            NSString *loginHint = parameters[MSAL_LOGIN_HINT_PARAM];
            
            [application acquireTokenForScopes:[scopes array]
                          extraScopesToConsent:extraScopes
                                     loginHint:loginHint
                                    uiBehavior:uiBehavior
                          extraQueryParameters:extraQueryParameters
                                     authority:nil
                                 correlationId:correlationId
                               completionBlock:^(MSALResult *result, NSError *error) {
                                   
                                   [self handleMSALResult:result error:error];
                               }];
        }
    };
    
    [self performSegueWithIdentifier:SHOW_REQUEST_SEGUE sender:@{COMPLETION_BLOCK_PARAM : completionBlock}];
    
}

- (IBAction)acquireTokenSilent:(id)sender
{
    (void)sender;
    
    MSALAutoParamBlock completionBlock = ^void (NSDictionary<NSString *, NSString *> * parameters)
    {
        if (![self checkParametersError:parameters])
        {
            return;
        }
        
        MSALPublicClientApplication *application = [self applicationWithParameters:parameters];
        
        if (!application)
        {
            return;
        }
        
        MSALAccount *account = [self accountWithParameters:parameters application:application];
        
        if (!account)
        {
            // Acquiretoken silent requires having a user
            [self dismissViewControllerAnimated:NO
                                     completion:^{
                                         [self displayResultJson:@"{\"error_code\":\"no_account\"}" logs:_resultLogs];
                                     }];
            
            return;
        }

        NSOrderedSet *scopes = [NSOrderedSet msidOrderedSetFromString:parameters[MSAL_SCOPES_PARAM]];
        BOOL forceRefresh = parameters[MSAL_FORCE_REFRESH_PARAM] ? [parameters[MSAL_FORCE_REFRESH_PARAM] boolValue] : NO;
        NSUUID *correlationId = parameters[MSAL_CORRELATION_ID_PARAM] ? [[NSUUID alloc] initWithUUIDString:parameters[MSAL_CORRELATION_ID_PARAM]] : nil;

        MSALAuthority *silentAuthority = nil;

        if (parameters[MSAL_SILENT_AUTHORITY_PARAM])
        {
            // In case we want to pass a different authority to silent call, we can use "silent authority" parameter
            silentAuthority = [MSALAuthority authorityWithURL:[NSURL URLWithString:parameters[MSAL_SILENT_AUTHORITY_PARAM]] error:nil];
        }
        
        [application acquireTokenSilentForScopes:[scopes array]
                                         account:account
                                       authority:silentAuthority
                                    forceRefresh:forceRefresh
                                   correlationId:correlationId
                                 completionBlock:^(MSALResult *result, NSError *error)
         {
             [self handleMSALResult:result error:error];
         }];
    };
    
    [self performSegueWithIdentifier:SHOW_REQUEST_SEGUE sender:@{COMPLETION_BLOCK_PARAM : completionBlock}];
}

#pragma mark - Cache

- (IBAction)expireAccessToken:(__unused id)sender
{
    MSALAutoParamBlock completionBlock = ^void (NSDictionary<NSString *, NSString *> * parameters)
    {
        if (![self checkParametersError:parameters])
        {
            return;
        }
        
        __auto_type authorityFactory = [MSALAuthorityFactory new];
        __auto_type authorityUrl = [NSURL URLWithString:parameters[MSAL_AUTHORITY_PARAM]];
        __auto_type authority = [authorityFactory authorityFromUrl:authorityUrl context:nil error:nil];
        
        MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil
                                                                                  homeAccountId:parameters[MSAL_ACCOUNT_IDENTIFIER_PARAM]];
        
        MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority.msidAuthority
                                                                            redirectUri:nil
                                                                               clientId:parameters[MSAL_CLIENT_ID_PARAM]
                                                                                 target:parameters[MSAL_SCOPES_PARAM]];
        
        __auto_type accessToken = [self.defaultAccessor getAccessTokenForAccount:account configuration:configuration context:nil error:nil];
        accessToken.expiresOn = [NSDate dateWithTimeIntervalSinceNow:-1.0];
        
        BOOL result = [self.accountCredentialCache saveCredential:accessToken.tokenCacheItem context:nil error:nil];
        
        NSString *resultString = [NSString stringWithFormat:@"{\"%@\":\"%@\"}", MSAL_EXPIRED_ACCESSTOKEN_COUNT_PARAM, accessToken && result ? @"1" : @"0"];
        [self displayOperationResultString:resultString];
    };
    
    [self performSegueWithIdentifier:SHOW_REQUEST_SEGUE sender:@{COMPLETION_BLOCK_PARAM : completionBlock}];
}

- (IBAction)invalidateRefreshToken:(__unused id)sender
{
    (void)sender;
    
    MSALAutoParamBlock completionBlock = ^void (NSDictionary<NSString *, NSString *> * parameters)
    {
        if (![self checkParametersError:parameters])
        {
            return;
        }
        
        __auto_type authorityFactory = [MSIDAuthorityFactory new];
        __auto_type authorityUrl = [NSURL URLWithString:parameters[MSAL_AUTHORITY_PARAM]];
        __auto_type authority = [authorityFactory authorityFromUrl:authorityUrl context:nil error:nil];
        
        MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:parameters[MSAL_ACCOUNT_IDENTIFIER_PARAM]];
        
        MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                            redirectUri:nil
                                                                               clientId:parameters[MSAL_CLIENT_ID_PARAM]
                                                                                 target:parameters[MSAL_SCOPES_PARAM]];
        
        __auto_type refreshToken = [self.defaultAccessor getRefreshTokenWithAccount:account
                                                                           familyId:nil
                                                                      configuration:configuration
                                                                            context:nil
                                                                              error:nil];
        
        refreshToken.refreshToken = @"bad-refresh-token";
        
        BOOL result = [self.accountCredentialCache saveCredential:refreshToken.tokenCacheItem context:nil error:nil];
        NSString *resultString = [NSString stringWithFormat:@"{\"%@\":\"%@\"}", MSAL_INVALIDATED_REFRESH_TOKEN_PARAM, result ? MSAL_AUTOMATION_SUCCESS_VALUE : MSAL_AUTOMATION_FAILURE_VALUE];
        
        [self displayOperationResultString:resultString];
    };
    
    [self performSegueWithIdentifier:SHOW_REQUEST_SEGUE sender:@{COMPLETION_BLOCK_PARAM : completionBlock}];
}

- (IBAction)clearKeychain:(__unused id)sender
{
    NSArray *secItemClasses = @[(__bridge id)kSecClassGenericPassword,
                                (__bridge id)kSecClassInternetPassword,
                                (__bridge id)kSecClassCertificate,
                                (__bridge id)kSecClassKey,
                                (__bridge id)kSecClassIdentity];
    
    for (NSString *itemClass in secItemClasses)
    {
        NSDictionary *clearQuery = @{(id)kSecClass : (id)itemClass};
        SecItemDelete((CFDictionaryRef)clearQuery);
    }
    [self displayResultJson:@"{\"result\":\"1\"}" logs:_resultLogs];
}

- (IBAction)clearCookies:(id)sender
{
    NSHTTPCookieStorage *cookieStore = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    int count = 0;
    for (NSHTTPCookie *cookie in cookieStore.cookies)
    {
        [cookieStore deleteCookie:cookie];
        count++;
    }
    
    // Clear WKWebView cookies
    NSSet *allTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:allTypes
                                               modifiedSince:[NSDate dateWithTimeIntervalSince1970:0]
                                           completionHandler:^{
                                               NSLog(@"Completed!");
                                           }];
    
    NSString *resultJson = [NSString stringWithFormat:@"{\"cleared_items_count\":\"%lu\"}", (unsigned long)count];
    [self displayResultJson:resultJson logs:_resultLogs];
}

- (IBAction)openURLInSafari:(id)sender
{
    void (^completionBlock)(NSDictionary<NSString *, NSString *> * parameters) = ^void(NSDictionary<NSString *, NSString *> * parameters) {
        
        [self dismissViewControllerAnimated:NO
                                 completion:^{
                                     [self displayResultJson:@"{\"success\":\"1\"}" logs:_resultLogs];
                                 }];
        
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:parameters[@"safari_url"]]];
    };
    
    [self performSegueWithIdentifier:SHOW_REQUEST_SEGUE sender:@{COMPLETION_BLOCK_PARAM : completionBlock}];
}

- (IBAction)readCache:(__unused id)sender
{
    NSMutableDictionary *cacheDictionary = [NSMutableDictionary dictionary];
    
    NSMutableArray *allTokens = [[self.defaultAccessor allTokensWithContext:nil error:nil] mutableCopy];
    [allTokens addObjectsFromArray:[self.legacyAccessor allTokensWithContext:nil error:nil]];
    [cacheDictionary setObject:@(allTokens.count) forKey:MSAL_ITEM_COUNT_PARAM];
    
    NSMutableArray *accessTokenItems = [NSMutableArray array];
    NSMutableArray *refreshTokenItems = [NSMutableArray array];
    NSMutableArray *idTokenItems = [NSMutableArray array];
    
    for (MSIDBaseToken *token in allTokens)
    {
        if (token.credentialType == MSIDAccessTokenType)
        {
            [accessTokenItems addObject:[token.tokenCacheItem itemAsDictionary]];
        }
        else if (token.credentialType == MSIDRefreshTokenType)
        {
            [refreshTokenItems addObject:[token.tokenCacheItem itemAsDictionary]];
        }
        else if (token.credentialType == MSIDIDTokenType)
        {
            [idTokenItems addObject:[token.tokenCacheItem itemAsDictionary]];
        }
    }
    
    [cacheDictionary setObject:refreshTokenItems forKey:MSAL_REFRESH_TOKENS_PARAM];
    [cacheDictionary setObject:accessTokenItems forKey:MSAL_ACCESS_TOKENS_PARAM];
    [cacheDictionary setObject:idTokenItems forKey:MSAL_ID_TOKENS_PARAM];
    
    [self displayResultJson:[self createJsonStringFromDictionary:cacheDictionary]
                       logs:_resultLogs];
}

#pragma mark - Users

- (IBAction)signOut:(__unused id)sender
{
    MSALAutoParamBlock completionBlock = ^void (NSDictionary<NSString *, NSString *> * parameters)
    {
        if (![self checkParametersError:parameters])
        {
            return;
        }
        
        MSALPublicClientApplication *application = [self applicationWithParameters:parameters];
        
        if (!application)
        {
            NSString *resultString = [NSString stringWithFormat:@"{\"%@\":\"%@\"}", MSAL_SIGNOUT_RESULT_PARAM, MSAL_AUTOMATION_FAILURE_VALUE];
            [self displayOperationResultString:resultString];
            return;
        }
        
        NSError *error = nil;
        MSALAccount *account = [application accountForHomeAccountId:parameters[MSAL_ACCOUNT_IDENTIFIER_PARAM] error:&error];
        
        if (error)
        {
            NSString *resultString = [NSString stringWithFormat:@"{\"%@\":\"%@\"}", MSAL_SIGNOUT_RESULT_PARAM, MSAL_AUTOMATION_FAILURE_VALUE];
            [self displayOperationResultString:resultString];
            return;
        }
        
        BOOL result = [application removeAccount:account error:&error];
        
        NSString *resultString = [NSString stringWithFormat:@"{\"%@\":\"%@\"}", MSAL_SIGNOUT_RESULT_PARAM, result ? MSAL_AUTOMATION_SUCCESS_VALUE : MSAL_AUTOMATION_FAILURE_VALUE];
        
        [self displayOperationResultString:resultString];
    };
    
    [self performSegueWithIdentifier:SHOW_REQUEST_SEGUE sender:@{COMPLETION_BLOCK_PARAM : completionBlock}];
}

- (IBAction)getUsers:(id)sender
{
    (void)sender;
    
    MSALAutoParamBlock completionBlock = ^void (NSDictionary<NSString *, NSString *> * parameters)
    {
        if (![self checkParametersError:parameters])
        {
            return;
        }
        
        MSALPublicClientApplication *application = [self applicationWithParameters:parameters];
        
        if (!application)
        {
            return;
        }
        
        NSError *error = nil;
        NSArray *users = [application allAccounts:nil];
        
        if (error)
        {
            [self displayError:error];
            return;
        }
        
        NSMutableDictionary *resultDictionary = [NSMutableDictionary dictionary];
        [resultDictionary setObject:@([users count]) forKey:MSAL_USER_COUNT_PARAM];
        
        NSMutableArray *items = [NSMutableArray array];
        
        for (MSALAccount *user in users)
        {
            [items addObject:[user itemAsDictionary]];
        }
        
        [resultDictionary setObject:items forKey:MSAL_USERS_PARAM];
        
        [self displayOperationResultString:[self createJsonStringFromDictionary:resultDictionary]];
    };
    
    [self performSegueWithIdentifier:SHOW_REQUEST_SEGUE sender:@{COMPLETION_BLOCK_PARAM : completionBlock}];
}

#pragma mark - Helpers

- (void)displayError:(NSError *)error
{
    [self displayOperationResultString:[self createJsonStringFromError:error]];
}

- (void)displayResultJson:(NSString *)resultJson logs:(NSString *)resultLogs
{
    [self performSegueWithIdentifier:SHOW_RESULT_SEGUE sender:@{RESULT_INFO_PARAM : resultJson ? resultJson : @"",
                                                                RESULT_LOGS_PARAM : resultLogs ? resultLogs : @""}];
}

- (NSString *)createJsonStringFromError:(NSError *)error
{
    NSString *errorString = [NSString stringWithFormat:@"Error Domain=%@ Code=%ld Description=%@", error.domain, (long)error.code, error.localizedDescription];
    
    NSMutableDictionary *errorDictionary = [NSMutableDictionary new];
    errorDictionary[@"error_title"] = errorString;
    
    if ([error.domain isEqualToString:MSALErrorDomain])
    {
        errorDictionary[@"error_code"] = MSALStringForErrorCode(error.code);
        errorDictionary[@"error_description"] = error.userInfo[MSALErrorDescriptionKey];
        
        if (error.userInfo[MSALOAuthSubErrorKey])
        {
            errorDictionary[@"subcode"] = error.userInfo[MSALOAuthSubErrorKey];
        }

        if (error.userInfo[NSUnderlyingErrorKey])
        {
            errorDictionary[@"underlying_error"] = [error.userInfo[NSUnderlyingErrorKey] description];
        }

        NSMutableDictionary *userInfo = [error.userInfo mutableCopy];
        [userInfo removeObjectForKey:NSUnderlyingErrorKey];

        errorDictionary[@"user_info"] = userInfo;
    }
    else if ([error.domain isEqualToString:MSIDErrorDomain])
    {
        @throw @"MSID errors should never be seen in MSAL";
    }
    
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:errorDictionary options:0 error:nil] encoding:NSUTF8StringEncoding];
}

- (NSString *)createJsonStringFromDictionary:(NSDictionary *)dictionary
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    
    if (!jsonData)
    {
        return [NSString stringWithFormat:@"{\"error\" : \"%@\"}", error.description];
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSString *)createJsonFromResult:(MSALResult *)result
{
    return [self createJsonStringFromDictionary:[result itemAsDictionary]];
}

- (void)displayOperationResultString:(NSString *)operationResult
{
    [self dismissViewControllerAnimated:NO completion:^{
        [self displayResultJson:operationResult
                           logs:_resultLogs];
    }];
}

@end
