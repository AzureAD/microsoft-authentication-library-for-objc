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

#import <Foundation/Foundation.h>
#import "MSALPublicClientApplication.h"

typedef enum {
                /*
                 With RT and AT in cache, 10 threads calling acquireTokenSilent at the same time.
                 */
                MSALStressTestWithSameToken,
    
                /*
                 With RT and AT in cache, 10 threads calling acquireTokenSilent at the same time.
                 Each acquireTokenSilent call will expire AT when the call is finished.
                 */
                MSALStressTestWithExpiredToken,
    
                /*
                 With two different users in cache, 10 threads calling acquireTokenSilent at the same time once for one user, once for another.
                 Each acquireTokenSilent call will expire AT when the call is finished.
                 */
                MSALStressTestWithMultipleUsers,
    
                /*
                 10 threads trying to find token in cache in background while interactive acquireToken is in progress.
                 Once interactive acquireToken is finished, they should find token and finish acquireTokenSilent.
                 */
                MSALStressTestOnlyUntilSuccess} MSALStressTestType;

@interface MSALStressTestHelper : NSObject

/*
 Runs a requested stress test type until stopped
 Returns YES if test was started
 */
+ (BOOL)runStressTestWithType:(MSALStressTestType)type application:(MSALPublicClientApplication *)application;

/*
 Returns the required number of users in cache for the requested stress test type
 */
+ (NSUInteger)numberOfUsersNeededForTestType:(MSALStressTestType)type;

/*
 Stops the currently running stress test
 */
+ (void)stopStressTest;

@end
