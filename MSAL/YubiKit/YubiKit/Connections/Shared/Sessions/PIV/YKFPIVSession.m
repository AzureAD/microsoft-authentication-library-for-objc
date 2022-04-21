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
#import <CommonCrypto/CommonCrypto.h>
#import "YKFPIVSession.h"
#import "YKFPIVSession+Private.h"
#import "YKFSession+Private.h"
#import "YKFSmartCardInterface.h"
#import "YKFSelectApplicationAPDU.h"
#import "YKFVersion.h"
#import "YKFFeature.h"
#import "YKFPIVSessionFeatures.h"
#import "YKFSessionError.h"
#import "YKFNSDataAdditions+Private.h"
#import "NSArray+YKFTLVRecord.h"
#import "YKFPIVManagementKeyType.h"
#import "YKFAPDU+Private.h"
#import "YKFPIVError.h"
#import "YKFSessionError+Private.h"
#import "YKFPIVManagementKeyMetadata+Private.h"
#import "YKFPIVPadding+Private.h"
#import "TKTLVRecordAdditions+Private.h"
#import "YKFTLVRecord.h"

NSString* const YKFPIVErrorDomain = @"com.yubico.piv";

// Special slot for the management key
static const NSUInteger YKFPIVSlotCardManagement = 0x9b;

// Instructions
static const NSUInteger YKFPIVInsAuthenticate = 0x87;
static const NSUInteger YKFPIVInsVerify = 0x20;
static const NSUInteger YKFPIVInsReset = 0xfb;
static const NSUInteger YKFPIVInsGetVersion = 0xfd;
static const NSUInteger YKFPIVInsGetSerial = 0xf8;
static const NSUInteger YKFPIVInsGetMetadata = 0xf7;
static const NSUInteger YKFPIVInsGetData = 0xcb;
static const NSUInteger YKFPIVInsPutData = 0xdb;
static const NSUInteger YKFPIVInsImportKey = 0xfe;
static const NSUInteger YKFPIVInsChangeReference = 0x24;
static const NSUInteger YKFPIVInsResetRetry = 0x2c;
static const NSUInteger YKFPIVInsSetManagementKey = 0xff;
static const NSUInteger YKFPIVInsSetPinPukAttempts = 0xfa;
static const NSUInteger YKFPIVInsGenerateAsymetric = 0x47;
static const NSUInteger YKFPIVInsAttest = 0xf9;


// Tags for parsing responses and preparing reqeusts
static const NSUInteger YKFPIVTagMetadataIsDefault = 0x05;
static const NSUInteger YKFPIVTagMetadataAlgorithm = 0x01;
static const NSUInteger YKFPIVTagMetadataTouchPolicy = 0x02;
static const NSUInteger YKFPIVTagMetadataRetries = 0x06;
static const NSUInteger YKFPIVTagDynAuth = 0x7c;
static const NSUInteger YKFPIVTagAuthWitness = 0x80;
static const NSUInteger YKFPIVTagChallenge = 0x81;
static const NSUInteger YKFPIVTagExponentiation = 0x85;
static const NSUInteger YKFPIVTagAuthResponse = 0x82;
static const NSUInteger YKFPIVTagGenAlgorithm = 0x80;
static const NSUInteger YKFPIVTagObjectData = 0x53;
static const NSUInteger YKFPIVTagObjectId = 0x5c;
static const NSUInteger YKFPIVTagCertificate = 0x70;
static const NSUInteger YKFPIVTagCertificateInfo = 0x71;
static const NSUInteger YKFPIVTagLRC = 0xfe;
static const NSUInteger YKFPIVTagPinPolicy = 0xaa;
static const NSUInteger YKFPIVTagTouchPolicy = 0xab;

// P2
static const NSUInteger YKFPIVP2Pin = 0x80;
static const NSUInteger YKFPIVP2Puk = 0x81;

typedef void (^YKFPIVSessionDataCompletionBlock)
    (NSData* _Nullable data, NSError* _Nullable error);

@interface YKFPIVSession()

@property (nonatomic, readonly) BOOL isValid;
@property (nonatomic, readwrite) YKFVersion * _Nonnull version;
@property (nonatomic, readwrite) YKFPIVSessionFeatures * _Nonnull features;

@end

@implementation YKFPIVSession

- (NSData *)objectIdForSlot:(YKFPIVSlot)slot {
    switch (slot) {
        case YKFPIVSlotSignature:
            return [NSData dataWithBytes:(UInt8[]){0x5f, 0xc1, 0x0a} length:3];
        case YKFPIVSlotAttestation:
            return [NSData dataWithBytes:(UInt8[]){0x5f, 0xff, 0x01} length:3];
        case YKFPIVSlotAuthentication:
            return [NSData dataWithBytes:(UInt8[]){0x5f, 0xc1, 0x05} length:3];
        case YKFPIVSlotCardAuth:
            return [NSData dataWithBytes:(UInt8[]){0x5f, 0xc1, 0x01} length:3];
        case YKFPIVSlotKeyManagement:
            return [NSData dataWithBytes:(UInt8[]){0x5f, 0xc1, 0x0b} length:3];
        default:
            [NSException raise:@"UnknownObjectId" format:@"No matching object id for this slot."];
            break;
    }
}


int currentPinAttempts = 3;
int maxPinAttempts = 3;

+ (void)sessionWithConnectionController:(nonnull id<YKFConnectionControllerProtocol>)connectionController
                             completion:(YKFPIVSessionCompletion _Nonnull)completion {
    YKFPIVSession *session = [YKFPIVSession new];
    session.features = [YKFPIVSessionFeatures new];
    session.smartCardInterface = [[YKFSmartCardInterface alloc] initWithConnectionController:connectionController];
    
    YKFSelectApplicationAPDU *apdu = [[YKFSelectApplicationAPDU alloc] initWithApplicationName:YKFSelectApplicationAPDUNamePIV];
    [session.smartCardInterface selectApplication:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
        } else {
            YKFAPDU *versionAPDU = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsGetVersion p1:0 p2:0 data:[NSData data] type:YKFAPDUTypeShort];
            [session.smartCardInterface executeCommand:versionAPDU completion:^(NSData * _Nullable data, NSError * _Nullable error) {
                if (error) {
                    completion(nil, error);
                } else {
                    if ([data length] < 3) {
                        completion(nil, [[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodeInvalidResponse userInfo:@{NSLocalizedDescriptionKey: @"Invalid response when retrieving PIV version."}]);
                        return;
                    }
                    UInt8 *versionBytes = (UInt8 *)data.bytes;
                    session.version = [[YKFVersion alloc] initWithBytes:versionBytes[0] minor:versionBytes[1] micro:versionBytes[2]];
                    completion(session, nil);
                }
            }];
        }
    }];
}

- (void)clearSessionState {
    // Do nothing for now
}

- (void)signWithKeyInSlot:(YKFPIVSlot)slot type:(YKFPIVKeyType)keyType algorithm:(SecKeyAlgorithm)algorithm message:(nonnull NSData *)message completion:(nonnull YKFPIVSessionSignCompletionBlock)completion {
    NSError *padError = nil;
    NSData *payload = [YKFPIVPadding padData:message keyType:keyType algorithm:algorithm error:&padError];
    if (padError != nil) {
        completion(nil, padError);
    }
    return [self usePrivateKeyInSlot:slot type:keyType message:payload exponentiation:false completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        completion(data, error);
    }];
}

- (void)decryptWithKeyInSlot:(YKFPIVSlot)slot algorithm:(SecKeyAlgorithm)algorithm encrypted:(NSData *)encrypted completion:(nonnull YKFPIVSessionDecryptCompletionBlock)completion {
    YKFPIVKeyType keyType;
    switch (encrypted.length) {
        case 1024 / 8:
            keyType = YKFPIVKeyTypeRSA1024;
            break;
        case 2048 / 8:
            keyType = YKFPIVKeyTypeRSA2048;
            break;
        default:
            completion(nil, [[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodeInvalidCipherTextLength userInfo:@{NSLocalizedDescriptionKey: @"Invalid lenght of cipher text."}]);
            return;
    }
    [self usePrivateKeyInSlot:slot type:keyType message:encrypted exponentiation:false completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        NSError *unpadError = nil;
        NSData *unpaddedData = [YKFPIVPadding unpadRSAData:data algorithm:algorithm error:&unpadError];
        if (unpadError) {
            completion(nil, unpadError);
            return;
        }
        completion(unpaddedData, nil);
    }];
}

- (void)usePrivateKeyInSlot:(YKFPIVSlot)slot type:(YKFPIVKeyType)type message:(NSData *)message exponentiation:(BOOL)exponentiation completion:(YKFPIVSessionDataCompletionBlock)completion {
    NSMutableData *recordsData = [NSMutableData data];
    [recordsData appendData:[[YKFTLVRecord alloc] initWithTag:YKFPIVTagAuthResponse value:[NSData data]].data];
    [recordsData appendData:[[YKFTLVRecord alloc] initWithTag:exponentiation ? YKFPIVTagExponentiation : YKFPIVTagChallenge value:message].data];
    NSData *data = [[YKFTLVRecord alloc] initWithTag:YKFPIVTagDynAuth value:recordsData].data;
    YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsAuthenticate p1:type p2:slot data:data type:YKFAPDUTypeExtended];
    [self.smartCardInterface executeCommand:apdu timeout:120.0  completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        NSError *tlvError = nil;
        NSData *recordData = [YKFTLVRecord valueFromData:data withTag:YKFPIVTagDynAuth error:&tlvError];
        if (tlvError) {
            completion(nil, tlvError);
            return;
        }
        NSData *result = [YKFTLVRecord valueFromData:recordData withTag:YKFPIVTagAuthResponse error:&tlvError];
        if (tlvError) {
            completion(nil, tlvError);
            return;
        }
        completion(result, error);
    }];
}

- (void)calculateSecretKeyInSlot:(YKFPIVSlot)slot peerPublicKey:(SecKeyRef)peerPublicKey completion:(nonnull YKFPIVSessionCalculateSecretCompletionBlock)completion {
    YKFPIVKeyType keyType = YKFPIVKeyTypeFromKey(peerPublicKey);
    if (keyType != YKFPIVKeyTypeECCP256 && keyType != YKFPIVKeyTypeECCP384) {
        completion(nil, [[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodeUnsupportedOperation userInfo:@{NSLocalizedDescriptionKey: @"Calculate secret only supported for EC keys."}]);
        return;
    }
    CFErrorRef cfError = nil;
    NSData *externalRepresentation = (__bridge NSData*)SecKeyCopyExternalRepresentation(peerPublicKey, &cfError);
    if (cfError) {
        NSError *error = (__bridge NSError *) cfError;
        completion(nil, error);
        return;
    }
    NSMutableData *data = [NSMutableData data];
    [data appendData:[externalRepresentation subdataWithRange:NSMakeRange(0, 1 + 2 * YKFPIVSizeFromKeyType(keyType))]];
    [self usePrivateKeyInSlot:slot type:keyType message:data exponentiation:true completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        completion(data, error);
    }];
}

- (void)attestKeyInSlot:(YKFPIVSlot)slot completion:(nonnull YKFPIVSessionAttestKeyCompletionBlock)completion {
    if (![self.features.attestation isSupportedBySession:self]) {
        completion(nil, [[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodeUnsupportedOperation userInfo:@{NSLocalizedDescriptionKey: @"Attestation not supported by this YubiKey."}]);
        return;
    }
    YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsAttest p1:slot p2:0 data:[NSData data] type:YKFAPDUTypeExtended];
    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        CFDataRef cfCertDataRef =  (__bridge CFDataRef)data;
        SecCertificateRef certificate = SecCertificateCreateWithData(nil, cfCertDataRef);
        if (certificate) {
            completion(certificate, nil);
        } else {
            completion(nil, [[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodeDataParseError userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse certificate."}]);        }
    }];
}

- (void)generateKeyInSlot:(YKFPIVSlot)slot type:(YKFPIVKeyType)type pinPolicy:(YKFPIVPinPolicy)pinPolicy touchPolicy:(YKFPIVTouchPolicy)touchPolicy completion:(nonnull YKFPIVSessionReadKeyCompletionBlock)completion {
    NSError *error = [self checkKeySupport:type pinPolicy:pinPolicy touchPolicy:touchPolicy generateKey:YES];
    if (error) {
        completion(nil, error);
    }
    NSMutableData *data = [NSMutableData dataWithBytes:&type length:1];
    YKFTLVRecord *tlv = [[YKFTLVRecord alloc] initWithTag:YKFPIVTagGenAlgorithm value:data];
    YKFTLVRecord *tlvsContainer = [[YKFTLVRecord alloc] initWithTag:0xac value:tlv.data];
    NSData *tlvsData = tlvsContainer.data;
    YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsGenerateAsymetric p1:0 p2:slot data:tlvsData type:YKFAPDUTypeExtended];
    [self.smartCardInterface executeCommand:apdu timeout:120.0 completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        NSArray<YKFTLVRecord*> *records = [YKFTLVRecord sequenceOfRecordsFromData:[[YKFTLVRecord sequenceOfRecordsFromData:data] ykfTLVRecordWithTag:(UInt64)0x7F49].value];
        SecKeyRef publicKey = nil;
        CFErrorRef cfError = nil;
        if (type == YKFPIVKeyTypeECCP256 || type == YKFPIVKeyTypeECCP384) {
            NSData *eccKeyData = [records ykfTLVRecordWithTag:(UInt64)0x86].value;
            CFDataRef cfDataRef = (__bridge CFDataRef)eccKeyData;
            NSDictionary *attributes = @{(id)kSecAttrKeyType: (id)kSecAttrKeyTypeEC,
                                         (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPublic};
            CFDictionaryRef attributesRef = (__bridge CFDictionaryRef)attributes;
            publicKey = SecKeyCreateWithData(cfDataRef, attributesRef, &cfError);
        } else if (type == YKFPIVKeyTypeRSA1024 || type == YKFPIVKeyTypeRSA2048) {
            NSMutableData *modulusData = [NSMutableData dataWithBytes:&(UInt8 *){0x00} length:1];
            [modulusData appendData:[records ykfTLVRecordWithTag:(UInt64)0x81].value];
            NSData *exponentData = [records ykfTLVRecordWithTag:(UInt64)0x82].value;
            NSMutableData *mutableData = [NSMutableData data];
            [mutableData appendData:[[YKFTLVRecord alloc] initWithTag:0x02 value:modulusData].data];
            [mutableData appendData:[[YKFTLVRecord alloc] initWithTag:0x02 value:exponentData].data];
            YKFTLVRecord *record = [[YKFTLVRecord alloc] initWithTag:0x30 value:mutableData];
            NSData *keyData = record.data;
            NSDictionary *attributes = @{(id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA,
                                         (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPublic};
            CFDictionaryRef attributesRef = (__bridge CFDictionaryRef)attributes;
            CFDataRef cfKeyDataRef = (__bridge CFDataRef)keyData;
            publicKey = SecKeyCreateWithData(cfKeyDataRef, attributesRef, &cfError);
        } else {
            [NSException raise:@"UnknownKeyType" format:@"Unknown key type."];

            completion(nil, [[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodeUnknownKeyType userInfo:@{NSLocalizedDescriptionKey: @"Unknown key type."}]);
        }
        NSError *bridgedError = (__bridge NSError *) cfError;
        completion(publicKey, bridgedError);
    }];
}

- (void)generateKeyInSlot:(YKFPIVSlot)slot type:(YKFPIVKeyType)type completion:(nonnull YKFPIVSessionReadKeyCompletionBlock)completion {
    [self generateKeyInSlot:slot type:type pinPolicy:YKFPIVPinPolicyDefault touchPolicy:YKFPIVTouchPolicyDefault completion:completion];
}

- (NSError * _Nullable)checkKeySupport:(YKFPIVKeyType)keyType pinPolicy:(YKFPIVPinPolicy)pinPolicy touchPolicy:(YKFPIVTouchPolicy)touchPolicy generateKey:(bool)generateKey {
    
    NSString *errorMessage = nil;
    if (keyType == YKFPIVKeyTypeECCP384) {
        if (![self.features.p384 isSupportedBySession:self]) {
            errorMessage = self.features.p384.name;
        }
    }
    if (pinPolicy != YKFPIVPinPolicyDefault || touchPolicy != YKFPIVTouchPolicyDefault) {
        if (![self.features.usagePolicy isSupportedBySession:self]) {
            errorMessage = self.features.usagePolicy.name;
        }
    }
    if (generateKey && (keyType == YKFPIVKeyTypeRSA1024 || keyType == YKFPIVKeyTypeRSA2048)) {
        YKFVersion *upUntil = [[YKFVersion alloc] initWithString:@"4.2.6"];
        YKFVersion *from = [[YKFVersion alloc] initWithString:@"4.3.5"];
        NSComparisonResult upUntilComparision = [upUntil compare:self.version];
        NSComparisonResult fromComparision = [from compare:self.version];
        
        if (!(upUntilComparision == NSOrderedSame || upUntilComparision == NSOrderedAscending ||
            fromComparision == NSOrderedSame || fromComparision == NSOrderedDescending)) {
            errorMessage = @"RSA key generation";
        }
    }
    
    if (errorMessage) {
        return [[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodeUnsupportedOperation userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@ not supported by this YubiKey.", errorMessage]}];
    }
    
    return nil;
}

- (void)putKey:(SecKeyRef)key inSlot:(YKFPIVSlot)slot pinPolicy:(YKFPIVPinPolicy)pinPolicy touchPolicy:(YKFPIVTouchPolicy)touchPolicy completion:(nonnull YKFPIVSessionPutKeyCompletionBlock)completion {
    YKFPIVKeyType keyType = YKFPIVKeyTypeFromKey(key);
    NSError *error = [self checkKeySupport:keyType pinPolicy:pinPolicy touchPolicy:touchPolicy generateKey:NO];
    if (error) {
        completion(keyType, error);
    }

    CFErrorRef cfError = nil;
    NSData *data = (__bridge NSData*)SecKeyCopyExternalRepresentation(key, &cfError);
    if (cfError) {
        NSError *error = (__bridge NSError *) cfError;
        completion(YKFPIVKeyTypeUnknown, error);
        return;
    }
    NSMutableData *mutableData = [NSMutableData data];
    switch (keyType) {
        case YKFPIVKeyTypeRSA1024:
        case YKFPIVKeyTypeRSA2048:
        {
            NSArray<YKFTLVRecord*> *records = [YKFTLVRecord sequenceOfRecordsFromData:[YKFTLVRecord recordFromData:data].value];
            NSData *primeOne = records[4].value;
            NSData *primeTwo = records[5].value;
            NSData *exponentOne = records[6].value;
            NSData *exponentTwo = records[7].value;
            NSData *coefficient = records[8].value;
            
            int length = YKFPIVSizeFromKeyType(keyType) / 2;
            [mutableData appendData:[[YKFTLVRecord alloc] initWithTag:0x01 value:[primeOne ykf_toLength:length]].data];
            [mutableData appendData:[[YKFTLVRecord alloc] initWithTag:0x02 value:[primeTwo ykf_toLength:length]].data];
            [mutableData appendData:[[YKFTLVRecord alloc] initWithTag:0x03 value:[exponentOne ykf_toLength:length]].data];
            [mutableData appendData:[[YKFTLVRecord alloc] initWithTag:0x04 value:[exponentTwo ykf_toLength:length]].data];
            [mutableData appendData:[[YKFTLVRecord alloc] initWithTag:0x05 value:[coefficient ykf_toLength:length]].data];
            break;
        }
        case YKFPIVKeyTypeECCP256:
        case YKFPIVKeyTypeECCP384:
        {
            int keyLength = YKFPIVSizeFromKeyType(keyType);
            NSData *privateKey = [data subdataWithRange:NSMakeRange(1 + 2 * keyLength, keyLength)];
            YKFTLVRecord *record = [[YKFTLVRecord alloc] initWithTag:0x06 value:privateKey];
            [mutableData appendData:record.data];
            break;
        }
        default:
            completion(YKFPIVKeyTypeUnknown, [[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodeUnknownKeyType userInfo:@{NSLocalizedDescriptionKey: @"Unknown key type."}]);
            return;
    }
    
    if (pinPolicy != YKFPIVPinPolicyDefault) {
        [mutableData appendData:[[YKFTLVRecord alloc] initWithTag:YKFPIVTagPinPolicy value:[NSData dataWithBytes:&pinPolicy length:1]].value];
    }
    if (touchPolicy != YKFPIVTouchPolicyDefault) {
        [mutableData appendData:[[YKFTLVRecord alloc] initWithTag:YKFPIVTagTouchPolicy value:[NSData dataWithBytes:&touchPolicy length:1]].value];
    }
    
    YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsImportKey p1:keyType p2:slot data:mutableData type:YKFAPDUTypeExtended];
    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        completion(keyType, error);
    }];
}

- (void)putKey:(SecKeyRef)key inSlot:(YKFPIVSlot)slot completion:(nonnull YKFPIVSessionPutKeyCompletionBlock)completion {
    [self putKey:key inSlot:slot pinPolicy:YKFPIVPinPolicyDefault touchPolicy:YKFPIVTouchPolicyDefault completion:completion];
}

- (void)putCertificate:(SecCertificateRef)certificate inSlot:(YKFPIVSlot)slot completion:(YKFPIVSessionGenericCompletionBlock)completion {
    NSMutableData *mutableData = [NSMutableData data];
    NSData *certData = (__bridge NSData *)SecCertificateCopyData(certificate);
    [mutableData appendData:[[YKFTLVRecord alloc] initWithTag:YKFPIVTagCertificate value:certData].data];
    [mutableData appendData:[[YKFTLVRecord alloc] initWithTag:YKFPIVTagCertificateInfo value:certData].data];
    [mutableData appendData:[[YKFTLVRecord alloc] initWithTag:YKFPIVTagLRC value:[NSData data]].data];
    [self putObject:mutableData objectId:[self objectIdForSlot:slot] completion:^(NSError * _Nullable error) {
        completion(error);
    }];
}

- (void)putObject:(NSData *)object objectId:(NSData *)objectId completion:(YKFPIVSessionGenericCompletionBlock)completion  {
    NSMutableData *mutableData = [NSMutableData data];
    [mutableData appendData:[[YKFTLVRecord alloc] initWithTag:YKFPIVTagObjectId value:objectId].data];
    [mutableData appendData:[[YKFTLVRecord alloc] initWithTag:YKFPIVTagObjectData value:object].data];
    YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsPutData p1:0x3f p2:0xff data:mutableData type:YKFAPDUTypeExtended];
    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        completion(error);
    }];
}

- (void)getCertificateInSlot:(YKFPIVSlot)slot completion:(nonnull YKFPIVSessionReadCertCompletionBlock)completion {
    NSData *data = [self objectIdForSlot:slot];
    YKFTLVRecord *tlv = [[YKFTLVRecord alloc] initWithTag:YKFPIVTagObjectId value:data];
    YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsGetData p1:0x3f p2:0xff data:tlv.data type:YKFAPDUTypeExtended];
    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error != nil) {
            completion(nil, error);
        } else {
            NSArray<YKFTLVRecord*> *records = [YKFTLVRecord sequenceOfRecordsFromData:data];
            NSData *objectData = [records ykfTLVRecordWithTag:YKFPIVTagObjectData].value;
            NSData *certificateData = [[YKFTLVRecord sequenceOfRecordsFromData:objectData] ykfTLVRecordWithTag:YKFPIVTagCertificate].value;
            CFDataRef cfCertDataRef =  (__bridge CFDataRef)certificateData;
            SecCertificateRef certificate = SecCertificateCreateWithData(nil, cfCertDataRef);
            completion(certificate, nil);
        }
    }];
}

- (void)deleteCertificateInSlot:(YKFPIVSlot)slot completion:(nonnull YKFPIVSessionGenericCompletionBlock)completion {
    [self putObject:[NSData data] objectId:[self objectIdForSlot:slot] completion:^(NSError * _Nullable error) {
        completion(error);
    }];
}

- (void)setManagementKey:(nonnull NSData *)managementKey type:(nonnull YKFPIVManagementKeyType *)type requiresTouch:(BOOL)requiresTouch completion:(nonnull YKFPIVSessionGenericCompletionBlock)completion {
    if (requiresTouch && ![self.features.usagePolicy isSupportedBySession:self]) {
        completion([[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodeUnsupportedOperation userInfo:@{NSLocalizedDescriptionKey: @"PIN/Touch policy not supported by this YubiKey."}]);
        return;
    }
    if (type.name != YKFPIVManagementKeyTypeTripleDES && ![self.features.aesKey isSupportedBySession:self]) {
        completion([[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodeUnsupportedOperation userInfo:@{NSLocalizedDescriptionKey: @"AES management key not supported by this YubiKey."}]);
        return;
    }
    YKFTLVRecord *tlv = [[YKFTLVRecord alloc] initWithTag:YKFPIVSlotCardManagement value:managementKey];
    
    UInt8 typeValue = type.value;
    NSMutableData *data = [NSMutableData dataWithBytes:&typeValue length:1];
    [data appendData:tlv.data];
    YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsSetManagementKey p1:0xff p2:requiresTouch ? 0xfe : 0xff data:data type:YKFAPDUTypeShort];

    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        completion(error);
    }];
}

- (void)authenticateWithManagementKey:(nonnull NSData *)managementKey type:(nonnull YKFPIVManagementKeyType *)keyType completion:(nonnull YKFPIVSessionGenericCompletionBlock)completion {
    if (keyType.keyLenght != managementKey.length) {
        YKFPIVError *error = [[YKFPIVError alloc] initWithCode:YKFPIVErrorCodeBadKeyLength message:[NSString stringWithFormat: @"Magagement key must be %i bytes in length. Used key is %lu long.", keyType.keyLenght, (unsigned long)managementKey.length]];
        completion(error);
        return;
    }
    
    YKFTLVRecord *witness = [[YKFTLVRecord alloc] initWithTag:YKFPIVTagAuthWitness value:[NSData data]];
    NSData *requestData = [[YKFTLVRecord alloc] initWithTag:YKFPIVTagDynAuth value:witness.data].data;
    YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsAuthenticate p1:keyType.value p2:YKFPIVSlotCardManagement data:requestData type:YKFAPDUTypeExtended];

    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error != nil) {
            completion(error);
            return;
        }
        YKFTLVRecord *dynAuthRecord = [YKFTLVRecord recordFromData:data];
        if (dynAuthRecord.tag != YKFPIVTagDynAuth) {
            completion([YKFPIVError errorUnpackingTLVExpected:YKFPIVTagDynAuth got:dynAuthRecord.tag]);
            return;
        }
        YKFTLVRecord *witnessRecord = [YKFTLVRecord recordFromData:dynAuthRecord.value];
        if (witnessRecord.tag != YKFPIVTagAuthWitness) {
            completion([YKFPIVError errorUnpackingTLVExpected:YKFPIVTagAuthWitness got:witnessRecord.tag]);
            return;
        }
        
        NSData *decryptedWitness = [witnessRecord.value ykf_decryptedDataWithAlgorithm:[keyType.name ykfCCAlgorithm] key:managementKey];
        YKFTLVRecord *decryptedWitnessRecord = [[YKFTLVRecord alloc] initWithTag:YKFPIVTagAuthWitness value:decryptedWitness];

        NSData *challenge = [NSData ykf_randomDataOfSize:keyType.challengeLength];
        YKFTLVRecord *challengeRecord = [[YKFTLVRecord alloc] initWithTag:YKFPIVTagChallenge value:challenge];

        NSMutableData *mutableData = [decryptedWitnessRecord.data mutableCopy];
        [mutableData appendData:challengeRecord.data];
        YKFTLVRecord *authTLVS = [[YKFTLVRecord alloc] initWithTag:YKFPIVTagDynAuth value:mutableData];

        YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsAuthenticate p1:keyType.value p2:YKFPIVSlotCardManagement data:authTLVS.data type:YKFAPDUTypeExtended];

        [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
            if (error != nil) {
                completion(error);
                return;
            }
            YKFTLVRecord *dynAuthRecord = [YKFTLVRecord recordFromData:data];
            if (dynAuthRecord.tag != YKFPIVTagDynAuth) {
                completion([YKFPIVError errorUnpackingTLVExpected:YKFPIVTagDynAuth got:dynAuthRecord.tag]);
                return;
            }
            YKFTLVRecord *encryptedRecord = [YKFTLVRecord recordFromData:dynAuthRecord.value];
            if (encryptedRecord.tag != YKFPIVTagAuthResponse) {
                completion([YKFPIVError errorUnpackingTLVExpected:YKFPIVTagAuthResponse got:encryptedRecord.tag]);
                return;
            }
            NSData *encryptedData = encryptedRecord.value;
            NSData *expectedData = [challenge ykf_encryptDataWithAlgorithm:[keyType.name ykfCCAlgorithm] key:managementKey];
            if (![encryptedData isEqual:expectedData]) {
                completion([[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodeAuthenticationFailed userInfo:@{NSLocalizedDescriptionKey: @"Authentication failed."}]);
                return;
            }
            completion(nil);
        }];
    }];
}

- (void)resetWithCompletion:(YKFPIVSessionGenericCompletionBlock)completion {
    [self blockPin:0 completion:^(NSError * _Nullable error) {
        if (error != nil) {
            completion(error);
            return;
        }
        [self blockPuk:0 completion:^(NSError * _Nullable error) {
            if (error != nil) {
                completion(error);
                return;
            }
            YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsReset p1:0 p2:0 data:[NSData data] type:YKFAPDUTypeShort];
            [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
                completion(error);
            }];
        }];
    }];
}

- (void)getSerialNumberWithCompletion:(YKFPIVSessionSerialNumberCompletionBlock)completion {
    if (![self.features.serial isSupportedBySession:self]) {
        completion(-1, [[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodeUnsupportedOperation userInfo:@{NSLocalizedDescriptionKey: @"Read serial number not supported by this YubiKey."}]);
        return;
    }
    
    YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsGetSerial p1:0 p2:0 data:[NSData data] type:YKFAPDUTypeShort];
    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (data != nil) {
            if ([data length] != 4) {
                completion(-1, [[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodeInvalidResponse userInfo:@{NSLocalizedDescriptionKey: @"Invalid response when reading serial number."}]);
                return;
            }
            UInt32 serialNumber = CFSwapInt32BigToHost(*(UInt32*)([data bytes]));
            completion(serialNumber, nil);
        } else {
            completion(-1, error);
        }
    }];
}

- (void)verifyPin:(nonnull NSString *)pin completion:(nonnull YKFPIVSessionVerifyPinCompletionBlock)completion {
    NSData *data = [self paddedDataWithPin:pin];
    YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsVerify p1:0 p2:0x80 data:data type:YKFAPDUTypeShort];
    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error == nil) {
            currentPinAttempts = maxPinAttempts;
            completion(currentPinAttempts, nil);
            return;
        } else {
            YKFSessionError *sessionError = (YKFSessionError *)error;
            if ([sessionError isKindOfClass:[YKFSessionError class]]) {
                int retries = [self getRetriesFromStatusCode:(int)sessionError.code];
                if (retries > 0) {
                    currentPinAttempts = retries;
                    completion(currentPinAttempts, [[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodeInvalidPin userInfo:@{NSLocalizedDescriptionKey: @"Invalid PIN code."}]);
                    return;
                    
                } else if (retries == 0) {
                    completion(retries, [[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodePinLocked userInfo:@{NSLocalizedDescriptionKey: @"PIN code entry locked."}]);
                    return;
                }
            }
            // Not wrong pin nor locked pin entry, pass on original error
            completion(-1, error);
        }
    }];
}

- (void)setPin:(nonnull NSString *)pin oldPin:(nonnull NSString *)oldPin completion:(nonnull YKFPIVSessionGenericCompletionBlock)completion {
    [self changeReference:YKFPIVInsChangeReference p2:YKFPIVP2Pin valueOne:oldPin valueTwo:pin completion:^(int retries, NSError * _Nullable error) {
        completion(error);
    }];
}

- (void)setPuk:(nonnull NSString *)puk oldPuk:(nonnull NSString *)oldPuk completion:(nonnull YKFPIVSessionGenericCompletionBlock)completion {
    [self changeReference:YKFPIVInsChangeReference p2:YKFPIVP2Puk valueOne:oldPuk valueTwo:puk completion:^(int retries, NSError * _Nullable error) {
        completion(error);
    }];
}

- (void)unblockPinWithPuk:(nonnull NSString *)puk newPin:(nonnull NSString *)newPin completion:(nonnull YKFPIVSessionGenericCompletionBlock)completion {
    [self changeReference:YKFPIVInsResetRetry p2:YKFPIVP2Pin valueOne:puk valueTwo:newPin completion:^(int retries, NSError * _Nullable error) {
        completion(error);
    }];
}

- (void)getPinPukMetadata:(UInt8)p2 completion:(nonnull YKFPIVSessionPinPukMetadataCompletionBlock)completion {
        YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsGetMetadata p1:0 p2:p2 data:[NSData data] type:YKFAPDUTypeShort];
    if (![self.features.metadata isSupportedBySession:self]) {
        completion(0, 0, 0, [[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodeUnsupportedOperation userInfo:@{NSLocalizedDescriptionKey: @"Read metadata not supported by this YubiKey."}]);
        return;
    }
    
    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error != nil) {
            completion(0, 0, 0, error);
            return;
        }
        NSArray<YKFTLVRecord*> *records = [YKFTLVRecord sequenceOfRecordsFromData:data];
        UInt8 isDefault = ((UInt8 *)[records ykfTLVRecordWithTag:YKFPIVTagMetadataIsDefault].value.bytes)[0];
        UInt8 retriesTotal = ((UInt8 *)[records ykfTLVRecordWithTag:YKFPIVTagMetadataRetries].value.bytes)[0];
        UInt8 retriesRemaining = ((UInt8 *)[records ykfTLVRecordWithTag:YKFPIVTagMetadataRetries].value.bytes)[1];
        completion(isDefault, retriesTotal, retriesRemaining, nil);
    }];
}

- (void)getManagementKeyMetadataWithCompletion:(nonnull YKFPIVSessionManagementKeyMetadataCompletionBlock)completion {
    if (![self.features.metadata isSupportedBySession:self]) {
        completion(nil, [[NSError alloc] initWithDomain:YKFPIVErrorDomain code:YKFPIVFErrorCodeUnsupportedOperation userInfo:@{NSLocalizedDescriptionKey: @"Read metadata not supported by this YubiKey."}]);
        return;
    }
    YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsGetMetadata p1:0 p2:YKFPIVSlotCardManagement data:[NSData data] type:YKFAPDUTypeShort];
    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error != nil) {
            completion(nil, error);
            return;
        }
        NSArray<YKFTLVRecord*> *records = [YKFTLVRecord sequenceOfRecordsFromData:data];
        YKFTLVRecord *algorithmRecord = [records ykfTLVRecordWithTag:YKFPIVTagMetadataAlgorithm];
        YKFPIVManagementKeyType *keyType;
        if (algorithmRecord) {
            keyType = [YKFPIVManagementKeyType fromValue:((UInt8 *)algorithmRecord.value.bytes)[0]];
        } else {
            keyType = [YKFPIVManagementKeyType TripleDES];
        }
        bool isDefault = ((UInt8 *)[records ykfTLVRecordWithTag:YKFPIVTagMetadataIsDefault].value.bytes)[0] != 0;
        YKFPIVTouchPolicy touchPolicy = ((UInt8 *)[records ykfTLVRecordWithTag:YKFPIVTagMetadataTouchPolicy].value.bytes)[1];
        
        YKFPIVManagementKeyMetadata *metaData = [[YKFPIVManagementKeyMetadata alloc] initWithKeyType:keyType touchPolicy:touchPolicy isDefault:isDefault];
        completion(metaData, nil);
    }];
}


- (void)getPinMetadataWithCompletion:(nonnull YKFPIVSessionPinPukMetadataCompletionBlock)completion {
    [self getPinPukMetadata:YKFPIVP2Pin completion:completion];
}


- (void)getPukMetadataWithCompletion:(nonnull YKFPIVSessionPinPukMetadataCompletionBlock)completion {
    [self getPinPukMetadata:YKFPIVP2Puk completion:completion];
}

- (void)getPinAttemptsWithCompletion:(nonnull YKFPIVSessionPinAttemptsCompletionBlock)completion {
    if ([self.features.metadata isSupportedBySession:self]) {
        [self getPinMetadataWithCompletion:^(bool isDefault, int retriesTotal, int retriesRemaining, NSError * _Nullable error) {
            completion(retriesRemaining, error);
        }];
    } else {
        YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsVerify p1:0 p2:YKFPIVP2Pin data:[NSData data] type:YKFAPDUTypeShort];
        [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
            if (error == nil) {
                // Already verified, no way to know true count
                completion(currentPinAttempts, nil);
                return;
            }
            int retries = [self getRetriesFromStatusCode:(int)error.code];
            completion(retries, retries < 0 ? error : nil);
        }];
    }
}

- (void)setPinAttempts:(int)pinAttempts pukAttempts:(int)pukAttempts completion:(nonnull YKFPIVSessionGenericCompletionBlock)completion {
    YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:YKFPIVInsSetPinPukAttempts p1:pinAttempts p2:pukAttempts data:[NSData data] type:YKFAPDUTypeShort];
    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error != nil) {
            completion(error);
            return;
        }
        maxPinAttempts = pinAttempts;
        currentPinAttempts = pinAttempts;
        completion(nil);
    }];
}

- (int)getRetriesFromStatusCode:(int)statusCode {
    if (statusCode == 0x6983) {
        return 0;
    }
    if ([self.version compare:[[YKFVersion alloc] initWithString:@"1.0.4"]] == NSOrderedAscending) {
        if (statusCode >= 0x6300 && statusCode <= 0x63ff) {
            return statusCode & 0xff;
        }
    } else {
        if (statusCode >= 0x63c0 && statusCode <= 0x63cf) {
            return statusCode & 0xf;
        }
    }
    return -1;
}

- (void)blockPin:(int)counter completion:(YKFPIVSessionGenericCompletionBlock)completion {
    [self verifyPin:@"" completion:^(int retries, NSError * _Nullable error) {
        if (retries == -1 && error != nil) {
            completion(error);
            return;
        }
        if (retries <= 0 || counter > 15) {
            completion(nil);
        } else {
            [self blockPin:(counter + 1) completion:completion];
        }
    }];
}

- (void)blockPuk:(int)counter completion:(YKFPIVSessionGenericCompletionBlock)completion {
    [self changeReference:YKFPIVInsResetRetry p2:YKFPIVP2Pin valueOne:@"" valueTwo:@"" completion:^(int retries, NSError * _Nullable error) {
        if (retries == -1 && error != nil) {
            completion(error);
            return;
        }
        if (retries <= 0 || counter > 15) {
            completion(nil);
        } else {
            [self blockPuk:(counter + 1) completion:completion];
        }
    }];
}

- (void)changeReference:(UInt8)ins p2:(UInt8)p2 valueOne:(NSString *)valueOne valueTwo:(NSString *)valueTwo completion:(nonnull YKFPIVSessionVerifyPinCompletionBlock)completion {
    NSMutableData *data = [self paddedDataWithPin:valueOne].mutableCopy;
    [data appendData:[self paddedDataWithPin:valueTwo]];
    YKFAPDU *apdu = [[YKFAPDU alloc] initWithCla:0 ins:ins p1:0 p2:p2 data:data type:YKFAPDUTypeShort];
    [self.smartCardInterface executeCommand:apdu completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error != nil) {
            int retries = [self getRetriesFromStatusCode:(int)error.code];
            if (retries >= 0) {
                if (p2 == 0x80) {
                    currentPinAttempts = retries;
                }
                completion(retries, error);
            }
        } else {
            completion(currentPinAttempts, nil);
        }
    }];
}

- (nonnull NSData *)paddedDataWithPin:(nonnull NSString *)pin {
    NSMutableData *mutableData = [[pin dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    UInt8 padding = 0xff;
    int paddingSize = 8 - (int)mutableData.length;
    for (int i = 0; i < paddingSize; i++) {
        [mutableData appendBytes:&padding length:1];
    }
    return mutableData;
}

@end
