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

@class MSALAuthority;
@class MSALAccountId;

NS_ASSUME_NONNULL_BEGIN

@interface MSALTenantProfile : NSObject <NSCopying>

/*!
 Unique identifier for the tenant profile.
 */
@property (readonly, nullable) NSString *identifier;

/*!
 Host part of the authority.
 */
@property (readonly, nullable) NSString *environment;

/*!
 Identifier for the directory where account is locally represented
 */
@property (readonly, nullable) NSString *tenantId;

/*!
 Indicator if this tenant profile represents account's home tenant.
 If an admin deletes this account from the tenant, it prevents this account from accessing anything in any tenant with the Microsoft Identity Platform.
 */
@property (readonly) BOOL isHomeTenantProfile;

/*!
 ID token claims for the account in the specified tenant. 
*/
@property (readonly, nullable) NSDictionary<NSString *, NSString *> *claims;

@end

NS_ASSUME_NONNULL_END
