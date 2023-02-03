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

/**
    Configuration for an instance of `MSALPublicClientApplication`
    @note Once `MSALPublicClientApplication` is initialized, MSALPublicClientApplication object ignores any changes you make to the MSALPublicClientApplicationConfig object.
*/
@interface MSALPublicClientApplicationConfig : NSObject <NSCopying>

#pragma mark - Configuration options

/** The client ID of the application, this should come from the app developer portal. */
@property (atomic) NSString *clientId;

/** The redirect URI of the application */
@property (atomic, nullable) NSString *redirectUri;

/** The client ID of the nested application. */
@property (atomic) NSString *nestedAuthBrokerClientId;

/** The redirect URI of the nested application */
@property (atomic, nullable) NSString *nestedAuthBrokerRedirectUri;

/** The authority the application will use to obtain tokens */
@property (atomic) MSALAuthority *authority;

/** List of known authorities that application should trust.
    Note that authorities listed here will bypass authority validation logic.
    Thus, it is advised not putting dynamically resolving authorities here.
 */
@property (nonatomic) NSArray<MSALAuthority *> *knownAuthorities;

/** Enable to return access token with extended lifetime during server outage. */
@property (atomic) BOOL extendedLifetimeEnabled;

/** List of additional STS features that client handles. */
@property (atomic, nullable) NSArray<NSString *> *clientApplicationCapabilities;

/** Time in seconds controlling how long before token expiry MSAL refreshes access tokens.
 When checking an access token for expiration we check if time to expiration
 is less than this value (in seconds) before making the request. The goal is to
 refresh the token ahead of its expiration and also not to return a token that is
 about to expire. */
@property (nonatomic) double tokenExpirationBuffer;

/** Used to specify query parameters that must be passed to both the authorize and token endpoints
to target MSAL at a specific test slice & flight. These apply to all requests made by an application. */
@property (nullable) MSALSliceConfig *sliceConfig;

/** MSAL configuration interface responsible for token caching and keychain configuration. Refer to `MSALCacheConfig` for more details */
@property (readonly) MSALCacheConfig *cacheConfig;

/**
 For clients that support multiple national clouds, set this to YES. NO by default.
 If set to YES, the Microsoft identity platform will automatically redirect user to the correct national cloud during the authorization flow. You can determine the national cloud of the signed-in account by examining the authority associated with the MSALResult. Note that the MSALResult doesn't provide the national cloud-specific endpoint address of the resource for which you request a token.
 
 @note Your client_id needs to be registered in national clouds for this feature to work.
 */
@property (nonatomic) BOOL multipleCloudsSupported;

#pragma mark - Constructing configuration

/**
 Initialize a MSALPublicClientApplicationConfig with a given clientId
 
 @param  clientId   The clientID of your application, you should get this from the app portal.
 */
- (nonnull instancetype)initWithClientId:(NSString *)clientId;

/**
 For client that wants to bypass redirectURI check in MSAL, set this to YES. NO by default.
 If set to YES, MSAL will skip the verification of redirectURI. Brokered authentication will be disabled in this case.
 */
@property (atomic) BOOL bypassRedirectURIValidation;

/**
 Initialize a MSALPublicClientApplicationConfig with a given clientId
 
 @param  clientId       The clientID of your application, you should get this from the app portal.
 @param  redirectUri    The redirect URI of the application
 @param  authority      The target authority
 */
- (nonnull instancetype)initWithClientId:(NSString *)clientId
                             redirectUri:(nullable NSString *)redirectUri
                               authority:(nullable MSALAuthority *)authority;

/**
 Initialize a MSALPublicClientApplicationConfig with a given clientId and a nested clientid
 
 @param  clientId       The clientID of your application, you should get this from the app portal.
 @param  redirectUri    The redirect URI of the application
 @param  authority      The target authority
 @param  nestedAuthBrokerClientId     The clientID of your child application
 @param  nestedAuthBrokerRedirectUri    The redirect URI of the child application
 */
- (nonnull instancetype)initWithClientId:(NSString *)clientId
                             redirectUri:(nullable NSString *)redirectUri
                               authority:(nullable MSALAuthority *)authority
                nestedAuthBrokerClientId:(nullable NSString *)nestedAuthBrokerClientId
             nestedAuthBrokerRedirectUri:(nullable NSString *)nestedAuthBrokerRedirectUri;

#pragma mark - Unavailable initializers

/**
    Use `[MSALPublicClientApplicationConfig initWithClientId:redirectUri:authority]` instead
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

/**
   Use `[MSALPublicClientApplicationConfig initWithClientId:redirectUri:authority]` instead
*/
+ (nonnull instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
