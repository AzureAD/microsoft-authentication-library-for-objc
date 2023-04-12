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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSALCIAMOauth2Provider.h"
#import "MSALOauth2Provider+Internal.h"
#import "MSIDCIAMOauth2Factory.h"
#import "MSALResult+Internal.h"
#import "MSIDAuthority.h"
#import "MSALCIAMAuthority.h"
#import "MSIDCIAMAuthority.h"
#import "MSIDTokenResult.h"
#import "MSALAccount.h"
#import "MSALAccountId.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSALAccount+Internal.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAADV2IdTokenClaims.h"
#import "MSALTenantProfile+Internal.h"

@implementation MSALCIAMOauth2Provider

#pragma mark - Public

- (MSALResult *)resultWithTokenResult:(MSIDTokenResult *)tokenResult
                           authScheme:(id<MSALAuthenticationSchemeProtocol, MSALAuthenticationSchemeProtocolInternal>)authScheme
                           popManager:(MSIDDevicePopManager *)popManager
                                error:(NSError **)error
{
    NSError *authorityError = nil;
    
    MSALCIAMAuthority *ciamAuthority = [[MSALCIAMAuthority alloc] initWithURL:tokenResult.authority.url validateFormat:NO error:&authorityError];
    
    if (!ciamAuthority)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"Invalid authority, error %@", MSID_PII_LOG_MASKABLE(authorityError));
        
        if (error) *error = authorityError;
        
        return nil;
    }
    
    return [MSALResult resultWithMSIDTokenResult:tokenResult authority:ciamAuthority authScheme:authScheme popManager:popManager error:error];
}

- (MSIDAuthority *)issuerAuthorityWithAccount:(MSALAccount *)account
                             requestAuthority:(MSIDAuthority *)requestAuthority
                                instanceAware:(BOOL)instanceAware
                                        error:(NSError **)error
{
    if (self.accountMetadataCache)
    {
        NSURL *cachedURL = [self.accountMetadataCache getAuthorityURL:requestAuthority.url
                                                        homeAccountId:account.homeAccountId.identifier
                                                             clientId:self.clientId
                                                        instanceAware:instanceAware
                                                              context:nil
                                                                error:error];
        
        MSIDAuthority *cachedAuthority =
        [[MSIDCIAMAuthority alloc] initWithURL:cachedURL?:requestAuthority.url
                               validateFormat:NO rawTenant:nil context:nil error:error];
        
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Request authority cache look up for %@, using %@ instead", requestAuthority.url, cachedAuthority.url);
        
        return cachedAuthority;
    }
    return requestAuthority;
}

- (BOOL)isSupportedAuthority:(MSIDAuthority *)authority
{
    return [authority isKindOfClass:[MSIDCIAMAuthority class]];
}

- (MSALTenantProfile *)tenantProfileWithClaims:(NSDictionary *)claims
                                 homeAccountId:(__unused MSALAccountId *)homeAccountId
                                   environment:(NSString *)environment
                                         error:(NSError **)error
{
    MSIDAADV2IdTokenClaims *idTokenClaims = [[MSIDAADV2IdTokenClaims alloc] initWithJSONDictionary:claims error:error];
    
    if (!idTokenClaims)
    {
        return nil;
    }
    
    return [[MSALTenantProfile alloc] initWithIdentifier:idTokenClaims.uniqueId
                                                tenantId:idTokenClaims.realm
                                             environment:environment
                                     isHomeTenantProfile:YES
                                                  claims:claims];
}

#pragma mark - Protected

- (void)initOauth2Factory
{
    self.msidOauth2Factory = [MSIDCIAMOauth2Factory new];
}

@end

