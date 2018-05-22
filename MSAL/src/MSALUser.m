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

#import "MSALUser.h"
#import "MSIDClientInfo.h"
#import "MSIDAccount.h"
#import "MSALUser+Internal.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDAuthority.h"
#import "MSIDAADV2IdTokenClaims.h"
#import "MSIDAccountIdentifier.h"

@interface MSALUser ()

@property (nonatomic) NSString *userIdentifier;
@property (nonatomic) NSString *displayableId;
@property (nonatomic) NSString *name;
@property (nonatomic) NSString *identityProvider;
@property (nonatomic) NSString *environment;
@property (nonatomic) MSIDClientInfo *clientInfo;
@property (nonatomic) NSString *uid;
@property (nonatomic) NSString *utid;

@end

@implementation MSALUser

- (id)initWithIdToken:(MSIDAADV2IdTokenClaims *)idToken
           clientInfo:(MSIDClientInfo *)clientInfo
          environment:(NSString *)environment
{
    self = [self initWithDisplayableId:idToken.preferredUsername name:idToken.name identityProvider:idToken.issuer uid:clientInfo.uid utid:clientInfo.utid environment:environment];
    
    if (self)
    {
        _clientInfo = clientInfo;
    }
    
    return self;
}

- (id)initWithDisplayableId:(NSString *)displayableId
                       name:(NSString *)name
           identityProvider:(NSString *)identityProvider
                        uid:(NSString *)uid
                       utid:(NSString *)utid
                environment:(NSString *)environment
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _displayableId = [displayableId copy];
    _name = [name copy];
    _identityProvider = [identityProvider copy];
    _uid = [uid copy];
    _utid = [utid copy];
    _environment = [environment copy];
    _account = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:displayableId homeAccountId:self.userIdentifier];
    
    return self;
}

- (NSString *)userIdentifier
{
    return [NSString stringWithFormat:@"%@.%@", self.uid, self.utid];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSALUser *user = [[MSALUser allocWithZone:zone] init];

    user.displayableId = [self.displayableId copyWithZone:zone];
    user.name = [self.name copyWithZone:zone];
    user.identityProvider = [self.identityProvider copyWithZone:zone];
    user.environment = [self.environment copyWithZone:zone];
    user.uid = [self.uid copyWithZone:zone];
    user.utid = [self.utid copyWithZone:zone];
    
    return user;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:MSALUser.class])
    {
        return NO;
    }
    
    return [self isEqualToUser:(MSALUser *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = 0;
    hash = hash * 31 + self.userIdentifier.hash;
    hash = hash * 31 + self.displayableId.hash;
    hash = hash * 31 + self.name.hash;
    hash = hash * 31 + self.identityProvider.hash;
    hash = hash * 31 + self.environment.hash;
    hash = hash * 31 + self.uid.hash;
    hash = hash * 31 + self.utid.hash;
    return hash;
}

- (BOOL)isEqualToUser:(MSALUser *)user
{
    if (!user) return NO;
    
    BOOL result = YES;
    result &= (!self.userIdentifier && !user.userIdentifier) || [self.userIdentifier isEqualToString:user.userIdentifier];
    result &= (!self.displayableId && !user.displayableId) || [self.displayableId isEqualToString:user.displayableId];
    result &= (!self.name && !user.name) || [self.name isEqualToString:user.name];
    result &= (!self.identityProvider && !user.identityProvider) || [self.identityProvider isEqualToString:user.identityProvider];
    result &= (!self.environment && !user.environment) || [self.environment isEqualToString:user.environment];
    result &= (!self.uid && !user.uid) || [self.uid isEqualToString:user.uid];
    result &= (!self.utid && !user.utid) || [self.utid isEqualToString:user.utid];
    
    return result;
}

@end
