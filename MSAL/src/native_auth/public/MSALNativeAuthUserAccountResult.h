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


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class MSALNativeAuthTokens;
@class MSALNativeAuthConfiguration;
@class MSALNativeAuthCacheInterface;
@class MSALControllerResponse;
@class MSALNativeAuthRequestContext;
@class CredentialsDelegate;
@class MSALNativeAuthRequestContext;
@class MSALLogger;
@class MSALNativeAuthCredentialsControlling;

@interface MSALNativeAuthUserAccountResult : NSObject

@property (nonatomic, strong) MSALAccount *account;
@property (nonatomic, strong) MSALNativeAuthTokens *authTokens;
@property (nonatomic, strong) MSALNativeAuthConfiguration *configuration;
@property (nonatomic, strong) MSALNativeAuthCacheInterface *cacheAccessor;

/// Get the ID token for the account.
@property (nonatomic, strong, readonly) NSString *idToken;

/// Get the list of permissions for the access token for the account if present.
@property (nonatomic, strong, readonly) NSArray<NSString *> *scopes;

/// Get the expiration date for the access token for the account if present.
@property (nonatomic, strong, readonly) NSDate *expiresOn;

- (instancetype) initWithTest:(NSString*) test;

- (instancetype)initWithAccount:(MSALAccount *)account
                     authTokens:(MSALNativeAuthTokens *)authTokens
                  configuration:(MSALNativeAuthConfiguration *)configuration
                  cacheAccessor:(MSALNativeAuthCacheInterface *)cacheAccessor;
- (void)getAccessTokenWithDelegate:(CredentialsDelegate*) delegate;

- (void)getAccessTokenWithForceRefresh:(BOOL)forceRefresh
                         correlationId:(nullable NSUUID *)correlationId
                              delegate:(CredentialsDelegate*) delegate;


/// Removes all the data from the cache.
- (void)signOut;

@end

NS_ASSUME_NONNULL_END
