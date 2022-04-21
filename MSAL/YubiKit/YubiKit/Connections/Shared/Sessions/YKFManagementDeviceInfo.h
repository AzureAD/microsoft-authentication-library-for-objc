// Copyright 2018-2021 Yubico AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef YKFDeviceInfo_h
#define YKFDeviceInfo_h


@class YKFVersion, YKFManagementInterfaceConfiguration;

typedef NS_ENUM(NSUInteger, YKFFormFactor) {
    /// Used when information about the YubiKey's form factor isn't available.
    YKFFormFactorUnknown = 0x00,
    /// A keychain-sized YubiKey with a USB-A connector.
    YKFFormFactorUSBAKeychain = 0x01,
    /// A keychain-sized YubiKey with a USB-C connector.
    YKFFormFactorUSBCKeychain = 0x03,
    /// A keychain-sized YubiKey with both USB-C and Lightning connectors.
    YKFFormFactorUSBCLightning = 0x05,
};

NS_ASSUME_NONNULL_BEGIN

@interface YKFManagementDeviceInfo : NSObject

@property (nonatomic, readonly, nullable) YKFManagementInterfaceConfiguration* configuration;

@property (nonatomic, readonly) YKFVersion *version;
@property (nonatomic, readonly) YKFFormFactor formFactor;
@property (nonatomic, readonly) NSUInteger serialNumber;
@property (nonatomic, readonly) bool isConfigurationLocked;

@end

NS_ASSUME_NONNULL_END

#endif /* YKFDeviceInfo_h */
