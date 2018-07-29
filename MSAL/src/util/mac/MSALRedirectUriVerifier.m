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

#import "MSALRedirectUriVerifier.h"

@implementation MSALRedirectUriVerifier

+ (BOOL)verifyRedirectUri:(NSURL *)redirectUri
            brokerEnabled:(BOOL)brokerEnabled
                    error:(NSError **)error
{
    // There's currently no verification necessary for macOS redirectUri
    return YES;
}

+ (NSURL *)generateRedirectUri:(NSString *)inputRedirectUri
                      clientId:(NSString *)clientId
                 brokerEnabled:(BOOL)brokerEnabled
                         error:(NSError **)error
{
    if ([NSString msidIsStringNilOrBlank:clientId])
    {
        MSAL_ERROR_PARAM(nil, MSALErrorInternal, @"The client ID provided is empty or nil.");
        return nil;
    }

    if (![NSString msidIsStringNilOrBlank:inputRedirectUri])
    {
        return [NSURL URLWithString:inputRedirectUri];
    }
    else
    {
        // macOS doesn't support broker
        NSString *scheme = [NSString stringWithFormat:@"msal%@", clientId];
        NSString *redirectUriString = [NSString stringWithFormat:@"%@://auth", scheme];
        return [NSURL URLWithString:redirectUriString];
    }
}

@end
