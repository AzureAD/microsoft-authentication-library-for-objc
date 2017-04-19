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
#import "NSDictionary+MSALTestUtil.h"
#import "MSALTestIdTokenUtil.h"
#import "MSALTestLogger.h"
#import "NSURL+MSALExtensions.h"

@interface MSALTokenCacheAccessorTests : XCTestCase
{
    NSURL *_testAuthority;
    NSString *_testEnvironment;
    NSString *_testClientId;
    
    MSALTokenCacheAccessor *_cache;
    
    NSDictionary *_testResponse1Claims;
    MSALTokenResponse *_testTokenResponse;
    NSString *_userIdentifier1;
    MSALUser *_user1;
    
    NSDictionary *_testResponse2Claims;
    MSALTokenResponse *_testTokenResponse2;
    NSString *_userIdentifier2;
    MSALUser *_user2;
}

@end

@implementation MSALTokenCacheAccessorTests

- (void)setUp {
    [super setUp];
    
    _cache = [MSALTestTokenCache createTestAccessor];
    
    _testAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    _testEnvironment = _testAuthority.msalHostWithPort;
    _testClientId = @"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc";
    
    NSString *idToken1 = [MSALTestIdTokenUtil idTokenWithName:@"User 1" preferredUsername:@"user1@contoso.com"];
    NSString *clientInfo1 = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} base64UrlJson];
    _userIdentifier1 = @"1.1234-5678-90abcdefg";
    _user1 = [[MSALUser alloc] initWithIdToken:[[MSALIdToken alloc] initWithRawIdToken:idToken1]
                                    clientInfo:[[MSALClientInfo alloc] initWithRawClientInfo:clientInfo1 error:nil]
                                   environment:_testAuthority.msalHostWithPort];
    
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
    
    NSString *idToken2 = [MSALTestIdTokenUtil idTokenWithName:@"User 2" preferredUsername:@"user2@contoso.com"];
    NSString *clientInfo2 = [@{ @"uid" : @"2", @"utid" : @"1234-5678-90abcdefg"} base64UrlJson];
    _userIdentifier2 = @"2.1234-5678-90abcdefg";
    _user2 = [[MSALUser alloc] initWithIdToken:[[MSALIdToken alloc] initWithRawIdToken:idToken2]
                                    clientInfo:[[MSALClientInfo alloc] initWithRawClientInfo:clientInfo2 error:nil]
                                   environment:_testAuthority.msalHostWithPort];
    
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

- (void)tearDown {
    
    _cache = nil;
    
    [super tearDown];
}

- (void)testSaveAndRetrieveAccessToken {

    //prepare request parameters
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = _testAuthority;
    requestParam.clientId = _testClientId;
    [requestParam setScopesFromArray:@[@"User.Read"]];
    requestParam.user = _user1;
    
    //prepare token response and save AT/RT
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                  clientId:_testClientId
                                                                                  response:_testTokenResponse];
    [_cache saveAccessAndRefreshToken:requestParam response:_testTokenResponse context:nil error:nil];
    
    //retrieve AT
    NSString *authorityFound;
    MSALAccessTokenCacheItem *atItemInCache = [_cache findAccessToken:requestParam context:nil authorityFound:&authorityFound error:nil];
    
    //compare AT with the AT retrieved from cache
    XCTAssertNil(authorityFound);
    XCTAssertEqualObjects(atItem.jsonDictionary, atItemInCache.jsonDictionary);
    XCTAssertEqualObjects(atItem.authority, atItemInCache.authority);
    XCTAssertEqualObjects(atItem.rawIdToken, atItemInCache.rawIdToken);
    XCTAssertEqualObjects(atItem.tokenType, atItemInCache.tokenType);
    XCTAssertEqualObjects(atItem.accessToken, atItemInCache.accessToken);
    XCTAssertEqualObjects(atItem.expiresOn.description, atItemInCache.expiresOn.description);
    XCTAssertEqualObjects(atItem.scope.msalToString, atItemInCache.scope.msalToString);
    XCTAssertEqualObjects(atItem.user.displayableId, atItemInCache.user.displayableId);
    XCTAssertEqualObjects(atItem.user.name, atItemInCache.user.name);
    XCTAssertEqualObjects(atItem.user.identityProvider, atItemInCache.user.identityProvider);
    XCTAssertEqualObjects(atItem.user.uid, atItemInCache.user.uid);
    XCTAssertEqualObjects(atItem.user.utid, atItemInCache.user.utid);
    XCTAssertEqualObjects(atItem.user.environment, atItemInCache.user.environment);
    XCTAssertEqualObjects(atItem.user.userIdentifier, atItemInCache.user.userIdentifier);
    XCTAssertEqualObjects(atItem.tenantId, atItemInCache.tenantId);
    XCTAssertTrue(atItem.isExpired==atItemInCache.isExpired);
    XCTAssertEqualObjects([atItem tokenCacheKey:nil].service, [atItemInCache tokenCacheKey:nil].service);
    XCTAssertEqualObjects([atItem tokenCacheKey:nil].account, [atItemInCache tokenCacheKey:nil].account);
    XCTAssertEqualObjects(atItem.clientId, atItemInCache.clientId);
    XCTAssertEqualObjects(atItem.clientInfo.uid, atItemInCache.clientInfo.uid);
    XCTAssertEqualObjects(atItem.clientInfo.utid, atItemInCache.clientInfo.utid);
    
    //save the same AT again
    [_cache saveAccessAndRefreshToken:requestParam response:_testTokenResponse context:nil error:nil];
    
    //there should be still one AT in cache
    XCTAssertEqual([_cache.dataSource getAccessTokenItemsWithKey:nil context:nil error:nil].count, 1);
    
    //change the scope and retrive the AT again
    [requestParam setScopesFromArray:@[@"User.Read", @"scope.notexist"]];
    XCTAssertNil([_cache findAccessToken:requestParam context:nil authorityFound:nil error:nil]);
    
    //save a second AT
    MSALRequestParameters *requestParam2 = [MSALRequestParameters new];
    requestParam2.unvalidatedAuthority = _testAuthority;
    requestParam2.clientId = _testClientId;
    [requestParam2 setScopesFromArray:@[@"User.Read"]];
    requestParam2.user = _user2;
    
    MSALAccessTokenCacheItem *atItem2 = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                   clientId:_testClientId
                                                                                   response:_testTokenResponse2];
    [_cache saveAccessAndRefreshToken:requestParam2 response:_testTokenResponse2 context:nil error:nil];
    
    //there should be two ATs in cache
    XCTAssertEqual([_cache.dataSource getAccessTokenItemsWithKey:nil context:nil error:nil].count, 2);
    
    //retrieve AT 2
    MSALAccessTokenCacheItem *atItemInCache2 = [_cache findAccessToken:requestParam2 context:nil authorityFound:nil error:nil];
    
    //compare AT 2 with the AT retrieved from cache
    XCTAssertEqualObjects(atItem2.jsonDictionary, atItemInCache2.jsonDictionary);
    XCTAssertEqualObjects(atItem2.authority, atItemInCache2.authority);
    XCTAssertEqualObjects(atItem2.rawIdToken, atItemInCache2.rawIdToken);
    XCTAssertEqualObjects(atItem2.tokenType, atItemInCache2.tokenType);
    XCTAssertEqualObjects(atItem2.accessToken, atItemInCache2.accessToken);
    XCTAssertEqualObjects(atItem2.expiresOn.description, atItemInCache2.expiresOn.description);
    XCTAssertEqualObjects(atItem2.scope.msalToString, atItemInCache2.scope.msalToString);
    XCTAssertEqualObjects(atItem2.user.displayableId, atItemInCache2.user.displayableId);
    XCTAssertEqualObjects(atItem2.user.name, atItemInCache2.user.name);
    XCTAssertEqualObjects(atItem2.user.identityProvider, atItemInCache2.user.identityProvider);
    XCTAssertEqualObjects(atItem2.user.uid, atItemInCache2.user.uid);
    XCTAssertEqualObjects(atItem2.user.utid, atItemInCache2.user.utid);
    XCTAssertEqualObjects(atItem2.user.environment, atItemInCache2.user.environment);
    XCTAssertEqualObjects(atItem2.user.userIdentifier, atItemInCache2.user.userIdentifier);
    XCTAssertEqualObjects(atItem2.tenantId, atItemInCache2.tenantId);
    XCTAssertTrue(atItem2.isExpired==atItemInCache2.isExpired);
    XCTAssertEqualObjects([atItem2 tokenCacheKey:nil].service, [atItemInCache2 tokenCacheKey:nil].service);
    XCTAssertEqualObjects([atItem2 tokenCacheKey:nil].account, [atItemInCache2 tokenCacheKey:nil].account);
    XCTAssertEqualObjects(atItem2.clientId, atItemInCache2.clientId);
    XCTAssertEqualObjects(atItem2.clientInfo.uid, atItemInCache2.clientInfo.uid);
    XCTAssertEqualObjects(atItem2.clientInfo.utid, atItemInCache2.clientInfo.utid);
}

- (void)testSaveAndRetrieveRefreshToken {
    
    //prepare request parameters
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = _testAuthority;
    requestParam.clientId = _testClientId;
    [requestParam setScopesFromArray:@[@"User.Read"]];
    requestParam.user = _user1;
    
    //prepare token response and save AT/RT
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:_testAuthority.msalHostWithPort
                                                                                      clientId:_testClientId
                                                                                      response:_testTokenResponse];
    [_cache saveAccessAndRefreshToken:requestParam response:_testTokenResponse context:nil error:nil];
    
    //retrieve RT
    MSALRefreshTokenCacheItem *rtItemInCache = [_cache findRefreshToken:requestParam context:nil error:nil];
    
    //compare RT with the RT retrieved from cache
    XCTAssertEqualObjects(rtItem.jsonDictionary, rtItemInCache.jsonDictionary);
    XCTAssertEqualObjects(rtItem.environment, rtItemInCache.environment);
    XCTAssertEqualObjects(rtItem.refreshToken, rtItemInCache.refreshToken);
    XCTAssertEqualObjects(rtItem.user.displayableId, rtItemInCache.user.displayableId);
    XCTAssertEqualObjects(rtItem.user.name, rtItemInCache.user.name);
    XCTAssertEqualObjects(rtItem.user.identityProvider, rtItemInCache.user.identityProvider);
    XCTAssertEqualObjects(rtItem.user.uid, rtItemInCache.user.uid);
    XCTAssertEqualObjects(rtItem.user.utid, rtItemInCache.user.utid);
    XCTAssertEqualObjects(rtItem.user.environment, rtItemInCache.user.environment);
    XCTAssertEqualObjects(rtItem.user.userIdentifier, rtItemInCache.user.userIdentifier);
    XCTAssertEqualObjects([rtItem tokenCacheKey:nil].service, [rtItemInCache tokenCacheKey:nil].service);
    XCTAssertEqualObjects([rtItem tokenCacheKey:nil].account, [rtItemInCache tokenCacheKey:nil].account);
    XCTAssertEqualObjects(rtItem.clientId, rtItemInCache.clientId);
    XCTAssertEqualObjects(rtItem.clientInfo.uid, rtItemInCache.clientInfo.uid);
    XCTAssertEqualObjects(rtItem.clientInfo.utid, rtItemInCache.clientInfo.utid);
    XCTAssertEqualObjects(rtItem.displayableId, rtItemInCache.displayableId);
    XCTAssertEqualObjects(rtItem.name, rtItemInCache.name);
    XCTAssertEqualObjects(rtItem.identityProvider, rtItemInCache.identityProvider);

    //save the same RT again
    [_cache saveAccessAndRefreshToken:requestParam response:_testTokenResponse context:nil error:nil];
    
    //there should be still one RT in cache
    XCTAssertEqual([_cache.dataSource allRefreshTokens:nil context:nil error:nil].count, 1);
    
    //change the scope and retrive the RT again
    [requestParam setScopesFromArray:@[@"User.Read", @"scope.notexist"]];
    XCTAssertNotNil([_cache findRefreshToken:requestParam context:nil error:nil]);
    
    //save a second RT
    MSALRequestParameters *requestParam2 = [MSALRequestParameters new];
    requestParam2.unvalidatedAuthority = _testAuthority;
    requestParam2.clientId = _testClientId;
    [requestParam2 setScopesFromArray:@[@"User.Read"]];
    requestParam2.user = _user2;
    
    MSALRefreshTokenCacheItem *rtItem2 = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:_testAuthority.msalHostWithPort
                                                                                       clientId:_testClientId
                                                                                       response:_testTokenResponse2];
    [_cache saveAccessAndRefreshToken:requestParam2 response:_testTokenResponse2 context:nil error:nil];
    
    //there should be two RTs in cache
    XCTAssertEqual([_cache.dataSource allRefreshTokens:nil context:nil error:nil].count, 2);
    
    //retrieve AT 2
    MSALRefreshTokenCacheItem *rtItemInCache2 = [_cache findRefreshToken:requestParam2 context:nil error:nil];
    
    //compare RT 2 with the RT retrieved from cache
    XCTAssertEqualObjects(rtItem2.jsonDictionary, rtItemInCache2.jsonDictionary);
    XCTAssertEqualObjects(rtItem2.environment, rtItemInCache2.environment);
    XCTAssertEqualObjects(rtItem2.refreshToken, rtItemInCache2.refreshToken);
    XCTAssertEqualObjects(rtItem2.user.displayableId, rtItemInCache2.user.displayableId);
    XCTAssertEqualObjects(rtItem2.user.name, rtItemInCache2.user.name);
    XCTAssertEqualObjects(rtItem2.user.identityProvider, rtItemInCache2.user.identityProvider);
    XCTAssertEqualObjects(rtItem2.user.uid, rtItemInCache2.user.uid);
    XCTAssertEqualObjects(rtItem2.user.utid, rtItemInCache2.user.utid);
    XCTAssertEqualObjects(rtItem2.user.environment, rtItemInCache2.user.environment);
    XCTAssertEqualObjects(rtItem2.user.userIdentifier, rtItemInCache2.user.userIdentifier);
    XCTAssertEqualObjects([rtItem2 tokenCacheKey:nil].service, [rtItemInCache2 tokenCacheKey:nil].service);
    XCTAssertEqualObjects([rtItem2 tokenCacheKey:nil].account, [rtItemInCache2 tokenCacheKey:nil].account);
    XCTAssertEqualObjects(rtItem2.clientId, rtItemInCache2.clientId);
    XCTAssertEqualObjects(rtItem2.clientInfo.uid, rtItemInCache2.clientInfo.uid);
    XCTAssertEqualObjects(rtItem2.clientInfo.utid, rtItemInCache2.clientInfo.utid);
    XCTAssertEqualObjects(rtItem2.displayableId, rtItemInCache2.displayableId);
    XCTAssertEqualObjects(rtItem2.name, rtItemInCache2.name);
    XCTAssertEqualObjects(rtItem2.identityProvider, rtItemInCache2.identityProvider);
}

- (void)testDeleteTokens {
    
    //prepare request parameters
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = _testAuthority;
    requestParam.clientId = _testClientId;
    [requestParam setScopesFromArray:@[@"mail.read", @"User.Read"]];
    requestParam.user = _user1;
    
    MSALRequestParameters *requestParam2 = [MSALRequestParameters new];
    requestParam2.unvalidatedAuthority = _testAuthority;
    requestParam2.clientId = _testClientId;
    [requestParam2 setScopesFromArray:@[@"User.Read"]];
    requestParam2.user = _user2;
    
    //prepare token response and save AT/RT
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                  clientId:_testClientId
                                                                                  response:_testTokenResponse];
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:_testAuthority.msalHostWithPort
                                                                                      clientId:_testClientId
                                                                                      response:_testTokenResponse];
    [_cache saveAccessAndRefreshToken:requestParam response:_testTokenResponse context:nil error:nil];
    
    MSALAccessTokenCacheItem *atItem2 = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                   clientId:_testClientId
                                                                                   response:_testTokenResponse2];
    MSALRefreshTokenCacheItem *rtItem2 = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:_testAuthority.msalHostWithPort
                                                                                       clientId:_testClientId
                                                                                       response:_testTokenResponse2];
    [_cache saveAccessAndRefreshToken:requestParam2 response:_testTokenResponse2 context:nil error:nil];
    
    //there should be two ATs in cache
    XCTAssertEqual([_cache.dataSource getAccessTokenItemsWithKey:nil context:nil error:nil].count, 2);
    
    //there should be two RTs in cache
    XCTAssertEqual([_cache.dataSource allRefreshTokens:nil context:nil error:nil].count, 2);
    
    //retrieve AT
    MSALAccessTokenCacheItem *atItemInCache = [_cache findAccessToken:requestParam context:nil authorityFound:nil error:nil];
    
    //compare AT with the AT retrieved from cache
    XCTAssertEqualObjects([atItem tokenCacheKey:nil].service, [atItemInCache tokenCacheKey:nil].service);
    XCTAssertEqualObjects([atItem tokenCacheKey:nil].account, [atItemInCache tokenCacheKey:nil].account);
    
    //retrieve RT
    MSALRefreshTokenCacheItem *rtItemInCache = [_cache findRefreshToken:requestParam context:nil error:nil];
    
    //compare RT with the RT retrieved from cache
    XCTAssertEqualObjects([rtItem tokenCacheKey:nil].service, [rtItemInCache tokenCacheKey:nil].service);
    XCTAssertEqualObjects([rtItem tokenCacheKey:nil].account, [rtItemInCache tokenCacheKey:nil].account);
    
    //delete tokens for a user
    XCTAssertTrue([_cache deleteAllTokensForUser:_user1 clientId:_testClientId context:nil error:nil]);
    
    //deleted RT and AT, both should return nil
    XCTAssertNil([_cache findAccessToken:requestParam context:nil authorityFound:nil error:nil]);
    XCTAssertNil([_cache findRefreshToken:requestParam context:nil error:nil]);
    
    //there should be one AT and one RT left in cache
    XCTAssertEqual([_cache.dataSource getAccessTokenItemsWithKey:nil context:nil error:nil].count, 1);
    XCTAssertEqual([_cache.dataSource allRefreshTokens:nil context:nil error:nil].count, 1);
    
    //retrieve AT 2 and compare it with the AT retrieved from cache
    MSALAccessTokenCacheItem *atItemInCache2 = [_cache findAccessToken:requestParam2 context:nil authorityFound:nil error:nil];
    
    XCTAssertEqualObjects([atItem2 tokenCacheKey:nil].service, [atItemInCache2 tokenCacheKey:nil].service);
    XCTAssertEqualObjects([atItem2 tokenCacheKey:nil].account, [atItemInCache2 tokenCacheKey:nil].account);
    
    //retrieve RT 2 and compare it with the RT retrieved from cache
    MSALRefreshTokenCacheItem *rtItemInCache2 = [_cache findRefreshToken:requestParam2 context:nil error:nil];
    
    XCTAssertEqualObjects([rtItem2 tokenCacheKey:nil].service, [rtItemInCache2 tokenCacheKey:nil].service);
    XCTAssertEqualObjects([rtItem2 tokenCacheKey:nil].account, [rtItemInCache2 tokenCacheKey:nil].account);
}

- (void)testGetUsers {
    //prepare request parameters
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = _testAuthority;
    requestParam.clientId = _testClientId;
    [requestParam setScopesFromArray:@[@"mail.read", @"User.Read"]];
    requestParam.user = _user1;
    
    MSALRequestParameters *requestParam2 = [MSALRequestParameters new];
    requestParam2.unvalidatedAuthority = _testAuthority;
    requestParam2.clientId = _testClientId;
    [requestParam2 setScopesFromArray:@[@"User.Read"]];
    requestParam2.user = _user2;
    
    //save AT/RT
    [_cache saveAccessAndRefreshToken:requestParam response:_testTokenResponse context:nil error:nil];
    [_cache saveAccessAndRefreshToken:requestParam2 response:_testTokenResponse2 context:nil error:nil];
    
    //get all users using client id (sorted by unique id for easy comparison later)
    NSArray<MSALUser *> *users = [_cache getUsers:requestParam.clientId context:nil error:nil];
    users = [users sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *uniqueIdA = [(MSALUser *)a userIdentifier];
        NSString *uniqueIdB = [(MSALUser *)b userIdentifier];
        return [uniqueIdA compare:uniqueIdB];
    }];
    
    XCTAssertTrue(users.count==2);
    XCTAssertEqualObjects(users[0].displayableId, _user1.displayableId);
    XCTAssertEqualObjects(users[0].name, _user1.name);
    XCTAssertEqualObjects(users[0].identityProvider, _user1.identityProvider);
    XCTAssertEqualObjects(users[0].uid, _user1.uid);
    XCTAssertEqualObjects(users[0].utid, _user1.utid);
    XCTAssertEqualObjects(users[0].environment, _user1.environment);
    
    XCTAssertEqualObjects(users[1].displayableId, _user2.displayableId);
    XCTAssertEqualObjects(users[1].name, _user2.name);
    XCTAssertEqualObjects(users[1].identityProvider, _user2.identityProvider);
    XCTAssertEqualObjects(users[1].uid, _user2.uid);
    XCTAssertEqualObjects(users[1].utid, _user2.utid);
    XCTAssertEqualObjects(users[1].environment, _user2.environment);
    
    //get all users using nil client id (sorted by unique id for easy comparison later)
    users = [[_cache getUsers:nil context:nil error:nil] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *uniqueIdA = [(MSALUser *)a userIdentifier];
        NSString *uniqueIdB = [(MSALUser *)b userIdentifier];
        return [uniqueIdA compare:uniqueIdB];
    }];
    
    XCTAssertTrue(users.count==2);
    XCTAssertEqualObjects(users[0].displayableId, _user1.displayableId);
    XCTAssertEqualObjects(users[0].name, _user1.name);
    XCTAssertEqualObjects(users[0].identityProvider, _user1.identityProvider);
    XCTAssertEqualObjects(users[0].uid, _user1.uid);
    XCTAssertEqualObjects(users[0].utid, _user1.utid);
    XCTAssertEqualObjects(users[0].environment, _user1.environment);
    
    XCTAssertEqualObjects(users[1].displayableId, _user2.displayableId);
    XCTAssertEqualObjects(users[1].name, _user2.name);
    XCTAssertEqualObjects(users[1].identityProvider, _user2.identityProvider);
    XCTAssertEqualObjects(users[1].uid, _user2.uid);
    XCTAssertEqualObjects(users[1].utid, _user2.utid);
    XCTAssertEqualObjects(users[1].environment, _user2.environment);
    
    users = [_cache getUsers:@"fake-client-id" context:nil error:nil];
    XCTAssertTrue(users.count==0);
}

- (void)testAmbugiousFindAccessTokenCall {
    
    //store token 1
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = _testAuthority;
    requestParam.clientId = _testClientId;
    [requestParam setScopesFromArray:@[@"User.Read"]];
    requestParam.user = _user1;
    [_cache saveAccessAndRefreshToken:requestParam response:_testTokenResponse context:nil error:nil];
    
    //store token 2
    MSALRequestParameters *requestParam2 = [MSALRequestParameters new];
    requestParam2.unvalidatedAuthority = _testAuthority;
    requestParam2.clientId = _testClientId;
    [requestParam2 setScopesFromArray:@[@"User.Read"]];
    requestParam2.user = _user2;
    [_cache saveAccessAndRefreshToken:requestParam2 response:_testTokenResponse2 context:nil error:nil];
    
    //remove user specifier to make the query ambigious
    requestParam2.user = nil;
    
    XCTAssertNil([_cache findAccessToken:requestParam2 context:nil authorityFound:nil error:nil]);
}

- (void)testFindExpiredAccessToken {
    
    //prepare and save expired token
    NSMutableDictionary *testResponse1ClaimsCopy = [_testResponse1Claims mutableCopy];
    [testResponse1ClaimsCopy setValue:@"0" forKey:@"expires_in"];
    _testTokenResponse = [[MSALTokenResponse alloc] initWithJson:testResponse1ClaimsCopy error:nil];
    
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = _testAuthority;
    requestParam.clientId = _testClientId;
    [requestParam setScopesFromArray:@[@"User.Read"]];
    requestParam.user = _user1;
    
    [_cache saveAccessAndRefreshToken:requestParam response:_testTokenResponse context:nil error:nil];
    
    //token is returned so it is not returned
    XCTAssertNil([_cache findAccessToken:requestParam context:nil authorityFound:nil error:nil]);
}

- (void)testFindAccessTokenWithoutAuthority {
    
    //prepare request parameters
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = _testAuthority;
    requestParam.clientId = _testClientId;
    [requestParam setScopesFromArray:@[@"User.Read"]];
    requestParam.user = _user1;
    
    MSALRequestParameters *requestParam2 = [MSALRequestParameters new];
    requestParam2.unvalidatedAuthority = _testAuthority;
    requestParam2.clientId = _testClientId;
    [requestParam2 setScopesFromArray:@[@"User.Read"]];
    requestParam2.user = _user2;
    
    //retrieve without authority in empty cache
    requestParam.unvalidatedAuthority = nil;
    NSString *authorityFound;
    MSALAccessTokenCacheItem *atItemInCache = [_cache findAccessToken:requestParam context:nil authorityFound:&authorityFound error:nil];
    XCTAssertNil(atItemInCache);
    XCTAssertNil(authorityFound);
    
    //store AT 1
    requestParam.unvalidatedAuthority = _testAuthority;
    [_cache saveAccessAndRefreshToken:requestParam response:_testTokenResponse context:nil error:nil];
    
    //retrieve with one token in cache
    authorityFound = nil;
    requestParam.unvalidatedAuthority = nil;
    atItemInCache = [_cache findAccessToken:requestParam context:nil authorityFound:&authorityFound error:nil];
    XCTAssertNotNil(atItemInCache);
    XCTAssertNil(authorityFound);
    
    //save a AT 2
    requestParam2.unvalidatedAuthority = _testAuthority;
    [_cache saveAccessAndRefreshToken:requestParam2 response:_testTokenResponse2 context:nil error:nil];
    
    //remove user specifier such that multiple matched tokens could be found
    requestParam.user = nil;
    requestParam.unvalidatedAuthority = nil;
    authorityFound = nil;
    NSError *error;
    atItemInCache = [_cache findAccessToken:requestParam context:nil authorityFound:&authorityFound error:&error];
    XCTAssertNil(atItemInCache);
    XCTAssertNil(authorityFound);
    XCTAssertEqual(error.code, MSALErrorMultipleMatchesNoAuthoritySpecified);
    
    //no match but can find a unique authority in cache
    requestParam2.unvalidatedAuthority = nil;
    [requestParam2 setScopesFromArray:@[@"nonexist"]];
    authorityFound = nil;
    atItemInCache = [_cache findAccessToken:requestParam2 context:nil authorityFound:&authorityFound error:nil];
    XCTAssertNil(atItemInCache);
    XCTAssertEqualObjects(authorityFound, _testAuthority.absoluteString);
}

- (void)testUserForIdentifier_whenIdentifierNil_shouldFail
{
    NSError *error = nil;
    
    XCTAssertNil([_cache getUserForIdentifier:nil
                                     clientId:@"12345"
                                  environment:@"environment.com"
                                        error:&error]);
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"userIdentifier"]);
}

- (void)testUserForIdentifier_whenClientIdNil_shouldFail
{
    NSError *error = nil;
    
    XCTAssertNil([_cache getUserForIdentifier:@"12345"
                                     clientId:nil
                                  environment:@"environment.com"
                                        error:&error]);
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"clientId"]);
}

- (void)testUserForIdentifier_whenEnvironmentNil_shouldFail
{
    NSError *error = nil;
    
    XCTAssertNil([_cache getUserForIdentifier:@"112334"
                                     clientId:@"12345"
                                  environment:nil
                                        error:&error]);
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"environment"]);
}

- (void)testUserForIdentifier_whenUserNotInCache_shouldFail
{
    NSError *error = nil;
    
    XCTAssertNil([_cache getUserForIdentifier:@"11234123+12314123"
                                     clientId:@"12345"
                                  environment:@"environment.com"
                                        error:&error]);
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorUserNotFound);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
}

- (void)testUserForIdentifier_whenUserNotInCacheAndNoError_shouldFailAndStillLog
{
    XCTAssertNil([_cache getUserForIdentifier:@"11234123+12314123"
                                     clientId:@"12345"
                                  environment:@"environment.com"
                                        error:nil]);
    
    XCTAssertTrue([[[MSALTestLogger sharedLogger] lastMessage] containsString:@"UserNotFound"]);
}


- (void)testUserForIdentifier_whenExists_shouldFind
{
    NSError *error = nil;
    
    NSString *uid = @"12345";
    NSString *utid = @"678910";
    NSDictionary *clientInfo = @{ @"uid" : uid, @"utid" : utid };
    
    MSALRefreshTokenCacheItem *rtItem =
    [[MSALRefreshTokenCacheItem alloc] initWithJson:@{ @"refresh_token" : @"i am a refresh token!",
                                                       @"environment" : _testEnvironment,
                                                       @"displayable_id" : @"user@contoso.com",
                                                       @"name" : @"User",
                                                       @"identity_provider" : @"issuer",
                                                       @"client_id" : _testClientId,
                                                       @"client_info" : [clientInfo base64UrlJson]
                                                       }
                                               error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateRefreshTokenItem:rtItem context:nil error:nil]);
    
    NSString *userIdentifier = @"12345.678910";
    
    MSALUser * user = [_cache getUserForIdentifier:userIdentifier clientId:_testClientId environment:_testEnvironment error:&error];
    XCTAssertNotNil(user);
    XCTAssertNil(error);
    XCTAssertEqualObjects(user.uid, uid);
    XCTAssertEqualObjects(user.utid, utid);
}

@end
