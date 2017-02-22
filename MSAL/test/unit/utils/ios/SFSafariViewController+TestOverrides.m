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

#import "SFSafariViewController+TestOverrides.h"
#import "MSALFakeViewController.h"

static void(^s_svcValidationBlock)(MSALFakeViewController *controller, NSURL *, BOOL) = nil;

@implementation SFSafariViewController (TestOverrides)

+ (void)setValidationBlock:(SVCValidationBlock)block
{
    s_svcValidationBlock = block;
}

+ (void)reset
{
    s_svcValidationBlock = nil;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (id)initWithURL:(NSURL *)URL
{
    return [self initWithURL:URL entersReaderIfAvailable:NO];
}

- (id)initWithURL:(NSURL *)URL entersReaderIfAvailable:(BOOL)entersReaderIfAvailable
{
    MSALFakeViewController *fakeController = [MSALFakeViewController new];
    if (s_svcValidationBlock)
    {
        s_svcValidationBlock(fakeController, URL, entersReaderIfAvailable);
    }
    return (SFSafariViewController *)fakeController;
}
#pragma pop


@end
