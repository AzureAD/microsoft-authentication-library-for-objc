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

typedef NS_ENUM(NSInteger, MSALExternalKeyPairFailureReason)
{
    MSALExternalKeyPairFailureReasonUnknown = 0,
    MSALExternalKeyPairFailureReasonInvalidKeyHandle,
    MSALExternalKeyPairFailureReasonUnsupportedKeyType,
    MSALExternalKeyPairFailureReasonKeySizeTooSmall,
    MSALExternalKeyPairFailureReasonInvalidKeyClass,
    MSALExternalKeyPairFailureReasonNotSigningCapable,
    MSALExternalKeyPairFailureReasonKeyPairMismatch,
    MSALExternalKeyPairFailureReasonPublicKeySerializationFailed,
    MSALExternalKeyPairFailureReasonPublicKeyDerivationFailed
};

/**
 A caller-owned RSA key pair supplied to MSAL for Access Token Proof-of-Possession.

 MSAL retains the key handles for the lifetime of this object. The caller remains
 responsible for creating, storing, rotating, and deleting the underlying keys.
 MSAL never exports or persists the private key material.
 */
@interface MSALExternalKeyPair : NSObject

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
