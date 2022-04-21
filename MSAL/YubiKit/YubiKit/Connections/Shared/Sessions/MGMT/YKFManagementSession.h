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
#import "YKFVersion.h"
#import "YKFSession.h"

@class YKFManagementDeviceInfo, YKFManagementInterfaceConfiguration;

/// Management error domain.
extern NSString* _Nonnull const YKFManagementErrorDomain;

/// Management error codes.
typedef NS_ENUM(NSUInteger, YKFManagementErrorCode) {
    YKFManagementErrorCodeUnsupportedOperation = 1,
};

/// @abstract
///    Response block for [getDeviceInfoWithCompletion:] which provides the device info for the
///    currently connected YubiKey.
///
/// @param deviceInfo
///    The response of the request when it was successful. In case of error this parameter is nil.
///
/// @param error
///    In case of a failed request this parameter contains the error. If the request was successful this
///    parameter is nil.
typedef void (^YKFManagementSessionGetDeviceInfoBlock)
    (YKFManagementDeviceInfo* _Nullable deviceInfo, NSError* _Nullable error);

/// @abstract
///    Response block for [writeConfiguration:reboot:completion:] which writes a new configuration to
///    the YubiKey.
///
/// @param error
///    In case of a failed request this parameter contains the error. If the request was successful this
///    parameter is nil.
typedef void (^YKFManagementSessionWriteCompletionBlock) (NSError* _Nullable error);

NS_ASSUME_NONNULL_BEGIN

/// @abstract Defines the interface for YKFManagementSessionProtocol.
@interface YKFManagementSession : YKFSession <YKFVersionProtocol>

/// @abstract
///    Reads configuration from YubiKey (what interfaces/applications are enabled and supported)
///
/// @param completion
///    The response block which is executed after the request was processed by the key. The completion block
///    will be executed on a background thread.
///
/// @note:
///    This method requires support for device info, available in YubiKey 4.1 or later.
///    The method is thread safe and can be invoked from any thread (main or a background thread).
- (void)getDeviceInfoWithCompletion:(YKFManagementSessionGetDeviceInfoBlock)completion;

/// @abstract
///    Writes configuration to YubiKey (allos to enable and disable applications on YubiKey)
///
/// @param configuration
///    The configurations that represent information on which interfaces/applications need to be enabled
///
/// @param reboot
///    The device reboots after setting configuration.
///
/// @param completion
///    The response block which is executed after the request was processed by the key. The completion block
///    will be executed on a background thread.
///
/// @note
///   This method requires support for device config, available in YubiKey 5.0 or later.
///   The method is thread safe and can be invoked from any thread (main or a background thread).
- (void)writeConfiguration:(YKFManagementInterfaceConfiguration*)configuration reboot:(BOOL)reboot completion:(nonnull YKFManagementSessionWriteCompletionBlock)completion;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
