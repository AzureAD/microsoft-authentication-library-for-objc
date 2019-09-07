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

#import "MSALTestAppDelegate.h"
#import "MSALTestAppSettings.h"

#import "MSALTestAppAcquireTokenViewController.h"
#import "MSALTestAppCacheViewController.h"
#import "MSALTestAppLogViewController.h"
#import "MSALTestAppSettingsViewController.h"
#import "MSALPublicClientApplication.h"

@implementation MSALTestAppDelegate
{
    UITabBarController* _tabBar;
}

/*
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    NSLog(@"original application openURL hit!");
    return YES;
}
*/

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    (void)application;
    (void)launchOptions;
    UIWindow* window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
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
    [_tabBar addChildViewController:cacheController];
    MSALTestAppLogViewController* logController = [MSALTestAppLogViewController new];
    [_tabBar addChildViewController:logController];
    
    [window setRootViewController:_tabBar];
    [window setBackgroundColor:[UIColor whiteColor]];
    [window makeKeyAndVisible];
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    
    (void)application;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    (void)application;
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    
    (void)application;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    (void)application;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    (void)application;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
{
    (void)app;
    (void)url;
    (void)options;
    NSLog(@"OpenURL Method! - MSALWebviewTypeSafariViewController");
    
    return [MSALPublicClientApplication handleMSALResponse:url sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]];
}

@end
