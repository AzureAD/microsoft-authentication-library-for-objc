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


@end
