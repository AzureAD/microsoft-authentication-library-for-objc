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

/*
 Key to read the UPN of the registeredOwner of the AAD device from the extraDeviceInformation property
 If device has multiple registrations, this will be the primary registration.
 */
extern NSString * _Nonnull const MSAL_PRIMARY_REGISTRATION_UPN;

/*
 Key to read the identifier of the AAD device from the extraDeviceInformation property
 If device has multiple registrations, this will be the primary registration.
 */
extern NSString * _Nonnull const MSAL_PRIMARY_REGISTRATION_DEVICE_ID;

/*
 Key to read the tenant identifier of the AAD device from the extraDeviceInformation property
 If device has multiple registrations, this will be the primary registration.
 */
extern NSString * _Nonnull const MSAL_PRIMARY_REGISTRATION_TENANT_ID;

/*
 Key to read the host of the AAD cloud for the AAD device from the extraDeviceInformation property
 If device has multiple registrations, this will be the primary registration.
 */
extern NSString * _Nonnull const MSAL_PRIMARY_REGISTRATION_CLOUD;

/*
 Key to read the thumbprint of the AAD device registration certificate from the extraDeviceInformation property
 If device has multiple registrations, this will be the primary registration.
 */
extern NSString * _Nonnull const MSAL_PRIMARY_REGISTRATION_CERTIFICATE_THUMBPRINT;

NS_ASSUME_NONNULL_BEGIN

/**
 Information about the device that is applicable to MSAL scenarios. 
*/
@interface MSALDeviceInformation : NSObject

/**
 Device mode configured by the administrator
*/
@property (nonatomic, readonly) MSALDeviceMode deviceMode;

/**
 Specifies whether AAD SSO extension was detected on the device.
*/
@property (nonatomic, readonly) BOOL hasAADSSOExtension;

/**
 Additional device information
*/
@property (nonatomic, readonly) NSDictionary *extraDeviceInformation;

#if TARGET_OS_OSX
/**
 Platform SSO status on macOS device
*/
@property (nonatomic, readonly) MSALPlatformSSOStatus platformSSOStatus;

#endif

@end

NS_ASSUME_NONNULL_END
