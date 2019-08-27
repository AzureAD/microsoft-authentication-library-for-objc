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
#import "NSString+MSALTestUtil.h"
#import "MSALTestConstants.h"
#import <MSAL/MSAL.h>
#import "MSIDTestSwizzle.h"
#import "MSIDTokenResult.h"
#import "MSIDLocalInteractiveController.h"
#import "MSIDAccount.h"
#import "MSIDAccountIdentifier.h"
#import "MSALMockExternalAccountHandler.h"
#import "MSIDAccessToken.h"
#import "MSIDAADAuthority.h"
#import "MSIDSilentController.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSALAccountId+Internal.h"
#import "MSALAccount+Internal.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSALTestBundle.h"
#import "MSALOauth2Provider.h"
#import "XCTestCase+HelperMethods.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface MSALPublicClientApplicationAccountUpdateTests : XCTestCase

@end

@implementation MSALPublicClientApplicationAccountUpdateTests

#pragma mark - Setup

- (void)setUp
{
    [super setUp];
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
}

#pragma mark - Tests

- (void)testAcquireToken_whenSuccessfulResponse_shouldUpdateExternalAccount
{
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID error:&error];
    MSALMockExternalAccountHandler *mockExternalAccountHandler = [MSALMockExternalAccountHandler new];
    application.externalAccountHandler = mockExternalAccountHandler;
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         completionBlock([self testTokenResult], nil);
     }];
    
#if TARGET_OS_IPHONE
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
#endif
    
    __auto_type parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"fakescope1", @"fakescope2"]];
#if TARGET_OS_IPHONE
    parameters.parentViewController = [self.class sharedViewControllerStub];
#endif
    parameters.loginHint = @"fakeuser@contoso.com";
    
    [application acquireTokenWithParameters:parameters
                            completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNotNil(result);
         XCTAssertNil(error);
         XCTAssertEqual(mockExternalAccountHandler.updateInvokedCount, 1);
     }];
}

- (void)testAcquireTokenSilent_whenSuccessfulResponse_shouldUpdateExternalAccount
{
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID error:&error];
    MSALMockExternalAccountHandler *mockExternalAccountHandler = [MSALMockExternalAccountHandler new];
    application.externalAccountHandler = mockExternalAccountHandler;
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDSilentController class]
                              block:(id)^(MSIDSilentController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDSilentController class]]);
         
         completionBlock([self testTokenResult], nil);
     }];
    
    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:[self testMSALAccount]
                             completionBlock:^(MSALResult * _Nullable result, NSError * _Nullable error) {
                                 
                                 XCTAssertNotNil(result);
                                 XCTAssertNil(error);
                                 XCTAssertEqual(mockExternalAccountHandler.updateInvokedCount, 1);
                             }];
}

- (void)testRemoveAccount_whenAccountExistsInExternalCache_shouldCallRemoveAccountFromExternalCache
{
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID error:&error];
    MSALMockExternalAccountHandler *mockExternalAccountHandler = [MSALMockExternalAccountHandler new];
    mockExternalAccountHandler.accountOperationResult = YES;
    application.externalAccountHandler = mockExternalAccountHandler;
    application.msalOauth2Provider = [[MSALOauth2Provider alloc] initWithClientId:UNIT_TEST_CLIENT_ID tokenCache:nil accountMetadataCache:nil];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    NSError *removalError = nil;
    BOOL result = [application removeAccount:[self testMSALAccount] error:&removalError];
    XCTAssertTrue(result);
    XCTAssertNil(removalError);
    XCTAssertEqual(mockExternalAccountHandler.removeAccountCount, 1);
}

#pragma mark - Helpers

- (MSIDTokenResult *)testTokenResult
{
    MSIDTokenResult *tokenResult = [MSIDTokenResult new];
    MSIDAccount *account = [MSIDAccount new];
    account.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"fakeuser@contoso.com" homeAccountId:@"uid.utid"];
    account.username = @"fakeuser@contoso.com";
    account.environment = @"login.microsoftonline.com";
    account.realm = @"contoso.com";
    tokenResult.account = account;
    tokenResult.accessToken = [MSIDAccessToken new];
    tokenResult.accessToken.accessToken = @"access.token";
    tokenResult.authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] rawTenant:@"tenant" context:nil error:nil];
    tokenResult.rawIdToken = [MSIDTestIdTokenUtil defaultV2IdToken];
    return tokenResult;
}

- (MSALAccount *)testMSALAccount
{
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"uid.utid" objectId:@"uid" tenantId:@"utid"];
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:nil homeAccountId:accountId environment:@"login.microsoftonline.com" tenantProfiles:nil];
    return account;
}

@end

#pragma clang diagnostic pop
