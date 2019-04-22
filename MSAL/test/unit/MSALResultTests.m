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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSALTestCase.h"
#import "MSALResult+Internal.h"
#import "MSIDTokenResult.h"
#import "MSIDAccount.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAADV2IdTokenClaims.h"
#import "MSALTenantProfile.h"
#import "MSALAuthority.h"
#import "MSALAccount.h"
#import "MSALAccountId.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDTestCacheUtil.h"
#import "MSALAccount+Internal.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDAccessToken.h"
#if TARGET_OS_IPHONE
#import "MSIDKeychainTokenCache.h"
#else
#import "MSIDMacTokenCache.h"
#endif

@interface MSALResultTests : MSALTestCase

@end

@implementation MSALResultTests
{
    MSIDDefaultTokenCacheAccessor *defaultCache;
    MSIDLegacyTokenCacheAccessor *legacyCache;
}

- (void)setUp
{
    [super setUp];
    
    id<MSIDTokenCacheDataSource> dataSource = nil;
    
#if TARGET_OS_IPHONE
    dataSource = MSIDKeychainTokenCache.defaultKeychainCache;
#else
    dataSource = MSIDMacTokenCache.defaultCache;
#endif
    
    legacyCache = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:dataSource
                                                       otherCacheAccessors:@[]];
    defaultCache = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:@[legacyCache]];
    
    [defaultCache clearWithContext:nil error:nil];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testMSALResultWithTokenResult_whenTokenResultIsNil_shouldReturnError
{
    MSIDTokenResult *tokenResult = nil;
    
    NSError *error = nil;
    MSALResult *result = [MSALResult resultWithTokenResult:tokenResult tokenCache:nil error:&error];
    
    XCTAssertNil(result);
    XCTAssertEqualObjects(error.domain, @"MSIDErrorDomain");
    XCTAssertEqual(error.code, -51100);
    XCTAssertNotNil(error.userInfo);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Nil token result provided");
}

- (void)testMSALResultWithTokenResult_whenTokenResultContainsInvalidIdToken_shouldReturnError
{
    MSIDTokenResult *tokenResult = [MSIDTokenResult new];
    
    NSError *error = nil;
    MSALResult *result = [MSALResult resultWithTokenResult:tokenResult tokenCache:nil error:&error];
    
    XCTAssertNil(result);
    XCTAssertEqualObjects(error.domain, @"MSIDErrorDomain");
    XCTAssertEqual(error.code, -51401);
    XCTAssertNotNil(error.userInfo);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Nil id_token passed");
}

- (void)testMSALResultWithTokenResult_whenTokenResultContainsNilAuthority_shouldReturnError
{
    MSIDTokenResult *tokenResult = [MSIDTokenResult new];
    tokenResult.rawIdToken = @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0aWQiOiJ0ZW5hbnRfaWQifQ.t3T_3W7IcUfkjxTEUlM4beC1KccZJG7JaCJvTLjYg6M";
    
    NSError *error = nil;
    MSALResult *result = [MSALResult resultWithTokenResult:tokenResult tokenCache:nil error:&error];
    
    XCTAssertNil(result);
    XCTAssertEqualObjects(error.domain, @"MSALErrorDomain");
    XCTAssertEqual(error.code, -42000);
    XCTAssertNotNil(error.userInfo);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Provided authority url is not a valid authority.");
}

- (void)testMSALResultWithTokenResult_whenValidTokenResult_shouldReturnCorrectAttributes
{
    MSIDTokenResult *tokenResult = [MSIDTokenResult new];
    tokenResult.rawIdToken = @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0aWQiOiJ0ZW5hbnRfaWQifQ.t3T_3W7IcUfkjxTEUlM4beC1KccZJG7JaCJvTLjYg6M";
    NSError *claimsError = nil;
    MSIDAADV2IdTokenClaims *claims = [[MSIDAADV2IdTokenClaims alloc] initWithRawIdToken:tokenResult.rawIdToken error:&claimsError];
    __auto_type authority = [@"https://login.microsoftonline.com/tenant_id" authority];
    tokenResult.authority = authority;
    MSIDAccount *account = [MSIDAccount new];
    account.authority = authority;
    account.localAccountId = @"local account id";
    account.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy.id" homeAccountId:@"uid.tenant_id"];
    tokenResult.account = account;
    
    NSError *error = nil;
    MSALResult *result = [MSALResult resultWithTokenResult:tokenResult tokenCache:nil error:&error];
    
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.tenantId, claims.realm);
    XCTAssertEqual(result.uniqueId, @"local account id");
    XCTAssertNotNil(result.tenantProfile);
    XCTAssertEqualObjects(result.tenantProfile.authority.url, authority.url);
    XCTAssertEqual(result.tenantProfile.isHomeTenant, YES);
    XCTAssertEqualObjects(result.tenantProfile.tenantId, @"tenant_id");
    XCTAssertNotNil(result.tenantProfile.claims);
    XCTAssertNotNil(result.account);
    XCTAssertEqualObjects(result.account.homeAccountId.identifier, @"uid.tenant_id");
    XCTAssertNil(result.account.allTenantProfiles);
}

// TODO: Make it applicable to Mac when Mac cache is complete
#if TARGET_OS_IPHONE
- (void)testMSALResultWithTokenResult_whenIdTokensInCache_shouldConstructTenantProfiles
{
    //Store some accounts to cache
    // first user logged in 1 home tenant and 2 guest tenants
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/tid"
                                             clientId:@"client_id"
                                                  upn:@"user@contoso.com"
                                                 name:@"contoso_user"
                                                  uid:@"uid"
                                                 utid:@"tid"
                                                  oid:@"oid"
                                             tenantId:@"tid"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
    
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/guest_tid"
                                             clientId:@"different_client_id"
                                                  upn:@"user@contoso.com"
                                                 name:@"contoso_user"
                                                  uid:@"uid"
                                                 utid:@"tid"
                                                  oid:@"guest_oid"
                                             tenantId:@"guest_tid"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
    
    [MSIDTestCacheUtil saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/guest2_tid"
                                            clientId:@"client_id"
                                                 upn:@"user@contoso.com"
                                                name:@"contoso_user"
                                                 uid:@"uid"
                                                utid:@"tid"
                                                 oid:@"guest2_oid"
                                            tenantId:@"guest2_tid"
                                            familyId:nil
                                       cacheAccessor:legacyCache];
    
    // second user logged in 1 home tenant and 1 guest tenant
    [MSIDTestCacheUtil saveLegacyTokensWithAuthority:@"https://login.microsoftonline.com/tid2"
                                            clientId:@"client_id"
                                                 upn:@"user@fabricant.com"
                                                name:@"fabricant_user"
                                                 uid:@"uid2"
                                                utid:@"tid2"
                                                 oid:@"oid2"
                                            tenantId:@"tid2"
                                            familyId:nil
                                       cacheAccessor:legacyCache];
    
    [MSIDTestCacheUtil saveDefaultTokensWithAuthority:@"https://login.microsoftonline.com/guest_tid2"
                                             clientId:@"client_id"
                                                  upn:@"user@fabricant.com"
                                                 name:@"fabricant_user"
                                                  uid:@"uid2"
                                                 utid:@"tid2"
                                                  oid:@"guest_oid2"
                                             tenantId:@"guest_tid2"
                                             familyId:nil
                                        cacheAccessor:defaultCache];
    
    MSIDTokenResult *tokenResult = [MSIDTokenResult new];
    tokenResult.rawIdToken = [MSIDTestIdTokenUtil idTokenWithName:@"contoso_user" preferredUsername:@"user@contoso.com" oid:@"uid" tenantId:@"tid"];
    tokenResult.accessToken = [MSIDAccessToken new];
    tokenResult.accessToken.clientId = @"client_id";
    __auto_type authority = [@"https://login.microsoftonline.com/tid" authority];
    tokenResult.authority = authority;
    MSIDAccount *account = [MSIDAccount new];
    account.authority = authority;
    account.localAccountId = @"uid";
    account.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com" homeAccountId:@"uid.tid"];
    tokenResult.account = account;
    
    // Construct MSAL result from MSID result
    NSError *error = nil;
    MSALResult *result = [MSALResult resultWithTokenResult:tokenResult tokenCache:defaultCache error:&error];
    
    // Verify account
    MSALAccount *resultAccount = result.account;
    XCTAssertNotNil(resultAccount);
    
    XCTAssertEqualObjects(resultAccount.username, @"user@contoso.com");
    XCTAssertEqualObjects(resultAccount.homeAccountId.identifier, @"uid.tid");
    XCTAssertEqualObjects(resultAccount.name, @"contoso_user");
    XCTAssertEqualObjects(resultAccount.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(resultAccount.lookupAccountIdentifier.homeAccountId, @"uid.tid");
    
    // expect 3 tenant profiles
    XCTAssertEqual(resultAccount.tenantProfiles.count, 3);
    
    XCTAssertEqualObjects(resultAccount.tenantProfiles[0].authority.url.absoluteString, @"https://login.microsoftonline.com/tid");
    XCTAssertEqualObjects(resultAccount.tenantProfiles[0].userObjectId, @"oid");
    XCTAssertEqualObjects(resultAccount.tenantProfiles[0].tenantId, @"tid");
    XCTAssertTrue(resultAccount.tenantProfiles[0].claims.count > 0);
    
    XCTAssertEqualObjects(resultAccount.tenantProfiles[1].authority.url.absoluteString, @"https://login.microsoftonline.com/guest_tid");
    XCTAssertEqualObjects(resultAccount.tenantProfiles[1].userObjectId, @"guest_oid");
    XCTAssertEqualObjects(resultAccount.tenantProfiles[1].tenantId, @"guest_tid");
    // this tenant profile belongs to another client id, so we do not expose all claims
    XCTAssertNil(resultAccount.tenantProfiles[1].claims);
    
    XCTAssertEqualObjects(resultAccount.tenantProfiles[2].authority.url.absoluteString, @"https://login.microsoftonline.com/guest2_tid");
    XCTAssertEqualObjects(resultAccount.tenantProfiles[2].userObjectId, @"guest2_oid");
    XCTAssertEqualObjects(resultAccount.tenantProfiles[2].tenantId, @"guest2_tid");
    XCTAssertTrue(resultAccount.tenantProfiles[0].claims.count > 0);
}
#endif

@end
