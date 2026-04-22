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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSALTokenParameters.h"

@protocol MSIDCacheAccessor;

NS_ASSUME_NONNULL_BEGIN

/**
 Token parameters to be used when MSAL is getting a token for a device. The resulting token won't have a user identity associated with it.
 */
@interface MSALDeviceTokenParameters : MSALTokenParameters

- (instancetype)initWithScopes:(NSArray<NSString *> *)scopes NS_UNAVAILABLE;

@property (nonatomic, readonly) NSString *tenantId;
@property (nonatomic, readonly) NSString *resource;
@property (nonatomic, readonly) id<MSIDCacheAccessor> tokenCache;

#pragma mark - Constructing MSALDeviceTokenParameters

/**
 Initialize a MSALDeviceTokenParameters with a resource and optional scopes.

 @param resource    The resource for which the token is requested. Resources MUST have a property set in MSODS permitting device_tokens to be issued for that resource.
 @param scopes      Permissions you want included in the access token received
                    in the result in the completionBlock. Not all scopes are
                    guaranteed to be included in the access token returned. Can be nil.
 @param tenantId    The tenant identifier. This is mandatory.
 @param tokenCache  The token cache accessor. This is mandatory.
 */
- (instancetype)initWithResource:(NSString *)resource
                          scopes:(nullable NSArray<NSString *> *)scopes
                     forTenantId:(NSString *)tenantId
                      tokenCache:(id<MSIDCacheAccessor>)tokenCache;

@end

NS_ASSUME_NONNULL_END
