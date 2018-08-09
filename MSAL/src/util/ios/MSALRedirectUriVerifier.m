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
    NSString *scheme = redirectUri.scheme;

    if (![self verifySchemeIsRegistered:scheme error:error])
    {
        return NO;
    }

    if (brokerEnabled)
    {
        NSString *host = [redirectUri host];
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];

        if (![host isEqualToString:bundleIdentifier])
        {
            MSAL_ERROR_PARAM(nil, MSALErrorRedirectSchemeNotRegistered, @"Your MSALPublicClientApplication is configured to allow brokered authentication but your redirect URI is not setup properly. Make sure your redirect URI is in the form of <app-scheme>://<bundle-id> (e.g. \"x-msauth-testapp://com.microsoft.msal.testapp\") and that the \"app-scheme\" you choose is registered in your application's info.plist.");

            return NO;
        }
    }

    return YES;
}

+ (NSURL *)generateRedirectUri:(NSString *)inputRedirectUri
                      clientId:(NSString *)clientId
                 brokerEnabled:(BOOL)brokerEnabled
                         error:(NSError **)error
{
    if (![NSString msidIsStringNilOrBlank:inputRedirectUri])
    {
        return [NSURL URLWithString:inputRedirectUri];
    }

    if ([NSString msidIsStringNilOrBlank:clientId])
    {
        MSAL_ERROR_PARAM(nil, MSALErrorInternal, @"The client ID provided is empty or nil.");
        return nil;
    }

    NSString *scheme = [NSString stringWithFormat:@"msal%@", clientId];
    NSString *hostComponent = brokerEnabled ? [[NSBundle mainBundle] bundleIdentifier] : @"auth";
    NSString *redirectUriString = [NSString stringWithFormat:@"%@://%@", scheme, hostComponent];
    return [NSURL URLWithString:redirectUriString];
}

#pragma mark - Helpers

+ (BOOL)verifySchemeIsRegistered:(NSString *)scheme
                           error:(NSError * __autoreleasing *)error
{
    if ([scheme isEqualToString:@"https"])
    {
        // HTTPS schemes don't need to be registered in the Info.plist file
        return YES;
    }

    NSArray *urlTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];

    for (NSDictionary *urlRole in urlTypes)
    {
        NSArray *urlSchemes = [urlRole objectForKey:@"CFBundleURLSchemes"];
        if ([urlSchemes containsObject:scheme])
        {
            return YES;
        }
    }

    MSAL_ERROR_PARAM(nil, MSALErrorRedirectSchemeNotRegistered, @"The required app scheme \"%@\" is not registered in the app's info.plist file. Please add \"%@\" into Info.plist under CFBundleURLSchemes without any whitespaces.", scheme, scheme);

    return NO;
}

@end
