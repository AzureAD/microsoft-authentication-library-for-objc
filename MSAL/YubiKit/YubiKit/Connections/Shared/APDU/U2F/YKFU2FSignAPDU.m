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

#import "YKFU2FSignAPDU.h"
#import "YKFAPDUCommandInstruction.h"
#import "YKFNSDataAdditions.h"
#import "YKFAssert.h"
#import "YKFNSDataAdditions+Private.h"

/*
 DOMString typ as defined in FIDO U2F Raw Message Format
 https://fidoalliance.org/specs/u2f-specs-1.0-bt-nfc-id-amendment/fido-u2f-raw-message-formats.html
 */
static NSString* const U2FClientDataTypeAuthentication = @"navigator.id.getAssertion";

/*
 Client data as defined in FIDO U2F Raw Message Format
 https://fidoalliance.org/specs/u2f-specs-1.0-bt-nfc-id-amendment/fido-u2f-raw-message-formats.html
 Note: The "cid_pubkey" is missing in this case since the TLS stack on iOS does not support channel id.
 */
static NSString* const U2FClientDataTypeTemplate = @"\{\"typ\":\"%@\",\"challenge\":\"%@\",\"origin\":\"%@\"}";

static const UInt8 YKFU2FSignAPDUKeyHandleSize = 64;
static const UInt8 YKFU2FSignAPDUEnforceUserPresenceAndSign = 0x03;


@interface YKFU2FSignAPDU()

@property (nonatomic, readwrite) NSString *clientData;

@end

@implementation YKFU2FSignAPDU

- (instancetype)initWithChallenge:(NSString *)challenge keyHandle:(NSString *)keyHandle appId:(NSString *)appId {
    YKFAssertAbortInit(challenge);
    YKFAssertAbortInit(keyHandle);
    YKFAssertAbortInit(appId);
    
    self.clientData = [[NSString alloc] initWithFormat:U2FClientDataTypeTemplate, U2FClientDataTypeAuthentication, challenge, appId];
    
    NSData *challengeSHA256 = [[self.clientData dataUsingEncoding:NSUTF8StringEncoding] ykf_SHA256];
    YKFAssertAbortInit(challengeSHA256);
    
    NSData *applicationSHA256 = [[appId dataUsingEncoding:NSUTF8StringEncoding] ykf_SHA256];
    YKFAssertAbortInit(applicationSHA256);
    
    NSMutableData *rawU2FRequest = [NSMutableData data];
    
    [rawU2FRequest appendData:challengeSHA256];
    [rawU2FRequest appendData:applicationSHA256];
    
    NSData *keyHandleData = [[NSData alloc] ykf_initWithWebsafeBase64EncodedString:keyHandle dataLength:YKFU2FSignAPDUKeyHandleSize];
    UInt8 keyHandleLength = [keyHandleData length];
    YKFAssertAbortInit(keyHandle);
    YKFAssertAbortInit(keyHandleLength <= UINT8_MAX);
    
    [rawU2FRequest appendBytes:&keyHandleLength length:1];
    [rawU2FRequest appendData:keyHandleData];
    
    return [super initWithCla:0 ins:YKFAPDUCommandInstructionU2FSign p1:YKFU2FSignAPDUEnforceUserPresenceAndSign p2:0 data:rawU2FRequest type:YKFAPDUTypeExtended];
}

@end
