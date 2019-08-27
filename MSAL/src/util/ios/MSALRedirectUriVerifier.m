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
#import "MSALRedirectUri+Internal.h"
#import "MSIDConstants.h"

@implementation MSALRedirectUriVerifier

+ (MSALRedirectUri *)msalRedirectUriWithCustomUri:(NSString *)customRedirectUri
                                         clientId:(NSString *)clientId
                                            error:(NSError * __autoreleasing *)error
{
#if AD_BROKER
    // Allow the broker app to use a special redirect URI when acquiring tokens
    if ([customRedirectUri isEqualToString:MSID_AUTHENTICATOR_REDIRECT_URI])
    {
        return [[MSALRedirectUri alloc] initWithRedirectUri:[NSURL URLWithString:customRedirectUri]
                                              brokerCapable:YES];

    }
#endif

    // If developer provides their own redirect uri, verify it
    if (![NSString msidIsStringNilOrBlank:customRedirectUri])
    {
        NSURL *redirectURI = [NSURL URLWithString:customRedirectUri];

        if (![self verifySchemeIsRegistered:redirectURI error:error])
        {
            return nil;
        }

        BOOL brokerCapable = [self redirectUriIsBrokerCapable:redirectURI];

        MSALRedirectUri *redirectUri = [[MSALRedirectUri alloc] initWithRedirectUri:redirectURI
                                                                      brokerCapable:brokerCapable];

        return redirectUri;
    }

    // First try to check for broker capable redirect URI
    NSURL *defaultRedirectUri = [MSALRedirectUri defaultBrokerCapableRedirectUri];

    NSError *redirectError = nil;
    if ([self verifySchemeIsRegistered:defaultRedirectUri error:&redirectError])
    {
        return [[MSALRedirectUri alloc] initWithRedirectUri:defaultRedirectUri brokerCapable:YES];
    }

    // Now check the uri that is not broker capable for backward compat
    defaultRedirectUri = [MSALRedirectUri defaultNonBrokerRedirectUri:clientId];

    if ([self verifySchemeIsRegistered:defaultRedirectUri error:nil])
    {
        return [[MSALRedirectUri alloc] initWithRedirectUri:defaultRedirectUri brokerCapable:NO];
    }

    if (error)
    {
        *error = redirectError;
    }

    return nil;
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

#pragma mark - Helpers

+ (BOOL)verifySchemeIsRegistered:(NSURL *)redirectUri
                           error:(NSError * __autoreleasing *)error
{
    NSString *scheme = redirectUri.scheme;

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

    NSString *message = [NSString stringWithFormat:@"The required app scheme \"%@\" is not registered in the app's info.plist file. Please add \"%@\" into Info.plist under CFBundleURLSchemes without any whitespaces and make sure that redirectURi \"%@\" is register in the portal for your app.", scheme, scheme, redirectUri.absoluteString];
    MSIDFillAndLogError(error, MSIDErrorRedirectSchemeNotRegistered, message, nil);

    return NO;
}

@end
