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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, YKFManagementApplicationType) {
    YKFManagementApplicationTypeOTP = 0x01,
    YKFManagementApplicationTypeU2F = 0x02,
    YKFManagementApplicationTypeOPGP = 0x08,
    YKFManagementApplicationTypePIV = 0x10,
    YKFManagementApplicationTypeOATH = 0x20,
    YKFManagementApplicationTypeCTAP2 = 0x0200
};

typedef NS_ENUM(NSUInteger, YKFManagementTransportType) {
    YKFManagementTransportTypeNFC = 1,
    YKFManagementTransportTypeUSB = 2
};

@interface YKFManagementInterfaceConfiguration : NSObject

@property (nonatomic, readonly) BOOL isConfigurationLocked;

- (BOOL)isEnabled:(YKFManagementApplicationType)application overTransport:(YKFManagementTransportType)transport;
- (BOOL)isSupported:(YKFManagementApplicationType)application overTransport:(YKFManagementTransportType)transport;
- (void)setEnabled:(BOOL)newValue application:(YKFManagementApplicationType)application overTransport:(YKFManagementTransportType)transport;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
