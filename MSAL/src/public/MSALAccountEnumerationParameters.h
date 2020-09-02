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

/**
    MSALAccountEnumerationParameters represents possible account identifying parameters that could be used for filtering cached accounts.
 */
@interface MSALAccountEnumerationParameters : MSALParameters

#pragma mark - Filtering options

/**
    Unique identifier for the account.
 */
@property (nonatomic, readonly, nullable) NSString *identifier;

/**
    Unique identifier for the tenant profile.
 */
@property (nonatomic, readonly, nullable) NSString *tenantProfileIdentifier;

/**
    Shorthand name by which the End-User wishes to be referred to at the RP, such as janedoe or j.doe.
 */
@property (nonatomic, readonly, nullable) NSString *username;

/**
    Filter accounts by whether this account is in the signed in state for the current client.
    Signed in state is determined by the presence of a refresh token credential for the requesting client.
    If account has been explicitly removed through the "removeAccount" API, it will be also marked as "signed out" as MSAL will remove refresh token for the client.
 
    YES by default (== only returns signed in accounts).
    Set it to NO to query all accounts visible to your application regardless if there's a refresh token present or not.
 */
@property (nonatomic, readwrite) BOOL returnOnlySignedInAccounts;

#pragma mark - Initializing enumeration parameters

/**
    Creates a filter with an account identifier.
    @param accountIdentifier                    Unique identifier for the account.
 */

- (nonnull instancetype)initWithIdentifier:(nonnull NSString *)accountIdentifier;

/**
    Creates a filter with an account identifier and a displayable username.
    @param accountIdentifier                    Unique identifier for the account.
    @param username                                        Shorthand name by which the End-User wishes to be referred to at the RP, such as janedoe or j.doe. This value MAY be any valid JSON string                                                                              including special characters such as @, /, or whitespace.
*/
- (nonnull instancetype)initWithIdentifier:(nullable NSString *)accountIdentifier
                                  username:(nonnull NSString *)username;

/**
    Creates a filter with a tenant profile identifier.
    @param tenantProfileIdentifier          Unique identifier for the tenant profile.
*/
- (nonnull instancetype)initWithTenantProfileIdentifier:(nonnull NSString *)tenantProfileIdentifier;

@end
