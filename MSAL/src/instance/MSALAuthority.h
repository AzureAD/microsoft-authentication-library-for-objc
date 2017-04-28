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
@class MSALTenantDiscoveryResponse;

typedef void(^OpenIDConfigEndpointCallback)(NSString *endpoint, NSError *error);
typedef void(^TenantDiscoveryCallback)(MSALTenantDiscoveryResponse *response, NSError *error);

@protocol MSALAuthorityResolver

- (void)openIDConfigurationEndpointForAuthority:(NSURL *)authority
                              userPrincipalName:(NSString *)userPrincipalName
                                       validate:(BOOL)validate
                                        context:(id<MSALRequestContext>)context
                                completionBlock:(OpenIDConfigEndpointCallback)completionBlock;

- (NSString *)defaultOpenIdConfigurationEndpointForAuthority:(NSURL *)authority;

- (void)tenantDiscoveryEndpoint:(NSURL *)url
                        context:(id<MSALRequestContext>)context
                completionBlock:(TenantDiscoveryCallback)completionBlock;

@end

typedef NS_ENUM(NSInteger, MSALAuthorityType)
{
    AADAuthority,
    ADFSAuthority,
    B2CAuthority
};

typedef void(^MSALAuthorityCompletion)(MSALAuthority *authority, NSError *error);

@interface MSALAuthority : NSObject

@property MSALAuthorityType authorityType;
@property NSURL *canonicalAuthority;
@property BOOL validatedAuthority;
@property BOOL isTenantless;
@property NSURL *authorizationEndpoint;
@property NSURL *tokenEndpoint;
@property NSURL *endSessionEndpoint;
// For AAD, currently, the v2.0 endpoint doesn't support the OpenID Connect end_session_endpoint
// https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-v2-protocols-oidc
@property NSString *selfSignedJwtAudience;

/*!
    Performs cursory validation on the passed in authority string to make sure it is
    a proper HTTPS URL and contains a tenant or common.
 */
+ (NSURL *)checkAuthorityString:(NSString *)authority
                          error:(NSError * __autoreleasing *)error;

+ (void)resolveEndpointsForAuthority:(NSURL *)unvalidatedAuthority
                   userPrincipalName:(NSString *)userPrincipalName
                            validate:(BOOL)validate
                             context:(id<MSALRequestContext>)context
                     completionBlock:(MSALAuthorityCompletion)completionBlock;

+ (BOOL)isKnownHost:(NSURL *)url;

/*!
    Returns YES if the URL includes a specific tenant NO if it does not.
 */
+ (BOOL)isTenantless:(NSURL *)authority;

+ (NSURL *)defaultAuthority;

/*!
    Returns the URL to use in the cache key for a given authority input string
    and tenant ID returned with the token response.
 */
+ (NSURL *)cacheUrlForAuthority:(NSURL *)authority
                       tenantId:(NSString *)tenantId;

+ (NSSet<NSString *> *)trustedHosts;

+ (BOOL)addToResolvedAuthority:(MSALAuthority *)authority
             userPrincipalName:(NSString *)userPrincipalName;

+ (MSALAuthority *)authorityFromCache:(NSURL *)authority
                        authorityType:(MSALAuthorityType)authorityType
                    userPrincipalName:(NSString *)userPrincipalName;

@end
