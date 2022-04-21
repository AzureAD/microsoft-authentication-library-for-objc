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

#import "YKFOATHUnlockAPDU.h"
#import "YKFAPDUCommandInstruction.h"
#import "YKFOATHCredential.h"
#import "YKFAssert.h"
#import "YKFNSMutableDataAdditions.h"
#import "YKFNSDataAdditions+Private.h"

static const UInt8 YKFOATHSetCodeAPDUChallengeTag = 0x74;
static const UInt8 YKFOATHSetCodeAPDUResponseTag = 0x75;

@implementation YKFOATHUnlockAPDU

- (nullable instancetype)initWithPassword:(nonnull NSString *)password challenge:(NSData *)challenge salt:(NSData *)salt {
    YKFAssertAbortInit(password);
    YKFAssertAbortInit(challenge);
    YKFAssertAbortInit(salt.length);
    
    NSMutableData *data = [[NSMutableData alloc] init];
    
    NSData *keyData = [[password dataUsingEncoding:NSUTF8StringEncoding] ykf_deriveOATHKeyWithSalt:salt];
    
    // Response (hmac of the select challenge)
    
    NSData *response = [challenge ykf_oathHMACWithKey:keyData];
    [data ykf_appendEntryWithTag:YKFOATHSetCodeAPDUResponseTag data:response];
        
    // Challenge (random bytes)
    
    UInt8 challengeBuffer[8];
    arc4random_buf(challengeBuffer, 8);
    NSData *randomChallenge = [NSData dataWithBytes:challengeBuffer length:8];
    
    self.expectedChallengeData = [randomChallenge ykf_oathHMACWithKey:keyData];
    [data ykf_appendEntryWithTag:YKFOATHSetCodeAPDUChallengeTag data:randomChallenge];
        
    return [super initWithCla:0 ins:YKFAPDUCommandInstructionOATHValidate p1:0 p2:0 data:data type:YKFAPDUTypeShort];
}

@end
