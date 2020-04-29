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

#import "MSALRedirectUri.h"

@implementation MSALRedirectUri

- (instancetype)initWithRedirectUri:(NSURL *)redirectUri
                      brokerCapable:(BOOL)brokerCapable
{
    self = [super init];

    if (self)
    {
        _url = redirectUri;
        _brokerCapable = brokerCapable;
    }

    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    NSURL *url = [_url copyWithZone:zone];
    MSALRedirectUri *redirectUri = [[MSALRedirectUri alloc] initWithRedirectUri:url brokerCapable:_brokerCapable];
    return redirectUri;
}

#pragma mark - Helpers

+ (NSURL *)defaultNonBrokerRedirectUri:(NSString *)clientId
{
    if ([NSString msidIsStringNilOrBlank:clientId])
    {
        return nil;
    }
    
    NSString *redirectUri = [NSString stringWithFormat:@"msal%@://auth", clientId];
    return [NSURL URLWithString:redirectUri];
}

+ (NSURL *)defaultBrokerCapableRedirectUri
{
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *redirectUri = [NSString stringWithFormat:@"msauth.%@://auth", bundleID];
    return [NSURL URLWithString:redirectUri];
}

+ (BOOL)redirectUriIsBrokerCapable:(NSURL *)redirectUri
{
    NSURL *defaultRedirectUri = [MSALRedirectUri defaultBrokerCapableRedirectUri];

    // Check default MSAL format
    if ([defaultRedirectUri isEqual:redirectUri])
    {
        return YES;
    }

    // Check default ADAL format
    if ([redirectUri.host isEqualToString:[[NSBundle mainBundle] bundleIdentifier]]
        && redirectUri.scheme.length > 0)
    {
        return YES;
    }

    return NO;
}

@end
