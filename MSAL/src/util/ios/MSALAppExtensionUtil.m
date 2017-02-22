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

#import "MSALAppExtensionUtil.h"

@implementation MSALAppExtensionUtil

+ (BOOL)isExecutingInAppExtension
{
    NSString* mainBundlePath = [[NSBundle mainBundle] bundlePath];
    
    if (mainBundlePath.length == 0)
    {
        LOG_ERROR(nil, @"Expected `[[NSBundle mainBundle] bundlePath]` to be non-nil. Defaulting to non-application-extension safe API.");
        return NO;
    }
    
    return [mainBundlePath hasSuffix:@"appex"];
}

#pragma mark - UIApplication

+ (UIApplication*)sharedApplication
{
    if ([self isExecutingInAppExtension])
    {
        // The caller should do this check but we will double check to fail safely
        return nil;
    }
    
    return [UIApplication performSelector:NSSelectorFromString(@"sharedApplication")];
}

+ (void)sharedApplicationOpenURL:(NSURL*)url
{
    if ([self isExecutingInAppExtension])
    {
        // The caller should do this check but we will double check to fail safely
        return;
    }
    
#pragma clang diagnostic push
    // performSelector always causes ARC warnings, due to ARC not knowing the
    // exact memory semantics of the call being made.
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [[self sharedApplication] performSelector:NSSelectorFromString(@"openURL:") withObject:url];
#pragma clang diagnostic pop
}

@end
