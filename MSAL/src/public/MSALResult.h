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

@class MSALAccount;
@class MSALAuthority;
@class MSALTenantProfile;

/**
    MSALResult represents information returned to the application after a successful interactive or silent token acquisition.
    It contains information requested by the application (e.g. access_token and id_token), and information that can be used to get a token silently from MSAL (e.g. account).
 */
NS_SWIFT_SENDABLE
@interface MSALResult : NSObject

#pragma mark - Token response

/**
 The Access Token requested.
 Note that if access token is not returned in token response, this property will be returned as an empty string.
 */
@property (atomic, readonly, nonnull) NSString *accessToken;

/**
    The time that the access token returned in the Token property ceases to be valid.
    This value is calculated based on current UTC time measured locally and the value expiresIn returned from the service
 */
@property (atomic, readonly, nullable) NSDate *expiresOn;

/**
    Some access tokens have extended lifetime when server is in an unavailable state.
    This property indicates whether the access token is returned in such a state.
 */
@property (atomic, readonly) BOOL extendedLifeTimeToken;

/**
 The raw id token if it's returned by the service or nil if no id token is returned.
 */
@property (atomic, readonly, nullable) NSString *idToken;

/**
    The scope values returned from the service.
 */
@property (atomic, readonly, nonnull) NSArray<NSString *> *scopes;

#pragma mark - Account information

/**
 A tenant profile object that contains all the tenant-specific information, including tenant id, user object id, etc. It also contains all the id token claims as a dictionary.
 */
@property (atomic, readonly, nonnull) MSALTenantProfile *tenantProfile;

/**
    The account object that holds account information.
 */
@property (atomic, readonly, nonnull) MSALAccount *account;

#pragma mark - Request information

/**
 Represents the authority used for getting the token from STS and caching it.
 This authority should be used for subsequent silent requests.
 It might be different from the authority provided by developer (e.g. for sovereign cloud scenarios).
 */
@property (atomic, readonly, nonnull) MSALAuthority *authority;

/**
 The correlation ID of the request.
 */
@property (atomic, readonly, nonnull) NSUUID *correlationId;

/**
 The authorization header for the specific authentication scheme . For instance "Bearer ..." or "Pop ...".
 */
@property (atomic, readonly, nonnull) NSString *authorizationHeader;

/**
 The authentication scheme for the tokens issued. For instance "Bearer " or "Pop".
 */
@property (atomic, readonly, nonnull) NSString *authenticationScheme;

@end
