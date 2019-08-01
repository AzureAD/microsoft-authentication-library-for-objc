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
#import "NSString+MSIDTestUtil.h"
#import "MSIDTestURLSession.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSIDTestURLResponse+MSAL.h"
#import "MSALAADAuthority.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDConstants.h"
#import "MSIDTestCacheUtil.h"
#import "MSALAccount+MultiTenantAccount.h"
#import "MSALAccountEnumerationParameters.h"
#import "MSALMockExternalAccountHandler.h"
#import "MSALAADOauth2Provider.h"
#import "MSALAccountId+Internal.h"
#import "MSALTenantProfile+Internal.h"

@interface MSALAccountsProviderTests : XCTestCase

@end

@implementation MSALAccountsProviderTests
{
    MSIDDefaultTokenCacheAccessor *defaultCache;
    MSIDLegacyTokenCacheAccessor *legacyCache;
}

- (void)setUp {
    id<MSIDExtendedTokenCacheDataSource> dataSource = nil;
    
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
    XCTAssertEqualObjects(allAccounts[0].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[0].lookupAccountIdentifier.homeAccountId, @"uid.tid");
    XCTAssertEqual(allAccounts[0].tenantProfiles.count, 1);
    XCTAssertEqualObjects(allAccounts[0].identifier, @"uid.tid");
    XCTAssertTrue(allAccounts[0].accountClaims.count > 0);
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].tenantId, @"tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].identifier, @"oid");
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
    XCTAssertEqualObjects(allAccounts[0].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[0].lookupAccountIdentifier.homeAccountId, @"uid.tid");
    XCTAssertEqual(allAccounts[0].tenantProfiles.count, 1);
    XCTAssertEqualObjects(allAccounts[0].identifier, @"uid.tid");
    XCTAssertTrue(allAccounts[0].accountClaims.count > 0);
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].tenantId, @"tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].identifier, @"oid");
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
    
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/tid" aadAuthority];
    
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:authority.url.absoluteString
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
    XCTAssertEqualObjects(allAccounts[0].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[0].lookupAccountIdentifier.homeAccountId, @"uid.tid");
    XCTAssertEqualObjects(allAccounts[0].identifier, @"uid.tid");
    XCTAssertNil(allAccounts[0].accountClaims);
    XCTAssertEqual(allAccounts[0].tenantProfiles.count, 1);
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].tenantId, @"tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].identifier, @"oid");
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
    
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/tid" aadAuthority];
    
    [MSIDTestCacheUtil saveLegacyTokensWithAuthority:authority.url.absoluteString
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
    XCTAssertEqualObjects(allAccounts[0].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[0].lookupAccountIdentifier.homeAccountId, @"uid.tid");
    XCTAssertEqual(allAccounts[0].tenantProfiles.count, 1);
    XCTAssertEqualObjects(allAccounts[0].identifier, @"uid.tid");
    XCTAssertNil(allAccounts[0].accountClaims);
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].tenantId, @"tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].identifier, @"oid");
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
    MSALAccount *firstAccount = [self accountWithIdentifier:@"uid.tid" fromArray:allAccounts];
    XCTAssertNotNil(firstAccount);
    
    XCTAssertEqualObjects(firstAccount.username, @"user@contoso.com");
    XCTAssertEqualObjects(firstAccount.homeAccountId.identifier, @"uid.tid");
    XCTAssertEqualObjects(firstAccount.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(firstAccount.lookupAccountIdentifier.homeAccountId, @"uid.tid");
    XCTAssertEqualObjects(firstAccount.identifier, @"uid.tid");
    XCTAssertTrue(firstAccount.accountClaims.count > 0);
    
    // expect 3 tenant profiles
    XCTAssertEqual(firstAccount.tenantProfiles.count, 3);
    
    NSInteger a1FirstProfileIndex = [self indexOfTenantProfileInArray:firstAccount.tenantProfiles localAccountId:@"oid"];
    
    [self verifyTenantProfileWithIndex:a1FirstProfileIndex
                              tenantId:@"tid"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"oid"
                           allProfiles:firstAccount.tenantProfiles
                             hasClaims:YES];
    
    NSInteger a1SecondProfileIndex = [self indexOfTenantProfileInArray:firstAccount.tenantProfiles localAccountId:@"guest_oid"];
    
    [self verifyTenantProfileWithIndex:a1SecondProfileIndex
                              tenantId:@"guest_tid"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"guest_oid"
                           allProfiles:firstAccount.tenantProfiles
                             hasClaims:YES];
    
    NSInteger a1ThirdProfileIndex = [self indexOfTenantProfileInArray:firstAccount.tenantProfiles localAccountId:@"guest2_oid"];
    
    [self verifyTenantProfileWithIndex:a1ThirdProfileIndex
                              tenantId:@"guest2_tid"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"guest2_oid"
                           allProfiles:firstAccount.tenantProfiles
                             hasClaims:YES];
    
    // verify second account
    MSALAccount *secondAccount = [self accountWithIdentifier:@"uid2.tid2" fromArray:allAccounts];
    XCTAssertNotNil(secondAccount);
    
    XCTAssertEqualObjects(secondAccount.username, @"user@fabricant.com");
    XCTAssertEqualObjects(secondAccount.homeAccountId.identifier, @"uid2.tid2");
    XCTAssertEqualObjects(secondAccount.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(secondAccount.lookupAccountIdentifier.homeAccountId, @"uid2.tid2");
    XCTAssertEqualObjects(secondAccount.identifier, @"uid2.tid2");
    XCTAssertTrue(secondAccount.accountClaims.count > 0);
    
    // expect 2 tenant profiles
    XCTAssertEqual(secondAccount.tenantProfiles.count, 2);
    
    // Since tenant profiles operate using a set, there's no guarantee regarding returned order
    NSInteger a2firstProfileIndex = [self indexOfTenantProfileInArray:secondAccount.tenantProfiles localAccountId:@"oid2"];
    
    [self verifyTenantProfileWithIndex:a2firstProfileIndex
                              tenantId:@"tid2"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"oid2"
                           allProfiles:secondAccount.tenantProfiles
                             hasClaims:YES];

    NSInteger a2secondProfileIndex = [self indexOfTenantProfileInArray:secondAccount.tenantProfiles localAccountId:@"guest_oid2"];
    [self verifyTenantProfileWithIndex:a2secondProfileIndex
                              tenantId:@"guest_tid2"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"guest_oid2"
                           allProfiles:secondAccount.tenantProfiles
                             hasClaims:YES];
}

- (NSInteger)indexOfTenantProfileInArray:(NSArray *)allProfiles
                           localAccountId:(NSString *)localAccountId
{
    for (MSALTenantProfile *tenantProfile in allProfiles)
    {
        if ([tenantProfile.identifier isEqualToString:localAccountId])
        {
            return [allProfiles indexOfObject:tenantProfile];
        }
    }
    
    return -1;
}

- (MSALAccount *)accountWithIdentifier:(NSString *)identifier
                             fromArray:(NSArray *)array
{
    for (MSALAccount *account in array)
    {
        if ([account.identifier isEqualToString:identifier])
        {
            return account;
        }
    }
    
    return nil;
}

- (void)verifyTenantProfileWithIndex:(NSInteger)index
                            tenantId:(NSString *)tenantId
                         environment:(NSString *)environment
                      localAccountId:(NSString *)localAccountId
                         allProfiles:(NSArray *)allProfiles
                           hasClaims:(BOOL)hasClaims
{
    XCTAssertTrue(index != -1);
    
    MSALTenantProfile *profile = allProfiles[index];
    
    XCTAssertEqualObjects(profile.tenantId, tenantId);
    XCTAssertEqualObjects(profile.environment, environment);
    XCTAssertEqualObjects(profile.identifier, localAccountId);
    
    if (hasClaims)
    {
        XCTAssertTrue(profile.claims.count > 0);
    }
    else
    {
        XCTAssertNil(profile.claims);
    }
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
    MSALAccount *firstAccount = [self accountWithIdentifier:@"uid.tid" fromArray:allAccounts];
    XCTAssertNotNil(firstAccount);
    
    XCTAssertEqualObjects(firstAccount.username, @"user@contoso.com");
    XCTAssertEqualObjects(firstAccount.homeAccountId.identifier, @"uid.tid");
    XCTAssertEqualObjects(firstAccount.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(firstAccount.lookupAccountIdentifier.homeAccountId, @"uid.tid");
    XCTAssertEqualObjects(firstAccount.identifier, @"uid.tid");
    XCTAssertTrue(firstAccount.accountClaims.count > 0);
    
    // expect 3 tenant profiles
    XCTAssertEqual(firstAccount.tenantProfiles.count, 3);
    
    NSInteger a1FirstProfileIndex = [self indexOfTenantProfileInArray:firstAccount.tenantProfiles localAccountId:@"oid"];
    
    [self verifyTenantProfileWithIndex:a1FirstProfileIndex
                              tenantId:@"tid"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"oid"
                           allProfiles:firstAccount.tenantProfiles
                             hasClaims:YES];
    
    
    NSInteger a1SecondProfileIndex = [self indexOfTenantProfileInArray:firstAccount.tenantProfiles localAccountId:@"guest_oid"];
    
    [self verifyTenantProfileWithIndex:a1SecondProfileIndex
                              tenantId:@"guest_tid"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"guest_oid"
                           allProfiles:firstAccount.tenantProfiles
                             hasClaims:YES];
    
    NSInteger a1ThirdProfileIndex = [self indexOfTenantProfileInArray:firstAccount.tenantProfiles localAccountId:@"guest2_oid"];
    
    [self verifyTenantProfileWithIndex:a1ThirdProfileIndex
                              tenantId:@"guest2_tid"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"guest2_oid"
                           allProfiles:firstAccount.tenantProfiles
                             hasClaims:YES];
    
    // verify second account
    MSALAccount *secondAccount = [self accountWithIdentifier:@"uid2.tid2" fromArray:allAccounts];
    XCTAssertNotNil(secondAccount);
    
    XCTAssertEqualObjects(secondAccount.username, @"user@fabricant.com");
    XCTAssertEqualObjects(secondAccount.homeAccountId.identifier, @"uid2.tid2");
    XCTAssertEqualObjects(secondAccount.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(secondAccount.lookupAccountIdentifier.homeAccountId, @"uid2.tid2");
    XCTAssertEqualObjects(secondAccount.identifier, @"uid2.tid2");
    XCTAssertTrue(secondAccount.accountClaims.count > 0);
    
    // expect 2 tenant profiles
    XCTAssertEqual(secondAccount.tenantProfiles.count, 2);
    
    NSInteger a2FirstProfileIndex = [self indexOfTenantProfileInArray:secondAccount.tenantProfiles localAccountId:@"guest_oid2"];
    
    [self verifyTenantProfileWithIndex:a2FirstProfileIndex
                              tenantId:@"guest_tid2"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"guest_oid2"
                           allProfiles:secondAccount.tenantProfiles
                             hasClaims:YES];
    
    NSInteger a2SecondProfileIndex = [self indexOfTenantProfileInArray:secondAccount.tenantProfiles localAccountId:@"oid2"];
    
    [self verifyTenantProfileWithIndex:a2SecondProfileIndex
                              tenantId:@"tid2"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"oid2"
                           allProfiles:secondAccount.tenantProfiles
                             hasClaims:YES];
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
    MSALAccount *firstAccount = [self accountWithIdentifier:@"uid.tid" fromArray:allAccounts];
    XCTAssertNotNil(firstAccount);
    
    XCTAssertEqualObjects(firstAccount.username, @"user@contoso.com");
    XCTAssertEqualObjects(firstAccount.homeAccountId.identifier, @"uid.tid");
    XCTAssertEqualObjects(firstAccount.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(firstAccount.lookupAccountIdentifier.homeAccountId, @"uid.tid");
    XCTAssertEqualObjects(firstAccount.identifier, @"uid.tid");
    XCTAssertTrue(firstAccount.accountClaims.count > 0);
    
    // expect 3 tenant profiles
    XCTAssertEqual(firstAccount.tenantProfiles.count, 3);
    
    NSInteger a1FirstProfileIndex = [self indexOfTenantProfileInArray:firstAccount.tenantProfiles localAccountId:@"oid"];
    
    [self verifyTenantProfileWithIndex:a1FirstProfileIndex
                              tenantId:@"tid"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"oid"
                           allProfiles:firstAccount.tenantProfiles
                             hasClaims:YES];
    
    
    NSInteger a1SecondProfileIndex = [self indexOfTenantProfileInArray:firstAccount.tenantProfiles localAccountId:@"guest_oid"];
    
    [self verifyTenantProfileWithIndex:a1SecondProfileIndex
                              tenantId:@"guest_tid"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"guest_oid"
                           allProfiles:firstAccount.tenantProfiles
                             hasClaims:NO];
    
    NSInteger a1ThirdProfileIndex = [self indexOfTenantProfileInArray:firstAccount.tenantProfiles localAccountId:@"guest2_oid"];
    
    [self verifyTenantProfileWithIndex:a1ThirdProfileIndex
                              tenantId:@"guest2_tid"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"guest2_oid"
                           allProfiles:firstAccount.tenantProfiles
                             hasClaims:YES];
    
    // verify second account
    MSALAccount *secondAccount = [self accountWithIdentifier:@"uid2.tid2" fromArray:allAccounts];
    XCTAssertNotNil(secondAccount);
    
    XCTAssertEqualObjects(secondAccount.username, @"user@fabricant.com");
    XCTAssertEqualObjects(secondAccount.homeAccountId.identifier, @"uid2.tid2");
    XCTAssertEqualObjects(secondAccount.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(secondAccount.lookupAccountIdentifier.homeAccountId, @"uid2.tid2");
    
    // expect 2 tenant profiles
    XCTAssertEqual(secondAccount.tenantProfiles.count, 2);
    
    NSInteger a2FirstProfileIndex = [self indexOfTenantProfileInArray:secondAccount.tenantProfiles localAccountId:@"oid2"];
    
    [self verifyTenantProfileWithIndex:a2FirstProfileIndex
                              tenantId:@"tid2"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"oid2"
                           allProfiles:secondAccount.tenantProfiles
                             hasClaims:YES];
    
    
    NSInteger a2SecondProfileIndex = [self indexOfTenantProfileInArray:secondAccount.tenantProfiles localAccountId:@"guest_oid2"];
    
    [self verifyTenantProfileWithIndex:a2SecondProfileIndex
                              tenantId:@"guest_tid2"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"guest_oid2"
                           allProfiles:secondAccount.tenantProfiles
                             hasClaims:YES];
}

- (void)testAccountForHomeAccountId_whenMixLegacyAccountsAndDefaultAccountsInCache_shouldReturnThemProperly {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    [self setupMixedAccountsInCache];
    
    NSError *error;
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:@"uid.tid"];
    MSALAccount *account = [provider accountForParameters:parameters error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(account);
    
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
    XCTAssertEqualObjects(account.homeAccountId.identifier, @"uid.tid");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.lookupAccountIdentifier.homeAccountId, @"uid.tid");
    XCTAssertEqualObjects(account.identifier, @"uid.tid");
    XCTAssertTrue(account.accountClaims.count > 0);
    
    // expect 3 tenant profiles
    XCTAssertEqual(account.tenantProfiles.count, 3);
    
    NSInteger a1FirstProfileIndex = [self indexOfTenantProfileInArray:account.tenantProfiles localAccountId:@"oid"];
    
    [self verifyTenantProfileWithIndex:a1FirstProfileIndex
                              tenantId:@"tid"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"oid"
                           allProfiles:account.tenantProfiles
                             hasClaims:YES];
    
    
    NSInteger a1SecondProfileIndex = [self indexOfTenantProfileInArray:account.tenantProfiles localAccountId:@"guest_oid"];
    
    [self verifyTenantProfileWithIndex:a1SecondProfileIndex
                              tenantId:@"guest_tid"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"guest_oid"
                           allProfiles:account.tenantProfiles
                             hasClaims:NO];
    
    NSInteger a1ThirdProfileIndex = [self indexOfTenantProfileInArray:account.tenantProfiles localAccountId:@"guest2_oid"];
    
    [self verifyTenantProfileWithIndex:a1ThirdProfileIndex
                              tenantId:@"guest2_tid"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"guest2_oid"
                           allProfiles:account.tenantProfiles
                             hasClaims:YES];
}

- (void)testAccountForUsername_whenMixLegacyAccountsAndDefaultAccountsInCache_shouldReturnThemProperly {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache clientId:@"client_id"];
    
    [self setupMixedAccountsInCache];
    
    NSError *error;
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:nil username:@"user@contoso.com"];
    MSALAccount *account = [provider accountForParameters:parameters error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(account);
    
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
    XCTAssertEqualObjects(account.homeAccountId.identifier, @"uid.tid");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.lookupAccountIdentifier.homeAccountId, @"uid.tid");
    XCTAssertEqualObjects(account.identifier, @"uid.tid");
    XCTAssertTrue(account.accountClaims.count > 0);
    
    // expect 3 tenant profiles
    XCTAssertEqual(account.tenantProfiles.count, 3);
    
    NSInteger a1FirstProfileIndex = [self indexOfTenantProfileInArray:account.tenantProfiles localAccountId:@"oid"];
    
    [self verifyTenantProfileWithIndex:a1FirstProfileIndex
                              tenantId:@"tid"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"oid"
                           allProfiles:account.tenantProfiles
                             hasClaims:YES];
    
    
    NSInteger a1SecondProfileIndex = [self indexOfTenantProfileInArray:account.tenantProfiles localAccountId:@"guest_oid"];
    
    [self verifyTenantProfileWithIndex:a1SecondProfileIndex
                              tenantId:@"guest_tid"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"guest_oid"
                           allProfiles:account.tenantProfiles
                             hasClaims:NO];
    
    NSInteger a1ThirdProfileIndex = [self indexOfTenantProfileInArray:account.tenantProfiles localAccountId:@"guest2_oid"];
    
    [self verifyTenantProfileWithIndex:a1ThirdProfileIndex
                              tenantId:@"guest2_tid"
                           environment:@"login.microsoftonline.com"
                        localAccountId:@"guest2_oid"
                           allProfiles:account.tenantProfiles
                             hasClaims:YES];
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
                                 XCTAssertEqualObjects(accounts[0].environment, @"login.microsoftonline.com");
                                 XCTAssertEqualObjects(accounts[0].lookupAccountIdentifier.homeAccountId, @"uid.tid");
                                 
                                 // expect 3 tenant profiles
                                 XCTAssertEqual(accounts[0].tenantProfiles.count, 3);
                                 
                                 NSInteger a1FirstProfileIndex = [self indexOfTenantProfileInArray:accounts[0].tenantProfiles localAccountId:@"oid"];
                                 
                                 [self verifyTenantProfileWithIndex:a1FirstProfileIndex
                                                           tenantId:@"tid"
                                                        environment:@"login.microsoftonline.com"
                                                     localAccountId:@"oid"
                                                        allProfiles:accounts[0].tenantProfiles
                                                          hasClaims:YES];
                                 
                                 
                                 NSInteger a1SecondProfileIndex = [self indexOfTenantProfileInArray:accounts[0].tenantProfiles localAccountId:@"guest_oid"];
                                 
                                 [self verifyTenantProfileWithIndex:a1SecondProfileIndex
                                                           tenantId:@"guest_tid"
                                                        environment:@"login.microsoftonline.com"
                                                     localAccountId:@"guest_oid"
                                                        allProfiles:accounts[0].tenantProfiles
                                                          hasClaims:NO];
                                 
                                 NSInteger a1ThirdProfileIndex = [self indexOfTenantProfileInArray:accounts[0].tenantProfiles localAccountId:@"guest2_oid"];
                                 
                                 [self verifyTenantProfileWithIndex:a1ThirdProfileIndex
                                                           tenantId:@"guest2_tid"
                                                        environment:@"login.microsoftonline.com"
                                                     localAccountId:@"guest2_oid"
                                                        allProfiles:accounts[0].tenantProfiles
                                                          hasClaims:YES];
                                 
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

#pragma mark - External accounts

- (void)testAllAccounts_whenLegacyAccountInCache_andSameExternalAccountExists_shouldReturnOneMergedAccount
{
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"uid.tid" objectId:nil tenantId:nil];
    MSALAccount *externalAccount = [[MSALAccount alloc] initWithUsername:@"user@contoso.com" homeAccountId:accountId environment:@"login.microsoftonline.com" tenantProfiles:nil];
    MSALMockExternalAccountHandler *externalAccountsHandler = [[MSALMockExternalAccountHandler alloc] initMock];
    externalAccountsHandler.externalAccountsResult = @[externalAccount];
    
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache
                                                                             clientId:@"client_id"
                                                              externalAccountProvider:externalAccountsHandler];
    
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
    XCTAssertEqualObjects(allAccounts[0].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[0].lookupAccountIdentifier.homeAccountId, @"uid.tid");
    XCTAssertEqual(allAccounts[0].tenantProfiles.count, 1);
    XCTAssertEqualObjects(allAccounts[0].identifier, @"uid.tid");
    XCTAssertTrue(allAccounts[0].accountClaims.count > 0);
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].tenantId, @"tid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].identifier, @"oid");
    XCTAssertEqualObjects(allAccounts[0].tenantProfiles[0].tenantId, @"tid");
    XCTAssertTrue(allAccounts[0].tenantProfiles[0].claims.count > 0);
    XCTAssertNotNil([allAccounts[0] accountClaims]);
}

- (void)testAllAccounts_whenLegacyAccountInCache_andDifferentExternalAccountExists_shouldReturnTwoAccounts
{
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"uid2.utid2" objectId:@"uid2" tenantId:@"utid2"];
    
    MSALTenantProfile *firstTenantProfile = [[MSALTenantProfile alloc] initWithIdentifier:@"uid2"
                                                                                 tenantId:@"utid2"
                                                                              environment:@"login.microsoftonline.com"
                                                                      isHomeTenantProfile:YES
                                                                                   claims:@{@"home":@"claim"}];
    
    MSALTenantProfile *secondTenantProfile = [[MSALTenantProfile alloc] initWithIdentifier:@"guestid"
                                                                                  tenantId:@"guesttid"
                                                                               environment:@"login.microsoftonline.com"
                                                                       isHomeTenantProfile:NO
                                                                                    claims:@{@"guest": @"claim"}];
    
    MSALAccount *externalAccount = [[MSALAccount alloc] initWithUsername:@"user2@contoso.com"
                                                           homeAccountId:accountId
                                                             environment:@"login.microsoftonline.com"
                                                          tenantProfiles:@[firstTenantProfile, secondTenantProfile]];
    
    MSALMockExternalAccountHandler *externalAccountsHandler = [[MSALMockExternalAccountHandler alloc] initMock];
    externalAccountsHandler.externalAccountsResult = @[externalAccount];
    
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache
                                                                             clientId:@"client_id"
                                                              externalAccountProvider:externalAccountsHandler];
    
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
    XCTAssertEqual(allAccounts.count, 2);
    
    // verify first account
    MSALAccount *firstAccount = [self accountWithIdentifier:@"uid.tid" fromArray:allAccounts];
    XCTAssertNotNil(firstAccount);
    XCTAssertEqualObjects(firstAccount.username, @"user@contoso.com");
    XCTAssertEqualObjects(firstAccount.environment, @"login.microsoftonline.com");
    
    // verify external account
    MSALAccount *secondAccount = [self accountWithIdentifier:@"uid2.utid2" fromArray:allAccounts];
    XCTAssertNotNil(secondAccount);
    XCTAssertEqualObjects(secondAccount.username, @"user2@contoso.com");
    XCTAssertEqualObjects(secondAccount.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(secondAccount.accountClaims, @{@"home":@"claim"});
}

@end
