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

#import "YKFFIDO2GetAssertionAPDU.h"
#import "YKFCBORType.h"
#import "YKFCBOREncoder.h"
#import "YKFAssert.h"
#import "YKFFIDO2Type.h"
#import "YKFFIDO2Type+Private.h"

typedef NS_ENUM(NSUInteger, YKFFIDO2GetAssertionAPDUKey) {
    YKFFIDO2GetAssertionAPDUKeyRp               = 0x01,
    YKFFIDO2GetAssertionAPDUKeyClientDataHash   = 0x02,
    YKFFIDO2GetAssertionAPDUKeyAllowList        = 0x03,
    YKFFIDO2GetAssertionAPDUKeyExtensions       = 0x04,
    YKFFIDO2GetAssertionAPDUKeyOptions          = 0x05,
    YKFFIDO2GetAssertionAPDUKeyPinAuth          = 0x06,
    YKFFIDO2GetAssertionAPDUKeyPinProtocol      = 0x07
};

@implementation YKFFIDO2GetAssertionAPDU

- (nullable instancetype)initWithClientDataHash:(NSData *)clientDataHash
                                           rpId:(NSString *)rpId
                                      allowList:(NSArray * _Nullable)allowList
                                        pinAuth:(NSData * _Nullable)pinAuth
                                    pinProtocol:(NSUInteger)pinProtocol
                                        options:(NSDictionary * _Nullable)options {
    YKFAssertAbortInit(clientDataHash);
    YKFAssertAbortInit(rpId);
    
    NSMutableDictionary *requestDictionary = [[NSMutableDictionary alloc] init];
    
    // RP
    requestDictionary[YKFCBORInteger(YKFFIDO2GetAssertionAPDUKeyRp)] = YKFCBORTextString(rpId);
    
    // Client Data Hash
    requestDictionary[YKFCBORInteger(YKFFIDO2GetAssertionAPDUKeyClientDataHash)] = YKFCBORByteString(clientDataHash);
    
    // Allow List
    if (allowList) {
        NSMutableArray *mutableAllowList = [[NSMutableArray alloc] initWithCapacity:allowList.count];
        for (YKFFIDO2PublicKeyCredentialDescriptor *credentialDescriptor in allowList) {
            [mutableAllowList addObject:[credentialDescriptor cborTypeObject]];
        }
        requestDictionary[YKFCBORInteger(YKFFIDO2GetAssertionAPDUKeyAllowList)] = YKFCBORArray(mutableAllowList);
    }
    
    // Options
    if (options) {
        NSMutableDictionary *mutableOptions = [[NSMutableDictionary alloc] initWithCapacity:options.count];
        NSArray *optionsKeys = options.allKeys;
        for (NSString *optionKey in optionsKeys) {
            NSNumber *value = options[optionKey];
            mutableOptions[YKFCBORTextString(optionKey)] = YKFCBORBool(value.boolValue);
        }
        requestDictionary[YKFCBORInteger(YKFFIDO2GetAssertionAPDUKeyOptions)] = YKFCBORMap(mutableOptions);
    }

    // Pin Auth
    if (pinAuth) {
        requestDictionary[YKFCBORInteger(YKFFIDO2GetAssertionAPDUKeyPinAuth)] = YKFCBORByteString(pinAuth);
    }

    // Pin Protocol
    if (pinProtocol) {
        requestDictionary[YKFCBORInteger(YKFFIDO2GetAssertionAPDUKeyPinProtocol)] = YKFCBORInteger(pinProtocol);
    }
    
    NSData *cborData = [YKFCBOREncoder encodeMap:YKFCBORMap(requestDictionary)];
    YKFAssertAbortInit(cborData);
    
    return [super initWithCommand:YKFFIDO2CommandGetAssertion data:cborData];
}

@end
