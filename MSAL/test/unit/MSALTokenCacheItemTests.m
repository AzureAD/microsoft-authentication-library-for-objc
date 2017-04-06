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
    NSString *base64String = @"eyJ0b2tlbl90eXBlIjoiQmVhcmVyIiwic2NvcGUiOiJtYWlsLnJlYWQgdXNlci5yZWFkIiwiZXhwaXJlc19pbiI6MzU5OSwiZXh0X2V4cGlyZXNfaW4iOjI2MjgwMCwiYWNjZXNzX3Rva2VuIjoiZXlKMGVYQWlPaUpLVjFRaUxDSnViMjVqWlNJNklrRlJRVUpCUVVGQlFVRkNibVpwUnkxdFFUWk9WR0ZsTjBOa1YxYzNVV1prUjJGS1lXNVZVR0pmUlRZeVVrRTFRMnBxVlZoc2JrMVRURzVZTjJsR1dXbENUa281ZDJ0RGFqZE5hRXA2T1c1bFVFdzNlV3RLWmtGMFIwTkdVMmhxVG1Gc2NsRkpVVFZ6VEhSbU9UbHZWR1JGTTNKRWRIbEJRU0lzSW1Gc1p5STZJbEpUTWpVMklpd2llRFYwSWpvaVlUTlJUakJDV2xNM2N6UnVUaTFDWkhKcVlrWXdXVjlNWkUxTklpd2lhMmxrSWpvaVlUTlJUakJDV2xNM2N6UnVUaTFDWkhKcVlrWXdXVjlNWkUxTkluMC5leUpoZFdRaU9pSm9kSFJ3Y3pvdkwyZHlZWEJvTG0xcFkzSnZjMjltZEM1amIyMGlMQ0pwYzNNaU9pSm9kSFJ3Y3pvdkwzTjBjeTUzYVc1a2IzZHpMbTVsZEM4d01qZzNaamsyTXkweVpEY3lMVFF6TmpNdE9XVXpZUzAxTnpBMVl6VmlNR1l3TXpFdklpd2lhV0YwSWpveE5Ea3hORGt4T1RJM0xDSnVZbVlpT2pFME9URTBPVEU1TWpjc0ltVjRjQ0k2TVRRNU1UUTVOVGd5Tnl3aVlXTnlJam9pTVNJc0ltRnBieUk2SWtGVFVVRXlMemhFUVVGQlFXc3lVelJxWnpaS2RHTkRUR2RhTjBsbWEyUm1LMjlTVDNKVFZHcHdSM3BNTmxCcmRGZGhjakZNVG1jOUlpd2lZVzF5SWpwYkluQjNaQ0pkTENKaGNIQmZaR2x6Y0d4aGVXNWhiV1VpT2lKT1lYUnBkbVZCY0hBaUxDSmhjSEJwWkNJNklqVmhORE0wTmpreExXTmpZakl0Tkdaa01TMWlPVGRpTFdJMk5HSmpabUpqTURObVl5SXNJbUZ3Y0dsa1lXTnlJam9pTUNJc0ltVmZaWGh3SWpveU5qSTRNREFzSW1aaGJXbHNlVjl1WVcxbElqb2lWWE5sY2lJc0ltZHBkbVZ1WDI1aGJXVWlPaUpUYVcxd2JHVWlMQ0pwY0dGa1pISWlPaUl4TnpRdU5pNDRPUzR5TVRjaUxDSnVZVzFsSWpvaVUybHRjR3hsSUZWelpYSWlMQ0p2YVdRaU9pSXlPV1l6T0RBM1lTMDBabUl3TFRReVpqSXRZVFEwWVMweU16WmhZVEJqWWpObU9UY2lMQ0p3YkdGMFppSTZJaklpTENKd2RXbGtJam9pTVRBd016ZEdSa1U1TkRVNE1qYzVReUlzSW5OamNDSTZJazFoYVd3dVVtVmhaQ0JWYzJWeUxsSmxZV1FpTENKemRXSWlPaUpaVURCS05GQTFTbGt0ZVdwV1IzRmhaR3BSZG1jNU0zQXpZamgyYjFCeFZEQlpaMGhJVlhKcWFsQnpJaXdpZEdsa0lqb2lNREk0TjJZNU5qTXRNbVEzTWkwME16WXpMVGxsTTJFdE5UY3dOV00xWWpCbU1ETXhJaXdpZFc1cGNYVmxYMjVoYldVaU9pSjFjMlZ5UUcxelpHVjJaWGd1YjI1dGFXTnliM052Wm5RdVkyOXRJaXdpZFhCdUlqb2lkWE5sY2tCdGMyUmxkbVY0TG05dWJXbGpjbTl6YjJaMExtTnZiU0lzSW5abGNpSTZJakV1TUNKOS5OVkFRemFPcjhZaGVOMGJvSWlwdDlfZGUzOFBCTHRJdl9lWnlwd2pBNDRVekFSSWYycVhMVlpYcl9jN0RGcXN6TTNvUVAwOURKc3NrSHF5QTg2OXY5U01OVEYxcXR6X3pCYnNjZUJKdE1sQU5JN01HRGZwU1FoXzc0c0JsY3BNZGJSZkdJbHFqU3VLM0ZrbG4zZVF0RjgteE95Wl9jWHNOQjZmX29VTnNvY2lJT0o2YnEzMjE1MEtMR1djeUlTZnJBeGhCMkxpa3RFMFA1RU81UTd1X3puLVQtYU1rejBVcTQySE9WVFFaS25za0o0b1UySlhoS3FzTUtCWjlvYVVsZ29wZUQwWkFZRTkyNzhoek02RWZNNjc4TWF6RjNBaHR4Z08xSnpWc2o3VEUxSGhsbXl5MU9LMjVMWWJ6UFFQRV9FRmtlR0RGSHBGdUU2S1A0bDRMelEiLCJyZWZyZXNoX3Rva2VuIjoiT0FRQUJBQUFBQUFCbmZpRy1tQTZOVGFlN0NkV1c3UWZkQk1uVzRIaU5uZUEzWXd1Mnl4WjdaaE1DVWJ3RUFsRGlyNEpFU3pUQ0tEd3ZKbXk3dTFIR3JjWWxHM1pJTjFERklCeGJGTzJ0SzRBbnZwMkJ3c1dVVTU0eGJuRU52cE9BQi1uLXhKQXRINEdBel80Z3F5UmVIUUp6VjhQZTBvRVFOZUZTYzhlbVBDV2N6X2I2OVZKS2FwYWkyU0FtNDEwVkFSLXkyRFhUb2N0WS1SLUtleWRzWE5UVXRELXZkazVFbUJuRWNrNm9sYlBVZHZ5Z0Nxc2s4V2dMeGtJZXJUSG1pdTlaaGNSb0x6YVhENXNLNnhIcTRMSi05SUpfT1VuWUU1eXk2a1RlcnlEeWZiMEU5eGpTVDVEWjQ2TUhvX2lySUpLLXJ2bGhiZk10NVhib0lwcURoNmxJVUt4U3pmMDdOdVY5U0hSb2J1SlNrbnpNVEF5NWdWOUZ3MHpUaDM4SjI2bzB4dGtQbVRZd19vT3RoMGFJMzc0VGF5U2xOSXVCRkxWZnotSjZJclV1VjVLaHo3LUkzbGJ2OXlua25MdzIwWVhJZjh6ZFp2UFZTMUkwanc1NG9LY2ZzVnBPWUFJUDIyMW9UUDlfT0ljUFlkc3FvY3pDcWlncXR0RDhsRzdiSXNKUEtCSG5TMXg5VHl5U2JMM3MyZzUzMXFJYl8wRTM0OTg4bWlwQXhYOEtPcVE5RmUwX3lYTzF1Zy1pVnhwUmZ1LUZRTi1mcTZveDVOdjFnVllmcTA4ZkVRc2pmTUlZb29lRzY2Z2pJUERHdlQyV195alZMU3o0dWUwZW9mUUlNdUY5V3ByVEtfV0ZEcHhnelZKR1BKQnhzQWE0MjlpTzdXTlNyWjlkV1Ntc0ZqZUxCWGg2MHg3MXd0cG5mV2Y2ZUlEVzdxeHRsd2lneG9TTlRTVGh2Njh6TXhZbXlZUDlJTUtCT3R0TjdqRlJ1ZHRtR0ppM0RSREdwTjhTMDFwaDBfd3FCdXVpc20tQjYxalRkZ2tCaDF6UGhwZVJUczc3SUFBIiwiaWRfdG9rZW4iOiJleUowZVhBaU9pSktWMVFpTENKaGJHY2lPaUpTVXpJMU5pSXNJbXRwWkNJNkltRXpVVTR3UWxwVE4zTTBiazR0UW1SeWFtSkdNRmxmVEdSTlRTSjkuZXlKaGRXUWlPaUkxWVRRek5EWTVNUzFqWTJJeUxUUm1aREV0WWprM1lpMWlOalJpWTJaaVl6QXpabU1pTENKcGMzTWlPaUpvZEhSd2N6b3ZMMnh2WjJsdUxtMXBZM0p2YzI5bWRHOXViR2x1WlM1amIyMHZNREk0TjJZNU5qTXRNbVEzTWkwME16WXpMVGxsTTJFdE5UY3dOV00xWWpCbU1ETXhMM1l5TGpBaUxDSnBZWFFpT2pFME9URTBPVEU1TWpjc0ltNWlaaUk2TVRRNU1UUTVNVGt5Tnl3aVpYaHdJam94TkRreE5EazFPREkzTENKaGFXOGlPaUpaTWxwbldVaENNR0pZYmxFclNFbGFkekZ5Um1GNVl6ZEdlR2dyWkZwNWRrdHRSM1U1T0dJNWQyeExURXd6UmxOelVrbEJJaXdpYm1GdFpTSTZJbE5wYlhCc1pTQlZjMlZ5SWl3aWIybGtJam9pTWpsbU16Z3dOMkV0TkdaaU1DMDBNbVl5TFdFME5HRXRNak0yWVdFd1kySXpaamszSWl3aWNISmxabVZ5Y21Wa1gzVnpaWEp1WVcxbElqb2lkWE5sY2tCdGMyUmxkbVY0TG05dWJXbGpjbTl6YjJaMExtTnZiU0lzSW5OMVlpSTZJbFJ4WjFSNmVsZGlWakUyYlVsclNVVXdjM2h6VWtkUlJtNXlUMWxzUVdWUFdWSjRhMlI1UW1oRVJtOGlMQ0owYVdRaU9pSXdNamczWmprMk15MHlaRGN5TFRRek5qTXRPV1V6WVMwMU56QTFZelZpTUdZd016RWlMQ0oyWlhJaU9pSXlMakFpZlEuWjBZZnl3OWNOZTlXbTN3OUNHYXVza21BdTR6aXVqY0xfY1hIbWtPWTVYRGJRQUFPWmlkSWxEbVVDMGROWTUxdU50d3Z0Rm5pVzBIbGZ4TUROR2IzZXNCWE83eXd3eWwtVG9WTUhiNjROOGJHdk5uMUlteGRtOFhUREdHcC1oT2hYMUFYakRNSTdmOWdzMUt2SlJVSmt4R3B3MFBrckhZNnNvbk83MVgyUVBNbS02UUVuSGtNTDRLRDB3c0ZMb0I4dWhsVkdramo3QlNwZDZIRUNqWXJ3T0hvTkRjaGZTWE9CcktyYzJXREpndzBJOWNmWU12aks4MmgwbnlGdEZ2Q3V1WExXT1ZiUHZWdUF5R01DOHRrQzFLZEVkLU9vUGhvaER3ODNrMlAzR2IyTlRjSFZqN2Y3SHJRWENVTml5QWJZZVNraWpHdWc4bXFaVEp2Z2ZaVWNBIiwiY2xpZW50X2luZm8iOiJleUoxYVdRaU9pSXlPV1l6T0RBM1lTMDBabUl3TFRReVpqSXRZVFEwWVMweU16WmhZVEJqWWpObU9UY2lMQ0oxZEdsa0lqb2lNREk0TjJZNU5qTXRNbVEzTWkwME16WXpMVGxsTTJFdE5UY3dOV00xWWpCbU1ETXhJbjAifQ==";
    
    NSData* responseData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
    MSALTokenResponse *response = [[MSALTokenResponse alloc] initWithData:responseData error:nil];
    
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                                                  clientId:@"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc"
                                                                                  response:response];
    
    XCTAssertEqualObjects(atItem.tokenType, @"Bearer");
    XCTAssertEqualObjects(atItem.accessToken, @"eyJ0eXAiOiJKV1QiLCJub25jZSI6IkFRQUJBQUFBQUFCbmZpRy1tQTZOVGFlN0NkV1c3UWZkR2FKYW5VUGJfRTYyUkE1Q2pqVVhsbk1TTG5YN2lGWWlCTko5d2tDajdNaEp6OW5lUEw3eWtKZkF0R0NGU2hqTmFsclFJUTVzTHRmOTlvVGRFM3JEdHlBQSIsImFsZyI6IlJTMjU2IiwieDV0IjoiYTNRTjBCWlM3czRuTi1CZHJqYkYwWV9MZE1NIiwia2lkIjoiYTNRTjBCWlM3czRuTi1CZHJqYkYwWV9MZE1NIn0.eyJhdWQiOiJodHRwczovL2dyYXBoLm1pY3Jvc29mdC5jb20iLCJpc3MiOiJodHRwczovL3N0cy53aW5kb3dzLm5ldC8wMjg3Zjk2My0yZDcyLTQzNjMtOWUzYS01NzA1YzViMGYwMzEvIiwiaWF0IjoxNDkxNDkxOTI3LCJuYmYiOjE0OTE0OTE5MjcsImV4cCI6MTQ5MTQ5NTgyNywiYWNyIjoiMSIsImFpbyI6IkFTUUEyLzhEQUFBQWsyUzRqZzZKdGNDTGdaN0lma2RmK29ST3JTVGpwR3pMNlBrdFdhcjFMTmc9IiwiYW1yIjpbInB3ZCJdLCJhcHBfZGlzcGxheW5hbWUiOiJOYXRpdmVBcHAiLCJhcHBpZCI6IjVhNDM0NjkxLWNjYjItNGZkMS1iOTdiLWI2NGJjZmJjMDNmYyIsImFwcGlkYWNyIjoiMCIsImVfZXhwIjoyNjI4MDAsImZhbWlseV9uYW1lIjoiVXNlciIsImdpdmVuX25hbWUiOiJTaW1wbGUiLCJpcGFkZHIiOiIxNzQuNi44OS4yMTciLCJuYW1lIjoiU2ltcGxlIFVzZXIiLCJvaWQiOiIyOWYzODA3YS00ZmIwLTQyZjItYTQ0YS0yMzZhYTBjYjNmOTciLCJwbGF0ZiI6IjIiLCJwdWlkIjoiMTAwMzdGRkU5NDU4Mjc5QyIsInNjcCI6Ik1haWwuUmVhZCBVc2VyLlJlYWQiLCJzdWIiOiJZUDBKNFA1SlkteWpWR3FhZGpRdmc5M3AzYjh2b1BxVDBZZ0hIVXJqalBzIiwidGlkIjoiMDI4N2Y5NjMtMmQ3Mi00MzYzLTllM2EtNTcwNWM1YjBmMDMxIiwidW5pcXVlX25hbWUiOiJ1c2VyQG1zZGV2ZXgub25taWNyb3NvZnQuY29tIiwidXBuIjoidXNlckBtc2RldmV4Lm9ubWljcm9zb2Z0LmNvbSIsInZlciI6IjEuMCJ9.NVAQzaOr8YheN0boIipt9_de38PBLtIv_eZypwjA44UzARIf2qXLVZXr_c7DFqszM3oQP09DJsskHqyA869v9SMNTF1qtz_zBbsceBJtMlANI7MGDfpSQh_74sBlcpMdbRfGIlqjSuK3Fkln3eQtF8-xOyZ_cXsNB6f_oUNsociIOJ6bq32150KLGWcyISfrAxhB2LiktE0P5EO5Q7u_zn-T-aMkz0Uq42HOVTQZKnskJ4oU2JXhKqsMKBZ9oaUlgopeD0ZAYE9278hzM6EfM678MazF3AhtxgO1JzVsj7TE1Hhlmyy1OK25LYbzPQPE_EFkeGDFHpFuE6KP4l4LzQ");
    XCTAssertTrue([atItem.expiresOn compare:NSDate.date] == NSOrderedDescending);
    XCTAssertEqualObjects(atItem.scope.msalToString, @"mail.read user.read");
    XCTAssertTrue(atItem.isExpired);
    
    XCTAssertEqualObjects([atItem tokenCacheKey:nil].service, @"aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2NvbW1vbg$NWE0MzQ2OTEtY2NiMi00ZmQxLWI5N2ItYjY0YmNmYmMwM2Zj$bWFpbC5yZWFkIHVzZXIucmVhZA");
    XCTAssertEqualObjects([atItem tokenCacheKey:nil].account, @"0.0.1-dev$MjlmMzgwN2EtNGZiMC00MmYyLWE0NGEtMjM2YWEwY2IzZjk3LjAyODdmOTYzLTJkNzItNDM2My05ZTNhLTU3MDVjNWIwZjAzMQ@bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ");
    XCTAssertEqualObjects(atItem.authority, @"https://login.microsoftonline.com/common");
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
    XCTAssertEqualObjects(atItem.clientInfo.uniqueIdentifier, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(atItem.clientInfo.uniqueTenantIdentifier, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
}

- (void)testBadAccessTokenInit {
    MSALTokenResponse *badResponse = [MSALTokenResponse new];
    MSALAccessTokenCacheItem *atItem = [[MSALAccessTokenCacheItem alloc] initWithAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                                                  clientId:@"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc"
                                                                                  response:badResponse];
    XCTAssertNil(atItem);
}

- (void)testRefreshTokenProperties {
    NSString *base64String = @"eyJ0b2tlbl90eXBlIjoiQmVhcmVyIiwic2NvcGUiOiJtYWlsLnJlYWQgdXNlci5yZWFkIiwiZXhwaXJlc19pbiI6MzU5OSwiZXh0X2V4cGlyZXNfaW4iOjI2MjgwMCwiYWNjZXNzX3Rva2VuIjoiZXlKMGVYQWlPaUpLVjFRaUxDSnViMjVqWlNJNklrRlJRVUpCUVVGQlFVRkNibVpwUnkxdFFUWk9WR0ZsTjBOa1YxYzNVV1prUjJGS1lXNVZVR0pmUlRZeVVrRTFRMnBxVlZoc2JrMVRURzVZTjJsR1dXbENUa281ZDJ0RGFqZE5hRXA2T1c1bFVFdzNlV3RLWmtGMFIwTkdVMmhxVG1Gc2NsRkpVVFZ6VEhSbU9UbHZWR1JGTTNKRWRIbEJRU0lzSW1Gc1p5STZJbEpUTWpVMklpd2llRFYwSWpvaVlUTlJUakJDV2xNM2N6UnVUaTFDWkhKcVlrWXdXVjlNWkUxTklpd2lhMmxrSWpvaVlUTlJUakJDV2xNM2N6UnVUaTFDWkhKcVlrWXdXVjlNWkUxTkluMC5leUpoZFdRaU9pSm9kSFJ3Y3pvdkwyZHlZWEJvTG0xcFkzSnZjMjltZEM1amIyMGlMQ0pwYzNNaU9pSm9kSFJ3Y3pvdkwzTjBjeTUzYVc1a2IzZHpMbTVsZEM4d01qZzNaamsyTXkweVpEY3lMVFF6TmpNdE9XVXpZUzAxTnpBMVl6VmlNR1l3TXpFdklpd2lhV0YwSWpveE5Ea3hORGt4T1RJM0xDSnVZbVlpT2pFME9URTBPVEU1TWpjc0ltVjRjQ0k2TVRRNU1UUTVOVGd5Tnl3aVlXTnlJam9pTVNJc0ltRnBieUk2SWtGVFVVRXlMemhFUVVGQlFXc3lVelJxWnpaS2RHTkRUR2RhTjBsbWEyUm1LMjlTVDNKVFZHcHdSM3BNTmxCcmRGZGhjakZNVG1jOUlpd2lZVzF5SWpwYkluQjNaQ0pkTENKaGNIQmZaR2x6Y0d4aGVXNWhiV1VpT2lKT1lYUnBkbVZCY0hBaUxDSmhjSEJwWkNJNklqVmhORE0wTmpreExXTmpZakl0Tkdaa01TMWlPVGRpTFdJMk5HSmpabUpqTURObVl5SXNJbUZ3Y0dsa1lXTnlJam9pTUNJc0ltVmZaWGh3SWpveU5qSTRNREFzSW1aaGJXbHNlVjl1WVcxbElqb2lWWE5sY2lJc0ltZHBkbVZ1WDI1aGJXVWlPaUpUYVcxd2JHVWlMQ0pwY0dGa1pISWlPaUl4TnpRdU5pNDRPUzR5TVRjaUxDSnVZVzFsSWpvaVUybHRjR3hsSUZWelpYSWlMQ0p2YVdRaU9pSXlPV1l6T0RBM1lTMDBabUl3TFRReVpqSXRZVFEwWVMweU16WmhZVEJqWWpObU9UY2lMQ0p3YkdGMFppSTZJaklpTENKd2RXbGtJam9pTVRBd016ZEdSa1U1TkRVNE1qYzVReUlzSW5OamNDSTZJazFoYVd3dVVtVmhaQ0JWYzJWeUxsSmxZV1FpTENKemRXSWlPaUpaVURCS05GQTFTbGt0ZVdwV1IzRmhaR3BSZG1jNU0zQXpZamgyYjFCeFZEQlpaMGhJVlhKcWFsQnpJaXdpZEdsa0lqb2lNREk0TjJZNU5qTXRNbVEzTWkwME16WXpMVGxsTTJFdE5UY3dOV00xWWpCbU1ETXhJaXdpZFc1cGNYVmxYMjVoYldVaU9pSjFjMlZ5UUcxelpHVjJaWGd1YjI1dGFXTnliM052Wm5RdVkyOXRJaXdpZFhCdUlqb2lkWE5sY2tCdGMyUmxkbVY0TG05dWJXbGpjbTl6YjJaMExtTnZiU0lzSW5abGNpSTZJakV1TUNKOS5OVkFRemFPcjhZaGVOMGJvSWlwdDlfZGUzOFBCTHRJdl9lWnlwd2pBNDRVekFSSWYycVhMVlpYcl9jN0RGcXN6TTNvUVAwOURKc3NrSHF5QTg2OXY5U01OVEYxcXR6X3pCYnNjZUJKdE1sQU5JN01HRGZwU1FoXzc0c0JsY3BNZGJSZkdJbHFqU3VLM0ZrbG4zZVF0RjgteE95Wl9jWHNOQjZmX29VTnNvY2lJT0o2YnEzMjE1MEtMR1djeUlTZnJBeGhCMkxpa3RFMFA1RU81UTd1X3puLVQtYU1rejBVcTQySE9WVFFaS25za0o0b1UySlhoS3FzTUtCWjlvYVVsZ29wZUQwWkFZRTkyNzhoek02RWZNNjc4TWF6RjNBaHR4Z08xSnpWc2o3VEUxSGhsbXl5MU9LMjVMWWJ6UFFQRV9FRmtlR0RGSHBGdUU2S1A0bDRMelEiLCJyZWZyZXNoX3Rva2VuIjoiT0FRQUJBQUFBQUFCbmZpRy1tQTZOVGFlN0NkV1c3UWZkQk1uVzRIaU5uZUEzWXd1Mnl4WjdaaE1DVWJ3RUFsRGlyNEpFU3pUQ0tEd3ZKbXk3dTFIR3JjWWxHM1pJTjFERklCeGJGTzJ0SzRBbnZwMkJ3c1dVVTU0eGJuRU52cE9BQi1uLXhKQXRINEdBel80Z3F5UmVIUUp6VjhQZTBvRVFOZUZTYzhlbVBDV2N6X2I2OVZKS2FwYWkyU0FtNDEwVkFSLXkyRFhUb2N0WS1SLUtleWRzWE5UVXRELXZkazVFbUJuRWNrNm9sYlBVZHZ5Z0Nxc2s4V2dMeGtJZXJUSG1pdTlaaGNSb0x6YVhENXNLNnhIcTRMSi05SUpfT1VuWUU1eXk2a1RlcnlEeWZiMEU5eGpTVDVEWjQ2TUhvX2lySUpLLXJ2bGhiZk10NVhib0lwcURoNmxJVUt4U3pmMDdOdVY5U0hSb2J1SlNrbnpNVEF5NWdWOUZ3MHpUaDM4SjI2bzB4dGtQbVRZd19vT3RoMGFJMzc0VGF5U2xOSXVCRkxWZnotSjZJclV1VjVLaHo3LUkzbGJ2OXlua25MdzIwWVhJZjh6ZFp2UFZTMUkwanc1NG9LY2ZzVnBPWUFJUDIyMW9UUDlfT0ljUFlkc3FvY3pDcWlncXR0RDhsRzdiSXNKUEtCSG5TMXg5VHl5U2JMM3MyZzUzMXFJYl8wRTM0OTg4bWlwQXhYOEtPcVE5RmUwX3lYTzF1Zy1pVnhwUmZ1LUZRTi1mcTZveDVOdjFnVllmcTA4ZkVRc2pmTUlZb29lRzY2Z2pJUERHdlQyV195alZMU3o0dWUwZW9mUUlNdUY5V3ByVEtfV0ZEcHhnelZKR1BKQnhzQWE0MjlpTzdXTlNyWjlkV1Ntc0ZqZUxCWGg2MHg3MXd0cG5mV2Y2ZUlEVzdxeHRsd2lneG9TTlRTVGh2Njh6TXhZbXlZUDlJTUtCT3R0TjdqRlJ1ZHRtR0ppM0RSREdwTjhTMDFwaDBfd3FCdXVpc20tQjYxalRkZ2tCaDF6UGhwZVJUczc3SUFBIiwiaWRfdG9rZW4iOiJleUowZVhBaU9pSktWMVFpTENKaGJHY2lPaUpTVXpJMU5pSXNJbXRwWkNJNkltRXpVVTR3UWxwVE4zTTBiazR0UW1SeWFtSkdNRmxmVEdSTlRTSjkuZXlKaGRXUWlPaUkxWVRRek5EWTVNUzFqWTJJeUxUUm1aREV0WWprM1lpMWlOalJpWTJaaVl6QXpabU1pTENKcGMzTWlPaUpvZEhSd2N6b3ZMMnh2WjJsdUxtMXBZM0p2YzI5bWRHOXViR2x1WlM1amIyMHZNREk0TjJZNU5qTXRNbVEzTWkwME16WXpMVGxsTTJFdE5UY3dOV00xWWpCbU1ETXhMM1l5TGpBaUxDSnBZWFFpT2pFME9URTBPVEU1TWpjc0ltNWlaaUk2TVRRNU1UUTVNVGt5Tnl3aVpYaHdJam94TkRreE5EazFPREkzTENKaGFXOGlPaUpaTWxwbldVaENNR0pZYmxFclNFbGFkekZ5Um1GNVl6ZEdlR2dyWkZwNWRrdHRSM1U1T0dJNWQyeExURXd6UmxOelVrbEJJaXdpYm1GdFpTSTZJbE5wYlhCc1pTQlZjMlZ5SWl3aWIybGtJam9pTWpsbU16Z3dOMkV0TkdaaU1DMDBNbVl5TFdFME5HRXRNak0yWVdFd1kySXpaamszSWl3aWNISmxabVZ5Y21Wa1gzVnpaWEp1WVcxbElqb2lkWE5sY2tCdGMyUmxkbVY0TG05dWJXbGpjbTl6YjJaMExtTnZiU0lzSW5OMVlpSTZJbFJ4WjFSNmVsZGlWakUyYlVsclNVVXdjM2h6VWtkUlJtNXlUMWxzUVdWUFdWSjRhMlI1UW1oRVJtOGlMQ0owYVdRaU9pSXdNamczWmprMk15MHlaRGN5TFRRek5qTXRPV1V6WVMwMU56QTFZelZpTUdZd016RWlMQ0oyWlhJaU9pSXlMakFpZlEuWjBZZnl3OWNOZTlXbTN3OUNHYXVza21BdTR6aXVqY0xfY1hIbWtPWTVYRGJRQUFPWmlkSWxEbVVDMGROWTUxdU50d3Z0Rm5pVzBIbGZ4TUROR2IzZXNCWE83eXd3eWwtVG9WTUhiNjROOGJHdk5uMUlteGRtOFhUREdHcC1oT2hYMUFYakRNSTdmOWdzMUt2SlJVSmt4R3B3MFBrckhZNnNvbk83MVgyUVBNbS02UUVuSGtNTDRLRDB3c0ZMb0I4dWhsVkdramo3QlNwZDZIRUNqWXJ3T0hvTkRjaGZTWE9CcktyYzJXREpndzBJOWNmWU12aks4MmgwbnlGdEZ2Q3V1WExXT1ZiUHZWdUF5R01DOHRrQzFLZEVkLU9vUGhvaER3ODNrMlAzR2IyTlRjSFZqN2Y3SHJRWENVTml5QWJZZVNraWpHdWc4bXFaVEp2Z2ZaVWNBIiwiY2xpZW50X2luZm8iOiJleUoxYVdRaU9pSXlPV1l6T0RBM1lTMDBabUl3TFRReVpqSXRZVFEwWVMweU16WmhZVEJqWWpObU9UY2lMQ0oxZEdsa0lqb2lNREk0TjJZNU5qTXRNbVEzTWkwME16WXpMVGxsTTJFdE5UY3dOV00xWWpCbU1ETXhJbjAifQ==";
    
    NSData* responseData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
    MSALTokenResponse *response = [[MSALTokenResponse alloc] initWithData:responseData error:nil];
    
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:@"login.microsoftonline.com"
                                                                                      clientId:@"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc"
                                                                                      response:response];
    
    XCTAssertEqualObjects(rtItem.refreshToken, @"OAQABAAAAAABnfiG-mA6NTae7CdWW7QfdBMnW4HiNneA3Ywu2yxZ7ZhMCUbwEAlDir4JESzTCKDwvJmy7u1HGrcYlG3ZIN1DFIBxbFO2tK4Anvp2BwsWUU54xbnENvpOAB-n-xJAtH4GAz_4gqyReHQJzV8Pe0oEQNeFSc8emPCWcz_b69VJKapai2SAm410VAR-y2DXToctY-R-KeydsXNTUtD-vdk5EmBnEck6olbPUdvygCqsk8WgLxkIerTHmiu9ZhcRoLzaXD5sK6xHq4LJ-9IJ_OUnYE5yy6kTeryDyfb0E9xjST5DZ46MHo_irIJK-rvlhbfMt5XboIpqDh6lIUKxSzf07NuV9SHRobuJSknzMTAy5gV9Fw0zTh38J26o0xtkPmTYw_oOth0aI374TaySlNIuBFLVfz-J6IrUuV5Khz7-I3lbv9ynknLw20YXIf8zdZvPVS1I0jw54oKcfsVpOYAIP221oTP9_OIcPYdsqoczCqigqttD8lG7bIsJPKBHnS1x9TyySbL3s2g531qIb_0E34988mipAxX8KOqQ9Fe0_yXO1ug-iVxpRfu-FQN-fq6ox5Nv1gVYfq08fEQsjfMIYooeG66gjIPDGvT2W_yjVLSz4ue0eofQIMuF9WprTK_WFDpxgzVJGPJBxsAa429iO7WNSrZ9dWSmsFjeLBXh60x71wtpnfWf6eIDW7qxtlwigxoSNTSThv68zMxYmyYP9IMKBOttN7jFRudtmGJi3DRDGpN8S01ph0_wqBuuism-B61jTdgkBh1zPhpeRTs77IAA");
    XCTAssertEqualObjects([rtItem tokenCacheKey:nil].service, @"NWE0MzQ2OTEtY2NiMi00ZmQxLWI5N2ItYjY0YmNmYmMwM2Zj");
    XCTAssertEqualObjects([rtItem tokenCacheKey:nil].account, @"0.0.1-dev$MjlmMzgwN2EtNGZiMC00MmYyLWE0NGEtMjM2YWEwY2IzZjk3LjAyODdmOTYzLTJkNzItNDM2My05ZTNhLTU3MDVjNWIwZjAzMQ@bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ");
    XCTAssertEqualObjects(rtItem.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(rtItem.clientId, @"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc");
    XCTAssertEqualObjects(rtItem.identityProvider, @"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031/v2.0");
    XCTAssertEqualObjects(rtItem.clientInfo.uniqueIdentifier, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(rtItem.clientInfo.uniqueTenantIdentifier, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
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

@end
