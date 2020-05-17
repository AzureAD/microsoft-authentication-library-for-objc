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

NSString *const MSAL_DEVICE_INFORMATION_SSO_EXTENSION_FULL_MODE_KEY = @"isSSOExtensionInFullMode";
NSString *const MSAL_DEVICE_INFORMATION_UPN_ID_KEY = @"upnIdentifier";
NSString *const MSAL_DEVICE_INFORMATION_AAD_DEVICE_ID_KEY = @"aadDeviceIdentifier";
NSString *const MSAL_DEVICE_INFORMATION_AAD_TENANT_ID_KEY = @"aadTenantIdentifier";

@implementation MSALDeviceInformation
{
    NSMutableDictionary *_extraDeviceInformation;
}

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        if (@available(iOS 13.0, macOS 10.15, *))
        {
            _hasAADSSOExtension = [[ASAuthorizationSingleSignOnProvider msidSharedProvider] canPerformAuthorization];
        }
        else
        {
            _hasAADSSOExtension = NO;
        }
        
        _extraDeviceInformation = [NSMutableDictionary new];
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

// For readability, both keys and values in the output dictionary are NSString
- (void) addExtraDeviceInformation:(MSIDDeviceInfo *)deviceInfo
{
    _deviceMode = [self msalDeviceModeFromMSIDMode:deviceInfo.deviceMode];
    [_extraDeviceInformation setValue:deviceInfo.ssoExtensionMode == MSIDSSOExtensionModeFull ? @"Yes" : @"No" forKey:MSAL_DEVICE_INFORMATION_SSO_EXTENSION_FULL_MODE_KEY];
}

- (void) addWorkPlaceJoinedDeviceId:(NSString *)deviceId
{
    [_extraDeviceInformation setValue:deviceId forKey:MSAL_DEVICE_INFORMATION_AAD_DEVICE_ID_KEY];
}

- (void) addWorkPlaceJoinedTenantId:(NSString *)tenantID
{
    [_extraDeviceInformation setValue:tenantID forKey:MSAL_DEVICE_INFORMATION_AAD_TENANT_ID_KEY];
}

- (void) addWorkPlaceJoinedUPN:(NSString *)upn
{
    [_extraDeviceInformation setValue:upn forKey:MSAL_DEVICE_INFORMATION_UPN_ID_KEY];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Device mode %@", self.msalDeviceModeString];
}

@end
