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

#import "MSALWebviewParameters.h"

@implementation MSALWebviewParameters

#if TARGET_OS_IPHONE
- (instancetype)init
{
    return [super init];
}

+ (instancetype)new
{
    return [super new];
}

- (instancetype)initWithParentViewController:(UIViewController *)parentViewController
{
    self = [super init];
    if (self)
    {
        _parentViewController = parentViewController;
    }
    
    return self;
}
#endif

#pragma mark - NSCopying

- (id)copyWithZone:(__unused NSZone *)zone
{
    MSALWebviewParameters *item;
#if TARGET_OS_IPHONE
    item = [[MSALWebviewParameters alloc] initWithParentViewController:_parentViewController];
    item.parentViewController = _parentViewController;
    item.presentationStyle = _presentationStyle;
    if (@available(iOS 13.0, *))
    {
        item.prefersEphemeralWebBrowserSession = _prefersEphemeralWebBrowserSession;
    }
#else
    item = [MSALWebviewParameters new];
#endif
    
    item.webviewType = _webviewType;
    item.customWebview = _customWebview;
    
    return item;
}

@end
