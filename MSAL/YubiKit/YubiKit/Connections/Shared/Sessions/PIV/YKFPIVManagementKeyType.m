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

#import <Foundation/Foundation.h>
#import "YKFPIVManagementKeyType.h"
#import <CommonCrypto/CommonCrypto.h>

NSString * const YKFPIVManagementKeyTypeTripleDES = @"DESede";
NSString * const YKFPIVManagementKeyTypeAES = @"AES";

@interface YKFPIVManagementKeyType()

- (instancetype)initWithName:(NSString *)name value:(UInt8)value keyLength:(int)keyLength challengeLength:(int)challengeLength;

@property (nonatomic, readwrite) NSString *name;
@property (nonatomic, readwrite) UInt8 value;
@property (nonatomic, readwrite) int keyLenght;
@property (nonatomic, readwrite) int challengeLength;

@end


@implementation YKFPIVManagementKeyType

NSString *name;

- (instancetype)initWithName:(NSString *)name value:(UInt8)value keyLength:(int)keyLength challengeLength:(int)challengeLength {
        self = [super init];
        if (self) {
            self.name = name;
            self.value = value;
            self.keyLenght = keyLength;
            self.challengeLength = challengeLength;
        }
        return self;
}

+ (YKFPIVManagementKeyType *)TripleDES {
    return [[YKFPIVManagementKeyType alloc] initWithName:YKFPIVManagementKeyTypeTripleDES value:0x03 keyLength:24 challengeLength:8];
}

+ (YKFPIVManagementKeyType *)AES128 {
    return [[YKFPIVManagementKeyType alloc] initWithName:YKFPIVManagementKeyTypeAES value:0x08 keyLength:16 challengeLength:16];
}

+ (YKFPIVManagementKeyType *)AES192 {
    return [[YKFPIVManagementKeyType alloc] initWithName:YKFPIVManagementKeyTypeAES value:0x0a keyLength:24 challengeLength:16];
}

+ (YKFPIVManagementKeyType *)AES256 {
    return [[YKFPIVManagementKeyType alloc] initWithName:YKFPIVManagementKeyTypeAES value:0x0c keyLength:32 challengeLength:16];
}

+ (YKFPIVManagementKeyType *)fromValue:(UInt8)value {
    switch (value) {
        case 0x03:
            return [self TripleDES];
            break;
        case 0x08:
            return [self AES128];
            break;
        case 0x0a:
            return [self AES192];
            break;
        case 0x0c:
            return [self AES256];
            break;
        default:
            return nil;
            break;
    }
}

@end


@implementation NSString (CryptoNameMapping)

- (uint32_t)ykfCCAlgorithm {
    if ([self isEqual:YKFPIVManagementKeyTypeTripleDES]) {
        return kCCAlgorithm3DES;
    } else {
        return kCCAlgorithmAES;
    }
}

@end
