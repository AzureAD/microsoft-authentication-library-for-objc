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

NS_ASSUME_NONNULL_BEGIN

extern NSString *const MSAL_DEVICE_INFORMATION_SSO_EXTENSION_FULL_MODE_KEY;
extern NSString *const MSAL_DEVICE_INFORMATION_UPN_ID_KEY;
extern NSString *const MSAL_DEVICE_INFORMATION_AAD_DEVICE_ID_KEY;
extern NSString *const MSAL_DEVICE_INFORMATION_AAD_TENANT_ID_KEY;

/**
 Information about the device that is applicable to MSAL scenarios. 
*/
@interface MSALDeviceInformation : NSObject

/**
 Device mode configured by the administrator
*/
@property (nonatomic, readonly) MSALDeviceMode deviceMode API_AVAILABLE(ios(13.0), macos(10.15));

/**
 Specifies whether AAD SSO extension was detected on the device.
*/
@property (nonatomic, readonly) BOOL hasAADSSOExtension;

/**
 Additional device information
*/
@property (nonatomic, readonly) NSDictionary *extraDeviceInformation;

@end

NS_ASSUME_NONNULL_END
