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

@interface MSALAutoMainViewController ()
{
    NSMutableString *_resultLogs;
}

@property (nonatomic) MSIDDefaultTokenCacheAccessor *defaultAccessor;
@property (nonatomic) MSIDLegacyTokenCacheAccessor *legacyAccessor;
@property (nonatomic) MSIDAccountCredentialCache *accountCredentialCache;

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

- (MSALPublicClientApplication *)applicationWithParameters:(NSDictionary<NSString *, NSString *> *)parameters
{
    BOOL validateAuthority = parameters[MSAL_VALIDATE_AUTHORITY_PARAM] ? [parameters[MSAL_VALIDATE_AUTHORITY_PARAM] boolValue] : YES;
    __auto_type authorityUrl = [[NSURL alloc] initWithString:parameters[MSAL_AUTHORITY_PARAM]];
    __auto_type authorityFactory = [MSALAuthorityFactory new];
    __auto_type authority = [authorityFactory authorityFromUrl:authorityUrl context:nil error:nil];
    
    NSError *error = nil;
    
    MSALPublicClientApplication *clientApplication =
    [[MSALPublicClientApplication alloc] initWithClientId:parameters[MSAL_CLIENT_ID_PARAM]
                                                authority:authority
                                                    error:&error];
    
    clientApplication.validateAuthority = validateAuthority;
    
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
    NSString *accountIdentifier = parameters[MSAL_USER_IDENTIFIER_PARAM];
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
        
        NSArray *scopes = (NSArray *)parameters[MSAL_SCOPES_PARAM];
        NSArray *extraScopes = (NSArray *)parameters[MSAL_EXTRA_SCOPES_PARAM];
        NSDictionary *extraQueryParameters = (NSDictionary *)parameters[MSAL_EXTRA_QP_PARAM];
        NSUUID *correlationId = parameters[MSAL_CORRELATION_ID_PARAM] ? [[NSUUID alloc] initWithUUIDString:parameters[MSAL_CORRELATION_ID_PARAM]] : nil;
        
        [application acquireTokenForScopes:scopes
                      extraScopesToConsent:extraScopes
                                   account:account
                                uiBehavior:MSALUIBehaviorDefault
                      extraQueryParameters:extraQueryParameters
                                 authority:nil // Will use the authority passed in with the application object
                             correlationId:correlationId
                           completionBlock:^(MSALResult *result, NSError *error)
         {
             [self handleMSALResult:result error:error];
         }];
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
            return;
        }
        
        NSArray *scopes = (NSArray *)parameters[MSAL_SCOPES_PARAM];
        BOOL forceRefresh = parameters[MSAL_FORCE_REFRESH_PARAM] ? [parameters[MSAL_FORCE_REFRESH_PARAM] boolValue] : NO;
        NSUUID *correlationId = parameters[MSAL_CORRELATION_ID_PARAM] ? [[NSUUID alloc] initWithUUIDString:parameters[MSAL_CORRELATION_ID_PARAM]] : nil;
        
        [application acquireTokenSilentForScopes:scopes
                                         account:account
                                       authority:nil
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
        __auto_type authorityUrl = [parameters[MSAL_AUTHORITY_PARAM] msidUrl];
        __auto_type authority = [authorityFactory authorityFromUrl:authorityUrl context:nil error:nil];
        
        MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:parameters[MSAL_USER_IDENTIFIER_PARAM]];
        MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority.msidAuthority
                                                                            redirectUri:nil
                                                                               clientId:parameters[MSAL_CLIENT_ID_PARAM]
                                                                                 target:parameters[MSAL_SCOPES_PARAM]];

        __auto_type accessToken = [self.defaultAccessor getAccessTokenForAccount:account configuration:configuration context:nil error:nil];
        accessToken.expiresOn = [NSDate dateWithTimeIntervalSinceNow:-1.0];

        BOOL resut = [self.accountCredentialCache saveCredential:accessToken.tokenCacheItem context:nil error:nil];

        NSString *resultString = [NSString stringWithFormat:@"{\"%@\":\"%@\"}", MSAL_EXPIRED_ACCESSTOKEN_COUNT_PARAM, resut ? MSAL_AUTOMATION_SUCCESS_VALUE : MSAL_AUTOMATION_FAILURE_VALUE];
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
        
        __auto_type authorityFactory = [MSALAuthorityFactory new];
        __auto_type authorityUrl = [parameters[MSAL_AUTHORITY_PARAM] msidUrl];
        __auto_type authority = [authorityFactory authorityFromUrl:authorityUrl context:nil error:nil];

        MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:nil homeAccountId:parameters[MSAL_USER_IDENTIFIER_PARAM]];
        MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:authority.msidAuthority
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

- (IBAction)clearCache:(__unused id)sender
{
    NSUInteger allCount = [self.defaultAccessor allTokensWithContext:nil error:nil].count;
    allCount += [self.legacyAccessor allTokensWithContext:nil error:nil].count;
    [self.defaultAccessor clearWithContext:nil error:nil];
    [self.legacyAccessor clearWithContext:nil error:nil];

    NSString *resultCountsString = [NSString stringWithFormat:@"{\"%@\":\"%lu\"}", MSAL_CLEARED_TOKENS_COUNT_PARAM, (unsigned long)allCount];
    [self displayResultJson:resultCountsString logs:_resultLogs];
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
        MSALAccount *account = [application accountForHomeAccountId:parameters[MSAL_USER_IDENTIFIER_PARAM] error:&error];

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
        NSArray *users = [application accounts:nil];
        
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
    return [NSString stringWithFormat:@"{\"error\" : \"%@\"}", errorString];
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
