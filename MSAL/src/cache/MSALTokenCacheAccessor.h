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

@class MSALAccessTokenCacheKey;
@class MSALRefreshTokenCacheKey;
@class MSALAccessTokenCacheItem;
@class MSALRefreshTokenCacheItem;

@protocol MSALRequestContext;

@protocol MSALTokenCacheAccessor <NSObject>

- (nullable NSArray<MSALAccessTokenCacheItem *> *)getAccessTokenItemsWithKey:(nullable MSALAccessTokenCacheKey *)key
                                                                     context:(nullable id<MSALRequestContext>)ctx
                                                                       error:(NSError * __nullable __autoreleasing * __nullable)error;

- (nullable MSALRefreshTokenCacheItem *)getRefreshTokenItemForKey:(nonnull MSALRefreshTokenCacheKey *)key
                                                          context:(nullable id<MSALRequestContext>)ctx
                                                            error:(NSError * __nullable __autoreleasing * __nullable)error;

- (nullable NSArray<MSALRefreshTokenCacheItem *> *)allRefreshTokens:(nullable NSString *)clientId
                                                            context:(nullable id<MSALRequestContext>)ctx
                                                              error:(NSError * __nullable __autoreleasing * __nullable)error;

- (BOOL)addOrUpdateAccessTokenItem:(nonnull MSALAccessTokenCacheItem *)item
                           context:(nullable id<MSALRequestContext>)ctx
                             error:(NSError * __nullable __autoreleasing * __nullable)error;

- (BOOL)addOrUpdateRefreshTokenItem:(nonnull MSALRefreshTokenCacheItem *)item
                            context:(nullable id<MSALRequestContext>)ctx
                              error:(NSError * __nullable __autoreleasing * __nullable)error;

- (BOOL)removeAccessTokenItem:(nonnull MSALAccessTokenCacheItem *)item
                      context:(nullable id<MSALRequestContext>)ctx
                        error:(NSError * __nullable __autoreleasing * __nullable)error;

- (BOOL)removeRefreshTokenItem:(nonnull MSALRefreshTokenCacheItem *)item
                       context:(nullable id<MSALRequestContext>)ctx
                         error:(NSError * __nullable __autoreleasing * __nullable)error;

- (BOOL)removeAllTokensForUserIdentifier:(nullable NSString *)userIdentifier
                             environment:(nonnull NSString *)environment
                                clientId:(nonnull NSString *)clientId
                                 context:(nullable id<MSALRequestContext>)ctx
                                   error:(NSError * __nullable __autoreleasing * __nullable)error;

@end
