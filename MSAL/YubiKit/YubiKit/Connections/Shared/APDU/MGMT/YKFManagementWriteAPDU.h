//
//  YKFManagementWriteAPDU.h
//  YubiKit
//
//  Created by Irina Makhalova on 2/3/20.
//  Copyright © 2020 Yubico. All rights reserved.
//

#import "YKFAPDU.h"
NS_ASSUME_NONNULL_BEGIN

@class YKFManagementInterfaceConfiguration;

@interface YKFManagementWriteAPDU : YKFAPDU

- (instancetype)initWithConfiguration:(nonnull YKFManagementInterfaceConfiguration*)configuration reboot:(BOOL)reboot NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
