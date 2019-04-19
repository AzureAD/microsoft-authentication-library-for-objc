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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDCacheAccessor.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDTestConfiguration.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDAADV1Oauth2Factory.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDKeychainTokenCache.h"

@interface MSALAccountsProviderTests : XCTestCase

@end

@implementation MSALAccountsProviderTests
{
    MSIDDefaultTokenCacheAccessor *defaultCache;
    MSIDLegacyTokenCacheAccessor *legacyCache;
}

- (void)setUp {
    id<MSIDTokenCacheDataSource> dataSource = nil;
    
#if TARGET_OS_IPHONE
    dataSource = MSIDKeychainTokenCache.defaultKeychainCache;
#else
    dataSource = MSIDMacTokenCache.defaultCache;
#endif
    
    legacyCache = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:dataSource
                                                       otherCacheAccessors:@[]];
    defaultCache = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:@[legacyCache]];
    
    [defaultCache clearWithContext:nil error:nil];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (BOOL)saveDefaultTokensWithAuthority:(NSString *)authority
                              clientId:(NSString *)clientId
                                   upn:(NSString *)upn
                                  name:(NSString *)name
                                   uid:(NSString *)uid
                                  utid:(NSString *)utid
                              tenantId:(NSString *)tid
                                 cache:(id<MSIDCacheAccessor>)cache
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:upn preferredUsername:upn tenantId:tid];
    
    MSIDTokenResponse *response = [MSIDTestTokenResponse v2TokenResponseWithAT:@"access token"
                                                                            RT:@"refresh token"
                                                                        scopes:[NSOrderedSet orderedSetWithObjects:@"user.read", nil]
                                                                       idToken:idToken
                                                                           uid:uid
                                                                          utid:utid
                                                                      familyId:nil];
    
    MSIDConfiguration * config = [MSIDTestConfiguration configurationWithAuthority:authority
                                                                          clientId:clientId
                                                                       redirectUri:nil
                                                                            target:@"user.read"];
    
    return [cache saveTokensWithConfiguration:config
                                     response:response
                                      factory:[MSIDAADV2Oauth2Factory new]
                                      context:nil
                                        error:nil];
}

- (BOOL)saveLegacyTokensWithAuthority:(NSString *)authority
                             clientId:(NSString *)clientId
                                  upn:(NSString *)upn
                                 name:(NSString *)name
                                  uid:(NSString *)uid
                                 utid:(NSString *)utid
                             tenantId:(NSString *)tid
                                cache:(id<MSIDCacheAccessor>)cache
{
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:name upn:upn tenantId:tid];
    
    MSIDTokenResponse *response = [MSIDTestTokenResponse v1TokenResponseWithAT:@"access token"
                                                                            rt:@"refresh token"
                                                                      resource:@"graph resource"
                                                                           uid:uid
                                                                          utid:utid
                                                                       idToken:idToken
                                                              additionalFields:nil];
    
    MSIDConfiguration * config = [MSIDTestConfiguration configurationWithAuthority:authority
                                                                          clientId:clientId
                                                                       redirectUri:nil
                                                                            target:@"fake_resource"];
    
    return [cache saveTokensWithConfiguration:config
                                     response:response
                                      factory:[MSIDAADV1Oauth2Factory new]
                                      context:nil
                                        error:nil];
    
}

@end
