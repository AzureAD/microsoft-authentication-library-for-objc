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

#import "MSALWebAuthResponse.h"
#import "MSALHttpResponse.h"
#import "MSALError.h"

@interface MSALWebAuthResponse()

{
    MSALWebAuthRequest *_request;
    id<MSALRequestContext> _context;
}

@end


@implementation MSALWebAuthResponse

NSString *const s_kWwwAuthenticateHeader = @"Accept";

+ (void)processResponse:(MSALHttpResponse *)response
                request:(MSALWebAuthRequest *)request
                context:(id<MSALRequestContext>)context
      completionHandler:(MSALHttpRequestCallback)completionHandler
{
    MSALWebAuthResponse *webAuthResponse = [MSALWebAuthResponse new];
    webAuthResponse->_request = request;
    webAuthResponse->_context = context;
    
    [webAuthResponse handleResponse:response
                  completionHandler:completionHandler];
    
}


- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    return self;
}


- (void)handleResponse:(MSALHttpResponse *)response
     completionHandler:(MSALHttpRequestCallback)completionHandler
{
    switch (response.statusCode) {
        case 200:
            completionHandler(response, nil);
            break;
        
        case 400:
        case 401:
        {
#if PKEYAUTH_IMPLEMENTED
            NSString *wwwAuthValue = [response.headers valueForKey:s_kWwwAuthenticateHeader];
            
            @throw @"to-do";
#endif
            completionHandler(response, nil);
            break;
        }
            
        case 500:
        case 503:
        case 504:
        {
            // retry if it is a server error
            // 500, 503 and 504 are the ones we retry
            if (_request.retryIfServerError)
            {
                _request.retryIfServerError = NO;

                // retry once after hald second
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [_request resend:completionHandler];
                });
                return;
            }
            //no "break;" here
            //will go to default for handling if "retryIfServerError" is NO
        }
        default:
        {
            // TODO: Check for right error code and details.
            //   Perhaps a utility class to generate NSError would be nice
            NSString *body = [[NSString alloc] initWithData:response.body encoding:NSUTF8StringEncoding];
            NSString *errorData = [NSString stringWithFormat:@"Full response: %@", body];
            
            NSString* message = [NSString stringWithFormat:@"Error raised: (Domain: \"%@\" Response Code: %ld \n%@", @"Domain", (long)response.statusCode, errorData];
            
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey: message};
            
            NSError *error = [NSError errorWithDomain:@"Domain"
                                                 code:MSALErrorNetworkFailure
                                             userInfo:userInfo];
            
            LOG_WARN(_context, @"%@", message);
            
            completionHandler(response, error);
            
            break;
        }
    }
}

@end
