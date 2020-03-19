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

#import "MSALPublicClientApplication.h"
#import "MSALDefinitions.h"
#import "MSALParameters.h"

NS_ASSUME_NONNULL_BEGIN

/**
 An interface that contains list of operations that are available when MSAL is in 'single account' mode - which means there's only one account available on the device.
*/
@interface MSALPublicClientApplication (SingleAccount)

/**
 Gets the current account and return previous account if present. This can be useful to detect if the current account changes.
 This method must be called whenever the application is resumed or prior to running a scheduled background operation.
 
 If there're multiple accounts present, MSAL will return an ambiguous account error, and application should do account disambiguation by calling other MSAL Account enumeration APIs.
*/
- (void)getCurrentAccountWithParameters:(nullable MSALParameters *)parameters
                        completionBlock:(MSALCurrentAccountCompletionBlock)completionBlock;

@end

NS_ASSUME_NONNULL_END
