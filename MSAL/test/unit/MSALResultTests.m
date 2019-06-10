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
#import "MSALResult+Internal.h"
#import "MSALAADAuthority.h"
#import "MSALAuthority_Internal.h"
#import "MSALAccount+MultiTenantAccount.h"

@interface MSALResultTests : MSALTestCase

@end

@implementation MSALResultTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testMSALResultWithTokenResult_whenTokenResultIsNil_shouldReturnError
{
    MSIDTokenResult *tokenResult = nil;
    
    NSError *error = nil;
    MSALAADAuthority *authority = [[MSALAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://my.issuer.com/contoso.com"] error:nil];
    MSALResult *result = [MSALResult resultWithMSIDTokenResult:tokenResult authority:authority error:&error];
    
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
    MSALAADAuthority *authority = [[MSALAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://my.issuer.com/contoso.com"] error:nil];
    MSALResult *result = [MSALResult resultWithMSIDTokenResult:tokenResult authority:authority error:&error];
    
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
    MSALAADAuthority *authority = nil;
    MSALResult *result = [MSALResult resultWithMSIDTokenResult:tokenResult authority:authority error:&error];
    
    XCTAssertNil(result);
    XCTAssertEqualObjects(error.domain, @"MSIDErrorDomain");
    XCTAssertEqual(error.code, MSIDErrorInternal);
    XCTAssertNotNil(error.userInfo);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Nil authority in the result provided");
}

- (void)testMSALResultWithTokenResult_whenValidTokenResult_shouldReturnCorrectAttributes
{
    MSALAADAuthority *msalAuthority = [[MSALAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/tenant_id"] error:nil];
    
    MSIDTokenResult *tokenResult = [MSIDTokenResult new];
    tokenResult.rawIdToken = @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0aWQiOiJ0ZW5hbnRfaWQifQ.t3T_3W7IcUfkjxTEUlM4beC1KccZJG7JaCJvTLjYg6M";
    NSError *claimsError = nil;
    MSIDAADV2IdTokenClaims *claims = [[MSIDAADV2IdTokenClaims alloc] initWithRawIdToken:tokenResult.rawIdToken error:&claimsError];
    __auto_type authority = [@"https://login.microsoftonline.com/tenant_id" aadAuthority];
    tokenResult.authority = msalAuthority.msidAuthority;
    MSIDAccount *account = [MSIDAccount new];
    account.environment = authority.environment;
    account.realm = authority.realm;
    account.localAccountId = @"local account id";
    account.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy.id" homeAccountId:@"uid.tenant_id"];
    tokenResult.account = account;
    tokenResult.correlationId = [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000001"];
    
    NSError *error = nil;
    MSALResult *result = [MSALResult resultWithMSIDTokenResult:tokenResult authority:msalAuthority error:&error];
    
    XCTAssertNotNil(result);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    XCTAssertEqualObjects(result.tenantId, claims.realm);
    XCTAssertEqual(result.uniqueId, @"local account id");
#pragma clang diagnostic pop
    XCTAssertNotNil(result.tenantProfile);
    XCTAssertEqualObjects(result.tenantProfile.environment, authority.environment);
    XCTAssertEqualObjects(result.tenantProfile.tenantId, authority.realm);
    XCTAssertEqual(result.tenantProfile.isHomeTenantProfile, YES);
    XCTAssertEqualObjects(result.tenantProfile.tenantId, @"tenant_id");
    XCTAssertNotNil(result.tenantProfile.claims);
    XCTAssertNotNil(result.account);
    XCTAssertEqualObjects(result.account.identifier, @"uid.tenant_id");
    XCTAssertNil(result.account.tenantProfiles);
    XCTAssertEqualObjects(tokenResult.correlationId.UUIDString, @"00000000-0000-0000-0000-000000000001");
}

@end
