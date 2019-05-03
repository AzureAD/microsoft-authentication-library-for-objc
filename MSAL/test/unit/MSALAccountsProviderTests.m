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
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDKeychainTokenCache.h"
#import "MSALAccount.h"
#import "MSALAccount+Internal.h"
#import "MSIDAccountIdentifier.h"
#import "MSALTenantProfile.h"
#import "MSALAuthority.h"
#import "MSALAccountId.h"
#import "MSIDAuthorityFactory.h"
#import "MSIDTestURLSession.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDTestURLResponse+MSAL.h"
#import "MSALAADAuthority.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDConstants.h"
#import "MSIDTestCacheUtil.h"

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
    
    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = @"v2.0";
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
    
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                                             clientId:@"client_id"
                                                  upn:@"user@contoso.com"
                                                 name:@"simple_user"
                                                  uid:@"uid"
                                                 utid:@"tid"
                                                  oid:@"oid"
                                             tenantId:@"tid"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
    
    NSError *error;
    NSArray *allAccounts = [provider allAccounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertEqual(allAccounts.count, 0);
}

- (void)testAllAccounts_whenDefaultAccountInCache_shouldReturnAccount {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                                             clientId:@"client_id"
                                                  upn:@"user@contoso.com"
                                                 name:@"simple_user"
                                                  uid:@"uid"
                                                 utid:@"tid"
                                                  oid:@"oid"
                                             tenantId:@"tid"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
    
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
    
    [MSIDTestCacheUtil saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                                            clientId:@"client_id"
                                                 upn:@"user@contoso.com"
                                                name:@"simple_user"
                                                 uid:@"uid"
                                                utid:@"tid"
                                                 oid:@"oid"
                                            tenantId:@"tid"
                                            familyId:nil
                                       cacheAccessor:legacyCache];
    
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
    
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                                             clientId:@"different_client_id"
                                                  upn:@"user@contoso.com"
                                                 name:@"simple_user"
                                                  uid:@"uid"
                                                 utid:@"tid"
                                                  oid:@"oid"
                                             tenantId:@"tid"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
    
    NSError *error;
    NSArray<MSALAccount *> *allAccounts = [provider allAccounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertEqual(allAccounts.count, 0);
}

- (void)testAllAccounts_whenDefaultAccountInCacheWithDifferentClientIdButSameFamily_shouldFindItButNotExposeAllClaims {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    NSURL *authorityUrl = [NSURL URLWithString:@"https://login.microsoftonline.com/tid"];
    MSIDAuthority *authority = [MSIDAuthorityFactory authorityFromUrl:authorityUrl context:nil error:nil];
    
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:authorityUrl.absoluteString
                                             clientId:@"different_client_id"
                                                  upn:@"user@contoso.com"
                                                 name:@"simple_user"
                                                  uid:@"uid"
                                                 utid:@"tid"
                                                  oid:@"oid"
                                             tenantId:@"tid"
                                             familyId:@"1"
                                        cacheAccessor:defaultCache];
    [defaultCache updateAppMetadataWithFamilyId:@"1" clientId:@"client_id" authority:authority context:nil error:nil];
    
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
    XCTAssertNil(allAccounts[0].tenantProfiles[0].claims);
}

- (void)testAllAccounts_whenLegacyAccountInCacheButDifferentClientId_shouldNotFindIt {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    [MSIDTestCacheUtil saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                                            clientId:@"different_client_id"
                                                 upn:@"user@contoso.com"
                                                name:@"simple_user"
                                                 uid:@"uid"
                                                utid:@"tid"
                                                 oid:@"oid"
                                            tenantId:@"tid"
                                            familyId:nil
                                       cacheAccessor:legacyCache];
    
    NSError *error;
    NSArray<MSALAccount *> *allAccounts = [provider allAccounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertEqual(allAccounts.count, 0);
}

- (void)testAllAccounts_whenLegacyAccountInCacheWithDifferentClientIdButSameFamily_shouldFindItButNotExposeAllClaims {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    NSURL *authorityUrl = [NSURL URLWithString:@"https://login.microsoftonline.com/tid"];
    MSIDAuthority *authority = [MSIDAuthorityFactory authorityFromUrl:authorityUrl context:nil error:nil];
    
    [MSIDTestCacheUtil saveLegacyTokensWithAuthority:authorityUrl.absoluteString
                                            clientId:@"different_client_id"
                                                 upn:@"user@contoso.com"
                                                name:@"simple_user"
                                                 uid:@"uid"
                                                utid:@"tid"
                                                 oid:@"oid"
                                            tenantId:@"tid"
                                            familyId:@"1"
                                       cacheAccessor:legacyCache];
    [defaultCache updateAppMetadataWithFamilyId:@"1" clientId:@"client_id" authority:authority context:nil error:nil];
    
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
    XCTAssertNil(allAccounts[0].tenantProfiles[0].claims);
}

- (void)testAllAccounts_whenMultipleDefaultAccountsInCache_shouldReturnThem {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    // first user logged in 1 home tenant and 2 guest tenants
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                                             clientId:@"client_id"
                                                  upn:@"user@contoso.com"
                                                 name:@"contoso_user"
                                                  uid:@"uid"
                                                 utid:@"tid"
                                                  oid:@"oid"
                                             tenantId:@"tid"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
    
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/guest_tid"
                                             clientId:@"client_id"
                                                  upn:@"user@contoso.com"
                                                 name:@"contoso_user"
                                                  uid:@"uid"
                                                 utid:@"tid"
                                                  oid:@"guest_oid"
                                             tenantId:@"guest_tid"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
    
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/guest2_tid"
                                             clientId:@"client_id"
                                                  upn:@"user@contoso.com"
                                                 name:@"contoso_user"
                                                  uid:@"uid"
                                                 utid:@"tid"
                                                  oid:@"guest2_oid"
                                             tenantId:@"guest2_tid"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
    
    // second user logged in 1 home tenant and 1 guest tenant
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/tid2"
                                             clientId:@"client_id"
                                                  upn:@"user@fabricant.com"
                                                 name:@"fabricant_user"
                                                  uid:@"uid2"
                                                 utid:@"tid2"
                                                  oid:@"oid2"
                                             tenantId:@"tid2"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
    
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/guest_tid2"
                                             clientId:@"client_id"
                                                  upn:@"user@fabricant.com"
                                                 name:@"fabricant_user"
                                                  uid:@"uid2"
                                                 utid:@"tid2"
                                                  oid:@"guest_oid2"
                                             tenantId:@"guest_tid2"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
    
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
    [MSIDTestCacheUtil saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                                            clientId:@"client_id"
                                                 upn:@"user@contoso.com"
                                                name:@"contoso_user"
                                                 uid:@"uid"
                                                utid:@"tid"
                                                 oid:@"oid"
                                            tenantId:@"tid"
                                            familyId:nil
                                       cacheAccessor:legacyCache];
    
    [MSIDTestCacheUtil saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/guest_tid"
                                            clientId:@"client_id"
                                                 upn:@"user@contoso.com"
                                                name:@"contoso_user"
                                                 uid:@"uid"
                                                utid:@"tid"
                                                 oid:@"guest_oid"
                                            tenantId:@"guest_tid"
                                            familyId:nil
                                       cacheAccessor:legacyCache];
    
    [MSIDTestCacheUtil saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/guest2_tid"
                                            clientId:@"client_id"
                                                 upn:@"user@contoso.com"
                                                name:@"contoso_user"
                                                 uid:@"uid"
                                                utid:@"tid"
                                                 oid:@"guest2_oid"
                                            tenantId:@"guest2_tid"
                                            familyId:nil
                                       cacheAccessor:legacyCache];
    
    // second user logged in 1 home tenant and 1 guest tenant
    [MSIDTestCacheUtil saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/tid2"
                                            clientId:@"client_id"
                                                 upn:@"user@fabricant.com"
                                                name:@"fabricant_user"
                                                 uid:@"uid2"
                                                utid:@"tid2"
                                                 oid:@"oid2"
                                            tenantId:@"tid2"
                                            familyId:nil
                                       cacheAccessor:legacyCache];
    
    [MSIDTestCacheUtil saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/guest_tid2"
                                            clientId:@"client_id"
                                                 upn:@"user@fabricant.com"
                                                name:@"fabricant_user"
                                                 uid:@"uid2"
                                                utid:@"tid2"
                                                 oid:@"guest_oid2"
                                            tenantId:@"guest_tid2"
                                            familyId:nil
                                       cacheAccessor:legacyCache];
    
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
    
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[1].authority.url.absoluteString, @"https://login.microsoftonline.com/tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[1].userObjectId, @"oid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[1].tenantId, @"tid");
    XCTAssertTrue(allAccounts[0].tenantProfiles[1].claims.count > 0);
    
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[2].authority.url.absoluteString, @"https://login.microsoftonline.com/guest_tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[2].userObjectId, @"guest_oid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[2].tenantId, @"guest_tid");
    XCTAssertTrue(allAccounts[0].tenantProfiles[2].claims.count > 0);
    
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
    
    [self setupMixedAccountsInCache];
    
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

- (void)testAccountForHomeAccountId_whenMixLegacyAccountsAndDefaultAccountsInCache_shouldReturnThemProperly {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    [self setupMixedAccountsInCache];
    
    NSError *error;
    MSALAccount *account = [provider accountForHomeAccountId:@"uid.tid" error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(account);
    
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
    XCTAssertEqualObjects(account.homeAccountId.identifier, @"uid.tid");
    XCTAssertEqualObjects(account.name, @"contoso_user");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.lookupAccountIdentifier.homeAccountId, @"uid.tid");
    
    // expect 3 tenant profiles
    XCTAssertEqual(account.tenantProfiles.count, 3);
    
    XCTAssertEqualObjects(account.tenantProfiles[0].authority.url.absoluteString, @"https://login.microsoftonline.com/tid");
    XCTAssertEqualObjects(account.tenantProfiles[0].userObjectId, @"oid");
    XCTAssertEqualObjects(account.tenantProfiles[0].tenantId, @"tid");
    XCTAssertTrue(account.tenantProfiles[0].claims.count > 0);
    
    XCTAssertEqualObjects(account.tenantProfiles[1].authority.url.absoluteString, @"https://login.microsoftonline.com/guest_tid");
    XCTAssertEqualObjects(account.tenantProfiles[1].userObjectId, @"guest_oid");
    XCTAssertEqualObjects(account.tenantProfiles[1].tenantId, @"guest_tid");
    // this tenant profile belongs to another client id, so we do not expose all claims
    XCTAssertNil(account.tenantProfiles[1].claims);
    
    XCTAssertEqualObjects(account.tenantProfiles[2].authority.url.absoluteString, @"https://login.microsoftonline.com/guest2_tid");
    XCTAssertEqualObjects(account.tenantProfiles[2].userObjectId, @"guest2_oid");
    XCTAssertEqualObjects(account.tenantProfiles[2].tenantId, @"guest2_tid");
    XCTAssertTrue(account.tenantProfiles[0].claims.count > 0);
}

- (void)testAccountForUsername_whenMixLegacyAccountsAndDefaultAccountsInCache_shouldReturnThemProperly {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    [self setupMixedAccountsInCache];
    
    NSError *error;
    MSALAccount *account = [provider accountForUsername:@"user@contoso.com" error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(account);
    
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
    XCTAssertEqualObjects(account.homeAccountId.identifier, @"uid.tid");
    XCTAssertEqualObjects(account.name, @"contoso_user");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.lookupAccountIdentifier.homeAccountId, @"uid.tid");
    
    // expect 3 tenant profiles
    XCTAssertEqual(account.tenantProfiles.count, 3);
    
    XCTAssertEqualObjects(account.tenantProfiles[0].authority.url.absoluteString, @"https://login.microsoftonline.com/tid");
    XCTAssertEqualObjects(account.tenantProfiles[0].userObjectId, @"oid");
    XCTAssertEqualObjects(account.tenantProfiles[0].tenantId, @"tid");
    XCTAssertTrue(account.tenantProfiles[0].claims.count > 0);
    
    XCTAssertEqualObjects(account.tenantProfiles[1].authority.url.absoluteString, @"https://login.microsoftonline.com/guest_tid");
    XCTAssertEqualObjects(account.tenantProfiles[1].userObjectId, @"guest_oid");
    XCTAssertEqualObjects(account.tenantProfiles[1].tenantId, @"guest_tid");
    // this tenant profile belongs to another client id, so we do not expose all claims
    XCTAssertNil(account.tenantProfiles[1].claims);
    
    XCTAssertEqualObjects(account.tenantProfiles[2].authority.url.absoluteString, @"https://login.microsoftonline.com/guest2_tid");
    XCTAssertEqualObjects(account.tenantProfiles[2].userObjectId, @"guest2_oid");
    XCTAssertEqualObjects(account.tenantProfiles[2].tenantId, @"guest2_tid");
    XCTAssertTrue(account.tenantProfiles[0].claims.count > 0);
}

- (void)testAllAccountsFilteredByAuthority_whenMixLegacyAccountsAndDefaultAccountsInCache_shouldReturnThemProperly {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    // first user logged in 1 home tenant and 2 guest tenants
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                                             clientId:@"client_id"
                                                  upn:@"user@contoso.com"
                                                 name:@"contoso_user"
                                                  uid:@"uid"
                                                 utid:@"tid"
                                                  oid:@"oid"
                                             tenantId:@"tid"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
    
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/guest_tid"
                                             clientId:@"different_client_id"
                                                  upn:@"user@contoso.com"
                                                 name:@"contoso_user"
                                                  uid:@"uid"
                                                 utid:@"tid"
                                                  oid:@"guest_oid"
                                             tenantId:@"guest_tid"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
    
    [MSIDTestCacheUtil saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/guest2_tid"
                                            clientId:@"client_id"
                                                 upn:@"user@contoso.com"
                                                name:@"contoso_user"
                                                 uid:@"uid"
                                                utid:@"tid"
                                                 oid:@"guest2_oid"
                                            tenantId:@"guest2_tid"
                                            familyId:nil
                                       cacheAccessor:legacyCache];
    
    // second user logged in 1 home tenant and 1 guest tenant
    [MSIDTestCacheUtil saveLegacyTokensWithAuthority:@"https://login.microsoftonline.de/tid2"
                                            clientId:@"client_id"
                                                 upn:@"user@fabricant.com"
                                                name:@"fabricant_user"
                                                 uid:@"uid2"
                                                utid:@"tid2"
                                                 oid:@"oid2"
                                            tenantId:@"tid2"
                                            familyId:nil
                                       cacheAccessor:legacyCache];
    
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.de/guest_tid2"
                                             clientId:@"client_id"
                                                  upn:@"user@fabricant.com"
                                                 name:@"fabricant_user"
                                                  uid:@"uid2"
                                                 utid:@"tid2"
                                                  oid:@"guest_oid2"
                                             tenantId:@"guest_tid2"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
    
    // Add mock network response for instance discovery
    NSError *error;
    NSString *authorityStr = @"https://login.microsoftonline.com/tid";
    MSALAADAuthority *authority = [[MSALAADAuthority alloc] initWithURL:[NSURL URLWithString:authorityStr] error:&error];
    XCTAssertNil(error);
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authorityStr];
    [discoveryResponse->_requestHeaders removeObjectForKey:MSID_OAUTH2_CORRELATION_ID_REQUEST_VALUE];
    [discoveryResponse->_requestHeaders removeObjectForKey:MSID_OAUTH2_CORRELATION_ID_REQUEST];
    [discoveryResponse->_requestHeaders removeObjectForKey:MSID_APP_VER_KEY];
    [discoveryResponse->_requestHeaders removeObjectForKey:MSID_APP_NAME_KEY];
    
    MSIDTestURLResponse *oidcResponse =
    [MSIDTestURLResponse oidcResponseForAuthority:authorityStr
                                      responseUrl:authorityStr
                                            query:nil];
    
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];
    
    // filter accounts by authority
    XCTestExpectation *expectation = [self expectationWithDescription:@"Filter accounts by authority."];
    [provider allAccountsFilteredByAuthority:authority
                             completionBlock:^(NSArray<MSALAccount *> *accounts, NSError *error) {
                                 XCTAssertNil(error);
                                 XCTAssertNotNil(accounts);
                                 XCTAssertEqual(accounts.count, 1);
                                 
                                 // verify first account
                                 XCTAssertEqualObjects(accounts[0].username, @"user@contoso.com");
                                 XCTAssertEqualObjects(accounts[0].homeAccountId.identifier, @"uid.tid");
                                 XCTAssertEqualObjects(accounts[0].name, @"contoso_user");
                                 XCTAssertEqualObjects(accounts[0].environment, @"login.microsoftonline.com");
                                 XCTAssertEqualObjects(accounts[0].lookupAccountIdentifier.homeAccountId, @"uid.tid");
                                 
                                 // expect 3 tenant profiles
                                 XCTAssertEqual(accounts[0].tenantProfiles.count, 3);
                                 
                                 XCTAssertEqualObjects(accounts[0].tenantProfiles[0].authority.url.absoluteString, @"https://login.microsoftonline.com/tid");
                                 XCTAssertEqualObjects(accounts[0].tenantProfiles[0].userObjectId, @"oid");
                                 XCTAssertEqualObjects(accounts[0].tenantProfiles[0].tenantId, @"tid");
                                 XCTAssertTrue(accounts[0].tenantProfiles[0].claims.count > 0);
                                 
                                 XCTAssertEqualObjects(accounts[0].tenantProfiles[1].authority.url.absoluteString, @"https://login.microsoftonline.com/guest_tid");
                                 XCTAssertEqualObjects(accounts[0].tenantProfiles[1].userObjectId, @"guest_oid");
                                 XCTAssertEqualObjects(accounts[0].tenantProfiles[1].tenantId, @"guest_tid");
                                 // this tenant profile belongs to another client id, so we do not expose all claims
                                 XCTAssertNil(accounts[0].tenantProfiles[1].claims);
                                 
                                 XCTAssertEqualObjects(accounts[0].tenantProfiles[2].authority.url.absoluteString, @"https://login.microsoftonline.com/guest2_tid");
                                 XCTAssertEqualObjects(accounts[0].tenantProfiles[2].userObjectId, @"guest2_oid");
                                 XCTAssertEqualObjects(accounts[0].tenantProfiles[2].tenantId, @"guest2_tid");
                                 XCTAssertTrue(accounts[0].tenantProfiles[0].claims.count > 0);
                                 
                                 [expectation fulfill];
                             }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)setupMixedAccountsInCache
{
    // first user logged in 1 home tenant and 2 guest tenants
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                                             clientId:@"client_id"
                                                  upn:@"user@contoso.com"
                                                 name:@"contoso_user"
                                                  uid:@"uid"
                                                 utid:@"tid"
                                                  oid:@"oid"
                                             tenantId:@"tid"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
    
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/guest_tid"
                                             clientId:@"different_client_id"
                                                  upn:@"user@contoso.com"
                                                 name:@"contoso_user"
                                                  uid:@"uid"
                                                 utid:@"tid"
                                                  oid:@"guest_oid"
                                             tenantId:@"guest_tid"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
    
    [MSIDTestCacheUtil saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/guest2_tid"
                                            clientId:@"client_id"
                                                 upn:@"user@contoso.com"
                                                name:@"contoso_user"
                                                 uid:@"uid"
                                                utid:@"tid"
                                                 oid:@"guest2_oid"
                                            tenantId:@"guest2_tid"
                                            familyId:nil
                                       cacheAccessor:legacyCache];
    
    // second user logged in 1 home tenant and 1 guest tenant
    [MSIDTestCacheUtil saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/tid2"
                                            clientId:@"client_id"
                                                 upn:@"user@fabricant.com"
                                                name:@"fabricant_user"
                                                 uid:@"uid2"
                                                utid:@"tid2"
                                                 oid:@"oid2"
                                            tenantId:@"tid2"
                                            familyId:nil
                                       cacheAccessor:legacyCache];
    
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/guest_tid2"
                                             clientId:@"client_id"
                                                  upn:@"user@fabricant.com"
                                                 name:@"fabricant_user"
                                                  uid:@"uid2"
                                                 utid:@"tid2"
                                                  oid:@"guest_oid2"
                                             tenantId:@"guest_tid2"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
}

@end
