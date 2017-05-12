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
#import "NSURL+MSALExtensions.h"

#import "MSALDrsDiscoveryRequest.h"
#import "MSALDrsDiscoveryResponse.h"
#import "MSALWebFingerRequest.h"
#import "MSALWebFingerResponse.h"

// Trusted realm for webFinger
#define TRUSTED_REALM       @"http://schemas.microsoft.com/rel/trusted-realm"

// DRS server error message
static NSString *const s_kDrsDiscoveryError = @"DRS discovery was invalid or failed to return PassiveAuthEndpoint";
// WebFinger error message
static NSString *const s_kWebFingerError    = @"WebFinger request was invalid or failed";

@implementation MSALAdfsAuthorityResolver

- (NSString *)defaultOpenIdConfigurationEndpointForAuthority:(NSURL *)authority
{
    if (!authority)
    {
        return nil;
    }
    return [authority URLByAppendingPathComponent:@".well-known/openid-configuration"].absoluteString;
}

- (void)openIDConfigurationEndpointForAuthority:(NSURL *)authority
                              userPrincipalName:(NSString *)userPrincipalName
                                       validate:(BOOL)validate
                                        context:(id<MSALRequestContext>)context
                                completionBlock:(OpenIDConfigEndpointCallback)completionBlock
{
    if (!validate || [MSALAuthority isKnownHost:authority])
    {
        NSString *endpoint = [self defaultOpenIdConfigurationEndpointForAuthority:authority];
        completionBlock(endpoint, nil);
        return;
    }
    
    // DRS discovery request
    [self getMetadataFromEnrollmentServerForUPN:userPrincipalName
                                        context:context
                                completionBlock:^(MSALDrsDiscoveryResponse *response, NSError *error)
    {
        if (!response || !response.passiveAuthEndpoint)
        {
            if (!error)
            {
                error = CREATE_LOG_ERROR(context, MSALErrorFailedAuthorityValidation, s_kDrsDiscoveryError);
            }
            completionBlock(nil, error);
            return;
        }
        
        // Webfinger request
        [MSALWebFingerRequest requestForAuthenticationEndpoint:response.passiveAuthEndpoint
                                                     authority:authority
                                                       context:context
                                               completionBlock:^(MSALWebFingerResponse *response, NSError *error)
         {
            if (!response ||
                ![self isRealmTrustedFromWebFingerPayload:response.links authority:authority])
            {
                if (!error)
                {
                    error = CREATE_LOG_ERROR(context, MSALErrorFailedAuthorityValidation, s_kWebFingerError);
                }
                completionBlock(nil, error);
                return;
            }
            completionBlock([self defaultOpenIdConfigurationEndpointForAuthority:authority], nil);
        }];
    }];
}

#pragma mark -
#pragma mark - DRS discovery request

- (void)getMetadataFromEnrollmentServerForUPN:(NSString *)upn
                                      context:(id<MSALRequestContext>)context
                              completionBlock:(void (^)(MSALDrsDiscoveryResponse *response, NSError *error))completionBlock
{
    NSString *domain = [self getUPNSuffix:upn];
    CHECK_ERROR_COMPLETION(domain, context, MSALErrorInvalidParameter, @"User principal name (UPN) is invalid.");
    
    [MSALDrsDiscoveryRequest queryEnrollmentServerEndpointForDomain:domain
                                                           adfsType:MSAL_ADFS_ON_PREMS
                                                            context:context
                                                    completionBlock:^(MSALDrsDiscoveryResponse *response, NSError *error)
     {
         (void)error;
         if (response)
         {
             completionBlock(response, nil);
             return;
         }
         
         [MSALDrsDiscoveryRequest queryEnrollmentServerEndpointForDomain:domain
                                                                adfsType:MSAL_ADFS_CLOUD
                                                                 context:context
                                                         completionBlock:^(MSALDrsDiscoveryResponse *response, NSError *error)
          {
              completionBlock(response, error);
          }];
     }];
}

#pragma mark -
#pragma mark - Helper methods

- (NSString *)getUPNSuffix:(NSString *)upn
{
    if (!upn)
    {
        return nil;
    }
    
    NSArray *array = [upn componentsSeparatedByString:@"@"];
    if (array.count != 2)
    {
        return nil;
    }
    
    return array[1];
}

- (BOOL)isRealmTrustedFromWebFingerPayload:(NSArray<MSALWebFingerLink *> *)links
                                 authority:(NSURL *)authority
{
    for (MSALWebFingerLink *link in links)
    {
        if ([link.rel caseInsensitiveCompare:TRUSTED_REALM] == NSOrderedSame &&
            [[NSURL URLWithString:link.href] isEquivalentAuthority:authority])
        {
            return YES;
        }
    }
    return NO;
}

@end
