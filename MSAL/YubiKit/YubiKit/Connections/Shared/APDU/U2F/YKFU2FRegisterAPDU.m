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

#import "YKFU2FRegisterAPDU.h"
#import "YKFAPDUCommandInstruction.h"
#import "YKFNSDataAdditions.h"
#import "YKFAssert.h"
#import "YKFNSDataAdditions+Private.h"

/*
 DOMString typ as defined in FIDO U2F Raw Message Format
 https://fidoalliance.org/specs/u2f-specs-1.0-bt-nfc-id-amendment/fido-u2f-raw-message-formats.html
 */
static NSString* const U2FClientDataTypeRegistration = @"navigator.id.finishEnrollment";

static const UInt8 YKFU2FRegisterAPDUEnforceUserPresenceAndSign = 0x03;

@interface YKFU2FRegisterAPDU()

@property (nonatomic, readwrite) NSString *clientData;

@end

@implementation YKFU2FRegisterAPDU

- (nullable instancetype)initWithChallenge:(NSString *)challenge appId:(NSString *)appId {
    YKFAssertAbortInit(challenge);
    YKFAssertAbortInit(appId);

    /*
     Client data as defined in FIDO U2F Raw Message Format
     https://fidoalliance.org/specs/u2f-specs-1.0-bt-nfc-id-amendment/fido-u2f-raw-message-formats.html
     Note: The "cid_pubkey" is missing in this case since the TLS stack on iOS does not support channel id.
     */
    NSDictionary *jsonDictionary = @{@"type": U2FClientDataTypeRegistration,
                                     @"challenge": challenge,
                                     @"origin": appId};
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDictionary options:0 error:&error];
    self.clientData = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    YKFAssertAbortInit(self.clientData)
    
    NSData *challengeSHA256 = [[self.clientData dataUsingEncoding:NSUTF8StringEncoding] ykf_SHA256];
    YKFAssertAbortInit(challengeSHA256);
    
    NSData *applicationSHA256 = [[appId dataUsingEncoding:NSUTF8StringEncoding] ykf_SHA256];
    YKFAssertAbortInit(applicationSHA256);
    
    NSMutableData *data = [[NSMutableData alloc] init];
    
    [data appendData:challengeSHA256];
    [data appendData:applicationSHA256];
    
    return [super initWithCla:0 ins:YKFAPDUCommandInstructionU2FRegister p1:YKFU2FRegisterAPDUEnforceUserPresenceAndSign p2:0 data:data type:YKFAPDUTypeExtended];
}

@end
