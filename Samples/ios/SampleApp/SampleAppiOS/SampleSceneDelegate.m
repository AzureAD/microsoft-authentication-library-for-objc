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

#import "SampleSceneDelegate.h"
#import "SampleAppDelegate.h"

@implementation SampleSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    (void)session;

    if (![scene isKindOfClass:[UIWindowScene class]])
    {
        return;
    }

    UIWindowScene *windowScene = (UIWindowScene *)scene;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:windowScene];
    self.window = window;

    // The app delegate owns the root controller / current controller VC-swap state, so let it
    // install its root into this scene's window. External callers reach that state through
    // [[UIApplication sharedApplication] delegate], so it must stay on the app delegate.
    SampleAppDelegate *appDelegate = (SampleAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate installRootIntoWindow:window];

    if (connectionOptions.URLContexts.count > 0)
    {
        [self scene:scene openURLContexts:connectionOptions.URLContexts];
    }
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts
{
    (void)scene;

    for (UIOpenURLContext *context in URLContexts)
    {
        if ([MSALPublicClientApplication handleMSALResponse:context.URL sourceApplication:context.options.sourceApplication])
        {
            NSLog(@"This URL is handled by MSAL");
        }
    }
}

@end
