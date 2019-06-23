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
#import "MSALExternalAccountHandler.h"
#import "MSALOauth2Provider.h"
#import "MSALTestConstants.h"
#import "MSALAccount+Internal.h"
#import "MSALAccountId+Internal.h"
#import <MSAL/MSAL.h>

@interface MSALTestExternalAccountsProvider : NSObject<MSALExternalAccountProviding>

@property (nonatomic) BOOL accountOperationResult;
@property (nonatomic) NSError *accountOperationError;
@property (nonatomic) NSArray *resultAccounts;

@property (nonatomic) NSInteger updateAccountInvokedCount;
@property (nonatomic) NSInteger removeAccountInvokedCount;
@property (nonatomic) NSInteger readAccountsInvokedCount;

@end

@implementation MSALTestExternalAccountsProvider

- (BOOL)updateAccount:(id<MSALAccount>)account
        idTokenClaims:(NSDictionary *)idTokenClaims
                error:(NSError * _Nullable * _Nullable)error
{
    self.updateAccountInvokedCount++;
    
    if (self.accountOperationError && error)
    {
        *error = self.accountOperationError;
    }
    
    return self.accountOperationResult;
}

- (BOOL)removeAccount:(id<MSALAccount>)account
       tenantProfiles:(nullable NSArray<MSALTenantProfile *> *)tenantProfiles
                error:(NSError * _Nullable * _Nullable)error
{
    self.removeAccountInvokedCount++;
    
    if (self.accountOperationError && error)
    {
        *error = self.accountOperationError;
    }
    
    return self.accountOperationResult;
}

- (nullable NSArray<id<MSALAccount>> *)accountsWithParameters:(MSALAccountEnumerationParameters *)parameters
                                                        error:(NSError * _Nullable * _Nullable)error
{
    self.readAccountsInvokedCount++;
    
    if (self.accountOperationError && error)
    {
        *error = self.accountOperationError;
    }
    
    return self.resultAccounts;
}

@end

@interface MSALExternalAccountHandlerTests : XCTestCase

@end

@implementation MSALExternalAccountHandlerTests

#pragma mark - Init

- (MSALOauth2Provider *)testOauth2Provider
{
    return [[MSALOauth2Provider alloc] initWithClientId:UNIT_TEST_CLIENT_ID tokenCache:nil accountMetadataCache:nil];
}

- (void)testInitWithExternalAccountsProvider_whenNilProviders_shouldReturnNilResultAndNilError
{
    NSArray *externalAccountProviders = nil;
    NSError *error = nil;
    MSALExternalAccountHandler *handler = [[MSALExternalAccountHandler alloc] initWithExternalAccountProviders:externalAccountProviders oauth2Provider:[self testOauth2Provider] error:&error];
    XCTAssertNil(handler);
    XCTAssertNil(error);
}

- (void)testInitWithExternalAccountsProvider_whenEmptyProvidersArray_shouldReturnNilResultAndNilError
{
    NSArray *externalAccountProviders = @[];
    NSError *error = nil;
    MSALExternalAccountHandler *handler = [[MSALExternalAccountHandler alloc] initWithExternalAccountProviders:externalAccountProviders oauth2Provider:[self testOauth2Provider] error:&error];
    XCTAssertNil(handler);
    XCTAssertNil(error);
}

- (void)testInitWithExternalAccountsProvider_whenNoOauth2Provider_shouldReturnNilResultAndNonNilError
{
    NSArray *externalAccountProviders = @[[MSALTestExternalAccountsProvider new]];
    MSALOauth2Provider *oauth2Provider = nil;
    NSError *error = nil;
    MSALExternalAccountHandler *handler = [[MSALExternalAccountHandler alloc] initWithExternalAccountProviders:externalAccountProviders oauth2Provider:oauth2Provider error:&error];
    XCTAssertNil(handler);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInternal);
}

- (void)testInitWithExternalAccountsProvider_whenAllParametersProvided_shouldReturnNotNilResultAndNilError
{
    NSArray *externalAccountProviders = @[[MSALTestExternalAccountsProvider new]];
    MSALOauth2Provider *oauth2Provider = [self testOauth2Provider];
    NSError *error = nil;
    MSALExternalAccountHandler *handler = [[MSALExternalAccountHandler alloc] initWithExternalAccountProviders:externalAccountProviders oauth2Provider:oauth2Provider error:&error];
    XCTAssertNotNil(handler);
    XCTAssertNil(error);
}

#pragma mark - allExternalAccountsWithParameters

- (void)testAllExternalAccountsWithParameters_whenFailedToReadExternalAccounts_shouldReturnError
{
    MSALTestExternalAccountsProvider *testProvider = [MSALTestExternalAccountsProvider new];
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected account reading error", nil, nil, nil, [NSUUID UUID], @{@"extra":@"extra1"});
    testProvider.accountOperationError = error;
    
    NSArray *externalAccountProviders = @[testProvider];
    MSALOauth2Provider *oauth2Provider = [self testOauth2Provider];
    MSALExternalAccountHandler *handler = [[MSALExternalAccountHandler alloc] initWithExternalAccountProviders:externalAccountProviders
                                                                                                oauth2Provider:oauth2Provider
                                                                                                         error:nil];
    
    MSALAccountEnumerationParameters *parameters = [MSALAccountEnumerationParameters new];
    NSError *accountsError = nil;
    NSArray *results = [handler allExternalAccountsWithParameters:parameters error:&accountsError];
    XCTAssertNil(results);
    XCTAssertNotNil(accountsError);
    
    XCTAssertEqual(accountsError.code, MSALErrorInternal);
    XCTAssertEqualObjects(accountsError.userInfo[MSALErrorDescriptionKey], @"Unexpected account reading error");
    XCTAssertEqual(testProvider.readAccountsInvokedCount, 1);
}

- (void)testAllExternalAccountsWithParameters_whenAccountsFromSameProvider_shouldReturnAll
{
    MSALTestExternalAccountsProvider *testProvider = [MSALTestExternalAccountsProvider new];
    MSALAccountId *homeAccountId1 = [[MSALAccountId alloc] initWithAccountIdentifier:@"id1" objectId:@"oid1" tenantId:@"tid1"];
    MSALAccount *account1 = [[MSALAccount alloc] initWithUsername:@"username" homeAccountId:homeAccountId1 environment:@"contoso.com" tenantProfiles:nil];
    MSALAccountId *homeAccountId2 = [[MSALAccountId alloc] initWithAccountIdentifier:@"id2" objectId:@"oid2" tenantId:@"tid2"];
    MSALAccount *account2 = [[MSALAccount alloc] initWithUsername:@"username2" homeAccountId:homeAccountId2 environment:@"contoso.com2" tenantProfiles:nil];
    testProvider.resultAccounts = @[account1, account2];
    
    NSArray *externalAccountProviders = @[testProvider];
    MSALOauth2Provider *oauth2Provider = [self testOauth2Provider];
    MSALExternalAccountHandler *handler = [[MSALExternalAccountHandler alloc] initWithExternalAccountProviders:externalAccountProviders
                                                                                                oauth2Provider:oauth2Provider
                                                                                                         error:nil];
    
    MSALAccountEnumerationParameters *parameters = [MSALAccountEnumerationParameters new];
    NSError *accountsError = nil;
    NSArray *results = [handler allExternalAccountsWithParameters:parameters error:&accountsError];
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
    MSALAccount *firstAccount = results[0];
    XCTAssertEqualObjects(firstAccount.username, @"username");
    XCTAssertEqualObjects(firstAccount.environment, @"contoso.com");
    XCTAssertEqualObjects(firstAccount.identifier, @"id1");
    
    MSALAccount *secondAccount = results[1];
    XCTAssertEqualObjects(secondAccount.username, @"username2");
    XCTAssertEqualObjects(secondAccount.environment, @"contoso.com2");
    XCTAssertEqualObjects(secondAccount.identifier, @"id2");
    
    XCTAssertNil(accountsError);
}

- (void)testAllExternalAccountsWithParameters_whenAccountsFromMultipleProvider_shouldReturnAll
{
    MSALAccountId *homeAccountId1 = [[MSALAccountId alloc] initWithAccountIdentifier:@"id1" objectId:@"oid1" tenantId:@"tid1"];
    MSALAccount *account1 = [[MSALAccount alloc] initWithUsername:@"username" homeAccountId:homeAccountId1 environment:@"contoso.com" tenantProfiles:nil];
    MSALAccountId *homeAccountId2 = [[MSALAccountId alloc] initWithAccountIdentifier:@"id2" objectId:@"oid2" tenantId:@"tid2"];
    MSALAccount *account2 = [[MSALAccount alloc] initWithUsername:@"username2" homeAccountId:homeAccountId2 environment:@"contoso.com2" tenantProfiles:nil];
    
    MSALTestExternalAccountsProvider *testProvider1 = [MSALTestExternalAccountsProvider new];
    testProvider1.resultAccounts = @[account1];
    
    MSALTestExternalAccountsProvider *testProvider2 = [MSALTestExternalAccountsProvider new];
    testProvider2.resultAccounts = @[account2];
    
    MSALTestExternalAccountsProvider *testProvider3 = [MSALTestExternalAccountsProvider new];
    testProvider3.resultAccounts = nil;
    
    NSArray *externalAccountProviders = @[testProvider1, testProvider2, testProvider3];
    MSALOauth2Provider *oauth2Provider = [self testOauth2Provider];
    MSALExternalAccountHandler *handler = [[MSALExternalAccountHandler alloc] initWithExternalAccountProviders:externalAccountProviders
                                                                                                oauth2Provider:oauth2Provider
                                                                                                         error:nil];
    
    MSALAccountEnumerationParameters *parameters = [MSALAccountEnumerationParameters new];
    NSError *accountsError = nil;
    NSArray *results = [handler allExternalAccountsWithParameters:parameters error:&accountsError];
    XCTAssertNotNil(results);
    XCTAssertEqual([results count], 2);
    MSALAccount *firstAccount = results[0];
    XCTAssertEqualObjects(firstAccount.username, @"username");
    XCTAssertEqualObjects(firstAccount.environment, @"contoso.com");
    XCTAssertEqualObjects(firstAccount.identifier, @"id1");
    
    MSALAccount *secondAccount = results[1];
    XCTAssertEqualObjects(secondAccount.username, @"username2");
    XCTAssertEqualObjects(secondAccount.environment, @"contoso.com2");
    XCTAssertEqualObjects(secondAccount.identifier, @"id2");
    
    XCTAssertNil(accountsError);
}

#pragma mark - updateWithResult

- (void)testUpdateWithResult_whenNilResult_shouldReturnNoAndFillError
{
    MSALTestExternalAccountsProvider *testProvider = [MSALTestExternalAccountsProvider new];
    NSArray *externalAccountProviders = @[testProvider];
    MSALOauth2Provider *oauth2Provider = [self testOauth2Provider];
    MSALExternalAccountHandler *handler = [[MSALExternalAccountHandler alloc] initWithExternalAccountProviders:externalAccountProviders
                                                                                                oauth2Provider:oauth2Provider
                                                                                                         error:nil];
    
    MSALResult *nilResult = nil;
    NSError *updateError = nil;
    BOOL result = [handler updateWithResult:nilResult error:&updateError];
    XCTAssertFalse(result);
    XCTAssertNotNil(updateError);
    XCTAssertEqual(updateError.code, MSALErrorInternal);
    XCTAssertEqual(testProvider.updateAccountInvokedCount, 0);
}

- (void)testUpdateWithResult_whenFailedToUpdate_shouldReturnNoAndFillError
{
    MSALTestExternalAccountsProvider *testProvider = [MSALTestExternalAccountsProvider new];
    testProvider.accountOperationResult = NO;
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected update error", nil, nil, nil, [NSUUID UUID], @{@"extra":@"extra1"});
    testProvider.accountOperationError = error;
    
    NSArray *externalAccountProviders = @[testProvider];
    MSALOauth2Provider *oauth2Provider = [self testOauth2Provider];
    MSALExternalAccountHandler *handler = [[MSALExternalAccountHandler alloc] initWithExternalAccountProviders:externalAccountProviders
                                                                                                oauth2Provider:oauth2Provider
                                                                                                         error:nil];
    
    MSALResult *result = [MSALResult new];
    NSError *updateError = nil;
    BOOL updateResult = [handler updateWithResult:result error:&updateError];
    XCTAssertFalse(updateResult);
    XCTAssertNotNil(updateError);
    
    XCTAssertEqual(updateError.code, MSALErrorInternal);
    XCTAssertEqualObjects(updateError.userInfo[MSALErrorDescriptionKey], @"Unexpected update error");
    XCTAssertEqual(testProvider.updateAccountInvokedCount, 1);
}

- (void)testUpdateWithResult_whenUpdateSucceeded_shouldReturnYesAndNilError
{
    MSALTestExternalAccountsProvider *testProvider = [MSALTestExternalAccountsProvider new];
    testProvider.accountOperationResult = YES;
    
    NSArray *externalAccountProviders = @[testProvider];
    MSALOauth2Provider *oauth2Provider = [self testOauth2Provider];
    MSALExternalAccountHandler *handler = [[MSALExternalAccountHandler alloc] initWithExternalAccountProviders:externalAccountProviders
                                                                                                oauth2Provider:oauth2Provider
                                                                                                         error:nil];
    
    MSALResult *result = [MSALResult new];
    NSError *updateError = nil;
    BOOL updateResult = [handler updateWithResult:result error:&updateError];
    XCTAssertTrue(updateResult);
    XCTAssertNil(updateError);
    XCTAssertEqual(testProvider.updateAccountInvokedCount, 1);
}

#pragma mark - removeAccount

- (void)testRemoveAccount_whenNilAccount_shouldReturnNoAndFillError
{
    MSALTestExternalAccountsProvider *testProvider = [MSALTestExternalAccountsProvider new];
    NSArray *externalAccountProviders = @[testProvider];
    MSALOauth2Provider *oauth2Provider = [self testOauth2Provider];
    MSALExternalAccountHandler *handler = [[MSALExternalAccountHandler alloc] initWithExternalAccountProviders:externalAccountProviders
                                                                                                oauth2Provider:oauth2Provider
                                                                                                         error:nil];
    
    MSALAccount *nilAccount = nil;
    NSError *removeError = nil;
    BOOL result = [handler removeAccount:nilAccount error:&removeError];
    XCTAssertFalse(result);
    XCTAssertNotNil(removeError);
    XCTAssertEqual(removeError.code, MSALErrorInternal);
    XCTAssertEqual(testProvider.removeAccountInvokedCount, 0);
}

- (void)testRemoveAccount_whenFailedToRemove_shouldReturnNoAndFillError
{
    MSALTestExternalAccountsProvider *testProvider = [MSALTestExternalAccountsProvider new];
    testProvider.accountOperationResult = NO;
    NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected removal error", nil, nil, nil, [NSUUID UUID], @{@"extra":@"extra1"});
    testProvider.accountOperationError = error;
    
    NSArray *externalAccountProviders = @[testProvider];
    MSALOauth2Provider *oauth2Provider = [self testOauth2Provider];
    MSALExternalAccountHandler *handler = [[MSALExternalAccountHandler alloc] initWithExternalAccountProviders:externalAccountProviders
                                                                                                oauth2Provider:oauth2Provider
                                                                                                         error:nil];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"username" homeAccountId:nil environment:@"login.microsoftonline.com" tenantProfiles:nil];
    NSError *removeError = nil;
    BOOL result = [handler removeAccount:account error:&removeError];
    XCTAssertFalse(result);
    XCTAssertNotNil(removeError);
    XCTAssertEqual(removeError.code, MSALErrorInternal);
    XCTAssertEqualObjects(removeError.userInfo[MSALErrorDescriptionKey], @"Unexpected removal error");
    XCTAssertEqual(testProvider.removeAccountInvokedCount, 1);
}

- (void)testRemoveAccount_whenRemovalSucceeded_shouldReturnYesAndNilError
{
    MSALTestExternalAccountsProvider *testProvider = [MSALTestExternalAccountsProvider new];
    testProvider.accountOperationResult = YES;
    
    NSArray *externalAccountProviders = @[testProvider];
    MSALOauth2Provider *oauth2Provider = [self testOauth2Provider];
    MSALExternalAccountHandler *handler = [[MSALExternalAccountHandler alloc] initWithExternalAccountProviders:externalAccountProviders
                                                                                                oauth2Provider:oauth2Provider
                                                                                                         error:nil];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"username" homeAccountId:nil environment:@"login.microsoftonline.com" tenantProfiles:nil];
    NSError *removeError = nil;
    BOOL result = [handler removeAccount:account error:&removeError];
    XCTAssertTrue(result);
    XCTAssertNil(removeError);
    XCTAssertEqual(testProvider.removeAccountInvokedCount, 1);
}

@end
