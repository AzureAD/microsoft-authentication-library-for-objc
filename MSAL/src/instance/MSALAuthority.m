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

#import "MSALAuthority.h"
#import "MSALAuthority_Internal.h"
#import "MSALAuthorityFactory.h"

@implementation MSALAuthority

- (instancetype)initWithURL:(nonnull NSURL *)url
                      error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    return [super init];
}

+ (MSALAuthority *)authorityWithURL:(nonnull NSURL *)url
                              error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    return [MSALAuthorityFactory authorityFromUrl:url
                                          context:nil
                                            error:error];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSALAuthority *authority = [[self.class alloc] init];
    authority->_msidAuthority = [_msidAuthority copyWithZone:zone];
    return authority;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:MSALAuthority.class])
    {
        return NO;
    }
    
    return [self isEqualToAuthority:(MSALAuthority *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = 0;
    hash = hash * 31 + self.msidAuthority.hash;
    return hash;
}

- (BOOL)isEqualToAuthority:(MSALAuthority *)authority
{
    if (!authority) return NO;
    
    BOOL result = YES;
    result &= (!self.msidAuthority && !authority.msidAuthority) || [self.msidAuthority isEqual:authority.msidAuthority];
    return result;
}

@end
