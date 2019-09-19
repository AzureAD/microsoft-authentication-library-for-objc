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

#import "MSALTestCase.h"

#import "MSALTestBundle.h"
#import "MSALTestConstants.h"
#import "MSIDTestSwizzle.h"
#import "MSIDTestURLSession+MSAL.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSIDTestURLSession.h"
#import "MSIDTestURLResponse+MSAL.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSALAccountId.h"
#import "MSIDBaseToken.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDB2CAuthority.h"
#import "MSIDAADNetworkConfiguration.h"
#import "NSString+MSALTestUtil.h"

#import "MSIDWebviewAuthorization.h"
#import "MSIDWebAADAuthResponse.h"

#import "MSALResult.h"
#import "MSALAccount.h"
#import "MSALInteractiveTokenParameters.h"
#import "MSALWebviewParameters.h"
#import "XCTestCase+HelperMethods.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface MSALB2CPolicyTests : MSALTestCase

@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCacheAccessor;

@end

@implementation MSALB2CPolicyTests

- (void)setUp
{
    [super setUp];

    [MSIDKeychainTokenCache reset];

    self.tokenCacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache otherCacheAccessors:nil];

    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = @"v2.0";
    [self.tokenCacheAccessor clearWithContext:nil error:nil];
}

- (void)tearDown
{
    [super tearDown];

    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = nil;
    [self.tokenCacheAccessor clearWithContext:nil error:nil];
}

- (void)setupURLSessionWithB2CAuthority:(MSALAuthority *)authority policy:(NSString *)policy
{
    NSString *query = [NSString stringWithFormat:@"p=%@", policy];

    MSIDTestURLResponse *oidcResponse =
    [MSIDTestURLResponse oidcResponseForAuthority:authority.msidAuthority.url.absoluteString
                                      responseUrl:@"https://login.microsoftonline.com/contosob2c"
                                            query:query];

    NSString *uid = [NSString stringWithFormat:@"1-%@", policy];

    // User identifier should be uid-policy
    MSIDTestURLResponse *tokenResponse =
    [MSIDTestURLResponse authCodeResponse:@"iamauthcode"
                                authority:@"https://login.microsoftonline.com/contosob2c"
                                    query:query
                                   scopes:[NSOrderedSet orderedSetWithArray:@[@"fakeb2cscopes", @"openid", @"profile", @"offline_access"]]
                               clientInfo:@{ @"uid" : uid, @"utid" : [MSIDTestIdTokenUtil defaultTenantId]}
                                   claims:nil];

    [MSIDTestURLSession addResponses:@[oidcResponse, tokenResponse]];
}


/*
    This is an integraton test to verify that two acquireToken calls with two different B2C policies
    result in two fully functional users that can be retrieved and used.
 */

- (void)testAcquireToken_whenMultipleB2CPolicies_shouldHaveMultipleUsers
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    // Setup acquireToken with first policy (b2c_1_policy)
    __auto_type firstAuthority = [@"https://login.microsoftonline.com/tfp/contosob2c/b2c_1_policy" msalAuthority];
    [self setupURLSessionWithB2CAuthority:firstAuthority policy:@"b2c_1_policy"];

    [MSIDTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(id obj, MSIDWebviewConfiguration *configuration, MSIDOauth2Factory *oauth2Factory, WKWebView *webview, id<MSIDRequestContext>context, MSIDWebviewAuthCompletionHandler completionHandler)
     {
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=iamauthcode"];
         
         MSIDWebAADAuthResponse *oauthResponse = [[MSIDWebAADAuthResponse alloc] initWithURL:[NSURL URLWithString:responseString]
                                                                                    context:nil error:nil];    
         completionHandler(oauthResponse, nil);
     }];

    NSError *error = nil;

    // Create application object with the first policy as authority
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:firstAuthority
                                                    error:&error];
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire Token."];
    
    UIViewController *parentController = nil;
    MSALWebviewParameters *webParameters = [[MSALWebviewParameters alloc] initWithParentViewController:parentController];
    webParameters.webviewType = MSALWebviewTypeWKWebView;
    
    __auto_type parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"fakeb2cscopes"] webviewParameters:webParameters];
    parameters.webviewParameters.webviewType = MSALWebviewTypeWKWebView;
    parameters.parentViewController = [self.class sharedViewControllerStub];

    [application acquireTokenWithParameters:parameters
                            completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(error);
         XCTAssertNotNil(result);

         NSString *userIdentifier = [NSString stringWithFormat:@"1-b2c_1_policy.%@", [MSIDTestIdTokenUtil defaultTenantId]];
         XCTAssertEqualObjects(result.account.identifier, userIdentifier);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    // Now acquiretoken call with second policy (b2c_2_policy)
    __auto_type secondAuthority = [@"https://login.microsoftonline.com/tfp/contosob2c/b2c_2_policy" msalAuthority];

    // Override oidc and token responses for the second policy
    [self setupURLSessionWithB2CAuthority:secondAuthority policy:@"b2c_2_policy"];

    parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"fakeb2cscopes"]];
    parameters.webviewParameters.webviewType = MSALWebviewTypeWKWebView;
    parameters.parentViewController = [self.class sharedViewControllerStub];
    parameters.promptType = MSALPromptTypeDefault;
    parameters.authority = secondAuthority;
    
    // Use an authority with a different policy in the second acquiretoken call
    expectation = [self expectationWithDescription:@"Acquire Token."];
    [application acquireTokenWithParameters:parameters
                            completionBlock:^(MSALResult *result, NSError *error)
    {

                           XCTAssertNil(error);
                           XCTAssertNotNil(result);

                           NSString *userIdentifier = [NSString stringWithFormat:@"1-b2c_2_policy.%@", [MSIDTestIdTokenUtil defaultTenantId]];
                           XCTAssertEqualObjects(result.account.identifier, userIdentifier);
                           [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    __auto_type allTokens = [self.tokenCacheAccessor allTokensWithContext:nil error:nil];

    NSMutableArray *ats = [NSMutableArray array];
    NSMutableArray *rts = [NSMutableArray array];

    for (MSIDBaseToken *token in allTokens)
    {
        if (token.credentialType == MSIDAccessTokenType)
        {
            [ats addObject:token];
        }
        else if (token.credentialType == MSIDRefreshTokenType)
        {
            [rts addObject:token];
        }
    }

    // Ensure we have two different accesstokens in cache
    // and that second call doesn't overwrite first one, since policies are different
    XCTAssertEqual(ats.count, 2);
    XCTAssertEqual(rts.count, 2);
    XCTAssertEqual([[application allAccounts:nil] count], 2);
}

@end

#pragma clang diagnostic pop
