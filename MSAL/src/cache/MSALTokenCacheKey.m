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

#import "MSALTokenCacheKey.h"
#import "NSURL+MSALExtensions.h"

@implementation MSALTokenCacheKey

- (id)initWithAuthority:(NSString *)authority
               clientId:(NSString *)clientId
                  scope:(MSALScopes *)scope
                   user:(MSALUser *)user
{
    return [self initWithAuthority:authority
                          clientId:clientId
                             scope:scope
                      homeObjectId:user.homeObjectId];
}

- (id)initWithAuthority:(NSString *)authority
               clientId:(NSString *)clientId
                  scope:(MSALScopes *)scope
           homeObjectId:(NSString *)homeObjectId
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    self.authority = [authority lowercaseString];
    self.clientId = [clientId lowercaseString];
    self.homeObjectId = [homeObjectId lowercaseString];
    
    NSURL *authorityURL = [NSURL URLWithString:authority];
    self.environment = [NSString stringWithFormat:@"%@://%@", authorityURL.scheme, authorityURL.hostWithPort];
    
    NSMutableOrderedSet<NSString *> *scopeCopy = [NSMutableOrderedSet<NSString *> new];
    for (NSString *item in scope)
    {
        [scopeCopy addObject:item.msalTrimmedString.lowercaseString];
    }
    self.scope = scopeCopy;
    
    return self;
}

- (NSString *)service
{
    if (!self.clientId && self.scope.count==0)
    {
        return nil;
    }
    
    return [NSString stringWithFormat:@"%@$%@",
            self.clientId ? self.clientId.msalBase64UrlEncode : @"",
            self.scope ? self.scope.msalToString.msalBase64UrlEncode : @""];
}

- (NSString *)account
{
    return [NSString stringWithFormat:@"%@$%@@%@", MSAL_VERSION_NSSTRING, self.homeObjectId.msalBase64UrlEncode, self.environment.msalBase64UrlEncode];
}

- (BOOL)matches:(MSALTokenCacheKey *)other
{
    return [self.clientId isEqualToString:other.clientId]
    && [self.scope isSubsetOfOrderedSet:other.scope]
    && (!self.environment || [self.environment isEqualToString:other.environment])
    && (!self.homeObjectId || [self.homeObjectId isEqualToString:other.homeObjectId]);
}

@end
