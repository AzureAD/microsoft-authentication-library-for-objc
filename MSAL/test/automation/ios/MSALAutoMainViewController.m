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
#import "MSALLogger+Internal.h"

#import "MSALAutoMainViewController.h"
#import "MSALAutoResultViewController.h"
#import "MSALAutoRequestViewController.h"
#import "MSALAccessTokenCacheItem+TestAppUtil.h"

#import "MSALAccessTokenCacheItem+Automation.h"
#import "MSALRefreshTokenCacheItem+Automation.h"
#import "MSALUser+Automation.h"
#import "MSALResult+Automation.h"

#import "MSALAutomationConstants.h"

#import "MSAL.h"

@interface MSALAutoMainViewController ()
{
    NSMutableString *_resultLogs;
}

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
    
    NSError *error = nil;
    
    MSALPublicClientApplication *clientApplication =
    [[MSALPublicClientApplication alloc] initWithClientId:parameters[MSAL_CLIENT_ID_PARAM]
                                                authority:parameters[MSAL_AUTHORITY_PARAM]
                                                    error:&error];
    
    clientApplication.validateAuthority = validateAuthority;
    
    if (error)
    {
        [self displayError:error];
        return nil;
    }
    
    return clientApplication;
}

- (MSALUser *)userWithParameters:(NSDictionary<NSString *, NSString *> *)parameters
                     application:(MSALPublicClientApplication *)application
{
    NSString *userIdentifier = parameters[MSAL_USER_IDENTIFIER_PARAM];
    MSALUser *user = nil;
    
    NSError *error = nil;
    
    if (userIdentifier)
    {
        user = [application userForIdentifier:userIdentifier error:&error];
        
        if (error)
        {
            [self displayResultJson:[self createJsonStringFromError:error]
                               logs:_resultLogs];
            return nil;
        }
    }
    
    return user;
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
        
        MSALUser *user = [self userWithParameters:parameters application:application]; // User is not required for acquiretoken
        
        NSArray *scopes = (NSArray *)parameters[MSAL_SCOPES_PARAM];
        NSArray *extraScopes = (NSArray *)parameters[MSAL_EXTRA_SCOPES_PARAM];
        NSDictionary *extraQueryParameters = (NSDictionary *)parameters[MSAL_EXTRA_QP_PARAM];
        NSUUID *correlationId = parameters[MSAL_CORRELATION_ID_PARAM] ? [[NSUUID alloc] initWithUUIDString:parameters[MSAL_CORRELATION_ID_PARAM]] : nil;
        
        [application acquireTokenForScopes:scopes
                      extraScopesToConsent:extraScopes
                                      user:user
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
        
        MSALUser *user = [self userWithParameters:parameters application:application];
        
        if (!user)
        {
            // Acquiretoken silent requires having a user
            return;
        }
        
        NSArray *scopes = (NSArray *)parameters[MSAL_SCOPES_PARAM];
        BOOL forceRefresh = parameters[MSAL_FORCE_REFRESH_PARAM] ? [parameters[MSAL_FORCE_REFRESH_PARAM] boolValue] : NO;
        NSUUID *correlationId = parameters[MSAL_CORRELATION_ID_PARAM] ? [[NSUUID alloc] initWithUUIDString:parameters[MSAL_CORRELATION_ID_PARAM]] : nil;
        
        [application acquireTokenSilentForScopes:scopes
                                            user:user
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

- (IBAction)expireAccessToken:(id)sender
{
    (void)sender;
    
    MSALAutoParamBlock completionBlock = ^void (NSDictionary<NSString *, NSString *> * parameters)
    {
        if (![self checkParametersError:parameters])
        {
            return;
        }
        
        MSALKeychainTokenCache *cache = MSALKeychainTokenCache.defaultKeychainCache;
        
        MSALScopes *scopes = [NSOrderedSet orderedSetWithArray:(NSArray *)parameters[MSAL_SCOPES_PARAM]];
        
        MSALAccessTokenCacheKey *tokenCacheKey = [[MSALAccessTokenCacheKey alloc] initWithAuthority:parameters[MSAL_AUTHORITY_PARAM]
                                                                                           clientId:parameters[MSAL_CLIENT_ID_PARAM]
                                                                                              scope:scopes
                                                                                     userIdentifier:parameters[MSAL_USER_IDENTIFIER_PARAM]
                                                                                        environment:parameters[MSAL_USER_ENVIRONMENT_PARAM]];
        
        NSArray *tokenCacheItems = [cache getAccessTokenItemsWithKey:tokenCacheKey context:nil error:nil];
        
        NSUInteger accessTokenCount = 0;
        
        for (MSALAccessTokenCacheItem *item in tokenCacheItems)
        {
            item.expiresOnString = [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate dateWithTimeIntervalSinceNow:-1.0] timeIntervalSince1970]];
            [cache addOrUpdateAccessTokenItem:item context:nil error:nil];
            accessTokenCount++;
        }
        
        NSString *resultString = [NSString stringWithFormat:@"{\"%@\":\"%lu\"}", MSAL_EXPIRED_ACCESSTOKEN_COUNT_PARAM, (unsigned long)accessTokenCount];
        [self displayOperationResultString:resultString];
    };
    
    [self performSegueWithIdentifier:SHOW_REQUEST_SEGUE sender:@{COMPLETION_BLOCK_PARAM : completionBlock}];
}

- (IBAction)invalidateRefreshToken:(id)sender
{
    (void)sender;
    
    MSALAutoParamBlock completionBlock = ^void (NSDictionary<NSString *, NSString *> * parameters)
    {
        if (![self checkParametersError:parameters])
        {
            return;
        }
        
        MSALKeychainTokenCache *cache = MSALKeychainTokenCache.defaultKeychainCache;
        
        MSALRefreshTokenCacheKey *tokenCacheKey = [[MSALRefreshTokenCacheKey alloc] initWithEnvironment:parameters[MSAL_USER_ENVIRONMENT_PARAM]
                                                                                               clientId:parameters[MSAL_CLIENT_ID_PARAM]
                                                                                         userIdentifier:parameters[MSAL_USER_IDENTIFIER_PARAM]];
        
        MSALRefreshTokenCacheItem *tokenCacheItem = [cache getRefreshTokenItemForKey:tokenCacheKey context:nil error:nil];
        
        if (tokenCacheItem)
        {
            tokenCacheItem.refreshToken = BAD_REFRESH_TOKEN;
            [cache addOrUpdateRefreshTokenItem:tokenCacheItem context:nil error:nil];
        }
        
        NSString *resultString = [NSString stringWithFormat:@"{\"%@\":\"%@\"}", MSAL_INVALIDATED_REFRESH_TOKEN_PARAM, tokenCacheItem ? MSAL_AUTOMATION_SUCCESS_VALUE : MSAL_AUTOMATION_FAILURE_VALUE];
        
        [self displayOperationResultString:resultString];
    };
    
    [self performSegueWithIdentifier:SHOW_REQUEST_SEGUE sender:@{COMPLETION_BLOCK_PARAM : completionBlock}];
}

- (IBAction)clearCache:(id)sender
{
    (void)sender;
    
    MSALKeychainTokenCache *cache = MSALKeychainTokenCache.defaultKeychainCache;
    
    NSArray *allAccessTokenItems = [cache getAccessTokenItemsWithKey:nil context:nil error:nil];
    NSArray *allRefreshTokenItems = [cache allRefreshTokens:nil context:nil error:nil];
    
    NSUInteger allCount = allAccessTokenItems.count + allRefreshTokenItems.count;
    
    [cache testRemoveAll];
    
    NSString *resultCountsString = [NSString stringWithFormat:@"{\"%@\":\"%lu\"}", MSAL_CLEARED_TOKENS_COUNT_PARAM, (unsigned long)allCount];
    [self displayResultJson:resultCountsString logs:_resultLogs];
}

- (IBAction)readCache:(id)sender
{
    (void)sender;
    
    MSALKeychainTokenCache *cache = MSALKeychainTokenCache.defaultKeychainCache;
    
    NSArray *allAccessTokenItems = [cache getAccessTokenItemsWithKey:nil context:nil error:nil];
    NSArray *allRefreshTokenItems = [cache allRefreshTokens:nil context:nil error:nil];
    
    NSMutableDictionary *cacheDictionary = [NSMutableDictionary dictionary];
    NSUInteger allCount = allAccessTokenItems.count + allRefreshTokenItems.count;
    
    [cacheDictionary setObject:@(allCount) forKey:MSAL_ITEM_COUNT_PARAM];
    
    NSMutableArray *accessTokenItems = [NSMutableArray array];
    
    for (MSALAccessTokenCacheItem *accessToken in allAccessTokenItems)
    {
        [accessTokenItems addObject:[accessToken itemAsDictionary]];
    }
    
    [cacheDictionary setObject:accessTokenItems forKey:MSAL_ACCESS_TOKENS_PARAM];
    
    NSMutableArray *refreshTokenItems = [NSMutableArray array];
    
    for (MSALRefreshTokenCacheItem *refreshToken in allRefreshTokenItems)
    {
        [refreshTokenItems addObject:[refreshToken itemAsDictionary]];
    }
    
    [cacheDictionary setObject:refreshTokenItems forKey:MSAL_REFRESH_TOKENS_PARAM];
    
    [self displayResultJson:[self createJsonStringFromDictionary:cacheDictionary]
                       logs:_resultLogs];
}

#pragma mark - Users

- (IBAction)signOut:(id)sender
{
    (void)sender;
    
    MSALAutoParamBlock completionBlock = ^void (NSDictionary<NSString *, NSString *> * parameters)
    {
        if (![self checkParametersError:parameters])
        {
            return;
        }
        
        MSALKeychainTokenCache *cache = MSALKeychainTokenCache.defaultKeychainCache;
        
        BOOL result = [cache removeAllTokensForUserIdentifier:parameters[MSAL_USER_IDENTIFIER_PARAM]
                                                  environment:parameters[MSAL_USER_ENVIRONMENT_PARAM]
                                                     clientId:parameters[MSAL_CLIENT_ID_PARAM]
                                                      context:nil
                                                        error:nil];
        
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
        NSArray *users = [application users:nil];
        
        if (error)
        {
            [self displayError:error];
            return;
        }
        
        NSMutableDictionary *resultDictionary = [NSMutableDictionary dictionary];
        [resultDictionary setObject:@([users count]) forKey:MSAL_USER_COUNT_PARAM];
        
        NSMutableArray *items = [NSMutableArray array];
        
        for (MSALUser *user in users)
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
