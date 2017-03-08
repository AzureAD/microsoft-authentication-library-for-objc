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

#import "MSALAdfsAuthorityResolver.h"

#define DEFAULT_OPENID_CONFIGURATION_ENDPOINT @".well-known/openid-configuration"

static NSMutableDictionary<NSString *, MSALAuthority *> *s_validatedAuthorities;

@implementation MSALAdfsAuthorityResolver

- (void)openIDConfigurationEndpointForURL:(NSURL *)url
                        userPrincipalName:(NSString *)userPrincipalName
                                 validate:(BOOL)validate
                                  context:(id<MSALRequestContext>)context
                          completionBlock:(OpenIDConfigEndpointCallback)completionBlock
{
    CHECK_ERROR_COMPLETION(userPrincipalName, context, MSALErrorInvalidParameter, @"User principal name cannot be null");
    
    if (validate)
    {
        
        NSError *error = CREATE_LOG_ERROR(context, MSALErrorInvalidRequest, @"Authority validation for AD FS is not enabled in MSAL");
        completionBlock(nil, error);
        return;
    }
    
    NSString *host = url.host;
    NSString *tenant = url.pathComponents[1];
    
    completionBlock([self defaultOpenIdConfigurationEndpointForHost:host tenant:tenant], nil);
}

- (NSString *)defaultOpenIdConfigurationEndpointForHost:(NSString *)host tenant:(NSString *)tenant
{
    if ([NSString msalIsStringNilOrBlank:host] || [NSString msalIsStringNilOrBlank:tenant])
    {
        return nil;
    }
    return [NSString stringWithFormat:@"https://%@/%@/%@", host, tenant, DEFAULT_OPENID_CONFIGURATION_ENDPOINT];
}

- (MSALAuthority *)authorityFromCache:(NSURL *)authority
                    userPrincipalName:(NSString *)userPrincipalName
{
    (void)authority;
    (void)userPrincipalName;
    @throw @"TODO";
    return nil;
}

- (BOOL)addToValidatedAuthorityCache:(MSALAuthority *)authority
                   userPrincipalName:(NSString *)userPrincipalName
{
    (void)authority;
    (void)userPrincipalName;
    @throw @"TODO";
    return NO;
}



@end
