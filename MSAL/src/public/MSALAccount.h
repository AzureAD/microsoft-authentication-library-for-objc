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
 Shorthand name by which the End-User wishes to be referred to at the RP, such as janedoe or j.doe. This value MAY be any valid JSON string including special characters such as @, /, or whitespace.
 Mostly maps to UserPrincipleName(UPN) in case of AAD.
 Can be nil if not returned from the service.
 */
@property (readonly, nullable) NSString *username;

/*!
 Unique identifier of the account in the home tenant.
 This can be used later to retrieve accounts and tokens silently from MSAL.
 */
@property (readonly, nullable) MSALAccountId *homeAccountId;

/*!
 Host part of the authority string used for authentication based on the issuer identifier.
 Note that if a host supports multiple tenants, there'll be one MSALAccount for the host and one tenant profile per each tenant accessed.
 If a host doesn't support multiple tenants, there'll be one MSALAccount with one tenant profile per host returned.
 
 e.g. if app accesses following tenants: Contoso.com and MyOrg.com in the Public AAD cloud, there'll be following information returned:
 
MSALAccount
- environment of "login.microsoftonline.com"
- homeAccountId based on the GUID of "MyOrg.com"
- tenantProfiles
    - tenantProfile[0]
        - localAccountId based on account identifiers from "MyOrg.com" (account object id in MyOrg.com and tenant Id for MyOrg.com directory)
        - claims for the id token issued by MyOrg.com
    - tenantProfile[1]
        - localAccountId based on account identifiers from "Contoso.com"
        - claims for the id token issued by Contoso.com
 */
@property (readonly, nonnull) NSString *environment;

/*!
 Array of all tenants for which a token has been requested by the client.
 
 Note that this field will only be available when querying account(s) by the following APIs of MSALPublicClientApplication:
 -allAccounts:
 -accountForHomeAccountId:error:
 -accountForUsername:error:
 -allAccountsFilteredByAuthority:
 
 The field will be nil in other scenarios. E.g., account returned as part of the result of an acquire token interactive/silent call.
 */
@property (readonly, nullable) NSArray<MSALTenantProfile *> *tenantProfiles;

@end

