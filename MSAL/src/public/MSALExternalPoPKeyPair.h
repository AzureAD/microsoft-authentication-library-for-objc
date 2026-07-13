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
 Wraps caller supplied key material used to bind Proof-of-Possession (PoP) tokens.

 By default MSAL generates and manages a device bound key pair for PoP token binding. Provide
 an instance of this class to `MSALAuthenticationSchemePop` when the application wants to bind
 the PoP token to a key pair it owns and manages (for example, a key stored in the Secure Enclave
 or provisioned by a hardware backed keystore) instead of the default MSAL generated key.

 The receiver retains the supplied `SecKeyRef`s for its lifetime. The keys must be RSA keys whose
 public key can be exported via `SecKeyCopyExternalRepresentation`.
 */
@interface MSALExternalPoPKeyPair : NSObject

/**
 The private key used to sign the PoP token.
 */
@property (nonatomic, readonly) SecKeyRef privateKeyRef;

/**
 The public key advertised to the token endpoint as the request confirmation (req_cnf).
 */
@property (nonatomic, readonly) SecKeyRef publicKeyRef;

/**
 Initializes the key pair with caller supplied private and public keys.

 @param privateKey  The private key used to sign PoP tokens. Must not be NULL.
 @param publicKey   The public key advertised to the token endpoint. Must not be NULL.

 @return An initialized key pair, or nil if either key is NULL.
 */
- (nullable instancetype)initWithPrivateKey:(SecKeyRef)privateKey
                                  publicKey:(SecKeyRef)publicKey NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
