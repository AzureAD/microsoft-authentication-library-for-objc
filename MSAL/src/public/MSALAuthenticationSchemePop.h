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

#import "MSALAuthenticationSchemeProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@class MSALExternalPoPKeyPair;

@interface MSALAuthenticationSchemePop : NSObject<MSALAuthenticationSchemeProtocol>

@property (nonatomic, readonly) MSALAuthScheme scheme;

/**
 Caller supplied key material used to bind the PoP token. When nil, MSAL uses its default
 device bound, keychain backed key pair.
 */
@property (nonatomic, readonly, nullable) MSALExternalPoPKeyPair *externalKeyPair;

- (instancetype)initWithHttpMethod:(MSALHttpMethod)httpMethod
                        requestUrl:(NSURL *)requestUrl
                             nonce:(nullable NSString *)nonce
              additionalParameters:(nullable NSDictionary *)additionalParameters;

/**
 Initializes a PoP authentication scheme that binds the token to caller supplied key material.

 @param httpMethod           The HTTP method of the request the PoP token will be used with.
 @param requestUrl           The URL of the request the PoP token will be used with.
 @param nonce                An optional server provided nonce. When nil, MSAL generates one.
 @param additionalParameters Additional parameters to include in the scheme.
 @param externalKeyPair      Caller owned key material used to bind the PoP token. When nil,
                             MSAL falls back to its default device bound key pair.
 */
- (instancetype)initWithHttpMethod:(MSALHttpMethod)httpMethod
                        requestUrl:(NSURL *)requestUrl
                             nonce:(nullable NSString *)nonce
              additionalParameters:(nullable NSDictionary *)additionalParameters
                   externalKeyPair:(nullable MSALExternalPoPKeyPair *)externalKeyPair NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
