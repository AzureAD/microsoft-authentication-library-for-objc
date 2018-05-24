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

#import "MSALAccount.h"

@class MSIDAccountIdentifier;
@class MSIDAADV2IdTokenClaims;
@class MSIDClientInfo;
@class MSIDAccount;

@interface MSALAccount ()

@property (nonatomic) MSIDAccountIdentifier *lookupAccountIdentifier;
@property (nonatomic) NSString *uid;
@property (nonatomic) NSString *utid;

/* TODO: These properties will be public once we agree on having an account per tenant.
         For now, will keep them here.
 */

/*!
 The displayable name of the account. Can be nil if not returned by the service.
 */
@property (nonatomic) NSString *name;

/*!
 Unique identifier of the account in the signed in directory.
 */
@property (nonatomic) NSString *localAccountId;
/*!
 An identifier for the tenant that the account was acquired from. This property will be nil if tenant information is not returned by the service.
 */
@property (nonatomic) NSString *tenantId;

/*!
 Initialize an MSALAccount with given information

 @param  displayableId       The displayable value in UserPrincipleName(UPN) format
 @param  name                The given name of the user
 @param  homeAccountId       Unique identifier of the account in the home directory
 @param  localAccountId      Unique identifier of the account in the signed in directory.
 @param  environment         Host part of the authority string
 @param  tenantId            An identifier for the tenant that the account was acquired from
 */
- (id)initWithDisplayableId:(NSString *)displayableId
                       name:(NSString *)name
              homeAccountId:(NSString *)homeAccountId
             localAccountId:(NSString *)localAccountId
                environment:(NSString *)environment
                   tenantId:(NSString *)tenantId
                 clientInfo:(MSIDClientInfo *)clientInfo;

/*!
 Initialize an MSALAccount with MSIDAccount
 @param  account             MSID account
 */
- (id)initWithMSIDAccount:(MSIDAccount *)account;

@end
