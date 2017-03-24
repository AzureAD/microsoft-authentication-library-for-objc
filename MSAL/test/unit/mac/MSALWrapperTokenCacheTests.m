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

typedef enum
{
    kNothingCalled,
    kWillCalled,
    kDidCalled,
} TestDelegateState;

@interface ADTestSimpleStorage : NSObject <MSALTokenCacheDelegate>
{
@public
    NSData* _cache;
    
    TestDelegateState access;
    TestDelegateState write;
}

@end

@implementation ADTestSimpleStorage

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    //load cache from where it is persisted
    //here we simply set it empty
    _cache = nil;
    
    return self;
}

- (void)willAccessCache:(nonnull MSALWrapperTokenCache *)cache
{
    [cache deserialize:_cache error:nil];
    
    switch (access)
    {
        case kNothingCalled: access = kWillCalled; break;
        case kWillCalled: NSAssert(0, @"willAccessCache called multiple times without calling didAccessCache!"); break;
        case kDidCalled: access = kWillCalled; break;
    }
}

- (void)didAccessCache:(nonnull MSALWrapperTokenCache *)cache
{
    (void)cache;
    
    switch (access)
    {
        case kNothingCalled: NSAssert(0, @"willAccessCache must be called before didAccessCache"); break;
        case kWillCalled: access = kDidCalled; break;
        case kDidCalled: NSAssert(0, @"didAccessCache callled multuple times!"); break;
    }
}

- (void)willWriteCache:(nonnull MSALWrapperTokenCache *)cache
{
    [cache deserialize:_cache error:nil];
    
    switch (write)
    {
        case kNothingCalled: write = kWillCalled; break;
        case kWillCalled: NSAssert(0, @"willAccessCache called multiple times without calling didAccessCache!"); break;
        case kDidCalled: write = kWillCalled; break;
    }
}

- (void)didWriteCache:(nonnull MSALWrapperTokenCache *)cache
{
    _cache = [cache serialize];
    
    switch (write)
    {
        case kNothingCalled: NSAssert(0, @"willAccessCache must be called before didAccessCache"); break;
        case kWillCalled: write = kDidCalled; break;
        case kDidCalled: NSAssert(0, @"didAccessCache callled multuple times!"); break;
    }
    
}

@end

@interface MSALWrapperTokenCacheTests : XCTestCase
{
    MSALTokenCacheAccessor *cache;
    MSALWrapperTokenCache *dataSource;
    MSALTokenResponse *testTokenResponse;
    MSALTokenResponse *testTokenResponse2;
    MSALIdToken *testIdToken;
    MSALIdToken *testIdToken2;
    MSALUser *testUser;
    MSALUser *testUser2;
    NSURL *testAuthority;
    NSString *testClientId;
}

@end

@implementation MSALWrapperTokenCacheTests

- (void)setUp {
    [super setUp];
    
    dataSource = MSALWrapperTokenCache.defaultCache;
    ADTestSimpleStorage* storage = [[ADTestSimpleStorage alloc] init];
    [dataSource setDelegate:storage];
    cache = [[MSALTokenCacheAccessor alloc] initWithDataSource:dataSource];
    
    testAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    testClientId = @"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc";
    
    NSString *responseBase64String = @"eyJ0b2tlbl90eXBlIjoiQmVhcmVyIiwic2NvcGUiOiJtYWlsLnJlYWQgdXNlci5yZWFkIiwiZXhwaXJlc19pbiI6MzU5OSwiZXh0X2V4cGlyZXNfaW4iOjEwODAwLCJhY2Nlc3NfdG9rZW4iOiJleUowZVhBaU9pSktWMVFpTENKdWIyNWpaU0k2SWtGUlFVSkJRVUZCUVVGRVVrNVpVbEV6WkdoU1UzSnRMVFJMTFdGa2NFTktUWEppUlhaWlEwaGlZMUJxUWs4d1psaGxiV3RTYkZOc1lqSnZaRE5SUmtkb2QzVlBXRWd5VUc1NVpHbHpkRE5xTFZScGJscHZTMGxxUWpadGIxQm9kM3BWTFdJd04yTXpSRXhOWlROSGFuVnZURko1VEdsQlFTSXNJbUZzWnlJNklsSlRNalUySWl3aWVEVjBJam9pWDFWbmNWaEhYM1JOVEdSMVUwb3hWRGhqWVVoNFZUZGpUM1JqSWl3aWEybGtJam9pWDFWbmNWaEhYM1JOVEdSMVUwb3hWRGhqWVVoNFZUZGpUM1JqSW4wLmV5SmhkV1FpT2lKb2RIUndjem92TDJkeVlYQm9MbTFwWTNKdmMyOW1kQzVqYjIwaUxDSnBjM01pT2lKb2RIUndjem92TDNOMGN5NTNhVzVrYjNkekxtNWxkQzh3TWpnM1pqazJNeTB5WkRjeUxUUXpOak10T1dVellTMDFOekExWXpWaU1HWXdNekV2SWl3aWFXRjBJam94TkRnNE1qWTBNVGt4TENKdVltWWlPakUwT0RneU5qUXhPVEVzSW1WNGNDSTZNVFE0T0RJMk9EQTVNU3dpWVdOeUlqb2lNU0lzSW1GdGNpSTZXeUp3ZDJRaVhTd2lZWEJ3WDJScGMzQnNZWGx1WVcxbElqb2lUbUYwYVhabFFYQndJaXdpWVhCd2FXUWlPaUkxWVRRek5EWTVNUzFqWTJJeUxUUm1aREV0WWprM1lpMWlOalJpWTJaaVl6QXpabU1pTENKaGNIQnBaR0ZqY2lJNklqQWlMQ0psWDJWNGNDSTZNVEE0TURBc0ltWmhiV2xzZVY5dVlXMWxJam9pVlhObGNpSXNJbWRwZG1WdVgyNWhiV1VpT2lKVGFXMXdiR1VpTENKcGNHRmtaSElpT2lJeE56UXVOaTQ0T1M0eU1UY2lMQ0p1WVcxbElqb2lVMmx0Y0d4bElGVnpaWElpTENKdmFXUWlPaUl5T1dZek9EQTNZUzAwWm1Jd0xUUXlaakl0WVRRMFlTMHlNelpoWVRCallqTm1PVGNpTENKd2JHRjBaaUk2SWpJaUxDSndkV2xrSWpvaU1UQXdNemRHUmtVNU5EVTRNamM1UXlJc0luTmpjQ0k2SWsxaGFXd3VVbVZoWkNCVmMyVnlMbEpsWVdRaUxDSnpkV0lpT2lKWlVEQktORkExU2xrdGVXcFdSM0ZoWkdwUmRtYzVNM0F6WWpoMmIxQnhWREJaWjBoSVZYSnFhbEJ6SWl3aWRHbGtJam9pTURJNE4yWTVOak10TW1RM01pMDBNell6TFRsbE0yRXROVGN3TldNMVlqQm1NRE14SWl3aWRXNXBjWFZsWDI1aGJXVWlPaUoxYzJWeVFHMXpaR1YyWlhndWIyNXRhV055YjNOdlpuUXVZMjl0SWl3aWRYQnVJam9pZFhObGNrQnRjMlJsZG1WNExtOXViV2xqY205emIyWjBMbU52YlNJc0luWmxjaUk2SWpFdU1DSjkuQ19rQ2VOdkxGR1B0N1FpcFJrTTlOUm9PRkZOUlhZOFN2THJQcXJaUDItTzFoeXpuTmZyc2gyTjExNjAwUXg2TnhMLS1Bc0o2NUZMSFVDZ0pHZ1hBSVFVSENwc290VkYxcTVWS0ZVd05zQ2g4U0RzYlN2SkxCUGdaaXhMdHNzTWtwLW1wcEFoTDJLX05BTEIySWJMWkdPQ003SkRtN3ROMC1jbVBTcE1lNWNVa0V5ZUlDcHVrQVRuVlkyd1BYc2NvUi1pWjB2MmxHekxLUVllV1dObnVGeWdybUFhb3hCcExLOGlPX2p2Y05qeEFDMWtqaHA0QVlxVGRpRTI5WnRvbVN6TDZ6ZmZCWXFVd0g4Z013bnZZMTRFQUoyb3drU1YwalA4YWV4di01YW5nclB0VmstME5IdHRZUXpuU010WUZmQTVlQ1ItYTZObjZPR2VURFEtWi1RIiwicmVmcmVzaF90b2tlbiI6Ik9BUUFCQUFBQUFBRFJOWVJRM2RoUlNybS00Sy1hZHBDSlQ1N0hXaGZMVXJEd2dweW8yRjc0UE54UjRBSGdXZTB0VW10RFV1US1wUEtuM1o2UGRCVHhrdlg0c0NSekQ2R0YxZVYtVEdCZE5XQ0xndW1BUnl2VGNBcDFCSDE5RUI0X3NlZkI4eEhHeHlMSUYtOG9PaEw5MWh0akJsWkFFZkdLUU94OU5mNExHWWZuYUYyMnBJR3dkZV93ckhPXzNsSnE5TGhoVnhIZnJOWVFFSmdJdjlGS01qdlB5WkpYNnFkTlE3aDl6d2Nndko1a3Yzb3BGc0M4bHhSNk9YX2wxYTYwOWQ2MzViUHNKY0JBYzNNOFdfVDllXzhrbzBUTVItclVvbFBGTjhzNURtSnRXMHFFbGpGa0xkWkluZjlOV2ViZ3hucy1sT0VXUTZsdFd3dUNLRk5GTFJGdFZYaWtNeHljQnVGLWIwVkxKck1hUUxVdjZQWGJpMnBjcnljbjlrek1ZM00tSkdRVUZwcHhmYjdiR2FlZmduXzE4M3pRdlBZdzlwRTA1aEg4eXEtQl9wUlJnX1VMTWRxRFZJd2dndjhMUFZ1VzJBWmJnQkl4M0tSektEaVVOV0phZ2Vya3dHYnZoMWx0eTNCSnFmYWhCYmlCRzVoYWJNQ2Npem5OTFI3X3NUTGxDUzNnaHZocmdQWGprTHp5X1RwSTJCajZGc3ZUODUwZHJmUmJkZGhfQll0YVA2SkU5ZVplY2Q5QnhJcnRPb296VUtOVGs5RUZDRjVEUDdZdkllVWxIalNYbk9Xa1pHZExGU3UxdmxVSDRYZHV3Q1MzXzI1dTd4RG1Mcks0bG9BMEFJUExlcENpOGVBN1pDQnFVemtZUHNQWE40X1NFYzFCUlZYWlNETXJNZU9XUEdsVXFiTkhyUmN4WEVsUUwyMFRYM040X3BFaFo1eHpDdjZPczRaX3Y0dmo3TjlkSUFBIiwiaWRfdG9rZW4iOiJleUowZVhBaU9pSktWMVFpTENKaGJHY2lPaUpTVXpJMU5pSXNJbXRwWkNJNklsOVZaM0ZZUjE5MFRVeGtkVk5LTVZRNFkyRkllRlUzWTA5MFl5SjkuZXlKaGRXUWlPaUkxWVRRek5EWTVNUzFqWTJJeUxUUm1aREV0WWprM1lpMWlOalJpWTJaaVl6QXpabU1pTENKcGMzTWlPaUpvZEhSd2N6b3ZMMnh2WjJsdUxtMXBZM0p2YzI5bWRHOXViR2x1WlM1amIyMHZNREk0TjJZNU5qTXRNbVEzTWkwME16WXpMVGxsTTJFdE5UY3dOV00xWWpCbU1ETXhMM1l5TGpBaUxDSnBZWFFpT2pFME9EZ3lOalF4T1RFc0ltNWlaaUk2TVRRNE9ESTJOREU1TVN3aVpYaHdJam94TkRnNE1qWTRNRGt4TENKdVlXMWxJam9pVTJsdGNHeGxJRlZ6WlhJaUxDSnZhV1FpT2lJeU9XWXpPREEzWVMwMFptSXdMVFF5WmpJdFlUUTBZUzB5TXpaaFlUQmpZak5tT1RjaUxDSndjbVZtWlhKeVpXUmZkWE5sY201aGJXVWlPaUoxYzJWeVFHMXpaR1YyWlhndWIyNXRhV055YjNOdlpuUXVZMjl0SWl3aWMzVmlJam9pVkhGblZIcDZWMkpXTVRadFNXdEpSVEJ6ZUhOU1IxRkdibkpQV1d4QlpVOVpVbmhyWkhsQ2FFUkdieUlzSW5ScFpDSTZJakF5T0RkbU9UWXpMVEprTnpJdE5ETTJNeTA1WlROaExUVTNNRFZqTldJd1pqQXpNU0lzSW5abGNpSTZJakl1TUNKOS5oeV9jOHRacWtzV210dDFuZ1Fsdl8zVDR6aXcyejhkc3RWc2RPQjA5TTVZaVhZU0dDZTZqTWRkcjY2Z0NFN0xncjZVRGRhRzZlWUZaSVF2SGFwaVVMSVo4Vi1nMC04WmEwS0t0SXprR3NMMFEybWhXRkVETl9PSUZNcE8welU4SzVXQVJzQ3g0SlgxY3BucWVValdxZ1hNVHV0d0lPeUdrWXZLUDBMbXlnMURKNHpnclpyZE1VanIwZ3J1SzRIaDB4QUM2bUpnNXVzbEgteEpUN1ZpV1ItUXVtRm9OU3VGWEgyanhKblB4OVlzeXhpVnB0a0plQTZlTFNRWXJqNVJaY3BGbklldHFnREt1R3JQd0xHaXFoa18tUGdldS1Sc0lkQzQ2dUN0VXlBVElzZWhrT015X0JsbXJnMUw3OU5GSWhGMUVpenktZ25ZY241ZV9LMG1jdHcifQ==";
    NSData* responseData = [[NSData alloc] initWithBase64EncodedString:responseBase64String options:0];
    testTokenResponse = [[MSALTokenResponse alloc] initWithData:responseData error:nil];
    
    testIdToken = [[MSALIdToken alloc] initWithRawIdToken:@"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Il9VZ3FYR190TUxkdVNKMVQ4Y2FIeFU3Y090YyJ9.eyJhdWQiOiI1YTQzNDY5MS1jY2IyLTRmZDEtYjk3Yi1iNjRiY2ZiYzAzZmMiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vMDI4N2Y5NjMtMmQ3Mi00MzYzLTllM2EtNTcwNWM1YjBmMDMxL3YyLjAiLCJpYXQiOjE0ODgyNjQxOTEsIm5iZiI6MTQ4ODI2NDE5MSwiZXhwIjoxNDg4MjY4MDkxLCJuYW1lIjoiU2ltcGxlIFVzZXIiLCJvaWQiOiIyOWYzODA3YS00ZmIwLTQyZjItYTQ0YS0yMzZhYTBjYjNmOTciLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJ1c2VyQG1zZGV2ZXgub25taWNyb3NvZnQuY29tIiwic3ViIjoiVHFnVHp6V2JWMTZtSWtJRTBzeHNSR1FGbnJPWWxBZU9ZUnhrZHlCaERGbyIsInRpZCI6IjAyODdmOTYzLTJkNzItNDM2My05ZTNhLTU3MDVjNWIwZjAzMSIsInZlciI6IjIuMCJ9.hy_c8tZqksWmtt1ngQlv_3T4ziw2z8dstVsdOB09M5YiXYSGCe6jMddr66gCE7Lgr6UDdaG6eYFZIQvHapiULIZ8V-g0-8Za0KKtIzkGsL0Q2mhWFEDN_OIFMpO0zU8K5WARsCx4JX1cpnqeUjWqgXMTutwIOyGkYvKP0Lmyg1DJ4zgrZrdMUjr0gruK4Hh0xAC6mJg5uslH-xJT7ViWR-QumFoNSuFXH2jxJnPx9YsyxiVptkJeA6eLSQYrj5RZcpFnIetqgDKuGrPwLGiqhk_-Pgeu-RsIdC46uCtUyATIsehkOMy_Blmrg1L79NFIhF1Eizy-gnYcn5e_K0mctw"];
    
    testUser = [[MSALUser alloc] initWithIdToken:testIdToken
                                       authority:testAuthority
                                        clientId:testClientId];
    
    NSString *responseBase64String2 = @"eyJ0b2tlbl90eXBlIjoiQmVhcmVyIiwic2NvcGUiOiJ1c2VyLnJlYWQiLCJleHBpcmVzX2luIjozNTk5LCJleHRfZXhwaXJlc19pbiI6MTA4MDAsImFjY2Vzc190b2tlbiI6ImV5SjBlWEFpT2lKS1YxUWlMQ0p1YjI1alpTSTZJa0ZSUVVKQlFVRkJRVUZFVWs1WlVsRXpaR2hTVTNKdExUUkxMV0ZrY0VOS2NraEpaekpwWmtkU01VZHhaVTlpTkU1ak4yTmlaVVZhYURKV1JtTjFNbDl0VVdaNFQzbDNiMmt3TFdONVJIUTNNMUZWVjBsQ1dFZzFVVzAwYkZOTGEwZHdaRTFxV2s1WWNHcGFXREpEVjBremFrdGFTbE5CUVNJc0ltRnNaeUk2SWxKVE1qVTJJaXdpZURWMElqb2lZVE5SVGpCQ1dsTTNjelJ1VGkxQ1pISnFZa1l3V1Y5TVpFMU5JaXdpYTJsa0lqb2lZVE5SVGpCQ1dsTTNjelJ1VGkxQ1pISnFZa1l3V1Y5TVpFMU5JbjAuZXlKaGRXUWlPaUpvZEhSd2N6b3ZMMmR5WVhCb0xtMXBZM0p2YzI5bWRDNWpiMjBpTENKcGMzTWlPaUpvZEhSd2N6b3ZMM04wY3k1M2FXNWtiM2R6TG01bGRDOHdNamczWmprMk15MHlaRGN5TFRRek5qTXRPV1V6WVMwMU56QTFZelZpTUdZd016RXZJaXdpYVdGMElqb3hORGc1TmpFNE1EWTFMQ0p1WW1ZaU9qRTBPRGsyTVRnd05qVXNJbVY0Y0NJNk1UUTRPVFl5TVRrMk5Td2lZV055SWpvaU1TSXNJbUZwYnlJNklrRlRVVUV5THpoRFFVRkJRVlZoTldsNVIxSk1MM1pFTDBwalNXODJRemxZY0hkNVFpdDVkbTAyVGpaRVowUldLMjAyWWs4eVYyTTlJaXdpWVcxeUlqcGJJbkIzWkNKZExDSmhjSEJmWkdsemNHeGhlVzVoYldVaU9pSk9ZWFJwZG1WQmNIQWlMQ0poY0hCcFpDSTZJalZoTkRNME5qa3hMV05qWWpJdE5HWmtNUzFpT1RkaUxXSTJOR0pqWm1Kak1ETm1ZeUlzSW1Gd2NHbGtZV055SWpvaU1DSXNJbVZmWlhod0lqb3hNRGd3TUN3aVptRnRhV3g1WDI1aGJXVWlPaUoxYzJWeUlpd2laMmwyWlc1ZmJtRnRaU0k2SW5OcGJYQnNaU0lzSW1sd1lXUmtjaUk2SWpFMk55NHlNakF1TWpRdU56QWlMQ0p1WVcxbElqb2lVMmx0Y0d4bElGVnpaWElnTWlJc0ltOXBaQ0k2SWpkbVltWmhOVEkwTFRneVlXRXROR1V6WVMwNVptSXlMV1JtWWpSaU16Qmhaak0yWkNJc0luQnNZWFJtSWpvaU1pSXNJbkIxYVdRaU9pSXhNREF6TTBaR1JqbENPREkzTVVSRElpd2ljMk53SWpvaVZYTmxjaTVTWldGa0lpd2ljM1ZpSWpvaVQxWnpRWFl6UkhBMFUzUkNTMlpTTUU1TkxVZHVOMFZuZDBSQlMyTTFVME5tWld4cFEzaG5ZazVWWnlJc0luUnBaQ0k2SWpBeU9EZG1PVFl6TFRKa056SXRORE0yTXkwNVpUTmhMVFUzTURWak5XSXdaakF6TVNJc0luVnVhWEYxWlY5dVlXMWxJam9pZFhObGNqSkFiWE5rWlhabGVDNXZibTFwWTNKdmMyOW1kQzVqYjIwaUxDSjFjRzRpT2lKMWMyVnlNa0J0YzJSbGRtVjRMbTl1YldsamNtOXpiMlowTG1OdmJTSXNJblpsY2lJNklqRXVNQ0o5LkVzdnF3VTJQaFNqVDNtNnlwdG9BWl9JQ2RQTWloaDFGOG1NakRQUzRpS0xSNWREVmFGSXZlYjFSekZkLU9neHVrbko3Z0J6T1hZeDg2NmNzXzRoMkgyNHdjemVKSFZZQU9wanlIRTVYMGVvOHB4STdOekppY21RcjF4SzFWMFlnaUs1aVBDeEZsNVdpNFI4SGpINzhGcENQbVpVLWhCbEkyeS1aZjB2dnpyYlJVRjNTYUM1NUowVmdMY3B3VFM1MnVyRVpTdVYzU2RfeDVpS1NNSzZES2M0azVNak51YVdzbzBOOXpnbDhnbUpGMHNjbTJSUU0wMXVBZFYwcnVuNUVwUUN5dG1OakwyRWFVWFZjX01ZX05oVjR3UHByYVlIRHJueElmVTdpUnlBV1VKdHpjNWNMWlRyVmdtWWk3N044dlFhdGFQdktMcTV6dUQ0RVpmVFA1QSIsInJlZnJlc2hfdG9rZW4iOiJPQVFBQkFBQUFBQURSTllSUTNkaFJTcm0tNEstYWRwQ0o0bFBjWlRLVFlINVFIMUlLb0FKR1VxVUZLaWtWNFRBajdFTjlGbWhNekdrNTJUYjlnelJzc3loUDV4NWVEV1FSd2hwdE5wOHF3OGFRdzVvYjFITTBSYklMUzBCcm5GUWxZTEZjZWQ3T19RZWFIU2dPdVR4R3ZyTnhxN0R6ZEs2S051YnZ0WWNQb1d6M1cydjdfYVkzYjhnaVVMeEpvcXRVVzROeEZtYVYzUUpfSVNaSVNYd19qVzlVVnFGUW1pS0xCZ1VLX2piUU8wZFhacWZMRE9MelpnX1ZpZzhYRF96UzdrX0RmYmwwaTZLeXFBQ0dWck5ZZnBwWG03VXc0OGVVLXVVazh6dmJYQjNCRXJQQ0lkSXE3N2RDVWx2UTJ3blV1dTFqcFlYTHRmMjl3UVM4UENjVWN5T21taWFtVVJGTkRyWUJpM1B1cWctdW9VRElqQ1BmOTV6M0g1d3o1S01PVld3RUNuSzNqZmZOUEowWk1NY3FMRHI4eEYzTVluSFN5elhPVWFoUlZndUNocUM1Sk8taXpLLXlUQWtDZENCY0dSMFJGekdLM3BBeEdIRjRZamhDbUdIUEwzX2QzYURNbjNRcUdrSW1lVjBWUFhaa0RORHZ1aFJaeHJYQlM3MWE2UVgtMTdCV0lSSEhaeXFuS0Y1MGtkZE9scDBfeTcxT1lmd1k2b1RPbEhjTUtuUDVBZHRSOG5sb1ZCZUlHenNfcnYzTlVMUEZraXZCUEZlSHJYTnJaNHpXdm52MGhjY2JhNDc1NVNXdFgzSEpzWk5OOEQ5ejZoYS1SM2RjTXh6Y3ZVaWotN3oySUEwcjZjeTZmYmRvWHpfSTFRdWdBalVzcTFmdWJLYXlIdjQwN1JrWHQtUGNVTjF3aHdZWHZlUjlqZ2NJbU5iZlVleU9MamxoOElZZFlDaTdRQ2dfR2tRX3VvWVFvQks1MFVmV0QtWVVnMkw2V29PNUlkeU9lMEh3M0J1NnZpUC12RFJTMU43VHFaQzIyTmNwUG9MODRlekJJQUEiLCJpZF90b2tlbiI6ImV5SjBlWEFpT2lKS1YxUWlMQ0poYkdjaU9pSlNVekkxTmlJc0ltdHBaQ0k2SW1FelVVNHdRbHBUTjNNMGJrNHRRbVJ5YW1KR01GbGZUR1JOVFNKOS5leUpoZFdRaU9pSTFZVFF6TkRZNU1TMWpZMkl5TFRSbVpERXRZamszWWkxaU5qUmlZMlppWXpBelptTWlMQ0pwYzNNaU9pSm9kSFJ3Y3pvdkwyeHZaMmx1TG0xcFkzSnZjMjltZEc5dWJHbHVaUzVqYjIwdk1ESTROMlk1TmpNdE1tUTNNaTAwTXpZekxUbGxNMkV0TlRjd05XTTFZakJtTURNeEwzWXlMakFpTENKcFlYUWlPakUwT0RrMk1UZ3dOalVzSW01aVppSTZNVFE0T1RZeE9EQTJOU3dpWlhod0lqb3hORGc1TmpJeE9UWTFMQ0p1WVcxbElqb2lVMmx0Y0d4bElGVnpaWElnTWlJc0ltOXBaQ0k2SWpkbVltWmhOVEkwTFRneVlXRXROR1V6WVMwNVptSXlMV1JtWWpSaU16Qmhaak0yWkNJc0luQnlaV1psY25KbFpGOTFjMlZ5Ym1GdFpTSTZJblZ6WlhJeVFHMXpaR1YyWlhndWIyNXRhV055YjNOdlpuUXVZMjl0SWl3aWMzVmlJam9pUTJwcWRqTlNlSFZzTTNkRGVGOTNiM2xsYUc4eVFWcDFWbTB5TjFKc2RWRlNhM3BTV0hrek4xRnFXU0lzSW5ScFpDSTZJakF5T0RkbU9UWXpMVEprTnpJdE5ETTJNeTA1WlROaExUVTNNRFZqTldJd1pqQXpNU0lzSW5abGNpSTZJakl1TUNKOS5GbVZsY1QtOTA2cnhIVncwWVRkVE55ZWRFOGs5N1B3ZWxzd2lhNDdlVWV2Z3JsdjNBWE10U0E5eGRrdWdtN2pJZ1ZpZVlDZU9Ud3dFUjgwOGxSRjYxdFMwZTJEb29hZ0t5WjRlQ2pyb3Y3Ym1tbTEycWFPU0tuT1VvX1VPcVBfdEhhYU1KVDVYdTM5SWNrcDh4aEV0M0V0dEJPVXJzQUUxeVpFZDc2Q3B5TF9MZm4wSmN2cm9CZTc0VUlkVW5yalpweU8xNExaVzc5c0x2dGllVUVCbU51UEExTHhSc1luR0JOWWVOYnVDa193MFU5NXdvRDZ1d0JNMzJJRmNJRU5Ub0VCY0YzUVRrcnFMMW9fVW5ZZ0ZEdjJaOEdBMnVwQXo0N1dSWjAtSS1DZ01ZNmNTVnB2dVZPYVR6Q0R1VnV4RWZJTWJHOUJha0hjQ1h4NURiVW5YencifQ==";
    
    NSData* responseData2 = [[NSData alloc] initWithBase64EncodedString:responseBase64String2 options:0];
    testTokenResponse2 = [[MSALTokenResponse alloc] initWithData:responseData2 error:nil];
    
    testIdToken2 = [[MSALIdToken alloc] initWithRawIdToken:@"eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6ImEzUU4wQlpTN3M0bk4tQmRyamJGMFlfTGRNTSJ9.eyJhdWQiOiI1YTQzNDY5MS1jY2IyLTRmZDEtYjk3Yi1iNjRiY2ZiYzAzZmMiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vMDI4N2Y5NjMtMmQ3Mi00MzYzLTllM2EtNTcwNWM1YjBmMDMxL3YyLjAiLCJpYXQiOjE0ODk2MTgwNjUsIm5iZiI6MTQ4OTYxODA2NSwiZXhwIjoxNDg5NjIxOTY1LCJuYW1lIjoiU2ltcGxlIFVzZXIgMiIsIm9pZCI6IjdmYmZhNTI0LTgyYWEtNGUzYS05ZmIyLWRmYjRiMzBhZjM2ZCIsInByZWZlcnJlZF91c2VybmFtZSI6InVzZXIyQG1zZGV2ZXgub25taWNyb3NvZnQuY29tIiwic3ViIjoiQ2pqdjNSeHVsM3dDeF93b3llaG8yQVp1Vm0yN1JsdVFSa3pSWHkzN1FqWSIsInRpZCI6IjAyODdmOTYzLTJkNzItNDM2My05ZTNhLTU3MDVjNWIwZjAzMSIsInZlciI6IjIuMCJ9.FmVlcT-906rxHVw0YTdTNyedE8k97Pwelswia47eUevgrlv3AXMtSA9xdkugm7jIgVieYCeOTwwER808lRF61tS0e2DooagKyZ4eCjrov7bmmm12qaOSKnOUo_UOqP_tHaaMJT5Xu39Ickp8xhEt3EttBOUrsAE1yZEd76CpyL_Lfn0JcvroBe74UIdUnrjZpyO14LZW79sLvtieUEBmNuPA1LxRsYnGBNYeNbuCk_w0U95woD6uwBM32IFcIENToEBcF3QTkrqL1o_UnYgFDv2Z8GA2upAz47WRZ0-I-CgMY6cSVpvuVOaTzCDuVuxEfIMbG9BakHcCXx5DbUnXzw"];
    
    testUser2 = [[MSALUser alloc] initWithIdToken:testIdToken2
                                        authority:testAuthority
                                         clientId:testClientId];
}

- (void)tearDown {
    
    [(MSALWrapperTokenCache *)cache.dataSource testRemoveAll];
    cache = nil;
    
    [super tearDown];
}

- (void)testSaveAndRetrieveAccessToken {
    
    //prepare request parameters
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = testAuthority;
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
    XCTAssertEqualObjects([atItem tokenCacheKey:nil].service, [atItemInCache tokenCacheKey:nil].service);
    XCTAssertEqualObjects([atItem tokenCacheKey:nil].account, [atItemInCache tokenCacheKey:nil].account);
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
    XCTAssertEqualObjects(atItem2.tokenType, atItemInCache2.tokenType);
    XCTAssertEqualObjects(atItem2.expiresOn.description, atItemInCache2.expiresOn.description);
    XCTAssertEqualObjects(atItem2.scope.msalToString, atItemInCache2.scope.msalToString);
    XCTAssertTrue(atItem2.isExpired==atItemInCache2.isExpired);
    XCTAssertEqualObjects([atItem2 tokenCacheKey:nil].service, [atItemInCache2 tokenCacheKey:nil].service);
    XCTAssertEqualObjects([atItem2 tokenCacheKey:nil].account, [atItemInCache2 tokenCacheKey:nil].account);
    XCTAssertEqualObjects(atItem2.authority, atItemInCache2.authority);
    XCTAssertEqualObjects(atItem2.clientId, atItemInCache2.clientId);
    XCTAssertEqualObjects(atItem2.tenantId, atItemInCache2.tenantId);
    XCTAssertEqualObjects(atItem2.rawIdToken, atItemInCache2.rawIdToken);
    XCTAssertEqualObjects(atItem2.uniqueId, atItemInCache2.uniqueId);
    XCTAssertEqualObjects(atItem2.displayableId, atItemInCache2.displayableId);
    XCTAssertEqualObjects(atItem2.homeObjectId, atItemInCache2.homeObjectId);
    XCTAssertEqualObjects(atItem2.user.uniqueId, atItemInCache2.user.uniqueId);
    XCTAssertEqualObjects(atItem2.user.displayableId, atItemInCache2.user.displayableId);
    XCTAssertEqualObjects(atItem2.user.name, atItemInCache2.user.name);
    XCTAssertEqualObjects(atItem2.user.identityProvider, atItemInCache2.user.identityProvider);
    XCTAssertEqualObjects(atItem2.user.clientId, atItemInCache2.user.clientId);
    XCTAssertEqualObjects(atItem2.user.authority, atItemInCache2.user.authority);
    XCTAssertEqualObjects(atItem2.user.homeObjectId, atItemInCache2.user.homeObjectId);
}

- (void)testSaveAndRetrieveRefreshToken {
    
    //prepare request parameters
    MSALRequestParameters *requestParam = [MSALRequestParameters new];
    requestParam.unvalidatedAuthority = testAuthority;
    requestParam.clientId = testClientId;
    [requestParam setScopesFromArray:@[@"User.Read"]];
    requestParam.user = testUser;
    
    //prepare token response and save AT/RT
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithAuthority:nil
                                                                                    clientId:testClientId
                                                                                    response:testTokenResponse];
    [cache saveAccessAndRefreshToken:requestParam response:testTokenResponse error:nil];
    
    //retrieve RT
    MSALRefreshTokenCacheItem *rtItemInCache = [cache findRefreshToken:requestParam error:nil];
    
    //compare RT with the RT retrieved from cache
    XCTAssertEqualObjects([rtItem tokenCacheKey:nil].service, [rtItemInCache tokenCacheKey:nil].service);
    XCTAssertEqualObjects([rtItem tokenCacheKey:nil].account, [rtItemInCache tokenCacheKey:nil].account);
    XCTAssertEqualObjects(rtItem.authority, rtItemInCache.authority);
    XCTAssertEqualObjects(rtItem.clientId, rtItemInCache.clientId);
    XCTAssertEqualObjects(rtItem.tenantId, rtItemInCache.tenantId);
    XCTAssertEqualObjects(rtItem.rawIdToken, rtItemInCache.rawIdToken);
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
    
    MSALRefreshTokenCacheItem *rtItem2 = [[MSALRefreshTokenCacheItem alloc] initWithAuthority:nil
                                                                                     clientId:testClientId
                                                                                     response:testTokenResponse2];
    [cache saveAccessAndRefreshToken:requestParam2 response:testTokenResponse2 error:nil];
    
    //there should be two RTs in cache
    XCTAssertEqual([dataSource getRefreshTokenItemsWithKey:nil correlationId:nil error:nil].count, 2);
    
    //retrieve AT 2
    MSALRefreshTokenCacheItem *rtItemInCache2 = [cache findRefreshToken:requestParam2 error:nil];
    
    //compare RT 2 with the RT retrieved from cache
    XCTAssertEqualObjects([rtItem2 tokenCacheKey:nil].service, [rtItemInCache2 tokenCacheKey:nil].service);
    XCTAssertEqualObjects([rtItem2 tokenCacheKey:nil].account, [rtItemInCache2 tokenCacheKey:nil].account);
    XCTAssertEqualObjects(rtItem2.authority, rtItemInCache2.authority);
    XCTAssertEqualObjects(rtItem2.clientId, rtItemInCache2.clientId);
    XCTAssertEqualObjects(rtItem2.tenantId, rtItemInCache2.tenantId);
    XCTAssertEqualObjects(rtItem2.rawIdToken, rtItemInCache2.rawIdToken);
    XCTAssertEqualObjects(rtItem2.uniqueId, rtItemInCache2.uniqueId);
    XCTAssertEqualObjects(rtItem2.displayableId, rtItemInCache2.displayableId);
    XCTAssertEqualObjects(rtItem2.homeObjectId, rtItemInCache2.homeObjectId);
    XCTAssertEqualObjects(rtItem2.user.uniqueId, rtItemInCache2.user.uniqueId);
    XCTAssertEqualObjects(rtItem2.user.displayableId, rtItemInCache2.user.displayableId);
    XCTAssertEqualObjects(rtItem2.user.name, rtItemInCache2.user.name);
    XCTAssertEqualObjects(rtItem2.user.identityProvider, rtItemInCache2.user.identityProvider);
    XCTAssertEqualObjects(rtItem2.user.clientId, rtItemInCache2.user.clientId);
    XCTAssertEqualObjects(rtItem2.user.authority, rtItemInCache2.user.authority);
    XCTAssertEqualObjects(rtItem2.user.homeObjectId, rtItemInCache2.user.homeObjectId);
}

- (void)testDeleteAccessToken {
    
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
    [cache saveAccessAndRefreshToken:requestParam response:testTokenResponse error:nil];
    
    MSALAccessTokenCacheItem *atItem2 = [[MSALAccessTokenCacheItem alloc] initWithAuthority:testAuthority
                                                                                   clientId:testClientId
                                                                                   response:testTokenResponse2];
    [cache saveAccessAndRefreshToken:requestParam2 response:testTokenResponse2 error:nil];
    
    //there should be two ATs in cache
    XCTAssertEqual([dataSource getAccessTokenItemsWithKey:nil correlationId:nil error:nil].count, 2);
    
    //retrieve AT
    MSALAccessTokenCacheItem *atItemInCache = [cache findAccessToken:requestParam error:nil];
    
    //compare AT with the AT retrieved from cache
    XCTAssertEqualObjects([atItem tokenCacheKey:nil].service, [atItemInCache tokenCacheKey:nil].service);
    XCTAssertEqualObjects([atItem tokenCacheKey:nil].account, [atItemInCache tokenCacheKey:nil].account);
    
    //delete AT
    [cache deleteAccessToken:atItemInCache error:nil];
    XCTAssertNil([cache findAccessToken:requestParam error:nil]);
    
    //there should be one AT left in cache
    XCTAssertEqual([dataSource getAccessTokenItemsWithKey:nil correlationId:nil error:nil].count, 1);
    
    //retrieve AT 2 and compare it with the AT retrieved from cache
    MSALAccessTokenCacheItem *atItemInCache2 = [cache findAccessToken:requestParam2 error:nil];
    
    XCTAssertEqualObjects([atItem2 tokenCacheKey:nil].service, [atItemInCache2 tokenCacheKey:nil].service);
    XCTAssertEqualObjects([atItem2 tokenCacheKey:nil].account, [atItemInCache2 tokenCacheKey:nil].account);
}

- (void)testDeleteRefreshToken {
    
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
    MSALRefreshTokenCacheItem *rtItem = [[MSALRefreshTokenCacheItem alloc] initWithAuthority:nil
                                                                                    clientId:testClientId
                                                                                    response:testTokenResponse];
    [cache saveAccessAndRefreshToken:requestParam response:testTokenResponse error:nil];
    
    MSALRefreshTokenCacheItem *rtItem2 = [[MSALRefreshTokenCacheItem alloc] initWithAuthority:nil
                                                                                     clientId:testClientId
                                                                                     response:testTokenResponse2];
    [cache saveAccessAndRefreshToken:requestParam2 response:testTokenResponse2 error:nil];
    
    //there should be two RTs in cache
    XCTAssertEqual([dataSource getRefreshTokenItemsWithKey:nil correlationId:nil error:nil].count, 2);
    
    //retrieve RT
    MSALRefreshTokenCacheItem *rtItemInCache = [cache findRefreshToken:requestParam error:nil];
    
    //compare RT with the RT retrieved from cache
    XCTAssertEqualObjects([rtItem tokenCacheKey:nil].service, [rtItemInCache tokenCacheKey:nil].service);
    XCTAssertEqualObjects([rtItem tokenCacheKey:nil].account, [rtItemInCache tokenCacheKey:nil].account);
    
    //delete RT
    [cache deleteRefreshToken:rtItemInCache error:nil];
    XCTAssertNil([cache findRefreshToken:requestParam error:nil]);
    
    //there should be one RT left in cache
    XCTAssertEqual([dataSource getRefreshTokenItemsWithKey:nil correlationId:nil error:nil].count, 1);
    
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
    
    //get all users using client id
    NSArray<MSALUser *> *users = [cache getUsers:requestParam.clientId];
    XCTAssertTrue(users.count==2);
    XCTAssertEqualObjects(users[0].uniqueId, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(users[0].displayableId, @"user@msdevex.onmicrosoft.com");
    XCTAssertEqualObjects(users[0].name, @"Simple User");
    XCTAssertEqualObjects(users[0].identityProvider, @"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031/v2.0");
    XCTAssertEqualObjects(users[0].clientId, @"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc");
    XCTAssertEqualObjects(users[0].authority, nil);
    XCTAssertEqualObjects(users[0].homeObjectId, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    
    XCTAssertEqualObjects(users[1].uniqueId, @"7fbfa524-82aa-4e3a-9fb2-dfb4b30af36d");
    XCTAssertEqualObjects(users[1].displayableId, @"user2@msdevex.onmicrosoft.com");
    XCTAssertEqualObjects(users[1].name, @"Simple User 2");
    XCTAssertEqualObjects(users[1].identityProvider, @"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031/v2.0");
    XCTAssertEqualObjects(users[1].clientId, @"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc");
    XCTAssertEqualObjects(users[1].authority, nil);
    XCTAssertEqualObjects(users[1].homeObjectId, @"7fbfa524-82aa-4e3a-9fb2-dfb4b30af36d");
    
    //get all users using nil client id
    users = [cache getUsers:nil];
    XCTAssertTrue(users.count==2);
    XCTAssertEqualObjects(users[0].uniqueId, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(users[0].displayableId, @"user@msdevex.onmicrosoft.com");
    XCTAssertEqualObjects(users[0].name, @"Simple User");
    XCTAssertEqualObjects(users[0].identityProvider, @"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031/v2.0");
    XCTAssertEqualObjects(users[0].clientId, @"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc");
    XCTAssertEqualObjects(users[0].authority, nil);
    XCTAssertEqualObjects(users[0].homeObjectId, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    
    XCTAssertEqualObjects(users[1].uniqueId, @"7fbfa524-82aa-4e3a-9fb2-dfb4b30af36d");
    XCTAssertEqualObjects(users[1].displayableId, @"user2@msdevex.onmicrosoft.com");
    XCTAssertEqualObjects(users[1].name, @"Simple User 2");
    XCTAssertEqualObjects(users[1].identityProvider, @"https://login.microsoftonline.com/0287f963-2d72-4363-9e3a-5705c5b0f031/v2.0");
    XCTAssertEqualObjects(users[1].clientId, @"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc");
    XCTAssertEqualObjects(users[1].authority, nil);
    XCTAssertEqualObjects(users[1].homeObjectId, @"7fbfa524-82aa-4e3a-9fb2-dfb4b30af36d");
    
    users = [cache getUsers:@"fake-client-id"];
    XCTAssertTrue(users.count==0);
}

@end
