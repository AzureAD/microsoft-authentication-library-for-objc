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

#import "MSALFakeViewController.h"
#import "MSIDTestSwizzle.h"
#import "UIApplication+MSIDExtensions.h"

static BOOL s_returnNil = NO;

static MSALFakeViewController *s_currentController = nil;

static id FakeCurrentViewController(id obj, SEL sel)
{
#pragma unused (obj, sel)
    if (s_returnNil)
    {
        return nil;
    }
    
    return s_currentController;
}

@implementation MSALFakeViewController

+ (void)initialize
{
    s_currentController = [MSALFakeViewController new];
    
    // Because msalCurrentViewController is defined in a category we can't safely
    // override it in yet another category, instead, swizzling!
    [[MSIDTestSwizzle classMethod:@selector(msidCurrentViewController:)
                            class:[UIApplication class]
                             impl:(IMP)FakeCurrentViewController] makePermanent];
}

+ (void)returnNilForCurrentController
{
    s_returnNil = YES;
}

+ (void)reset
{
    s_returnNil = NO;
    s_currentController.wasDismissed = NO;
    s_currentController.wasPresented = NO;
}

+ (MSALFakeViewController *)currentController
{
    return s_currentController;
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated: (BOOL)flag completion:(void (^ __nullable)(void))completion
{
    if (!viewControllerToPresent)
    {
        @throw @"no view controller!";
    }
    
    (void)flag;
    (void)completion;
    
    self.wasPresented = YES;
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^ _Nullable)(void))completion
{
    (void)flag;
    (void)completion;
    
    self.wasDismissed = YES;
}



@end
