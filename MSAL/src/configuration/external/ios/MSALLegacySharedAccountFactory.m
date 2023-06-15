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

#import "MSALLegacySharedAccountFactory.h"
#import "MSIDJsonObject.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSALLegacySharedADALAccount.h"
#import "MSALLegacySharedMSAAccount.h"
#import "MSIDConstants.h"
#import "MSIDAccountIdentifier.h"
#import "MSALAccountEnumerationParameters.h"

@implementation MSALLegacySharedAccountFactory

+ (MSALLegacySharedAccount *)accountWithJSONDictionary:(NSDictionary *)jsonDictionary error:(NSError **)error
{
    NSString *accountType = [jsonDictionary msidStringObjectForKey:@"type"];
    
    if ([accountType isEqualToString:@"ADAL"])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"Initializing ADAL account type");
        return [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:error];
    }
    else if ([accountType isEqualToString:@"MSA"])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"Initializing MSA account type");
        return [[MSALLegacySharedMSAAccount alloc] initWithJSONDictionary:jsonDictionary error:error];
    }
    
    if (error)
    {
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected account type found", nil, nil, nil, nil, nil, NO);
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"Unknown account type found %@", accountType);
    return nil;
}

+ (nullable MSALLegacySharedAccount *)accountWithMSALAccount:(nonnull id<MSALAccount>)account
                                                      claims:(nonnull NSDictionary *)claims
                                             applicationName:(nonnull NSString *)applicationName
                                              accountVersion:(MSALLegacySharedAccountVersion)accountVersion
                                                       error:(NSError * _Nullable * _Nullable )error
{
    if ([self isMSAAccount:account])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"Initializing MSA account type");
        return [[MSALLegacySharedMSAAccount alloc] initWithMSALAccount:account
                                                         accountClaims:claims
                                                       applicationName:applicationName
                                                        accountVersion:accountVersion
                                                                 error:error];
    }
    else if (![NSString msidIsStringNilOrBlank:claims[@"oid"]])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"Initializing AAD account type");
        return [[MSALLegacySharedADALAccount alloc] initWithMSALAccount:account
                                                          accountClaims:claims
                                                        applicationName:applicationName
                                                         accountVersion:accountVersion
                                                                  error:error];
    }
    
    return nil;
}

+ (MSALAccountEnumerationParameters *)parametersForAccount:(nonnull id<MSALAccount>)account
                                   tenantProfileIdentifier:(nullable NSString *)tenantProfileIdentifier
{
    if ([self isMSAAccount:account])
    {
        MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:account.identifier];
        parameters.returnOnlySignedInAccounts = NO;
        return parameters;
    }
    else if (![NSString msidIsStringNilOrBlank:tenantProfileIdentifier])
    {
        MSALAccountEnumerationParameters *parameters =  [[MSALAccountEnumerationParameters alloc] initWithTenantProfileIdentifier:tenantProfileIdentifier];
        parameters.returnOnlySignedInAccounts = NO;
        return parameters;
    }
    
    return nil;
}

+ (BOOL)isMSAAccount:(id<MSALAccount>)account
{
    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:account.identifier];
    
    if (accountIdentifier.utid && [accountIdentifier.utid isEqualToString:MSID_DEFAULT_MSA_TENANTID])
    {
        return YES;
    }
    
    return NO;
}

@end
