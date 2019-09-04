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

#import "MSALLegacySharedAccount.h"
#import "MSIDJsonObject.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSALAccountEnumerationParameters.h"
#import <MSAL/MSAL.h>

@interface MSALLegacySharedAccount()

@property (nonatomic, readwrite) NSDictionary *jsonDictionary;
@property (nonatomic, readwrite) NSString *username;

@end

static NSDateFormatter *s_updateDateFormatter = nil;

@implementation MSALLegacySharedAccount

#pragma mark - Init

- (instancetype)initWithJSONDictionary:(NSDictionary *)jsonDictionary error:(NSError **)error
{
    self = [super init];
    
    if (self)
    {
        _jsonDictionary = jsonDictionary;
        _accountType = [jsonDictionary msidStringObjectForKey:@"type"];
        _accountIdentifier = [jsonDictionary msidStringObjectForKey:@"id"];
        
        if ([NSString msidIsStringNilOrBlank:_accountType]
            || [NSString msidIsStringNilOrBlank:_accountIdentifier])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Missing account type or identifier (account type = %@, account identifier = %@)", _accountType, _accountIdentifier);
            
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected shared account found without type or identifier", nil, nil, nil, nil, nil);
            }
            
            return nil;
        }
        
        _signinStatusDictionary = [jsonDictionary msidObjectForKey:@"signInStatus" ofClass:[NSDictionary class]];
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Created sign in status dictionary %@", MSID_PII_LOG_MASKABLE(_signinStatusDictionary));
    }
    
    return self;
}

- (instancetype)initWithMSALAccount:(id<MSALAccount>)account
                      accountClaims:(NSDictionary *)claims
                    applicationName:(NSString *)appName
                     accountVersion:(MSALLegacySharedAccountVersion)accountVersion
                              error:(NSError **)error
{
    if (accountVersion == MSALLegacySharedAccountVersionV1)
    {
        return nil;
    }
    
    if (!account)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected parameter - no account", nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    NSString *appBundleId = [[NSBundle mainBundle] bundleIdentifier];
    
    NSMutableDictionary *jsonDictionary = [NSMutableDictionary new];
    jsonDictionary[@"id"] = [[NSUUID UUID] UUIDString];
    jsonDictionary[@"environment"] = @"PROD";
    
    if (accountVersion == MSALLegacySharedAccountVersionV3)
    {
        jsonDictionary[@"originAppId"] = appBundleId;
    }
    
    jsonDictionary[@"signInStatus"] = @{appBundleId : @"SignedIn"};
    jsonDictionary[@"username"] = account.username;
    jsonDictionary[@"additionalProperties"] = @{@"createdBy": appName};
    [jsonDictionary addEntriesFromDictionary:[self claimsFromMSALAccount:account claims:claims]];
    return [self initWithJSONDictionary:jsonDictionary error:error];
}

#pragma mark - Match

- (BOOL)matchesParameters:(MSALAccountEnumerationParameters *)parameters
{
    if (parameters.returnOnlySignedInAccounts)
    {
        NSString *appIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        NSString *signinStatus = [self.signinStatusDictionary msidStringObjectForKey:appIdentifier];
        
        return [signinStatus isEqualToString:@"SignedIn"];
    }
    else if (![self.signinStatusDictionary count])
    {
        return YES;
    }
    
    // Don't return accounts that are signed out from everywhere
    for (NSString *app in self.signinStatusDictionary)
    {
        if ([self.signinStatusDictionary[app] isEqualToString:@"SignedIn"]) return YES;
    }
    
    return NO;
}

#pragma mark - Update

- (BOOL)updateAccountWithMSALAccount:(id<MSALAccount>)account
                     applicationName:(NSString *)appName
                           operation:(MSALLegacySharedAccountWriteOperation)operation
                      accountVersion:(MSALLegacySharedAccountVersion)accountVersion
                               error:(NSError **)error
{
    if (accountVersion == MSALLegacySharedAccountVersionV1)
    {
        return YES;
    }
    
    NSMutableDictionary *oldDictionary = [self.jsonDictionary mutableCopy];
    NSString *appIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    
    if (appIdentifier)
    {
        NSMutableDictionary *signinDictionary = [NSMutableDictionary new];
        [signinDictionary addEntriesFromDictionary:self.signinStatusDictionary];
        
        NSString *signinState = nil;
        
        switch (operation) {
            case MSALLegacySharedAccountRemoveOperation:
                signinState = @"SignedOut";
                break;
            case MSALLegacySharedAccountUpdateOperation:
                signinState = @"SignedIn";
                break;
                
            default:
                return NO;
        }
        
        signinDictionary[appIdentifier] = signinState;
        oldDictionary[@"signInStatus"] = signinDictionary;
    }
    
    NSDictionary *additionalAccountInfo = [self.jsonDictionary msidObjectForKey:@"additionalProperties" ofClass:[NSDictionary class]];
    NSMutableDictionary *mutableAdditionalInfo = [NSMutableDictionary new];
    [mutableAdditionalInfo addEntriesFromDictionary:additionalAccountInfo];
    
    mutableAdditionalInfo[@"updatedBy"] = appName;
    mutableAdditionalInfo[@"updatedAt"] = [[[self class] dateFormatter] stringFromDate:[NSDate date]];
    
    oldDictionary[@"additionalProperties"] = mutableAdditionalInfo;
    
    if (account.username)
    {
        self.username = account.username;
        oldDictionary[@"username"] = self.username;
    }
    
    self.jsonDictionary = oldDictionary;
    return YES;
}

- (NSDictionary *)claimsFromMSALAccount:(id<MSALAccount>)account claims:(NSDictionary *)claims
{
    return nil;
}

#pragma mark - Helpers

+ (NSDateFormatter *)dateFormatter
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_updateDateFormatter = [NSDateFormatter new];
        [s_updateDateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    });
    
    return s_updateDateFormatter;
}

@end
