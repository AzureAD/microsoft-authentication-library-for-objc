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
#import "MSALTestTokenCache.h"
#import "MSALIdToken.h"
#import "MSALTokenResponse.h"
#import "MSALClientInfo.h"

#import "MSALTestIdTokenUtil.h"
#import "MSALTestTokenCacheItemUtil.h"

#import "NSDictionary+MSALTestUtil.h"
#import "NSURL+MSALExtensions.h"

// There are keychain entitlement bugs with the simulator in unit test runs where the simulator can
// lose its entitlements between the first use of the keychain and when these get hit, so we added
// a "1" to the name of these tests to make sure they're the first ones run. :)
@interface MSAL1KeychainTokenCacheTests : XCTestCase
{
    NSURL *_testAuthority;
    NSString *_testEnvironment;
    NSString *_testClientId;
    
    MSALKeychainTokenCache *_dataSource;
    
    NSDictionary *_testResponse1Claims;
    MSALTokenResponse *_testTokenResponse;
    NSString *_userIdentifier1;
    
    NSDictionary *_testResponse2Claims;
    MSALTokenResponse *_testTokenResponse2;
    NSString *_userIdentifier2;
}


@end

static NSString *MakeIdToken(NSString *name, NSString *preferredUsername)
{
    return [MSALTestIdTokenUtil idTokenWithName:name preferredUsername:preferredUsername];
}

@implementation MSAL1KeychainTokenCacheTests

- (void)setUp
{
    [super setUp];
    
    _dataSource = MSALKeychainTokenCache.defaultKeychainCache;
    [_dataSource testRemoveAll];
    
    _testAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    _testEnvironment = _testAuthority.msalHostWithPort;
    _testClientId = @"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc";
    
    NSString *idToken1 = MakeIdToken(@"User 1", @"user1@contoso.com");
    NSString *clientInfo1 = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} base64UrlJson];
    _userIdentifier1 = @"1.1234-5678-90abcdefg";
    
    _testResponse1Claims =
    @{ @"token_type" : @"Bearer",
       @"authority" : _testAuthority,
       @"scope" : @"mail.read user.read",
       @"expires_in" : @"3599",
       @"ext_expires_in" : @"10800",
       @"access_token" : @"fake-access-token",
       @"refresh_token" : @"fake-refresh-token",
       @"id_token" : idToken1,
       @"client_info" : clientInfo1
    };
   
    NSError *error = nil;
    _testTokenResponse = [[MSALTokenResponse alloc] initWithJson:_testResponse1Claims error:&error];
    XCTAssertNotNil(_testTokenResponse);
    XCTAssertNil(error);
    
    NSString *idToken2 = MakeIdToken(@"User 2", @"user2@contoso.com");
    NSString *clientInfo2 = [@{ @"uid" : @"2", @"utid" : @"1234-5678-90abcdefg"} base64UrlJson];
    _userIdentifier2 = @"2.1234-5678-90abcdefg";
    
    _testResponse2Claims =
    @{ @"token_type" : @"Bearer",
       @"scope" : @"mail.read user.read",
       @"authority" : _testAuthority,
       @"expires_in" : @"3599",
       @"ext_expires_in" : @"10800",
       @"access_token" : @"fake-access-token",
       @"refresh_token" : @"fake-refresh-token",
       @"id_token" : idToken2,
       @"client_info" : clientInfo2
       };
    
    _testTokenResponse2 = [[MSALTokenResponse alloc] initWithJson:_testResponse2Claims error:nil];

}

- (void)tearDown
{
    [_dataSource testRemoveAll];
    
    [super tearDown];
}

- (void)testBadInit
{
    XCTAssertThrows([MSALKeychainTokenCache new]);
}

- (void)testSaveAndRetrieveAccessToken
{
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                  clientId:_testClientId
                                                                                  response:_testTokenResponse];
    NSError *error = nil;
    XCTAssertTrue([_dataSource addOrUpdateAccessTokenItem:atItem context:nil error:&error]);
    XCTAssertNil(error);
    
    //retrieve AT
    MSALAccessTokenCacheKey *atKey =
    [[MSALAccessTokenCacheKey alloc] initWithAuthority:_testAuthority.absoluteString
                                              clientId:_testClientId
                                                 scope:[NSOrderedSet orderedSetWithObjects:@"mail.read", @"user.read", nil]
                                        userIdentifier:_userIdentifier1
                                           environment:_testEnvironment];
    XCTAssertNotNil(atKey);
    NSArray<MSALAccessTokenCacheItem *> *items = [_dataSource getAccessTokenItemsWithKey:atKey
                                                                           context:nil
                                                                                   error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(items);
    XCTAssertEqual(items.count, 1);
    
    
    MSALAccessTokenCacheItem *atItemInCache = items[0];
    XCTAssertNotNil(atItemInCache);
    XCTAssertNil(error);
    
    //compare AT with the AT retrieved from cache
    XCTAssertEqualObjects(atItem, atItemInCache);
}

- (void)testSaveIdenticalATMultipleTimes_shouldReturnOnlyOneAT
{
    XCTAssertEqual([_dataSource getAccessTokenItemsWithKey:nil context:nil error:nil].count, 0);
    
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                  clientId:_testClientId
                                                                                  response:_testTokenResponse];
    NSError *error = nil;
    XCTAssertTrue([_dataSource addOrUpdateAccessTokenItem:atItem context:nil error:&error]);
    XCTAssertNil(error);
    
    XCTAssertEqual([_dataSource getAccessTokenItemsWithKey:nil context:nil error:nil].count, 1);
    
    //save the same AT again
    XCTAssertTrue([_dataSource addOrUpdateAccessTokenItem:atItem context:nil error:&error]);
    XCTAssertNil(error);
    
    XCTAssertEqual([_dataSource getAccessTokenItemsWithKey:nil context:nil error:nil].count, 1);
}

- (void)testRetrieve_whenInsufficientScopes_shouldNotReturnItem
{
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                  clientId:_testClientId
                                                                                  response:_testTokenResponse];
    NSError *error = nil;
    XCTAssertTrue([_dataSource addOrUpdateAccessTokenItem:atItem context:nil error:&error]);
    XCTAssertNil(error);
    
    //retrieve AT
    MSALAccessTokenCacheKey *atKey =
    [[MSALAccessTokenCacheKey alloc] initWithAuthority:_testAuthority.absoluteString
                                              clientId:_testClientId
                                                 scope:[NSOrderedSet orderedSetWithObjects:@"User.Read", @"User.Write", nil]
                                        userIdentifier:_userIdentifier1
                                           environment:_testEnvironment];
    XCTAssertNotNil(atKey);
    NSArray<MSALAccessTokenCacheItem *> *items = [_dataSource getAccessTokenItemsWithKey:atKey
                                                                           context:nil
                                                                                   error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(items);
    XCTAssertEqual(items.count, 0);
}

- (void)testSaveAT_whenMultipleUsers_shouldCoexist
{
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                  clientId:_testClientId
                                                                                  response:_testTokenResponse];
    NSError *error = nil;
    XCTAssertTrue([_dataSource addOrUpdateAccessTokenItem:atItem context:nil error:&error]);
    XCTAssertNil(error);
    
    
    
    //save a second AT
    MSALAccessTokenCacheItem *atItem2 = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                   clientId:_testClientId
                                                                                   response:_testTokenResponse2];
    XCTAssertTrue([_dataSource addOrUpdateAccessTokenItem:atItem2 context:nil error:&error]);
    XCTAssertNil(error);
    
    XCTAssertEqual([_dataSource getAccessTokenItemsWithKey:nil context:nil error:nil].count, 2);
}

- (void)testSaveAndRetrieveRefreshToken
{
    //prepare token response and save AT/RT
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:_testAuthority.msalHostWithPort
                                                                                      clientId:_testClientId
                                                                                      response:_testTokenResponse];
    NSError *error = nil;
    XCTAssertTrue([_dataSource addOrUpdateRefreshTokenItem:rtItem context:nil error:&error]);
    XCTAssertNil(error);
    
    //retrieve RT
    MSALRefreshTokenCacheKey *rtKey = [[MSALRefreshTokenCacheKey alloc] initWithEnvironment:_testEnvironment
                                                                                   clientId:_testClientId
                                                                             userIdentifier:_userIdentifier1];
    MSALRefreshTokenCacheItem *rtItemInCache = [_dataSource getRefreshTokenItemForKey:rtKey context:nil error:&error];
    XCTAssertNotNil(rtItemInCache);
    
    //compare RT with the RT retrieved from cache
    XCTAssertEqualObjects(rtItem, rtItemInCache);
}

- (void)testDeleteAccessToken
{
    NSError *error = nil;
    
    XCTAssertEqual([_dataSource getAccessTokenItemsWithKey:nil context:nil error:&error].count, 0);
    XCTAssertNil(error);
    
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                  clientId:_testClientId
                                                                                  response:_testTokenResponse];
    XCTAssertTrue([_dataSource addOrUpdateAccessTokenItem:atItem context:nil error:&error]);
    XCTAssertNil(error);
    
    XCTAssertEqual([_dataSource getAccessTokenItemsWithKey:nil context:nil error:&error].count, 1);
    XCTAssertNil(error);
    
    XCTAssertTrue([_dataSource removeAccessTokenItem:atItem context:nil error:&error]);
    XCTAssertNil(error);
    
    XCTAssertEqual([_dataSource getAccessTokenItemsWithKey:nil context:nil error:&error].count, 0);
    XCTAssertNil(error);
}

- (void)testDeleteRefreshToken
{
    NSError *error = nil;
    
    XCTAssertEqual([_dataSource allRefreshTokens:_testClientId context:nil error:&error].count, 0);
    XCTAssertNil(error);
    
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:_testAuthority.msalHostWithPort
                                                                                      clientId:_testClientId
                                                                                      response:_testTokenResponse];
    XCTAssertTrue([_dataSource addOrUpdateRefreshTokenItem:rtItem context:nil error:&error]);
    XCTAssertNil(error);
    
    XCTAssertEqual([_dataSource allRefreshTokens:_testClientId context:nil error:&error].count, 1);
    XCTAssertNil(error);
    
    XCTAssertTrue([_dataSource removeRefreshTokenItem:rtItem context:nil error:&error]);
    XCTAssertNil(error);
    
    XCTAssertEqual([_dataSource allRefreshTokens:_testClientId context:nil error:&error].count, 0);
    XCTAssertNil(error);
}

- (void)testRemoveAllTokensForUserIdentifier
{
    //save AT/RT for user 1
    NSError *error = nil;
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                  clientId:_testClientId
                                                                                  response:_testTokenResponse];
    XCTAssertTrue([_dataSource addOrUpdateAccessTokenItem:atItem context:nil error:&error]);
    XCTAssertNil(error);
    
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:_testAuthority.msalHostWithPort
                                                                                      clientId:_testClientId
                                                                                      response:_testTokenResponse];
    XCTAssertTrue([_dataSource addOrUpdateRefreshTokenItem:rtItem context:nil error:&error]);
    XCTAssertNil(error);
    
    //save AT/RT for user 2
    MSALAccessTokenCacheItem *atItem2 = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                   clientId:_testClientId
                                                                                   response:_testTokenResponse2];
    XCTAssertTrue([_dataSource addOrUpdateAccessTokenItem:atItem2 context:nil error:&error]);
    XCTAssertNil(error);
    
    MSALRefreshTokenCacheItem *rtItem2 = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:_testAuthority.msalHostWithPort
                                                                                       clientId:_testClientId
                                                                                       response:_testTokenResponse2];
    XCTAssertTrue([_dataSource addOrUpdateRefreshTokenItem:rtItem2 context:nil error:&error]);
    XCTAssertNil(error);
    
    //there should be 2 ATs and 2 RTs in cache
    XCTAssertEqual([_dataSource getAccessTokenItemsWithKey:nil context:nil error:nil].count, 2);
    XCTAssertEqual([_dataSource allRefreshTokens:nil context:nil error:nil].count, 2);
    
    //delete tokens for user 1
    XCTAssertTrue([_dataSource removeAllTokensForUserIdentifier:_userIdentifier1 environment:_testAuthority.msalHostWithPort clientId:_testClientId context:nil error:&error]);
    
    //there should be one AT and one RT left in cache
    XCTAssertEqual([_dataSource getAccessTokenItemsWithKey:nil context:nil error:nil].count, 1);
    XCTAssertEqual([_dataSource allRefreshTokens:nil context:nil error:nil].count, 1);
}

@end
