// Copyright 2018-2019 Yubico AB
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

#import "YKFOATHDeleteAPDU.h"
#import "YKFOATHCredential.h"
#import "YKFAPDUCommandInstruction.h"
#import "YKFAssert.h"
#import "YKFNSMutableDataAdditions.h"
#import "YKFOATHCredential+Private.h"
#import "YKFOATHCredentialUtils.h"

static const UInt8 YKFOATHDeleteAPDUNameTag = 0x71;

@implementation YKFOATHDeleteAPDU

- (instancetype)initWithCredential:(YKFOATHCredential *)credential {
    YKFAssertAbortInit(credential);
    
    NSMutableData *data = [[NSMutableData alloc] init];
    NSString *name = [YKFOATHCredentialUtils keyFromCredentialIdentifier:credential];
    [data ykf_appendEntryWithTag:YKFOATHDeleteAPDUNameTag data:[name dataUsingEncoding:NSUTF8StringEncoding]];
    return [super initWithCla:0 ins:YKFAPDUCommandInstructionOATHDelete p1:0 p2:0 data:data type:YKFAPDUTypeShort];
}

@end
