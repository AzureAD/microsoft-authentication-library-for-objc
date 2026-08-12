//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSALExternalKeyPair.h"
#import "MSALExternalKeyPair+Internal.h"
#import "MSALError.h"
#import "MSIDDevicePopManager.h"
#import "MSIDAssymetricKeyPair.h"
#import "NSData+MSIDExtensions.h"

@interface MSALExternalKeyPairTests : XCTestCase

@end

@implementation MSALExternalKeyPairTests

- (void)setUp
{
    [super setUp];
    self.continueAfterFailure = NO;
}

- (void)testInitWithNilPrivateKey_ShouldReturnInvalidKeyHandle
{
    SecKeyRef privateKey = [self createPrivateKeyWithType:kSecAttrKeyTypeRSA size:@2048];
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    NSError *error = nil;

    MSALExternalKeyPair *keyPair = [[MSALExternalKeyPair alloc] initWithPrivateKey:NULL
                                                                         publicKey:publicKey
                                                                             error:&error];

    XCTAssertNil(keyPair);
    XCTAssertEqual(error.code, MSALErrorInvalidExternalKeyPair);
    XCTAssertEqual([error.userInfo[MSALExternalKeyPairFailureReasonKey] integerValue], MSALExternalKeyPairFailureReasonInvalidKeyHandle);
    XCTAssertNotNil(error.userInfo[NSUnderlyingErrorKey]);

    CFRelease(publicKey);
    CFRelease(privateKey);
}

- (void)testInitWithNilPublicKey_ShouldReturnInvalidKeyHandle
{
    SecKeyRef privateKey = [self createPrivateKeyWithType:kSecAttrKeyTypeRSA size:@2048];
    NSError *error = nil;

    MSALExternalKeyPair *keyPair = [[MSALExternalKeyPair alloc] initWithPrivateKey:privateKey
                                                                         publicKey:NULL
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

    MSIDDevicePopManager *manager = [[MSIDDevicePopManager alloc] initWithExternalKeyPair:keyPair.msidKeyPair];
    NSString *signedToken = [manager createSignedAccessToken:@"access-token"
                                                  httpMethod:@"POST"
                                                  requestUrl:@"https://contoso.com/path"
                                                       nonce:@"nonce"
                                                       error:&error];
    XCTAssertNotNil(signedToken);
    XCTAssertNil(error);

    NSArray<NSString *> *segments = [signedToken componentsSeparatedByString:@"."];
    XCTAssertEqual(segments.count, 3);
    NSData *signedData = [[NSString stringWithFormat:@"%@.%@", segments[0], segments[1]] dataUsingEncoding:NSUTF8StringEncoding];
    NSData *signature = [NSData msidDataFromBase64UrlEncodedString:segments[2]];
    CFErrorRef verificationError = NULL;
    BOOL signatureValid = SecKeyVerifySignature(keyPair.msidKeyPair.publicKeyRef,
                                                kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256,
                                                (__bridge CFDataRef)signedData,
                                                (__bridge CFDataRef)signature,
                                                &verificationError);
    XCTAssertTrue(signatureValid);
    XCTAssertEqual(verificationError, NULL);
    if (verificationError)
    {
        CFRelease(verificationError);
    }
}

- (void)testFailureReason_whenMissing_shouldReturnUnknown
{
    NSError *error = [NSError errorWithDomain:MSALErrorDomain
                                         code:MSALErrorInvalidExternalKeyPair
                                     userInfo:nil];

    XCTAssertEqual([error.userInfo[MSALExternalKeyPairFailureReasonKey] integerValue], MSALExternalKeyPairFailureReasonUnknown);
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
    if (error)
    {
        CFRelease(error);
    }

    return privateKey;
}

@end
