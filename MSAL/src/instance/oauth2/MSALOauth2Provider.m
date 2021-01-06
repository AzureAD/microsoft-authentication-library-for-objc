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

#import "MSALOauth2Provider.h"
#import "MSIDOauth2Factory.h"
#import "MSIDTokenResult.h"
#import "MSALOauth2Provider+Internal.h"
#import "MSALResult+Internal.h"
#import "MSIDAuthority.h"
#import "MSALAuthority_Internal.h"
#import "MSALOauth2Authority.h"
#import "MSIDIdTokenClaims.h"
#import "MSALTenantProfile+Internal.h"

@implementation MSALOauth2Provider

#pragma mark - Public

- (instancetype)initWithClientId:(NSString *)clientId
                      tokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
            accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache

{
    self = [super init];
    if (self)
    {
        [self initOauth2Factory];
        _clientId = clientId;
        _accountMetadataCache = accountMetadataCache;
        _tokenCache = tokenCache;
    }
    return self;
}

- (MSALResult *)resultWithTokenResult:(MSIDTokenResult *)tokenResult
                           authScheme:(id<MSALAuthenticationSchemeProtocol, MSALAuthenticationSchemeProtocolInternal>)authScheme
                           popManager:(MSIDDevicePopManager *)popManager
                                error:(NSError **)error
{
    NSError *authorityError = nil;
    
    MSALAuthority *authority = [[MSALOauth2Authority alloc] initWithURL:tokenResult.authority.url error:error];
    
    if (!authority)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"Invalid authority, error %@", MSID_PII_LOG_MASKABLE(authorityError));
        
        if (error) *error = authorityError;
        
        return nil;
    }
    
    return [MSALResult resultWithMSIDTokenResult:tokenResult authority:authority authScheme:authScheme popManager:popManager error:error];
}

- (BOOL)removeAdditionalAccountInfo:(__unused MSALAccount *)account
                              error:(__unused NSError **)error
{
    return YES;
}

- (MSIDAuthority *)issuerAuthorityWithAccount:(__unused MSALAccount *)account
                             requestAuthority:(MSIDAuthority *)requestAuthority
                                instanceAware:(__unused BOOL)instanceAware
                                        error:(__unused NSError * _Nullable __autoreleasing *)error
{
    // TODO: after authority->issuer cache is ready, this should always lookup cached issuer instead
    return requestAuthority;
}

- (BOOL)isSupportedAuthority:(__unused MSIDAuthority *)authority
{
    return YES;
}

- (MSALTenantProfile *)tenantProfileWithClaims:(NSDictionary *)claims
                                 homeAccountId:(__unused MSALAccountId *)homeAccountId
                                   environment:(NSString *)environment
                                         error:(NSError **)error
{
    MSIDIdTokenClaims *idTokenClaims = [[MSIDIdTokenClaims alloc] initWithJSONDictionary:claims error:error];
    
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
    self.msidOauth2Factory = [MSIDOauth2Factory new];
}

@end
