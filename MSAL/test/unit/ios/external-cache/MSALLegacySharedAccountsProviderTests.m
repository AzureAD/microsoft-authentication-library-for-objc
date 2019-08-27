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

#import <XCTest/XCTest.h>
#import "MSALLegacySharedAccountsProvider.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDJsonObject.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDCacheKey.h"
#import "MSALAccount+Internal.h"
#import "MSALAccountId+Internal.h"
#import "MSALTenantProfile+Internal.h"
#import "MSIDConstants.h"
#import "MSALLegacySharedAccountTestUtil.h"
#import "MSALAccountEnumerationParameters.h"

@interface MSALLegacySharedAccountsProviderTests : XCTestCase

@property (nonatomic) MSALLegacySharedAccountsProvider *accountsProvider;
@property (nonatomic) MSIDKeychainTokenCache *keychainTokenCache;

@end

@implementation MSALLegacySharedAccountsProviderTests

#pragma mark - Setup

- (void)setUp
{
    [super setUp];
    self.accountsProvider = [[MSALLegacySharedAccountsProvider alloc] initWithSharedKeychainAccessGroup:@"com.microsoft.adalcache"
                                                                                      serviceIdentifier:@"MyAccountService"
                                                                                  applicationIdentifier:@"MyApp"];
    
    self.keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:@"com.microsoft.adalcache" error:nil];
    [self.keychainTokenCache clearWithContext:nil error:nil];
}

#pragma mark - Read

- (void)testAccountsWithParameters_whenNoAccountsInCache_shouldReturnEmptyResultsList
{
    MSALAccountEnumerationParameters *parameters = [MSALAccountEnumerationParameters new];
    
    NSError *error = nil;
    NSArray *results = [self.accountsProvider accountsWithParameters:parameters error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testAccountsWithParameters_whenEmptyBlobInCache_shouldReturnEmptyResultsList
{
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849"};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV1"];
    
    MSALAccountEnumerationParameters *parameters = [MSALAccountEnumerationParameters new];
    
    NSError *error = nil;
    NSArray *results = [self.accountsProvider accountsWithParameters:parameters error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testAccountsWithParameters_whenMatchingAccountInOlderVersion_shouldReturnThatAccount
{
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSDictionary *singleAccountBlob = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId
                                                                                                    objectId:nil
                                                                                                    tenantId:nil
                                                                                                    username:@"user@contoso.com"];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV2"];
    
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:nil username:@"user@contoso.com"];
    parameters.returnOnlySignedInAccounts = NO;
    
    NSError *error = nil;
    NSArray *results = [self.accountsProvider accountsWithParameters:parameters error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
}

- (void)testAccountsWithParameters_whenMatchingAccountInLatestVersion_shouldReturnThatAccount
{
    NSString *accountId1 = [NSUUID UUID].UUIDString;
    NSString *accountId2 = [NSUUID UUID].UUIDString;
    NSDictionary *accountBlob1 = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId1
                                                                                               objectId:@"oid1"
                                                                                               tenantId:nil
                                                                                               username:@"user@CONTOSO.com"];
    
    NSDictionary *accountBlob2 = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId2
                                                                                               objectId:@"oid2"
                                                                                               tenantId:nil
                                                                                               username:@"user2@contoso.com"];
    
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId1 : accountBlob1, accountId2 : accountBlob2};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    NSString *accountId3 = [NSUUID UUID].UUIDString;
    NSDictionary *accountBlob3 = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId3
                                                                                               objectId:@"oid3"
                                                                                               tenantId:nil
                                                                                               username:@"user@CONTOSO.com"];
    
    NSDictionary *oldAccountsBlob = @{@"lastWriteTimestamp": @"123474848", accountId3 : accountBlob3};
    [self saveAccountsBlob:oldAccountsBlob version:@"AccountsV2"];
    
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:nil username:@"user@contoso.com"];
    parameters.returnOnlySignedInAccounts = NO;
    
    NSError *error = nil;
    NSArray *results = [self.accountsProvider accountsWithParameters:parameters error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    id<MSALAccount> account = results[0];
    XCTAssertTrue([account.identifier hasPrefix:@"oid1"]);
    XCTAssertEqualObjects(account.username, @"user@CONTOSO.com");
    XCTAssertEqualObjects(account.environment, @"login.windows.net");
}

- (void)testAccountsWithParameters_whenAccountsPresent_butNotMatching_shouldReturnNilAndNilError
{
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSDictionary *singleAccountBlob = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId
                                                                                                    objectId:nil
                                                                                                    tenantId:nil
                                                                                                    username:@"user2@contoso.com"];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:nil username:@"user@contoso.com"];
    parameters.returnOnlySignedInAccounts = NO;
    
    NSError *error = nil;
    NSArray *results = [self.accountsProvider accountsWithParameters:parameters error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testAccountsWithParameters_whenCorruptSingleItem_shouldIgnoreAccount
{
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSMutableDictionary *singleAccountBlob = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId objectId:nil tenantId:nil username:@"user@contoso.com"] mutableCopy];
    singleAccountBlob[@"type"] = @"Unknown";
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:nil username:@"user@contoso.com"];
    parameters.returnOnlySignedInAccounts = NO;
    
    NSError *error = nil;
    NSArray *results = [self.accountsProvider accountsWithParameters:parameters error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

#pragma mark - Update

- (void)testUpdateAccount_whenEmptyBlob_shouldAddAccount
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849"};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    
    MSALAccount *testAccount = [MSALLegacySharedAccountTestUtil testADALAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider updateAccount:testAccount idTokenClaims:testAccount.accountClaims error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    [self verifyBlobCountWithV1Count:1 v2Count:2 v3Count:2];
}

- (void)testUpdateAccount_whenCorruptSingleEntry_shouldAddAccount
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSMutableDictionary *singleAccountBlob = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId objectId:nil tenantId:nil username:@"user@contoso.com"] mutableCopy];
    singleAccountBlob[@"type"] = @"Unknown";
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    
    MSALAccount *testAccount = [MSALLegacySharedAccountTestUtil testADALAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider updateAccount:testAccount idTokenClaims:testAccount.accountClaims error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    [self verifyBlobCountWithV1Count:1 v2Count:2 v3Count:3];
}

- (void)testUpdateAccount_whenMatchingADALAccountsPresent_shouldUpdateAccounts
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSDictionary *singleAccountBlob = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId objectId:@"uid" tenantId:nil username:@"old@contoso.com"];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    [self saveAccountsBlob:accountsBlob version:@"AccountsV2"];
    
    MSALAccount *testAccount = [MSALLegacySharedAccountTestUtil testADALAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider updateAccount:testAccount idTokenClaims:testAccount.accountClaims error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    [self verifyBlobCountWithV1Count:1 v2Count:2 v3Count:2];

    NSDictionary *v2Blob = [self readBlobWithVersion:@"AccountsV2"];
    NSString *accountIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    XCTAssertEqualObjects(v2Blob[accountId][@"signInStatus"][accountIdentifier], @"SignedIn");
    XCTAssertEqualObjects(v2Blob[accountId][@"username"], @"user@contoso.com");
    
    NSDictionary *v3Blob = [self readBlobWithVersion:@"AccountsV3"];
    XCTAssertEqualObjects(v3Blob[accountId][@"signInStatus"][accountIdentifier], @"SignedIn");
    XCTAssertEqualObjects(v3Blob[accountId][@"username"], @"user@contoso.com");
}

- (void)testUpdateAccount_whenMatchingMSAAccountsPresent_shouldUpdateAccounts
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSDictionary *singleAccountBlob = [MSALLegacySharedAccountTestUtil sampleMSAJSONDictionaryWithAccountId:accountId];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    [self saveAccountsBlob:accountsBlob version:@"AccountsV2"];
    
    MSALAccount *testAccount = [MSALLegacySharedAccountTestUtil testMSAAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider updateAccount:testAccount idTokenClaims:testAccount.accountClaims error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    [self verifyBlobCountWithV1Count:1 v2Count:2 v3Count:2];
    
    NSDictionary *v2Blob = [self readBlobWithVersion:@"AccountsV2"];
    NSString *accountIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    XCTAssertEqualObjects(v2Blob[accountId][@"signInStatus"][accountIdentifier], @"SignedIn");
    XCTAssertEqualObjects(v2Blob[accountId][@"username"], @"user@contoso.com");
    
    NSDictionary *v3Blob = [self readBlobWithVersion:@"AccountsV3"];
    XCTAssertEqualObjects(v3Blob[accountId][@"signInStatus"][accountIdentifier], @"SignedIn");
    XCTAssertEqualObjects(v3Blob[accountId][@"username"], @"user@contoso.com");
}

- (void)testUpdateAccount_whenNonMatchingAccountPresent_shouldAddAccount
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSDictionary *singleAccountBlob = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId objectId:@"uid2" tenantId:nil username:@"old@contoso.com"];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    [self saveAccountsBlob:accountsBlob version:@"AccountsV2"];
    
    MSALAccount *testAccount = [MSALLegacySharedAccountTestUtil testADALAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider updateAccount:testAccount idTokenClaims:testAccount.accountClaims error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    [self verifyBlobCountWithV1Count:1 v2Count:3 v3Count:3];
}

#pragma mark - Remove

- (void)testRemoveAccount_whenEmptyBlob_shouldUpdateTimeStamp
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849"};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    
    MSALAccount *testAccount = [MSALLegacySharedAccountTestUtil testADALAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider removeAccount:testAccount tenantProfiles:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    [self verifyBlobCountWithV1Count:1 v2Count:1 v3Count:1];
}

- (void)testRemoveAccount_whenCorruptSingleEntry_shouldUpdateTimestamp
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSMutableDictionary *singleAccountBlob = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId objectId:nil tenantId:nil username:@"user@contoso.com"] mutableCopy];
    singleAccountBlob[@"type"] = @"Unknown";
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    
    MSALAccount *testAccount = [MSALLegacySharedAccountTestUtil testADALAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider removeAccount:testAccount tenantProfiles:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    [self verifyBlobCountWithV1Count:1 v2Count:1 v3Count:2];
    
    NSMutableDictionary *v3Blob = [[self readBlobWithVersion:@"AccountsV3"] mutableCopy];
    XCTAssertEqualObjects(v3Blob[accountId], singleAccountBlob); // make sure we didn't touch corrupted dict
}

- (void)testRemoveAccount_whenMatchingAccountsPresent_shouldUpdateAccountsWithSignedOutStatus
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSDictionary *singleAccountBlob = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId objectId:@"uid" tenantId:nil username:@"old@contoso.com"];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    [self saveAccountsBlob:accountsBlob version:@"AccountsV2"];
    
    MSALAccount *testAccount = [MSALLegacySharedAccountTestUtil testADALAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider removeAccount:testAccount tenantProfiles:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    [self verifyBlobCountWithV1Count:1 v2Count:2 v3Count:2];
    
    NSDictionary *v2Blob = [self readBlobWithVersion:@"AccountsV2"];
    NSString *accountIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    XCTAssertEqualObjects(v2Blob[accountId][@"signInStatus"][accountIdentifier], @"SignedOut");
    XCTAssertEqualObjects(v2Blob[accountId][@"username"], @"user@contoso.com");
    
    NSDictionary *v3Blob = [self readBlobWithVersion:@"AccountsV3"];
    XCTAssertEqualObjects(v3Blob[accountId][@"signInStatus"][accountIdentifier], @"SignedOut");
    XCTAssertEqualObjects(v3Blob[accountId][@"username"], @"user@contoso.com");
}

- (void)testRemoveAccount_whenTenantProfilesPassed_andMatchingAccountsPresent_shouldUpdateAccountsWithSignedOutStatus
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSDictionary *singleAccountBlob = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId objectId:@"uid" tenantId:nil username:@"old@contoso.com"];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    [self saveAccountsBlob:accountsBlob version:@"AccountsV2"];
    
    MSALAccount *testAccount = [MSALLegacySharedAccountTestUtil testADALAccount];
    NSError *error = nil;
    MSALTenantProfile *tenantProfile1 = [[MSALTenantProfile alloc] initWithIdentifier:@"uid"
                                                                             tenantId:@"tid"
                                                                          environment:@"login.microoftonline.com"
                                                                  isHomeTenantProfile:YES
                                                                               claims:nil];
    
    MSALTenantProfile *tenantProfile2 = [[MSALTenantProfile alloc] initWithIdentifier:@"guest-uid"
                                                                             tenantId:@"guest-tid"
                                                                          environment:@"login.microoftonline.com"
                                                                  isHomeTenantProfile:YES
                                                                               claims:nil];
    
    BOOL result = [self.accountsProvider removeAccount:testAccount tenantProfiles:@[tenantProfile2, tenantProfile1] error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    [self verifyBlobCountWithV1Count:1 v2Count:2 v3Count:2];
    
    NSDictionary *v2Blob = [self readBlobWithVersion:@"AccountsV2"];
    NSString *accountIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    XCTAssertEqualObjects(v2Blob[accountId][@"signInStatus"][accountIdentifier], @"SignedOut");
    XCTAssertEqualObjects(v2Blob[accountId][@"username"], @"user@contoso.com");
    
    NSDictionary *v3Blob = [self readBlobWithVersion:@"AccountsV3"];
    XCTAssertEqualObjects(v3Blob[accountId][@"signInStatus"][accountIdentifier], @"SignedOut");
    XCTAssertEqualObjects(v3Blob[accountId][@"username"], @"user@contoso.com");
}

- (void)testRemoveAccount_whenNonMatchingAccountPresent_shouldOnlyUpdateTimestamps
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSDictionary *singleAccountBlob = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId objectId:@"uid2" tenantId:nil username:@"old@contoso.com"];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    [self saveAccountsBlob:accountsBlob version:@"AccountsV2"];
    
    MSALAccount *testAccount = [MSALLegacySharedAccountTestUtil testADALAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider removeAccount:testAccount tenantProfiles:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    [self verifyBlobCountWithV1Count:1 v2Count:2 v3Count:2];
    
    NSDictionary *v2Blob = [self readBlobWithVersion:@"AccountsV2"];
    XCTAssertEqualObjects(v2Blob[accountId], singleAccountBlob);
    
    NSDictionary *v3Blob = [self readBlobWithVersion:@"AccountsV3"];
    XCTAssertEqualObjects(v3Blob[accountId], singleAccountBlob);
}

#pragma mark - Asserts

- (void)verifyBlobCountWithV1Count:(NSUInteger)v1BlobCount
                           v2Count:(NSUInteger)v2BlobCount
                           v3Count:(NSUInteger)v3BlobCount
{
    NSDictionary *v1Blob = [self readBlobWithVersion:@"AccountsV1"];
    XCTAssertNotNil(v1Blob);
    XCTAssertEqual([v1Blob count], v1BlobCount);
    XCTAssertNotNil(v1Blob[@"lastWriteTimestamp"]);
    
    NSDictionary *v2Blob = [self readBlobWithVersion:@"AccountsV2"];
    XCTAssertNotNil(v2Blob);
    XCTAssertEqual([v2Blob count], v2BlobCount);
    XCTAssertNotNil(v2Blob[@"lastWriteTimestamp"]);
    XCTAssertTrue([v2Blob[@"lastWriteTimestamp"] longValue] > [v1Blob[@"lastWriteTimestamp"] longValue]);
    
    NSDictionary *v3Blob = [self readBlobWithVersion:@"AccountsV3"];
    XCTAssertNotNil(v3Blob);
    XCTAssertEqual([v3Blob count], v3BlobCount);
    XCTAssertNotNil(v3Blob[@"lastWriteTimestamp"]);
    XCTAssertTrue([v3Blob[@"lastWriteTimestamp"] longValue] > [v2Blob[@"lastWriteTimestamp"] longValue]);
}

#pragma mark - Helpers

- (void)saveAccountsBlob:(NSDictionary *)accountsBlob version:(NSString *)version
{
    MSIDJsonObject *jsonObject = [[MSIDJsonObject alloc] initWithJSONDictionary:accountsBlob error:nil];
    MSIDCacheKey *cacheKey = [[MSIDCacheKey alloc] initWithAccount:version
                                                           service:@"MyAccountService"
                                                           generic:nil
                                                              type:nil];
    
    BOOL saveResult = [self.keychainTokenCache saveJsonObject:jsonObject
                                                   serializer:[MSIDCacheItemJsonSerializer new]
                                                          key:cacheKey
                                                      context:nil
                                                        error:nil];
    XCTAssertTrue(saveResult);
}

- (NSDictionary *)readBlobWithVersion:(NSString *)version
{
    MSIDCacheKey *cacheKey = [[MSIDCacheKey alloc] initWithAccount:version
                                                           service:@"MyAccountService"
                                                           generic:nil
                                                              type:nil];
    
    NSArray *results = [self.keychainTokenCache jsonObjectsWithKey:cacheKey
                                                        serializer:[MSIDCacheItemJsonSerializer new]
                                                           context:nil
                                                             error:nil];
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 1);
    
    MSIDJsonObject *jsonObject = results[0];
    return [jsonObject jsonDictionary];
}

@end
