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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSALExternalAccountHandler.h"
#import "MSALExternalAccountProviding.h"
#import "MSALTenantProfile.h"
#import "MSALAccount.h"
#import "MSALAADAuthority.h"
#import "MSALExternalAccountImpl.h"
#import "MSALResult.h"
#import "MSALAccount+MultiTenantAccount.h"

@interface MSALExternalAccountHandler()

@property (nonatomic, nonnull, readwrite) id<MSALExternalAccountProviding> externalAccountProvider;

@end

@implementation MSALExternalAccountHandler

#pragma mark - Init

- (instancetype)initWithExternalAccountProvider:(id<MSALExternalAccountProviding>)externalAccountProvider
{
    self = [super init];
    
    if (self)
    {
        _externalAccountProvider = externalAccountProvider;
    }
    
    return self;
}

#pragma mark - Accounts

- (BOOL)removeAccountFromExternalProvider:(MSALAccount *)account error:(NSError **)error
{
    if (!self.externalAccountProvider)
    {
        return YES;
    }
    
    for (MSALTenantProfile *tenantProfile in account.tenantProfiles)
    {
        MSALExternalAccountImpl *externalAADAccount = [[MSALExternalAccountImpl alloc] initWithAccount:account tenantProfile:tenantProfile];
        
        NSError *removalError = nil;
        
        BOOL result = [self.externalAccountProvider removeAccount:externalAADAccount error:&removalError];
        
        if (!result)
        {
            MSID_LOG_WARN(nil, @"Failed to remove external account with error %ld, %@", (long)removalError.code, removalError.domain);
            
            if (error)
            {
                *error = removalError;
            }
            
            return NO;
        }
    }
    
    return YES;
}

- (void)updateExternalAccountProviderWithResult:(MSALResult *)result
{
    if (self.externalAccountProvider && [result.authority isKindOfClass:[MSALAADAuthority class]])
    {
        MSALExternalAccountImpl *externalAADAccount = [[MSALExternalAccountImpl alloc] initWithAccount:result.account
                                                                                         tenantProfile:result.tenantProfile];
        
        NSError *updateError = nil;
        BOOL result = [self.externalAccountProvider updateAccount:externalAADAccount error:&updateError];
        
        if (!result)
        {
            MSID_LOG_WARN(nil, @"Failed to update account with error %ld, %@", (long)updateError.code, updateError.domain);
        }
    }
}

- (NSArray<id<MSALExternalAccount>> *)allExternalAccountsWithParameters:(MSALAccountEnumerationParameters *)parameters
{
    NSMutableArray *allExternalAccounts = [NSMutableArray new];
    
    if (self.externalAccountProvider)
    {
        NSError *externalError = nil;
        NSArray *externalAccounts = [self.externalAccountProvider accountsWithParameters:parameters error:&externalError];
        
        if (externalError)
        {
            // TODO: implement description method for MSALAccountEnumerationParameters
            MSID_LOG_WARN(nil, @"Failed to read external accounts for parameters %@, error %@/%ld", parameters, externalError.domain, (long)externalError.code);
            return nil;
        }
        
        [allExternalAccounts addObjectsFromArray:externalAccounts];
    }
    
    return allExternalAccounts;
}

@end
