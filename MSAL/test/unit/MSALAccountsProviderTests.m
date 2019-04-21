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
#import "MSALAccountsProvider.h"
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
#import "MSALAccount.h"
#import "MSALAccount+Internal.h"
#import "MSIDAccountIdentifier.h"
#import "MSALTenantProfile.h"
#import "MSALAuthority.h"
#import "MSALAccountId.h"

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

- (void)testAllAccounts_whenNoAccountInCache_shouldReturnEmptyList {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"a_different_client_id"];
    
    NSError *error;
    NSArray *allAccounts = [provider allAccounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertEqual(allAccounts.count, 0);
}

- (void)testAllAccounts_whenAccountWithDifferentClientIdInCache_shouldReturnEmptyList {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"some_client_id"];
    
    [self saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                                clientId:@"client_id"
                                     upn:@"user@contoso.com"
                                    name:@"simple_user"
                                     uid:@"uid"
                                    utid:@"tid"
                                     oid:@"oid"
                                tenantId:@"tid"];
    
    NSError *error;
    NSArray *allAccounts = [provider allAccounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertEqual(allAccounts.count, 0);
}

- (void)testAllAccounts_whenDefaultAccountInCache_shouldReturnAccount {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    [self saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                                clientId:@"client_id"
                                     upn:@"user@contoso.com"
                                    name:@"simple_user"
                                     uid:@"uid"
                                    utid:@"tid"
                                     oid:@"oid"
                                tenantId:@"tid"];
    
    NSError *error;
    NSArray<MSALAccount *> *allAccounts = [provider allAccounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertEqual(allAccounts.count, 1);
    XCTAssertEqualObjects(allAccounts[0].username, @"user@contoso.com");
    XCTAssertEqualObjects(allAccounts[0].homeAccountId.identifier, @"uid.tid");
    XCTAssertEqualObjects(allAccounts[0].name, @"simple_user");
    XCTAssertEqualObjects(allAccounts[0].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[0].lookupAccountIdentifier.homeAccountId, @"uid.tid");
    XCTAssertEqual(allAccounts[0].tenantProfiles.count, 1);
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].authority.url.absoluteString, @"https://login.microsoftonline.com/tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].userObjectId, @"oid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].tenantId, @"tid");
    XCTAssertTrue(allAccounts[0].tenantProfiles[0].claims.count > 0);
}

- (void)testAllAccounts_whenLegacyAccountInCache_shouldReturnAccount {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    [self saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                               clientId:@"client_id"
                                    upn:@"user@contoso.com"
                                   name:@"simple_user"
                                    uid:@"uid"
                                   utid:@"tid"
                                    oid:@"oid"
                               tenantId:@"tid"];
    
    NSError *error;
    NSArray<MSALAccount *> *allAccounts = [provider allAccounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertEqual(allAccounts.count, 1);
    XCTAssertEqualObjects(allAccounts[0].username, @"user@contoso.com");
    XCTAssertEqualObjects(allAccounts[0].homeAccountId.identifier, @"uid.tid");
    XCTAssertEqualObjects(allAccounts[0].name, @"simple_user");
    XCTAssertEqualObjects(allAccounts[0].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[0].lookupAccountIdentifier.homeAccountId, @"uid.tid");
    XCTAssertEqual(allAccounts[0].tenantProfiles.count, 1);
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].authority.url.absoluteString, @"https://login.microsoftonline.com/tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].userObjectId, @"oid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].tenantId, @"tid");
    XCTAssertTrue(allAccounts[0].tenantProfiles[0].claims.count > 0);
}

- (void)testAllAccounts_whenDefaultAccountInCacheButDifferentClientId_shouldNotFindIt {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    [self saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                                clientId:@"different_client_id"
                                     upn:@"user@contoso.com"
                                    name:@"simple_user"
                                     uid:@"uid"
                                    utid:@"tid"
                                     oid:@"oid"
                                tenantId:@"tid"];
    
    NSError *error;
    NSArray<MSALAccount *> *allAccounts = [provider allAccounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertEqual(allAccounts.count, 0);
}

- (void)testAllAccounts_whenDefaultAccountInCacheWithDifferentClientIdButSameFamily_shouldFindItButNotExposeAllClaims {
    //TODO
}

- (void)testAllAccounts_whenLegacyAccountInCacheButDifferentClientId_shouldNotFindIt {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    [self saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                               clientId:@"different_client_id"
                                    upn:@"user@contoso.com"
                                   name:@"simple_user"
                                    uid:@"uid"
                                   utid:@"tid"
                                    oid:@"oid"
                               tenantId:@"tid"];
    
    NSError *error;
    NSArray<MSALAccount *> *allAccounts = [provider allAccounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertEqual(allAccounts.count, 0);
}

- (void)testAllAccounts_whenLegacyAccountInCacheWithDifferentClientIdButSameFamily_shouldFindItButNotExposeAllClaims {
    //TODO
}

- (void)testAllAccounts_whenMultipleDefaultAccountsInCache_shouldReturnThem {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    // first user logged in 1 home tenant and 2 guest tenants
    [self saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                                clientId:@"client_id"
                                     upn:@"user@contoso.com"
                                    name:@"contoso_user"
                                     uid:@"uid"
                                    utid:@"tid"
                                     oid:@"oid"
                                tenantId:@"tid"];
    
    [self saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/guest_tid"
                                clientId:@"client_id"
                                     upn:@"user@contoso.com"
                                    name:@"contoso_user"
                                     uid:@"uid"
                                    utid:@"tid"
                                     oid:@"guest_oid"
                                tenantId:@"guest_tid"];
    
    [self saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/guest2_tid"
                                clientId:@"client_id"
                                     upn:@"user@contoso.com"
                                    name:@"contoso_user"
                                     uid:@"uid"
                                    utid:@"tid"
                                     oid:@"guest2_oid"
                                tenantId:@"guest2_tid"];
    
    // second user logged in 1 home tenant and 1 guest tenant1
    [self saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/tid2"
                                clientId:@"client_id"
                                     upn:@"user@fabricant.com"
                                    name:@"fabricant_user"
                                     uid:@"uid2"
                                    utid:@"tid2"
                                     oid:@"oid2"
                                tenantId:@"tid2"];
    
    [self saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/guest_tid2"
                                clientId:@"client_id"
                                     upn:@"user@fabricant.com"
                                    name:@"fabricant_user"
                                     uid:@"uid2"
                                    utid:@"tid2"
                                     oid:@"guest_oid2"
                                tenantId:@"guest_tid2"];
    
    NSError *error;
    NSArray<MSALAccount *> *allAccounts = [provider allAccounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertEqual(allAccounts.count, 2);
    
    // verify first account
    XCTAssertEqualObjects(allAccounts[0].username, @"user@contoso.com");
    XCTAssertEqualObjects(allAccounts[0].homeAccountId.identifier, @"uid.tid");
    XCTAssertEqualObjects(allAccounts[0].name, @"contoso_user");
    XCTAssertEqualObjects(allAccounts[0].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[0].lookupAccountIdentifier.homeAccountId, @"uid.tid");
    
    // expect 3 tenant profiles
    XCTAssertEqual(allAccounts[0].tenantProfiles.count, 3);
    
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].authority.url.absoluteString, @"https://login.microsoftonline.com/tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].userObjectId, @"oid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].tenantId, @"tid");
    XCTAssertTrue(allAccounts[0].tenantProfiles[0].claims.count > 0);
    
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[1].authority.url.absoluteString, @"https://login.microsoftonline.com/guest_tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[1].userObjectId, @"guest_oid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[1].tenantId, @"guest_tid");
    XCTAssertTrue(allAccounts[0].tenantProfiles[1].claims.count > 0);
    
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[2].authority.url.absoluteString, @"https://login.microsoftonline.com/guest2_tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[2].userObjectId, @"guest2_oid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[2].tenantId, @"guest2_tid");
    XCTAssertTrue(allAccounts[0].tenantProfiles[2].claims.count > 0);
    
    // verify second account
    XCTAssertEqualObjects(allAccounts[1].username, @"user@fabricant.com");
    XCTAssertEqualObjects(allAccounts[1].homeAccountId.identifier, @"uid2.tid2");
    XCTAssertEqualObjects(allAccounts[1].name, @"fabricant_user");
    XCTAssertEqualObjects(allAccounts[1].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[1].lookupAccountIdentifier.homeAccountId, @"uid2.tid2");
    
    // expect 2 tenant profiles
    XCTAssertEqual(allAccounts[1].tenantProfiles.count, 2);
    
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[0].authority.url.absoluteString, @"https://login.microsoftonline.com/tid2");
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[0].userObjectId, @"oid2");
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[0].tenantId, @"tid2");
    XCTAssertTrue(allAccounts[1].tenantProfiles[0].claims.count > 0);
    
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[1].authority.url.absoluteString, @"https://login.microsoftonline.com/guest_tid2");
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[1].userObjectId, @"guest_oid2");
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[1].tenantId, @"guest_tid2");
    XCTAssertTrue(allAccounts[1].tenantProfiles[1].claims.count > 0);
}

- (void)testAllAccounts_whenMultipleLegacyAccountsInCache_shouldReturnThem {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    // first user logged in 1 home tenant and 2 guest tenants
    [self saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                               clientId:@"client_id"
                                    upn:@"user@contoso.com"
                                   name:@"contoso_user"
                                    uid:@"uid"
                                   utid:@"tid"
                                    oid:@"oid"
                               tenantId:@"tid"];
    
    [self saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/guest_tid"
                               clientId:@"client_id"
                                    upn:@"user@contoso.com"
                                   name:@"contoso_user"
                                    uid:@"uid"
                                   utid:@"tid"
                                    oid:@"guest_oid"
                               tenantId:@"guest_tid"];
    
    [self saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/guest2_tid"
                               clientId:@"client_id"
                                    upn:@"user@contoso.com"
                                   name:@"contoso_user"
                                    uid:@"uid"
                                   utid:@"tid"
                                    oid:@"guest2_oid"
                               tenantId:@"guest2_tid"];
    
    // second user logged in 1 home tenant and 1 guest tenant1
    [self saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/tid2"
                               clientId:@"client_id"
                                    upn:@"user@fabricant.com"
                                   name:@"fabricant_user"
                                    uid:@"uid2"
                                   utid:@"tid2"
                                    oid:@"oid2"
                               tenantId:@"tid2"];
    
    [self saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/guest_tid2"
                               clientId:@"client_id"
                                    upn:@"user@fabricant.com"
                                   name:@"fabricant_user"
                                    uid:@"uid2"
                                   utid:@"tid2"
                                    oid:@"guest_oid2"
                               tenantId:@"guest_tid2"];
    
    NSError *error;
    NSArray<MSALAccount *> *allAccounts = [provider allAccounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertEqual(allAccounts.count, 2);
    
    // verify first account
    XCTAssertEqualObjects(allAccounts[0].username, @"user@contoso.com");
    XCTAssertEqualObjects(allAccounts[0].homeAccountId.identifier, @"uid.tid");
    XCTAssertEqualObjects(allAccounts[0].name, @"contoso_user");
    XCTAssertEqualObjects(allAccounts[0].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[0].lookupAccountIdentifier.homeAccountId, @"uid.tid");
    
    // expect 3 tenant profiles
    XCTAssertEqual(allAccounts[0].tenantProfiles.count, 3);
    
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[2].authority.url.absoluteString, @"https://login.microsoftonline.com/guest_tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[2].userObjectId, @"guest_oid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[2].tenantId, @"guest_tid");
    XCTAssertTrue(allAccounts[0].tenantProfiles[2].claims.count > 0);
    
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[1].authority.url.absoluteString, @"https://login.microsoftonline.com/tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[1].userObjectId, @"oid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[1].tenantId, @"tid");
    XCTAssertTrue(allAccounts[0].tenantProfiles[1].claims.count > 0);
    
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].authority.url.absoluteString, @"https://login.microsoftonline.com/guest2_tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].userObjectId, @"guest2_oid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].tenantId, @"guest2_tid");
    XCTAssertTrue(allAccounts[0].tenantProfiles[0].claims.count > 0);
    
    // verify second account
    XCTAssertEqualObjects(allAccounts[1].username, @"user@fabricant.com");
    XCTAssertEqualObjects(allAccounts[1].homeAccountId.identifier, @"uid2.tid2");
    XCTAssertEqualObjects(allAccounts[1].name, @"fabricant_user");
    XCTAssertEqualObjects(allAccounts[1].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[1].lookupAccountIdentifier.homeAccountId, @"uid2.tid2");
    
    // expect 2 tenant profiles
    XCTAssertEqual(allAccounts[1].tenantProfiles.count, 2);
    
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[1].authority.url.absoluteString, @"https://login.microsoftonline.com/tid2");
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[1].userObjectId, @"oid2");
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[1].tenantId, @"tid2");
    XCTAssertTrue(allAccounts[1].tenantProfiles[1].claims.count > 0);
    
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[0].authority.url.absoluteString, @"https://login.microsoftonline.com/guest_tid2");
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[0].userObjectId, @"guest_oid2");
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[0].tenantId, @"guest_tid2");
    XCTAssertTrue(allAccounts[1].tenantProfiles[0].claims.count > 0);
}

- (void)testAllAccounts_whenMixLegacyAccountsAndDefaultAccountsInCache_shouldReturnThemProperly {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    // first user logged in 1 home tenant and 2 guest tenants
    [self saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                                clientId:@"client_id"
                                     upn:@"user@contoso.com"
                                    name:@"contoso_user"
                                     uid:@"uid"
                                    utid:@"tid"
                                     oid:@"oid"
                                tenantId:@"tid"];
    
    [self saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/guest_tid"
                                clientId:@"different_client_id"
                                     upn:@"user@contoso.com"
                                    name:@"contoso_user"
                                     uid:@"uid"
                                    utid:@"tid"
                                     oid:@"guest_oid"
                                tenantId:@"guest_tid"];
    
    [self saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/guest2_tid"
                               clientId:@"client_id"
                                    upn:@"user@contoso.com"
                                   name:@"contoso_user"
                                    uid:@"uid"
                                   utid:@"tid"
                                    oid:@"guest2_oid"
                               tenantId:@"guest2_tid"];
    
    // second user logged in 1 home tenant and 1 guest tenant1
    [self saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/tid2"
                               clientId:@"client_id"
                                    upn:@"user@fabricant.com"
                                   name:@"fabricant_user"
                                    uid:@"uid2"
                                   utid:@"tid2"
                                    oid:@"oid2"
                               tenantId:@"tid2"];
    
    [self saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/guest_tid2"
                                clientId:@"client_id"
                                     upn:@"user@fabricant.com"
                                    name:@"fabricant_user"
                                     uid:@"uid2"
                                    utid:@"tid2"
                                     oid:@"guest_oid2"
                                tenantId:@"guest_tid2"];
    
    NSError *error;
    NSArray<MSALAccount *> *allAccounts = [provider allAccounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertEqual(allAccounts.count, 2);
    
    // verify first account
    XCTAssertEqualObjects(allAccounts[0].username, @"user@contoso.com");
    XCTAssertEqualObjects(allAccounts[0].homeAccountId.identifier, @"uid.tid");
    XCTAssertEqualObjects(allAccounts[0].name, @"contoso_user");
    XCTAssertEqualObjects(allAccounts[0].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[0].lookupAccountIdentifier.homeAccountId, @"uid.tid");
    
    // expect 3 tenant profiles
    XCTAssertEqual(allAccounts[0].tenantProfiles.count, 3);
    
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].authority.url.absoluteString, @"https://login.microsoftonline.com/tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].userObjectId, @"oid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].tenantId, @"tid");
    XCTAssertTrue(allAccounts[0].tenantProfiles[0].claims.count > 0);
    
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[1].authority.url.absoluteString, @"https://login.microsoftonline.com/guest_tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[1].userObjectId, @"guest_oid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[1].tenantId, @"guest_tid");
    // this tenant profile belongs to another client id, so we do not expose all claims
    XCTAssertNil(allAccounts[0].tenantProfiles[1].claims);
    
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[2].authority.url.absoluteString, @"https://login.microsoftonline.com/guest2_tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[2].userObjectId, @"guest2_oid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[2].tenantId, @"guest2_tid");
    XCTAssertTrue(allAccounts[0].tenantProfiles[0].claims.count > 0);
    
    // verify second account
    XCTAssertEqualObjects(allAccounts[1].username, @"user@fabricant.com");
    XCTAssertEqualObjects(allAccounts[1].homeAccountId.identifier, @"uid2.tid2");
    XCTAssertEqualObjects(allAccounts[1].name, @"fabricant_user");
    XCTAssertEqualObjects(allAccounts[1].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[1].lookupAccountIdentifier.homeAccountId, @"uid2.tid2");
    
    // expect 2 tenant profiles
    XCTAssertEqual(allAccounts[1].tenantProfiles.count, 2);
    
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[0].authority.url.absoluteString, @"https://login.microsoftonline.com/tid2");
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[0].userObjectId, @"oid2");
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[0].tenantId, @"tid2");
    XCTAssertTrue(allAccounts[1].tenantProfiles[1].claims.count > 0);
    
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[1].authority.url.absoluteString, @"https://login.microsoftonline.com/guest_tid2");
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[1].userObjectId, @"guest_oid2");
    XCTAssertEqualObjects(allAccounts[1].tenantProfiles[1].tenantId, @"guest_tid2");
    XCTAssertTrue(allAccounts[1].tenantProfiles[1].claims.count > 0);
}

- (BOOL)saveDefaultTokensWithAuthority:(NSString *)authority
                              clientId:(NSString *)clientId
                                   upn:(NSString *)upn
                                  name:(NSString *)name
                                   uid:(NSString *)uid
                                  utid:(NSString *)utid
                                   oid:(NSString *)oid
                              tenantId:(NSString *)tid
{
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:name preferredUsername:upn oid:oid tenantId:tid];
    
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
    
    return [defaultCache saveTokensWithConfiguration:config
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
                                  oid:(NSString *)oid
                             tenantId:(NSString *)tid
{
    
    NSString *idToken = [MSIDTestIdTokenUtil idTokenWithName:name upn:upn oid:oid tenantId:tid];
    
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
    
    return [legacyCache saveTokensWithConfiguration:config
                                           response:response
                                            factory:[MSIDAADV1Oauth2Factory new]
                                            context:nil
                                              error:nil];
    
}

@end
