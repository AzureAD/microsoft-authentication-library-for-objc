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
#import "MSALKeychainTokenCache.h"
#import "MSALKeychainTokenCache+Internal.h"
#import "MSALTokenResponse.h"
#import "MSALAccessTokenCacheItem.h"
#import "MSALTokenCacheKey.h"
#import "MSALRefreshTokenCacheItem.h"
#import "MSALIdToken.h"

@interface MSALKeychainTokenCacheTests : XCTestCase
{
    MSALKeychainTokenCache *cache;
    MSALTokenResponse *testTokenResponse;
    MSALIdToken *testIdToken;
    MSALUser *testUser;
    NSString *testAuthority;
    NSString *testClientId;
}

@end

@implementation MSALKeychainTokenCacheTests

- (void)setUp {
    [super setUp];
    
    cache = MSALKeychainTokenCache.defaultKeychainCache;
    [cache testRemoveAll];
    
    NSString *responseBase64String = @"eyJ0b2tlbl90eXBlIjoiQmVhcmVyIiwic2NvcGUiOiJtYWlsLnJlYWQgdXNlci5yZWFkIiwiZXhwaXJlc19pbiI6MzU5OSwiZXh0X2V4cGlyZXNfaW4iOjEwODAwLCJhY2Nlc3NfdG9rZW4iOiJleUowZVhBaU9pSktWMVFpTENKdWIyNWpaU0k2SWtGUlFVSkJRVUZCUVVGRVVrNVpVbEV6WkdoU1UzSnRMVFJMTFdGa2NFTktUWEppUlhaWlEwaGlZMUJxUWs4d1psaGxiV3RTYkZOc1lqSnZaRE5SUmtkb2QzVlBXRWd5VUc1NVpHbHpkRE5xTFZScGJscHZTMGxxUWpadGIxQm9kM3BWTFdJd04yTXpSRXhOWlROSGFuVnZURko1VEdsQlFTSXNJbUZzWnlJNklsSlRNalUySWl3aWVEVjBJam9pWDFWbmNWaEhYM1JOVEdSMVUwb3hWRGhqWVVoNFZUZGpUM1JqSWl3aWEybGtJam9pWDFWbmNWaEhYM1JOVEdSMVUwb3hWRGhqWVVoNFZUZGpUM1JqSW4wLmV5SmhkV1FpT2lKb2RIUndjem92TDJkeVlYQm9MbTFwWTNKdmMyOW1kQzVqYjIwaUxDSnBjM01pT2lKb2RIUndjem92TDNOMGN5NTNhVzVrYjNkekxtNWxkQzh3TWpnM1pqazJNeTB5WkRjeUxUUXpOak10T1dVellTMDFOekExWXpWaU1HWXdNekV2SWl3aWFXRjBJam94TkRnNE1qWTBNVGt4TENKdVltWWlPakUwT0RneU5qUXhPVEVzSW1WNGNDSTZNVFE0T0RJMk9EQTVNU3dpWVdOeUlqb2lNU0lzSW1GdGNpSTZXeUp3ZDJRaVhTd2lZWEJ3WDJScGMzQnNZWGx1WVcxbElqb2lUbUYwYVhabFFYQndJaXdpWVhCd2FXUWlPaUkxWVRRek5EWTVNUzFqWTJJeUxUUm1aREV0WWprM1lpMWlOalJpWTJaaVl6QXpabU1pTENKaGNIQnBaR0ZqY2lJNklqQWlMQ0psWDJWNGNDSTZNVEE0TURBc0ltWmhiV2xzZVY5dVlXMWxJam9pVlhObGNpSXNJbWRwZG1WdVgyNWhiV1VpT2lKVGFXMXdiR1VpTENKcGNHRmtaSElpT2lJeE56UXVOaTQ0T1M0eU1UY2lMQ0p1WVcxbElqb2lVMmx0Y0d4bElGVnpaWElpTENKdmFXUWlPaUl5T1dZek9EQTNZUzAwWm1Jd0xUUXlaakl0WVRRMFlTMHlNelpoWVRCallqTm1PVGNpTENKd2JHRjBaaUk2SWpJaUxDSndkV2xrSWpvaU1UQXdNemRHUmtVNU5EVTRNamM1UXlJc0luTmpjQ0k2SWsxaGFXd3VVbVZoWkNCVmMyVnlMbEpsWVdRaUxDSnpkV0lpT2lKWlVEQktORkExU2xrdGVXcFdSM0ZoWkdwUmRtYzVNM0F6WWpoMmIxQnhWREJaWjBoSVZYSnFhbEJ6SWl3aWRHbGtJam9pTURJNE4yWTVOak10TW1RM01pMDBNell6TFRsbE0yRXROVGN3TldNMVlqQm1NRE14SWl3aWRXNXBjWFZsWDI1aGJXVWlPaUoxYzJWeVFHMXpaR1YyWlhndWIyNXRhV055YjNOdlpuUXVZMjl0SWl3aWRYQnVJam9pZFhObGNrQnRjMlJsZG1WNExtOXViV2xqY205emIyWjBMbU52YlNJc0luWmxjaUk2SWpFdU1DSjkuQ19rQ2VOdkxGR1B0N1FpcFJrTTlOUm9PRkZOUlhZOFN2THJQcXJaUDItTzFoeXpuTmZyc2gyTjExNjAwUXg2TnhMLS1Bc0o2NUZMSFVDZ0pHZ1hBSVFVSENwc290VkYxcTVWS0ZVd05zQ2g4U0RzYlN2SkxCUGdaaXhMdHNzTWtwLW1wcEFoTDJLX05BTEIySWJMWkdPQ003SkRtN3ROMC1jbVBTcE1lNWNVa0V5ZUlDcHVrQVRuVlkyd1BYc2NvUi1pWjB2MmxHekxLUVllV1dObnVGeWdybUFhb3hCcExLOGlPX2p2Y05qeEFDMWtqaHA0QVlxVGRpRTI5WnRvbVN6TDZ6ZmZCWXFVd0g4Z013bnZZMTRFQUoyb3drU1YwalA4YWV4di01YW5nclB0VmstME5IdHRZUXpuU010WUZmQTVlQ1ItYTZObjZPR2VURFEtWi1RIiwicmVmcmVzaF90b2tlbiI6Ik9BUUFCQUFBQUFBRFJOWVJRM2RoUlNybS00Sy1hZHBDSlQ1N0hXaGZMVXJEd2dweW8yRjc0UE54UjRBSGdXZTB0VW10RFV1US1wUEtuM1o2UGRCVHhrdlg0c0NSekQ2R0YxZVYtVEdCZE5XQ0xndW1BUnl2VGNBcDFCSDE5RUI0X3NlZkI4eEhHeHlMSUYtOG9PaEw5MWh0akJsWkFFZkdLUU94OU5mNExHWWZuYUYyMnBJR3dkZV93ckhPXzNsSnE5TGhoVnhIZnJOWVFFSmdJdjlGS01qdlB5WkpYNnFkTlE3aDl6d2Nndko1a3Yzb3BGc0M4bHhSNk9YX2wxYTYwOWQ2MzViUHNKY0JBYzNNOFdfVDllXzhrbzBUTVItclVvbFBGTjhzNURtSnRXMHFFbGpGa0xkWkluZjlOV2ViZ3hucy1sT0VXUTZsdFd3dUNLRk5GTFJGdFZYaWtNeHljQnVGLWIwVkxKck1hUUxVdjZQWGJpMnBjcnljbjlrek1ZM00tSkdRVUZwcHhmYjdiR2FlZmduXzE4M3pRdlBZdzlwRTA1aEg4eXEtQl9wUlJnX1VMTWRxRFZJd2dndjhMUFZ1VzJBWmJnQkl4M0tSektEaVVOV0phZ2Vya3dHYnZoMWx0eTNCSnFmYWhCYmlCRzVoYWJNQ2Npem5OTFI3X3NUTGxDUzNnaHZocmdQWGprTHp5X1RwSTJCajZGc3ZUODUwZHJmUmJkZGhfQll0YVA2SkU5ZVplY2Q5QnhJcnRPb296VUtOVGs5RUZDRjVEUDdZdkllVWxIalNYbk9Xa1pHZExGU3UxdmxVSDRYZHV3Q1MzXzI1dTd4RG1Mcks0bG9BMEFJUExlcENpOGVBN1pDQnFVemtZUHNQWE40X1NFYzFCUlZYWlNETXJNZU9XUEdsVXFiTkhyUmN4WEVsUUwyMFRYM040X3BFaFo1eHpDdjZPczRaX3Y0dmo3TjlkSUFBIiwiaWRfdG9rZW4iOiJleUowZVhBaU9pSktWMVFpTENKaGJHY2lPaUpTVXpJMU5pSXNJbXRwWkNJNklsOVZaM0ZZUjE5MFRVeGtkVk5LTVZRNFkyRkllRlUzWTA5MFl5SjkuZXlKaGRXUWlPaUkxWVRRek5EWTVNUzFqWTJJeUxUUm1aREV0WWprM1lpMWlOalJpWTJaaVl6QXpabU1pTENKcGMzTWlPaUpvZEhSd2N6b3ZMMnh2WjJsdUxtMXBZM0p2YzI5bWRHOXViR2x1WlM1amIyMHZNREk0TjJZNU5qTXRNbVEzTWkwME16WXpMVGxsTTJFdE5UY3dOV00xWWpCbU1ETXhMM1l5TGpBaUxDSnBZWFFpT2pFME9EZ3lOalF4T1RFc0ltNWlaaUk2TVRRNE9ESTJOREU1TVN3aVpYaHdJam94TkRnNE1qWTRNRGt4TENKdVlXMWxJam9pVTJsdGNHeGxJRlZ6WlhJaUxDSnZhV1FpT2lJeU9XWXpPREEzWVMwMFptSXdMVFF5WmpJdFlUUTBZUzB5TXpaaFlUQmpZak5tT1RjaUxDSndjbVZtWlhKeVpXUmZkWE5sY201aGJXVWlPaUoxYzJWeVFHMXpaR1YyWlhndWIyNXRhV055YjNOdlpuUXVZMjl0SWl3aWMzVmlJam9pVkhGblZIcDZWMkpXTVRadFNXdEpSVEJ6ZUhOU1IxRkdibkpQV1d4QlpVOVpVbmhyWkhsQ2FFUkdieUlzSW5ScFpDSTZJakF5T0RkbU9UWXpMVEprTnpJdE5ETTJNeTA1WlROaExUVTNNRFZqTldJd1pqQXpNU0lzSW5abGNpSTZJakl1TUNKOS5oeV9jOHRacWtzV210dDFuZ1Fsdl8zVDR6aXcyejhkc3RWc2RPQjA5TTVZaVhZU0dDZTZqTWRkcjY2Z0NFN0xncjZVRGRhRzZlWUZaSVF2SGFwaVVMSVo4Vi1nMC04WmEwS0t0SXprR3NMMFEybWhXRkVETl9PSUZNcE8welU4SzVXQVJzQ3g0SlgxY3BucWVValdxZ1hNVHV0d0lPeUdrWXZLUDBMbXlnMURKNHpnclpyZE1VanIwZ3J1SzRIaDB4QUM2bUpnNXVzbEgteEpUN1ZpV1ItUXVtRm9OU3VGWEgyanhKblB4OVlzeXhpVnB0a0plQTZlTFNRWXJqNVJaY3BGbklldHFnREt1R3JQd0xHaXFoa18tUGdldS1Sc0lkQzQ2dUN0VXlBVElzZWhrT015X0JsbXJnMUw3OU5GSWhGMUVpenktZ25ZY241ZV9LMG1jdHcifQ==";
    NSData* responseData = [[NSData alloc] initWithBase64EncodedString:responseBase64String options:0];
    testTokenResponse = [[MSALTokenResponse alloc] initWithData:responseData error:nil];
    
    testIdToken = [[MSALIdToken alloc] initWithRawIdToken:@"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9VZ3FYR190TUxkdVNKMVQ4Y2FIeFU3Y090YyJ9.eyJhdWQiOiI1YTQzNDY5MS1jY2IyLTRmZDEtYjk3Yi1iNjRiY2ZiYzAzZmMiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vMDI4N2Y5NjMtMmQ3Mi00MzYzLTllM2EtNTcwNWM1YjBmMDMxL3YyLjAiLCJpYXQiOjE0ODgyNjQxOTEsIm5iZiI6MTQ4ODI2NDE5MSwiZXhwIjoxNDg4MjY4MDkxLCJuYW1lIjoiU2ltcGxlIFVzZXIiLCJvaWQiOiIyOWYzODA3YS00ZmIwLTQyZjItYTQ0YS0yMzZhYTBjYjNmOTciLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJ1c2VyQG1zZGV2ZXgub25taWNyb3NvZnQuY29tIiwic3ViIjoiVHFnVHp6V2JWMTZtSWtJRTBzeHNSR1FGbnJPWWxBZU9ZUnhrZHlCaERGbyIsInRpZCI6IjAyODdmOTYzLTJkNzItNDM2My05ZTNhLTU3MDVjNWIwZjAzMSIsInZlciI6IjIuMCJ9.hy_c8tZqksWmtt1ngQlv_3T4ziw2z8dstVsdOB09M5YiXYSGCe6jMddr66gCE7Lgr6UDdaG6eYFZIQvHapiULIZ8V-g0-8Za0KKtIzkGsL0Q2mhWFEDN_OIFMpO0zU8K5WARsCx4JX1cpnqeUjWqgXMTutwIOyGkYvKP0Lmyg1DJ4zgrZrdMUjr0gruK4Hh0xAC6mJg5uslH-xJT7ViWR-QumFoNSuFXH2jxJnPx9YsyxiVptkJeA6eLSQYrj5RZcpFnIetqgDKuGrPwLGiqhk_-Pgeu-RsIdC46uCtUyATIsehkOMy_Blmrg1L79NFIhF1Eizy-gnYcn5e_K0mctw"];
    
    testAuthority = @"https://login.microsoftonline.com/common";
    testClientId = @"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc";
    testUser = [[MSALUser alloc] initWithIdToken:testIdToken
                                                authority:testAuthority
                                                 clientId:testClientId];
}

- (void)tearDown {
    
    [cache testRemoveAll];
    cache = nil;
    
    [super tearDown];
}

- (void)testSaveAndRetrieveAccessToken {
    
    //prepare request parameters
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = [NSURL URLWithString:testAuthority];
    requestParam.clientId = testClientId;
    [requestParam setScopesFromArray:@[@"mail.read", @"User.Read"]];
    requestParam.user = testUser;

    //prepare token response and save AT/RT
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:testAuthority
                                                                                  clientId:testClientId
                                                                                  response:testTokenResponse];
    [cache saveAccessAndRefreshToken:requestParam response:testTokenResponse error:nil];
    
    //retrieve AT
    MSALAccessTokenCacheItem *atItemInCache = [cache findAccessToken:requestParam error:nil];
    
    //compare AT with the AT retrieved from cache
    XCTAssertEqualObjects(atItem.tokenType, atItemInCache.tokenType);
    XCTAssertEqualObjects(atItem.expiresOn.description, atItemInCache.expiresOn.description);
    XCTAssertEqualObjects(atItem.scope.msalToString, atItemInCache.scope.msalToString);
    XCTAssertTrue(atItem.isExpired==atItemInCache.isExpired);
    XCTAssertEqualObjects(atItem.tokenCacheKey.service, atItemInCache.tokenCacheKey.service);
    XCTAssertEqualObjects(atItem.tokenCacheKey.account, atItemInCache.tokenCacheKey.account);
    XCTAssertEqualObjects(atItem.authority, atItemInCache.authority);
    XCTAssertEqualObjects(atItem.clientId, atItemInCache.clientId);
    XCTAssertEqualObjects(atItem.tenantId, atItemInCache.tenantId);
    XCTAssertEqualObjects(atItem.rawIdToken, atItemInCache.rawIdToken);
    XCTAssertEqualObjects(atItem.uniqueId, atItemInCache.uniqueId);
    XCTAssertEqualObjects(atItem.displayableId, atItemInCache.displayableId);
    XCTAssertEqualObjects(atItem.homeObjectId, atItemInCache.homeObjectId);
    XCTAssertEqualObjects(atItem.user.uniqueId, atItemInCache.user.uniqueId);
    XCTAssertEqualObjects(atItem.user.displayableId, atItemInCache.user.displayableId);
    XCTAssertEqualObjects(atItem.user.name, atItemInCache.user.name);
    XCTAssertEqualObjects(atItem.user.identityProvider, atItemInCache.user.identityProvider);
    XCTAssertEqualObjects(atItem.user.clientId, atItemInCache.user.clientId);
    XCTAssertEqualObjects(atItem.user.authority, atItemInCache.user.authority);
    XCTAssertEqualObjects(atItem.user.homeObjectId, atItemInCache.user.homeObjectId);
}

- (void)testSaveAndRetrieveRefreshToken {
    
    //prepare request parameters
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = [NSURL URLWithString:testAuthority];
    requestParam.clientId = testClientId;
    [requestParam setScopesFromArray:@[@"mail.read", @"User.Read"]];
    requestParam.user = testUser;

    //prepare token response and save AT/RT
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithAuthority:nil
                                                                                  clientId:testClientId
                                                                                  response:testTokenResponse];
    [cache saveAccessAndRefreshToken:requestParam response:testTokenResponse error:nil];
    
    //retrieve RT
    MSALRefreshTokenCacheItem *rtItemInCache = [cache findRefreshToken:requestParam error:nil];
    
    //compare RT with the RT retrieved from cache
    XCTAssertEqualObjects(rtItem.tokenCacheKey.service, rtItemInCache.tokenCacheKey.service);
    XCTAssertEqualObjects(rtItem.tokenCacheKey.account, rtItemInCache.tokenCacheKey.account);
    XCTAssertEqualObjects(rtItem.authority, rtItemInCache.authority);
    XCTAssertEqualObjects(rtItem.clientId, rtItemInCache.clientId);
    XCTAssertEqualObjects(rtItem.uniqueId, rtItemInCache.uniqueId);
    XCTAssertEqualObjects(rtItem.displayableId, rtItemInCache.displayableId);
    XCTAssertEqualObjects(rtItem.homeObjectId, rtItemInCache.homeObjectId);
    XCTAssertEqualObjects(rtItem.user.uniqueId, rtItemInCache.user.uniqueId);
    XCTAssertEqualObjects(rtItem.user.displayableId, rtItemInCache.user.displayableId);
    XCTAssertEqualObjects(rtItem.user.name, rtItemInCache.user.name);
    XCTAssertEqualObjects(rtItem.user.identityProvider, rtItemInCache.user.identityProvider);
    XCTAssertEqualObjects(rtItem.user.clientId, rtItemInCache.user.clientId);
    XCTAssertEqualObjects(rtItem.user.authority, rtItemInCache.user.authority);
    XCTAssertEqualObjects(rtItem.user.homeObjectId, rtItemInCache.user.homeObjectId);
}

- (void)testDeleteAccessToken {
    
    //prepare request parameters
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = [NSURL URLWithString:testAuthority];
    requestParam.clientId = testClientId;
    [requestParam setScopesFromArray:@[@"mail.read", @"User.Read"]];
    requestParam.user = testUser;

    //prepare token response and save AT/RT
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:testAuthority
                                                                                  clientId:testClientId
                                                                                  response:testTokenResponse];
    [cache saveAccessAndRefreshToken:requestParam response:testTokenResponse error:nil];
    
    //retrieve AT
    MSALAccessTokenCacheItem *atItemInCache = [cache findAccessToken:requestParam error:nil];
    
    //compare AT with the AT retrieved from cache
    XCTAssertEqualObjects(atItem.tokenCacheKey.service, atItemInCache.tokenCacheKey.service);
    XCTAssertEqualObjects(atItem.tokenCacheKey.account, atItemInCache.tokenCacheKey.account);
    
    //delete AT
    [cache deleteAccessToken:atItemInCache error:nil];
    XCTAssertNil([cache findAccessToken:requestParam error:nil]);
}

- (void)testDeleteRefreshToken {
    
    //prepare request parameters
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = [NSURL URLWithString:testAuthority];
    requestParam.clientId = testClientId;
    [requestParam setScopesFromArray:@[@"mail.read", @"User.Read"]];
    requestParam.user = testUser;
    
    //prepare token response and save AT/RT
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithAuthority:nil
                                                                                    clientId:testClientId
                                                                                    response:testTokenResponse];
    [cache saveAccessAndRefreshToken:requestParam response:testTokenResponse error:nil];
    
    //retrieve RT
    MSALRefreshTokenCacheItem *rtItemInCache = [cache findRefreshToken:requestParam error:nil];
    
    //compare RT with the RT retrieved from cache
    XCTAssertEqualObjects(rtItem.tokenCacheKey.service, rtItemInCache.tokenCacheKey.service);
    XCTAssertEqualObjects(rtItem.tokenCacheKey.account, rtItemInCache.tokenCacheKey.account);
    
    //delete RT
    [cache deleteRefreshToken:rtItemInCache error:nil];
    XCTAssertNil([cache findRefreshToken:requestParam error:nil]);
}

- (void)testGetUsers {
    //prepare request parameters
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = [NSURL URLWithString:testAuthority];
    requestParam.clientId = testClientId;
    [requestParam setScopesFromArray:@[@"mail.read", @"User.Read"]];
    requestParam.user = testUser;
    
    //save AT/RT
    [cache saveAccessAndRefreshToken:requestParam response:testTokenResponse error:nil];
    
    //get all users using client id
    NSArray<MSALUser *> *users = [cache getUsers:requestParam.clientId];
    XCTAssertTrue(users.count==1);
    XCTAssertEqualObjects(users[0].uniqueId, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(users[0].displayableId, @"user@msdevex.onmicrosoft.com");
    XCTAssertEqualObjects(users[0].name, @"Simple User");
    XCTAssertEqualObjects(users[0].identityProvider, @"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031/v2.0");
    XCTAssertEqualObjects(users[0].clientId, @"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc");
    XCTAssertEqualObjects(users[0].authority, nil);
    XCTAssertEqualObjects(users[0].homeObjectId, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    
    //get all users using nil client id
    users = [cache getUsers:nil];
    XCTAssertTrue(users.count==1);
    XCTAssertEqualObjects(users[0].uniqueId, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(users[0].displayableId, @"user@msdevex.onmicrosoft.com");
    XCTAssertEqualObjects(users[0].name, @"Simple User");
    XCTAssertEqualObjects(users[0].identityProvider, @"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031/v2.0");
    XCTAssertEqualObjects(users[0].clientId, @"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc");
    XCTAssertEqualObjects(users[0].authority, nil);
    XCTAssertEqualObjects(users[0].homeObjectId, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    
    //get all users using non-existant client id
    users = [cache getUsers:@"fake-client-id"];
    XCTAssertTrue(users.count==0);
}

@end
