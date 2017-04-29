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

#import "MSALTokenCacheAccessor.h"

@class MSALTokenResponse;
@class MSALRequestParameters;
@protocol MSALRequestContext;

@interface MSALTokenCache : NSObject

- (id)initWithDataSource:(id<MSALTokenCacheAccessor>)dataSource;

- (id<MSALTokenCacheAccessor>)dataSource;

- (MSALAccessTokenCacheItem *)saveAccessTokenWithAuthority:(NSURL *)authority
                                                  clientId:(NSString *)clientId
                                                  response:(MSALTokenResponse *)response
                                                   context:(id<MSALRequestContext>)context
                                                     error:(NSError * __autoreleasing *)error;

- (MSALRefreshTokenCacheItem *)saveRefreshTokenWithEnvironment:(NSString *)environment
                                                      clientId:(NSString *)clientId
                                                      response:(MSALTokenResponse *)response
                                                       context:(id<MSALRequestContext>)context
                                                         error:(NSError * __autoreleasing *)error;

/*
    Searches the cache for either a matching access token, or an authority to use, if it only found
    one authority matching the client ID and user. Returns NO if it can't find either.
 */
- (BOOL)findAccessTokenWithAuthority:(NSURL *)authority
                            clientId:(NSString *)clientId
                              scopes:(MSALScopes *)scopes
                                user:(MSALUser *)user
                             context:(id<MSALRequestContext>)ctx
                         accessToken:(MSALAccessTokenCacheItem **)outAccessToken
                      authorityFound:(NSString **)outAuthorityFound
                               error:(NSError * __autoreleasing *)error;

- (MSALRefreshTokenCacheItem *)findRefreshTokenWithEnvironment:(NSString *)environment
                                                      clientId:(NSString *)clientId
                                                userIdentifier:(NSString *)userIdentifier
                                                       context:(id<MSALRequestContext>)ctx
                                                         error:(NSError * __autoreleasing *)error;

- (BOOL)deleteAllTokensForUser:(MSALUser *)user
                      clientId:(NSString *)clientId
                       context:(id<MSALRequestContext>)ctx
                         error:(NSError * __autoreleasing *)error;

- (NSArray<MSALUser *> *)getUsers:(NSString *)clientId
                          context:(id<MSALRequestContext>)ctx
                            error:(NSError * __autoreleasing *)error;

- (MSALUser *)getUserForIdentifier:(NSString *)userIdentifier
                          clientId:(NSString *)clientId
                       environment:(NSString *)environment
                             error:(NSError * __autoreleasing *)error;

@end
