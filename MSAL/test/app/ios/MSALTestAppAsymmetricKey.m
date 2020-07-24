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

#import "MSALTestAppAsymmetricKey.h"

@implementation MSALTestAppAsymmetricKey

- (instancetype)initWithName:(NSString *)name kid:(NSString *)kid
{
    self = [super init];
    if (self)
    {
        _name = name;
        _kid = kid;
    }
    
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:MSALTestAppAsymmetricKey.class])
    {
        return NO;
    }
    
    return [self isEqualToItem:(MSALTestAppAsymmetricKey *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = 0;
    hash = hash * 31 + self.name.hash;
    hash = hash * 31 + self.kid.hash;
    return hash;
}

- (BOOL)isEqualToItem:(MSALTestAppAsymmetricKey *)key
{
    if (!key) return NO;
    
    BOOL result = YES;
    result &= (!self.name && !key.name) || [self.name isEqualToString:key.name];
    result &= (!self.kid && !key.kid) || [self.kid isEqualToString:key.kid];
    return result;
}

@end
