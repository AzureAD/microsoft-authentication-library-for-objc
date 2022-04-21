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
#import "YKFPIVPadding+Private.h"
#import <CommonCrypto/CommonDigest.h>

@implementation YKFPIVPadding

+ (NSData *)padData:(NSData *)data keyType:(YKFPIVKeyType)keyType algorithm:(SecKeyAlgorithm)algorithm error:(NSError **)error {
    if (keyType == YKFPIVKeyTypeRSA2048 || keyType == YKFPIVKeyTypeRSA1024) {
        NSNumber *keySize = [NSNumber numberWithInt:YKFPIVSizeFromKeyType(keyType) * 8];
        CFDictionaryRef attributes = (__bridge CFDictionaryRef) (@{(id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA,
                                                                   (id)kSecAttrKeySizeInBits: keySize});
        
        SecKeyRef publicKey;
        SecKeyRef privateKey;
        SecKeyGeneratePair(attributes, &publicKey, &privateKey);
        CFErrorRef cfErrorRef = nil;
        CFDataRef cfDataRef = (__bridge CFDataRef)data;
        CFDataRef cfSignedDataRef = SecKeyCreateSignature(privateKey, algorithm, cfDataRef, &cfErrorRef);
        CFRelease(privateKey);
        if (cfErrorRef) {
            NSError *encryptError = (__bridge NSError *)cfErrorRef;
            *error = encryptError;
            return nil;
        }
        CFDataRef cfEncryptedDataRef = SecKeyCreateEncryptedData(publicKey, kSecKeyAlgorithmRSAEncryptionRaw, cfSignedDataRef, &cfErrorRef);
        CFRelease(publicKey);
        if (cfErrorRef) {
            NSError *encryptError = (__bridge NSError *)cfErrorRef;
            *error = encryptError;
            return nil;
        }
        NSData *encrypted = (__bridge NSData*)cfEncryptedDataRef;
        return encrypted;
    } else if (keyType == YKFPIVKeyTypeECCP256 || keyType == YKFPIVKeyTypeECCP384) {
        int keySize = YKFPIVSizeFromKeyType(keyType);
        NSMutableData *hash = nil;
        if ([(__bridge NSString *)algorithm isEqualToString:(__bridge NSString *)kSecKeyAlgorithmECDSASignatureMessageX962SHA224]) {
            hash = [NSMutableData dataWithLength:(NSUInteger)CC_SHA256_DIGEST_LENGTH];
            CC_SHA224(data.bytes, (CC_LONG)data.length, hash.mutableBytes);
        }
        if ([(__bridge NSString *)algorithm isEqualToString:(__bridge NSString *)kSecKeyAlgorithmECDSASignatureMessageX962SHA256]) {
            hash = [NSMutableData dataWithLength:(NSUInteger)CC_SHA256_DIGEST_LENGTH];
            CC_SHA256(data.bytes, (CC_LONG)data.length, hash.mutableBytes);
        }
        if ([(__bridge NSString *)algorithm isEqualToString:(__bridge NSString *)kSecKeyAlgorithmECDSASignatureMessageX962SHA384]) {
            hash = [NSMutableData dataWithLength:(NSUInteger)CC_SHA512_DIGEST_LENGTH];
            CC_SHA384(data.bytes, (CC_LONG)data.length, hash.mutableBytes);
        }

        if ([(__bridge NSString *)algorithm isEqualToString:(__bridge NSString *)kSecKeyAlgorithmECDSASignatureMessageX962SHA512]) {
            hash = [NSMutableData dataWithLength:(NSUInteger)CC_SHA512_DIGEST_LENGTH];
            CC_SHA512(data.bytes, (CC_LONG)data.length, hash.mutableBytes);
        }
        if ([(__bridge NSString *)algorithm isEqualToString:(__bridge NSString *)kSecKeyAlgorithmECDSASignatureMessageX962SHA1]) {
            hash = [NSMutableData dataWithLength:(NSUInteger)CC_SHA1_DIGEST_LENGTH];
            CC_SHA1(data.bytes, (CC_LONG)data.length, hash.mutableBytes);
        }
        if ([(__bridge NSString *)algorithm isEqualToString:(__bridge NSString *)kSecKeyAlgorithmECDSASignatureDigestX962SHA1] ||
            [(__bridge NSString *)algorithm isEqualToString:(__bridge NSString *)kSecKeyAlgorithmECDSASignatureDigestX962SHA224] ||
            [(__bridge NSString *)algorithm isEqualToString:(__bridge NSString *)kSecKeyAlgorithmECDSASignatureDigestX962SHA256] ||
            [(__bridge NSString *)algorithm isEqualToString:(__bridge NSString *)kSecKeyAlgorithmECDSASignatureDigestX962SHA384] ||
            [(__bridge NSString *)algorithm isEqualToString:(__bridge NSString *)kSecKeyAlgorithmECDSASignatureDigestX962SHA512]) {
            hash = [data mutableCopy];
        }
        if (hash.length == keySize) {
            return hash;
        }
        if (hash.length > keySize) {
            return [hash subdataWithRange:NSMakeRange(0, keySize)];
        }
        if (hash.length < keySize) {
            NSMutableData *paddedHash = [NSMutableData data];
            UInt8 padding = 0x00;
            int paddingSize = keySize - (int)hash.length;
            for (int i = 0; i < paddingSize; i++) {
                [paddedHash appendBytes:&padding length:1];
            }
            [paddedHash appendData:hash];
            return paddedHash;
        }
        *error = [[NSError alloc] initWithDomain:@"com.yubico.piv" code:1 userInfo:@{NSLocalizedDescriptionKey: @"EC padding algorithm not supported."}];
        return nil;
    } else {
        *error = [[NSError alloc] initWithDomain:@"com.yubico.piv" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Unknown key type."}];
        return nil;
    }
}

+ (NSData *)unpadRSAData:(NSData *)data algorithm:(SecKeyAlgorithm)algorithm error:(NSError **)error {
    NSNumber *size;
    switch (data.length) {
        case 1024 / 8:
            size = @1024;
            break;
        case 2048 / 8:
            size = @2048;
            break;
        default:
            *error = [[NSError alloc] initWithDomain:@"com.yubico.piv" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to unpad RSA data - input buffer bad size."}];
            return nil;
    }
    CFDictionaryRef attributes = (__bridge CFDictionaryRef) @{(id)kSecAttrKeyType: (id)kSecAttrKeyTypeRSA,
                                                              (id)kSecAttrKeySizeInBits: size};
    SecKeyRef publicKey;
    SecKeyRef privateKey;
    SecKeyGeneratePair(attributes, &publicKey, &privateKey);
    CFErrorRef cfErrorRef = nil;
    CFDataRef cfDataRef = (__bridge CFDataRef)data;
    CFDataRef cfEncryptedDataRef = SecKeyCreateEncryptedData(publicKey, kSecKeyAlgorithmRSAEncryptionRaw, cfDataRef, &cfErrorRef);
    CFRelease(publicKey);
    if (cfErrorRef) {
        NSError *encryptError = (__bridge NSError *)cfErrorRef;
        *error = encryptError;
        return nil;
    }
    CFDataRef cfDecryptedDataRef = SecKeyCreateDecryptedData(privateKey, algorithm, cfEncryptedDataRef, &cfErrorRef);
    CFRelease(privateKey);
    if (cfErrorRef) {
        NSError *decryptError = (__bridge NSError *)cfErrorRef;
        *error = decryptError;
        return nil;
    }
    NSData *decrypted = (__bridge NSData*)cfDecryptedDataRef;
    return decrypted;
}

@end
