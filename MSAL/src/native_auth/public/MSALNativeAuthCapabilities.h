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

#ifndef MSALNativeAuthCapabilities_h
#define MSALNativeAuthCapabilities_h

#import <Foundation/Foundation.h>

/// The set of capabilities that an application wishes to support for Native Auth operations.
///
/// Valid options are:
/// * MFARequired: The application can accommodate the associated challenge type(s) specified by the user when MFA is required.
/// * RegistrationRequired: The application can accommodate the associated challenge type(s) specified by the user
/// when registering a new strong authentication method is required.
typedef NS_OPTIONS(NSInteger, MSALNativeAuthCapabilities) {
    /// Specifies that the associated challenge type(s) are supported when MFA is required
    MSALNativeAuthCapabilityMFARequired          = 1 << 0,
    
    /// Specifies that the associated challenge type(s) are supported when the registration of a new strong authentication method is required
    MSALNativeAuthCapabilityRegistrationRequired     = 1 << 1
};

#endif /* MSALNativeAuthCapabilities_h */
