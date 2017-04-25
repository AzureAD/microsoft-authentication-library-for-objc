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
#import "NSURL+MSALExtensions.h"
#import "MSALAuthority.h"
#import "MSALAccessTokenCacheItem+TestAppUtil.h"

@implementation MSALStressTestHelper

static dispatch_semaphore_t sem = nil;
static BOOL stop = NO;
static BOOL runningTest = NO;

#pragma mark - Helpers

+ (void)commonSetup
{
    [[MSALTestAppTelemetryViewController sharedController] stopTracking];
    [MSALLogger sharedLogger].level = MSALLogLevelNothing;
    
    stop = NO;
}

+ (MSALPublicClientApplication *)createTestPublicApplicationWithLogHandler:(void (^)(NSString *testLogEntry))logHandler
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    
    if (![[settings.scopes allObjects] count])
    {
        logHandler(@"Please select the scope!");
        return nil;
    }
    
    if (runningTest)
    {
        logHandler(@"Running other test, please stop first!");
        return nil;
    }
    
    NSString *authority = [settings authority];
    NSString *clientId = TEST_APP_CLIENT_ID;
    
    NSError *error = nil;
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:clientId authority:authority error:&error];
    
    if (!application)
    {
        logHandler([NSString stringWithFormat:@"Failed to create PublicClientApplication:\n%@", error]);
    }

    return application;
}

+ (void)expireAllTokens
{
    MSALKeychainTokenCache *cache = MSALKeychainTokenCache.defaultKeychainCache;
    NSArray *tokenCacheItems = [cache getAccessTokenItemsWithKey:nil context:nil error:nil];
    
    for (MSALAccessTokenCacheItem *item in tokenCacheItems)
    {
        item.expiresOnString = [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate dateWithTimeIntervalSinceNow:-1.0] timeIntervalSince1970]];
        [cache addOrUpdateAccessTokenItem:item context:nil error:nil];
    }
}

#pragma mark - Stress tests

+ (void)testAcquireTokenSilentWithExpiringToken:(BOOL)expireToken
                               useMultipleUsers:(BOOL)multipleUsers
                                     logHandler:(void (^)(NSString *testLogEntry))logHandler
{
    [self commonSetup];
    
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    MSALPublicClientApplication *application = [self createTestPublicApplicationWithLogHandler:logHandler];
    
    if (!application)
    {
        return;
    }
    
    NSArray<MSALUser *> *users = [application users:nil];
    
    if (![users count])
    {
        logHandler(@"Cannot proceed with a silent call without having any users");
        return;
    }
    
    logHandler([NSString stringWithFormat:@"Started stress test at %@", [NSDate date]]);
    
    runningTest = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        sem = dispatch_semaphore_create(10);
        
        __block NSUInteger userIndex = 0;
        
        while (!stop)
        {
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                MSALUser *user = users[userIndex];
                
                if (multipleUsers)
                {
                    userIndex = ++userIndex >= [users count] ? 0 : userIndex;
                }
                
                [application acquireTokenSilentForScopes:[settings.scopes allObjects]
                                                    user:user
                                         completionBlock:^(MSALResult *result, NSError *error)
                 {
                     (void)error;
                     
                     if (expireToken
                         && result.user)
                     {
                         [self expireAllTokens];
                     }
                     
                     dispatch_semaphore_signal(sem);
                 }];
            });
        }});
}

+ (void)testPollingInBackgroundWithLogHandler:(void (^)(NSString *testLogEntry))logHandler
{
    [self commonSetup];
    
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    MSALPublicClientApplication *application = [self createTestPublicApplicationWithLogHandler:logHandler];
    
    if (!application)
    {
        return;
    }
    
    logHandler([NSString stringWithFormat:@"Started stress test at %@", [NSDate date]]);
    
    runningTest = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        sem = dispatch_semaphore_create(10);
        
        while (!stop)
        {
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                NSArray *users = [application users:nil];
                
                if (![users count])
                {
                    dispatch_semaphore_signal(sem);
                }
                else
                {
                    [application acquireTokenSilentForScopes:[settings.scopes allObjects]
                                                        user:users[0]
                                             completionBlock:^(MSALResult *result, NSError *error)
                     {
                         (void)error;
                         
                         if (result.accessToken)
                         {
                             stop = YES;
                             logHandler([NSString stringWithFormat:@"Stress test received access token at %@", [NSDate date]]);
                         }
                         
                         dispatch_semaphore_signal(sem);
                     }];
                }
            });
        }
        
    });
}

#pragma mark - Convinience

+ (void)testWithSameTokenAndLogHandler:(void (^)(NSString *testLogEntry))logHandler
{
    [self testAcquireTokenSilentWithExpiringToken:NO useMultipleUsers:NO logHandler:logHandler];
}

+ (void)testWithExpiredTokenAndLogHandler:(void (^)(NSString *testLogEntry))logHandler
{
    [self testAcquireTokenSilentWithExpiringToken:YES useMultipleUsers:NO logHandler:logHandler];
}

+ (void)testWithMultipleUsersAndLogHandler:(void (^)(NSString *testLogEntry))logHandler
{
    [self testAcquireTokenSilentWithExpiringToken:YES useMultipleUsers:YES logHandler:logHandler];
}

+ (void)stopStressTestWithLogHandler:(void (^)(NSString *testLogEntry))logHandler
{
    stop = YES;
    runningTest = NO;
    
    logHandler([NSString stringWithFormat:@"Stopped the currently running stress test at %@", [NSDate date]]);
}

@end
