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

#import "MSALDrsDiscoveryRequest.h"
#import "MSALDrsDiscoveryResponse.h"
#import "MSALWebAuthRequest.h"
#import "MSALHttpResponse.h"

@implementation MSALDrsDiscoveryRequest

+ (NSURL *)urlForDrsDiscoveryForDomain:(NSString *)domain adfsType:(AdfsType)type
{
    if (!domain)
    {
        return nil;
    }
    
    if (type == MSAL_ADFS_ON_PREMS)
    {
        return [NSURL URLWithString:
                [NSString stringWithFormat:@"https://enterpriseregistration.%@/enrollmentserver/contract?api-version=1.0", domain.lowercaseString]];
    }
    else if (type == MSAL_ADFS_CLOUD)
    {
        return [NSURL URLWithString:
                [NSString stringWithFormat:@"https://enterpriseregistration.windows.net/%@/enrollmentserver/contract?api-version=1.0", domain.lowercaseString]];
    }
    
    @throw @"unrecognized type";
}

+ (void)queryEnrollmentServerEndpointForDomain:(NSString *)domain
                                      adfsType:(AdfsType)type
                                       context:(id<MSALRequestContext>)context
                               completionBlock:(void (^)(MSALDrsDiscoveryResponse *response, NSError *error))completionBlock
{
    CHECK_ERROR_COMPLETION(domain, context, MSALErrorInvalidParameter, @"Domain cannot be nil.");
    
    MSALWebAuthRequest *request =
    [[MSALWebAuthRequest alloc] initWithURL:[self.class urlForDrsDiscoveryForDomain:domain adfsType:type]
                                    context:context];
    
    [request sendGet:^(MSALHttpResponse *response, NSError *error) {
        CHECK_COMPLETION(!error);
        
        NSError *jsonError = nil;
        MSALDrsDiscoveryResponse *drsResponse = [[MSALDrsDiscoveryResponse alloc] initWithData:response.body
                                                                                         error:&jsonError];
        if (jsonError)
        {
            completionBlock(nil, error);
            return;
        }
        
        completionBlock(drsResponse, nil);
    }];
}

@end
