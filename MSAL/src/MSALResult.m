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
#import "MSIDClientInfo.h"
#import "MSIDAADV2IdTokenClaims.h"
#import "MSALAccount+Internal.h"
#import "MSIDIdToken.h"
#import "MSALAuthority.h"
#import "MSIDAuthority.h"
#import "MSIDAccountIdentifier.h"
#import "MSALAuthorityFactory.h"

@implementation MSALResult

@end

@implementation MSALResult (Internal)

+ (MSALResult *)resultWithAccessToken:(NSString *)accessToken
                            expiresOn:(NSDate *)expiresOn
              isExtendedLifetimeToken:(BOOL)isExtendedLifetimeToken
                             tenantId:(NSString *)tenantId
                              account:(MSALAccount *)account
                              idToken:(NSString *)idToken
                             uniqueId:(NSString *)uniqueId
                               scopes:(NSArray<NSString *> *)scopes
                            authority:(MSALAuthority *)authority
{
    MSALResult *result = [MSALResult new];
    
    result->_accessToken = accessToken;
    result->_expiresOn = expiresOn;
    result->_extendedLifeTimeToken = isExtendedLifetimeToken;
    result->_tenantId = tenantId;
    result->_account = account;
    result->_idToken = idToken;
    result->_uniqueId = uniqueId;
    result->_scopes = scopes;
    result->_authority = authority;
    
    return result;
}

+ (MSALResult *)resultWithAccessToken:(MSIDAccessToken *)accessToken
                              idToken:(MSIDIdToken *)idToken
              isExtendedLifetimeToken:(BOOL)isExtendedLifetimeToken
                                error:(NSError **)error
{
    NSError *idTokenError = nil;
    __auto_type idTokenClaims = [[MSIDAADV2IdTokenClaims alloc] initWithRawIdToken:idToken.rawIdToken error:&idTokenError];

    if (error)
    {
        MSID_LOG_WARN(nil, @"Invalid ID token");
        MSID_LOG_WARN_PII(nil, @"Invalid ID token, error %@", idTokenError);
    }

    MSALAccount *account = [[MSALAccount alloc] initWithUsername:idTokenClaims.preferredUsername
                                                            name:idTokenClaims.name
                                                   homeAccountId:accessToken.accountIdentifier.homeAccountId
                                                  localAccountId:idTokenClaims.objectId
                                                     environment:accessToken.authority.environment
                                                        tenantId:idTokenClaims.tenantId];

    NSError *authorityError = nil;
    MSALAuthority *authority = [[MSALAuthorityFactory new] authorityFromUrl:accessToken.authority.url
                                                                    context:nil
                                                                      error:&authorityError];

    if (!authority)
    {
        MSID_LOG_WARN(nil, @"Invalid authority");
        MSID_LOG_WARN_PII(nil, @"Invalid authority, error %@", authorityError);

        if (error) *error = authorityError;

        return nil;
    }
    
    return [self resultWithAccessToken:accessToken.accessToken
                             expiresOn:accessToken.expiresOn
               isExtendedLifetimeToken:isExtendedLifetimeToken
                              tenantId:accessToken.authority.url.msidTenant
                               account:account
                               idToken:idToken.rawIdToken
                              uniqueId:idTokenClaims.uniqueId
                                scopes:[accessToken.scopes array]
                             authority:authority];
}

@end
