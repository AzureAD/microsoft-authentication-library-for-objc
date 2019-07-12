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
#import "MSALTenantProfile+Internal.h"

@class MSIDAccountIdentifier;
@class MSIDAADV2IdTokenClaims;
@class MSIDClientInfo;
@class MSIDAccount;
@class MSALAccountId;
@class MSIDIdTokenClaims;
@protocol MSALAccount;
@class MSALOauth2Provider;

@interface MSALAccount ()

@property (nonatomic) MSALAccountId *homeAccountId;
@property (nonatomic) NSString *username;
@property (nonatomic) NSString *environment;
@property (nonatomic) NSMutableArray<MSALTenantProfile *> *mTenantProfiles;
@property (nonatomic) NSDictionary<NSString *, NSString *> *accountClaims;
@property (nonatomic) NSString *identifier;
@property (nonatomic) MSIDAccountIdentifier *lookupAccountIdentifier;

- (instancetype)initWithUsername:(NSString *)username
                   homeAccountId:(MSALAccountId *)homeAccountId
                     environment:(NSString *)environment
                  tenantProfiles:(NSArray<MSALTenantProfile *> *)tenantProfiles;

/*!
 Initialize an MSALAccount with MSIDAccount
 @param  account             MSID account
 @param  createTenantProfile Whether to create tenant profile based on the info of MSID account
 */
- (instancetype)initWithMSIDAccount:(MSIDAccount *)account createTenantProfile:(BOOL)createTenantProfile;
- (instancetype)initWithMSALExternalAccount:(id<MSALAccount>)externalAccount
                             oauth2Provider:(MSALOauth2Provider *)oauthProvider;

- (void)addTenantProfiles:(NSArray<MSALTenantProfile *> *)tenantProfiles;

@end
