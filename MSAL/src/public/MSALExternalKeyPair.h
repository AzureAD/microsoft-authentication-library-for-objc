//------------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
//------------------------------------------------------------------------------

#import <Foundation/Foundation.h>
#import <Security/Security.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MSALExternalKeyPairFailureReason)
{
    MSALExternalKeyPairFailureReasonInvalidKeyHandle = 1,
    MSALExternalKeyPairFailureReasonUnsupportedKeyType,
    MSALExternalKeyPairFailureReasonKeySizeTooSmall,
    MSALExternalKeyPairFailureReasonInvalidKeyClass,
    MSALExternalKeyPairFailureReasonNotSigningCapable,
    MSALExternalKeyPairFailureReasonKeyPairMismatch,
    MSALExternalKeyPairFailureReasonPublicKeySerializationFailed
};

extern NSString *const MSALExternalKeyPairFailureReasonKey;

/**
 A caller-owned RSA key pair supplied to MSAL for Access Token Proof-of-Possession.

 MSAL retains the key handles for the lifetime of this object. The caller remains
 responsible for creating, storing, rotating, and deleting the underlying keys.
 MSAL never exports or persists the private key material.
 */
@interface MSALExternalKeyPair : NSObject

- (nullable instancetype)initWithPrivateKey:(SecKeyRef)privateKey
                                  publicKey:(SecKeyRef)publicKey
                                      error:(NSError * _Nullable __autoreleasing * _Nullable)error NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 RFC 7638 thumbprint of the public key used for the access token confirmation claim.
 */
@property (nonatomic, readonly) NSString *keyId;

@end

NS_ASSUME_NONNULL_END
