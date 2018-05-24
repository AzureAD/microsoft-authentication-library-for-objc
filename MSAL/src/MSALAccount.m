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

@interface MSALAccount ()

@property (nonatomic) NSString *homeAccountId;
@property (nonatomic) NSString *displayableId;
@property (nonatomic) NSString *environment;

@end

@implementation MSALAccount

- (id)initWithDisplayableId:(NSString *)displayableId
                       name:(NSString *)name
              homeAccountId:(NSString *)homeAccountId
             localAccountId:(NSString *)localAccountId
                environment:(NSString *)environment
                   tenantId:(NSString *)tenantId
{
    self = [super init];

    if (self)
    {
        _displayableId = [displayableId copy];
        _name = [name copy];
        _homeAccountId = [_homeAccountId copy];
        _localAccountId = [_localAccountId copy];
        _environment = [_environment copy];
        _tenantId = [_tenantId copy];
        _lookupAccountIdentifier = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:displayableId homeAccountId:_homeAccountId];
    }

    return self;
}

- (id)initWithMSIDAccount:(MSIDAccount *)account
{
    self = [self initWithDisplayableId:account.username
                                  name:account.name
                         homeAccountId:account.homeAccountId
                        localAccountId:account.localAccountId
                           environment:account.authority.msidHostWithPortIfNecessary
                              tenantId:account.authority.msidTenant];

    if (self)
    {
        _uid = account.clientInfo.uid;
        _utid = account.clientInfo.utid;

        if (!account.clientInfo)
        {
            NSArray *accountIdComponents = [account.homeAccountId componentsSeparatedByString:@"."];

            if ([accountIdComponents count] == 2)
            {
                _uid = accountIdComponents[0];
                _utid = accountIdComponents[1];
            }
        }
    }

    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSALAccount *account = [[MSALAccount allocWithZone:zone] init];
    account.displayableId = [self.displayableId copyWithZone:zone];
    account.name = [self.name copyWithZone:zone];
    account.homeAccountId = [self.homeAccountId copyWithZone:zone];
    account.localAccountId = [self.localAccountId copyWithZone:zone];
    account.environment = [self.environment copyWithZone:zone];
    account.tenantId = [self.tenantId copyWithZone:zone];
    account.uid = [self.uid copyWithZone:zone];
    account.utid = [self.utid copyWithZone:zone];
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

- (NSUInteger)hash
{
    NSUInteger hash = 0;
    hash = hash * 31 + self.displayableId.hash;
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
    result &= (!self.displayableId && !user.displayableId) || [self.displayableId isEqualToString:user.displayableId];
    result &= (!self.name && !user.name) || [self.name isEqualToString:user.name];
    result &= (!self.homeAccountId && !user.homeAccountId) || [self.homeAccountId isEqualToString:user.homeAccountId];
    result &= (!self.localAccountId && !user.localAccountId) || [self.localAccountId isEqualToString:user.localAccountId];
    result &= (!self.environment && !user.environment) || [self.environment isEqualToString:user.environment];
    result &= (!self.tenantId && !user.tenantId) || [self.tenantId isEqualToString:user.tenantId];
    result &= (!self.uid && !user.uid) || [self.uid isEqualToString:user.uid];
    result &= (!self.utid && !user.utid) || [self.utid isEqualToString:user.utid];
    
    return result;
}

@end
