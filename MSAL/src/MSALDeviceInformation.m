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

#import "MSALDeviceInformation.h"
#import "MSALDeviceInformation+Internal.h"
#import "MSIDDeviceInfo.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "MSIDBrokerConstants.h"

NSString *const MSAL_DEVICE_INFORMATION_SSO_EXTENSION_FULL_MODE_KEY = @"isSSOExtensionInFullMode";
NSString *const MSAL_PRIMARY_REGISTRATION_UPN = @"primary_registration_metadata_upn";
NSString *const MSAL_PRIMARY_REGISTRATION_DEVICE_ID = @"primary_registration_metadata_device_id";
NSString *const MSAL_PRIMARY_REGISTRATION_TENANT_ID = @"primary_registration_metadata_tenant_id";
NSString *const MSAL_PRIMARY_REGISTRATION_CLOUD = @"primary_registration_metadata_cloud_host";
NSString *const MSAL_PRIMARY_REGISTRATION_CERTIFICATE_THUMBPRINT = @"primary_registration_metadata_certificate_thumbprint";

@implementation MSALDeviceInformation
{
    // For readability, both keys and values in the output dictionary are NSString
    NSMutableDictionary<NSString *,NSString *> *_extraDeviceInformation;
}

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        _deviceMode = MSALDeviceModeDefault;
        _extraDeviceInformation = [NSMutableDictionary new];
        
        if (@available(macOS 10.15, *))
        {
            _hasAADSSOExtension = [[ASAuthorizationSingleSignOnProvider msidSharedProvider] canPerformAuthorization];
        }
        else
        {
            _hasAADSSOExtension = NO;
        }
    }

    return self;
}

- (instancetype)initWithMSIDDeviceInfo:(MSIDDeviceInfo *)deviceInfo
{
    self = [super init];

    if (self)
    {
        _deviceMode = [self msalDeviceModeFromMSIDMode:deviceInfo.deviceMode];

        if (@available(macOS 10.15, *))
        {
            _hasAADSSOExtension = [[ASAuthorizationSingleSignOnProvider msidSharedProvider] canPerformAuthorization];
        }
        else
        {
            _hasAADSSOExtension = NO;
        }
        
#if TARGET_OS_OSX
        _platformSSOStatus = [self msalPlatformSSOStatusFromMSIDPlatformSSOStatus:deviceInfo.platformSSOStatus];
#endif

        _extraDeviceInformation = [NSMutableDictionary new];
        [self initExtraDeviceInformation:deviceInfo];
    }

    return self;
}

- (NSDictionary *)extraDeviceInformation
{
    return _extraDeviceInformation;
}

- (MSALDeviceMode)msalDeviceModeFromMSIDMode:(MSIDDeviceMode)msidDeviceMode
{
    switch (msidDeviceMode) {
        case MSIDDeviceModeShared:
            return MSALDeviceModeShared;
            
        default:
            return MSALDeviceModeDefault;
    }
}

- (NSString *)msalDeviceModeString
{
    switch (self.deviceMode) {
        case MSALDeviceModeShared:
            return @"shared";
            
        default:
            return @"default";
    }
}

- (MSALPlatformSSOStatus)msalPlatformSSOStatusFromMSIDPlatformSSOStatus:(MSIDPlatformSSOStatus)msidPlatformSSOStatus
{
    switch (msidPlatformSSOStatus) {
        case MSIDPlatformSSOEnabledNotRegistered:
            return MSALPlatformSSOEnabledNotRegistered;
        case MSIDPlatformSSOEnabledAndRegistered:
            return MSALPlatformSSOEnabledAndRegistered;
            
        default:
            return MSALPlatformSSONotEnabled;
    }
}

// For readability, both keys and values in the output dictionary are NSString
- (void) initExtraDeviceInformation:(MSIDDeviceInfo *)deviceInfo
{
    [_extraDeviceInformation setValue:deviceInfo.ssoExtensionMode == MSIDSSOExtensionModeFull ? @"Yes" : @"No" forKey:MSAL_DEVICE_INFORMATION_SSO_EXTENSION_FULL_MODE_KEY];
    
    if (deviceInfo.extraDeviceInfo)
    {
        [_extraDeviceInformation addEntriesFromDictionary:deviceInfo.extraDeviceInfo];
    }
    
}

- (void)addRegisteredDeviceMetadataInformation:(NSDictionary *)deviceInfoMetadata
{
    [_extraDeviceInformation addEntriesFromDictionary:deviceInfoMetadata];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Device mode %@", self.msalDeviceModeString];
}

@end
