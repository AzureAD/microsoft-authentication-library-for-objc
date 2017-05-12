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

#import "MSALWebFingerRequest.h"
#import "MSALWebFingerResponse.h"
#import "MSALWebAuthRequest.h"
#import "MSALHttpResponse.h"

@implementation MSALWebFingerRequest

+ (NSURL *)urlForWebFinger:(NSString *)authenticationEndpoint absoluteAuthority:(NSString *)authority
{
    if (!authenticationEndpoint || !authority)
    {
        return nil;
    }
    
    NSURL *endpointFullUrl = [NSURL URLWithString:authenticationEndpoint.lowercaseString];
    NSURL *url = [NSURL URLWithString:
                  [NSString stringWithFormat:@"https://%@/.well-known/webfinger?resource=%@", endpointFullUrl.host, authority]];
    
    
    return url;
}

+ (void)requestForAuthenticationEndpoint:(NSString *)authenticationEndpoint
                               authority:(NSURL *)authority
                                 context:(id<MSALRequestContext>)context
                         completionBlock:(void (^)(MSALWebFingerResponse *response, NSError *error))completionBlock
{
    CHECK_ERROR_COMPLETION(authenticationEndpoint, context, MSALErrorInvalidParameter, @"AuthenticationEndpoint cannot be nil.");
    CHECK_ERROR_COMPLETION(authority, context, MSALErrorInvalidParameter, @"authority cannot be nil.");
    
    MSALWebAuthRequest *request =
    [[MSALWebAuthRequest alloc] initWithURL:[self.class urlForWebFinger:authenticationEndpoint absoluteAuthority:authority.absoluteString]
                                    context:context];
    
    [request sendGet:^(MSALHttpResponse *response, NSError *error) {
        CHECK_COMPLETION(!error);
        
        NSError *jsonError = nil;
        MSALWebFingerResponse *webFingerResponse = [[MSALWebFingerResponse alloc] initWithData:response.body error:&jsonError];
        
        if (jsonError)
        {
            completionBlock(nil, error);
            return;
        }
        
        completionBlock(webFingerResponse, nil);
    }];
}

@end
