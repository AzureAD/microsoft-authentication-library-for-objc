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

- (void)testSaveAndRetrieveAccessToken
{
    //prepare token response and save AT/RT
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                  clientId:_testClientId
                                                                                  response:_testTokenResponse];
    [_cache saveAccessAndRefreshToken:_requestParam1 response:_testTokenResponse context:nil error:nil];
    
    //retrieve AT
    NSString *authorityFound;
    MSALAccessTokenCacheItem *atItemInCache = [_cache findAccessToken:_requestParam1 context:nil authorityFound:&authorityFound error:nil];
    
    //compare AT with the AT retrieved from cache
    XCTAssertNil(authorityFound);
    XCTAssertTrue([MSALTestTokenCacheItemUtil areAccessTokensEqual:atItem tokenB:atItemInCache]);
}

- (void)testSaveSameTokenTwice
{
    //save AT/RT twice
    [_cache saveAccessAndRefreshToken:_requestParam1 response:_testTokenResponse context:nil error:nil];
    [_cache saveAccessAndRefreshToken:_requestParam1 response:_testTokenResponse context:nil error:nil];
    
    //there should be still one AT and one RT in cache
    NSArray <MSALAccessTokenCacheItem *> *atsInCache = [_cache.dataSource getAccessTokenItemsWithKey:nil context:nil error:nil];
    XCTAssertEqual(atsInCache.count, 1);
    NSArray <MSALRefreshTokenCacheItem *> *rtsInCache = [_cache.dataSource allRefreshTokens:nil context:nil error:nil];
    XCTAssertEqual(rtsInCache.count, 1);

    
    //compare AT with the AT retrieved from cache
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                  clientId:_testClientId
                                                                                  response:_testTokenResponse];
    XCTAssertTrue([MSALTestTokenCacheItemUtil areAccessTokensEqual:atItem tokenB:atsInCache[0]]);
    
    //compare RT with the RT retrieved from cache
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:_testAuthority.msalHostWithPort
                                                                                      clientId:_testClientId
                                                                                      response:_testTokenResponse];
    XCTAssertTrue([MSALTestTokenCacheItemUtil areRefreshTokensEqual:rtItem tokenB:rtsInCache[0]]);
}

- (void)testSaveMultipleTokens
{
    //save first and second AT/RT
    [_cache saveAccessAndRefreshToken:_requestParam1 response:_testTokenResponse context:nil error:nil];
    [_cache saveAccessAndRefreshToken:_requestParam2 response:_testTokenResponse2 context:nil error:nil];
    
    //there should be two ATs and RTs in cache
    NSArray <MSALAccessTokenCacheItem *> *atsInCache = [_cache.dataSource getAccessTokenItemsWithKey:nil context:nil error:nil];
    NSArray <MSALRefreshTokenCacheItem *> *rtsInCache = [_cache.dataSource allRefreshTokens:nil context:nil error:nil];
    XCTAssertEqual(atsInCache.count, 2);
    XCTAssertEqual(rtsInCache.count, 2);
    
    atsInCache = [atsInCache sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *uniqueIdA = [[(MSALAccessTokenCacheItem *)a user] userIdentifier];
        NSString *uniqueIdB = [[(MSALAccessTokenCacheItem *)b user] userIdentifier];
        return [uniqueIdA compare:uniqueIdB];
    }];
    
    rtsInCache = [rtsInCache sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *uniqueIdA = [[(MSALRefreshTokenCacheItem *)a user] userIdentifier];
        NSString *uniqueIdB = [[(MSALRefreshTokenCacheItem *)b user] userIdentifier];
        return [uniqueIdA compare:uniqueIdB];
    }];
    
    //compare ATs with the ATs retrieved from cache
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                  clientId:_testClientId
                                                                                  response:_testTokenResponse];
    XCTAssertTrue([MSALTestTokenCacheItemUtil areAccessTokensEqual:atItem tokenB:atsInCache[0]]);
    
    MSALAccessTokenCacheItem *atItem2 = [[MSALAccessTokenCacheItem alloc] initWithAuthority:_testAuthority
                                                                                   clientId:_testClientId
                                                                                   response:_testTokenResponse2];
    XCTAssertTrue([MSALTestTokenCacheItemUtil areAccessTokensEqual:atItem2 tokenB:atsInCache[1]]);
    
    //compare RTs with the RTs retrieved from cache
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:_testAuthority.msalHostWithPort
                                                                                      clientId:_testClientId
                                                                                      response:_testTokenResponse];
    XCTAssertTrue([MSALTestTokenCacheItemUtil areRefreshTokensEqual:rtItem tokenB:rtsInCache[0]]);
    
    MSALRefreshTokenCacheItem *rtItem2 = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:_testAuthority.msalHostWithPort
                                                                                       clientId:_testClientId
                                                                                       response:_testTokenResponse2];
    XCTAssertTrue([MSALTestTokenCacheItemUtil areRefreshTokensEqual:rtItem2 tokenB:rtsInCache[1]]);
    
}

- (void)testFindAccessToken_noMatch_becauseOfScopes
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
    XCTAssertNil([_cache findAccessToken:requestParam context:nil authorityFound:nil error:nil]);
}

- (void)testFindRefreshToken_notAffectedByScopes
{
    // store an access token
    NSDictionary *clientInfo = @{ @"uid" : _user1.uid, @"utid" : _user1.utid };
    MSALRefreshTokenCacheItem *rtItem =
    [[MSALRefreshTokenCacheItem alloc] initWithJson:@{ @"refresh_token" : @"i am a refresh token!",
                                                       @"environment" : _testEnvironment,
                                                       @"displayable_id" : _user1.displayableId,
                                                       @"name" : _user1.name,
                                                       @"identity_provider" : _user1.identityProvider,
                                                       @"client_id" : _testClientId,
                                                       @"client_info" : [clientInfo base64UrlJson]
                                                       }
                                              error:nil];
    XCTAssertTrue([_cache.dataSource addOrUpdateRefreshTokenItem:rtItem context:nil error:nil]);
    
    //prepare requestParameter
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = _testAuthority;
    requestParam.clientId = _testClientId;
    requestParam.user = _user1;
    [requestParam setScopesFromArray:@[@"User.Read", @"scope.notexist"]];
    XCTAssertNotNil([_cache findRefreshToken:requestParam context:nil error:nil]);
}

- (void)testSaveAndRetrieveRefreshToken
{
    //prepare token response and save AT/RT
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:_testAuthority.msalHostWithPort
                                                                                      clientId:_testClientId
                                                                                      response:_testTokenResponse];
    [_cache saveAccessAndRefreshToken:_requestParam1 response:_testTokenResponse context:nil error:nil];
    
    //retrieve RT
    MSALRefreshTokenCacheItem *rtItemInCache = [_cache findRefreshToken:_requestParam1 context:nil error:nil];
    
    //compare RT with the RT retrieved from cache
    XCTAssertTrue([MSALTestTokenCacheItemUtil areRefreshTokensEqual:rtItem tokenB:rtItemInCache]);
}

- (void)testDeleteTokens
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
    XCTAssertNil([_cache findAccessToken:_requestParam1 context:nil authorityFound:nil error:nil]);
    XCTAssertNil([_cache findRefreshToken:_requestParam1 context:nil error:nil]);
    
    //there should be one AT and one RT left in cache, both are for user 2
    XCTAssertEqual([_cache.dataSource getAccessTokenItemsWithKey:nil context:nil error:nil].count, 1);
    XCTAssertEqual([_cache.dataSource allRefreshTokens:nil context:nil error:nil].count, 1);
    
    MSALAccessTokenCacheItem *atItemInCache2 = [_cache findAccessToken:_requestParam2 context:nil authorityFound:nil error:nil];
    MSALRefreshTokenCacheItem *rtItemInCache2 = [_cache findRefreshToken:_requestParam2 context:nil error:nil];
    XCTAssertTrue([MSALTestTokenCacheItemUtil areAccessTokensEqual:atItem2 tokenB:atItemInCache2]);
    XCTAssertTrue([MSALTestTokenCacheItemUtil areRefreshTokensEqual:rtItem2 tokenB:rtItemInCache2]);
}

- (void)testDeleteTokens_nilUser
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

- (void)testAmbugiousFindAccessTokenCall
{
    //store 2 tokens
    [_cache saveAccessAndRefreshToken:_requestParam1 response:_testTokenResponse context:nil error:nil];
    [_cache saveAccessAndRefreshToken:_requestParam2 response:_testTokenResponse2 context:nil error:nil];
    
    //remove user specifier to make an ambigious query
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = _testAuthority;
    requestParam.clientId = _testClientId;
    [requestParam setScopesFromArray:@[@"User.Read"]];
    requestParam.user = nil;
    
    XCTAssertNil([_cache findAccessToken:requestParam context:nil authorityFound:nil error:nil]);
}

- (void)testFindExpiredAccessToken
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
    
    //token is returned so it is not returned
    XCTAssertNil([_cache findAccessToken:_requestParam1 context:nil authorityFound:nil error:nil]);
}

- (void)testFindAccessTokenWithoutAuthority
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
    MSALAccessTokenCacheItem *atItemInCache = [_cache findAccessToken:_requestParam1 context:nil authorityFound:&authorityFound error:nil];
    XCTAssertNotNil(atItemInCache);
    XCTAssertNil(authorityFound);
}
- (void)testFindAccessTokenWithoutAuthority_emptyCache
{
    //retrieve without authority in empty cache
    _requestParam1.unvalidatedAuthority = nil;
    NSString *authorityFound;
    MSALAccessTokenCacheItem *atItemInCache = [_cache findAccessToken:_requestParam1 context:nil authorityFound:&authorityFound error:nil];
    XCTAssertNil(atItemInCache);
    XCTAssertNil(authorityFound);
}

- (void)testFindAccessTokenWithoutAuthority_multipleMatchedTokens
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
    NSError *error;
    MSALAccessTokenCacheItem *atItemInCache = [_cache findAccessToken:_requestParam1 context:nil authorityFound:&authorityFound error:&error];
    XCTAssertNil(atItemInCache);
    XCTAssertNil(authorityFound);
    XCTAssertEqual(error.code, MSALErrorMultipleMatchesNoAuthoritySpecified);
}

- (void)testFindAccessTokenWithoutAuthority_noMatchButFoundUniqueAuthority
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
    MSALAccessTokenCacheItem *atItemInCache = [_cache findAccessToken:_requestParam1 context:nil authorityFound:&authorityFound error:nil];
    XCTAssertNil(atItemInCache);
    XCTAssertEqualObjects(authorityFound, _testAuthority.absoluteString);
}

- (void)testFindAccessTokenWithoutAuthority_noMatchAndNoUniqueAuthority
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
    MSALAccessTokenCacheItem *atItemInCache = [_cache findAccessToken:_requestParam1 context:nil authorityFound:&authorityFound error:nil];
    XCTAssertNil(atItemInCache);
    XCTAssertNil(authorityFound);
}

@end
