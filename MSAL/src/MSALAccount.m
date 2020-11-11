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
#import "MSALAccountsProvider.h"
#import "MSALAuthority_Internal.h"
#import "MSALOauth2Provider.h"
#import "MSIDAccountIdentifier.h"

@implementation MSALAccount

- (instancetype)initWithUsername:(NSString *)username
                   homeAccountId:(MSALAccountId *)homeAccountId
                     environment:(NSString *)environment
                  tenantProfiles:(NSArray<MSALTenantProfile *> *)tenantProfiles
{
    self = [super init];

    if (self)
    {
        _username = username;
        _environment = environment;
        _homeAccountId = homeAccountId;
        _identifier = homeAccountId.identifier;
        _lookupAccountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:username homeAccountId:homeAccountId.identifier];
        
        [self addTenantProfiles:tenantProfiles];
    }

    return self;
}

- (instancetype)initWithMSIDAccount:(MSIDAccount *)account
                createTenantProfile:(BOOL)createTenantProfile
{
    NSArray *tenantProfiles = nil;
    if (createTenantProfile)
    {
        NSDictionary *allClaims = account.idTokenClaims.jsonDictionary;
        
        MSALTenantProfile *tenantProfile = [[MSALTenantProfile alloc] initWithIdentifier:account.localAccountId
                                                                                tenantId:account.realm
                                                                             environment:account.storageEnvironment ?: account.environment
                                                                     isHomeTenantProfile:account.isHomeTenantAccount
                                                                                  claims:allClaims];
        if (tenantProfile)
        {
            tenantProfiles = @[tenantProfile];
        }
    }
    
    MSALAccountId *homeAccountId = [[MSALAccountId alloc] initWithAccountIdentifier:account.accountIdentifier.homeAccountId
                                                                           objectId:account.accountIdentifier.uid
                                                                           tenantId:account.accountIdentifier.utid];
    
    MSALAccount *msalAccount = [self initWithUsername:account.username
                                        homeAccountId:homeAccountId
                                          environment:account.storageEnvironment ?: account.environment
                                       tenantProfiles:tenantProfiles];
    
    msalAccount.isSSOAccount = account.isSSOAccount;
    return msalAccount;
}

- (instancetype)initWithMSALExternalAccount:(id<MSALAccount>)externalAccount
                             oauth2Provider:(MSALOauth2Provider *)oauthProvider
{
    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:externalAccount.identifier];
    MSALAccountId *homeAccountId = [[MSALAccountId alloc] initWithAccountIdentifier:accountIdentifier.homeAccountId
                                                                           objectId:accountIdentifier.uid
                                                                           tenantId:accountIdentifier.utid];
    
    NSError *tenantProfileError = nil;
    MSALTenantProfile *tenantProfile = [oauthProvider tenantProfileWithClaims:externalAccount.accountClaims
                                                                homeAccountId:homeAccountId
                                                                  environment:externalAccount.environment
                                                                        error:&tenantProfileError];
    
    if (tenantProfileError)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, nil, @"Failed to create tenant profile with error code %ld, domain %@", (long)tenantProfileError.code, tenantProfileError.domain);
    }
    
    NSArray *tenantProfiles = tenantProfile ? @[tenantProfile] : nil;
    
    MSALAccount *account = [self initWithUsername:externalAccount.username
                                    homeAccountId:homeAccountId
                                      environment:externalAccount.environment
                                   tenantProfiles:tenantProfiles];
    
    return account;
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
    NSString *username = [self.username copyWithZone:zone];
    MSALAccountId *homeAccountId = [self.homeAccountId copyWithZone:zone];
    NSString *environment = [self.environment copyWithZone:zone];
    NSArray *tenantProfiles = [[NSMutableArray alloc] initWithArray:[self tenantProfiles] copyItems:YES];
    
    MSALAccount *account = [[MSALAccount allocWithZone:zone] initWithUsername:username homeAccountId:homeAccountId environment:environment tenantProfiles:tenantProfiles];
    account.accountClaims = [self.accountClaims copyWithZone:zone];
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
    
    return [self isEqualToAccount:(MSALAccount *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = 0;
    // Equality of MSALAccount is depending on equality of homeAccountId or username
    // So we are not able to calculate a precise hash
    return hash;
}

- (BOOL)isEqualToAccount:(MSALAccount *)user
{
    if (!user) return NO;

    BOOL result = YES;
    
    if (self.homeAccountId.identifier && user.homeAccountId.identifier)
    {
        result &= [self.homeAccountId.identifier isEqualToString:user.homeAccountId.identifier];
    }
    else if (self.username || user.username)
    {
        result &= [self.username.lowercaseString isEqualToString:user.username.lowercaseString];
    }
    
    return result;
}

#pragma mark - Tenant profiles

- (NSArray<MSALTenantProfile *> *)tenantProfiles
{
    return self.mTenantProfiles.allValues;
}

- (void)addTenantProfiles:(NSArray<MSALTenantProfile *> *)tenantProfiles
{
    if (tenantProfiles.count <= 0) return;
    
    if (!self.mTenantProfiles)
    {
        self.mTenantProfiles = [NSMutableDictionary new];
    }
    
    for (MSALTenantProfile *profile in tenantProfiles)
    {
        if (profile.tenantId && !self.mTenantProfiles[profile.tenantId])
        {
            self.mTenantProfiles[profile.tenantId] = profile;
        }
    }
}

@end
