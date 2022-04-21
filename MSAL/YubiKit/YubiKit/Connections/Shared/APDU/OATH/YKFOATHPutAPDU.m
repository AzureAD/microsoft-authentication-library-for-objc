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

#import "YKFOATHPutAPDU.h"
#import "YKFAPDUCommandInstruction.h"
#import "YKFAssert.h"
#import "YKFNSMutableDataAdditions.h"
#import "YKFOATHCredentialTemplate.h"
#import "YKFOATHCredential+Private.h"
#import "YKFOATHCredentialUtils.h"

typedef NS_ENUM(NSUInteger, YKFOATHPutCredentialAPDUTag) {
    YKFOATHPutCredentialAPDUTagName = 0x71,
    YKFOATHPutCredentialAPDUTagKey = 0x73,
    YKFOATHPutCredentialAPDUTagProperty = 0x78,
    YKFOATHPutCredentialAPDUTagCounter = 0x7A // Only HOTP
};

typedef NS_ENUM(NSUInteger, YKFOATHPutCredentialAPDUProperty) {
    YKFOATHPutCredentialAPDUPropertyTouch = 0x02
};

@implementation YKFOATHPutAPDU

- (instancetype)initWithCredentialTemplate:(YKFOATHCredentialTemplate *)credential requriesTouch:(BOOL)requiresTouch {
    YKFAssertAbortInit(credential);
    
    NSMutableData *rawRequest = [[NSMutableData alloc] init];
    
    // Name - max 64 bytes
    NSString *name = [YKFOATHCredentialUtils keyFromCredentialIdentifier:credential];
    NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
    [rawRequest ykf_appendEntryWithTag:YKFOATHPutCredentialAPDUTagName data:nameData];
    
    // Key
    NSData *secret = credential.secret;
    UInt8 keyAlgorithm = credential.algorithm | credential.type;
    UInt8 keyDigits = credential.digits;
    
    [rawRequest ykf_appendEntryWithTag:YKFOATHPutCredentialAPDUTagKey headerBytes:@[@(keyAlgorithm), @(keyDigits)] data:secret];
    
    // Touch
    if (requiresTouch) {
        [rawRequest ykf_appendByte:YKFOATHPutCredentialAPDUTagProperty];
        [rawRequest ykf_appendByte:YKFOATHPutCredentialAPDUPropertyTouch];
    }
    
    // Counter if HOTP
    if (credential.type == YKFOATHCredentialTypeHOTP) {
        [rawRequest ykf_appendUInt32EntryWithTag:YKFOATHPutCredentialAPDUTagCounter value:credential.counter];
    }
    
    return [super initWithCla:0 ins:YKFAPDUCommandInstructionOATHPut p1:0 p2:0 data:rawRequest type:YKFAPDUTypeShort];
}

@end
