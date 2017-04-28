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

#import "MSALAadAuthorityResolver.h"
#import "MSALHttpRequest.h"
#import "MSALHttpResponse.h"
#import "MSALInstanceDiscoveryResponse.h"

@implementation MSALAadAuthorityResolver

#define TOKEN_ENDPOINT_SUFFIX           @"oauth2/v2.0/authorize"
#define AUTHORIZE_ENDPOINT_SUFFIX       @"oauth2/v2.0/token"

#define AAD_INSTANCE_DISCOVERY_ENDPOINT @"https://login.microsoftonline.com/common/discovery/instance"
#define API_VERSION                     @"api-version"
#define API_VERSION_VALUE               @"1.0"
#define AUTHORIZATION_ENDPOINT          @"authorization_endpoint"

- (NSString *)defaultOpenIdConfigurationEndpointForAuthority:(NSURL *)authority
{
    if (!authority)
    {
        return nil;
    }
    
    return [authority URLByAppendingPathComponent:@"v2.0/.well-known/openid-configuration"].absoluteString;
}

- (void)openIDConfigurationEndpointForAuthority:(NSURL *)authority
                              userPrincipalName:(NSString *)userPrincipalName
                                       validate:(BOOL)validate
                                        context:(id<MSALRequestContext>)context
                                completionBlock:(OpenIDConfigEndpointCallback)completionBlock
{
    (void)userPrincipalName;
    
    if (!validate || [MSALAuthority isKnownHost:authority])
    {
        NSString *endpoint = [self defaultOpenIdConfigurationEndpointForAuthority:authority];
        completionBlock(endpoint, nil);
        return;
    }

    MSALHttpRequest *request = [[MSALHttpRequest alloc] initWithURL:[NSURL URLWithString:AAD_INSTANCE_DISCOVERY_ENDPOINT]
                                                            context:context];
    [request setValue:API_VERSION_VALUE forQueryParameter:API_VERSION];
    [request setValue:[authority URLByAppendingPathComponent:TOKEN_ENDPOINT_SUFFIX].absoluteString forQueryParameter:AUTHORIZATION_ENDPOINT];
    
    [request sendGet:^(MSALHttpResponse *response, NSError *error)
     {
         if (error)
         {
             completionBlock(nil, error);
             return;
         }
         
         NSError *jsonError = nil;
         MSALInstanceDiscoveryResponse *json = [[MSALInstanceDiscoveryResponse alloc] initWithData:response.body
                                                                                             error:&jsonError];
         if (jsonError)
         {
             completionBlock(nil, error);
             return;
         }
         
         NSString *tenantDiscoverEndpoint = json.tenant_discovery_endpoint;
         
         if ([NSString msalIsStringNilOrBlank:tenantDiscoverEndpoint])
         {
             NSError *tenantDiscoveryError;
             CREATE_ERROR_INVALID_RESULT(context, tenant_discovery_endpoint, tenantDiscoveryError);
             completionBlock(nil, tenantDiscoveryError);
             return;
         }
         completionBlock(tenantDiscoverEndpoint, nil);
         return;
     }];
  
}

@end
