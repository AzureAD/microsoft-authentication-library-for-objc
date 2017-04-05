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

#import "MSALRefreshTokenCacheKey.h"

@implementation MSALRefreshTokenCacheKey

- (id)initWithEnvironment:(NSString *)environment
                 clientId:(NSString *)clientId
           userIdentifier:(NSString *)userIdentifier
{
    if (!(self = [super initWithClientId:clientId userIdentifier:userIdentifier]))
    {
        return nil;
    }
    
    self.environment = [environment lowercaseString];
    
    return self;
}

- (BOOL)matches:(MSALRefreshTokenCacheKey *)other
{
    return [self.clientId isEqualToString:other.clientId]
    && (!self.environment || [self.environment isEqualToString:other.environment])
    && (!self.userIdentifier || [self.userIdentifier isEqualToString:other.userIdentifier]);
}

- (NSString *)service {
    if (!self.clientId)
    {
        return nil;
    }

    return self.clientId.msalBase64UrlEncode;
}

- (NSString *)account {
    if (!self.userIdentifier)
    {
        return nil;
    }

    return [NSString stringWithFormat:@"%@$%@@%@", MSAL_VERSION_NSSTRING, self.userIdentifier.msalBase64UrlEncode, self.environment.msalBase64UrlEncode];
}

@end
