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

#import "MSAL.h"

@interface MSALAutoMainViewController ()
{
    NSMutableString *_resultLogs;
}

@end

@implementation MSALAutoMainViewController

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
    
    if ([segue.identifier isEqualToString:@"showRequest"])
    {
        MSALAutoRequestViewController *requestVC = segue.destinationViewController;
        requestVC.completionBlock = sender[@"completionBlock"];
    }
    
    
    if ([segue.identifier isEqualToString:@"showResult"])
    {
        MSALAutoResultViewController *resultVC = segue.destinationViewController;
        resultVC.resultInfoString = sender[@"resultInfo"];
        resultVC.resultLogsString = sender[@"resultLogs"];
    }
}

#pragma mark - Utils

- (BOOL)parametersHaveError:(NSDictionary<NSString *, NSString *> *)parameters
{
    _resultLogs = [NSMutableString new];
    
    if (parameters[@"error"])
    {
        [self dismissViewControllerAnimated:NO completion:^{
            [self displayResultJson:parameters[@"error"]
                               logs:_resultLogs];
        }];
        
        return YES;
    }
    
    return NO;
}

- (MSALPublicClientApplication *)applicationWithParameters:(NSDictionary<NSString *, NSString *> *)parameters
{
    BOOL validateAuthority = parameters[@"validate_authority"] ? [parameters[@"validate_authority"] boolValue] : YES;
    
    NSError *error = nil;
    
    MSALPublicClientApplication *clientApplication =
    [[MSALPublicClientApplication alloc] initWithClientId:parameters[@"client_id"]
                                                authority:parameters[@"authority"]
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
    NSString *userIdentifier = parameters[@"user_identifier"];
    MSALUser *user = nil;
    
    NSError *error = nil;
    
    if (userIdentifier)
    {
        user = [application userForIdentifier:userIdentifier error:&error];
        
        if (error)
        {
            [self displayError:error];
            return nil;
        }
    }
    
    return user;
}

- (void)handleMSALResult:(MSALResult *)result error:(NSError *)error
{
    [self dismissViewControllerAnimated:NO
                             completion:^{
                                 
                                 if (error)
                                 {
                                     [self displayError:error];
                                 }
                                 else
                                 {
                                     [self displayResultJson:[self createJsonFromResult:result]
                                                        logs:_resultLogs];
                                 }
                             }];
}

#pragma mark - AcquireToken

- (IBAction)acquireToken:(id)sender
{
    (void)sender;
    
    MSALAutoParamBlock completionBlock = ^void (NSDictionary<NSString *, NSString *> * parameters)
    {
        if ([self parametersHaveError:parameters])
        {
            return;
        }
        
        MSALPublicClientApplication *application = [self applicationWithParameters:parameters];
        
        if (!application)
        {
            return;
        }
        
        MSALUser *user = [self userWithParameters:parameters application:application]; // User is not required for acquiretoken
        
        NSArray *scopes = (NSArray *)parameters[@"scopes"];
        NSArray *extraScopes = (NSArray *)parameters[@"extra_scopes"];
        NSDictionary *extraQueryParameters = (NSDictionary *)parameters[@"extra_qp"];
        NSUUID *correlationId = parameters[@"correlation_id"] ? [[NSUUID alloc] initWithUUIDString:parameters[@"correlation_id"]] : nil;
        
        [application acquireTokenForScopes:scopes
                      extraScopesToConsent:extraScopes
                                      user:user
                                uiBehavior:MSALUIBehaviorDefault
                      extraQueryParameters:extraQueryParameters
                                 authority:nil // Will use the authority passed in the application object
                             correlationId:correlationId
                           completionBlock:^(MSALResult *result, NSError *error)
         {
             [self handleMSALResult:result error:error];
         }];
    };
    
    [self performSegueWithIdentifier:@"showRequest" sender:@{@"completionBlock" : completionBlock}];
    
}

- (IBAction)acquireTokenSilent:(id)sender
{
    (void)sender;
    
    MSALAutoParamBlock completionBlock = ^void (NSDictionary<NSString *, NSString *> * parameters)
    {
        if ([self parametersHaveError:parameters])
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
        
        NSArray *scopes = (NSArray *)parameters[@"scopes"];
        BOOL forceRefresh = parameters[@"force_refresh"] ? [parameters[@"force_refresh"] boolValue] : NO;
        NSUUID *correlationId = parameters[@"correlation_id"] ? [[NSUUID alloc] initWithUUIDString:parameters[@"correlation_id"]] : nil;
        
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
    
    [self performSegueWithIdentifier:@"showRequest" sender:@{@"completionBlock" : completionBlock}];
}

#pragma mark - Cache

- (IBAction)expireAccessToken:(id)sender
{
    (void)sender;
    
    MSALAutoParamBlock completionBlock = ^void (NSDictionary<NSString *, NSString *> * parameters)
    {
        if ([self parametersHaveError:parameters])
        {
            return;
        }
        
        MSALKeychainTokenCache *cache = MSALKeychainTokenCache.defaultKeychainCache;
        
        MSALScopes *scopes = [NSOrderedSet orderedSetWithArray:(NSArray *)parameters[@"scopes"]];
        
        MSALAccessTokenCacheKey *tokenCacheKey = [[MSALAccessTokenCacheKey alloc] initWithAuthority:parameters[@"authority"]
                                                                                           clientId:parameters[@"client_id"]
                                                                                              scope:scopes
                                                                                     userIdentifier:parameters[@"user_identifier"]
                                                                                        environment:parameters[@"user_environment"]];
        
        NSArray *tokenCacheItems = [cache getAccessTokenItemsWithKey:tokenCacheKey context:nil error:nil];
        
        NSUInteger accessTokenCount = 0;
        
        for (MSALAccessTokenCacheItem *item in tokenCacheItems)
        {
            item.expiresOnString = [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate dateWithTimeIntervalSinceNow:-1.0] timeIntervalSince1970]];
            [cache addOrUpdateAccessTokenItem:item context:nil error:nil];
            accessTokenCount++;
        }
        
        [self dismissViewControllerAnimated:NO completion:^{
            [self displayResultJson:[NSString stringWithFormat:@"{\"expired_access_token_count\":\"%lu\"}", (unsigned long)accessTokenCount]
                               logs:_resultLogs];
        }];
    };
    
    [self performSegueWithIdentifier:@"showRequest" sender:@{@"completionBlock" : completionBlock}];
}

- (IBAction)invalidateRefreshToken:(id)sender
{
    (void)sender;
    
    MSALAutoParamBlock completionBlock = ^void (NSDictionary<NSString *, NSString *> * parameters)
    {
        if ([self parametersHaveError:parameters])
        {
            return;
        }
        
        MSALKeychainTokenCache *cache = MSALKeychainTokenCache.defaultKeychainCache;
        
        MSALRefreshTokenCacheKey *tokenCacheKey = [[MSALRefreshTokenCacheKey alloc] initWithEnvironment:parameters[@"user_environment"]
                                                                                               clientId:parameters[@"client_id"]
                                                                                         userIdentifier:parameters[@"user_identifier"]];
        
        MSALRefreshTokenCacheItem *tokenCacheItem = [cache getRefreshTokenItemForKey:tokenCacheKey context:nil error:nil];
        
        if (tokenCacheItem)
        {
            tokenCacheItem.refreshToken = BAD_REFRESH_TOKEN;
            [cache addOrUpdateRefreshTokenItem:tokenCacheItem context:nil error:nil];
        }
        
        [self dismissViewControllerAnimated:NO completion:^{
            [self displayResultJson:[NSString stringWithFormat:@"{\"invalidated_refresh_token\":\"%@\"}", tokenCacheItem ? @"yes" : @"no"]
                               logs:_resultLogs];
        }];
    };
    
    [self performSegueWithIdentifier:@"showRequest" sender:@{@"completionBlock" : completionBlock}];
}

#pragma mark - Helpers

- (void)displayError:(NSError *)error
{
    NSString *errorString = [NSString stringWithFormat:@"Error Domain=%@ Code=%ld Description=%@", error.domain, (long)error.code, error.localizedDescription];
    
    [self displayResultJson:[NSString stringWithFormat:@"{\"error\" : \"%@\"}", errorString]
                       logs:_resultLogs];
}

- (void)displayResultJson:(NSString *)resultJson logs:(NSString *)resultLogs
{
    [self performSegueWithIdentifier:@"showResult" sender:@{@"resultInfo":resultJson,
                                                            @"resultLogs":resultLogs}];
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
    // TODO: settle on what to show for test to succeed
    return [self createJsonStringFromDictionary:
            @{@"access_token":result.accessToken,
              @"scopes":result.scopes,
              @"tenantId":(result.tenantId) ? result.tenantId : @"",
              @"expires_on":[NSString stringWithFormat:@"%f", result.expiresOn.timeIntervalSince1970]}];
}

@end
