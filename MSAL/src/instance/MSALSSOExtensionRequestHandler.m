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

#import "MSALSSOExtensionRequestHandler.h"

@interface MSALSSOExtensionRequestHandler()

@property (nullable, nonatomic) id currentRequest;

@end

@implementation MSALSSOExtensionRequestHandler

#pragma mark - Request tracking

- (BOOL)setCurrentSSOExtensionRequest:(id)request
{
    @synchronized (self)
    {
        if (self.currentRequest)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Request is already executing. Please wait or cancel the request before starting it again.");
            return NO;
        }
        
        self.currentRequest = request;
        return YES;
    }
    
    return NO;
}

- (id)copyAndClearCurrentSSOExtensionRequest
{
    @synchronized (self)
    {
        if (!self.currentRequest)
        {
            // There's no error param because this isn't on a critical path. Just log that you are
            // trying to clear a request when there isn't one.
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Trying to clear out an empty request");
            return nil;
        }
        
        id currentRequest = self.currentRequest;
        self.currentRequest = nil;
        return currentRequest;
    }
}

@end
