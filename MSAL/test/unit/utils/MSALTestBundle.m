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

#import "MSALTestBundle.h"
#import <objc/runtime.h>

static NSMutableDictionary *s_overrideDictionary = nil;
static NSString *s_bundleId = nil;

typedef id (*ObjForKeyPtr)(id obj, SEL cmd, NSString *key);
typedef NSString *(*GetNSStringPtr)(id obj, SEL cmd);

static ObjForKeyPtr original_objectForInfoDictionaryKey = NULL;
static GetNSStringPtr original_bundleId = NULL;

static id swizzled_objectForInfoDictionaryKey(id obj, SEL cmd, NSString *key)
{
    (void)cmd;
    (void)obj;
    @synchronized ([MSALTestBundle class])
    {
        id value = s_overrideDictionary[key];
        if (value)
        {
            return value;
        }
    }
    
    return original_objectForInfoDictionaryKey(obj, cmd, key);
}

static id swizzled_bundleIdentifier(id obj, SEL cmd)
{
    @synchronized ([MSALTestBundle class])
    {
        if (s_bundleId)
        {
            return s_bundleId;
        }
    }
    
    return original_bundleId(obj, cmd);
}

@implementation MSALTestBundle

+ (void)load
{
    s_overrideDictionary = [NSMutableDictionary new];
    Method objectForInfoDictionaryKeyMethod =
    class_getInstanceMethod([NSBundle class], @selector(objectForInfoDictionaryKey:));
    
    original_objectForInfoDictionaryKey =
    (ObjForKeyPtr)method_setImplementation(objectForInfoDictionaryKeyMethod, (IMP)swizzled_objectForInfoDictionaryKey);
    
    Method bundleIdentifierMethod =
    class_getInstanceMethod([NSBundle class], @selector(bundleIdentifier));
    
    original_bundleId =
    (GetNSStringPtr)method_setImplementation(bundleIdentifierMethod, (IMP)swizzled_bundleIdentifier);
}

+ (void)reset
{
    @synchronized ([MSALTestBundle class])
    {
        [s_overrideDictionary removeAllObjects];
    }
    @synchronized ([MSALTestBundle class])
    {
        s_bundleId = nil;
    }
}

+ (void)overrideObject:(id)object
                forKey:(NSString *)key
{
    @synchronized ([MSALTestBundle class])
    {
        s_overrideDictionary[key] = object;
    }
}

+ (void)overrideBundleId:(NSString *)bundleId
{
    @synchronized ([MSALTestBundle class])
    {
        s_bundleId = bundleId;
    }
}

@end
