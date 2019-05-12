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
#import "MSIDClientInfo.h"
#import "MSIDAccount.h"
#import "MSALAccount+Internal.h"
#import "NSURL+MSIDExtensions.h"
#import "MSALAuthority.h"
#import "MSIDAADV2IdTokenClaims.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAccount.h"
#import "MSALAccountId+Internal.h"
#import "MSIDAuthority.h"
#import "MSALTenantProfile.h"
#import "MSALTenantProfile+Internal.h"
#import "MSALPublicClientApplication+Internal.h"
#import "MSALAuthorityFactory.h"
#import "MSALAccountsProvider.h"
#import "MSALExternalAccount.h"
#import "MSALAuthority_Internal.h"

@implementation MSALAccount

- (instancetype)initWithUsername:(NSString *)username
                            name:(NSString *)name
                   homeAccountId:(NSString *)homeAccountId
                  localAccountId:(NSString *)localAccountId
                     environment:(NSString *)environment
                  tenantProfiles:(NSArray<MSALTenantProfile *> *)tenantProfiles
{
    self = [super init];

    if (self)
    {
        _username = username;
        _name = name;
        _environment = environment;

        NSArray *accountIdComponents = [homeAccountId componentsSeparatedByString:@"."];

        NSString *uid = nil;
        NSString *utid = nil;

        if ([accountIdComponents count] == 2)
        {
            uid = accountIdComponents[0];
            utid = accountIdComponents[1];
        }

        _homeAccountId = [[MSALAccountId alloc] initWithAccountIdentifier:homeAccountId
                                                                 objectId:uid
                                                                 tenantId:utid];

        _lookupAccountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:username homeAccountId:homeAccountId];
        
        if (tenantProfiles.count > 0)
        {
            self.mTenantProfiles = [[NSMutableArray alloc] initWithArray:tenantProfiles];
        }
    }

    return self;
}

- (instancetype)initWithMSIDAccount:(MSIDAccount *)account
                createTenantProfile:(BOOL)createTenantProfile
{
    NSError *error;
    // TODO: use the new msid authority factory which fixes a bug when handling B2C authority
    MSALAuthority *authority = [MSALAuthorityFactory authorityFromUrl:account.authority.url context:nil error:&error];
    if (error || !authority)
    {
        MSID_LOG_ERROR(nil, @"Failed to create msal authority from msid authority!");
        return nil;
    }
    
    NSArray *tenantProfiles;
    if (createTenantProfile)
    {
        MSALTenantProfile *tenantProfile = [[MSALTenantProfile alloc] initWithUserObjectId:account.localAccountId
                                                                                  tenantId:account.tenantId
                                                                                 authority:authority
                                                                              isHomeTenant:account.isHomeTenantAccount
                                                                                    claims:account.idTokenClaims.jsonDictionary];
        
        if (tenantProfile)
        {
            tenantProfiles = @[tenantProfile];
        }
    }
    
    return [self initWithUsername:account.username
                             name:account.name
                    homeAccountId:account.accountIdentifier.homeAccountId
                   localAccountId:account.localAccountId
                      environment:account.authority.environment
                   tenantProfiles:tenantProfiles];
}

- (instancetype)initWithMSALExternalAccount:(id<MSALExternalAccount>)externalAccount
{
    NSError *error = nil;
    
    MSALAuthority *authority = [MSALAuthorityFactory authorityFromUrl:externalAccount.authorityURL context:nil error:&error];
    
    if (error || !authority)
    {
        MSID_LOG_ERROR(nil, @"Failed to create msal authority from external provided authority!");
        return nil;
    }
    
    MSALTenantProfile *tenantProfile = [[MSALTenantProfile alloc] initWithUserObjectId:externalAccount.localAccountId
                                                                              tenantId:externalAccount.tenantId
                                                                             authority:authority
                                                                          isHomeTenant:NO
                                                                                claims:externalAccount.accountClaims];
    
    return [self initWithUsername:externalAccount.username
                             name:nil
                    homeAccountId:externalAccount.homeAccountId
                   localAccountId:externalAccount.localAccountId
                      environment:authority.msidAuthority.environment
                   tenantProfiles:@[tenantProfile]];
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
    MSALAccount *account = [[MSALAccount allocWithZone:zone] init];
    account.username = [self.username copyWithZone:zone];
    account.name = [self.name copyWithZone:zone];
    account.homeAccountId = [self.homeAccountId copyWithZone:zone];
    account.mTenantProfiles = [[NSMutableArray alloc] initWithArray:self.mTenantProfiles copyItems:YES];
    account.environment = [self.environment copyWithZone:zone];
    return account;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:MSALAccount.class])
    {
        return NO;
    }
    
    return [self isEqualToUser:(MSALAccount *)object];
}

/*
 TODO: this is correct implementation, but we can't use it until we agree on the public API changes
- (NSUInteger)hash
{
    NSUInteger hash = 0;
    hash = hash * 31 + self.username.hash;
    hash = hash * 31 + self.name.hash;
    hash = hash * 31 + self.homeAccountId.hash;
    hash = hash * 31 + self.localAccountId.hash;
    hash = hash * 31 + self.environment.hash;
    hash = hash * 31 + self.tenantId.hash;
    hash = hash * 31 + self.uid.hash;
    hash = hash * 31 + self.utid.hash;
    return hash;
}

- (BOOL)isEqualToUser:(MSALAccount *)user
{
    if (!user) return NO;
    
    BOOL result = YES;
    result &= (!self.username && !user.username) || [self.username isEqualToString:user.username];
    result &= (!self.name && !user.name) || [self.name isEqualToString:user.name];
    result &= (!self.homeAccountId && !user.homeAccountId) || [self.homeAccountId isEqualToString:user.homeAccountId];
    result &= (!self.localAccountId && !user.localAccountId) || [self.localAccountId isEqualToString:user.localAccountId];
    result &= (!self.environment && !user.environment) || [self.environment isEqualToString:user.environment];
    result &= (!self.tenantId && !user.tenantId) || [self.tenantId isEqualToString:user.tenantId];
    result &= (!self.uid && !user.uid) || [self.uid isEqualToString:user.uid];
    result &= (!self.utid && !user.utid) || [self.utid isEqualToString:user.utid];
    
    return result;
}*/

/* TODO: this is a temporary solution that maintains previous MSAL behavior of having one account per environment.
   This is a temporary solution to test the overall app and will be removed once we agree on the public API changes. */

- (NSUInteger)hash
{
    NSUInteger hash = 0;
    hash = hash * 31 + self.username.hash;
    hash = hash * 31 + self.homeAccountId.hash;
    hash = hash * 31 + self.environment.hash;
    return hash;
}

- (BOOL)isEqualToUser:(MSALAccount *)user
{
    if (!user) return NO;

    BOOL result = YES;
    result &= (!self.username && !user.username) || [self.username isEqualToString:user.username];
    result &= (!self.homeAccountId && !user.homeAccountId) || [self.homeAccountId.identifier isEqualToString:user.homeAccountId.identifier];
    result &= (!self.environment && !user.environment) || [self.environment isEqualToString:user.environment];

    return result;
}

#pragma mark - Tenant profiles

- (NSArray<MSALTenantProfile *> *)tenantProfiles
{
    return self.mTenantProfiles;
}

- (void)addTenantProfiles:(NSArray<MSALTenantProfile *> *)tenantProfiles
{
    if (tenantProfiles.count <= 0) return;
    
    if (self.mTenantProfiles)
    {
        [self.mTenantProfiles addObjectsFromArray:tenantProfiles];
    }
    else
    {
        self.mTenantProfiles = [[NSMutableArray alloc] initWithArray:tenantProfiles];
    }
}

@end
