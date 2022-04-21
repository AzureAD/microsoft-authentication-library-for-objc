//
//  YKFManagementWriteAPDU.m
//  YubiKit
//
//  Created by Irina Makhalova on 2/3/20.
//  Copyright © 2020 Yubico. All rights reserved.
//

#import "YKFManagementWriteAPDU.h"
#import "YKFAPDUCommandInstruction.h"
#import "YKFManagementInterfaceConfiguration+Private.h"
#import "YKFManagementDeviceInfo+Private.h"
#import "YKFNSMutableDataAdditions.h"
#import "YKFAssert.h"

@implementation YKFManagementWriteAPDU

static UInt8 const YKFManagementConfigurationTagsReboot = 0x0c;

- (instancetype)initWithConfiguration:(nonnull YKFManagementInterfaceConfiguration*)configuration reboot:(BOOL)reboot {
    YKFAssertAbortInit(configuration);

    NSMutableData *configData = [[NSMutableData alloc] init];
    if (configuration.usbMaskChanged) {
        [configData ykf_appendShortWithTag:YKFManagementTagUSBEnabled data:configuration.usbEnabledMask];
    }
    
    if (configuration.nfcMaskChanged) {
        [configData ykf_appendShortWithTag:YKFManagementTagNFCEnabled data:configuration.nfcEnabledMask];
    }
    
    if (reboot) {
        // specify that device requires reboot (force disconnection of YubiKey)
        [configData ykf_appendByte:YKFManagementConfigurationTagsReboot];
        [configData ykf_appendByte:0];
    }
    
    NSMutableData *rawRequest = [[NSMutableData alloc] init];
    [rawRequest ykf_appendByte:configData.length];
    [rawRequest appendData:configData];

    return [super initWithCla:0x00 ins:0x1C p1:0x00 p2:0x00 data:rawRequest type:YKFAPDUTypeShort];
}

@end
