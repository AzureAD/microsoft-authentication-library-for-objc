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

#import <Foundation/Foundation.h>
#import <Security/Security.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Reason an external Access Token Proof-of-Possession key pair was rejected.

 Read from `MSALExternalKeyPairFailureReasonKey` in the `userInfo` of an
 `MSALErrorInvalidExternalKeyPair` error.
 */
typedef NS_ENUM(NSInteger, MSALExternalKeyPairFailureReason)
{
    /** No reason was recorded, or the `userInfo` key was absent. */
    MSALExternalKeyPairFailureReasonUnknown = 0,

    /** A key handle was NULL, or its attributes could not be read. */
    MSALExternalKeyPairFailureReasonInvalidKeyHandle,

    /** A key was not RSA. Elliptic curve keys, including Secure Enclave keys, are not supported. */
    MSALExternalKeyPairFailureReasonUnsupportedKeyType,

    /** A key was smaller than the 2048-bit minimum. */
    MSALExternalKeyPairFailureReasonKeySizeTooSmall,

    /** The supplied keys were not one private key and one public key. */
    MSALExternalKeyPairFailureReasonInvalidKeyClass,

    /** The private key cannot sign, or the public key cannot verify, using RS256. */
    MSALExternalKeyPairFailureReasonNotSigningCapable,

    /** The public key does not correspond to the private key, or their sizes differ. */
    MSALExternalKeyPairFailureReasonKeyPairMismatch,

    /** The public key could not be exported, so no thumbprint could be computed. */
    MSALExternalKeyPairFailureReasonPublicKeySerializationFailed,

    /** The public key could not be derived from the private key. */
    MSALExternalKeyPairFailureReasonPublicKeyDerivationFailed
};

/**
 A caller-owned RSA key pair supplied to MSAL for Access Token Proof-of-Possession.

 MSAL retains the key handles for the lifetime of this object. The caller remains
 responsible for creating, storing, rotating, and deleting the underlying keys.
 MSAL never exports or persists the private key material.
 */
@interface MSALExternalKeyPair : NSObject

/**
 Validates a caller-owned RSA key pair and, on success, retains both key handles.

 The key pair must satisfy all of the following, otherwise initialization fails:

 - Both handles are non-NULL and their attributes are readable.
 - Both keys are RSA. Elliptic curve keys, including Secure Enclave keys, are rejected.
 - One key is a private key and the other is a public key.
 - Both keys are at least 2048 bits and are of equal size.
 - The private key supports RS256 signing and the public key supports RS256 verification.
 - The public key can be exported, so that its RFC 7638 thumbprint can be computed.
 - The public key derived from the private key matches the supplied public key.

 Validation is non-interactive: it never signs a challenge, so it does not trigger a
 biometric or user-presence prompt. It fails closed. If the public key cannot be derived
 from the private key, the pair is rejected rather than accepted on weaker evidence.

 @param privateKey Caller-owned RSA private key. Retained for the lifetime of the returned object.
 @param publicKey Caller-owned RSA public key matching `privateKey`. Retained for the lifetime of the returned object.
 @param error On failure, an `NSError` in `MSALErrorDomain` with code `MSALErrorInvalidExternalKeyPair`.
        Its `userInfo` contains `MSALExternalKeyPairFailureReasonKey`, holding a boxed
        `MSALExternalKeyPairFailureReason`, and, when validation produced one, the originating
        error under `NSUnderlyingErrorKey`.

 @return An initialized object, or `nil` if the key pair failed validation.
 */
- (nullable instancetype)initWithPrivateKey:(SecKeyRef _Nullable)privateKey
                                  publicKey:(SecKeyRef _Nullable)publicKey
                                      error:(NSError * _Nullable __autoreleasing * _Nullable)error NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 RFC 7638 thumbprint of the public key used for the access token confirmation claim.
 */
@property (nonatomic, readonly) NSString *keyId;

@end

NS_ASSUME_NONNULL_END
