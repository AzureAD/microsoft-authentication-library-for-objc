//
//  MSALStressTestHelper.h
//  MSAL
//
//  Created by Olga Dalton on 4/24/17.
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MSALStressTestHelper : NSObject

/*
 With RT and AT in cache, 10 threads calling acquireTokenSilent at the same time.
 */
+ (void)testWithSameTokenAndLogHandler:(void (^)(NSString *testLogEntry))logHandler;

/*
 With RT and AT in cache, 10 threads calling acquireTokenSilent at the same time.
 Each acquireTokenSilent call will expire AT when the call is finished.
 */
+ (void)testWithExpiredTokenAndLogHandler:(void (^)(NSString *testLogEntry))logHandler;

/*
 With two different users in cache, 10 threads calling acquireTokenSilent at the same time once for one user, once for another.
 Each acquireTokenSilent call will expire AT when the call is finished.
 */
+ (void)testWithMultipleUsersAndLogHandler:(void (^)(NSString *testLogEntry))logHandler;

/*
 10 threads trying to find token in cache in background while interactive acquireToken is in progress.
 Once interactive acquireToken is finished, they should find token and fo acquireTokenSilent.
 */
+ (void)testPollingInBackgroundWithLogHandler:(void (^)(NSString *testLogEntry))logHandler;

/*
 Stops the currently running stress test
 */
+ (void)stopStressTestWithLogHandler:(void (^)(NSString *testLogEntry))logHandler;

@end
