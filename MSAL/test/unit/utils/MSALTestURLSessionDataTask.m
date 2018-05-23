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


#import "MSALTestURLSessionDataTask.h"
#import "MSIDTestURLSession.h"
#import "MSIDTestURLResponse.h"

@interface MSALTestURLSessionDataTask()

@property MSALTestHttpCompletionBlock completionHandler;
@property MSIDTestURLSession *session;
@property NSURLRequest *request;

@end

@implementation MSALTestURLSessionDataTask

- (id)initWithRequest:(NSURLRequest *)request
              session:(MSIDTestURLSession *)session
    completionHandler:(MSALTestHttpCompletionBlock)completionHandler;
{
    (void)completionHandler;
    
    self = [super init];
    if (self)
    {
        self.completionHandler = completionHandler;
        self.session = session;
        self.request = request;
    }
    return self;
}


- (void)resume
{
    MSIDTestURLResponse *response = [MSIDTestURLSession removeResponseForRequest:self.request];
    
    if (!response)
    {
        [self.session dispatchIfNeed:^{
            NSError* error = [NSError errorWithDomain:NSURLErrorDomain
                                                 code:NSURLErrorNotConnectedToInternet
                                             userInfo:nil];
            
            self.completionHandler(nil, nil, error);
        }];
        
        return;
    }
    
    if (response->_error)
    {
        [self.session dispatchIfNeed:^{
            self.completionHandler(nil, nil, response->_error);
        }];
        return;
    }
    
    if (response->_expectedRequestHeaders)
    {
        BOOL failed = NO;
        for (NSString *key in response->_expectedRequestHeaders)
        {
            NSString *value = [response->_expectedRequestHeaders objectForKey:key];
            NSString *requestValue = [_request.allHTTPHeaderFields objectForKey:key];
            
            if (!requestValue)
            {
                // TODO: Add logging
                // MSID_AD_LOG_ERROR_F(@"Missing request header", AD_FAILED, nil, @"expected \"%@\" header", key);
                failed = YES;
            }
            
            if (![requestValue isEqualToString:value])
            {
                // TODO: Add logging
                // MSID_AD_LOG_ERROR_F(@"Mismatched request header", AD_FAILED, nil, @"On \"%@\" header, expected:\"%@\" actual:\"%@\"", key, value, requestValue);
                failed = YES;
            }
        }
        
        if (failed)
        {
            [self.session dispatchIfNeed:^{
                self.completionHandler(nil, nil, [NSError errorWithDomain:NSURLErrorDomain
                                                                     code:NSURLErrorNotConnectedToInternet
                                                                 userInfo:nil]);
            }];
            return;
        }
    }
    
    self.completionHandler(response->_responseData, response->_response, response->_error);
}


@end
