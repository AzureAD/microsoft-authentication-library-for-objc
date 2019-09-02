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

#import "MSALLegacySharedMSAAccount.h"
#import "MSIDJsonObject.h"
#import "MSIDAADAuthority.h"
#import "MSIDConstants.h"
#import "MSIDAccountIdentifier.h"
#import "NSString+MSALAccountIdenfiers.h"
#import "MSALAccountEnumerationParameters.h"

static NSString *kMSAAccountType = @"MSA";

@interface MSALLegacySharedMSAAccount()

@property (nonatomic) MSIDAADAuthority *authority;
@property (nonatomic, readwrite) NSString *environment;
@property (nonatomic, readwrite) NSString *identifier;
@property (nonatomic, readwrite) NSDictionary *accountClaims;

@end

static NSString *kDefaultCacheAuthority = @"https://login.windows.net/common";

@implementation MSALLegacySharedMSAAccount

#pragma mark - Init

- (instancetype)initWithJSONDictionary:(NSDictionary *)jsonDictionary error:(NSError **)error
{
    self = [super initWithJSONDictionary:jsonDictionary error:error];
    
    if (self)
    {
        if (![_accountType isEqualToString:kMSAAccountType])
        {
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected account type", nil, nil, nil, nil, nil);
            }
            
            return nil;
        }
        
        _authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:kDefaultCacheAuthority] rawTenant:nil context:nil error:error];

        _environment = [_authority cacheEnvironmentWithContext:nil];
        // cid == hash of PUID (Live account ID)
        NSString *cid = [jsonDictionary msidStringObjectForKey:@"cid"];
        NSString *uid = [cid msalStringAsGUID];
        
        if ([NSString msidIsStringNilOrBlank:uid])
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Unable to read cid from MSA account, cid %@", cid);
            
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected identifier found for MSA account", nil, nil, nil, nil, nil);
            }
            
            return nil;
        }
        
        _identifier = [MSIDAccountIdentifier homeAccountIdentifierFromUid:uid utid:MSID_DEFAULT_MSA_TENANTID];
        _username = [jsonDictionary msidStringObjectForKey:@"email"];
        
        _accountClaims = @{@"tid": MSID_DEFAULT_MSA_TENANTID,
                           @"oid": uid};
        
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Created external MSA account with identifier %@, object Id %@, tenant Id %@, username %@, claims %@", MSID_PII_LOG_TRACKABLE(_identifier), MSID_PII_LOG_MASKABLE(cid), MSID_DEFAULT_MSA_TENANTID, MSID_PII_LOG_EMAIL(_username), MSID_PII_LOG_MASKABLE(_accountClaims));
    }
    
    return self;
}

- (instancetype)initWithMSALAccount:(id<MSALAccount>)account
                      accountClaims:(NSDictionary *)claims
                    applicationName:(NSString *)appName
                     accountVersion:(MSALLegacySharedAccountVersion)accountVersion
                              error:(NSError **)error
{
    return nil; // Creating new MSA accounts isn't supported currently and will be added at a later point
}

#pragma mark - Match

- (BOOL)matchesParameters:(MSALAccountEnumerationParameters *)parameters
{
    BOOL matchResult = YES;
    
    if (parameters.identifier)
    {
        matchResult &= ([self.identifier caseInsensitiveCompare:parameters.identifier] == NSOrderedSame);
    }
    
    if (parameters.username)
    {
        matchResult &= ([self.username caseInsensitiveCompare:parameters.username] == NSOrderedSame);
    }
    
    if (parameters.tenantProfileIdentifier)
    {
        return NO;
    }
    
    return matchResult &= [super matchesParameters:parameters];
}

#pragma mark - Updates

- (NSDictionary *)claimsFromMSALAccount:(id<MSALAccount>)account claims:(NSDictionary *)claims
{
    NSMutableDictionary *jsonDictionary = [NSMutableDictionary new];
    jsonDictionary[@"displayName"] = claims[@"name"] ? claims[@"name"] : account.username;
    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:account.identifier];
    jsonDictionary[@"cid"] = [accountIdentifier.uid msalGUIDAsShortString];
    jsonDictionary[@"email"] = account.username;
    jsonDictionary[@"type"] = @"MSA";
    return jsonDictionary;
}

@end
