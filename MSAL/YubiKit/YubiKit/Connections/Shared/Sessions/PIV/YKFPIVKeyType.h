//
//  YKFPIVKeyType.h
//  YubiKit
//
//  Created by Jens Utbult on 2021-03-18.
//  Copyright © 2021 Yubico. All rights reserved.
//

#ifndef YKFPIVKeyType_h
#define YKFPIVKeyType_h

typedef NS_ENUM(NSUInteger, YKFPIVKeyType) {
    YKFPIVKeyTypeRSA1024 = 0x06,
    YKFPIVKeyTypeRSA2048 = 0x07,
    YKFPIVKeyTypeECCP256 = 0x11,
    YKFPIVKeyTypeECCP384 = 0x14,
    YKFPIVKeyTypeUnknown = 0x00
};

YKFPIVKeyType YKFPIVKeyTypeFromKey(SecKeyRef key);
int YKFPIVSizeFromKeyType(YKFPIVKeyType keyType);

#endif /* YKFPIVKeyType_h */
