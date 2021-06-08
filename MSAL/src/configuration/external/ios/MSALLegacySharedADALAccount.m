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

#import "MSALLegacySharedADALAccount.h"
#import "MSIDAADAuthority.h"
#import "MSIDJsonObject.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSIDAccountIdentifier.h"
#import "MSALAccountEnumerationParameters.h"
#import "MSALAADAuthority.h"

static NSString *kADALAccountType = @"ADAL";

@interface MSALLegacySharedADALAccount()

@property (nonatomic) MSIDAADAuthority *authority;
@property (nonatomic) NSString *objectId;
@property (nonatomic) NSString *tenantId;
@property (nonatomic, readwrite) NSString *environment;
@property (nonatomic, readwrite) NSString *identifier;
@property (nonatomic, readwrite) NSDictionary *accountClaims;

@end

@implementation MSALLegacySharedADALAccount

#pragma mark - Init

- (instancetype)initWithJSONDictionary:(NSDictionary *)jsonDictionary error:(NSError **)error
{
    self = [super initWithJSONDictionary:jsonDictionary error:error];
    
    if (self)
    {        
        if (![_accountType isEqualToString:kADALAccountType])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create ADAL account. Wrong account type %@ provided", _accountType);
            
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected account type", nil, nil, nil, nil, nil, NO);
            }
            
            return nil;
        }
        
        NSString *authEndpoint = [jsonDictionary msidStringObjectForKey:@"authEndpointUrl"];
        
        if (!authEndpoint)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to read AAD authority. Nil authority provided");
            
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected authority found", nil, nil, nil, nil, nil, NO);
            }
            
            return nil;
        }
        
        _authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:authEndpoint] rawTenant:nil context:nil error:error];
        
        if (!_authority)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create AAD authority. Wrong authority provided %@", authEndpoint);
            return nil;
        }
        
        _environment = [_authority cacheEnvironmentWithContext:nil];
        
        _objectId = [jsonDictionary msidStringObjectForKey:@"oid"];
        _tenantId = [jsonDictionary msidStringObjectForKey:@"tenantId"];
        
        if (_authority.tenant.type == MSIDAADTenantTypeCommon)
        {
            _identifier = [MSIDAccountIdentifier homeAccountIdentifierFromUid:_objectId utid:_tenantId];
        }
        else
        {
            NSDictionary *additionalPropertiesDictionary = [jsonDictionary msidObjectForKey:@"additionalProperties" ofClass:[NSDictionary class]];
            
            if (additionalPropertiesDictionary)
            {
                NSString *homeAccountId = [additionalPropertiesDictionary msidObjectForKey:@"home_account_id" ofClass:[NSString class]];
                
                if (![NSString msidIsStringNilOrBlank:homeAccountId])
                {
                    _identifier = homeAccountId;
                }
            }
        }
        
        NSMutableDictionary *claims = [NSMutableDictionary new];
        
        if (![NSString msidIsStringNilOrBlank:_objectId])
        {
            claims[@"oid"] = _objectId;
        }
        
        if (![NSString msidIsStringNilOrBlank:_tenantId])
        {
            claims[@"tid"] = _tenantId;
        }
        
        NSString *displayName = [jsonDictionary msidStringObjectForKey:@"displayName"];
        
        if (![NSString msidIsStringNilOrBlank:displayName])
        {
            claims[@"name"] = displayName;
        }
        
        _username = [jsonDictionary msidStringObjectForKey:@"username"];
        _accountClaims = claims;
        
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, nil, @"Created external ADAL account with identifier %@, object Id %@, tenant Id %@, name %@, username %@, claims %@", MSID_PII_LOG_TRACKABLE(_identifier), MSID_PII_LOG_TRACKABLE(_objectId), _tenantId, MSID_EUII_ONLY_LOG_MASKABLE(displayName), MSID_PII_LOG_EMAIL(_username), MSID_EUII_ONLY_LOG_MASKABLE(_accountClaims));
    }
    
    return self;
}

#pragma mark - Match

- (BOOL)matchesParameters:(MSALAccountEnumerationParameters *)parameters
{
    BOOL matchResult = YES;
    
    if (parameters.identifier)
    {
        matchResult &= (self.identifier && [self.identifier caseInsensitiveCompare:parameters.identifier] == NSOrderedSame);
    }
    
    if (parameters.username)
    {
        matchResult &= (self.username && [self.username caseInsensitiveCompare:parameters.username] == NSOrderedSame);
    }
    
    if (parameters.tenantProfileIdentifier)
    {
        matchResult &= (self.objectId && [self.objectId caseInsensitiveCompare:parameters.tenantProfileIdentifier] == NSOrderedSame);
    }
    
    return matchResult & [super matchesParameters:parameters];
}

#pragma mark - Updates

- (NSDictionary *)claimsFromMSALAccount:(id<MSALAccount>)account claims:(NSDictionary *)claims
{
    NSMutableDictionary *jsonDictionary = [NSMutableDictionary new];
    jsonDictionary[@"displayName"] = claims[@"name"];
    jsonDictionary[@"oid"] = claims[@"oid"];
    jsonDictionary[@"tenantId"] = claims[@"tid"];
    jsonDictionary[@"username"] = account.username;
    jsonDictionary[@"type"] = @"ADAL";
    
    MSIDAccountIdentifier *accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:account.identifier];
    BOOL isHomeTenant = [accountIdentifier.utid isEqualToString:claims[@"tid"]];
    
    MSALAADAuthority *aadAuthority = [[MSALAADAuthority alloc] initWithEnvironment:account.environment
                                                                      audienceType:isHomeTenant ? MSALAzureADAndPersonalMicrosoftAccountAudience : MSALAzureADMyOrgOnlyAudience
                                                                         rawTenant:isHomeTenant ? nil : claims[@"tid"]
                                                                             error:nil];
    jsonDictionary[@"authEndpointUrl"] = aadAuthority.url.absoluteString;
    return jsonDictionary;
}

@end
