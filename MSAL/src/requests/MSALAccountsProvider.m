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

@interface MSALAccountsProvider()

@property (nullable, nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;
@property (nullable, nonatomic) MSALAuthority *authority;
@property (nullable, nonatomic) NSString *clientId;

@end

@implementation MSALAccountsProvider

#pragma mark - Init

- (instancetype)initWithTokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
                         authority:(MSALAuthority *)authority
                          clientId:(NSString *)clientId
{
    self = [super init];

    if (self)
    {
        _tokenCache = tokenCache;
        _authority = authority;
        _clientId = clientId;
    }

    return self;
}

#pragma mark - Accounts

- (void)loadAccountsWithCompletionBlock:(MSALAccountsCompletionBlock)completionBlock
{
    [self.authority.msidAuthority resolveAndValidate:NO
                                   userPrincipalName:nil
                                             context:nil
                                     completionBlock:^(NSURL * _Nullable openIdConfigurationEndpoint, BOOL validated, NSError * _Nullable error) {

                                         if (error)
                                         {
                                             completionBlock(nil, error);
                                             return;
                                         }

                                         NSError *accountsError = nil;
                                         NSArray *accounts = [self accounts:&accountsError];
                                         completionBlock(accounts, accountsError);
                                     }];
}

#pragma mark - Accounts sync

- (NSArray <MSALAccount *> *)accounts:(NSError * __autoreleasing *)error
{
    NSError *msidError = nil;
    __auto_type host = self.authority.msidAuthority.environment;
    __auto_type msidAccounts = [self.tokenCache allAccountsForEnvironment:host
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

- (MSALAccount *)accountForHomeAccountId:(NSString *)homeAccountId
                                   error:(NSError * __autoreleasing *)error
{
    NSArray<MSALAccount *> *accounts = [self accounts:error];

    for (MSALAccount *account in accounts)
    {
        if ([account.homeAccountId.identifier isEqualToString:homeAccountId])
        {
            return account;
        }
    }

    return nil;
}

- (MSALAccount *)accountForUsername:(NSString *)username
                              error:(NSError * __autoreleasing *)error
{
    NSArray<MSALAccount *> *accounts = [self accounts:error];

    for (MSALAccount *account in accounts)
    {
        if ([account.username isEqualToString:username])
        {
            return account;
        }
    }

    return nil;
}

@end
