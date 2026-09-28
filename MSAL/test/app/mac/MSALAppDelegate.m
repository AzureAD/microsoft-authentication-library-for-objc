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

#import "MSALAppDelegate.h"
#import "MSALAcquireTokenViewController.h"
#import "MSALCacheViewController.h"

@interface MSALMacDashboardFactory : NSObject
+ (NSViewController *)rootControllerWithAcquireController:(MSALAcquireTokenViewController *)acquireController
                                           cacheController:(MSALCacheViewController *)cacheController;
@end

@interface MSALAppDelegate ()

@end

@implementation MSALAppDelegate

- (void)applicationDidFinishLaunching:(__unused NSNotification *)aNotification
{
    for (NSWindow *window in NSApp.windows)
    {
        NSTabViewController *tabs = (NSTabViewController *)window.contentViewController;
        if (![tabs isKindOfClass:[NSTabViewController class]] || tabs.tabViewItems.count < 2)
        {
            continue;
        }
        MSALAcquireTokenViewController *acquire = (MSALAcquireTokenViewController *)tabs.tabViewItems[0].viewController;
        MSALCacheViewController *cache = (MSALCacheViewController *)tabs.tabViewItems[1].viewController;
        if (![acquire isKindOfClass:[MSALAcquireTokenViewController class]]
            || ![cache isKindOfClass:[MSALCacheViewController class]])
        {
            continue;
        }
        (void)acquire.view;
        window.contentViewController = [MSALMacDashboardFactory rootControllerWithAcquireController:acquire
                                                                                    cacheController:cache];
        [window setContentSize:NSMakeSize(1120, 760)];
        window.minSize = NSMakeSize(850, 620);
        [window makeKeyAndOrderFront:nil];
        break;
    }
}


- (void)applicationWillTerminate:(__unused NSNotification *)aNotification
{
}

@end
