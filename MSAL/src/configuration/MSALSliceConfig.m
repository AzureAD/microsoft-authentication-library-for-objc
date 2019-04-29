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

#import "MSALSliceConfig.h"

@implementation MSALSliceConfig

- (nullable instancetype)initWithSlice:(nullable NSString *)slice dc:(nullable NSString *)dc
{
    self = [super init];
    if (self)
    {
        self.slice = slice;
        self.dc = dc;
    }
    return self;
}

+ (nullable instancetype)configWithSlice:(nullable NSString *)slice dc:(nullable NSString *)dc
{
    return [[MSALSliceConfig alloc] initWithSlice:slice dc:dc];
}

- (NSDictionary *)sliceDictionary
{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    if (self.slice)
    {
        dict[@"slice"] = self.slice;
    }
    if (self.dc)
    {
        dict[@"dc"] = self.dc;
    }
    return dict;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    NSString *dc = [_dc copyWithZone:zone];
    NSString *slice = [_slice copyWithZone:zone];
    MSALSliceConfig *config = [[MSALSliceConfig alloc] initWithSlice:slice dc:dc];
    return config;
}

@end
