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

#import <MSAL/MSAL.h>

#import "SampleAppDelegate.h"
#import "SampleMSALUtil.h"
#import "SampleMainViewController.h"
#import "SampleLoginViewController.h"

@interface SampleAppDelegate ()
{
    UIViewController *_rootController;
    UIViewController *_currentController;
}

@end

@implementation SampleAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // The MSAL Logger should be set as early as possible in the app launch sequence, before any MSAL
    // requests are made.
    [SampleMSALUtil setup];
    
    UIWindow* window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window = window;
    
    _rootController = [UIViewController new];
    
    if ([[SampleMSALUtil sharedUtil] currentAccount:nil])
    {
        [self setCurrentViewController:[SampleMainViewController sharedViewController]];
    }
    else
    {
        [self setCurrentViewController:[SampleLoginViewController sharedViewController]];
    }
    
    [window setRootViewController:_rootController];
    [window setBackgroundColor:[UIColor whiteColor]];
    [window makeKeyAndVisible];
    
    return YES;
}

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    if ([MSALPublicClientApplication handleMSALResponse:url sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]])
    {
        NSLog(@"This URL is handled by MSAL");
    }
    return YES;
}

+ (void)setCurrentViewController:(SampleBaseViewController *)viewController
{
    [(SampleAppDelegate *)[[UIApplication sharedApplication] delegate] setCurrentViewController:viewController];
}

- (void)setCurrentViewController:(SampleBaseViewController *)viewController
{
    [_currentController willMoveToParentViewController:nil];
    [_rootController addChildViewController:viewController];
    
    if (!_currentController)
    {
        viewController.view.frame = _rootController.view.frame;
        [_rootController.view addSubview:viewController.view];
        _currentController = viewController;
        [_currentController didMoveToParentViewController:_rootController];
    }
    else
    {
        CGRect newInitialFrame = _rootController.view.frame;
        CGRect newEndFrame = _rootController.view.frame;
        
        float startYp = viewController.startY;
        float endY = startYp * newInitialFrame.size.height;
        float dY = newEndFrame.origin.y - endY;
        newInitialFrame.origin.y = endY;
        
        viewController.view.frame = newInitialFrame;
        
        CGRect oldEndFrame = _rootController.view.frame;
        oldEndFrame.origin.y += dY;
        
        UIViewController *oldController = _currentController;
        _currentController = viewController;
        [_rootController transitionFromViewController:oldController
                                     toViewController:viewController
                                             duration:0.5
                                              options:UIViewAnimationOptionCurveEaseIn
                                           animations:^{
                                               viewController.view.frame = newEndFrame;
                                               oldController.view.frame = oldEndFrame;
                                           }
                                           completion:^(BOOL finished) {
                                               [oldController removeFromParentViewController];
                                               [viewController didMoveToParentViewController:_rootController];
                                           }];
    }
}

@end

