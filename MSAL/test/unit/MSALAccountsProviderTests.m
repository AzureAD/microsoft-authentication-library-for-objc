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

#import "MSALTestCase.h"
#import "MSALAccountsProvider.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDTestCacheDataSource.h"
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
#import "MSALAccountEnumerationParameters.h"
#import "MSALMockExternalAccountHandler.h"
#import "MSALAADOauth2Provider.h"
#import "MSALAccountId+Internal.h"
#import "MSALTenantProfile+Internal.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDTestSwizzle.h"
#import "MSIDSSOExtensionGetAccountsRequest.h"
#import "MSIDAccount.h"
#import "MSIDRequestParameters.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDTestParametersProvider.h"

@interface MSALAccountsProviderTests : MSALTestCase

@end

@implementation MSALAccountsProviderTests
{
    MSIDDefaultTokenCacheAccessor *defaultCache;
    MSIDLegacyTokenCacheAccessor *legacyCache;
    MSIDAccountMetadataCacheAccessor *accountMetadataCache;
}

- (void)setUp
{
    [super setUp];

    MSIDTestCacheDataSource *dataSource = [MSIDTestCacheDataSource new];
    
    legacyCache = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:dataSource
                                                       otherCacheAccessors:@[]];
    defaultCache = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:@[legacyCache]];
    
    accountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
}

- (void)tearDown
{
    [MSIDTestSwizzle reset];
    defaultCache = nil;
    legacyCache = nil;
    accountMetadataCache = nil;

    [super tearDown];
}

- (void)testAllAccounts_whenNoAccountInCache_shouldReturnEmptyList {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache accountMetadataCache:accountMetadataCache clientId:@"a_different_client_id"];
    
    NSError *error;
    NSArray *allAccounts = [provider allAccounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertEqual(allAccounts.count, 0);
}

- (void)testAllAccounts_whenAccountWithDifferentClientIdInCache_shouldReturnEmptyList {
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache accountMetadataCache:accountMetadataCache clientId:@"some_client_id"];
    
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
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache accountMetadataCache:accountMetadataCache clientId:@"client_id"];
    
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
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache accountMetadataCache:accountMetadataCache clientId:@"client_id"];
    
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
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache accountMetadataCache:accountMetadataCache clientId:@"client_id"];
    
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
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache accountMetadataCache:accountMetadataCache clientId:@"client_id"];
    
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
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache accountMetadataCache:accountMetadataCache clientId:@"client_id"];
    
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
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache accountMetadataCache:accountMetadataCache clientId:@"client_id"];
    
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
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache accountMetadataCache:accountMetadataCache clientId:@"client_id"];
    
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
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache accountMetadataCache:accountMetadataCache clientId:@"client_id"];
    
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
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache accountMetadataCache:accountMetadataCache clientId:@"client_id"];
    
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
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache accountMetadataCache:accountMetadataCache clientId:@"client_id"];
    
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
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache accountMetadataCache:accountMetadataCache clientId:@"client_id"];
    
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

- (void)testAccountsForParameters_whenTenantProfileIdentifierUsesDifferentCase_shouldReturnMatchingProfile
{
    [self setupMixedAccountsInCache];
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache
                                                              accountMetadataCache:accountMetadataCache
                                                                          clientId:@"client_id"];
    MSALAccountEnumerationParameters *parameters =
        [[MSALAccountEnumerationParameters alloc] initWithTenantProfileIdentifier:@"GUEST2_OID"];

    NSError *error = nil;
    NSArray<MSALAccount *> *accounts = [provider accountsForParameters:parameters error:&error];

    XCTAssertNotNil(accounts);
    XCTAssertNil(error);
    XCTAssertEqual(accounts.count, 1);
    XCTAssertEqualObjects(accounts.firstObject.identifier, @"uid.tid");
    XCTAssertEqual(accounts.firstObject.tenantProfiles.count, 1);
    XCTAssertEqualObjects(accounts.firstObject.tenantProfiles.firstObject.identifier, @"guest2_oid");
    XCTAssertEqualObjects(accounts.firstObject.tenantProfiles.firstObject.tenantId, @"guest2_tid");
}

- (void)testAccountsForParameters_whenIdentifierAndUsernameReferToDifferentAccounts_shouldReturnNoAccounts
{
    [self setupMixedAccountsInCache];
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache
                                                              accountMetadataCache:accountMetadataCache
                                                                          clientId:@"client_id"];
    MSALAccountEnumerationParameters *parameters =
        [[MSALAccountEnumerationParameters alloc] initWithIdentifier:@"uid.tid" username:@"user@fabricant.com"];

    NSError *error = nil;
    NSArray<MSALAccount *> *accounts = [provider accountsForParameters:parameters error:&error];

    XCTAssertNotNil(accounts);
    XCTAssertNil(error);
    XCTAssertEqual(accounts.count, 0);
}

- (void)testCurrentPrincipalAccount_whenNoPrincipalIsStored_shouldReturnNil
{
    [self setupMixedAccountsInCache];
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache
                                                              accountMetadataCache:accountMetadataCache
                                                                          clientId:@"client_id"];

    NSError *error = nil;
    MSALAccount *account = [provider currentPrincipalAccount:&error];

    XCTAssertNil(account);
    XCTAssertNil(error);
}

- (void)testCurrentPrincipalAccount_whenPrincipalIsMissingFromTokenCache_shouldRecoverStoredIdentity
{
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache
                                                              accountMetadataCache:accountMetadataCache
                                                                          clientId:@"client_id"];
    MSIDAccountIdentifier *identifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com"
                                                                             homeAccountId:@"uid.tid"];
    NSError *error = nil;
    BOOL updated = [provider setCurrentPrincipalAccountId:identifier accountEnvironment:@"login.microsoftonline.com" error:&error];
    XCTAssertTrue(updated);
    XCTAssertNil(error);

    MSALAccount *account = [provider currentPrincipalAccount:&error];

    XCTAssertNotNil(account);
    XCTAssertNil(error);
    XCTAssertEqualObjects(account.identifier, @"uid.tid");
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.homeAccountId.objectId, @"uid");
    XCTAssertEqualObjects(account.homeAccountId.tenantId, @"tid");
    XCTAssertEqual(account.tenantProfiles.count, 0);
    XCTAssertNil(account.accountClaims);
}

- (void)testCurrentPrincipalAccount_whenPrincipalIsInTokenCache_shouldReturnCachedProfilesAndClaims
{
    [self setupMixedAccountsInCache];
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache
                                                              accountMetadataCache:accountMetadataCache
                                                                          clientId:@"client_id"];
    MSIDAccountIdentifier *identifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"old@contoso.com"
                                                                             homeAccountId:@"uid.tid"];
    NSError *error = nil;
    BOOL updated = [provider setCurrentPrincipalAccountId:identifier accountEnvironment:@"login.microsoftonline.com" error:&error];
    XCTAssertTrue(updated);
    XCTAssertNil(error);

    MSALAccount *account = [provider currentPrincipalAccount:&error];

    XCTAssertNotNil(account);
    XCTAssertNil(error);
    XCTAssertEqualObjects(account.identifier, @"uid.tid");
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
    XCTAssertEqual(account.tenantProfiles.count, 3);
    XCTAssertTrue(account.accountClaims.count > 0);
    XCTAssertEqualObjects(account.accountClaims[@"oid"], @"oid");
    XCTAssertEqualObjects(account.accountClaims[@"tid"], @"tid");

    NSDictionary<NSString *, NSString *> *expectedTenants = @{@"oid": @"tid",
                                                            @"guest_oid": @"guest_tid",
                                                            @"guest2_oid": @"guest2_tid"};
    XCTAssertEqualObjects([NSSet setWithArray:[account.tenantProfiles valueForKey:@"identifier"]],
                          [NSSet setWithArray:expectedTenants.allKeys]);
    for (MSALTenantProfile *profile in account.tenantProfiles)
    {
        XCTAssertEqualObjects(profile.tenantId, expectedTenants[profile.identifier]);
        XCTAssertEqualObjects(profile.environment, @"login.microsoftonline.com");
    }
}

- (void)testCurrentPrincipalAccount_whenPrincipalIsCleared_shouldNotReturnAnotherCachedAccount
{
    [self setupMixedAccountsInCache];
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache
                                                              accountMetadataCache:accountMetadataCache
                                                                          clientId:@"client_id"];
    MSIDAccountIdentifier *identifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com"
                                                                             homeAccountId:@"uid.tid"];
    NSError *error = nil;
    BOOL updated = [provider setCurrentPrincipalAccountId:identifier accountEnvironment:@"login.microsoftonline.com" error:&error];
    XCTAssertTrue(updated);
    XCTAssertNil(error);

    BOOL cleared = [provider setCurrentPrincipalAccountId:nil accountEnvironment:nil error:&error];
    XCTAssertTrue(cleared);
    XCTAssertNil(error);

    MSALAccount *account = [provider currentPrincipalAccount:&error];

    XCTAssertNil(account);
    XCTAssertNil(error);
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
    externalAccount.isSSOAccount = YES;
    MSALMockExternalAccountHandler *externalAccountsHandler = [[MSALMockExternalAccountHandler alloc] initMock];
    externalAccountsHandler.externalAccountsResult = @[externalAccount];
    
    MSALAccountsProvider *provider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache
                                                                 accountMetadataCache:accountMetadataCache
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
    XCTAssertTrue(allAccounts[0].isSSOAccount);
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
                                                                 accountMetadataCache:accountMetadataCache
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

#pragma mark - AllAccountsFromDevice

- (void)testAllAccountsFromDevice_whenCurrentSSOExtensionAlreadyPresent_shouldReturnNilAndFillError
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetAccountsRequest class]
                           block:(id)^(id obj)
    {
        return YES;
    }];
    
    MSALAccountsProvider *accountsProvider = [[MSALAccountsProvider alloc] initWithTokenCache:nil
                                                                         accountMetadataCache:nil
                                                                                     clientId:@"myclientid"];
        
    __block MSIDGetAccountsRequestCompletionBlock pendingCompletion = nil;
    
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetAccountsRequest  class]
                              block:(id)^(id obj, MSIDGetAccountsRequestCompletionBlock callback)
    {
        pendingCompletion = [callback copy];
    }];
    
    MSALAccountEnumerationParameters *params = [MSALAccountEnumerationParameters new];
    XCTestExpectation *expectation = [self expectationWithDescription:@"All Accounts"];
    XCTestExpectation *failExpectation = [self expectationWithDescription:@"Failed expectation"];
    expectation.assertForOverFulfill = YES;
    failExpectation.assertForOverFulfill = YES;
    
    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    requestParams.validateAuthority = YES;
    
    [accountsProvider allAccountsFromDevice:params
                          requestParameters:requestParams
                            completionBlock:^(NSArray<MSALAccount *> * _Nullable accounts, NSError * _Nullable error) {
        XCTAssertNotNil(accounts);
        XCTAssertEqual(accounts.count, 0);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    
    [accountsProvider allAccountsFromDevice:params
                          requestParameters:requestParams
                            completionBlock:^(NSArray<MSALAccount *> * _Nullable accounts, NSError * _Nullable error) {
        
        XCTAssertNil(accounts);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInternal);
        [failExpectation fulfill];
    }];

    XCTAssertNotNil(pendingCompletion);
    if (pendingCompletion)
    {
        pendingCompletion(@[], NO, nil);
        pendingCompletion = nil;
    }
    
    [self waitForExpectations:@[expectation, failExpectation] timeout:1];
}

- (void)testAllAccuntsFromDevice_whenSSOExtensionNotAvailable_shouldReturnLocalAccounts
{
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
    
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetAccountsRequest class]
                           block:(id)^(id obj)
    {
        return NO;
    }];
    
    MSALAccountsProvider *accountsProvider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache
                                                                         accountMetadataCache:nil
                                                                                     clientId:@"client_id"];
        
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    expectation.inverted = YES;
    
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetAccountsRequest  class]
                              block:(id)^(id obj, MSIDGetAccountsRequestCompletionBlock callback)
    {
        [expectation fulfill];
    }];
    
    MSALAccountEnumerationParameters *params = [MSALAccountEnumerationParameters new];
    XCTestExpectation *allAccountsExpectation = [self expectationWithDescription:@"All Accounts"];
    
    [accountsProvider allAccountsFromDevice:params
                          requestParameters:[MSIDRequestParameters new]
                            completionBlock:^(NSArray<MSALAccount *> * _Nullable accounts, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(accounts);
        XCTAssertEqual([accounts count], 1);
        [allAccountsExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation, allAccountsExpectation] timeout:1];
}

- (void)testAllAccountsFromDevice_whenSSOExtensionPresent_encounteredError_shouldReturnError
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetAccountsRequest class]
                           block:(id)^(id obj)
    {
        return YES;
    }];
    
    MSALAccountsProvider *accountsProvider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache
                                                                         accountMetadataCache:nil
                                                                                     clientId:@"client_id"];
        
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetAccountsRequest  class]
                              block:(id)^(id obj, MSIDGetAccountsRequestCompletionBlock callback)
    {
        [expectation fulfill];
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUnsupportedFunctionality, @"Unsupported functionality", nil, nil, nil, nil, nil, NO);
        callback(nil, NO, error);
    }];
    
    MSALAccountEnumerationParameters *params = [MSALAccountEnumerationParameters new];
    XCTestExpectation *allAccountsExpectation = [self expectationWithDescription:@"All Accounts"];
    
    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    requestParams.validateAuthority = YES;
    
    [accountsProvider allAccountsFromDevice:params
                          requestParameters:requestParams
                            completionBlock:^(NSArray<MSALAccount *> * _Nullable accounts, NSError * _Nullable error) {
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorUnsupportedFunctionality);
        XCTAssertNil(accounts);
        XCTAssertEqual([accounts count], 0);
        [allAccountsExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation, allAccountsExpectation] timeout:1];
}

- (void)testAllAccountsFromDevice_whenSSOExtensionPresent_andReturnedAccounts_shouldCombineWithLocalAccounts
{
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.windows.net/tid"
         clientId:@"client_id"
              upn:@"user@contoso.com"
             name:@"simple_user"
              uid:@"uid"
             utid:@"tid"
              oid:@"oid"
         tenantId:@"tid"
         familyId:nil
    cacheAccessor:defaultCache];
    
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetAccountsRequest class]
                           block:(id)^(id obj)
    {
        return YES;
    }];
    
    MSALAccountsProvider *accountsProvider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache
                                                                         accountMetadataCache:nil
                                                                                     clientId:@"client_id"];
        
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetAccountsRequest  class]
                              block:(id)^(id obj, MSIDGetAccountsRequestCompletionBlock callback)
    {
        [expectation fulfill];
        
        MSIDAccount *account2 = [MSIDAccount new];
        account2.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com" homeAccountId:@"uid.tid"];
        account2.environment = @"login.windows.net";
        
        MSIDAccount *account3 = [MSIDAccount new];
        account3.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user2@contoso.com" homeAccountId:@"uid2.utid"];
        account3.environment = @"login.windows.net";
        
        callback(@[account2, account3], NO, nil);
    }];
    
    MSALAccountEnumerationParameters *params = [MSALAccountEnumerationParameters new];
    XCTestExpectation *allAccountsExpectation = [self expectationWithDescription:@"All Accounts"];
    
    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    requestParams.validateAuthority = YES;
    
    [accountsProvider allAccountsFromDevice:params
                          requestParameters:requestParams
                            completionBlock:^(NSArray<MSALAccount *> * _Nullable accounts, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(accounts);
        XCTAssertEqual([accounts count], 2);
        
        MSALAccount *firstAccount = [self accountWithIdentifier:@"uid.tid" fromArray:accounts];
        XCTAssertNotNil(firstAccount);
        XCTAssertEqualObjects(firstAccount.identifier, @"uid.tid");
        
        MSALAccount *secondAccount = [self accountWithIdentifier:@"uid2.utid" fromArray:accounts];
        XCTAssertNotNil(secondAccount);
        XCTAssertEqualObjects(secondAccount.identifier, @"uid2.utid");
        
        [allAccountsExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation, allAccountsExpectation] timeout:1];
}

- (void)testAllAccountsFromDevice_whenSSOExtensionPresent_andReturnedAccounts_andReturnBrokerAccountsOnlyYES_shouldReturnBrokerAccountsOnly
{
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
    
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetAccountsRequest class]
                           block:(id)^(id obj)
    {
        return YES;
    }];
    
    MSALAccountsProvider *accountsProvider = [[MSALAccountsProvider alloc] initWithTokenCache:defaultCache
                                                                         accountMetadataCache:nil
                                                                                     clientId:@"client_id"];
        
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetAccountsRequest  class]
                              block:(id)^(id obj, MSIDGetAccountsRequestCompletionBlock callback)
    {
        [expectation fulfill];
        
        MSIDAccount *account3 = [MSIDAccount new];
        account3.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user2@contoso.com" homeAccountId:@"uid2.utid"];
        account3.environment = @"login.microsoftonline.com";
        
        callback(@[account3], YES, nil);
    }];
    
    MSALAccountEnumerationParameters *params = [MSALAccountEnumerationParameters new];
    XCTestExpectation *allAccountsExpectation = [self expectationWithDescription:@"All Accounts"];
    
    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    requestParams.validateAuthority = YES;
    
    [accountsProvider allAccountsFromDevice:params
                          requestParameters:requestParams
                            completionBlock:^(NSArray<MSALAccount *> * _Nullable accounts, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(accounts);
        XCTAssertEqual([accounts count], 1);
        
        MSALAccount *account = accounts[0];
        XCTAssertEqualObjects(account.identifier, @"uid2.utid");
        
        [allAccountsExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation, allAccountsExpectation] timeout:1];
}

@end
