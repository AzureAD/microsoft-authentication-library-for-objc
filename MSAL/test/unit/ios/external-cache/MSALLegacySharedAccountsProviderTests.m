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

@interface MSALLegacySharedAccountsProviderTests : XCTestCase

@property (nonatomic) MSALLegacySharedAccountsProvider *accountsProvider;
@property (nonatomic) MSIDKeychainTokenCache *keychainTokenCache;

@end

static NSString *kDefaultTestUid = @"00000000-0000-0000-40c0-3bac188d0d10";
static NSString *kDefaultTestCid = @"40c03bac188d0d10";

@implementation MSALLegacySharedAccountsProviderTests

#pragma mark - Setup

- (void)setUp
{
    [super setUp];
    self.accountsProvider = [[MSALLegacySharedAccountsProvider alloc] initWithSharedKeychainAccessGroup:@"com.microsoft.adalcache"
                                                                                      serviceIdentifier:@"MyAccountService"
                                                                                  applicationIdentifier:@"MyApp"];
    
    self.keychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:@"com.microsoft.adalcache"];
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
    NSDictionary *singleAccountBlob = [self sampleADALJSONDictionaryWithUsername:@"user@contoso.com" accountId:accountId objectId:nil];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV2"];
    
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:nil username:@"user@contoso.com"];
    parameters.needsAssociatedRefreshToken = NO;
    
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
    NSDictionary *accountBlob1 = [self sampleADALJSONDictionaryWithUsername:@"user@CONTOSO.com" accountId:accountId1 objectId:@"oid1"];
    NSDictionary *accountBlob2 = [self sampleADALJSONDictionaryWithUsername:@"user2@contoso.com" accountId:accountId2 objectId:@"oid2"];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId1 : accountBlob1, accountId2 : accountBlob2};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    NSString *accountId3 = [NSUUID UUID].UUIDString;
    NSDictionary *accountBlob3 = [self sampleADALJSONDictionaryWithUsername:@"user@CONTOSO.com" accountId:accountId3 objectId:@"oid3"];
    NSDictionary *oldAccountsBlob = @{@"lastWriteTimestamp": @"123474848", accountId3 : accountBlob3};
    [self saveAccountsBlob:oldAccountsBlob version:@"AccountsV2"];
    
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:nil username:@"user@contoso.com"];
    parameters.needsAssociatedRefreshToken = NO;
    
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
    NSDictionary *singleAccountBlob = [self sampleADALJSONDictionaryWithUsername:@"user2@contoso.com" accountId:accountId objectId:nil];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:nil username:@"user@contoso.com"];
    parameters.needsAssociatedRefreshToken = NO;
    
    NSError *error = nil;
    NSArray *results = [self.accountsProvider accountsWithParameters:parameters error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 0);
}

- (void)testAccountsWithParameters_whenCorruptSingleItem_shouldIgnoreAccount
{
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSMutableDictionary *singleAccountBlob = [[self sampleADALJSONDictionaryWithUsername:@"user@contoso.com" accountId:accountId objectId:nil] mutableCopy];
    singleAccountBlob[@"type"] = @"Unknown";
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:nil username:@"user@contoso.com"];
    parameters.needsAssociatedRefreshToken = NO;
    
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
    
    MSALAccount *testAccount = [self testADALAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider updateAccount:testAccount idTokenClaims:testAccount.accountClaims error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    NSDictionary *v1Blob = [self readBlobWithVersion:@"AccountsV1"];
    XCTAssertNotNil(v1Blob);
    XCTAssertEqual([v1Blob count], 1);
    XCTAssertNotNil(v1Blob[@"lastWriteTimestamp"]);
    
    NSDictionary *v2Blob = [self readBlobWithVersion:@"AccountsV2"];
    XCTAssertNotNil(v2Blob);
    XCTAssertEqual([v2Blob count], 2);
    XCTAssertNotNil(v2Blob[@"lastWriteTimestamp"]);
    XCTAssertTrue([v2Blob[@"lastWriteTimestamp"] longValue] > [v1Blob[@"lastWriteTimestamp"] longValue]);
    
    NSDictionary *v3Blob = [self readBlobWithVersion:@"AccountsV3"];
    XCTAssertNotNil(v3Blob);
    XCTAssertEqual([v3Blob count], 2);
    XCTAssertNotNil(v3Blob[@"lastWriteTimestamp"]);
    XCTAssertTrue([v3Blob[@"lastWriteTimestamp"] longValue] > [v2Blob[@"lastWriteTimestamp"] longValue]);
}

- (void)testUpdateAccount_whenCorruptSingleEntry_shouldAddAccount
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSMutableDictionary *singleAccountBlob = [[self sampleADALJSONDictionaryWithUsername:@"user@contoso.com" accountId:accountId objectId:nil] mutableCopy];
    singleAccountBlob[@"type"] = @"Unknown";
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    
    MSALAccount *testAccount = [self testADALAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider updateAccount:testAccount idTokenClaims:testAccount.accountClaims error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    NSDictionary *v1Blob = [self readBlobWithVersion:@"AccountsV1"];
    XCTAssertNotNil(v1Blob);
    XCTAssertEqual([v1Blob count], 1);
    XCTAssertNotNil(v1Blob[@"lastWriteTimestamp"]);
    
    NSDictionary *v2Blob = [self readBlobWithVersion:@"AccountsV2"];
    XCTAssertNotNil(v2Blob);
    XCTAssertEqual([v2Blob count], 2);
    XCTAssertNotNil(v2Blob[@"lastWriteTimestamp"]);
    XCTAssertTrue([v2Blob[@"lastWriteTimestamp"] longValue] > [v1Blob[@"lastWriteTimestamp"] longValue]);
    
    NSDictionary *v3Blob = [self readBlobWithVersion:@"AccountsV3"];
    XCTAssertNotNil(v3Blob);
    XCTAssertEqual([v3Blob count], 3);
    XCTAssertNotNil(v3Blob[@"lastWriteTimestamp"]);
    XCTAssertTrue([v3Blob[@"lastWriteTimestamp"] longValue] > [v2Blob[@"lastWriteTimestamp"] longValue]);
}

- (void)testUpdateAccount_whenMatchingADALAccountsPresent_shouldUpdateAccounts
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSDictionary *singleAccountBlob = [self sampleADALJSONDictionaryWithUsername:@"old@contoso.com" accountId:accountId objectId:@"uid"];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    [self saveAccountsBlob:accountsBlob version:@"AccountsV2"];
    
    MSALAccount *testAccount = [self testADALAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider updateAccount:testAccount idTokenClaims:testAccount.accountClaims error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    NSDictionary *v1Blob = [self readBlobWithVersion:@"AccountsV1"];
    XCTAssertNotNil(v1Blob);
    XCTAssertEqual([v1Blob count], 1);
    XCTAssertNotNil(v1Blob[@"lastWriteTimestamp"]);
    
    NSDictionary *v2Blob = [self readBlobWithVersion:@"AccountsV2"];
    XCTAssertNotNil(v2Blob);
    XCTAssertEqual([v2Blob count], 2);
    XCTAssertNotNil(v2Blob[@"lastWriteTimestamp"]);
    NSString *accountIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    XCTAssertEqualObjects(v2Blob[accountId][@"signInStatus"][accountIdentifier], @"SignedIn");
    XCTAssertEqualObjects(v2Blob[accountId][@"username"], @"user@contoso.com");
    XCTAssertTrue([v2Blob[@"lastWriteTimestamp"] longValue] > [v1Blob[@"lastWriteTimestamp"] longValue]);
    
    NSDictionary *v3Blob = [self readBlobWithVersion:@"AccountsV3"];
    XCTAssertNotNil(v3Blob);
    XCTAssertEqual([v3Blob count], 2);
    XCTAssertNotNil(v3Blob[@"lastWriteTimestamp"]);
    XCTAssertEqualObjects(v3Blob[accountId][@"signInStatus"][accountIdentifier], @"SignedIn");
    XCTAssertEqualObjects(v3Blob[accountId][@"username"], @"user@contoso.com");
    XCTAssertTrue([v3Blob[@"lastWriteTimestamp"] longValue] > [v2Blob[@"lastWriteTimestamp"] longValue]);
}

- (void)testUpdateAccount_whenMatchingMSAAccountsPresent_shouldUpdateAccounts
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSDictionary *singleAccountBlob = [self sampleMSAJSONDictionaryWithAccountId:accountId];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    [self saveAccountsBlob:accountsBlob version:@"AccountsV2"];
    
    MSALAccount *testAccount = [self testMSAAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider updateAccount:testAccount idTokenClaims:testAccount.accountClaims error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    NSDictionary *v1Blob = [self readBlobWithVersion:@"AccountsV1"];
    XCTAssertNotNil(v1Blob);
    XCTAssertEqual([v1Blob count], 1);
    XCTAssertNotNil(v1Blob[@"lastWriteTimestamp"]);
    
    NSDictionary *v2Blob = [self readBlobWithVersion:@"AccountsV2"];
    XCTAssertNotNil(v2Blob);
    XCTAssertEqual([v2Blob count], 2);
    XCTAssertNotNil(v2Blob[@"lastWriteTimestamp"]);
    NSString *accountIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    XCTAssertEqualObjects(v2Blob[accountId][@"signInStatus"][accountIdentifier], @"SignedIn");
    XCTAssertEqualObjects(v2Blob[accountId][@"username"], @"user@contoso.com");
    XCTAssertTrue([v2Blob[@"lastWriteTimestamp"] longValue] > [v1Blob[@"lastWriteTimestamp"] longValue]);
    
    NSDictionary *v3Blob = [self readBlobWithVersion:@"AccountsV3"];
    XCTAssertNotNil(v3Blob);
    XCTAssertEqual([v3Blob count], 2);
    XCTAssertNotNil(v3Blob[@"lastWriteTimestamp"]);
    XCTAssertEqualObjects(v3Blob[accountId][@"signInStatus"][accountIdentifier], @"SignedIn");
    XCTAssertEqualObjects(v3Blob[accountId][@"username"], @"user@contoso.com");
    XCTAssertTrue([v3Blob[@"lastWriteTimestamp"] longValue] > [v2Blob[@"lastWriteTimestamp"] longValue]);
}

- (void)testUpdateAccount_whenNonMatchingAccountPresent_shouldAddAccount
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSDictionary *singleAccountBlob = [self sampleADALJSONDictionaryWithUsername:@"old@contoso.com" accountId:accountId objectId:@"uid2"];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    [self saveAccountsBlob:accountsBlob version:@"AccountsV2"];
    
    MSALAccount *testAccount = [self testADALAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider updateAccount:testAccount idTokenClaims:testAccount.accountClaims error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    NSDictionary *v1Blob = [self readBlobWithVersion:@"AccountsV1"];
    XCTAssertNotNil(v1Blob);
    XCTAssertEqual([v1Blob count], 1);
    XCTAssertNotNil(v1Blob[@"lastWriteTimestamp"]);
    
    NSDictionary *v2Blob = [self readBlobWithVersion:@"AccountsV2"];
    XCTAssertNotNil(v2Blob);
    XCTAssertEqual([v2Blob count], 3);
    XCTAssertNotNil(v2Blob[@"lastWriteTimestamp"]);
    XCTAssertTrue([v2Blob[@"lastWriteTimestamp"] longValue] > [v1Blob[@"lastWriteTimestamp"] longValue]);
    
    NSDictionary *v3Blob = [self readBlobWithVersion:@"AccountsV3"];
    XCTAssertNotNil(v3Blob);
    XCTAssertEqual([v3Blob count], 3);
    XCTAssertNotNil(v3Blob[@"lastWriteTimestamp"]);
    XCTAssertTrue([v3Blob[@"lastWriteTimestamp"] longValue] > [v2Blob[@"lastWriteTimestamp"] longValue]);
}

#pragma mark - Remove

- (void)testRemoveAccount_whenEmptyBlob_shouldUpdateTimeStamp
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849"};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    
    MSALAccount *testAccount = [self testADALAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider removeAccount:testAccount tenantProfiles:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    NSDictionary *v1Blob = [self readBlobWithVersion:@"AccountsV1"];
    XCTAssertNotNil(v1Blob);
    XCTAssertEqual([v1Blob count], 1);
    XCTAssertNotNil(v1Blob[@"lastWriteTimestamp"]);
    
    NSMutableDictionary *v2Blob = [[self readBlobWithVersion:@"AccountsV2"] mutableCopy];
    XCTAssertNotNil(v2Blob);
    XCTAssertEqual([v2Blob count], 1);
    XCTAssertNotNil(v2Blob[@"lastWriteTimestamp"]);
    XCTAssertTrue([v2Blob[@"lastWriteTimestamp"] longValue] > [v1Blob[@"lastWriteTimestamp"] longValue]);
    
    NSMutableDictionary *v3Blob = [[self readBlobWithVersion:@"AccountsV3"] mutableCopy];
    XCTAssertNotNil(v3Blob);
    XCTAssertEqual([v3Blob count], 1);
    XCTAssertNotNil(v3Blob[@"lastWriteTimestamp"]);
    XCTAssertTrue([v3Blob[@"lastWriteTimestamp"] longValue] > [v2Blob[@"lastWriteTimestamp"] longValue]);
}

- (void)testRemoveAccount_whenCorruptSingleEntry_shouldUpdateTimestamp
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSMutableDictionary *singleAccountBlob = [[self sampleADALJSONDictionaryWithUsername:@"user@contoso.com" accountId:accountId objectId:nil] mutableCopy];
    singleAccountBlob[@"type"] = @"Unknown";
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    
    MSALAccount *testAccount = [self testADALAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider removeAccount:testAccount tenantProfiles:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    NSDictionary *v1Blob = [self readBlobWithVersion:@"AccountsV1"];
    XCTAssertNotNil(v1Blob);
    XCTAssertEqual([v1Blob count], 1);
    XCTAssertNotNil(v1Blob[@"lastWriteTimestamp"]);
    
    NSMutableDictionary *v2Blob = [[self readBlobWithVersion:@"AccountsV2"] mutableCopy];
    XCTAssertNotNil(v2Blob);
    XCTAssertEqual([v2Blob count], 1);
    XCTAssertNotNil(v2Blob[@"lastWriteTimestamp"]);
    XCTAssertTrue([v2Blob[@"lastWriteTimestamp"] longValue] > [v1Blob[@"lastWriteTimestamp"] longValue]);
    
    NSMutableDictionary *v3Blob = [[self readBlobWithVersion:@"AccountsV3"] mutableCopy];
    XCTAssertNotNil(v3Blob);
    XCTAssertEqual([v3Blob count], 2);
    XCTAssertEqualObjects(v3Blob[accountId], singleAccountBlob); // make sure we didn't touch corrupted dict
    XCTAssertNotNil(v3Blob[@"lastWriteTimestamp"]);
    XCTAssertTrue([v3Blob[@"lastWriteTimestamp"] longValue] > [v2Blob[@"lastWriteTimestamp"] longValue]);
}

- (void)testRemoveAccount_whenMatchingAccountsPresent_shouldUpdateAccountsWithSignedOutStatus
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSDictionary *singleAccountBlob = [self sampleADALJSONDictionaryWithUsername:@"old@contoso.com" accountId:accountId objectId:@"uid"];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    [self saveAccountsBlob:accountsBlob version:@"AccountsV2"];
    
    MSALAccount *testAccount = [self testADALAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider removeAccount:testAccount tenantProfiles:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    NSDictionary *v1Blob = [self readBlobWithVersion:@"AccountsV1"];
    XCTAssertNotNil(v1Blob);
    XCTAssertEqual([v1Blob count], 1);
    XCTAssertNotNil(v1Blob[@"lastWriteTimestamp"]);
    
    NSDictionary *v2Blob = [self readBlobWithVersion:@"AccountsV2"];
    XCTAssertNotNil(v2Blob);
    XCTAssertEqual([v2Blob count], 2);
    XCTAssertNotNil(v2Blob[@"lastWriteTimestamp"]);
    NSString *accountIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    XCTAssertEqualObjects(v2Blob[accountId][@"signInStatus"][accountIdentifier], @"SignedOut");
    XCTAssertEqualObjects(v2Blob[accountId][@"username"], @"user@contoso.com");
    XCTAssertTrue([v2Blob[@"lastWriteTimestamp"] longValue] > [v1Blob[@"lastWriteTimestamp"] longValue]);
    
    NSDictionary *v3Blob = [self readBlobWithVersion:@"AccountsV3"];
    XCTAssertNotNil(v3Blob);
    XCTAssertEqual([v3Blob count], 2);
    XCTAssertNotNil(v3Blob[@"lastWriteTimestamp"]);
    XCTAssertEqualObjects(v3Blob[accountId][@"signInStatus"][accountIdentifier], @"SignedOut");
    XCTAssertEqualObjects(v3Blob[accountId][@"username"], @"user@contoso.com");
    XCTAssertTrue([v3Blob[@"lastWriteTimestamp"] longValue] > [v2Blob[@"lastWriteTimestamp"] longValue]);
}

- (void)testRemoveAccount_whenTenantProfilesPassed_andMatchingAccountsPresent_shouldUpdateAccountsWithSignedOutStatus
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSDictionary *singleAccountBlob = [self sampleADALJSONDictionaryWithUsername:@"old@contoso.com" accountId:accountId objectId:@"uid"];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    [self saveAccountsBlob:accountsBlob version:@"AccountsV2"];
    
    MSALAccount *testAccount = [self testADALAccount];
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
    
    NSDictionary *v1Blob = [self readBlobWithVersion:@"AccountsV1"];
    XCTAssertNotNil(v1Blob);
    XCTAssertEqual([v1Blob count], 1);
    XCTAssertNotNil(v1Blob[@"lastWriteTimestamp"]);
    
    NSDictionary *v2Blob = [self readBlobWithVersion:@"AccountsV2"];
    XCTAssertNotNil(v2Blob);
    XCTAssertEqual([v2Blob count], 2);
    XCTAssertNotNil(v2Blob[@"lastWriteTimestamp"]);
    NSString *accountIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    XCTAssertEqualObjects(v2Blob[accountId][@"signInStatus"][accountIdentifier], @"SignedOut");
    XCTAssertEqualObjects(v2Blob[accountId][@"username"], @"user@contoso.com");
    XCTAssertTrue([v2Blob[@"lastWriteTimestamp"] longValue] > [v1Blob[@"lastWriteTimestamp"] longValue]);
    
    NSDictionary *v3Blob = [self readBlobWithVersion:@"AccountsV3"];
    XCTAssertNotNil(v3Blob);
    XCTAssertEqual([v3Blob count], 2);
    XCTAssertNotNil(v3Blob[@"lastWriteTimestamp"]);
    XCTAssertEqualObjects(v3Blob[accountId][@"signInStatus"][accountIdentifier], @"SignedOut");
    XCTAssertEqualObjects(v3Blob[accountId][@"username"], @"user@contoso.com");
    XCTAssertTrue([v3Blob[@"lastWriteTimestamp"] longValue] > [v2Blob[@"lastWriteTimestamp"] longValue]);
}

- (void)testRemoveAccount_whenNonMatchingAccountPresent_shouldOnlyUpdateTimestamps
{
    self.accountsProvider.sharedAccountMode = MSALLegacySharedAccountModeReadWrite;
    
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSDictionary *singleAccountBlob = [self sampleADALJSONDictionaryWithUsername:@"old@contoso.com" accountId:accountId objectId:@"uid2"];
    NSDictionary *accountsBlob = @{@"lastWriteTimestamp": @"123474849", accountId : singleAccountBlob};
    [self saveAccountsBlob:accountsBlob version:@"AccountsV3"];
    [self saveAccountsBlob:accountsBlob version:@"AccountsV2"];
    
    MSALAccount *testAccount = [self testADALAccount];
    NSError *error = nil;
    BOOL result = [self.accountsProvider removeAccount:testAccount tenantProfiles:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    NSDictionary *v1Blob = [self readBlobWithVersion:@"AccountsV1"];
    XCTAssertNotNil(v1Blob);
    XCTAssertEqual([v1Blob count], 1);
    XCTAssertNotNil(v1Blob[@"lastWriteTimestamp"]);
    
    NSDictionary *v2Blob = [self readBlobWithVersion:@"AccountsV2"];
    XCTAssertNotNil(v2Blob);
    XCTAssertEqual([v2Blob count], 2);
    XCTAssertEqualObjects(v2Blob[accountId], singleAccountBlob);
    XCTAssertNotNil(v2Blob[@"lastWriteTimestamp"]);
    XCTAssertTrue([v2Blob[@"lastWriteTimestamp"] longValue] > [v1Blob[@"lastWriteTimestamp"] longValue]);
    
    NSDictionary *v3Blob = [self readBlobWithVersion:@"AccountsV3"];
    XCTAssertNotNil(v3Blob);
    XCTAssertEqual([v3Blob count], 2);
    XCTAssertNotNil(v3Blob[@"lastWriteTimestamp"]);
    XCTAssertEqualObjects(v3Blob[accountId], singleAccountBlob);
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

- (MSALAccount *)testADALAccount
{
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"uid.utid"
                                                                       objectId:@"uid"
                                                                       tenantId:@"utid"];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:nil];
    
    account.accountClaims = @{@"name": @"Contoso User",
                              @"oid": @"uid",
                              @"tid": @"utid"
                              };
    
    return account;
}

- (MSALAccount *)testMSAAccount
{
    NSString *accountidentifier = [NSString stringWithFormat:@"%@.%@", kDefaultTestUid, MSID_DEFAULT_MSA_TENANTID.lowercaseString];
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:accountidentifier
                                                                       objectId:kDefaultTestUid
                                                                       tenantId:MSID_DEFAULT_MSA_TENANTID.lowercaseString];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:nil];
    
    account.accountClaims = @{@"name": @"Contoso User",
                              @"oid": @"uid",
                              @"tid": @"utid"
                              };
    
    return account;
}

- (NSDictionary *)sampleADALJSONDictionaryWithUsername:(NSString *)username
                                             accountId:(NSString *)accountId
                                              objectId:(NSString *)objectId
{
    return @{@"authEndpointUrl": @"https://login.windows.net/common/oauth2/authorize",
             @"id": accountId ?: [NSUUID UUID].UUIDString,
             @"environment": @"PROD",
             @"oid": objectId ?: [NSUUID UUID].UUIDString,
             @"originAppId": @"com.myapp.app",
             @"tenantDisplayName": @"",
             @"type": @"ADAL",
             @"displayName": @"myDisplayName.contoso.user",
             @"tenantId": [NSUUID UUID].UUIDString,
             @"username": username ?: @"user@contoso.com"
             };
}

- (NSDictionary *)sampleMSAJSONDictionaryWithAccountId:(NSString *)accountIdentifier
{
    return @{@"cid": kDefaultTestCid,
             @"email": @"user@outlook.com",
             @"id": accountIdentifier ?: [NSUUID UUID].UUIDString,
             @"originAppId": @"com.myapp.app",
             @"type": @"MSA",
             @"displayName": @"MyDisplayName",
             @"additionalProperties": @{@"myprop1": @"myprop2"},
             @"additionalfield1": @"additionalvalue1"
             };
}

@end
