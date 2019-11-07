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
    An ADFS authority indicating an endpoint that MSAL can use to obtain tokens when talking to ADFS directly.
    For example: https://somesite.contoso.com/adfs
    @note Modern authentication with Active Directory Federation Services as identity provider (ADFS) is not supported by MSAL. ADFS is supported through federation only.
    Initialization of MSALADFSAuthority will always fail.
 */
@interface MSALADFSAuthority : MSALAuthority

#pragma mark - Initializing MSALADFSAuthority with an NSURL

/**
    Initializes MSALADFSAuthority with NSURL.
    @param     url                    Authority indicating an ADFS instance that MSAL can use to obtain tokens.
    @param     error               The error that occurred creating the authority object, if any, if you're not interested in the specific error pass in nil.
*/
- (nullable instancetype)initWithURL:(nonnull NSURL *)url
                               error:(NSError * _Nullable __autoreleasing * _Nullable)error;

@end
