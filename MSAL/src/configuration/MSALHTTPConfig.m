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

#import "MSALHTTPConfig+Internal.h"
#import "MSIDURLSessionManager.h"
#import "MSIDHttpRequest.h"

@implementation MSALHTTPConfig

+ (instancetype)sharedInstance
{
    static MSALHTTPConfig *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self.class alloc] init];
    });
    
    return sharedInstance;
}


- (NSInteger)retryCount { return MSIDHttpRequest.retryCountSetting; }
- (void)setRetryCount:(NSInteger)retryCount { MSIDHttpRequest.retryCountSetting = retryCount; }

- (NSTimeInterval)retryInterval { return MSIDHttpRequest.retryIntervalSetting; }
- (void)setRetryInterval:(NSTimeInterval)retryInterval { MSIDHttpRequest.retryIntervalSetting = retryInterval; }

- (NSTimeInterval)timeoutIntervalForRequest {
    return MSIDHttpRequest.requestTimeoutInterval;
}
- (void)setTimeoutIntervalForRequest:(NSTimeInterval)timeoutIntervalForRequest
{
    MSIDHttpRequest.requestTimeoutInterval = timeoutIntervalForRequest;
}

@end
