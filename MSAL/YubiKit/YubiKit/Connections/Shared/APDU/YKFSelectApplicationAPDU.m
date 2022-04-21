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
#import "YKFSelectApplicationAPDU.h"
#import "YKFAPDUCommandInstruction.h"

@implementation  YKFSelectApplicationAPDU

- (instancetype)initWithData:(NSData *)data {
    return [super initWithCla:0x00 ins:YKFAPDUCommandInstructionSelectApplication p1:0x04 p2:0x00 data:data type:YKFAPDUTypeShort];
}

- (instancetype)initWithApplicationName:(YKFSelectApplicationAPDUName)application {
    NSData *data = nil;
    switch (application) {
        case YKFSelectApplicationAPDUNameManagement:
            data = [NSData dataWithBytes:(UInt8[]){0xA0, 0x00, 0x00, 0x05, 0x27, 0x47, 0x11, 0x17} length:8];
            break;
        case YKFSelectApplicationAPDUNameChalResp:
            data = [NSData dataWithBytes:(UInt8[]){0xA0, 0x00, 0x00, 0x05, 0x27, 0x20, 0x01, 0x01} length:8];
            break;
        case YKFSelectApplicationAPDUNameFIDO2:
            data = [NSData dataWithBytes:(UInt8[]){0xA0, 0x00, 0x00, 0x06, 0x47, 0x2F, 0x00, 0x01} length:8];
            break;
        case YKFSelectApplicationAPDUNamePIV:
            data = [NSData dataWithBytes:(UInt8[]){0xA0, 0x00, 0x00, 0x03, 0x08} length:5];
            break;
        case YKFSelectApplicationAPDUNameOATH:
            data = [NSData dataWithBytes:(UInt8[]){0xA0, 0x00, 0x00, 0x05, 0x27, 0x21, 0x01} length:7];
            break;
        case YKFSelectApplicationAPDUNameU2F:
            data = [NSData dataWithBytes:(UInt8[]){0xA0, 0x00, 0x00, 0x06, 0x47, 0x2F, 0x00, 0x01} length:8];
            break;
    }
    return [self initWithData:data];
};

@end

