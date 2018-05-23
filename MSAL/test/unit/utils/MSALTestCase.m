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

#import "MSALTestCase.h"

#import "MSALAuthority.h"
#import "MSALWebUI.h"

#import "MSALTestBundle.h"
#import "MSALTestSwizzle.h"

#import "MSIDTestURLSession.h"

#if TARGET_OS_IPHONE
#import "SFSafariViewController+TestOverrides.h"
#import "MSALFakeViewController.h"
#endif

@implementation MSALTestCase

- (void)setUp
{
    [super setUp];
    [MSALTestBundle reset];
    [MSALTestSwizzle reset];
    [MSALAuthority initialize];
    
    [MSIDTestURLSession clearResponses];
    
#if TARGET_OS_IPHONE
    [SFSafariViewController reset];
    [MSALFakeViewController reset];
#endif
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    XCTAssertFalse([MSALWebUI cancelCurrentWebAuthSession]);
    [super tearDown];
}

@end

void wait_and_run_main_thread(dispatch_semaphore_t sem)
{
    while (dispatch_semaphore_wait(sem, DISPATCH_TIME_NOW))
    {
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate: [NSDate distantFuture]];
    }
}
