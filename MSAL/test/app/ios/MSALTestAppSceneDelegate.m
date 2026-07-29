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

#import "MSALTestAppSceneDelegate.h"
#import "MSALTestAppAcquireTokenViewController.h"
#import "MSALTestAppCacheViewController.h"
#import "MSALTestAppLogViewController.h"
#import "MSALTestAppSettingsViewController.h"

@implementation MSALTestAppSceneDelegate
{
    UITabBarController* _tabBar;
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    (void)session;
    (void)connectionOptions;

    if (![scene isKindOfClass:[UIWindowScene class]])
    {
        return;
    }

    UIWindowScene *windowScene = (UIWindowScene *)scene;
    UIWindow* window = [[UIWindow alloc] initWithWindowScene:windowScene];
    [window setTintColor:[UIColor colorWithRed:118.0/255.0 green:44.0/255.0 blue:144.0/255.0 alpha:1.0]];
    self.window = window;

    _tabBar = [UITabBarController new];

    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MSALTestAppAcquireTokenViewController" bundle:nil];
    MSALTestAppAcquireTokenViewController *tokenController = [storyboard instantiateViewControllerWithIdentifier:@"MSALTestAppAcquireTokenViewController"];
    UINavigationController* tokenNavController = [[UINavigationController alloc] initWithRootViewController:tokenController];
    tokenNavController.tabBarItem = tokenController.tabBarItem;
    tokenNavController.navigationBar.hidden = YES;
    [_tabBar addChildViewController:tokenNavController];

    // Settings controller is contained in a navigation controller
    MSALTestAppSettingsViewController* settingsController = [MSALTestAppSettingsViewController new];

    UINavigationController* navController = [[UINavigationController alloc] initWithRootViewController:settingsController];
    navController.navigationBar.hidden = YES;
    navController.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Settings"
                                                             image:[UIImage imageNamed:@"Settings"]
                                                               tag:0];
    [_tabBar addChildViewController:navController];

    MSALTestAppCacheViewController* cacheController = [MSALTestAppCacheViewController new];
    UINavigationController* cacheNavController = [[UINavigationController alloc] initWithRootViewController:cacheController];
    cacheNavController.tabBarItem = cacheController.tabBarItem;
    cacheController.navigationItem.title = @"MSAL Credentials";
    [_tabBar addChildViewController:cacheNavController];
    MSALTestAppLogViewController* logController = [MSALTestAppLogViewController new];
    [_tabBar addChildViewController:logController];

    [window setRootViewController:_tabBar];
    [window setBackgroundColor:[UIColor whiteColor]];
    [window makeKeyAndVisible];
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts
{
    (void)scene;

    id<UIApplicationDelegate> appDelegate = UIApplication.sharedApplication.delegate;

    if (![appDelegate respondsToSelector:@selector(application:openURL:options:)])
    {
        return;
    }

    for (UIOpenURLContext *context in URLContexts)
    {
        NSMutableDictionary<UIApplicationOpenURLOptionsKey, id> *options = [NSMutableDictionary new];

        if (context.options.sourceApplication)
        {
            options[UIApplicationOpenURLOptionsSourceApplicationKey] = context.options.sourceApplication;
        }

        [appDelegate application:UIApplication.sharedApplication openURL:context.URL options:options];
    }
}

@end
