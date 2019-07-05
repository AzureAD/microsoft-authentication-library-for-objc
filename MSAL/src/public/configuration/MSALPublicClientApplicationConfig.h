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
#import "MSALDefinitions.h"

@class MSALRedirectUri;
@class MSALAuthority;
@class MSALSliceConfig;
@class MSALCacheConfig;

NS_ASSUME_NONNULL_BEGIN

@interface MSALPublicClientApplicationConfig : NSObject <NSCopying>

/*! The client ID of the application, this should come from the app developer portal. */
@property (nonatomic) NSString *clientId;

/*! The redirect URI of the application */
@property (nonatomic) NSString *redirectUri;

/*! The authority the application will use to obtain tokens */
@property (nonatomic) MSALAuthority *authority;

/*! List of known authorities that application should trust.
    Note that authorities listed here will bypass authority validation logic.
    Thus, it is advised not putting in here dynamically resolving authorities here.
 */
@property (nonatomic) NSArray<MSALAuthority *> *knownAuthorities;

/*! Enable to return access token with extended lifttime during server outage. */
@property (nonatomic) BOOL extendedLifetimeEnabled;

/*! List of additional ESTS features that client handles. */
@property (nullable) NSArray<NSString *> *clientApplicationCapabilities;

/*! When checking an access token for expiration we check if time to expiration
 is less than this value (in seconds) before making the request. The goal is to
 refresh the token ahead of its expiration and also not to return a token that is
 about to expire. */
@property (nonatomic) double tokenExpirationBuffer;

/*! slice configuration for testing. */
@property (nonatomic, nullable) MSALSliceConfig *sliceConfig;

/*! Cache configurations, refer to MSALCacheConfig.h for more detail */
@property (nonatomic, readonly) MSALCacheConfig *cacheConfig;

/*!
 Initialize a MSALPublicClientApplicationConfig with a given clientId
 
 @param  clientId   The clientID of your application, you should get this from the app portal.
 */
- (nonnull instancetype)initWithClientId:(NSString *)clientId DEPRECATED_MSG_ATTRIBUTE("Use [MSALPublicClientApplicationConfig initWithClientId:redirectUri:authority:] instead");

/*!
 Initialize a MSALPublicClientApplicationConfig with a given clientId
 
 @param  clientId       The clientID of your application, you should get this from the app portal.
 @param  redirectUri    The redirect URI of the application
 @param  authority      The target authority
 */
- (nonnull instancetype)initWithClientId:(NSString *)clientId
                             redirectUri:(nullable NSString *)redirectUri
                               authority:(nullable MSALAuthority *)authority;

- (nonnull instancetype)init NS_UNAVAILABLE;
+ (nonnull instancetype)new NS_UNAVAILABLE;

// Todo: add a init that takes in a config file.

@end

NS_ASSUME_NONNULL_END
