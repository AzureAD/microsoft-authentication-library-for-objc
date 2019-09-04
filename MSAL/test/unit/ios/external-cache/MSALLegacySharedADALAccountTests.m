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
#import "MSALAccount+Internal.h"
#import "MSALAccountId+Internal.h"
#import "MSALLegacySharedADALAccount.h"
#import "MSALAccountEnumerationParameters.h"
#import "MSALLegacySharedAccountTestUtil.h"

@interface MSALLegacySharedADALAccountTests : XCTestCase

@end

@implementation MSALLegacySharedADALAccountTests

#pragma mark - Init

- (void)testInitWithJSONDictionary_whenWrongAccountType_shouldReturnNilAndError
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionary] mutableCopy];
    jsonDictionary[@"type"] = @"UnknownType";
    
    NSError *error = nil;
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNil(account);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Unexpected account type");
}

- (void)testInitWithJSONDictionary_whenNilAuthEndpoint_shouldReturnNilAndFillError
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionary] mutableCopy];
    jsonDictionary[@"authEndpointUrl"] = nil;
    
    NSError *error = nil;
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNil(account);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Unexpected authority found");
}

- (void)testInitWithJSONDictionary_whenWrongAuthEndpoint_shouldReturnNilAndFillError
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionary] mutableCopy];
    jsonDictionary[@"authEndpointUrl"] = @"https://b2clogin.microsoft.com/";
    
    NSError *error = nil;
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:&error];
    XCTAssertNil(account);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"authority must have AAD tenant.");
}

- (void)testInitWithJSONDictionary_whenAllInformationPresentAndHomeTenant_shouldCreateAccount
{
    NSString *accountId = [NSUUID UUID].UUIDString.lowercaseString;
    NSString *objectId = [NSUUID UUID].UUIDString.lowercaseString;
    NSString *tenantId = [NSUUID UUID].UUIDString.lowercaseString;
    
    NSDictionary *adalAccountDictionary = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId objectId:objectId tenantId:tenantId username:nil];
    
    NSError *error = nil;
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:adalAccountDictionary error:&error];
    XCTAssertNotNil(account);
    XCTAssertNil(error);
    XCTAssertEqualObjects(account.accountType, @"ADAL");
    XCTAssertEqualObjects(account.environment, @"login.windows.net");
    NSString *expectedIdentifier = [NSString stringWithFormat:@"%@.%@", objectId, tenantId];
    XCTAssertEqualObjects(account.identifier, expectedIdentifier);
    XCTAssertEqualObjects(account.accountIdentifier, accountId);
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
    XCTAssertEqualObjects(account.accountClaims[@"oid"], objectId);
    XCTAssertEqualObjects(account.accountClaims[@"tid"], tenantId);
    XCTAssertEqualObjects(account.accountClaims[@"name"], @"myDisplayName.contoso.user");
}

- (void)testInitWithJSONDictionary_whenAllInformationPresentAndGuestTenant_shouldCreateAccountWithoutIdentifier
{
    NSString *accountId = [NSUUID UUID].UUIDString.lowercaseString;
    NSString *objectId = [NSUUID UUID].UUIDString.lowercaseString;
    NSString *tenantId = [NSUUID UUID].UUIDString.lowercaseString;
    
    NSDictionary *adalAccountDictionary = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:accountId objectId:objectId tenantId:tenantId username:nil];
    
    NSMutableDictionary *mutableDict = [adalAccountDictionary mutableCopy];
    mutableDict[@"authEndpointUrl"] = @"https://login.microsoftonline.com/contoso.com";
    
    NSError *error = nil;
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:mutableDict error:&error];
    XCTAssertNotNil(account);
    XCTAssertNil(error);
    XCTAssertEqualObjects(account.accountType, @"ADAL");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertNil(account.identifier);
    XCTAssertEqualObjects(account.accountIdentifier, accountId);
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
    XCTAssertEqualObjects(account.accountClaims[@"oid"], objectId);
    XCTAssertEqualObjects(account.accountClaims[@"tid"], tenantId);
    XCTAssertEqualObjects(account.accountClaims[@"name"], @"myDisplayName.contoso.user");
}

#pragma mark - InitWithMSALAccount

- (void)testInitWithMSALAccount_whenV1Version_shouldReturnNilResultAndNilError
{
    NSError *error = nil;
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithMSALAccount:[MSALLegacySharedAccountTestUtil testADALAccount]
                                                                                      accountClaims:@{}
                                                                                    applicationName:@"MyApp"
                                                                                     accountVersion:MSALLegacySharedAccountVersionV1
                                                                                              error:&error];
    XCTAssertNil(account);
    XCTAssertNil(error);
}

- (void)testInitWithMSALAccount_whenNilAccount_shouldReturnNilAndFillError
{
    NSError *error = nil;
    MSALAccount *msalAccount = nil;
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithMSALAccount:msalAccount
                                                                                      accountClaims:@{}
                                                                                    applicationName:@"MyApp"
                                                                                     accountVersion:MSALLegacySharedAccountVersionV3
                                                                                              error:&error];
    XCTAssertNil(account);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Unexpected parameter - no account");
}

- (void)testInitWithMSALAccount_whenADALAccount_andV3Version_shouldFillAllEntries
{
    NSError *error = nil;
    MSALAccount *msalAccount = [MSALLegacySharedAccountTestUtil testADALAccount];
    NSDictionary *claims = @{@"name": @"Contoso User",
                             @"oid": @"uid",
                             @"tid": @"utid"
                             };
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithMSALAccount:msalAccount
                                                                                      accountClaims:claims
                                                                                    applicationName:@"MyApp"
                                                                                     accountVersion:MSALLegacySharedAccountVersionV3
                                                                                              error:&error];
    XCTAssertNotNil(account);
    XCTAssertNil(error);
    NSDictionary *resultDictionary = [account jsonDictionary];
    XCTAssertNotNil(resultDictionary[@"id"]);
    XCTAssertEqualObjects(resultDictionary[@"environment"], @"PROD");
    NSString *appIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    XCTAssertEqualObjects(resultDictionary[@"originAppId"], appIdentifier);
    NSString *signinStatus = resultDictionary[@"signInStatus"][appIdentifier];
    XCTAssertEqualObjects(signinStatus, @"SignedIn");
    XCTAssertEqualObjects(resultDictionary[@"username"], @"user@contoso.com");
    XCTAssertEqualObjects(resultDictionary[@"additionalProperties"][@"createdBy"], @"MyApp");
    XCTAssertEqualObjects(resultDictionary[@"displayName"], @"Contoso User");
    XCTAssertEqualObjects(resultDictionary[@"oid"], @"uid");
    XCTAssertEqualObjects(resultDictionary[@"tenantId"], @"utid");
    XCTAssertEqualObjects(resultDictionary[@"type"], @"ADAL");
    XCTAssertEqualObjects(resultDictionary[@"authEndpointUrl"], @"https://login.microsoftonline.com/common");
    
}

- (void)testInitWithMSALAccount_whenADALAccount_andV2Version_shouldFillAllEntriesExceptOriginApp
{
    NSError *error = nil;
    MSALAccount *msalAccount = [MSALLegacySharedAccountTestUtil testADALAccount];
    NSDictionary *claims = @{@"name": @"Contoso User",
                             @"oid": @"uid",
                             @"tid": @"utid"
                             };
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithMSALAccount:msalAccount
                                                                                      accountClaims:claims
                                                                                    applicationName:@"MyApp"
                                                                                     accountVersion:MSALLegacySharedAccountVersionV2
                                                                                              error:&error];
    XCTAssertNotNil(account);
    XCTAssertNil(error);
    NSDictionary *resultDictionary = [account jsonDictionary];
    XCTAssertNotNil(resultDictionary[@"id"]);
    XCTAssertEqualObjects(resultDictionary[@"environment"], @"PROD");
    NSString *appIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    XCTAssertNil(resultDictionary[@"originAppId"]);
    NSString *signinStatus = resultDictionary[@"signInStatus"][appIdentifier];
    XCTAssertEqualObjects(signinStatus, @"SignedIn");
    XCTAssertEqualObjects(resultDictionary[@"username"], @"user@contoso.com");
    XCTAssertEqualObjects(resultDictionary[@"additionalProperties"][@"createdBy"], @"MyApp");
    XCTAssertEqualObjects(resultDictionary[@"displayName"], @"Contoso User");
    XCTAssertEqualObjects(resultDictionary[@"oid"], @"uid");
    XCTAssertEqualObjects(resultDictionary[@"tenantId"], @"utid");
    XCTAssertEqualObjects(resultDictionary[@"type"], @"ADAL");
    XCTAssertEqualObjects(resultDictionary[@"authEndpointUrl"], @"https://login.microsoftonline.com/common");
}

- (void)testInitWithMSALAccount_whenADALAccount_andGuestTenant_shouldFillAllEntriesWithGuestTenantAuthority
{
    NSError *error = nil;
    MSALAccount *msalAccount = [MSALLegacySharedAccountTestUtil testADALAccount];
    NSDictionary *claims = @{@"name": @"Contoso User",
                             @"oid": @"guest_uid",
                             @"tid": @"guest_utid"
                             };
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithMSALAccount:msalAccount
                                                                                      accountClaims:claims
                                                                                    applicationName:@"MyApp"
                                                                                     accountVersion:MSALLegacySharedAccountVersionV3
                                                                                              error:&error];
    XCTAssertNotNil(account);
    XCTAssertNil(error);
    NSDictionary *resultDictionary = [account jsonDictionary];
    XCTAssertNotNil(resultDictionary[@"id"]);
    XCTAssertEqualObjects(resultDictionary[@"environment"], @"PROD");
    NSString *appIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    XCTAssertEqualObjects(resultDictionary[@"originAppId"], appIdentifier);
    NSString *signinStatus = resultDictionary[@"signInStatus"][appIdentifier];
    XCTAssertEqualObjects(signinStatus, @"SignedIn");
    XCTAssertEqualObjects(resultDictionary[@"username"], @"user@contoso.com");
    XCTAssertEqualObjects(resultDictionary[@"additionalProperties"][@"createdBy"], @"MyApp");
    XCTAssertEqualObjects(resultDictionary[@"displayName"], @"Contoso User");
    XCTAssertEqualObjects(resultDictionary[@"oid"], @"guest_uid");
    XCTAssertEqualObjects(resultDictionary[@"tenantId"], @"guest_utid");
    XCTAssertEqualObjects(resultDictionary[@"type"], @"ADAL");
    XCTAssertEqualObjects(resultDictionary[@"authEndpointUrl"], @"https://login.microsoftonline.com/guest_utid");
}

#pragma mark - MatchesParameters

- (void)testMatchesWithParameters_whenShouldHaveAssociatedRefreshTokenYES_AndAccountSignedOut_shouldReturnNO
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionary] mutableCopy];
    
    NSDictionary *signinStatusDict = @{[[NSBundle mainBundle] bundleIdentifier]: @"SignedOut"};
    jsonDictionary[@"signInStatus"] = signinStatusDict;
    
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [MSALAccountEnumerationParameters new];
    params.returnOnlySignedInAccounts = YES;
    BOOL result = [account matchesParameters:params];
    XCTAssertFalse(result);
}

- (void)testMatchesWithParameters_whenNilParameters_shouldReturnYES
{
    NSDictionary *jsonDictionary = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionary];
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = nil;
    BOOL result = [account matchesParameters:params];
    XCTAssertTrue(result);
}

- (void)testMatchesWithParameters_whenIdentifierNonNil_andMatchingIdentifier_shouldReturnYES
{
    NSDictionary *jsonDictionary = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:@"accountId" objectId:@"oid" tenantId:@"utid" username:nil];
    
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:@"oid.utid"];
    params.returnOnlySignedInAccounts = NO;
    BOOL result = [account matchesParameters:params];
    XCTAssertTrue(result);
}

- (void)testMatchesWithParameters_whenIdentifierAndUsernameSet_andMatchingAllOptions_shouldReturnYES
{
    NSDictionary *jsonDictionary = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:@"accountId" objectId:@"oid" tenantId:@"utid" username:nil];
    
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:@"oid.utid" username:@"user@contoso.com"];
    params.returnOnlySignedInAccounts = NO;
    BOOL result = [account matchesParameters:params];
    XCTAssertTrue(result);
}

- (void)testMatchesWithParameters_whenAllMatchignOptionsSet_andMatchingAllOptions_butDifferentCase_shouldReturnYES
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:@"accountId" objectId:@"oid" tenantId:@"utid" username:nil] mutableCopy];
    NSDictionary *signinStatusDict = @{[[NSBundle mainBundle] bundleIdentifier]: @"SignedIn"};
    jsonDictionary[@"signInStatus"] = signinStatusDict;
    
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:@"oID.UTid" username:@"USER@contoso.COM"];
    params.returnOnlySignedInAccounts = YES;
    BOOL result = [account matchesParameters:params];
    XCTAssertTrue(result);
}

- (void)testMatchesWithParameters_whenNoAppSignedIn_andDontReturnOnlySignedInAccounts_shouldReturnYES
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:@"accountId" objectId:@"oid" tenantId:@"utid" username:nil] mutableCopy];
    jsonDictionary[@"signInStatus"] = @{};
    
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:@"oID.UTid" username:@"USER@contoso.COM"];
    params.returnOnlySignedInAccounts = NO;
    BOOL result = [account matchesParameters:params];
    XCTAssertTrue(result);
}

- (void)testMatchesWithParameters_whenAllAppsSignedOut_andDontReturnOnlySignedInAccounts_shouldReturnNO
{
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:@"accountId" objectId:@"oid" tenantId:@"utid" username:nil] mutableCopy];
    NSDictionary *signinStatusDict = @{@"com.microsoft.app1": @"SignedOut", @"com.microsoft.app2": @"SignedOut"};
    jsonDictionary[@"signInStatus"] = signinStatusDict;
    
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:@"oID.UTid" username:@"USER@contoso.COM"];
    params.returnOnlySignedInAccounts = NO;
    BOOL result = [account matchesParameters:params];
    XCTAssertFalse(result);
}

- (void)testMatchesWithParameters_whenTenantProfileIdentifierNonNil_andTenantProfileIdentifierSame_shouldReturnYES
{
    NSDictionary *jsonDictionary = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:@"accountId" objectId:@"myoid" tenantId:@"utid" username:nil];
    
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithTenantProfileIdentifier:@"myoid"];
    params.returnOnlySignedInAccounts = NO;
    BOOL result = [account matchesParameters:params];
    XCTAssertTrue(result);
}

- (void)testMatchesWithParamaters_whenUsernameNonNil_andUsernameDifferent_shouldReturnNO
{
    NSDictionary *jsonDictionary = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:@"accountId" objectId:@"myoid" tenantId:@"utid" username:nil];
    
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:nil username:@"user2@contoso.com"];
    params.returnOnlySignedInAccounts = NO;
    BOOL result = [account matchesParameters:params];
    XCTAssertFalse(result);
}

- (void)testMatchesWithParameters_whenTenantProfileIdentifierNonNil_andTenantProfileIdentifierDifferent_shouldReturnNO
{
    NSDictionary *jsonDictionary = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:@"accountId" objectId:@"myoid" tenantId:@"utid" username:nil];
    
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithTenantProfileIdentifier:@"myoid2"];
    params.returnOnlySignedInAccounts = NO;
    BOOL result = [account matchesParameters:params];
    XCTAssertFalse(result);
}

- (void)testMatchesWithParameters_whenIdentifierNonNil_andIdentifierDifferent_shouldReturnNO
{
    NSDictionary *jsonDictionary = [MSALLegacySharedAccountTestUtil sampleADALJSONDictionaryWithAccountId:@"accountId" objectId:@"oid" tenantId:@"utid" username:nil];
    
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:@"oid.utid2"];
    params.returnOnlySignedInAccounts = NO;
    BOOL result = [account matchesParameters:params];
    XCTAssertFalse(result);
}

#pragma mark - Update

- (void)testUpdateWithMSALAccount_whenUsernameAndSigninStatusChanged_shouldUpdateUsername
{
    NSString *appIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSMutableDictionary *jsonDictionary = [[MSALLegacySharedAccountTestUtil sampleADALJSONDictionary] mutableCopy];
    NSDictionary *signinStatusDict = @{appIdentifier : @"SignedOut"};
    jsonDictionary[@"signInStatus"] = signinStatusDict;
    jsonDictionary[@"username"] = @"old@contoso.old.com";
    
    MSALLegacySharedADALAccount *account = [[MSALLegacySharedADALAccount alloc] initWithJSONDictionary:jsonDictionary error:nil];
    
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
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
    
}

@end
