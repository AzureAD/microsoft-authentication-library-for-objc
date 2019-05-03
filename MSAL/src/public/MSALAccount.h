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

@class MSALAccountId;
@class MSALTenantProfile;
@class MSALPublicClientApplication;

@interface MSALAccount : NSObject <NSCopying>

/*!
 The displayable value in UserPrincipleName(UPN) format. Can be nil if not returned from the service.
 */
@property (readonly, nullable) NSString *username;

/*!
 Unique identifier of the account in the home directory.
 */
@property (readonly, nullable) MSALAccountId *homeAccountId;

/*!
 Host part of the authority string used for authentication.
 */
@property (readonly, nonnull) NSString *environment;

/*!
 Array of all tenants for which a token has been requested by the client.
 
 Note that this field will only be available when querying account(s) by the following APIs of MSALPublicClientApplication:
 -allAccounts:
 -accountForHomeAccountId:error:
 -accountForUsername:error:
 -allAccountsFilteredByAuthority:
 
 The field will be nil in other scenarios. E.g., account returned as part of the result of an acqure token interactive/silent call.
 */
@property (readonly, nullable) NSArray<MSALTenantProfile *> *tenantProfiles;

@end

