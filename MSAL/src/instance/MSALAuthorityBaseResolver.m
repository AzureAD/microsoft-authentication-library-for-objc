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

#import "MSALAuthorityBaseResolver.h"
#import "MSALHttpRequest.h"
#import "MSALHttpResponse.h"
#import "MSALTenantDiscoveryResponse.h"

@implementation MSALAuthorityBaseResolver

#define TENANT_DISCOVERY_INVALID_RESPONSE_MESSAGE @"Tenant discovery response does not contain all of authorization_endpoint, token_endpoint and issuer"

- (void)tenantDiscoveryEndpoint:(NSURL *)url
                        context:(id<MSALRequestContext>)context
                completionBlock:(TenantDiscoveryCallback)completionBlock
{
    MSALHttpRequest *request = [[MSALHttpRequest alloc] initWithURL:url
                                                            context:context];

    [request sendGet:^(MSALHttpResponse *response, NSError *error) {
        CHECK_COMPLETION(!error);

        NSError *jsonError = nil;
        MSALTenantDiscoveryResponse *tenantDiscoveryResponse = [[MSALTenantDiscoveryResponse alloc] initWithData:response.body
                                                                                                           error:&jsonError];
        if (jsonError)
        {
            completionBlock(nil, jsonError);
            return;
        }
        
        NSString *authorizationEndpoint = tenantDiscoveryResponse.authorization_endpoint;
        NSString *tokenEndpoint = tenantDiscoveryResponse.token_endpoint;
        NSString *issuer = tenantDiscoveryResponse.issuer;
        
        if ([NSString msalIsStringNilOrBlank:authorizationEndpoint] ||
            [NSString msalIsStringNilOrBlank:tokenEndpoint] ||
            [NSString msalIsStringNilOrBlank:issuer])
        {
            MSALLogError(context, MSALErrorDomain, MSALErrorInvalidResponse, TENANT_DISCOVERY_INVALID_RESPONSE_MESSAGE, nil, nil,  __FUNCTION__, __LINE__);
            
            NSError *discoveryError = MSALCreateError(MSALErrorDomain, MSALErrorInvalidResponse, TENANT_DISCOVERY_INVALID_RESPONSE_MESSAGE, nil, nil, nil);
            completionBlock(nil, discoveryError);
            return;
        }
        
        completionBlock(tenantDiscoveryResponse, nil);
    }];
}

@end

