//
//  YKFPIVKeyType.m
//  YubiKit
//
//  Created by Jens Utbult on 2021-03-18.
//  Copyright © 2021 Yubico. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YKFPIVKeyType.h"

YKFPIVKeyType YKFPIVKeyTypeFromKey(SecKeyRef key) {
    NSDictionary *attributes = (__bridge NSDictionary*)SecKeyCopyAttributes(key);
    long size = [attributes[(__bridge NSString*)kSecAttrKeySizeInBits] integerValue];
    NSString *type = attributes[(__bridge NSString*)kSecAttrKeyType];
    if ([type isEqual:(__bridge NSString*)kSecAttrKeyTypeRSA]) {
        if (size == 1024) {
            return YKFPIVKeyTypeRSA1024;
        }
        if (size == 2048) {
            return YKFPIVKeyTypeRSA2048;
        }
    }
    if ([type isEqual:(__bridge NSString*)kSecAttrKeyTypeEC]) {
        if (size == 256) {
            return YKFPIVKeyTypeECCP256;
        }
        if (size == 384) {
            return YKFPIVKeyTypeECCP384;
        }
    }
    return YKFPIVKeyTypeUnknown;
}


int YKFPIVSizeFromKeyType(YKFPIVKeyType keyType) {
    switch (keyType) {
        case YKFPIVKeyTypeECCP256:
            return 256 / 8;
        case YKFPIVKeyTypeECCP384:
            return 384 / 8;
        case YKFPIVKeyTypeRSA1024:
            return 1024 / 8;
        case YKFPIVKeyTypeRSA2048:
            return 2048 / 8;
        default:
            return 0;
    }
}
