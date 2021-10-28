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

#import "MSALResult.h"
#import "MSIDAccessToken.h"
#import "NSString+MSIDExtensions.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDAADV2IdTokenClaims.h"
#import "MSALAccount+Internal.h"
#import "MSIDIdToken.h"
#import "MSALAuthority.h"
#import "MSIDAuthority.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTokenResult.h"
#import "MSIDAccount.h"
#import "MSIDAADV2IdTokenClaims.h"
#import "MSALAccountsProvider.h"
#import "MSALTenantProfile.h"
#import "MSALTenantProfile+Internal.h"
#import "MSIDDevicePopManager.h"
#import "MSALAuthenticationSchemeProtocol.h"
#import "MSALAuthenticationSchemeProtocolInternal.h"

@interface MSALResult()

@property (atomic) id<MSALAuthenticationSchemeProtocol, MSALAuthenticationSchemeProtocolInternal> authScheme;

@end

@implementation MSALResult

- (NSString *)authorizationHeader
{
    if ([NSString msidIsStringNilOrBlank:self.accessToken])
    {
        return @"";
    }
    
    return [self.authScheme getAuthorizationHeader:self.accessToken];
}

- (NSString *)authenticationScheme
{
    return self.authScheme.authenticationScheme;
}

@end

@implementation MSALResult (Internal)

+ (MSALResult *)resultWithAccessToken:(NSString *)accessToken
                            expiresOn:(NSDate *)expiresOn
              isExtendedLifetimeToken:(BOOL)isExtendedLifetimeToken
                             tenantId:(NSString *)tenantId
                        tenantProfile:(MSALTenantProfile *)tenantProfile
                              account:(MSALAccount *)account
                              idToken:(NSString *)idToken
                             uniqueId:(NSString *)uniqueId
                               scopes:(NSArray<NSString *> *)scopes
                            authority:(MSALAuthority *)authority
                        correlationId:(NSUUID *)correlationId
                           authScheme:(id<MSALAuthenticationSchemeProtocol, MSALAuthenticationSchemeProtocolInternal>)authScheme
{
    MSALResult *result = [MSALResult new];
    result->_accessToken = accessToken;
    result->_expiresOn = expiresOn;
    result->_extendedLifeTimeToken = isExtendedLifetimeToken;
    result->_tenantId = tenantId;
    result->_tenantProfile = tenantProfile;
    result->_account = account;
    result->_idToken = idToken;
    result->_uniqueId = uniqueId;
    result->_scopes = scopes;
    result->_authority = authority;
    result->_correlationId = correlationId;
    result->_authScheme = authScheme;
    return result;
}

+ (MSALResult *)resultWithMSIDTokenResult:(MSIDTokenResult *)tokenResult
                                authority:(MSALAuthority *)authority
                               authScheme:(id<MSALAuthenticationSchemeProtocol, MSALAuthenticationSchemeProtocolInternal>)authScheme
                               popManager:(MSIDDevicePopManager *)popManager
                                    error:(NSError **)error
{
    if (!tokenResult)
    {
        MSIDFillAndLogError(error, MSIDErrorInternal, @"Nil token result provided", nil);
        return nil;
    }
    
    MSIDIdTokenClaims *claims = [[MSIDIdTokenClaims alloc] initWithRawIdToken:tokenResult.rawIdToken error:error];
    
    if (!claims)
    {
        return nil;
    }
    
    if (!authority)
    {
        MSIDFillAndLogError(error, MSIDErrorInternal, @"Nil authority in the result provided", nil);
        return nil;
    }
    
    MSALTenantProfile *tenantProfile = [[MSALTenantProfile alloc] initWithIdentifier:tokenResult.account.localAccountId
                                                                            tenantId:tokenResult.account.realm
                                                                         environment:tokenResult.account.environment
                                                                 isHomeTenantProfile:tokenResult.account.isHomeTenantAccount
                                                                              claims:claims.jsonDictionary];
    
    MSALAccount *account = [[MSALAccount alloc] initWithMSIDAccount:tokenResult.account createTenantProfile:NO];
    
    if (tokenResult.account.isHomeTenantAccount)
    {
        account.accountClaims = claims.jsonDictionary;
    }
    
    NSString *resultAccessToken = @"";
    NSArray *resultScopes = @[];
    
    if (![NSString msidIsStringNilOrBlank:tokenResult.accessToken.accessToken])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Parsing result access token");
        resultAccessToken = [authScheme getClientAccessToken:tokenResult.accessToken popManager:popManager error:error];
        resultScopes = [tokenResult.accessToken.scopes array];
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Access token missing in token result. Continuing without it");
    }
        
    return [self resultWithAccessToken:resultAccessToken
                             expiresOn:tokenResult.accessToken.expiresOn
               isExtendedLifetimeToken:tokenResult.extendedLifeTimeToken
                              tenantId:tenantProfile.tenantId
                         tenantProfile:tenantProfile
                               account:account
                               idToken:tokenResult.rawIdToken
                              uniqueId:tenantProfile.identifier
                                scopes:resultScopes
                             authority:authority
                         correlationId:tokenResult.correlationId
                            authScheme:authScheme];
}

@end
