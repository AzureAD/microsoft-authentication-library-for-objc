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

#import "MSALTestSwizzle.h"

#import <objc/runtime.h>


static NSMutableArray<MSALTestSwizzle *> *s_currentMonkeyPatches = nil;


@implementation MSALTestSwizzle
{
    Method _m;
    IMP _originalImp;
}

+ (void)initialize
{
    s_currentMonkeyPatches = [NSMutableArray new];
}

+ (void)reset
{
    @synchronized (s_currentMonkeyPatches)
    {
        // We want to go through this backwards like a stack in case someone
        // changed a method multiple times and it gets restored to its
        // original implementation
        for (NSInteger i = s_currentMonkeyPatches.count - 1; i >= 0; i--)
        {
            MSALTestSwizzle *patch = s_currentMonkeyPatches[i];
            method_setImplementation(patch->_m, patch->_originalImp);
        }
        
        [s_currentMonkeyPatches removeAllObjects];
    }
}

+ (void)instanceMethodClass:(Class)cls
                   selector:(SEL)sel
                       impl:(IMP)impl
{
    Method method = class_getInstanceMethod(cls, sel);
    if (!method)
    {
        return;
    }
    @synchronized (s_currentMonkeyPatches)
    {
    
        MSALTestSwizzle *patch = [MSALTestSwizzle new];
        patch->_m = method;
        patch->_originalImp = method_setImplementation(method, impl);
    
    
        [s_currentMonkeyPatches addObject:patch];
    }
}

@end
