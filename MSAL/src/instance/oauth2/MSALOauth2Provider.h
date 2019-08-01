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

NS_ASSUME_NONNULL_BEGIN

@class MSIDOauth2Factory;
@class MSIDTokenResult;
@class MSIDDefaultTokenCacheAccessor;
@class MSALAccount;
@class MSIDAuthority;
@class MSALTenantProfile;
@class MSALAccountId;
@class MSIDAccountMetadataCacheAccessor;

@interface MSALOauth2Provider : NSObject

@property (nonatomic, readonly) MSIDOauth2Factory *msidOauth2Factory;
@property (nonatomic, readonly) NSString *clientId;
@property (nonatomic, readonly) MSIDAccountMetadataCacheAccessor *accountMetadataCache;
@property (nonatomic, readonly) MSIDDefaultTokenCacheAccessor *tokenCache;

- (nonnull instancetype)init NS_UNAVAILABLE;
+ (nonnull instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithClientId:(NSString *)clientId
                      tokenCache:(nullable MSIDDefaultTokenCacheAccessor *)tokenCache
            accountMetadataCache:(nullable MSIDAccountMetadataCacheAccessor *)accountMetadataCache;

- (nullable MSALResult *)resultWithTokenResult:(MSIDTokenResult *)tokenResult
                                         error:(NSError * _Nullable * _Nullable)error;

- (BOOL)removeAdditionalAccountInfo:(MSALAccount *)account
                              error:(NSError * _Nullable * _Nullable)error;

- (MSIDAuthority *)issuerAuthorityWithAccount:(MSALAccount *)account
                             requestAuthority:(MSIDAuthority *)requestAuthority
                                instanceAware:(BOOL)instanceAware
                                        error:(NSError **)error;

- (BOOL)isSupportedAuthority:(MSIDAuthority *)authority;

- (nullable MSALTenantProfile *)tenantProfileWithClaims:(NSDictionary *)claims
                                          homeAccountId:(MSALAccountId *)homeAccountId
                                            environment:(NSString *)environment
                                                  error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
