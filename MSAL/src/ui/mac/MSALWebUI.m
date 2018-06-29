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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSALWebUI.h"

@implementation MSALWebUI

+ (void)startWebUIWithURL:(NSURL *)url
                  context:(id<MSALRequestContext>)context
           callbackScheme:(NSString *)callbackScheme
          completionBlock:(MSALWebUICompletionBlock)completionBlock
{
    (void)url;
    (void)context;
    (void)callbackScheme;
    (void)completionBlock;
    
    @throw @"MSAL is not supported on macOS at this time.";
}

+ (BOOL)handleResponse:(NSURL *)url
{
    (void)url;
    @throw @"MSAL is not supported on macOS at this time.";
}

+ (BOOL)cancelCurrentWebAuthSession
{
    return NO;
}

@end
