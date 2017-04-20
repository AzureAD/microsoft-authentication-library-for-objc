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
#import "MSALTokenResponse.h"
#import "MSALAccessTokenCacheItem.h"
#import "MSALRefreshTokenCacheItem.h"
#import "MSALAccessTokenCacheKey.h"
#import "MSALRefreshTokenCacheKey.h"
#import "MSALUSer.h"
#import "MSALClientInfo.h"
#import "NSURL+MSALExtensions.h"

@interface MSALTokenCacheItemTests : XCTestCase

@end

@implementation MSALTokenCacheItemTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testAccessTokenProperties {
    NSString *base64String = @"eyJ0b2tlbl90eXBlIjoiQmVhcmVyIiwic2NvcGUiOiJtYWlsLnJlYWQgdXNlci5yZWFkIiwiZXhwaXJlc19pbiI6MzU5OSwiZXh0X2V4cGlyZXNfaW4iOjI2MjgwMCwiYWNjZXNzX3Rva2VuIjoiZmFrZS1hY2Nlc3MtdG9rZW4iLCJyZWZyZXNoX3Rva2VuIjoiZmFrZS1yZWZyZXNoLXRva2VuIiwiaWRfdG9rZW4iOiJleUowZVhBaU9pSktWMVFpTENKaGJHY2lPaUpTVXpJMU5pSXNJbXRwWkNJNkltRXpVVTR3UWxwVE4zTTBiazR0UW1SeWFtSkdNRmxmVEdSTlRTSjkuZXlKaGRXUWlPaUkxWVRRek5EWTVNUzFqWTJJeUxUUm1aREV0WWprM1lpMWlOalJpWTJaaVl6QXpabU1pTENKcGMzTWlPaUpvZEhSd2N6b3ZMMnh2WjJsdUxtMXBZM0p2YzI5bWRHOXViR2x1WlM1amIyMHZNREk0TjJZNU5qTXRNbVEzTWkwME16WXpMVGxsTTJFdE5UY3dOV00xWWpCbU1ETXhMM1l5TGpBaUxDSnBZWFFpT2pFME9URTBPVEU1TWpjc0ltNWlaaUk2TVRRNU1UUTVNVGt5Tnl3aVpYaHdJam94TkRreE5EazFPREkzTENKaGFXOGlPaUpaTWxwbldVaENNR0pZYmxFclNFbGFkekZ5Um1GNVl6ZEdlR2dyWkZwNWRrdHRSM1U1T0dJNWQyeExURXd6UmxOelVrbEJJaXdpYm1GdFpTSTZJbE5wYlhCc1pTQlZjMlZ5SWl3aWIybGtJam9pTWpsbU16Z3dOMkV0TkdaaU1DMDBNbVl5TFdFME5HRXRNak0yWVdFd1kySXpaamszSWl3aWNISmxabVZ5Y21Wa1gzVnpaWEp1WVcxbElqb2lkWE5sY2tCdGMyUmxkbVY0TG05dWJXbGpjbTl6YjJaMExtTnZiU0lzSW5OMVlpSTZJbFJ4WjFSNmVsZGlWakUyYlVsclNVVXdjM2h6VWtkUlJtNXlUMWxzUVdWUFdWSjRhMlI1UW1oRVJtOGlMQ0owYVdRaU9pSXdNamczWmprMk15MHlaRGN5TFRRek5qTXRPV1V6WVMwMU56QTFZelZpTUdZd016RWlMQ0oyWlhJaU9pSXlMakFpZlEuWjBZZnl3OWNOZTlXbTN3OUNHYXVza21BdTR6aXVqY0xfY1hIbWtPWTVYRGJRQUFPWmlkSWxEbVVDMGROWTUxdU50d3Z0Rm5pVzBIbGZ4TUROR2IzZXNCWE83eXd3eWwtVG9WTUhiNjROOGJHdk5uMUlteGRtOFhUREdHcC1oT2hYMUFYakRNSTdmOWdzMUt2SlJVSmt4R3B3MFBrckhZNnNvbk83MVgyUVBNbS02UUVuSGtNTDRLRDB3c0ZMb0I4dWhsVkdramo3QlNwZDZIRUNqWXJ3T0hvTkRjaGZTWE9CcktyYzJXREpndzBJOWNmWU12aks4MmgwbnlGdEZ2Q3V1WExXT1ZiUHZWdUF5R01DOHRrQzFLZEVkLU9vUGhvaER3ODNrMlAzR2IyTlRjSFZqN2Y3SHJRWENVTml5QWJZZVNraWpHdWc4bXFaVEp2Z2ZaVWNBIiwiY2xpZW50X2luZm8iOiJleUoxYVdRaU9pSXlPV1l6T0RBM1lTMDBabUl3TFRReVpqSXRZVFEwWVMweU16WmhZVEJqWWpObU9UY2lMQ0oxZEdsa0lqb2lNREk0TjJZNU5qTXRNbVEzTWkwME16WXpMVGxsTTJFdE5UY3dOV00xWWpCbU1ETXhJbjAifQ==";
    
    NSData* responseData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
    MSALTokenResponse *response = [[MSALTokenResponse alloc] initWithData:responseData error:nil];
    
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                                                  clientId:@"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc"
                                                                                  response:response];
    
    XCTAssertEqualObjects(atItem.tokenType, @"Bearer");
    XCTAssertEqualObjects(atItem.accessToken, @"fake-access-token");
    XCTAssertTrue([atItem.expiresOn compare:NSDate.date] == NSOrderedDescending);
    XCTAssertEqualObjects(atItem.scope.msalToString, @"mail.read user.read");
    XCTAssertFalse(atItem.isExpired);
    
    XCTAssertEqualObjects([atItem tokenCacheKey:nil].service, @"aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tLzAyODdmOTYzLTJkNzItNDM2My05ZTNhLTU3MDVjNWIwZjAzMQ$NWE0MzQ2OTEtY2NiMi00ZmQxLWI5N2ItYjY0YmNmYmMwM2Zj$bWFpbC5yZWFkIHVzZXIucmVhZA");
    XCTAssertEqualObjects([atItem tokenCacheKey:nil].account, @"1297315377$MjlmMzgwN2EtNGZiMC00MmYyLWE0NGEtMjM2YWEwY2IzZjk3LjAyODdmOTYzLTJkNzItNDM2My05ZTNhLTU3MDVjNWIwZjAzMQ@bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ");
    XCTAssertEqualObjects(atItem.authority, @"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031");
    XCTAssertEqualObjects(atItem.clientId, @"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc");
    XCTAssertEqualObjects(atItem.tenantId, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
    XCTAssertEqualObjects(atItem.rawIdToken, @"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6ImEzUU4wQlpTN3M0bk4tQmRyamJGMFlfTGRNTSJ9.eyJhdWQiOiI1YTQzNDY5MS1jY2IyLTRmZDEtYjk3Yi1iNjRiY2ZiYzAzZmMiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vMDI4N2Y5NjMtMmQ3Mi00MzYzLTllM2EtNTcwNWM1YjBmMDMxL3YyLjAiLCJpYXQiOjE0OTE0OTE5MjcsIm5iZiI6MTQ5MTQ5MTkyNywiZXhwIjoxNDkxNDk1ODI3LCJhaW8iOiJZMlpnWUhCMGJYblErSEladzFyRmF5YzdGeGgrZFp5dkttR3U5OGI5d2xLTEwzRlNzUklBIiwibmFtZSI6IlNpbXBsZSBVc2VyIiwib2lkIjoiMjlmMzgwN2EtNGZiMC00MmYyLWE0NGEtMjM2YWEwY2IzZjk3IiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlckBtc2RldmV4Lm9ubWljcm9zb2Z0LmNvbSIsInN1YiI6IlRxZ1R6eldiVjE2bUlrSUUwc3hzUkdRRm5yT1lsQWVPWVJ4a2R5QmhERm8iLCJ0aWQiOiIwMjg3Zjk2My0yZDcyLTQzNjMtOWUzYS01NzA1YzViMGYwMzEiLCJ2ZXIiOiIyLjAifQ.Z0Yfyw9cNe9Wm3w9CGauskmAu4ziujcL_cXHmkOY5XDbQAAOZidIlDmUC0dNY51uNtwvtFniW0HlfxMDNGb3esBXO7ywwyl-ToVMHb64N8bGvNn1Imxdm8XTDGGp-hOhX1AXjDMI7f9gs1KvJRUJkxGpw0PkrHY6sonO71X2QPMm-6QEnHkML4KD0wsFLoB8uhlVGkjj7BSpd6HECjYrwOHoNDchfSXOBrKrc2WDJgw0I9cfYMvjK82h0nyFtFvCuuXLWOVbPvVuAyGMC8tkC1KdEd-OoPhohDw83k2P3Gb2NTcHVj7f7HrQXCUNiyAbYeSkijGug8mqZTJvgfZUcA");
    XCTAssertEqualObjects(atItem.user.userIdentifier, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97.0287f963-2d72-4363-9e3a-5705c5b0f031");
    XCTAssertEqualObjects(atItem.user.displayableId, @"user@msdevex.onmicrosoft.com");
    XCTAssertEqualObjects(atItem.user.name, @"Simple User");
    XCTAssertEqualObjects(atItem.user.identityProvider, @"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031/v2.0");
    XCTAssertEqualObjects(atItem.user.uid, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(atItem.user.utid, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
    XCTAssertEqualObjects(atItem.user.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(atItem.clientInfo.uid, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(atItem.clientInfo.utid, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
}

- (void)testBadAccessTokenInit {
    MSALTokenResponse *badResponse = [MSALTokenResponse new];
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                                                  clientId:@"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc"
                                                                                  response:badResponse];
    XCTAssertNil(atItem);
}

- (void)testRefreshTokenProperties {
    NSString *base64String = @"eyJ0b2tlbl90eXBlIjoiQmVhcmVyIiwic2NvcGUiOiJtYWlsLnJlYWQgdXNlci5yZWFkIiwiZXhwaXJlc19pbiI6MzU5OSwiZXh0X2V4cGlyZXNfaW4iOjI2MjgwMCwiYWNjZXNzX3Rva2VuIjoiZmFrZS1hY2Nlc3MtdG9rZW4iLCJyZWZyZXNoX3Rva2VuIjoiZmFrZS1yZWZyZXNoLXRva2VuIiwiaWRfdG9rZW4iOiJleUowZVhBaU9pSktWMVFpTENKaGJHY2lPaUpTVXpJMU5pSXNJbXRwWkNJNkltRXpVVTR3UWxwVE4zTTBiazR0UW1SeWFtSkdNRmxmVEdSTlRTSjkuZXlKaGRXUWlPaUkxWVRRek5EWTVNUzFqWTJJeUxUUm1aREV0WWprM1lpMWlOalJpWTJaaVl6QXpabU1pTENKcGMzTWlPaUpvZEhSd2N6b3ZMMnh2WjJsdUxtMXBZM0p2YzI5bWRHOXViR2x1WlM1amIyMHZNREk0TjJZNU5qTXRNbVEzTWkwME16WXpMVGxsTTJFdE5UY3dOV00xWWpCbU1ETXhMM1l5TGpBaUxDSnBZWFFpT2pFME9URTBPVEU1TWpjc0ltNWlaaUk2TVRRNU1UUTVNVGt5Tnl3aVpYaHdJam94TkRreE5EazFPREkzTENKaGFXOGlPaUpaTWxwbldVaENNR0pZYmxFclNFbGFkekZ5Um1GNVl6ZEdlR2dyWkZwNWRrdHRSM1U1T0dJNWQyeExURXd6UmxOelVrbEJJaXdpYm1GdFpTSTZJbE5wYlhCc1pTQlZjMlZ5SWl3aWIybGtJam9pTWpsbU16Z3dOMkV0TkdaaU1DMDBNbVl5TFdFME5HRXRNak0yWVdFd1kySXpaamszSWl3aWNISmxabVZ5Y21Wa1gzVnpaWEp1WVcxbElqb2lkWE5sY2tCdGMyUmxkbVY0TG05dWJXbGpjbTl6YjJaMExtTnZiU0lzSW5OMVlpSTZJbFJ4WjFSNmVsZGlWakUyYlVsclNVVXdjM2h6VWtkUlJtNXlUMWxzUVdWUFdWSjRhMlI1UW1oRVJtOGlMQ0owYVdRaU9pSXdNamczWmprMk15MHlaRGN5TFRRek5qTXRPV1V6WVMwMU56QTFZelZpTUdZd016RWlMQ0oyWlhJaU9pSXlMakFpZlEuWjBZZnl3OWNOZTlXbTN3OUNHYXVza21BdTR6aXVqY0xfY1hIbWtPWTVYRGJRQUFPWmlkSWxEbVVDMGROWTUxdU50d3Z0Rm5pVzBIbGZ4TUROR2IzZXNCWE83eXd3eWwtVG9WTUhiNjROOGJHdk5uMUlteGRtOFhUREdHcC1oT2hYMUFYakRNSTdmOWdzMUt2SlJVSmt4R3B3MFBrckhZNnNvbk83MVgyUVBNbS02UUVuSGtNTDRLRDB3c0ZMb0I4dWhsVkdramo3QlNwZDZIRUNqWXJ3T0hvTkRjaGZTWE9CcktyYzJXREpndzBJOWNmWU12aks4MmgwbnlGdEZ2Q3V1WExXT1ZiUHZWdUF5R01DOHRrQzFLZEVkLU9vUGhvaER3ODNrMlAzR2IyTlRjSFZqN2Y3SHJRWENVTml5QWJZZVNraWpHdWc4bXFaVEp2Z2ZaVWNBIiwiY2xpZW50X2luZm8iOiJleUoxYVdRaU9pSXlPV1l6T0RBM1lTMDBabUl3TFRReVpqSXRZVFEwWVMweU16WmhZVEJqWWpObU9UY2lMQ0oxZEdsa0lqb2lNREk0TjJZNU5qTXRNbVEzTWkwME16WXpMVGxsTTJFdE5UY3dOV00xWWpCbU1ETXhJbjAifQ==";
    
    NSData* responseData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
    MSALTokenResponse *response = [[MSALTokenResponse alloc] initWithData:responseData error:nil];
    
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:@"login.microsoftonline.com"
                                                                                      clientId:@"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc"
                                                                                      response:response];
    
    XCTAssertEqualObjects(rtItem.refreshToken, @"fake-refresh-token");
    XCTAssertEqualObjects([rtItem tokenCacheKey:nil].service, @"NWE0MzQ2OTEtY2NiMi00ZmQxLWI5N2ItYjY0YmNmYmMwM2Zj");
    XCTAssertEqualObjects([rtItem tokenCacheKey:nil].account, @"1297315377$MjlmMzgwN2EtNGZiMC00MmYyLWE0NGEtMjM2YWEwY2IzZjk3LjAyODdmOTYzLTJkNzItNDM2My05ZTNhLTU3MDVjNWIwZjAzMQ@bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ");
    XCTAssertEqualObjects(rtItem.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(rtItem.clientId, @"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc");
    XCTAssertEqualObjects(rtItem.identityProvider, @"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031/v2.0");
    XCTAssertEqualObjects(rtItem.clientInfo.uid, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(rtItem.clientInfo.utid, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
    XCTAssertEqualObjects(rtItem.displayableId, @"user@msdevex.onmicrosoft.com");
    XCTAssertEqualObjects(rtItem.name, @"Simple User");
    XCTAssertEqualObjects(rtItem.user.displayableId, @"user@msdevex.onmicrosoft.com");
    XCTAssertEqualObjects(rtItem.user.name, @"Simple User");
    XCTAssertEqualObjects(rtItem.user.identityProvider, @"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031/v2.0");
    XCTAssertEqualObjects(rtItem.user.uid, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(rtItem.user.utid, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
    XCTAssertEqualObjects(rtItem.user.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(rtItem.user.userIdentifier, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97.0287f963-2d72-4363-9e3a-5705c5b0f031");
}

- (void)testBadRefreshTokenInit {
    MSALTokenResponse *badResponse = [MSALTokenResponse new];
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:@"login.microsoftonline.com"                                                                                    clientId:@"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc"
                                                                                      response:badResponse];
    XCTAssertNil(rtItem);
}

- (void)testBaseItemUser
{
    MSALBaseTokenCacheItem *item = [[MSALBaseTokenCacheItem alloc] initWithClientId:nil
                                                                           response:nil];
    
    XCTAssertThrows([item user]);
}

- (void)testTokenCacheKeyBaseService
{
    MSALTokenCacheKeyBase *keyBase = [MSALTokenCacheKeyBase new];
    XCTAssertThrows(keyBase.service);
}

- (void)testTokenCacheKeyBaseAccount
{
    MSALTokenCacheKeyBase *keyBase = [MSALTokenCacheKeyBase new];
    XCTAssertThrows(keyBase.account);
}

- (void)testRefreshTokenCacheKeyMatch
{
    NSURL *testAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    MSALRefreshTokenCacheKey *keyA = [[MSALRefreshTokenCacheKey alloc] initWithEnvironment:testAuthority.msalHostWithPort
                                                                                  clientId:@"123-456"
                                                                            userIdentifier:nil];
    MSALRefreshTokenCacheKey *keyB = [[MSALRefreshTokenCacheKey alloc] initWithEnvironment:testAuthority.msalHostWithPort
                                                                                  clientId:@"123-456"
                                                                            userIdentifier:@"abcde"];
    XCTAssertTrue([keyA matches:keyB]);
}

- (void)testRefreshTokenCacheKeyAccount
{
    NSURL *testAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    MSALRefreshTokenCacheKey *keyA = [[MSALRefreshTokenCacheKey alloc] initWithEnvironment:testAuthority.msalHostWithPort
                                                                                  clientId:@"123-456"
                                                                            userIdentifier:nil];
    XCTAssertNil(keyA.account);
}

@end
