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
#import "MSALTokenCache.h"
#import "MSALIdToken.h"
#import "MSALTokenResponse.h"
#import "MSALClientInfo.h"

@interface MSALKeychainTokenCacheTests : XCTestCase
{
    MSALTokenCacheAccessor *cache;
    MSALKeychainTokenCache *dataSource;
    MSALTokenResponse *testTokenResponse;
    MSALTokenResponse *testTokenResponse2;
    MSALIdToken *testIdToken;
    MSALIdToken *testIdToken2;
    MSALUser *testUser;
    MSALUser *testUser2;
    MSALClientInfo *testClientInfo;
    MSALClientInfo *testClientInfo2;
    NSURL *testAuthority;
    NSString *testEnvironment;
    NSString *testClientId;
}

@end

@implementation MSALKeychainTokenCacheTests

- (void)setUp {
    [super setUp];
    
    dataSource = MSALKeychainTokenCache.defaultKeychainCache;
    [dataSource testRemoveAll];
    cache = [[MSALTokenCacheAccessor alloc] initWithDataSource:dataSource];
    
    testAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    testEnvironment = testAuthority.host;
    testClientId = @"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc";
    
    NSString *responseBase64String = @"eyJ0b2tlbl90eXBlIjoiQmVhcmVyIiwic2NvcGUiOiJtYWlsLnJlYWQgdXNlci5yZWFkIiwiZXhwaXJlc19pbiI6MzU5OSwiZXh0X2V4cGlyZXNfaW4iOjEwODAwLCJhY2Nlc3NfdG9rZW4iOiJmYWtlLWFjY2Vzcy10b2tlbiIsInJlZnJlc2hfdG9rZW4iOiJmYWtlLXJlZnJlc2gtdG9rZW4iLCJpZF90b2tlbiI6ImV5SjBlWEFpT2lKS1YxUWlMQ0poYkdjaU9pSlNVekkxTmlJc0ltdHBaQ0k2SWw5VlozRllSMTkwVFV4a2RWTktNVlE0WTJGSWVGVTNZMDkwWXlKOS5leUpoZFdRaU9pSTFZVFF6TkRZNU1TMWpZMkl5TFRSbVpERXRZamszWWkxaU5qUmlZMlppWXpBelptTWlMQ0pwYzNNaU9pSm9kSFJ3Y3pvdkwyeHZaMmx1TG0xcFkzSnZjMjltZEc5dWJHbHVaUzVqYjIwdk1ESTROMlk1TmpNdE1tUTNNaTAwTXpZekxUbGxNMkV0TlRjd05XTTFZakJtTURNeEwzWXlMakFpTENKcFlYUWlPakUwT0RneU5qUXhPVEVzSW01aVppSTZNVFE0T0RJMk5ERTVNU3dpWlhod0lqb3hORGc0TWpZNE1Ea3hMQ0p1WVcxbElqb2lVMmx0Y0d4bElGVnpaWElpTENKdmFXUWlPaUl5T1dZek9EQTNZUzAwWm1Jd0xUUXlaakl0WVRRMFlTMHlNelpoWVRCallqTm1PVGNpTENKd2NtVm1aWEp5WldSZmRYTmxjbTVoYldVaU9pSjFjMlZ5UUcxelpHVjJaWGd1YjI1dGFXTnliM052Wm5RdVkyOXRJaXdpYzNWaUlqb2lWSEZuVkhwNlYySldNVFp0U1d0SlJUQnplSE5TUjFGR2JuSlBXV3hCWlU5WlVuaHJaSGxDYUVSR2J5SXNJblJwWkNJNklqQXlPRGRtT1RZekxUSmtOekl0TkRNMk15MDVaVE5oTFRVM01EVmpOV0l3WmpBek1TSXNJblpsY2lJNklqSXVNQ0o5Lmh5X2M4dFpxa3NXbXR0MW5nUWx2XzNUNHppdzJ6OGRzdFZzZE9CMDlNNVlpWFlTR0NlNmpNZGRyNjZnQ0U3TGdyNlVEZGFHNmVZRlpJUXZIYXBpVUxJWjhWLWcwLThaYTBLS3RJemtHc0wwUTJtaFdGRUROX09JRk1wTzB6VThLNVdBUnNDeDRKWDFjcG5xZVVqV3FnWE1UdXR3SU95R2tZdktQMExteWcxREo0emdyWnJkTVVqcjBncnVLNEhoMHhBQzZtSmc1dXNsSC14SlQ3VmlXUi1RdW1Gb05TdUZYSDJqeEpuUHg5WXN5eGlWcHRrSmVBNmVMU1FZcmo1UlpjcEZuSWV0cWdES3VHclB3TEdpcWhrXy1QZ2V1LVJzSWRDNDZ1Q3RVeUFUSXNlaGtPTXlfQmxtcmcxTDc5TkZJaEYxRWl6eS1nblljbjVlX0swbWN0dyJ9";
    NSData* responseData = [[NSData alloc] initWithBase64EncodedString:responseBase64String options:0];
    testTokenResponse = [[MSALTokenResponse alloc] initWithData:responseData error:nil];
    
    testIdToken = [[MSALIdToken alloc] initWithRawIdToken:@"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9VZ3FYR190TUxkdVNKMVQ4Y2FIeFU3Y090YyJ9.eyJhdWQiOiI1YTQzNDY5MS1jY2IyLTRmZDEtYjk3Yi1iNjRiY2ZiYzAzZmMiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vMDI4N2Y5NjMtMmQ3Mi00MzYzLTllM2EtNTcwNWM1YjBmMDMxL3YyLjAiLCJpYXQiOjE0ODgyNjQxOTEsIm5iZiI6MTQ4ODI2NDE5MSwiZXhwIjoxNDg4MjY4MDkxLCJuYW1lIjoiU2ltcGxlIFVzZXIiLCJvaWQiOiIyOWYzODA3YS00ZmIwLTQyZjItYTQ0YS0yMzZhYTBjYjNmOTciLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJ1c2VyQG1zZGV2ZXgub25taWNyb3NvZnQuY29tIiwic3ViIjoiVHFnVHp6V2JWMTZtSWtJRTBzeHNSR1FGbnJPWWxBZU9ZUnhrZHlCaERGbyIsInRpZCI6IjAyODdmOTYzLTJkNzItNDM2My05ZTNhLTU3MDVjNWIwZjAzMSIsInZlciI6IjIuMCJ9.hy_c8tZqksWmtt1ngQlv_3T4ziw2z8dstVsdOB09M5YiXYSGCe6jMddr66gCE7Lgr6UDdaG6eYFZIQvHapiULIZ8V-g0-8Za0KKtIzkGsL0Q2mhWFEDN_OIFMpO0zU8K5WARsCx4JX1cpnqeUjWqgXMTutwIOyGkYvKP0Lmyg1DJ4zgrZrdMUjr0gruK4Hh0xAC6mJg5uslH-xJT7ViWR-QumFoNSuFXH2jxJnPx9YsyxiVptkJeA6eLSQYrj5RZcpFnIetqgDKuGrPwLGiqhk_-Pgeu-RsIdC46uCtUyATIsehkOMy_Blmrg1L79NFIhF1Eizy-gnYcn5e_K0mctw"];
    
    testClientInfo = [[MSALClientInfo alloc] initWithRawClientInfo:@"eyJ1aWQiOiIyOWYzODA3YS00ZmIwLTQyZjItYTQ0YS0yMzZhYTBjYjNmOTciLCJ1dGlkIjoiMDI4N2Y5NjMtMmQ3Mi00MzYzLTllM2EtNTcwNWM1YjBmMDMxIn0"
error:nil];
    
    testUser = [[MSALUser alloc] initWithIdToken:testIdToken
                                      clientInfo:testClientInfo
                                     environment:testEnvironment];
    
    NSString *responseBase64String2 = @"eyJ0b2tlbl90eXBlIjoiQmVhcmVyIiwic2NvcGUiOiJ1c2VyLnJlYWQiLCJleHBpcmVzX2luIjozNTk5LCJleHRfZXhwaXJlc19pbiI6MTA4MDAsImFjY2Vzc190b2tlbiI6ImZha2UtYWNjZXNzLXRva2VuIiwicmVmcmVzaF90b2tlbiI6ImZha2UtcmVmcmVzaC10b2tlbiIsImlkX3Rva2VuIjoiZXlKMGVYQWlPaUpLVjFRaUxDSmhiR2NpT2lKU1V6STFOaUlzSW10cFpDSTZJbUV6VVU0d1FscFROM00wYms0dFFtUnlhbUpHTUZsZlRHUk5UU0o5LmV5SmhkV1FpT2lJMVlUUXpORFk1TVMxalkySXlMVFJtWkRFdFlqazNZaTFpTmpSaVkyWmlZekF6Wm1NaUxDSnBjM01pT2lKb2RIUndjem92TDJ4dloybHVMbTFwWTNKdmMyOW1kRzl1YkdsdVpTNWpiMjB2TURJNE4yWTVOak10TW1RM01pMDBNell6TFRsbE0yRXROVGN3TldNMVlqQm1NRE14TDNZeUxqQWlMQ0pwWVhRaU9qRTBPRGsyTVRnd05qVXNJbTVpWmlJNk1UUTRPVFl4T0RBMk5Td2laWGh3SWpveE5EZzVOakl4T1RZMUxDSnVZVzFsSWpvaVUybHRjR3hsSUZWelpYSWdNaUlzSW05cFpDSTZJamRtWW1aaE5USTBMVGd5WVdFdE5HVXpZUzA1Wm1JeUxXUm1ZalJpTXpCaFpqTTJaQ0lzSW5CeVpXWmxjbkpsWkY5MWMyVnlibUZ0WlNJNkluVnpaWEl5UUcxelpHVjJaWGd1YjI1dGFXTnliM052Wm5RdVkyOXRJaXdpYzNWaUlqb2lRMnBxZGpOU2VIVnNNM2REZUY5M2IzbGxhRzh5UVZwMVZtMHlOMUpzZFZGU2EzcFNXSGt6TjFGcVdTSXNJblJwWkNJNklqQXlPRGRtT1RZekxUSmtOekl0TkRNMk15MDVaVE5oTFRVM01EVmpOV0l3WmpBek1TSXNJblpsY2lJNklqSXVNQ0o5LkZtVmxjVC05MDZyeEhWdzBZVGRUTnllZEU4azk3UHdlbHN3aWE0N2VVZXZncmx2M0FYTXRTQTl4ZGt1Z203aklnVmllWUNlT1R3d0VSODA4bFJGNjF0UzBlMkRvb2FnS3laNGVDanJvdjdibW1tMTJxYU9TS25PVW9fVU9xUF90SGFhTUpUNVh1MzlJY2twOHhoRXQzRXR0Qk9VcnNBRTF5WkVkNzZDcHlMX0xmbjBKY3Zyb0JlNzRVSWRVbnJqWnB5TzE0TFpXNzlzTHZ0aWVVRUJtTnVQQTFMeFJzWW5HQk5ZZU5idUNrX3cwVTk1d29ENnV3Qk0zMklGY0lFTlRvRUJjRjNRVGtycUwxb19VbllnRkR2Mlo4R0EydXBBejQ3V1JaMC1JLUNnTVk2Y1NWcHZ1Vk9hVHpDRHVWdXhFZklNYkc5QmFrSGNDWHg1RGJVblh6dyJ9";
    
    NSData* responseData2 = [[NSData alloc] initWithBase64EncodedString:responseBase64String2 options:0];
    testTokenResponse2 = [[MSALTokenResponse alloc] initWithData:responseData2 error:nil];
    
    testIdToken2 = [[MSALIdToken alloc] initWithRawIdToken:@"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6ImEzUU4wQlpTN3M0bk4tQmRyamJGMFlfTGRNTSJ9.eyJhdWQiOiI1YTQzNDY5MS1jY2IyLTRmZDEtYjk3Yi1iNjRiY2ZiYzAzZmMiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vMDI4N2Y5NjMtMmQ3Mi00MzYzLTllM2EtNTcwNWM1YjBmMDMxL3YyLjAiLCJpYXQiOjE0ODk2MTgwNjUsIm5iZiI6MTQ4OTYxODA2NSwiZXhwIjoxNDg5NjIxOTY1LCJuYW1lIjoiU2ltcGxlIFVzZXIgMiIsIm9pZCI6IjdmYmZhNTI0LTgyYWEtNGUzYS05ZmIyLWRmYjRiMzBhZjM2ZCIsInByZWZlcnJlZF91c2VybmFtZSI6InVzZXIyQG1zZGV2ZXgub25taWNyb3NvZnQuY29tIiwic3ViIjoiQ2pqdjNSeHVsM3dDeF93b3llaG8yQVp1Vm0yN1JsdVFSa3pSWHkzN1FqWSIsInRpZCI6IjAyODdmOTYzLTJkNzItNDM2My05ZTNhLTU3MDVjNWIwZjAzMSIsInZlciI6IjIuMCJ9.FmVlcT-906rxHVw0YTdTNyedE8k97Pwelswia47eUevgrlv3AXMtSA9xdkugm7jIgVieYCeOTwwER808lRF61tS0e2DooagKyZ4eCjrov7bmmm12qaOSKnOUo_UOqP_tHaaMJT5Xu39Ickp8xhEt3EttBOUrsAE1yZEd76CpyL_Lfn0JcvroBe74UIdUnrjZpyO14LZW79sLvtieUEBmNuPA1LxRsYnGBNYeNbuCk_w0U95woD6uwBM32IFcIENToEBcF3QTkrqL1o_UnYgFDv2Z8GA2upAz47WRZ0-I-CgMY6cSVpvuVOaTzCDuVuxEfIMbG9BakHcCXx5DbUnXzw"];
    
    testClientInfo2 = [[MSALClientInfo alloc] initWithRawClientInfo:@"eyJ1aWQiOiI3ZmJmYTUyNC04MmFhLTRlM2EtOWZiMi1kZmI0YjMwYWYzNmQiLCJ1dGlkIjoiMDI4N2Y5NjMtMmQ3Mi00MzYzLTllM2EtNTcwNWM1YjBmMDMxIn0"
                                                              error:nil];
    testUser2 = [[MSALUser alloc] initWithIdToken:testIdToken2
                                       clientInfo:testClientInfo2
                                      environment:testEnvironment];
}

- (void)tearDown {
    
    [(MSALKeychainTokenCache *)cache.dataSource testRemoveAll];
    cache = nil;
    
    [super tearDown];
}

- (void)testBadInit
{
    XCTAssertThrows([MSALKeychainTokenCache new]);
}

- (void)testSaveAndRetrieveAccessToken {
    
    //prepare request parameters
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = testAuthority;
    requestParam.clientId = testClientId;
    [requestParam setScopesFromArray:@[@"User.Read"]];
    requestParam.user = testUser;

    //prepare token response and save AT/RT
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:testAuthority
                                                                                  clientId:testClientId
                                                                                  response:testTokenResponse];
    [cache saveAccessAndRefreshToken:requestParam response:testTokenResponse error:nil];
    
    //retrieve AT
    MSALAccessTokenCacheItem *atItemInCache = [cache findAccessToken:requestParam error:nil];
    
    //compare AT with the AT retrieved from cache
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
    XCTAssertEqualObjects(atItem.clientInfo.uniqueIdentifier, atItemInCache.clientInfo.uniqueIdentifier);
    XCTAssertEqualObjects(atItem.clientInfo.uniqueTenantIdentifier, atItemInCache.clientInfo.uniqueTenantIdentifier);
    
    //save the same AT again
    [cache saveAccessAndRefreshToken:requestParam response:testTokenResponse error:nil];
    
    //there should be still one AT in cache
    XCTAssertEqual([dataSource getAccessTokenItemsWithKey:nil correlationId:nil error:nil].count, 1);
    
    //change the scope and retrive the AT again
    [requestParam setScopesFromArray:@[@"User.Read", @"scope.notexist"]];
    XCTAssertNil([cache findAccessToken:requestParam error:nil]);
    
    //save a second AT
    MSALRequestParameters *requestParam2 = [MSALRequestParameters new];
    requestParam2.unvalidatedAuthority = testAuthority;
    requestParam2.clientId = testClientId;
    [requestParam2 setScopesFromArray:@[@"User.Read"]];
    requestParam2.user = testUser2;
    
    MSALAccessTokenCacheItem *atItem2 = [[MSALAccessTokenCacheItem alloc] initWithAuthority:testAuthority
                                                                                  clientId:testClientId
                                                                                  response:testTokenResponse2];
    [cache saveAccessAndRefreshToken:requestParam2 response:testTokenResponse2 error:nil];
    
    //there should be two ATs in cache
    XCTAssertEqual([dataSource getAccessTokenItemsWithKey:nil correlationId:nil error:nil].count, 2);
    
    //retrieve AT 2
    MSALAccessTokenCacheItem *atItemInCache2 = [cache findAccessToken:requestParam2 error:nil];
    
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
    XCTAssertEqualObjects(atItem2.clientInfo.uniqueIdentifier, atItemInCache2.clientInfo.uniqueIdentifier);
    XCTAssertEqualObjects(atItem2.clientInfo.uniqueTenantIdentifier, atItemInCache2.clientInfo.uniqueTenantIdentifier);
}

- (void)testSaveAndRetrieveRefreshToken {
    
    //prepare request parameters
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = testAuthority;
    requestParam.clientId = testClientId;
    [requestParam setScopesFromArray:@[@"User.Read"]];
    requestParam.user = testUser;

    //prepare token response and save AT/RT
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:testAuthority.host
                                                                                      clientId:testClientId
                                                                                      response:testTokenResponse];
    [cache saveAccessAndRefreshToken:requestParam response:testTokenResponse error:nil];
    
    //retrieve RT
    MSALRefreshTokenCacheItem *rtItemInCache = [cache findRefreshToken:requestParam error:nil];
    
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
    XCTAssertEqualObjects(rtItem.clientInfo.uniqueIdentifier, rtItemInCache.clientInfo.uniqueIdentifier);
    XCTAssertEqualObjects(rtItem.clientInfo.uniqueTenantIdentifier, rtItemInCache.clientInfo.uniqueTenantIdentifier);
    XCTAssertEqualObjects(rtItem.displayableId, rtItemInCache.displayableId);
    XCTAssertEqualObjects(rtItem.name, rtItemInCache.name);
    XCTAssertEqualObjects(rtItem.identityProvider, rtItemInCache.identityProvider);

    //save the same RT again
    [cache saveAccessAndRefreshToken:requestParam response:testTokenResponse error:nil];
    
    //there should be still one RT in cache
    XCTAssertEqual([dataSource getRefreshTokenItemsWithKey:nil correlationId:nil error:nil].count, 1);
    
    //change the scope and retrive the RT again
    [requestParam setScopesFromArray:@[@"User.Read", @"scope.notexist"]];
    XCTAssertNotNil([cache findRefreshToken:requestParam error:nil]);
    
    //save a second RT
    MSALRequestParameters *requestParam2 = [MSALRequestParameters new];
    requestParam2.unvalidatedAuthority = testAuthority;
    requestParam2.clientId = testClientId;
    [requestParam2 setScopesFromArray:@[@"User.Read"]];
    requestParam2.user = testUser2;
    
    MSALRefreshTokenCacheItem *rtItem2 = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:testAuthority.host
                                                                                       clientId:testClientId
                                                                                       response:testTokenResponse2];
    [cache saveAccessAndRefreshToken:requestParam2 response:testTokenResponse2 error:nil];
    
    //there should be two RTs in cache
    XCTAssertEqual([dataSource getRefreshTokenItemsWithKey:nil correlationId:nil error:nil].count, 2);
    
    //retrieve AT 2
    MSALRefreshTokenCacheItem *rtItemInCache2 = [cache findRefreshToken:requestParam2 error:nil];

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
    XCTAssertEqualObjects(rtItem2.clientInfo.uniqueIdentifier, rtItemInCache2.clientInfo.uniqueIdentifier);
    XCTAssertEqualObjects(rtItem2.clientInfo.uniqueTenantIdentifier, rtItemInCache2.clientInfo.uniqueTenantIdentifier);
    XCTAssertEqualObjects(rtItem2.displayableId, rtItemInCache2.displayableId);
    XCTAssertEqualObjects(rtItem2.name, rtItemInCache2.name);
    XCTAssertEqualObjects(rtItem2.identityProvider, rtItemInCache2.identityProvider);
}

- (void)testDeleteTokens {
    
    //prepare request parameters
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = testAuthority;
    requestParam.clientId = testClientId;
    [requestParam setScopesFromArray:@[@"mail.read", @"User.Read"]];
    requestParam.user = testUser;
    
    MSALRequestParameters *requestParam2 = [MSALRequestParameters new];
    requestParam2.unvalidatedAuthority = testAuthority;
    requestParam2.clientId = testClientId;
    [requestParam2 setScopesFromArray:@[@"User.Read"]];
    requestParam2.user = testUser2;

    //prepare token response and save AT/RT
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:testAuthority
                                                                                  clientId:testClientId
                                                                                  response:testTokenResponse];
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:testAuthority.host
                                                                                      clientId:testClientId
                                                                                      response:testTokenResponse];
    [cache saveAccessAndRefreshToken:requestParam response:testTokenResponse error:nil];
    
    MSALAccessTokenCacheItem *atItem2 = [[MSALAccessTokenCacheItem alloc] initWithAuthority:testAuthority
                                                                                  clientId:testClientId
                                                                                  response:testTokenResponse2];
    MSALRefreshTokenCacheItem *rtItem2 = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:testAuthority.host
                                                                                       clientId:testClientId
                                                                                       response:testTokenResponse2];
    [cache saveAccessAndRefreshToken:requestParam2 response:testTokenResponse2 error:nil];
    
    //there should be two ATs in cache
    XCTAssertEqual([dataSource getAccessTokenItemsWithKey:nil correlationId:nil error:nil].count, 2);
    
    //there should be two RTs in cache
    XCTAssertEqual([dataSource getRefreshTokenItemsWithKey:nil correlationId:nil error:nil].count, 2);
    
    //retrieve AT
    MSALAccessTokenCacheItem *atItemInCache = [cache findAccessToken:requestParam error:nil];
    
    //compare AT with the AT retrieved from cache
    XCTAssertEqualObjects([atItem tokenCacheKey:nil].service, [atItemInCache tokenCacheKey:nil].service);
    XCTAssertEqualObjects([atItem tokenCacheKey:nil].account, [atItemInCache tokenCacheKey:nil].account);
    
    //retrieve RT
    MSALRefreshTokenCacheItem *rtItemInCache = [cache findRefreshToken:requestParam error:nil];
    
    //compare RT with the RT retrieved from cache
    XCTAssertEqualObjects([rtItem tokenCacheKey:nil].service, [rtItemInCache tokenCacheKey:nil].service);
    XCTAssertEqualObjects([rtItem tokenCacheKey:nil].account, [rtItemInCache tokenCacheKey:nil].account);
    
    //delete tokens for a user
    XCTAssertTrue([cache deleteAllTokensForUser:testUser clientId:testClientId error:nil]);

    //deleted RT and AT, both should return nil
    XCTAssertNil([cache findAccessToken:requestParam error:nil]);
    XCTAssertNil([cache findRefreshToken:requestParam error:nil]);
    
    //there should be one AT and one RT left in cache
    XCTAssertEqual([dataSource getAccessTokenItemsWithKey:nil correlationId:nil error:nil].count, 1);
    XCTAssertEqual([dataSource getRefreshTokenItemsWithKey:nil correlationId:nil error:nil].count, 1);
    
    //retrieve AT 2 and compare it with the AT retrieved from cache
    MSALAccessTokenCacheItem *atItemInCache2 = [cache findAccessToken:requestParam2 error:nil];
    
    XCTAssertEqualObjects([atItem2 tokenCacheKey:nil].service, [atItemInCache2 tokenCacheKey:nil].service);
    XCTAssertEqualObjects([atItem2 tokenCacheKey:nil].account, [atItemInCache2 tokenCacheKey:nil].account);

    //retrieve RT 2 and compare it with the RT retrieved from cache
    MSALRefreshTokenCacheItem *rtItemInCache2 = [cache findRefreshToken:requestParam2 error:nil];
    
    XCTAssertEqualObjects([rtItem2 tokenCacheKey:nil].service, [rtItemInCache2 tokenCacheKey:nil].service);
    XCTAssertEqualObjects([rtItem2 tokenCacheKey:nil].account, [rtItemInCache2 tokenCacheKey:nil].account);
}

- (void)testGetUsers {
    //prepare request parameters
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = testAuthority;
    requestParam.clientId = testClientId;
    [requestParam setScopesFromArray:@[@"mail.read", @"User.Read"]];
    requestParam.user = testUser;
    
    MSALRequestParameters *requestParam2 = [MSALRequestParameters new];
    requestParam2.unvalidatedAuthority = testAuthority;
    requestParam2.clientId = testClientId;
    [requestParam2 setScopesFromArray:@[@"User.Read"]];
    requestParam2.user = testUser2;
    
    //save AT/RT
    [cache saveAccessAndRefreshToken:requestParam response:testTokenResponse error:nil];
    [cache saveAccessAndRefreshToken:requestParam2 response:testTokenResponse2 error:nil];
    
    //get all users using client id (sorted by unique id for easy comparison later)
    NSArray<MSALUser *> *users = [cache getUsers:requestParam.clientId];
    users = [users sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *uniqueIdA = [(MSALUser *)a userIdentifier];
        NSString *uniqueIdB = [(MSALUser *)b userIdentifier];
        return [uniqueIdA compare:uniqueIdB];
    }];
    
    XCTAssertTrue(users.count==2);
    XCTAssertEqualObjects(users[0].displayableId, @"user@msdevex.onmicrosoft.com");
    XCTAssertEqualObjects(users[0].name, @"Simple User");
    XCTAssertEqualObjects(users[0].identityProvider, @"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031/v2.0");
    XCTAssertEqualObjects(users[0].uid, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(users[0].utid, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
    XCTAssertEqualObjects(users[0].environment, @"login.microsoftonline.com");
    
    XCTAssertEqualObjects(users[1].displayableId, @"user2@msdevex.onmicrosoft.com");
    XCTAssertEqualObjects(users[1].name, @"Simple User 2");
    XCTAssertEqualObjects(users[1].identityProvider, @"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031/v2.0");
    XCTAssertEqualObjects(users[1].uid, @"7fbfa524-82aa-4e3a-9fb2-dfb4b30af36d");
    XCTAssertEqualObjects(users[1].utid, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
    XCTAssertEqualObjects(users[1].environment, @"login.microsoftonline.com");
    
    //get all users using nil client id (sorted by unique id for easy comparison later)
    users = [[cache getUsers:nil] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *uniqueIdA = [(MSALUser *)a userIdentifier];
        NSString *uniqueIdB = [(MSALUser *)b userIdentifier];
        return [uniqueIdA compare:uniqueIdB];
    }];
    
    XCTAssertTrue(users.count==2);
    XCTAssertEqualObjects(users[0].displayableId, @"user@msdevex.onmicrosoft.com");
    XCTAssertEqualObjects(users[0].name, @"Simple User");
    XCTAssertEqualObjects(users[0].identityProvider, @"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031/v2.0");
    XCTAssertEqualObjects(users[0].uid, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(users[0].utid, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
    XCTAssertEqualObjects(users[0].environment, @"login.microsoftonline.com");
    
    XCTAssertEqualObjects(users[1].displayableId, @"user2@msdevex.onmicrosoft.com");
    XCTAssertEqualObjects(users[1].name, @"Simple User 2");
    XCTAssertEqualObjects(users[1].identityProvider, @"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031/v2.0");
    XCTAssertEqualObjects(users[1].uid, @"7fbfa524-82aa-4e3a-9fb2-dfb4b30af36d");
    XCTAssertEqualObjects(users[1].utid, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
    XCTAssertEqualObjects(users[1].environment, @"login.microsoftonline.com");

    users = [cache getUsers:@"fake-client-id"];
    XCTAssertTrue(users.count==0);
}

@end
