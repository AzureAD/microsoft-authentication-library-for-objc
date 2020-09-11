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
#import "MSALResult.h"
#import "MSALAccount+MultiTenantAccount.h"
#import "MSALOauth2Provider.h"
#import "MSALAccount+Internal.h"
#import "MSALErrorConverter.h"
#import "MSALResult.h"
#import "MSALTenantProfile.h"

@interface MSALExternalAccountHandler()

@property (nonatomic, nonnull, readwrite) NSArray<id<MSALExternalAccountProviding>> *externalAccountProviders;
@property (nonatomic, nonnull, readwrite) MSALOauth2Provider *oauth2Provider;

@end

@implementation MSALExternalAccountHandler

#pragma mark - Init

- (instancetype)initWithExternalAccountProviders:(NSArray<id<MSALExternalAccountProviding>> *)externalAccountProviders
                                  oauth2Provider:(MSALOauth2Provider *)oauth2Provider
                                           error:(NSError **)error
{
    if (![externalAccountProviders count])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"No external account providers found");
        return nil;
    }
    
    if (!oauth2Provider)
    {
        [self fillAndLogParameterError:error parameterName:@"oauth2Provider"];
        return nil;
    }
    
    self = [super init];
    
    if (self)
    {
        _externalAccountProviders = externalAccountProviders;
        _oauth2Provider = oauth2Provider;
    }
    
    return self;
}

#pragma mark - Accounts

- (BOOL)removeAccount:(MSALAccount *)account wipeAccount:(BOOL)wipeAccount error:(NSError **)error
{
    if (!account)
    {
        [self fillAndLogParameterError:error parameterName:@"account"];
        return NO;
    }
    
    for (id<MSALExternalAccountProviding> provider in self.externalAccountProviders)
    {
        NSError *removalError = nil;
        BOOL result = [provider removeAccount:account wipeAccount:wipeAccount tenantProfiles:account.tenantProfiles error:&removalError];
        
        if (!result)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"Failed to remove external account with error %@", MSID_PII_LOG_MASKABLE(removalError));
            
            if (error)
            {
                *error = [MSALErrorConverter msalErrorFromMsidError:removalError];
            }
            
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)updateWithResult:(MSALResult *)result error:(NSError **)error
{
    if (!result)
    {
        [self fillAndLogParameterError:error parameterName:@"result"];
        return NO;
    }
    
    NSError *updateError = nil;
    MSALAccount *copiedAccount = [result.account copy];
    
    for (id<MSALExternalAccountProviding> provider in self.externalAccountProviders)
    {
        BOOL updateResult = [provider updateAccount:copiedAccount idTokenClaims:result.tenantProfile.claims error:&updateError];
        
        if (!updateResult)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil,  @"Failed to update account with error %@", MSID_PII_LOG_MASKABLE(updateError));
            
            if (error)
            {
                *error = [MSALErrorConverter msalErrorFromMsidError:updateError];
            }
            
            return NO;
        }
    }
    
    return YES;
}

- (NSArray<MSALAccount *> *)allExternalAccountsWithParameters:(MSALAccountEnumerationParameters *)parameters error:(NSError **)error
{
    NSMutableArray *allExternalAccounts = [NSMutableArray new];
    
    for (id<MSALExternalAccountProviding> provider in self.externalAccountProviders)
    {
        NSError *externalError = nil;
        NSArray *externalAccounts = [provider accountsWithParameters:parameters error:&externalError];
        
        if (externalError)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"Failed to read external accounts with parameters %@ with error %@", MSID_PII_LOG_MASKABLE(parameters), MSID_PII_LOG_MASKABLE(externalError));
            
            if (error) *error = [MSALErrorConverter msalErrorFromMsidError:externalError];
            return nil;
        }
        
        for (id<MSALAccount> externalAccount in externalAccounts)
        {
            MSALAccount *msalAccount = [[MSALAccount alloc] initWithMSALExternalAccount:externalAccount oauth2Provider:self.oauth2Provider];
            
            if (msalAccount)
            {
                [allExternalAccounts addObject:msalAccount];
            }
        }
    }
    
    return allExternalAccounts;
}

#pragma mark - Helpers

- (BOOL)fillAndLogParameterError:(NSError **)error parameterName:(NSString *)parameterName
{
    NSString *errorMessage = [NSString stringWithFormat:@"Parameter missing: %@", parameterName];
    MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", errorMessage);
    
    if (error)
    {
        NSError *msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorMessage, nil, nil, nil, nil, nil, NO);
        NSError *msalError = [MSALErrorConverter msalErrorFromMsidError:msidError];
        *error = msalError;
    }
    
    return YES;
}

@end
