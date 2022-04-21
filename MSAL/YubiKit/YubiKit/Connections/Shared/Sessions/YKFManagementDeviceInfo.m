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
#import "YKFManagementDeviceInfo+Private.h"
#import "YKFAssert.h"
#import "YKFTLVRecord.h"
#import "NSArray+YKFTLVRecord.h"
#import "YKFNSDataAdditions+Private.h"
#import "YKFVersion.h"
#import "YKFManagementInterfaceConfiguration+Private.h"



@interface YKFManagementDeviceInfo()

@property (nonatomic, readwrite) YKFVersion *version;
@property (nonatomic, readwrite) YKFFormFactor formFactor;
@property (nonatomic, readwrite) NSUInteger serialNumber;
@property (nonatomic, readwrite) bool isLocked;

@property (nonatomic, readwrite) YKFManagementInterfaceConfiguration *configuration;

@end

@implementation YKFManagementDeviceInfo

- (nullable instancetype)initWithResponseData:(nonnull NSData *)data defaultVersion:(nonnull YKFVersion *)defaultVersion {
    YKFAssertAbortInit(data.length);
    YKFAssertAbortInit(defaultVersion)
    self = [super init];
    if (self) {
        const char* bytes = (const char*)[data bytes];
        int length = bytes[0] & 0xff;
        if (length != data.length - 1) {
            return nil;
        }
        NSArray<YKFTLVRecord*> *records = [YKFTLVRecord sequenceOfRecordsFromData:[data subdataWithRange:NSMakeRange(1, data.length -  1)]];
        
        self.isLocked = [[records ykfTLVRecordWithTag:YKFManagementTagConfigLocked].value ykf_integerValue] == 1;
        
        self.serialNumber = [[records ykfTLVRecordWithTag:YKFManagementTagSerialNumber].value ykf_integerValue];
        
        NSData *versionData = [records ykfTLVRecordWithTag:YKFManagementTagFirmwareVersion].value;
        if (versionData != nil) {
            self.version = [[YKFVersion alloc] initWithData:versionData];
        } else {
            self.version = defaultVersion;
        }
        
        NSUInteger reportedFormFactor = [[records ykfTLVRecordWithTag:YKFManagementTagFormfactor].value ykf_integerValue];
        switch (reportedFormFactor & 0xf) {
            case YKFFormFactorUSBAKeychain:
                self.formFactor = YKFFormFactorUSBAKeychain;
                break;
            case YKFFormFactorUSBCKeychain:
                self.formFactor = YKFFormFactorUSBCKeychain;
                break;
            case YKFFormFactorUSBCLightning:
                self.formFactor = YKFFormFactorUSBCLightning;
                break;
            default:
                self.formFactor = YKFFormFactorUnknown;
        }
        
        self.usbSupportedMask = [[records ykfTLVRecordWithTag:YKFManagementTagUSBSupported].value ykf_integerValue];
        self.usbEnabledMask = [[records ykfTLVRecordWithTag:YKFManagementTagUSBEnabled].value ykf_integerValue];
        self.nfcSupportedMask = [[records ykfTLVRecordWithTag:YKFManagementTagNFCSupported].value ykf_integerValue];
        self.nfcEnabledMask = [[records ykfTLVRecordWithTag:YKFManagementTagNFCEnabled].value ykf_integerValue];
        
        self.configuration = [[YKFManagementInterfaceConfiguration alloc] initWithDeviceInfo:self];
    }
    return self;
}

@end
