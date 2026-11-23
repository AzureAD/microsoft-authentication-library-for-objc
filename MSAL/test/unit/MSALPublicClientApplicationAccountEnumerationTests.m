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

#import "MSALTestCase.h"
#import "MSALPublicClientApplication+Internal.h"
#import "MSALPublicClientApplication+SingleAccount.h"
#import "MSALAccountsProvider.h"
#import "MSALAccount+Internal.h"
#import "MSALAccountId+Internal.h"
#import "MSALAccountEnumerationParameters.h"
#import "MSALParameters.h"
#import "MSALTestConstants.h"
#import "MSIDTestBundle.h"
#import "MSIDTestSwizzle.h"
#import "MSIDTestCacheDataSource.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDRequestParameters.h"

@interface MSALPublicClientApplicationAccountEnumerationTests : MSALTestCase

@property (nonatomic) MSALPublicClientApplication *application;
@property (nonatomic) MSALAccount *firstAccount;
@property (nonatomic) MSALAccount *secondAccount;

@end

@implementation MSALPublicClientApplicationAccountEnumerationTests

- (void)setUp
{
    [super setUp];
    [MSIDTestBundle overrideObject:@[@{@"CFBundleURLSchemes": @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME]}]
                           forKey:@"CFBundleURLTypes"];
    NSError *error = nil;
    self.application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID error:&error];
    XCTAssertNotNil(self.application);
    XCTAssertNil(error);

    MSIDTestCacheDataSource *dataSource = [MSIDTestCacheDataSource new];
    self.application.tokenCache = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    self.application.accountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
    self.firstAccount = [self accountWithIdentifier:@"first.tenant" username:@"first@example.com"];
    self.secondAccount = [self accountWithIdentifier:@"second.tenant" username:@"second@example.com"];
}

- (void)tearDown
{
    [MSIDTestSwizzle reset];
    self.application = nil;
    self.firstAccount = nil;
    self.secondAccount = nil;
    [super tearDown];
}

- (void)testDeviceAccounts_preservesParametersCompleteResultAndRequestedQueue
{
    MSALAccountEnumerationParameters *parameters =
        [[MSALAccountEnumerationParameters alloc] initWithIdentifier:@"first.tenant" username:@"first@example.com"];
    parameters.returnOnlySignedInAccounts = NO;
    dispatch_queue_t queue = dispatch_queue_create("MSALAccountEnumerationTests.completion", DISPATCH_QUEUE_SERIAL);
    const void *queueKey = &queueKey;
    dispatch_queue_set_specific(queue, queueKey, (void *)queueKey, NULL);
    parameters.completionBlockQueue = queue;
    NSArray *expected = @[self.firstAccount, self.secondAccount];
    [MSIDTestSwizzle instanceMethod:@selector(allAccountsFromDevice:requestParameters:completionBlock:)
                              class:MSALAccountsProvider.class
                              block:(id)^(id object, MSALAccountEnumerationParameters *received,
                                          MSIDRequestParameters *request, MSALAccountsCompletionBlock completion)
    {
        XCTAssertEqual(received, parameters);
        XCTAssertFalse(received.returnOnlySignedInAccounts);
        XCTAssertNotNil(request);
        completion(expected, nil);
    }];
    XCTestExpectation *completed = [self expectationWithDescription:@"device accounts"];
    completed.assertForOverFulfill = YES;
    [self.application accountsFromDeviceForParameters:parameters completionBlock:^(NSArray<MSALAccount *> *accounts, NSError *error)
    {
        XCTAssertEqual(dispatch_get_specific(queueKey), queueKey);
        XCTAssertEqualObjects(accounts, expected);
        XCTAssertEqual(accounts.count, 2);
        XCTAssertNil(error);
        [completed fulfill];
    }];
    [self waitForExpectations:@[completed] timeout:1];
}

- (void)testDeviceAccounts_convertsInteractionRequiredWithoutReturningAccounts
{
    NSError *expected = [NSError errorWithDomain:MSIDErrorDomain code:MSIDErrorInteractionRequired userInfo:nil];
    [self stubDeviceAccounts:nil error:expected];
    XCTestExpectation *completed = [self expectationWithDescription:@"device account error"];
    completed.assertForOverFulfill = YES;
    [self.application accountsFromDeviceForParameters:[MSALAccountEnumerationParameters new]
                                     completionBlock:^(NSArray<MSALAccount *> *accounts, NSError *error)
    {
        XCTAssertNil(accounts);
        XCTAssertEqualObjects(error.domain, MSALErrorDomain);
        XCTAssertEqual(error.code, MSALErrorInteractionRequired);
        [completed fulfill];
    }];
    [self waitForExpectations:@[completed] timeout:1];
}

- (void)testCurrentAccount_whenNoAccountsRemain_returnsPreviousIdentityAndClearsPrincipal
{
    MSALAccountsProvider *provider = [self provider];
    NSError *error = nil;
    BOOL stored = [provider setCurrentPrincipalAccountId:self.firstAccount.lookupAccountIdentifier
                                     accountEnvironment:self.firstAccount.environment error:&error];
    XCTAssertTrue(stored);
    XCTAssertNil(error);
    [self stubDeviceAccounts:@[] error:nil];
    XCTestExpectation *completed = [self expectationWithDescription:@"signed out account"];
    completed.assertForOverFulfill = YES;
    [self.application getCurrentAccountWithParameters:nil completionBlock:^(MSALAccount *current, MSALAccount *previous, NSError *error)
    {
        XCTAssertNil(current);
        XCTAssertEqualObjects(previous.identifier, self.firstAccount.identifier);
        XCTAssertEqualObjects(previous.username, self.firstAccount.username);
        XCTAssertNil(error);
        [completed fulfill];
    }];
    [self waitForExpectations:@[completed] timeout:1];
    error = nil;
    XCTAssertNil([provider currentPrincipalAccount:&error]);
    XCTAssertNil(error);
}

- (void)testCurrentAccount_whenOneAccountRemains_returnsAndPersistsThatExactIdentity
{
    [self stubDeviceAccounts:@[self.secondAccount] error:nil];
    XCTestExpectation *completed = [self expectationWithDescription:@"current account"];
    completed.assertForOverFulfill = YES;
    MSALParameters *parameters = [MSALParameters new];
    parameters.completionBlockQueue = dispatch_get_main_queue();
    [self.application getCurrentAccountWithParameters:parameters
                                     completionBlock:^(MSALAccount *current, MSALAccount *previous, NSError *error)
    {
        XCTAssertEqual(current, self.secondAccount);
        XCTAssertNil(previous);
        XCTAssertNil(error);
        XCTAssertTrue(NSThread.isMainThread);
        [completed fulfill];
    }];
    [self waitForExpectations:@[completed] timeout:1];
    NSError *error = nil;
    MSALAccount *stored = [[self provider] currentPrincipalAccount:&error];
    XCTAssertNotNil(stored);
    XCTAssertEqualObjects(stored.identifier, self.secondAccount.identifier);
    XCTAssertEqualObjects(stored.username, self.secondAccount.username);
    XCTAssertNil(error);
}

- (void)testCurrentAccount_whenMultipleAccountsRemain_failsWithoutChoosingOrPersistingOne
{
    [self stubDeviceAccounts:@[self.firstAccount, self.secondAccount] error:nil];
    XCTestExpectation *completed = [self expectationWithDescription:@"ambiguous current account"];
    completed.assertForOverFulfill = YES;
    [self.application getCurrentAccountWithParameters:nil completionBlock:^(MSALAccount *current, MSALAccount *previous, NSError *error)
    {
        XCTAssertNil(current);
        XCTAssertNil(previous);
        XCTAssertEqualObjects(error.domain, MSALErrorDomain);
        XCTAssertEqual(error.code, MSALErrorInternal);
        XCTAssertEqualObjects(error.userInfo[MSALInternalErrorCodeKey], @(MSALInternalErrorAmbiguousAccount));
        [completed fulfill];
    }];
    [self waitForExpectations:@[completed] timeout:1];
    NSError *error = nil;
    XCTAssertNil([[self provider] currentPrincipalAccount:&error]);
    XCTAssertNil(error);
}

- (void)testCurrentAccount_whenDeviceEnumerationFails_doesNotReplacePreviousPrincipal
{
    MSALAccountsProvider *provider = [self provider];
    NSError *error = nil;
    BOOL stored = [provider setCurrentPrincipalAccountId:self.firstAccount.lookupAccountIdentifier
                                     accountEnvironment:self.firstAccount.environment error:&error];
    XCTAssertTrue(stored);
    XCTAssertNil(error);
    [self stubDeviceAccounts:nil error:[NSError errorWithDomain:MSIDErrorDomain code:MSIDErrorInteractionRequired userInfo:nil]];
    XCTestExpectation *completed = [self expectationWithDescription:@"current account error"];
    completed.assertForOverFulfill = YES;
    [self.application getCurrentAccountWithParameters:nil completionBlock:^(MSALAccount *current, MSALAccount *previous, NSError *error)
    {
        XCTAssertNil(current);
        XCTAssertNil(previous);
        XCTAssertEqualObjects(error.domain, MSALErrorDomain);
        XCTAssertEqual(error.code, MSALErrorInteractionRequired);
        [completed fulfill];
    }];
    [self waitForExpectations:@[completed] timeout:1];
    error = nil;
    MSALAccount *principal = [provider currentPrincipalAccount:&error];
    XCTAssertEqualObjects(principal.identifier, self.firstAccount.identifier);
    XCTAssertNil(error);
}

- (MSALAccount *)accountWithIdentifier:(NSString *)identifier username:(NSString *)username
{
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:identifier objectId:nil tenantId:nil];
    return [[MSALAccount alloc] initWithUsername:username homeAccountId:accountId
                                    environment:@"login.microsoftonline.com" tenantProfiles:nil];
}

- (MSALAccountsProvider *)provider
{
    return [[MSALAccountsProvider alloc] initWithTokenCache:self.application.tokenCache
                                     accountMetadataCache:self.application.accountMetadataCache
                                                 clientId:UNIT_TEST_CLIENT_ID];
}

- (void)stubDeviceAccounts:(NSArray<MSALAccount *> *)accounts error:(NSError *)error
{
    [MSIDTestSwizzle instanceMethod:@selector(allAccountsFromDevice:requestParameters:completionBlock:)
                              class:MSALAccountsProvider.class
                              block:(id)^(id object, MSALAccountEnumerationParameters *parameters,
                                          MSIDRequestParameters *request, MSALAccountsCompletionBlock completion)
    {
        completion(accounts, error);
    }];
}

@end
