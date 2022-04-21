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

#import "YKFManagementInterfaceConfiguration.h"
#import "YKFManagementDeviceInfo+Private.h"
#import "YKFManagementDeviceInfo.h"
#import "YKFAssert.h"

@interface YKFManagementInterfaceConfiguration()

@property (nonatomic, readwrite) BOOL isConfigurationLocked;

@property (nonatomic, readwrite) NSUInteger usbSupportedMask;
@property (nonatomic, readwrite) NSUInteger nfcSupportedMask;

@property (nonatomic, readwrite) NSUInteger usbEnabledMask;
@property (nonatomic, readwrite) NSUInteger nfcEnabledMask;

@property (nonatomic, readwrite) BOOL usbMaskChanged;
@property (nonatomic, readwrite) BOOL nfcMaskChanged;

@end

@implementation YKFManagementInterfaceConfiguration

- (nullable instancetype)initWithDeviceInfo:(nonnull YKFManagementDeviceInfo *)deviceInfo {
    YKFAssertAbortInit(deviceInfo);
    self = [super init];
    if (self) {

        self.isConfigurationLocked = deviceInfo.isConfigurationLocked;
        self.usbSupportedMask = deviceInfo.usbSupportedMask;
        self.nfcSupportedMask = deviceInfo.nfcSupportedMask;
        self.usbEnabledMask = deviceInfo.usbEnabledMask;
        self.nfcEnabledMask = deviceInfo.nfcEnabledMask;
    }
    return self;
}

- (BOOL) isSupported: (YKFManagementApplicationType)application overTransport:(YKFManagementTransportType)transport {
    switch (transport) {
        case YKFManagementTransportTypeNFC:
            return (self.nfcSupportedMask & application) == application;
        case YKFManagementTransportTypeUSB:
            return (self.usbSupportedMask & application) == application;
        default:
            YKFAssertReturnValue(true, @"Not supperted transport type", false);
            break;
    }
}

- (BOOL) isEnabled: (YKFManagementApplicationType)application overTransport:(YKFManagementTransportType)transport {
    switch (transport) {
        case YKFManagementTransportTypeNFC:
            return (self.nfcEnabledMask & application) == application;
        case YKFManagementTransportTypeUSB:
            return (self.usbEnabledMask & application) == application;
        default:
            YKFAssertReturnValue(true, @"Not supperted transport type", false);
            break;
    }
}

- (void) setEnabled: (BOOL)newValue application:(YKFManagementApplicationType)application overTransport:(YKFManagementTransportType)transport {
    NSUInteger oldEnabledMask = transport == YKFManagementTransportTypeUSB ? self.usbEnabledMask : self.nfcEnabledMask;
    NSUInteger newEnabledMask = newValue ? (oldEnabledMask | application) : (oldEnabledMask & ~application);

    if (oldEnabledMask == newEnabledMask) {
        // check if there is no changes needs to be applied
        return;
    }

    YKFAssertReturn(!self.isConfigurationLocked, @"Configuration is locked.")
    YKFAssertReturn([self isSupported: application overTransport:transport], @"This YubiKey interface is not supported.")

    switch (transport) {
        case YKFManagementTransportTypeNFC:
            self.nfcEnabledMask = newEnabledMask;
            self.nfcMaskChanged = true;
            break;
        case YKFManagementTransportTypeUSB:
            self.usbEnabledMask = newEnabledMask;
            self.usbMaskChanged = true;
            break;
        default:
            YKFAssertReturn(true, @"Not supperted transport type");
            break;
    }
}

@end
