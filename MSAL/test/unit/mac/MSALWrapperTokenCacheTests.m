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

#import <XCTest/XCTest.h>
#import "MSALIdToken.h"
#import "MSALTokenResponse.h"
#import "MSALClientInfo.h"

typedef enum
{
    kNothingCalled,
    kWillCalled,
    kDidCalled,
} TestDelegateState;

@interface ADTestSimpleStorage : NSObject <MSALTokenCacheDelegate>
{
@public
    NSData* _cache;
    
    TestDelegateState access;
    TestDelegateState write;
}

@end

@implementation ADTestSimpleStorage

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    //load cache from where it is persisted
    //here we simply set it empty
    _cache = nil;
    
    return self;
}

- (void)willAccessCache:(nonnull MSALWrapperTokenCache *)cache
{
    [cache deserialize:_cache error:nil];
    
    switch (access)
    {
        case kNothingCalled: access = kWillCalled; break;
        case kWillCalled: NSAssert(0, @"willAccessCache called multiple times without calling didAccessCache!"); break;
        case kDidCalled: access = kWillCalled; break;
    }
}

- (void)didAccessCache:(nonnull MSALWrapperTokenCache *)cache
{
    (void)cache;
    
    switch (access)
    {
        case kNothingCalled: NSAssert(0, @"willAccessCache must be called before didAccessCache"); break;
        case kWillCalled: access = kDidCalled; break;
        case kDidCalled: NSAssert(0, @"didAccessCache callled multuple times!"); break;
    }
}

- (void)willWriteCache:(nonnull MSALWrapperTokenCache *)cache
{
    [cache deserialize:_cache error:nil];
    
    switch (write)
    {
        case kNothingCalled: write = kWillCalled; break;
        case kWillCalled: NSAssert(0, @"willAccessCache called multiple times without calling didAccessCache!"); break;
        case kDidCalled: write = kWillCalled; break;
    }
}

- (void)didWriteCache:(nonnull MSALWrapperTokenCache *)cache
{
    _cache = [cache serialize];
    
    switch (write)
    {
        case kNothingCalled: NSAssert(0, @"willAccessCache must be called before didAccessCache"); break;
        case kWillCalled: write = kDidCalled; break;
        case kDidCalled: NSAssert(0, @"didAccessCache callled multuple times!"); break;
    }
    
}

@end

@interface MSALWrapperTokenCacheTests : XCTestCase
{
}

@end

@implementation MSALWrapperTokenCacheTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

// TODO : copy keychain tests

@end
