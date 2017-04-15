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

#import "NSURL+MSALExtensions.h"
#import "MSALAccessTokenCacheKey.h"

@implementation MSALAccessTokenCacheKey

- (id)initWithAuthority:(NSString *)authority
               clientId:(NSString *)clientId
                  scope:(MSALScopes *)scope
         userIdentifier:(NSString *)userIdentifier
            environment:(NSString *)environment
{
    if (!(self = [super initWithClientId:clientId userIdentifier:userIdentifier]))
    {
        return nil;
    }
    
    self.authority = [authority lowercaseString];
    self.environment = [environment lowercaseString];

    NSMutableOrderedSet<NSString *> *scopeCopy = [NSMutableOrderedSet<NSString *> new];
    for (NSString *item in scope)
    {
        [scopeCopy addObject:item.msalTrimmedString.lowercaseString];
    }
    self.scope = scopeCopy;
    
    return self;
}

- (BOOL)matches:(MSALAccessTokenCacheKey *)other
{
    return [self.clientId isEqualToString:other.clientId]
    && [self.scope isSubsetOfOrderedSet:other.scope]
    && (!self.authority || [self.authority isEqualToString:other.authority])
    && (!self.userIdentifier || [self.userIdentifier isEqualToString:other.userIdentifier]);
}

- (NSString *)service
{
    if (!self.authority && !self.clientId && self.scope.count==0)
    {
        return nil;
    }
    
    return [NSString stringWithFormat:@"%@$%@$%@",
            self.authority ? self.authority.msalBase64UrlEncode : @"",
            self.clientId ? self.clientId.msalBase64UrlEncode : @"",
            self.scope ? self.scope.msalToString.msalBase64UrlEncode : @""];
}

- (NSString *)account
{
    if (!self.userIdentifier)
    {
        return nil;
    }
    
    return [NSString stringWithFormat:@"%u$%@", MSAL_V1,
            [MSALTokenCacheKeyBase userIdAtEnvironmentBase64:self.userIdentifier environment:self.environment]];
}

@end
