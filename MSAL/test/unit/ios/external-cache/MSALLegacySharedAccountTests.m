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
#import "MSALLegacySharedAccount.h"
#import "MSALAccountEnumerationParameters.h"
#import "MSALTestConstants.h"
#import "MSALTestBundle.h"
#import "MSALAccount+Internal.h"
#import "MSALAccountId+Internal.h"
#import "MSALLegacySharedAccountTestUtil.h"

@interface MSALLegacySharedAccountTests : XCTestCase

@end

@implementation MSALLegacySharedAccountTests

#pragma mark - Init

- (void)testInitWithJSONDictionary_whenAccountTypeMissing_shouldReturnNilAndFillError
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionary] mutableCopy];
    jsonDictionary[@"type"] = nil;
    
    NSError *error = nil;
    MSALLegacySharedAccount *account = [[MSALLegacySharedAccount alloc] initWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNil(account);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Unexpected shared account found without type or identifier");
}

- (void)testInitWithJSONDictionary_whenIdentifierMissing_shouldReturnNilAndFillError
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionary] mutableCopy];
    jsonDictionary[@"id"] = nil;
    
    NSError *error = nil;
    MSALLegacySharedAccount *account = [[MSALLegacySharedAccount alloc] initWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNil(account);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Unexpected shared account found without type or identifier");
}

- (void)testInitWithJSONDictionary_whenAllMandatoryFieldsPresent_shouldReturnNotNilResultAndNilError
{
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId objectId:nil tenantId:nil username:nil] mutableCopy];
    NSDictionary *signinStatusDict = @{@"com.microsoft.myapp": @"SignedIn",
                                       @"com.microsoft.myapp2": @"SignedOut"
                                       };
    jsonDictionary[@"signInStatus"] = signinStatusDict;
    
    NSError *error = nil;
    MSALLegacySharedAccount *account = [[MSALLegacySharedAccount alloc] initWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNotNil(account);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(account.accountType, @"ADAL");
    XCTAssertEqualObjects(account.accountIdentifier, accountId);
    XCTAssertEqualObjects(account.signinStatusDictionary, signinStatusDict);
}

- (void)testInitWithJSONDictionary_whenFieldsOfWrongType_shouldReturnNilAndFillError
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionary] mutableCopy];
    jsonDictionary[@"type"] = [NSNull null];
    jsonDictionary[@"id"] = [NSNumber numberWithInteger:5];
    
    NSError *error = nil;
    MSALLegacySharedAccount *account = [[MSALLegacySharedAccount alloc] initWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNil(account);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Unexpected shared account found without type or identifier");
}

#pragma mark - matchesParameters

- (void)testMatchesParameters_whenNilParameters_shouldReturnYES
{
    NSDictionary *jsonDictionary = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionary];
    MSALLegacySharedAccount *account = [[MSALLegacySharedAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = nil;
    BOOL result = [account matchesParameters:params];
    XCTAssertTrue(result);
}

- (void)testMatchesParameters_whenReturnOnlySignedInAccountsNO_andAppSignedOut_shouldReturnYES
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionary] mutableCopy];
    
    NSDictionary *signinStatusDict = @{[[NSBundle mainBundle] bundleIdentifier]: @"SignedOut", @"com.microsoft.otherapp": @"SignedIn"};
    jsonDictionary[@"signInStatus"] = signinStatusDict;
    
    MSALLegacySharedAccount *account = [[MSALLegacySharedAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [MSALAccountEnumerationParameters new];
    params.returnOnlySignedInAccounts = NO;
    BOOL result = [account matchesParameters:params];
    XCTAssertTrue(result);
}

- (void)testMatchesParameters_whenReturnOnlySignedInAccountsYES_andAppSignedIn_shouldReturnYES
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionary] mutableCopy];
    
    NSDictionary *signinStatusDict = @{[[NSBundle mainBundle] bundleIdentifier] : @"SignedIn"};
    jsonDictionary[@"signInStatus"] = signinStatusDict;
    
    MSALLegacySharedAccount *account = [[MSALLegacySharedAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [MSALAccountEnumerationParameters new];
    params.returnOnlySignedInAccounts = YES;
    BOOL result = [account matchesParameters:params];
    XCTAssertTrue(result);
}

- (void)testMatchesParameters_whenReturnOnlySignedInAccountsYES_andAppSignedOut_shouldReturnNO
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionary] mutableCopy];
    
    NSDictionary *signinStatusDict = @{[[NSBundle mainBundle] bundleIdentifier]: @"SignedOut"};
    jsonDictionary[@"signInStatus"] = signinStatusDict;
    
    MSALLegacySharedAccount *account = [[MSALLegacySharedAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [MSALAccountEnumerationParameters new];
    params.returnOnlySignedInAccounts = YES;
    BOOL result = [account matchesParameters:params];
    XCTAssertFalse(result);
}

#pragma mark - updateAccountWithMSALAccount

- (void)testUpdateAccountWithMSALAccount_whenV1Account_shouldReturnYesAndNilError_andNotUpdate
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionary] mutableCopy];
    MSALLegacySharedAccount *account = [[MSALLegacySharedAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    NSError *updateError = nil;
    BOOL result = [account updateAccountWithMSALAccount:[MSALLegacySharedAccountTestUtil testADALAccount]
                                        applicationName:@"MyApp"
                                              operation:MSALLegacySharedAccountRemoveOperation
                                         accountVersion:MSALLegacySharedAccountVersionV1
                                                  error:&updateError];
    
    XCTAssertTrue(result);
    XCTAssertNil(updateError);
    XCTAssertEqualObjects([account jsonDictionary], jsonDictionary);
}

- (void)testUpdateAccountWithMSALAccount_whenRemoveOperation_shouldUpdateSigninStatusAndUpdatedDict
{
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSString *appIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId objectId:nil tenantId:nil username:nil] mutableCopy];
    NSDictionary *signinStatusDict = @{appIdentifier : @"SignedIn"};
    jsonDictionary[@"signInStatus"] = signinStatusDict;
    
    MSALLegacySharedAccount *account = [[MSALLegacySharedAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    NSError *updateError = nil;
    BOOL result = [account updateAccountWithMSALAccount:[MSALLegacySharedAccountTestUtil testADALAccount]
                                        applicationName:@"MyApp"
                                              operation:MSALLegacySharedAccountRemoveOperation
                                         accountVersion:MSALLegacySharedAccountVersionV2
                                                  error:&updateError];
    
    XCTAssertTrue(result);
    XCTAssertNil(updateError);
    XCTAssertNotEqualObjects([account jsonDictionary], jsonDictionary);
    NSString *newSigninStatus = [account jsonDictionary][@"signInStatus"][appIdentifier];
    XCTAssertEqualObjects(newSigninStatus, @"SignedOut");
    NSString *updatedByStatus = [account jsonDictionary][@"additionalProperties"][@"updatedBy"];
    XCTAssertEqualObjects(updatedByStatus, @"MyApp");
    NSString *updatedAt = [account jsonDictionary][@"additionalProperties"][@"updatedAt"];
    XCTAssertNotNil(updatedAt);
    XCTAssertEqualObjects(account.accountType, @"ADAL");
    XCTAssertEqualObjects(account.accountIdentifier, accountId);
}

- (void)testUpdateAccountWithMSALAccount_whenUpdateOperation_shouldUpdateSigninStatusAndUpdatedDict
{
    NSString *accountId = [NSUUID UUID].UUIDString;
    NSString *appIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId objectId:nil tenantId:nil username:nil] mutableCopy];
    NSDictionary *signinStatusDict = @{appIdentifier : @"SignedOut"};
    jsonDictionary[@"signInStatus"] = signinStatusDict;
    
    MSALLegacySharedAccount *account = [[MSALLegacySharedAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    NSError *updateError = nil;
    BOOL result = [account updateAccountWithMSALAccount:[MSALLegacySharedAccountTestUtil testADALAccount]
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
    XCTAssertEqualObjects(account.accountType, @"ADAL");
    XCTAssertEqualObjects(account.accountIdentifier, accountId);
}

@end
