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

#import "XCTestCase+HelperMethods.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

@implementation XCTestCase (HelperMethods)

- (void)msalAssertStringEquals:(NSString *)actual
              stringExpression:(NSString *)expression
                      expected:(NSString *)expected
                          file:(const char *)file
                          line:(int)line
{
    if (!actual && !expected)
    {
        //Both nil, so they are equal
        return;
    }
    
    if (![expected isEqualToString:actual])
    {
        _XCTFailureHandler(self, YES, file, line, @"Strings.", @"" "The strings are different: '%@' = '%@', expected '%@'", expression, actual, expected);
    }
}

#if TARGET_OS_IPHONE
+ (UIViewController *)sharedViewControllerStub
{
    static dispatch_once_t once;
    static UIViewController *controller;
    static UIWindow *window;
    
    dispatch_once(&once, ^{
        controller = [UIViewController new];
        UIView *view = [UIView new];
        window = [UIWindow new];
        [view setValue:window forKey:@"window"];
        [controller setValue:view forKey:@"view"];
    });
    
    return controller;
}
#endif

@end
