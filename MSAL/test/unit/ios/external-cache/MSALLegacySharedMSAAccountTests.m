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
#import "MSALLegacySharedMSAAccount.h"
#import "MSALAccount+Internal.h"
#import "MSALAccountId+Internal.h"
#import "MSALAccountEnumerationParameters.h"
#import "MSIDConstants.h"
#import "MSALLegacySharedAccountTestUtil.h"

@interface MSALLegacySharedMSAAccountTests : XCTestCase

@end

static NSString *kDefaultTestUid = @"00000000-0000-0000-40c0-3bac188d0d10";
static NSString *kDefaultTestCid = @"40c03bac188d0d10";

@implementation MSALLegacySharedMSAAccountTests

#pragma mark - Init

- (void)testInitWithJSONDictionary_whenWrongAccountType_shouldReturnNilAndError
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleMSAJSONDictionary] mutableCopy];
    jsonDictionary[@"type"] = @"ADAL";
    
    NSError *error = nil;
    MSALLegacySharedMSAAccount *account = [[MSALLegacySharedMSAAccount alloc] initWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNil(account);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Unexpected account type");
}

- (void)testInitWithJSONDictionary_whenNilUID_shouldReturnNilAndFillError
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleMSAJSONDictionary] mutableCopy];
    jsonDictionary[@"cid"] = nil;
    
    NSError *error = nil;
    MSALLegacySharedMSAAccount *account = [[MSALLegacySharedMSAAccount alloc] initWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNil(account);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Unexpected identifier found for MSA account");
}

- (void)testInitWithJSONDictionary_whenAllInformationPresent_shouldCreateAccount
{
    NSString *accountId = [NSUUID UUID].UUIDString.lowercaseString;
    
    NSDictionary *jsonDictionary = [MSALLegacySharedAccountTestUtil sampleMSAJSONDictionaryWithAccountId:accountId];
    
    NSError *error = nil;
    MSALLegacySharedMSAAccount *account = [[MSALLegacySharedMSAAccount alloc] initWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNotNil(account);
    XCTAssertNil(error);
    XCTAssertEqualObjects(account.accountType, @"MSA");
    XCTAssertEqualObjects(account.environment, @"login.windows.net");
    NSString *expectedIdentifier = [NSString stringWithFormat:@"%@.%@", kDefaultTestUid, MSID_DEFAULT_MSA_TENANTID.lowercaseString];
    XCTAssertEqualObjects(account.identifier, expectedIdentifier);
    XCTAssertEqualObjects(account.accountIdentifier, accountId);
    XCTAssertEqualObjects(account.username, @"user@outlook.com");
    XCTAssertEqualObjects(account.accountClaims[@"oid"], kDefaultTestUid);
    XCTAssertEqualObjects(account.accountClaims[@"tid"], MSID_DEFAULT_MSA_TENANTID);
}

#pragma mark - MatchesParameters

- (void)testMatchesWithParameters_whenShouldHaveAssociatedRefreshTokenYES_AndAccountSignedOut_shouldReturnNO
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleMSAJSONDictionary] mutableCopy];
    
    NSDictionary *signinStatusDict = @{[[NSBundle mainBundle] bundleIdentifier]: @"SignedOut"};
    jsonDictionary[@"signInStatus"] = signinStatusDict;
    
    MSALLegacySharedMSAAccount *account = [[MSALLegacySharedMSAAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [MSALAccountEnumerationParameters new];
    params.returnOnlySignedInAccounts = YES;
    BOOL result = [account matchesParameters:params];
    XCTAssertFalse(result);
}

- (void)testMatchesWithParameters_whenNilParameters_shouldReturnYES
{
    NSDictionary *jsonDictionary = [MSALLegacySharedAccountTestUtil sampleMSAJSONDictionary];
    MSALLegacySharedMSAAccount *account = [[MSALLegacySharedMSAAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = nil;
    BOOL result = [account matchesParameters:params];
    XCTAssertTrue(result);
}

- (void)testMatchesWithParameters_whenIdentifierNonNil_andMatchingIdentifier_shouldReturnYES
{
    NSDictionary *jsonDictionary = [MSALLegacySharedAccountTestUtil sampleMSAJSONDictionary];
    
    MSALLegacySharedMSAAccount *account = [[MSALLegacySharedMSAAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    NSString *expectedIdentifier = [NSString stringWithFormat:@"%@.%@", kDefaultTestUid, MSID_DEFAULT_MSA_TENANTID.lowercaseString];
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:expectedIdentifier];
    params.returnOnlySignedInAccounts = NO;
    BOOL result = [account matchesParameters:params];
    XCTAssertTrue(result);
}

- (void)testMatchesWithParameters_whenIdentifierAndUsernameSet_andMatchingAllOptions_shouldReturnYES
{
    NSDictionary *jsonDictionary = [MSALLegacySharedAccountTestUtil sampleMSAJSONDictionary];
    
    MSALLegacySharedMSAAccount *account = [[MSALLegacySharedMSAAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    NSString *expectedIdentifier = [NSString stringWithFormat:@"%@.%@", kDefaultTestUid, MSID_DEFAULT_MSA_TENANTID.lowercaseString];
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:expectedIdentifier username:@"user@outlook.com"];
    params.returnOnlySignedInAccounts = NO;
    BOOL result = [account matchesParameters:params];
    XCTAssertTrue(result);
}

- (void)testMatchesWithParameters_whenAllMatchignOptionsSet_andMatchingAllOptions_butDifferentCase_shouldReturnYES
{
    NSDictionary *jsonDictionary = [MSALLegacySharedAccountTestUtil sampleMSAJSONDictionary];
    
    MSALLegacySharedMSAAccount *account = [[MSALLegacySharedMSAAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    NSString *expectedIdentifier = [NSString stringWithFormat:@"%@.%@", kDefaultTestUid.uppercaseString, MSID_DEFAULT_MSA_TENANTID];
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:expectedIdentifier username:@"USER@outlOOK.com"];
    params.returnOnlySignedInAccounts = NO;
    BOOL result = [account matchesParameters:params];
    XCTAssertTrue(result);
}

- (void)testMatchesWithParameters_whenTenantProfileIdentifierNonNil_shouldReturnNO
{
    NSDictionary *jsonDictionary = [MSALLegacySharedAccountTestUtil sampleMSAJSONDictionary];
    
    MSALLegacySharedMSAAccount *account = [[MSALLegacySharedMSAAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithTenantProfileIdentifier:@"myoid"];
    params.returnOnlySignedInAccounts = NO;
    BOOL result = [account matchesParameters:params];
    XCTAssertFalse(result);
}

- (void)testMatchesWithParamaters_whenUsernameNonNil_andUsernameDifferent_shouldReturnNO
{
    NSDictionary *jsonDictionary = [MSALLegacySharedAccountTestUtil sampleMSAJSONDictionary];
    
    MSALLegacySharedMSAAccount *account = [[MSALLegacySharedMSAAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:nil username:@"user2@contoso.com"];
    params.returnOnlySignedInAccounts = NO;
    BOOL result = [account matchesParameters:params];
    XCTAssertFalse(result);
}

- (void)testMatchesWithParameters_whenIdentifierNonNil_andIdentifierDifferent_shouldReturnNO
{
    NSDictionary *jsonDictionary = [MSALLegacySharedAccountTestUtil sampleMSAJSONDictionary];
    
    MSALLegacySharedMSAAccount *account = [[MSALLegacySharedMSAAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:@"oid.utid2"];
    params.returnOnlySignedInAccounts = NO;
    BOOL result = [account matchesParameters:params];
    XCTAssertFalse(result);
}

#pragma mark - Update

- (void)testUpdateWithMSALAccount_whenUsernameAndSigninStatusChanged_shouldUpdateUsername
{
    NSString *appIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleMSAJSONDictionary] mutableCopy];
    NSDictionary *signinStatusDict = @{appIdentifier : @"SignedOut"};
    jsonDictionary[@"signInStatus"] = signinStatusDict;
    jsonDictionary[@"email"] = @"old@contoso.old.com";
    
    MSALLegacySharedMSAAccount *account = [[MSALLegacySharedMSAAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    NSError *updateError = nil;
    BOOL result = [account updateAccountWithMSALAccount:[MSALLegacySharedAccountTestUtil testMSAAccount]
                                        applicationName:@"MyApp"
                                              operation:MSALLegacySharedAccountUpdateOperation
                                         accountVersion:MSALLegacySharedAccountVersionV3
                                                  error:&updateError];
    
    XCTAssertTrue(result);
    XCTAssertNil(updateError);
    XCTAssertNotEqualObjects([account jsonDictionary], jsonDictionary);
    NSString *newSigninStatus = [account jsonDictionary][@"signInStatus"][appIdentifier];
    XCTAssertEqualObjects(newSigninStatus, @"SignedIn");
    NSString *updatedByStatus = [account jsonDictionary][@"additionalProperties"][@"updatedBy"];
    XCTAssertEqualObjects(updatedByStatus, @"MyApp");
    NSString *updatedAt = [account jsonDictionary][@"additionalProperties"][@"updatedAt"];
    XCTAssertNotNil(updatedAt);
    XCTAssertEqualObjects(account.accountType, @"MSA");
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
    XCTAssertEqualObjects([account jsonDictionary][@"additionalfield1"], @"additionalvalue1");
    
}

@end
