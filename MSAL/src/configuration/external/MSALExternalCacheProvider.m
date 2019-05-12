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

#import "MSALExternalCacheProvider.h"
#import "MSALExternalCacheProvider+Internal.h"
#import "MSALErrorConverter.h"
#import "MSIDMacTokenCache.h"
#import "MSALAccount.h"
#import "MSALExternalAADAccount.h"
#import "MSALTenantProfile.h"
#import "MSALAADAuthority.h"
#import "MSALResult.h"

@interface MSALExternalCacheProvider()

@property (nonatomic, nullable, readwrite) id<MSALExternalAccountProviding> accountProvider;
@property (nonatomic, nullable, readwrite) MSALExternalSerializedCacheProvider *cacheProvider;

@end

@implementation MSALExternalCacheProvider

#pragma mark - Init

- (instancetype)initWithAccountProvider:(nullable id<MSALExternalAccountProviding>)accountProvider
                          cacheProvider:(nullable MSALExternalSerializedCacheProvider *)serializedCacheProvider
                                  error:(NSError **)error
{
    self = [super init];
    
    if (self)
    {
        _accountProvider = accountProvider;
        _serializedCacheProvider = serializedCacheProvider;
    }
    
    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSALExternalSerializedCacheProvider *copiedCacheProvider = [self.cacheProvider copyWithZone:zone];
    MSALExternalCacheProvider *copiedProvider = [[self.class alloc] initWithAccountProvider:self.accountProvider cacheProvider:copiedCacheProvider error:nil];
    return copiedProvider;
}

#pragma mark - Internal

- (BOOL)removeAccountFromExternalProvider:(MSALAccount *)account error:(NSError **)error
{
    if (!self.accountProvider)
    {
        return YES;
    }
    
    for (MSALTenantProfile *tenantProfile in account.tenantProfiles)
    {
        if ([tenantProfile.authority isKindOfClass:[MSALAADAuthority class]])
        {
            MSALExternalAADAccount *externalAADAccount = [[MSALExternalAADAccount alloc] initWithAccount:account tenantProfile:tenantProfile];
            
            NSError *removalError = nil;
            
            BOOL result = [self.accountProvider removeAccount:externalAADAccount error:&removalError];
            
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
    }
    
    return YES;
}

- (void)updateExternalAccountProviderWithResult:(MSALResult *)result
{
    if (self.accountProvider && [result.authority isKindOfClass:[MSALAADAuthority class]])
    {
        MSALExternalAADAccount *externalAADAccount = [[MSALExternalAADAccount alloc] initWithAccount:result.account
                                                                                       tenantProfile:result.tenantProfile];
        
        NSError *updateError = nil;
        BOOL result = [self.accountProvider updateAccount:externalAADAccount error:&updateError];
        
        if (!result)
        {
            MSID_LOG_WARN(nil, @"Failed to update account with error %ld, %@", (long)updateError.code, updateError.domain);
        }
    }
}

@end
