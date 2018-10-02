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

#import "MSALAccountsProvider.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSALAuthority.h"
#import "MSALAuthority_Internal.h"
#import "MSIDAuthority.h"
#import "MSALAccount+Internal.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDAccount.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDConfiguration.h"

@interface MSALAccountsProvider()

@property (nullable, nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;
@property (nullable, nonatomic) NSString *clientId;

@end

@implementation MSALAccountsProvider

#pragma mark - Init

- (instancetype)initWithTokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
                          clientId:(NSString *)clientId
{
    self = [super init];

    if (self)
    {
        _tokenCache = tokenCache;
        _clientId = clientId;
    }

    return self;
}

#pragma mark - Accounts

- (void)allAccountsFilteredByAuthority:(MSALAuthority *)authority
                       completionBlock:(MSALAccountsCompletionBlock)completionBlock;
{
    [authority.msidAuthority resolveAndValidate:NO
                              userPrincipalName:nil
                                        context:nil
                                completionBlock:^(NSURL * _Nullable openIdConfigurationEndpoint, BOOL validated, NSError * _Nullable error) {
                                    
                                    if (error)
                                    {
                                        completionBlock(nil, error);
                                        return;
                                    }
                                    
                                    NSError *accountsError = nil;
                                    NSArray *accounts = [self allAccountsForAuthority:authority.msidAuthority error:&accountsError];
                                    completionBlock(accounts, accountsError);
                                }];
}

#pragma mark - Accounts sync

- (NSArray <MSALAccount *> *)allAccounts:(NSError * __autoreleasing *)error
{
    return [self allAccountsForAuthority:nil error:error];
}

- (MSALAccount *)accountForHomeAccountId:(NSString *)homeAccountId
                                   error:(NSError * __autoreleasing *)error
{
    NSError *msidError = nil;

    __auto_type msidAccounts = [self.tokenCache allAccountsForAuthority:nil
                                                               clientId:self.clientId
                                                               familyId:nil
                                                                context:nil
                                                                  error:&msidError];
    
    if (msidError)
    {
        *error = msidError;
        return nil;
    }
    
    for (MSIDAccount *msidAccount in msidAccounts)
    {
        if ([msidAccount.accountIdentifier.homeAccountId isEqualToString:homeAccountId])
        {
            return [[MSALAccount alloc] initWithMSIDAccount:msidAccount];
        }
    }

    return nil;
}

- (MSALAccount *)accountForUsername:(NSString *)username
                              error:(NSError * __autoreleasing *)error
{
    NSError *msidError = nil;

    __auto_type msidAccounts = [self.tokenCache allAccountsForAuthority:nil
                                                               clientId:self.clientId
                                                               familyId:nil
                                                                context:nil
                                                                  error:&msidError];
    
    if (msidError)
    {
        *error = msidError;
        return nil;
    }
    
    for (MSIDAccount *msidAccount in msidAccounts)
    {
        if ([msidAccount.username isEqualToString:username])
        {
            return [[MSALAccount alloc] initWithMSIDAccount:msidAccount];
        }
    }
    
    return nil;
}

#pragma mark - Private

- (NSArray <MSALAccount *> *)allAccountsForAuthority:(MSIDAuthority *)authority
                                               error:(NSError * __autoreleasing *)error
{
    NSError *msidError = nil;

    __auto_type msidAccounts = [self.tokenCache allAccountsForAuthority:authority
                                                               clientId:self.clientId
                                                               familyId:nil
                                                                context:nil
                                                                  error:&msidError];
    
    if (msidError)
    {
        *error = msidError;
        return nil;
    }
    
    NSMutableSet *msalAccounts = [NSMutableSet new];
    
    for (MSIDAccount *msidAccount in msidAccounts)
    {
        MSALAccount *msalAccount = [[MSALAccount alloc] initWithMSIDAccount:msidAccount];
        
        if (msalAccount)
        {
            [msalAccounts addObject:msalAccount];
        }
    }
    
    return [msalAccounts allObjects];
}

@end
