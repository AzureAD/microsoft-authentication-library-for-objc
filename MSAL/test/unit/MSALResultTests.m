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
    __auto_type authority = [@"https://login.microsoftonline.com/common" authority];
    tokenResult.authority = authority;
    MSIDAccount *account = [MSIDAccount new];
    account.authority = authority;
    account.localAccountId = @"local account id";
    account.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy.id" homeAccountId:@"some id"];
    tokenResult.account = account;
    
    NSError *error = nil;
    MSALResult *result = [MSALResult resultWithTokenResult:tokenResult tokenCache:nil error:&error];
    
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.tenantId, claims.realm);
    XCTAssertEqual(result.uniqueId, @"local account id");
}

@end
