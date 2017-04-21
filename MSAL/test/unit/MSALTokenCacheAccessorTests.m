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
#import "MSALTestTokenCacheItemUtil.h"

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
    MSALRequestParameters *_requestParam1;
    
    NSDictionary *_testResponse2Claims;
    MSALTokenResponse *_testTokenResponse2;
    NSString *_userIdentifier2;
    MSALUser *_user2;
    MSALRequestParameters *_requestParam2;
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
    
    _requestParam1 = [MSALRequestParameters new];
    _requestParam1.unvalidatedAuthority = _testAuthority;
    _requestParam1.clientId = _testClientId;
    [_requestParam1 setScopesFromArray:@[@"mail.read", @"user.read"]];
    _requestParam1.user = _user1;
    
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
    
    _requestParam2 = [MSALRequestParameters new];
    _requestParam2.unvalidatedAuthority = _testAuthority;
    _requestParam2.clientId = _testClientId;
    [_requestParam2 setScopesFromArray:@[@"mail.read", @"user.read"]];
    _requestParam2.user = _user2;

}

- (void)tearDown {
    
    _cache = nil;
    
    [super tearDown];
}

- (void)testSaveAndRetrieveAccessToken_whenExists_shouldFind
{
    //prepare token response and save AT/RT
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                  clientId:_testClientId
                                                                                  response:_testTokenResponse];
    [_cache saveAccessAndRefreshToken:_requestParam1 response:_testTokenResponse context:nil error:nil];
    
    //retrieve AT
    NSString *authorityFound;
    NSError *error = nil;
    MSALAccessTokenCacheItem *atItemInCache = [_cache findAccessToken:_requestParam1 context:nil authorityFound:&authorityFound error:&error];
    XCTAssertNil(error);
    
    //compare AT with the AT retrieved from cache
    XCTAssertNil(authorityFound);
    XCTAssertEqualObjects(atItem, atItemInCache);
}

- (void)testSaveSameTokenTwice
{
    //save AT/RT twice
    NSError *error = nil;
    [_cache saveAccessAndRefreshToken:_requestParam1 response:_testTokenResponse context:nil error:&error];
    XCTAssertNil(error);
    
    error = nil;
    [_cache saveAccessAndRefreshToken:_requestParam1 response:_testTokenResponse context:nil error:&error];
    XCTAssertNil(error);
    
    //there should be still one AT and one RT in cache
    NSArray <MSALAccessTokenCacheItem *> *atsInCache = [_cache.dataSource getAccessTokenItemsWithKey:nil context:nil error:nil];
    XCTAssertEqual(atsInCache.count, 1);
    NSArray <MSALRefreshTokenCacheItem *> *rtsInCache = [_cache.dataSource allRefreshTokens:nil context:nil error:nil];
    XCTAssertEqual(rtsInCache.count, 1);
}

- (void)testSaveMultipleTokens
{
    //save first and second AT/RT
    NSError *error = nil;
    [_cache saveAccessAndRefreshToken:_requestParam1 response:_testTokenResponse context:nil error:&error];
    XCTAssertNil(error);
    
    error = nil;
    [_cache saveAccessAndRefreshToken:_requestParam2 response:_testTokenResponse2 context:nil error:&error];
    XCTAssertNil(error);
    
    //there should be two ATs and RTs in cache
    NSArray <MSALAccessTokenCacheItem *> *atsInCache = [_cache.dataSource getAccessTokenItemsWithKey:nil context:nil error:nil];
    NSArray <MSALRefreshTokenCacheItem *> *rtsInCache = [_cache.dataSource allRefreshTokens:nil context:nil error:nil];
    XCTAssertEqual(atsInCache.count, 2);
    XCTAssertEqual(rtsInCache.count, 2);
    
    //compare ATs with the ATs retrieved from cache
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                  clientId:_testClientId
                                                                                  response:_testTokenResponse];
    MSALAccessTokenCacheItem *atItem2 = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                   clientId:_testClientId
                                                                                   response:_testTokenResponse2];
    NSSet *atsSet = [[NSSet alloc] initWithObjects:atItem, atItem2, nil];
    NSSet *atsInCacheSet = [[NSSet alloc] initWithArray:atsInCache];
    XCTAssertEqualObjects(atsInCacheSet, atsSet);
    
    //compare RTs with the RTs retrieved from cache
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:_testAuthority.msalHostWithPort
                                                                                      clientId:_testClientId
                                                                                      response:_testTokenResponse];
    MSALRefreshTokenCacheItem *rtItem2 = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:_testAuthority.msalHostWithPort
                                                                                       clientId:_testClientId
                                                                                       response:_testTokenResponse2];
    NSSet *rtsSet = [[NSSet alloc] initWithObjects:rtItem, rtItem2, nil];
    NSSet *rtsInCacheSet = [[NSSet alloc] initWithArray:rtsInCache];
    XCTAssertEqualObjects(rtsInCacheSet, rtsSet);
}

- (void)testFindAccessToken_whenScopeMismatch_shouldNoTokenFound
{
    // store an access token
    NSDictionary *clientInfo1 = @{ @"uid" : _user1.uid, @"utid" : _user1.utid };
    MSALAccessTokenCacheItem *atItem =
    [[MSALAccessTokenCacheItem alloc] initWithJson:@{ @"access_token" : @"i am a access token!",
                                                      @"authority" : _testAuthority.absoluteString,
                                                      @"displayable_id" : _user1.displayableId,
                                                      @"scope" : @"mail.read user.read",
                                                      @"token_type" : @"Bearer",
                                                      @"expires_on" : [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate date] timeIntervalSince1970]+600],
                                                      @"client_id" : _testClientId,
                                                      @"client_info" : [clientInfo1 base64UrlJson]
                                                      }
                                              error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateAccessTokenItem:atItem context:nil error:nil]);
    
    //prepare requestParameter
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = _testAuthority;
    requestParam.clientId = _testClientId;
    requestParam.user = _user1;
    [requestParam setScopesFromArray:@[@"User.Read", @"scope.notexist"]];
    NSError *error = nil;
    XCTAssertNil([_cache findAccessToken:requestParam context:nil authorityFound:nil error:&error]);
    XCTAssertNil(error);
}

- (void)testSaveAndRetrieveRefreshToken
{
    //prepare token response and save AT/RT
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:_testAuthority.msalHostWithPort
                                                                                      clientId:_testClientId
                                                                                      response:_testTokenResponse];
    NSError *error = nil;
    [_cache saveAccessAndRefreshToken:_requestParam1 response:_testTokenResponse context:nil error:&error];
    XCTAssertNil(error);
    
    //retrieve RT
    error = nil;
    MSALRefreshTokenCacheItem *rtItemInCache = [_cache findRefreshToken:_requestParam1 context:nil error:&error];
    XCTAssertNil(error);
    
    //compare RT with the RT retrieved from cache
    XCTAssertEqualObjects(rtItem, rtItemInCache);
}

- (void)testDeleteAllTokensForUser
{
    //store AT/RT for user 1
    NSDictionary *clientInfo1 = @{ @"uid" : _user1.uid, @"utid" : _user1.utid };
    MSALAccessTokenCacheItem *atItem =
    [[MSALAccessTokenCacheItem alloc] initWithJson:@{ @"access_token" : @"i am a access token!",
                                                      @"authority" : _testAuthority.absoluteString,
                                                      @"displayable_id" : _user1.displayableId,
                                                      @"scope" : @"mail.read user.read",
                                                      @"token_type" : @"Bearer",
                                                      @"expires_on" : [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate date] timeIntervalSince1970]+600],
                                                      @"client_id" : _testClientId,
                                                      @"client_info" : [clientInfo1 base64UrlJson]
                                                      }
                                             error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateAccessTokenItem:atItem context:nil error:nil]);
    
    MSALRefreshTokenCacheItem *rtItem =
    [[MSALRefreshTokenCacheItem alloc] initWithJson:@{ @"refresh_token" : @"i am a refresh token!",
                                                       @"environment" : _testEnvironment,
                                                       @"displayable_id" : _user1.displayableId,
                                                       @"name" : _user1.name,
                                                       @"identity_provider" : _user1.identityProvider,
                                                       @"client_id" : _testClientId,
                                                       @"client_info" : [clientInfo1 base64UrlJson]
                                                       }
                                              error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateRefreshTokenItem:rtItem context:nil error:nil]);
    
    //store AT/RT for user 2
    NSDictionary *clientInfo2 = @{ @"uid" : _user2.uid, @"utid" : _user2.utid };
    MSALAccessTokenCacheItem *atItem2 =
    [[MSALAccessTokenCacheItem alloc] initWithJson:@{ @"access_token" : @"i am a access token!",
                                                      @"authority" : _testAuthority.absoluteString,
                                                      @"displayable_id" : _user2.displayableId,
                                                      @"scope" : @"mail.read user.read",
                                                      @"token_type" : @"Bearer",
                                                      @"expires_on" : [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate date] timeIntervalSince1970]+600],
                                                      @"client_id" : _testClientId,
                                                      @"client_info" : [clientInfo2 base64UrlJson]
                                                      }
                                             error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateAccessTokenItem:atItem2 context:nil error:nil]);
    
    MSALRefreshTokenCacheItem *rtItem2 =
    [[MSALRefreshTokenCacheItem alloc] initWithJson:@{ @"refresh_token" : @"i am a refresh token!",
                                                       @"environment" : _testEnvironment,
                                                       @"displayable_id" : _user2.displayableId,
                                                       @"name" : _user2.name,
                                                       @"identity_provider" : _user2.identityProvider,
                                                       @"client_id" : _testClientId,
                                                       @"client_info" : [clientInfo2 base64UrlJson]
                                                       }
                                              error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateRefreshTokenItem:rtItem2 context:nil error:nil]);
    
    //delete tokens for user 1
    XCTAssertTrue([_cache deleteAllTokensForUser:_user1 clientId:_testClientId context:nil error:nil]);
    
    //Both RT and AT are deleted, both should return nil
    NSError *error = nil;
    XCTAssertNil([_cache findAccessToken:_requestParam1 context:nil authorityFound:nil error:&error]);
    XCTAssertNil(error);
    
    error = nil;
    XCTAssertNil([_cache findRefreshToken:_requestParam1 context:nil error:&error]);
    XCTAssertNil(error);
    
    //there should be one AT and one RT left in cache, both are for user 2
    XCTAssertEqual([_cache.dataSource getAccessTokenItemsWithKey:nil context:nil error:nil].count, 1);
    XCTAssertEqual([_cache.dataSource allRefreshTokens:nil context:nil error:nil].count, 1);
    
    error = nil;
    MSALAccessTokenCacheItem *atItemInCache2 = [_cache findAccessToken:_requestParam2 context:nil authorityFound:nil error:&error];
    XCTAssertNil(error);
    error = nil;
    MSALRefreshTokenCacheItem *rtItemInCache2 = [_cache findRefreshToken:_requestParam2 context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(atItem2, atItemInCache2);
    XCTAssertEqualObjects(rtItem2, rtItemInCache2);
}

- (void)testDeleteAllTokensForUser_whenNilUser_shouldReturnYes
{
    XCTAssertTrue([_cache deleteAllTokensForUser:nil clientId:_testClientId context:nil error:nil]);
}

- (void)testGetUsers {
    
    // store 2 refresh tokens for 2 different users
    NSDictionary *clientInfo1 = @{ @"uid" : _user1.uid, @"utid" : _user1.utid };
    MSALRefreshTokenCacheItem *rtItem1 =
    [[MSALRefreshTokenCacheItem alloc] initWithJson:@{ @"refresh_token" : @"i am a refresh token!",
                                                       @"environment" : _testEnvironment,
                                                       @"displayable_id" : _user1.displayableId,
                                                       @"name" : _user1.name,
                                                       @"identity_provider" : _user1.identityProvider,
                                                       @"client_id" : _testClientId,
                                                       @"client_info" : [clientInfo1 base64UrlJson]
                                                       }
                                              error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateRefreshTokenItem:rtItem1 context:nil error:nil]);
    
    NSDictionary *clientInfo2 = @{ @"uid" : _user2.uid, @"utid" : _user2.utid };
    MSALRefreshTokenCacheItem *rtItem2 =
    [[MSALRefreshTokenCacheItem alloc] initWithJson:@{ @"refresh_token" : @"i am a refresh token!",
                                                       @"environment" : _testEnvironment,
                                                       @"displayable_id" : _user2.displayableId,
                                                       @"name" : _user2.name,
                                                       @"identity_provider" : _user2.identityProvider,
                                                       @"client_id" : _testClientId,
                                                       @"client_info" : [clientInfo2 base64UrlJson]
                                                       }
                                              error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateRefreshTokenItem:rtItem2 context:nil error:nil]);
    
    //get all users using client id (sorted by unique id for easy comparison later)
    NSArray<MSALUser *> *users = [_cache getUsers:_testClientId context:nil error:nil];
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

- (void)testFindAccessToken_whenMultipleMatches_shouldFail
{
    //store 2 tokens
    NSError *error = nil;
    [_cache saveAccessAndRefreshToken:_requestParam1 response:_testTokenResponse context:nil error:&error];
    XCTAssertNil(error);
    
    error = nil;
    [_cache saveAccessAndRefreshToken:_requestParam2 response:_testTokenResponse2 context:nil error:&error];
    XCTAssertNil(error);
    
    //remove user specifier to make an ambigious query
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = _testAuthority;
    requestParam.clientId = _testClientId;
    [requestParam setScopesFromArray:@[@"User.Read"]];
    requestParam.user = nil;
    
    error = nil;
    XCTAssertNil([_cache findAccessToken:requestParam context:nil authorityFound:nil error:&error]);
    XCTAssertEqual(error.code, MSALErrorMultipleMatchesNoAuthoritySpecified);
}

- (void)testFindAccessToken_whenTokenExpired_shouldReturnNil
{
    //prepare and save expired token
    NSDictionary *clientInfo = @{ @"uid" : _user1.uid, @"utid" : _user1.utid };
    MSALAccessTokenCacheItem *atItem =
    [[MSALAccessTokenCacheItem alloc] initWithJson:@{ @"access_token" : @"i am a access token!",
                                                      @"authority" : _testAuthority.absoluteString,
                                                      @"displayable_id" : _user1.displayableId,
                                                      @"scope" : @"mail.read user.read",
                                                      @"token_type" : @"Bearer",
                                                      @"expires_on" : [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate date] timeIntervalSince1970]],
                                                      @"client_id" : _testClientId,
                                                      @"client_info" : [clientInfo base64UrlJson]
                                                      }
                                             error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateAccessTokenItem:atItem context:nil error:nil]);
    
    //token is expired so it is not returned
    NSError *error = nil;
    XCTAssertNil([_cache findAccessToken:_requestParam1 context:nil authorityFound:nil error:&error]);
    XCTAssertNil(error);
}

- (void)testFindAccessTokenWithoutAuthority_whenExists_shouldFind
{
    //store AT
    NSDictionary *clientInfo = @{ @"uid" : _user1.uid, @"utid" : _user1.utid };
    MSALAccessTokenCacheItem *atItem =
    [[MSALAccessTokenCacheItem alloc] initWithJson:@{ @"access_token" : @"i am a access token!",
                                                      @"authority" : _testAuthority.absoluteString,
                                                      @"displayable_id" : _user1.displayableId,
                                                      @"scope" : @"mail.read user.read",
                                                      @"token_type" : @"Bearer",
                                                      @"expires_on" : [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate date] timeIntervalSince1970]+600],
                                                      @"client_id" : _testClientId,
                                                      @"client_info" : [clientInfo base64UrlJson]
                                                      }
                                             error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateAccessTokenItem:atItem context:nil error:nil]);
    
    //retrieve with one token in cache
    NSString *authorityFound = nil;
    _requestParam1.unvalidatedAuthority = nil;
    NSError *error = nil;
    MSALAccessTokenCacheItem *atItemInCache = [_cache findAccessToken:_requestParam1 context:nil authorityFound:&authorityFound error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(atItemInCache);
    XCTAssertNil(authorityFound);
}
- (void)testFindAccessTokenWithoutAuthority_whenEmptyCache_shouldReturnNil
{
    //retrieve without authority in empty cache
    _requestParam1.unvalidatedAuthority = nil;
    NSString *authorityFound;
    NSError *error = nil;
    MSALAccessTokenCacheItem *atItemInCache = [_cache findAccessToken:_requestParam1 context:nil authorityFound:&authorityFound error:&error];
    XCTAssertNil(error);
    XCTAssertNil(atItemInCache);
    XCTAssertNil(authorityFound);
}

- (void)testFindAccessTokenWithoutAuthority_whenMultipleMatches_shouldFail
{
    //store two ATs
    NSDictionary *clientInfo1 = @{ @"uid" : _user1.uid, @"utid" : _user1.utid };
    MSALAccessTokenCacheItem *atItem1 =
    [[MSALAccessTokenCacheItem alloc] initWithJson:@{ @"access_token" : @"i am a access token!",
                                                      @"authority" : _testAuthority.absoluteString,
                                                      @"displayable_id" : _user1.displayableId,
                                                      @"scope" : @"mail.read user.read",
                                                      @"token_type" : @"Bearer",
                                                      @"expires_on" : [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate date] timeIntervalSince1970]+600],
                                                      @"client_id" : _testClientId,
                                                      @"client_info" : [clientInfo1 base64UrlJson]
                                                      }
                                             error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateAccessTokenItem:atItem1 context:nil error:nil]);

    NSDictionary *clientInfo2 = @{ @"uid" : _user2.uid, @"utid" : _user2.utid };
    MSALAccessTokenCacheItem *atItem2 =
    [[MSALAccessTokenCacheItem alloc] initWithJson:@{ @"access_token" : @"i am a access token!",
                                                      @"authority" : _testAuthority.absoluteString,
                                                      @"displayable_id" : _user2.displayableId,
                                                      @"scope" : @"mail.read user.read",
                                                      @"token_type" : @"Bearer",
                                                      @"expires_on" : [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate date] timeIntervalSince1970]+600],
                                                      @"client_id" : _testClientId,
                                                      @"client_info" : [clientInfo2 base64UrlJson]
                                                      }
                                             error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateAccessTokenItem:atItem2 context:nil error:nil]);
    
    //remove user specifier such that multiple matched tokens could be found
    _requestParam1.user = nil;
    _requestParam1.unvalidatedAuthority = nil;
    NSString *authorityFound = nil;
    NSError *error = nil;
    MSALAccessTokenCacheItem *atItemInCache = [_cache findAccessToken:_requestParam1 context:nil authorityFound:&authorityFound error:&error];
    XCTAssertNil(atItemInCache);
    XCTAssertNil(authorityFound);
    XCTAssertEqual(error.code, MSALErrorMultipleMatchesNoAuthoritySpecified);
}

- (void)testFindAccessTokenWithoutAuthority_whenNoMatchButFoundUniqueAuthority_shouldReturnAuthority
{
    //store two ATs
    NSDictionary *clientInfo1 = @{ @"uid" : _user1.uid, @"utid" : _user1.utid };
    MSALAccessTokenCacheItem *atItem1 =
    [[MSALAccessTokenCacheItem alloc] initWithJson:@{ @"access_token" : @"i am a access token!",
                                                      @"authority" : _testAuthority.absoluteString,
                                                      @"displayable_id" : _user1.displayableId,
                                                      @"scope" : @"mail.read user.read",
                                                      @"token_type" : @"Bearer",
                                                      @"expires_on" : [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate date] timeIntervalSince1970]+600],
                                                      @"client_id" : _testClientId,
                                                      @"client_info" : [clientInfo1 base64UrlJson]
                                                      }
                                             error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateAccessTokenItem:atItem1 context:nil error:nil]);
    
    NSDictionary *clientInfo2 = @{ @"uid" : _user2.uid, @"utid" : _user2.utid };
    MSALAccessTokenCacheItem *atItem2 =
    [[MSALAccessTokenCacheItem alloc] initWithJson:@{ @"access_token" : @"i am a access token!",
                                                      @"authority" : _testAuthority.absoluteString,
                                                      @"displayable_id" : _user2.displayableId,
                                                      @"scope" : @"mail.read user.read",
                                                      @"token_type" : @"Bearer",
                                                      @"expires_on" : [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate date] timeIntervalSince1970]+600],
                                                      @"client_id" : _testClientId,
                                                      @"client_info" : [clientInfo2 base64UrlJson]
                                                      }
                                             error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateAccessTokenItem:atItem2 context:nil error:nil]);
    
    //no match but can find a unique authority in cache
    _requestParam1.unvalidatedAuthority = nil;
    [_requestParam1 setScopesFromArray:@[@"nonexist"]];
    NSString *authorityFound = nil;
    NSError *error = nil;
    MSALAccessTokenCacheItem *atItemInCache = [_cache findAccessToken:_requestParam1 context:nil authorityFound:&authorityFound error:&error];
    XCTAssertNil(error);
    XCTAssertNil(atItemInCache);
    XCTAssertEqualObjects(authorityFound, _testAuthority.absoluteString);
}

- (void)testFindAccessTokenWithoutAuthority_whenNoMatchNoUniqueAuthority_shouldReturnNothing
{
    //store two ATs for the same user but with different authorities
    NSDictionary *clientInfo = @{ @"uid" : _user1.uid, @"utid" : _user1.utid };
    MSALAccessTokenCacheItem *atItem1 =
    [[MSALAccessTokenCacheItem alloc] initWithJson:@{ @"access_token" : @"i am a access token!",
                                                      @"authority" : _testAuthority.absoluteString,
                                                      @"displayable_id" : _user1.displayableId,
                                                      @"scope" : @"mail.read user.read",
                                                      @"token_type" : @"Bearer",
                                                      @"expires_on" : [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate date] timeIntervalSince1970]+600],
                                                      @"client_id" : _testClientId,
                                                      @"client_info" : [clientInfo base64UrlJson]
                                                      }
                                             error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateAccessTokenItem:atItem1 context:nil error:nil]);
    
    MSALAccessTokenCacheItem *atItem2 =
    [[MSALAccessTokenCacheItem alloc] initWithJson:@{ @"access_token" : @"i am a access token!",
                                                      @"authority" : @"https://login.microsoftonline.com/fabrikam.com",
                                                      @"displayable_id" : _user1.displayableId,
                                                      @"scope" : @"mail.read user.read",
                                                      @"token_type" : @"Bearer",
                                                      @"expires_on" : [NSString stringWithFormat:@"%qu", (uint64_t)[[NSDate date] timeIntervalSince1970]+600],
                                                      @"client_id" : _testClientId,
                                                      @"client_info" : [clientInfo base64UrlJson]
                                                      }
                                             error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateAccessTokenItem:atItem2 context:nil error:nil]);
    
    //no match but can find a unique authority in cache
    _requestParam1.unvalidatedAuthority = nil;
    [_requestParam1 setScopesFromArray:@[@"nonexist"]];
    NSString *authorityFound = nil;
    NSError *error = nil;
    MSALAccessTokenCacheItem *atItemInCache = [_cache findAccessToken:_requestParam1 context:nil authorityFound:&authorityFound error:&error];
    XCTAssertNil(error);
    XCTAssertNil(atItemInCache);
    XCTAssertNil(authorityFound);
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
