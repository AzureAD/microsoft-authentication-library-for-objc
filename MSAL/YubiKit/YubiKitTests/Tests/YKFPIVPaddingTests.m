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

#import <XCTest/XCTest.h>
#import "YKFTestCase.h"
#import "YKFPIVPadding+Private.h"
#import "YKFPIVKeyType.h"
#import "YKFNSDataAdditions.h"

@interface YKFPIVPaddingTests : XCTestCase

@end

@implementation YKFPIVPaddingTests

- (void)testPadSHA256ECCP256Data {
    NSData *data = [@"Hello world!" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSData *result = [YKFPIVPadding padData:data keyType:YKFPIVKeyTypeECCP256 algorithm:kSecKeyAlgorithmECDSASignatureMessageX962SHA256 error:&error];
    NSData *expected = [NSData dataFromHexString:@"c0535e4be2b79ffd93291305436bf889314e4a3faec05ecffcbb7df31ad9e51a"];
    XCTAssert([expected isEqualToData:result]);
}

- (void)testPadSHA256ECCP384Data {
    NSData *data = [@"Hello world!" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSData *result = [YKFPIVPadding padData:data keyType:YKFPIVKeyTypeECCP384 algorithm:kSecKeyAlgorithmECDSASignatureMessageX962SHA256 error:&error];
    NSData *expected = [NSData dataFromHexString:@"00000000000000000000000000000000c0535e4be2b79ffd93291305436bf889314e4a3faec05ecffcbb7df31ad9e51a"];
    XCTAssert([expected isEqualToData:result]);
}

- (void)testPadSHA1ECCP256Data {
    NSData *data = [@"Hello world!" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSData *result = [YKFPIVPadding padData:data keyType:YKFPIVKeyTypeECCP256 algorithm:kSecKeyAlgorithmECDSASignatureMessageX962SHA1 error:&error];
    NSData *expected = [NSData dataFromHexString:@"000000000000000000000000d3486ae9136e7856bc42212385ea797094475802"];
    XCTAssert([expected isEqualToData:result]);
}

- (void)testPadSHA512ECCP256Data {
    NSData *data = [@"Hello world!" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSData *result = [YKFPIVPadding padData:data keyType:YKFPIVKeyTypeECCP256 algorithm:kSecKeyAlgorithmECDSASignatureMessageX962SHA512 error:&error];
    NSData *expected = [NSData dataFromHexString:@"f6cde2a0f819314cdde55fc227d8d7dae3d28cc556222a0a8ad66d91ccad4aad"];
    XCTAssert([expected isEqualToData:result]);
}

- (void)testPadSHA512ECCP384Data {
    NSData *data = [@"Hello world!" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSData *result = [YKFPIVPadding padData:data keyType:YKFPIVKeyTypeECCP384 algorithm:kSecKeyAlgorithmECDSASignatureMessageX962SHA512 error:&error];
    NSData *expected = [NSData dataFromHexString:@"f6cde2a0f819314cdde55fc227d8d7dae3d28cc556222a0a8ad66d91ccad4aad6094f517a2182360c9aacf6a3dc32316"];
    XCTAssert([expected isEqualToData:result]);
}

- (void)testPreHashedECCP256Data {
    NSData *preHashed = [NSData dataFromHexString:@"c0535e4be2b79ffd93291305436bf889314e4a3faec05ecffcbb7df31ad9e51a"];
    NSError *error = nil;
    NSData *result = [YKFPIVPadding padData:preHashed keyType:YKFPIVKeyTypeECCP256 algorithm:kSecKeyAlgorithmECDSASignatureDigestX962SHA256 error:&error];
    NSData *expected = [NSData dataFromHexString:@"c0535e4be2b79ffd93291305436bf889314e4a3faec05ecffcbb7df31ad9e51a"];
    XCTAssert([expected isEqualToData:result]);
}

- (void)testPadRSAPKCS1Data {
    NSData *data = [@"Hello World!" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSData *padded = [YKFPIVPadding padData:data keyType:YKFPIVKeyTypeRSA1024 algorithm:kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA512 error:&error];
    NSData *expected = [NSData dataFromHexString:@"0001ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff003051300d060960864801650304020305000440861844d6704e8573fec34d967e20bcfef3d424cf48be04e6dc08f2bd58c729743371015ead891cc3cf1c9d34b49264b510751b1ff9e537937bc46b5d6ff4ecc8"];
    XCTAssert([padded isEqualToData:expected]);
}

- (void)testPadSHA256ECCP384DigestData {
    NSData *hash = [@"Hello world!" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSData *result = [YKFPIVPadding padData:hash keyType:YKFPIVKeyTypeECCP384 algorithm:kSecKeyAlgorithmECDSASignatureDigestX962SHA256 error:&error];
    NSData *expected = [NSData dataFromHexString:@"00000000000000000000000000000000000000000000000000000000000000000000000048656c6c6f20776f726c6421"];
    XCTAssert([expected isEqualToData:result]);
}

- (void)testUnpadRSAEncryptionPKCS1PaddedData {
    NSData *rsaEncryptionPKCS1PaddedData = [NSData dataFromHexString:@"00022b781255b78f9570844701748107f506effbea5f0822b41dded192938906cefe16eef190d4cf7f7b0866badf94ca0e4e08fda43e4619edec2703987a56a78aa4c2d36a8f89c43f1f9c0ab681e45a759744ef946d65d95e74536b28b83cdc1c62e36c014c8b4a50c178a54306ce7395240e0048656c6c6f20576f726c6421"];

    NSError *error = nil;
    NSData *unpadded = [YKFPIVPadding unpadRSAData:rsaEncryptionPKCS1PaddedData algorithm:kSecKeyAlgorithmRSAEncryptionPKCS1 error:&error];

    NSString *result = [[NSString alloc] initWithData:unpadded encoding:NSUTF8StringEncoding];
    XCTAssert([result isEqual:@"Hello World!"]);
}

- (void)testUnpadRSAEncryptionOAEPSHA224Data {
    NSData *rsaEncryptionOAEPSHA224Data = [NSData dataFromHexString:@"00bcbb35b6ef5c94a85fb3439a6dabda617a08963cf81023bac19c619b024cb71b8aee25cc30991279c908198ba623fba88547741dbf17a6f2a737ec95542b56b2b429bea8bd3145af7c8f144dcf804b89d3f9de21d6d6dc852fc91c666b8582bf348e1388ac2f54651ae6a1f5355c8d96daf96c922a9f1a499d890412d09454"];
    
    NSError *error = nil;
    NSData *unpadded = [YKFPIVPadding unpadRSAData:rsaEncryptionOAEPSHA224Data algorithm:kSecKeyAlgorithmRSAEncryptionOAEPSHA224 error:&error];
    
    NSString *result = [[NSString alloc] initWithData:unpadded encoding:NSUTF8StringEncoding];
    XCTAssert([result isEqual:@"Hello World!"]);
}

- (void)testUnpadWrongData {
    NSData *rsaEncryptionOAEPSHA224Data = [NSData dataFromHexString:@"00bcbb35b6ef5c94a85fb3439a6dabda617a08963cf81023bac19c619b024cb71b8aee25cc30991279c908198ba623fba88547741dbf17a6f2a737ec95542b56b2b429bea8bd3145af7c8f144dcf804b89d3f9de21d6d6dc852fc91c666b8582bf348e1388ac2f54651ae6a1f5355c8d96daf96c922a9f1a499d890412d09454"];
    
    NSError *error = nil;
    NSData *result = [YKFPIVPadding unpadRSAData:rsaEncryptionOAEPSHA224Data algorithm:kSecKeyAlgorithmRSAEncryptionPKCS1 error:&error];

    XCTAssertNil(result);
}

@end
