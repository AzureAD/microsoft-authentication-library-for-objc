//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSALExternalKeyPair.h"
#import "MSALError.h"

@interface MSALExternalKeyPairTests : XCTestCase

@end

@implementation MSALExternalKeyPairTests

- (void)testInitWithNilPrivateKey_ShouldReturnInvalidKeyHandle
{
    SecKeyRef privateKey = [self createPrivateKeyWithType:kSecAttrKeyTypeRSA size:@2048];
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    SecKeyRef nilPrivateKey = NULL;
    NSError *error = nil;

    MSALExternalKeyPair *keyPair = [[MSALExternalKeyPair alloc] initWithPrivateKey:nilPrivateKey
                                                                         publicKey:publicKey
                                                                             error:&error];

    XCTAssertNil(keyPair);
    XCTAssertEqual(error.code, MSALErrorInvalidExternalKeyPair);
    XCTAssertEqual([error.userInfo[MSALExternalKeyPairFailureReasonKey] integerValue], MSALExternalKeyPairFailureReasonInvalidKeyHandle);

    CFRelease(publicKey);
    CFRelease(privateKey);
}

- (void)testInitWithNilPublicKey_ShouldReturnInvalidKeyHandle
{
    SecKeyRef privateKey = [self createPrivateKeyWithType:kSecAttrKeyTypeRSA size:@2048];
    SecKeyRef nilPublicKey = NULL;
    NSError *error = nil;

    MSALExternalKeyPair *keyPair = [[MSALExternalKeyPair alloc] initWithPrivateKey:privateKey
                                                                         publicKey:nilPublicKey
                                                                             error:&error];

    XCTAssertNil(keyPair);
    XCTAssertEqual(error.code, MSALErrorInvalidExternalKeyPair);
    XCTAssertEqual([error.userInfo[MSALExternalKeyPairFailureReasonKey] integerValue], MSALExternalKeyPairFailureReasonInvalidKeyHandle);

    CFRelease(privateKey);
}

- (void)testInitWithValidRSAKeyPair_ShouldReturnKeyPair
{
    SecKeyRef privateKey = [self createPrivateKeyWithType:kSecAttrKeyTypeRSA size:@2048];
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    NSError *error = nil;
    MSALExternalKeyPair *keyPair = [[MSALExternalKeyPair alloc] initWithPrivateKey:privateKey
                                                                         publicKey:publicKey
                                                                             error:&error];

    XCTAssertNotNil(keyPair);
    XCTAssertNotNil(keyPair.keyId);
    XCTAssertNil(error);

    CFRelease(publicKey);
    CFRelease(privateKey);
    XCTAssertNotNil(keyPair.keyId);
}

- (void)testInitWithEccKeyPair_ShouldReturnUnsupportedKeyType
{
    SecKeyRef privateKey = [self createPrivateKeyWithType:kSecAttrKeyTypeECSECPrimeRandom size:@256];
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    NSError *error = nil;
    MSALExternalKeyPair *keyPair = [[MSALExternalKeyPair alloc] initWithPrivateKey:privateKey
                                                                         publicKey:publicKey
                                                                             error:&error];

    XCTAssertNil(keyPair);
    XCTAssertEqual(error.code, MSALErrorInvalidExternalKeyPair);
    XCTAssertEqual([error.userInfo[MSALExternalKeyPairFailureReasonKey] integerValue], MSALExternalKeyPairFailureReasonUnsupportedKeyType);

    CFRelease(publicKey);
    CFRelease(privateKey);
}

- (void)testInitWithSmallRSAKeyPair_ShouldReturnKeySizeTooSmall
{
    SecKeyRef privateKey = [self createPrivateKeyWithType:kSecAttrKeyTypeRSA size:@1024];
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    NSError *error = nil;
    MSALExternalKeyPair *keyPair = [[MSALExternalKeyPair alloc] initWithPrivateKey:privateKey
                                                                         publicKey:publicKey
                                                                             error:&error];

    XCTAssertNil(keyPair);
    XCTAssertEqual(error.code, MSALErrorInvalidExternalKeyPair);
    XCTAssertEqual([error.userInfo[MSALExternalKeyPairFailureReasonKey] integerValue], MSALExternalKeyPairFailureReasonKeySizeTooSmall);

    CFRelease(publicKey);
    CFRelease(privateKey);
}

- (void)testInitWithMismatchedRSAKeyPair_ShouldReturnKeyPairMismatch
{
    SecKeyRef privateKey = [self createPrivateKeyWithType:kSecAttrKeyTypeRSA size:@2048];
    SecKeyRef otherPrivateKey = [self createPrivateKeyWithType:kSecAttrKeyTypeRSA size:@2048];
    SecKeyRef otherPublicKey = SecKeyCopyPublicKey(otherPrivateKey);
    NSError *error = nil;
    MSALExternalKeyPair *keyPair = [[MSALExternalKeyPair alloc] initWithPrivateKey:privateKey
                                                                         publicKey:otherPublicKey
                                                                             error:&error];

    XCTAssertNil(keyPair);
    XCTAssertEqual(error.code, MSALErrorInvalidExternalKeyPair);
    XCTAssertEqual([error.userInfo[MSALExternalKeyPairFailureReasonKey] integerValue], MSALExternalKeyPairFailureReasonKeyPairMismatch);

    CFRelease(otherPublicKey);
    CFRelease(otherPrivateKey);
    CFRelease(privateKey);
}

- (void)testInitWithPublicKeys_ShouldReturnInvalidKeyClass
{
    SecKeyRef privateKey = [self createPrivateKeyWithType:kSecAttrKeyTypeRSA size:@2048];
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    NSError *error = nil;
    MSALExternalKeyPair *keyPair = [[MSALExternalKeyPair alloc] initWithPrivateKey:publicKey
                                                                         publicKey:publicKey
                                                                             error:&error];

    XCTAssertNil(keyPair);
    XCTAssertEqual(error.code, MSALErrorInvalidExternalKeyPair);
    XCTAssertEqual([error.userInfo[MSALExternalKeyPairFailureReasonKey] integerValue], MSALExternalKeyPairFailureReasonInvalidKeyClass);

    CFRelease(publicKey);
    CFRelease(privateKey);
}

- (SecKeyRef)createPrivateKeyWithType:(CFStringRef)keyType size:(NSNumber *)size
{
    NSDictionary *attributes = @{
        (id)kSecAttrKeyType : (__bridge id)keyType,
        (id)kSecAttrKeySizeInBits : size
    };
    CFErrorRef error = NULL;
    SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes, &error);
    XCTAssertNotEqual(privateKey, NULL);
    XCTAssertEqual(error, NULL);
    return privateKey;
}

@end
