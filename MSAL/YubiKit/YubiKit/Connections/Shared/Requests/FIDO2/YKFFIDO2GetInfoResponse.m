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

#import "YKFFIDO2GetInfoResponse.h"
#import "YKFFIDO2GetInfoResponse+Private.h"
#import "YKFCBORDecoder.h"
#import "YKFAssert.h"

NSString* const YKFFIDO2GetInfoResponseOptionClientPin = @"clientPin";
NSString* const YKFFIDO2GetInfoResponseOptionPlatformDevice = @"plat";
NSString* const YKFFIDO2GetInfoResponseOptionResidentKey = @"rk";
NSString* const YKFFIDO2GetInfoResponseOptionUserPresence = @"up";
NSString* const YKFFIDO2GetInfoResponseOptionUserVerification = @"uv";

typedef NS_ENUM(NSUInteger, YKFFIDO2GetInfoResponseKey) {
    YKFFIDO2GetInfoResponseKeyVersions       = 0x01,
    YKFFIDO2GetInfoResponseKeyExtensions     = 0x02,
    YKFFIDO2GetInfoResponseKeyAAGUID         = 0x03,
    YKFFIDO2GetInfoResponseKeyOptions        = 0x04,
    YKFFIDO2GetInfoResponseKeyMaxMsgSize     = 0x05,
    YKFFIDO2GetInfoResponseKeyPinProtocols   = 0x06
};

@interface YKFFIDO2GetInfoResponse()

@property (nonatomic, readwrite) NSArray *versions;
@property (nonatomic, readwrite) NSArray *extensions;
@property (nonatomic, readwrite) NSData *aaguid;
@property (nonatomic, readwrite) NSDictionary *options;
@property (nonatomic, assign, readwrite) NSUInteger maxMsgSize;
@property (nonatomic, readwrite) NSArray *pinProtocols;

@end

@implementation YKFFIDO2GetInfoResponse

- (instancetype)initWithCBORData:(NSData *)cborData {
    self = [super init];
    if (self) {
        YKFCBORMap *getInfoMap = nil;
        
        NSInputStream *decoderInputStream = [[NSInputStream alloc] initWithData:cborData];
        [decoderInputStream open];
        getInfoMap = [YKFCBORDecoder decodeObjectFrom:decoderInputStream];
        [decoderInputStream close];
        
        YKFAssertAbortInit(getInfoMap);
        
        BOOL success = [self parseResponseMap:getInfoMap];
        YKFAssertAbortInit(success);
    }
    return self;
}

#pragma mark - Private

- (BOOL)parseResponseMap:(YKFCBORMap *)map {
    id convertedObject = [YKFCBORDecoder convertCBORObjectToFoundationType:map];
    if (!convertedObject || ![convertedObject isKindOfClass:NSDictionary.class]) {
        return NO;
    }
    NSDictionary *response = (NSDictionary *)convertedObject;
    
    // versions
    NSArray *versions = response[@(YKFFIDO2GetInfoResponseKeyVersions)];
    YKFAssertReturnValue(versions, @"authenticatorGetInfo versions is required.", NO);
    self.versions = versions;
    
    // extensions
    self.extensions = response[@(YKFFIDO2GetInfoResponseKeyExtensions)];
    
    // aaguid
    NSData *aaguid = response[@(YKFFIDO2GetInfoResponseKeyAAGUID)];
    YKFAssertReturnValue(aaguid, @"authenticatorGetInfo aaguid is required.", NO);
    YKFAssertReturnValue(aaguid.length == 16, @"authenticatorGetInfo aaguid has the wrong value.", NO);
    self.aaguid = aaguid;
    
    // options
    self.options = response[@(YKFFIDO2GetInfoResponseKeyOptions)];
    
    // maxMsgSize
    NSNumber *maxMsgSize = response[@(YKFFIDO2GetInfoResponseKeyMaxMsgSize)];
    if (maxMsgSize != nil) {
        self.maxMsgSize = maxMsgSize.integerValue;
    }
    
    // pin protocols
    self.pinProtocols = response[@(YKFFIDO2GetInfoResponseKeyPinProtocols)];
        
    return YES;
}

@end
