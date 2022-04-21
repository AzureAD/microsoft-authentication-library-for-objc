// Copyright 2018-2020 Yubico AB
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


#import <Foundation/Foundation.h>

#ifndef YKFSmartCardInterface_h
#define YKFSmartCardInterface_h

@class YKFAPDU, YKFSelectApplicationAPDU;
@protocol YKFConnectionControllerProtocol;

typedef void (^YKFSmartCardInterfaceResponseBlock)
    (NSData* _Nullable data, NSError* _Nullable error);

typedef void (^YKFSmartCardInterfaceCommandBlock)(void);

typedef NS_ENUM(NSUInteger, YKFSmartCardInterfaceSendRemainingIns) {
    
    /// The APDU instruction to read the remaining data from the Yubikey.
    YKFSmartCardInterfaceSendRemainingInsNormal,
    
    /// The APDU instruction to read the remaining data from the OATH application on the Yubikey.
    YKFSmartCardInterfaceSendRemainingInsOATH,
};

@interface YKFSmartCardInterface: NSObject

NS_ASSUME_NONNULL_BEGIN

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithConnectionController:(id<YKFConnectionControllerProtocol>)connectionController NS_DESIGNATED_INITIALIZER;

- (void)selectApplication:(YKFSelectApplicationAPDU *)apdu completion:(YKFSmartCardInterfaceResponseBlock)completion;

- (void)executeCommand:(YKFAPDU *)apdu completion:(YKFSmartCardInterfaceResponseBlock)completion;

- (void)executeCommand:(YKFAPDU *)apdu timeout:(NSTimeInterval)timeout completion:(YKFSmartCardInterfaceResponseBlock)completion;

- (void)executeCommand:(YKFAPDU *)apdu sendRemainingIns:(YKFSmartCardInterfaceSendRemainingIns)sendRemainingIns completion:(YKFSmartCardInterfaceResponseBlock)completion;

- (void)executeCommand:(YKFAPDU *)apdu sendRemainingIns:(YKFSmartCardInterfaceSendRemainingIns)sendRemainingIns timeout:(NSTimeInterval)timeout completion:(YKFSmartCardInterfaceResponseBlock)completion;

- (void)dispatchAfterCurrentCommands:(YKFSmartCardInterfaceCommandBlock)block;

NS_ASSUME_NONNULL_END

@end

#endif
