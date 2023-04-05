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

#import <Foundation/Foundation.h>
#import "MSALAuthority.h"

/**
    CIAM endpoint that MSAL will use to get a token and perform CIAM policies.
     @note By default, the CIAM authority url should be in the following format https://tenant.ciamlogin.com. However, MSAL also supports other arbitrary CIAM such as: https://tenant.ciamlogin.com/GUID and https://tenant.ciamlogin.com/aDomain, where GUID is tenantID and aDomain and domainName
*/
@interface MSALCIAMAuthority : MSALAuthority

#pragma mark - Constructing a CIAM authority

/**
 Initializes MSALCIAMAuthority with NSURL.
 @param     url                    Authority indicating a CIAM endpoint that MSAL can use to obtain tokens.
 @param     error               The error that occurred creating the authority object, if any, if you're not interested in the specific error pass in nil.
 //*/

- (nullable instancetype)initWithURL:(nonnull NSURL *)url
                               error:(NSError * _Nullable __autoreleasing * _Nullable)error;

- (nullable instancetype)initWithURL:(nonnull NSURL *)url
                      validateFormat:(BOOL)validateFormat
                               error:(NSError * _Nullable __autoreleasing * _Nullable)error NS_DESIGNATED_INITIALIZER;
@end
