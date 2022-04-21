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

#import "YKFOATHCalculateAPDU.h"
#import "YKFOATHCredential.h"
#import "YKFAPDUCommandInstruction.h"
#import "YKFAssert.h"
#import "YKFNSMutableDataAdditions.h"
#import "YKFOATHCredential+Private.h"
#import "YKFOATHCredentialUtils.h"

static const UInt8 YKFOATHCalculateAPDUNameTag = 0x71;
static const UInt8 YKFOATHCalculateAPDUChallengeTag = 0x74;

@implementation YKFOATHCalculateAPDU

- (nullable instancetype)initWithCredential:(YKFOATHCredential *)credential timestamp:(NSDate *)timestamp {
    YKFAssertAbortInit(credential);
    
    NSMutableData *data = [[NSMutableData alloc] init];
    
    // Name
    NSString *name = [YKFOATHCredentialUtils keyFromCredentialIdentifier:credential];
    NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
    
    [data ykf_appendEntryWithTag:YKFOATHCalculateAPDUNameTag data:nameData];
    
    // Challenge
    if (credential.type == YKFOATHCredentialTypeTOTP) {
        time_t time = (time_t)[timestamp timeIntervalSince1970];
        time_t challengeTime = time / credential.period;
        
        [data ykf_appendUInt64EntryWithTag:YKFOATHCalculateAPDUChallengeTag value:challengeTime];
    } else {
        // For HOTP the challenge is 0
        [data ykf_appendByte:YKFOATHCalculateAPDUChallengeTag];
        [data ykf_appendByte:0];
    }
    
    // P2 is 0x01 for truncated response only
    return [super initWithCla:0 ins:YKFAPDUCommandInstructionOATHCalculate p1:0 p2:1 data:data type:YKFAPDUTypeShort];
}

@end
