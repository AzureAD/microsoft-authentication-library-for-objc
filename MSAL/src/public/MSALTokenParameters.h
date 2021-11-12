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
#import "MSALParameters.h"

@class MSALAccount;
@class MSALAuthority;
@class MSALClaimsRequest;
@protocol MSALAuthenticationSchemeProtocol;

NS_ASSUME_NONNULL_BEGIN

/**
 MSALTokenParameters is the base abstract class for all types of token parameters (see `MSALInteractiveTokenParameters` and `MSALSilentTokenParameters`).
 */
@interface MSALTokenParameters : MSALParameters

#pragma mark - Configuration parameters

/**
 Permissions you want included in the access token received
 in the result in the completionBlock. Not all scopes are
 guaranteed to be included in the access token returned.
 */
@property (nonatomic) NSArray<NSString *> *scopes;

/**
 An account object for which tokens should be returned.
 */
@property (nonatomic, nullable) MSALAccount *account;

/**
 The authority that MSAL will use to obtain tokens.
 Azure AD it is of the form https://aad_instance/aad_tenant, where
 aad_instance is the directory host
 (e.g. https://login.microsoftonline.com) and aad_tenant is a
 identifier within the directory itself (e.g. a domain associated
 to the tenant, such as contoso.onmicrosoft.com, or the GUID
 representing the TenantID property of the directory).
 If nil, authority from MSALPublicClientApplication will be used.
 */
@property (nonatomic, nullable) MSALAuthority *authority;

/**
 The claims parameter that needs to be sent to authorization or token endpoint.
 If claims parameter is passed in silent flow, access token will be skipped and refresh token will be tried.
 */
@property (nonatomic, nullable) MSALClaimsRequest *claimsRequest;

/**
 Key-value pairs to pass to the /authorize and /token endpoints. This should not be url-encoded value.
 */
@property (nonatomic, nullable) NSDictionary <NSString *, NSString *> *extraQueryParameters;

/**
 UUID to correlate this request with the server.
 */
@property (nonatomic, nullable) NSUUID *correlationId;

/**
 Authentication Scheme to access the resource
 */
@property (nonatomic, nullable) id<MSALAuthenticationSchemeProtocol> authenticationScheme;

#pragma mark - Creating MSALTokenParameters

/**
 Initialize a MSALTokenParameters with scopes.
 
 @param scopes      Permissions you want included in the access token received
                    in the result in the completionBlock. Not all scopes are
                    guaranteed to be included in the access token returned.
 */
- (instancetype)initWithScopes:(NSArray<NSString *> *)scopes NS_DESIGNATED_INITIALIZER;

#pragma mark - Unavailable initializers

/**
    Use `[MSALTokenParameters initWithScopes:]` instead
 */
+ (instancetype)new NS_UNAVAILABLE;

/**
   Use `[MSALTokenParameters initWithScopes:]` instead
*/
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
