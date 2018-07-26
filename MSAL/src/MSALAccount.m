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
#import "MSIDAuthority.h"
#import "MSIDAADV2IdTokenClaims.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAccount.h"
#import "MSALAccountId+Internal.h"

@interface MSALAccount ()

@property (nonatomic) MSALAccountId *homeAccountId;
@property (nonatomic) NSString *username;
@property (nonatomic) NSString *environment;

@end

@implementation MSALAccount

- (id)initWithUsername:(NSString *)username
                  name:(NSString *)name
         homeAccountId:(NSString *)homeAccountId
        localAccountId:(NSString *)localAccountId
           environment:(NSString *)environment
              tenantId:(NSString *)tenantId
            clientInfo:(MSIDClientInfo *)clientInfo
{
    self = [super init];

    if (self)
    {
        _username = username;
        _name = name;
        _environment = environment;

        NSString *uid = clientInfo.uid;
        NSString *utid = clientInfo.utid;

        if (!uid && !utid)
        {
            NSArray *accountIdComponents = [homeAccountId componentsSeparatedByString:@"."];

            if ([accountIdComponents count] == 2)
            {
                uid = accountIdComponents[0];
                utid = accountIdComponents[1];
            }
        }

        _homeAccountId = [[MSALAccountId alloc] initWithHomeAccountIdentifier:homeAccountId
                                                                          uid:uid
                                                                         utid:utid];

        _localAccountId = [[MSALAccountId alloc] initWithLocalAccountIdentifier:localAccountId
                                                                       objectId:localAccountId
                                                                       tenantId:tenantId];

        _lookupAccountIdentifier = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:username homeAccountId:homeAccountId];
    }

    return self;
}

- (id)initWithMSIDAccount:(MSIDAccount *)account
{
    return [self initWithUsername:account.username
                                  name:account.name
                         homeAccountId:account.accountIdentifier.homeAccountId
                        localAccountId:account.localAccountId
                           environment:account.authority.msidHostWithPortIfNecessary
                              tenantId:account.authority.msidTenant
                            clientInfo:account.clientInfo];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSALAccount *account = [[MSALAccount allocWithZone:zone] init];
    account.username = [self.username copyWithZone:zone];
    account.name = [self.name copyWithZone:zone];
    account.homeAccountId = [self.homeAccountId copyWithZone:zone];
    account.localAccountId = [self.localAccountId copyWithZone:zone];
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

@end
