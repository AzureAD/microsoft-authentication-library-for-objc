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

#import <Foundation/Foundation.h>
#import "MSALAuthority.h"

/**
    B2C endpoint that MSAL will use to get a token and perform B2C policies.
    @note By default, the B2C authority url should be in the following format, where custom_port is optional: https://b2c_host:custom_port/tfp/b2c_tenant/b2c_policy. However, MSAL also supports other arbitrary B2C authority formats.
    See https://docs.microsoft.com/en-us/azure/active-directory-b2c/active-directory-b2c-reference-protocols
*/
@interface MSALB2CAuthority : MSALAuthority

#pragma mark - Constructing a B2C authority

/**
    Initializes MSALB2CAuthority with NSURL.
    @param     url                    Authority indicating a B2C endpoint that MSAL can use to obtain tokens.
    @param     error               The error that occurred creating the authority object, if any, if you're not interested in the specific error pass in nil.
*/
- (nullable instancetype)initWithURL:(nonnull NSURL *)url
                               error:(NSError * _Nullable __autoreleasing * _Nullable)error;

@end
