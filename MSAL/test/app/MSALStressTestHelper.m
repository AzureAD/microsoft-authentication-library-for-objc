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

#import "MSALStressTestHelper.h"
#import "MSALTestAppTelemetryViewController.h"
#import "MSALTestAppSettings.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDAccessToken.h"
#import "MSIDAccount.h"
#import "MSIDAccountCredentialCache.h"
#import "MSALPublicClientApplication.h"
#import "MSALResult.h"
#import "MSALSilentTokenParameters.h"

@implementation MSALStressTestHelper

static BOOL s_stop = NO;
static BOOL s_runningTest = NO;

#pragma mark - Helpers

+ (void)expireAllAccessTokens
{
    MSIDAccountCredentialCache *cache = [[MSIDAccountCredentialCache alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache];
    NSArray<MSIDCredentialCacheItem *> *accessTokens = [cache getAllCredentialsWithType:MSIDAccessTokenType context:nil error:nil];

    for (MSIDCredentialCacheItem *token in accessTokens)
    {
        token.expiresOn = [NSDate dateWithTimeIntervalSinceNow:-1.0];
        [cache saveCredential:token context:nil error:nil];
    }
}

#pragma mark - Stress tests

+ (void)testAcquireTokenSilentWithExpiringToken:(BOOL)expireToken
                               useMultipleUsers:(BOOL)multipleUsers
                                    application:(MSALPublicClientApplication *)application
{
    NSArray<MSALAccount *> *accounts = [application allAccounts:nil];
    
    [self testAcquireTokenSilentWithExpiringTokenImpl:expireToken
                                     useMultipleUsers:multipleUsers
                                          application:application
                                             accounts:accounts];
}

+ (void)testAcquireTokenSilentWithExpiringTokenImpl:(BOOL)expireToken
                                   useMultipleUsers:(BOOL)multipleUsers
                                        application:(MSALPublicClientApplication *)application
                                           accounts:(NSArray<MSALAccount *> *)accounts
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        __block dispatch_semaphore_t sem = dispatch_semaphore_create(10);
        __block NSUInteger userIndex = 0;

        while (!s_stop)
        {
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

                MSALAccount *account = accounts[userIndex];

                if (multipleUsers)
                {
                    userIndex = ++userIndex >= [accounts count] ? 0 : userIndex;
                }
                
                __auto_type scopes = [[MSALTestAppSettings settings].scopes allObjects];
                MSALSilentTokenParameters *parameters = [[MSALSilentTokenParameters alloc] initWithScopes:scopes account:account];
                
                [application acquireTokenSilentWithParameters:parameters completionBlock:^(MSALResult *result, __unused NSError *error)
                 {
                     if (expireToken && result.account)
                     {
                         [self expireAllAccessTokens];
                     }
                     
                     dispatch_semaphore_signal(sem);
                 }];
            });
        }});
}

+ (void)testPollingUntilSuccessWithApplication:(MSALPublicClientApplication *)application
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        __block dispatch_semaphore_t sem = dispatch_semaphore_create(10);
        
        while (!s_stop)
        {
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

                NSArray<MSALAccount *> *accounts = [application allAccounts:nil];
                if (![accounts count])
                {
                    dispatch_semaphore_signal(sem);
                }
                else
                {
                    __auto_type scopes = [settings.scopes allObjects];
                    MSALSilentTokenParameters *parameters = [[MSALSilentTokenParameters alloc] initWithScopes:scopes account:accounts[0]];
                    
                    [application acquireTokenSilentWithParameters:parameters completionBlock:^(MSALResult *result, __unused NSError *error)
                     {
                         if (result.accessToken)
                         {
                             s_stop = YES;
                             s_runningTest = NO;
                         }
                         
                         dispatch_semaphore_signal(sem);
                     }];
                }
            });
        }
    });
}

#pragma mark - Convenience

+ (BOOL)runStressTestWithType:(MSALStressTestType)type application:(MSALPublicClientApplication *)application
{
    if (s_runningTest)
    {
        return NO;
    }
    
    s_stop = NO;
    s_runningTest = YES;
    
    switch (type) {
        case MSALStressTestWithSameToken:
            [self testAcquireTokenSilentWithExpiringToken:NO useMultipleUsers:NO application:application];
            break;
            
        case MSALStressTestWithExpiredToken:
            [self testAcquireTokenSilentWithExpiringToken:YES useMultipleUsers:NO application:application];
            break;
        
        case MSALStressTestWithMultipleUsers:
            [self testAcquireTokenSilentWithExpiringToken:YES useMultipleUsers:YES application:application];
            break;
            
        case MSALStressTestOnlyUntilSuccess:
            [self testPollingUntilSuccessWithApplication:application];
            break;
            
        default:
            break;
    }
    
    return YES;
}

+ (NSUInteger)numberOfUsersNeededForTestType:(MSALStressTestType)type
{
    switch (type) {
        case MSALStressTestOnlyUntilSuccess:
            return 0;
            
        case MSALStressTestWithMultipleUsers:
            return 2;
            
        default:
            return 1;
    }
}

+ (void)stopStressTest
{
    s_stop = YES;
    s_runningTest = NO;
}

@end
