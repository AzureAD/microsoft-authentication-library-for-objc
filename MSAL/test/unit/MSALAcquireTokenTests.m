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
#import "MSALTestSwizzle.h"
#import "MSIDTestURLSession+MSAL.h"

#import "NSURL+MSIDExtensions.h"
#import "MSIDDeviceId.h"
#import "MSIDTestURLResponse.h"

#import "MSALPublicClientApplication+Internal.h"
#import "MSIDTestURLSession+MSAL.h"
#import "MSIDTestURLSession.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDTestURLResponse+MSAL.h"
#import "MSIDAccessToken.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccount.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDTestConfiguration.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestIdentifiers.h"
#import "MSALAccount+Internal.h"
#import "MSIDClientInfo.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSALIdToken.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#import "MSIDMacTokenCache.h"
#import "MSIDAADV2Oauth2Factory.h"

#import "MSIDWebviewAuthorization.h"
#import "MSIDWebAADAuthResponse.h"

@interface MSALAcquireTokenTests : MSALTestCase

@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;

@end

@implementation MSALAcquireTokenTests

- (void)setUp
{
    [super setUp];
    
    id<MSIDTokenCacheDataSource> dataSource;
#if TARGET_OS_IPHONE
    dataSource = MSIDKeychainTokenCache.defaultKeychainCache;
#else
    dataSource = MSIDMacTokenCache.defaultCache;
#endif
    self.tokenCache = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil factory:[MSIDAADV2Oauth2Factory new]];
    
    [self.tokenCache clearWithContext:nil error:nil];
}

- (void)tearDown
{
    [super tearDown];
}


- (void)testAcquireTokenInteractive_whenB2CAuthorityWithQP_shouldRetainQP
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSString *authority = @"https://login.microsoftonline.com/tfp/contosob2c/b2c_1_policy";
    MSIDTestURLResponse *oidcResponse =
    [MSIDTestURLResponse oidcResponseForAuthority:authority
                                      responseUrl:@"https://login.microsoftonline.com/contosob2c"
                                            query:@"p=b2c_1_policy"];
    MSIDTestURLResponse *tokenResponse =
    [MSIDTestURLResponse authCodeResponse:@"i am an auth code"
                                authority:@"https://login.microsoftonline.com/contosob2c"
                                    query:@"p=b2c_1_policy"
                                   scopes:[NSOrderedSet orderedSetWithArray:@[@"fakeb2cscopes", @"openid", @"profile", @"offline_access"]]];
    
    [MSIDTestURLSession addResponses:@[oidcResponse, tokenResponse]];
    
    [MSALTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(id obj, MSIDWebviewConfiguration *configuration, MSIDOauth2Factory *oauth2Factory, WKWebView *webview, id<MSIDRequestContext>context, MSIDWebviewAuthCompletionHandler completionHandler)
     {
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=i+am+an+auth+code"];
         
         MSIDWebAADAuthResponse *oauthResponse = [[MSIDWebAADAuthResponse alloc] initWithURL:[NSURL URLWithString:responseString]
                                                                                     context:nil error:nil];
         
         completionHandler(oauthResponse, nil);
     }];
    
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                                    error:&error];
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    application.webviewType = MSALWebviewTypeWKWebView;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenForScopes"];
    [application acquireTokenForScopes:@[@"fakeb2cscopes"]
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");
         
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testAcquireTokenSilent_whenNoATForScopeInCache_shouldUseRTAndReturnNewAT
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    // Seed a cache object with a user and existing AT that does not match the scope we will ask for
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                 RT:@"i am a refresh token!"
                                                                             scopes:[[NSOrderedSet alloc] initWithArray:@[@"user.read"]]
                                                                            idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                                uid:DEFAULT_TEST_UID
                                                                               utid:DEFAULT_TEST_UTID
                                                                           familyId:nil];
    
    NSDictionary* clientInfoClaims = @{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];

    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:clientInfo];
    
    // Add AT & RT.
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL result = [self.tokenCache saveTokensWithConfiguration:configuration
                                                      response:response
                                                       context:nil
                                                         error:nil];
    XCTAssertTrue(result);
    
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                    error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = self.tokenCache;

    // Set up the network responses for OIDC discovery and the RT response
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"mail.read", @"openid", @"profile", @"offline_access"]];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes authority:authority tenantId:nil user:account];
    NSMutableDictionary *json = [[response jsonDictionary] mutableCopy];
    json[@"access_token"] = @"i am an updated access token!";
    [tokenResponse setResponseJSON:json];
    [MSIDTestURLSession addResponses:@[oidcResponse, tokenResponse]];

    // Acquire a token silently for a scope that does not exist in cache
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"mail.read"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we get back the proper access token
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");
         XCTAssertEqual(result.extendedLifeTimeToken, NO);

         [expectation fulfill];
     }];

    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testAcquireTokenSilent_whenExtendedLifetimeTokenEnabledAndServiceUnavailable_shouldReturnExtendedLifetimeToken
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    // Seed a cache object with a user and an expired AT
    NSMutableDictionary *json = [MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                          RT:@"i am a refresh token!"
                                                                      scopes:[[NSOrderedSet alloc] initWithArray:@[@"user.read"]]
                                                                     idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                         uid:DEFAULT_TEST_UID
                                                                        utid:DEFAULT_TEST_UTID
                                                                    familyId:nil].jsonDictionary.mutableCopy;
    [json setValue:@"-1" forKey:MSID_OAUTH2_EXPIRES_IN];
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:json error:nil];
    
    NSDictionary* clientInfoClaims = @{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:clientInfo];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL result = [self.tokenCache saveTokensWithConfiguration:configuration
                                                      response:response
                                                       context:nil
                                                         error:nil];
    XCTAssertTrue(result);
    
    // Set up the network responses for OIDC discovery
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"user.read", @"openid", @"profile", @"offline_access"]];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];
    
    // Set up two 504 network responses
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes authority:authority tenantId:nil user:account];
    [tokenResponse setResponseURL:@"https://someresponseurl.com" code:504 headerFields:@{}];
    [MSIDTestURLSession addResponse:tokenResponse]; //Add the responsce twice because retry will happen
    [MSIDTestURLSession addResponse:tokenResponse];
    
    // Enable extended lifetime token and acquire token
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                               error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = self.tokenCache;
    application.extendedLifetimeEnabled = YES; //Turn on extended lifetime token
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"user.read"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we get back the extended lifetime access token
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
         XCTAssertEqual(result.extendedLifeTimeToken, YES);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testAcquireTokenSilent_whenExtendedLifetimeTokenDisabledAndServiceUnavailable_shouldNotReturnToken
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    // Seed a cache object with a user and an expired AT
    NSMutableDictionary *json = [MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                          RT:@"i am a refresh token!"
                                                                      scopes:[[NSOrderedSet alloc] initWithArray:@[@"user.read"]]
                                                                     idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                         uid:DEFAULT_TEST_UID
                                                                        utid:DEFAULT_TEST_UTID
                                                                    familyId:nil].jsonDictionary.mutableCopy;
    [json setValue:@"-1" forKey:MSID_OAUTH2_EXPIRES_IN];
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:json error:nil];
    
    NSDictionary* clientInfoClaims = @{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:clientInfo];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL result = [self.tokenCache saveTokensWithConfiguration:configuration
                                                      response:response
                                                       context:nil
                                                         error:nil];
    XCTAssertTrue(result);
    
    // Set up the network responses for OIDC discovery
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"user.read", @"openid", @"profile", @"offline_access"]];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];
    
    // Set up two 504 network responses
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes authority:authority tenantId:nil user:account];
    [tokenResponse setResponseURL:@"https://someresponseurl.com" code:504 headerFields:@{}];
    [MSIDTestURLSession addResponse:tokenResponse]; //Add the responsce twice because retry will happen
    [MSIDTestURLSession addResponse:tokenResponse];
    
    // Enable extended lifetime token and acquire token
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                               error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = self.tokenCache;
    application.extendedLifetimeEnabled = NO; //default is NO
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"user.read"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure error is returned
         XCTAssertNil(result);
         XCTAssertNotNil(error);
         XCTAssertEqualObjects(error.domain, MSIDHttpErrorCodeDomain);
         XCTAssertEqual(error.code, 504);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testAcquireTokenSilent_whenATAvailableAndExtendedLifetimeTokenEnabled_shouldReturnTokenWithExtendedFlagBeingNo
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    // Seed a cache object with a user and an AT
    NSMutableDictionary *json = [MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                          RT:@"i am a refresh token!"
                                                                      scopes:[[NSOrderedSet alloc] initWithArray:@[@"user.read"]]
                                                                     idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                         uid:DEFAULT_TEST_UID
                                                                        utid:DEFAULT_TEST_UTID
                                                                    familyId:nil].jsonDictionary.mutableCopy;
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:json error:nil];
    
    NSDictionary* clientInfoClaims = @{ @"uid" : DEFAULT_TEST_UID, @"utid" : DEFAULT_TEST_UTID};
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:clientInfo];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL result = [self.tokenCache saveTokensWithConfiguration:configuration
                                                      response:response
                                                       context:nil
                                                         error:nil];
    XCTAssertTrue(result);
    
    // Set up the network responses for OIDC discovery
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"user.read", @"openid", @"profile", @"offline_access"]];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponse:oidcResponse];
    
    // Set up two 504 network responses
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes authority:authority tenantId:nil user:account];
    [tokenResponse setResponseURL:@"https://someresponseurl.com" code:504 headerFields:@{}];
    [MSIDTestURLSession addResponse:tokenResponse]; //Add the responsce twice because retry will happen
    [MSIDTestURLSession addResponse:tokenResponse];
    
    // Enable extended lifetime token and acquire token
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                               error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = self.tokenCache;
    application.extendedLifetimeEnabled = YES; //Turn on extended lifetime token
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"user.read"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we get back access token with extendedLifetimeToken being NO
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, DEFAULT_TEST_ACCESS_TOKEN);
         XCTAssertEqual(result.extendedLifeTimeToken, NO);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

@end
