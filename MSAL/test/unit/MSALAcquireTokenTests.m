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
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#import "MSIDMacTokenCache.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSALTestIdTokenUtil.h"
#import "MSIDAADAuthority.h"
#import "MSIDB2CAuthority.h"
#import "MSIDAADNetworkConfiguration.h"
#import "NSString+MSALTestUtil.h"
#import "MSIDTestURLResponse+MSAL.h"
#import "MSALB2CAuthority.h"
#import "MSIDWebviewAuthorization.h"
#import "MSIDWebAADAuthResponse.h"
#import "MSIDWebviewFactory.h"
#import "NSOrderedSet+MSIDExtensions.h"

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
    
    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = @"v2.0";
}

- (void)tearDown
{
    [super tearDown];
    
    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = nil;
}


- (void)testAcquireTokenInteractive_whenB2CAuthorityWithQP_shouldRetainQP
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    __auto_type authority = [@"https://login.microsoftonline.com/tfp/contosob2c/b2c_1_policy" msalAuthority];
    MSIDTestURLResponse *oidcResponse =
    [MSIDTestURLResponse oidcResponseForAuthority:authority.msidAuthority.url.absoluteString
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
         XCTAssertEqualObjects(result.authority.url.absoluteString, @"https://login.microsoftonline.com/tfp/contosob2c/b2c_1_policy");
         
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testAcquireTokenSilent_whenNoATForScopeInCache_andInvalidRT_shouldReturnInteractionRequired
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];
    
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
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"mail.read", @"openid", @"profile", @"offline_access"]];
    
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse errorRtResponseForScopes:expectedScopes authority:authority tenantId:nil account:account errorCode:@"invalid_grant" errorDescription:@"Refresh token revoked" subError:@"unauthorized_client"];
    [MSIDTestURLSession addResponses:@[tokenResponse]];
    
    // Acquire a token silently for a scope that does not exist in cache
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"mail.read"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we get back the proper access token
         XCTAssertNotNil(error);
         XCTAssertNil(result);
         XCTAssertEqual(error.code, MSALErrorInteractionRequired);
         XCTAssertEqualObjects(error.userInfo[MSALErrorDescriptionKey], @"User interaction is required");
         XCTAssertEqualObjects(error.userInfo[MSALOAuthErrorKey], @"invalid_grant");
         XCTAssertEqualObjects(error.userInfo[MSALOAuthSubErrorKey], @"unauthorized_client");
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:5];
}

- (void)testAcquireTokenSilent_whenNoATForScopeInCache_shouldUseRTAndReturnNewAT
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];
    
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
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"mail.read", @"openid", @"profile", @"offline_access"]];
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes authority:authority tenantId:nil user:account];
    NSMutableDictionary *json = [[response jsonDictionary] mutableCopy];
    json[@"access_token"] = @"i am an updated access token!";
    json[@"scope"] = [expectedScopes msidToString];
    [tokenResponse setResponseJSON:json];
    [MSIDTestURLSession addResponses:@[tokenResponse]];
    
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
         XCTAssertEqualObjects(result.authority.url.absoluteString, @"https://login.microsoftonline.com/" DEFAULT_TEST_UTID);
         XCTAssertEqual(result.extendedLifeTimeToken, NO);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:5];
}

- (void)testAcquireTokenInteractive_whenClaimsIsPassedViaOverloadedAcquireToken_shouldSendClaims
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:DEFAULT_TEST_AUTHORITY];
    
    // Mock tenant discovery response
    MSIDTestURLResponse *oidcResponse =
    [MSIDTestURLResponse oidcResponseForAuthority:DEFAULT_TEST_AUTHORITY
                                      responseUrl:DEFAULT_TEST_AUTHORITY
                                            query:nil];
    // Mock auth code grant response
    MSIDTestURLResponse *tokenResponse =
    [MSIDTestURLResponse authCodeResponse:@"i am an auth code"
                                authority:DEFAULT_TEST_AUTHORITY
                                    query:nil
                                   scopes:[NSOrderedSet orderedSetWithArray:@[@"fakescopes", @"openid", @"profile", @"offline_access"]]];
    
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse, tokenResponse]];
    
    // Check claims is in start url
    [MSALTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(id obj, MSIDWebviewConfiguration *configuration, MSIDOauth2Factory *oauth2Factory, WKWebView *webview, id<MSIDRequestContext>context, MSIDWebviewAuthCompletionHandler completionHandler)
     {
         NSURL *url = [oauth2Factory.webviewFactory startURLFromConfiguration:configuration requestState:[[NSUUID UUID] UUIDString]];
         XCTAssertNotNil(url);
         NSDictionary *QPs = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:url.query];
         
         NSMutableDictionary *expectedQPs =
         [@{
            @"claims" : @"{\"fake_claims\"}", //claims should be in the QPs
            @"client-request-id" : [MSIDTestRequireValueSentinel sentinel],
            @"return-client-request-id" : @"true",
            @"state" : [MSIDTestRequireValueSentinel sentinel],
            @"prompt" : @"select_account",
            @"client_id" : UNIT_TEST_CLIENT_ID,
            @"scope" : @"fakescopes openid profile offline_access",
            @"redirect_uri" : UNIT_TEST_DEFAULT_REDIRECT_URI,
            @"response_type" : @"code",
            @"code_challenge": [MSIDTestRequireValueSentinel sentinel],
            @"code_challenge_method" : @"S256",
            @"haschrome" : @"1",
            @"eqpKey" : @"eqpValue",
            UT_SLICE_PARAMS_DICT
            } mutableCopy];
         [expectedQPs addEntriesFromDictionary:[MSIDDeviceId deviceId]];
         
         XCTAssertTrue([expectedQPs compareAndPrintDiff:QPs]);
         
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=%@&state=%@", @"i+am+an+auth+code", QPs[@"state"]];
         MSIDWebAADAuthResponse *oauthResponse = [[MSIDWebAADAuthResponse alloc] initWithURL:[NSURL URLWithString:responseString]
                                                                                     context:nil error:nil];
         completionHandler(oauthResponse, nil);
     }];
    
    // Acquire token call
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                           authority:[DEFAULT_TEST_AUTHORITY msalAuthority]
                                                                                               error:&error];
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireToken"];
    application.webviewType = MSALWebviewTypeWKWebView;
    [application acquireTokenForScopes:@[@"fakescopes"]
                  extraScopesToConsent:nil
                               account:nil
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:@{@"eqpKey":@"eqpValue"}
                                claims:@"{\"fake_claims\"}"
                             authority:nil
                         correlationId:nil
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testAcquireTokenInteractive_whenClaimsIsEmpty_shouldNotSendClaims
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:DEFAULT_TEST_AUTHORITY];
    
    // Mock tenant discovery response
    MSIDTestURLResponse *oidcResponse =
    [MSIDTestURLResponse oidcResponseForAuthority:DEFAULT_TEST_AUTHORITY
                                      responseUrl:DEFAULT_TEST_AUTHORITY
                                            query:nil];
    // Mock auth code grant response
    MSIDTestURLResponse *tokenResponse =
    [MSIDTestURLResponse authCodeResponse:@"i am an auth code"
                                authority:DEFAULT_TEST_AUTHORITY
                                    query:nil
                                   scopes:[NSOrderedSet orderedSetWithArray:@[@"fakescopes", @"openid", @"profile", @"offline_access"]]];
    
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse, tokenResponse]];
    
    // Check claims is in start url
    [MSALTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(id obj, MSIDWebviewConfiguration *configuration, MSIDOauth2Factory *oauth2Factory, WKWebView *webview, id<MSIDRequestContext>context, MSIDWebviewAuthCompletionHandler completionHandler)
     {
         NSURL *url = [oauth2Factory.webviewFactory startURLFromConfiguration:configuration requestState:[[NSUUID UUID] UUIDString]];
         XCTAssertNotNil(url);
         NSDictionary *QPs = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:url.query];
         
         NSMutableDictionary *expectedQPs =
         [@{
            //claims should not be in the QPs
            @"client-request-id" : [MSIDTestRequireValueSentinel sentinel],
            @"return-client-request-id" : @"true",
            @"state" : [MSIDTestRequireValueSentinel sentinel],
            @"prompt" : @"select_account",
            @"client_id" : UNIT_TEST_CLIENT_ID,
            @"scope" : @"fakescopes openid profile offline_access",
            @"redirect_uri" : UNIT_TEST_DEFAULT_REDIRECT_URI,
            @"response_type" : @"code",
            @"code_challenge": [MSIDTestRequireValueSentinel sentinel],
            @"code_challenge_method" : @"S256",
            @"haschrome" : @"1",
            UT_SLICE_PARAMS_DICT
            } mutableCopy];
         [expectedQPs addEntriesFromDictionary:[MSIDDeviceId deviceId]];
         
         XCTAssertTrue([expectedQPs compareAndPrintDiff:QPs]);
         
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=%@&state=%@", @"i+am+an+auth+code", QPs[@"state"]];
         MSIDWebAADAuthResponse *oauthResponse = [[MSIDWebAADAuthResponse alloc] initWithURL:[NSURL URLWithString:responseString]
                                                                                     context:nil error:nil];
         completionHandler(oauthResponse, nil);
     }];
    
    // Acquire token call
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                           authority:[DEFAULT_TEST_AUTHORITY msalAuthority]
                                                                                               error:&error];
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireToken"];
    application.webviewType = MSALWebviewTypeWKWebView;
    [application acquireTokenForScopes:@[@"fakescopes"]
                  extraScopesToConsent:nil
                               account:nil
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:nil
                                claims:@""
                             authority:nil
                         correlationId:nil
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testAcquireTokenInteractive_whenDuplicateClaimsIsPassedInEQP_shouldReturnError
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                           authority:[DEFAULT_TEST_AUTHORITY msalAuthority]
                                                                                               error:&error];
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireToken"];
    [application acquireTokenForScopes:@[@"fakescopes"]
                  extraScopesToConsent:nil
                               account:nil
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:@{@"eqpKey":@"eqpValue", @"claims":@"claims_value"}
                                claims:@"fake_claims"
                             authority:nil
                         correlationId:nil
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNotNil(error);
         XCTAssertNil(result);
         XCTAssertEqualObjects(error.domain, MSALErrorDomain);
         XCTAssertEqual(error.code, MSALErrorInvalidParameter);
         XCTAssertEqualObjects(error.userInfo[MSALErrorDescriptionKey], @"Duplicate claims parameter is found in extraQueryParameters. Please remove it.");
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testAcquireTokenInteractive_whenInstanceAware_shouldReturnCloudAuthorityInResult
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:DEFAULT_TEST_AUTHORITY];
    
    // Mock tenant discovery response
    MSIDTestURLResponse *oidcResponse =
    [MSIDTestURLResponse oidcResponseForAuthority:DEFAULT_TEST_AUTHORITY
                                      responseUrl:DEFAULT_TEST_AUTHORITY
                                            query:nil];
    
    // Mock auth code grant response for instance-aware flow
    // It will hit login.microsoftonline.de rather than login.microsoftonline.com
    MSIDTestURLResponse *tokenResponse =
    [MSIDTestURLResponse authCodeResponse:@"i am an auth code"
                                authority:@"https://login.microsoftonline.de/common"
                                    query:nil
                                   scopes:[NSOrderedSet orderedSetWithArray:@[@"fakescopes", @"openid", @"profile", @"offline_access"]]];
    
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse, tokenResponse]];
    
    MSIDTestURLResponse *sovereignOidcResponse =
    [MSIDTestURLResponse oidcResponseForAuthority:@"https://login.microsoftonline.de/1234-5678-90abcdefg"
                                      responseUrl:@"https://login.microsoftonline.de/1234-5678-90abcdefg"
                                            query:nil];
    
    [MSIDTestURLSession addResponse:sovereignOidcResponse];
    
    // Check if instance_aware parameter is in start url
    [MSALTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(id obj, MSIDWebviewConfiguration *configuration, MSIDOauth2Factory *oauth2Factory, WKWebView *webview, id<MSIDRequestContext>context, MSIDWebviewAuthCompletionHandler completionHandler)
     {
         NSURL *url = [oauth2Factory.webviewFactory startURLFromConfiguration:configuration requestState:[[NSUUID UUID] UUIDString]];
         XCTAssertNotNil(url);
         NSDictionary *QPs = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:url.query];
         
         NSMutableDictionary *expectedQPs =
         [@{
            @"client-request-id" : [MSIDTestRequireValueSentinel sentinel],
            @"return-client-request-id" : @"true",
            @"state" : [MSIDTestRequireValueSentinel sentinel],
            @"prompt" : @"select_account",
            @"client_id" : UNIT_TEST_CLIENT_ID,
            @"scope" : @"fakescopes openid profile offline_access",
            @"redirect_uri" : UNIT_TEST_DEFAULT_REDIRECT_URI,
            @"response_type" : @"code",
            @"code_challenge": [MSIDTestRequireValueSentinel sentinel],
            @"code_challenge_method" : @"S256",
            @"haschrome" : @"1",
            @"instance_aware" : @"true", //instance_aware parameter should be sent
            UT_SLICE_PARAMS_DICT
            } mutableCopy];
         [expectedQPs addEntriesFromDictionary:[MSIDDeviceId deviceId]];
         
         XCTAssertTrue([expectedQPs compareAndPrintDiff:QPs]);
         
         // Mock auth code response with cloud_instance_host_name
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=%@&state=%@&cloud_instance_host_name=%@", @"i+am+an+auth+code", QPs[@"state"], @"login.microsoftonline.de"];
         MSIDWebAADAuthResponse *oauthResponse = [[MSIDWebAADAuthResponse alloc] initWithURL:[NSURL URLWithString:responseString]
                                                                                     context:nil error:nil];
         completionHandler(oauthResponse, nil);
     }];
    
    // Acquire token call
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                           authority:[DEFAULT_TEST_AUTHORITY msalAuthority]
                                                                                               error:&error];
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    XCTestExpectation *expectationInteractive = [self expectationWithDescription:@"acquireTokenInteractive"];
    __block MSALResult *result = nil;
    
    application.webviewType = MSALWebviewTypeWKWebView;
    [application acquireTokenForScopes:@[@"fakescopes"]
                  extraScopesToConsent:nil
                               account:nil
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:@{@"instance_aware":@"true"}
                             authority:nil
                         correlationId:nil
                       completionBlock:^(MSALResult *rlt, NSError *error)
     {
         result = rlt;
         
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");
         
         // Expect authority to be cloud authority
         XCTAssertEqualObjects(result.authority.url.absoluteString, @"https://login.microsoftonline.de/" DEFAULT_TEST_UTID);
         XCTAssertEqualObjects(result.account.environment, @"login.microsoftonline.de");
         
         [expectationInteractive fulfill];
     }];
    
    [self waitForExpectations:@[expectationInteractive] timeout:1];
    
    // acquire token silently to verify that access token is stored under the correct authority
    XCTestExpectation *expectationSilent = [self expectationWithDescription:@"acquireTokenSilent"];
    MSALAccount *account = result.account;
    [application acquireTokenSilentForScopes:@[@"fakescopes"]
                                     account:account
                                   authority:[@"https://login.microsoftonline.de/" DEFAULT_TEST_UTID msalAuthority]
                                forceRefresh:NO
                               correlationId:nil
                             completionBlock:^(MSALResult *rlt, NSError *error)
     {
         XCTAssertNil(error);
         XCTAssertNotNil(rlt);
         XCTAssertEqualObjects(rlt.accessToken, @"i am an updated access token!");
         
         // authority cloud authority as expected
         XCTAssertEqualObjects(rlt.authority.url.absoluteString, @"https://login.microsoftonline.de/" DEFAULT_TEST_UTID);
         
         [expectationSilent fulfill];
     }];
    
    [self waitForExpectations:@[expectationSilent] timeout:1];
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
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"user.read", @"openid", @"profile", @"offline_access"]];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];
    
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
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"user.read", @"openid", @"profile", @"offline_access"]];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];
    
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
         XCTAssertEqualObjects(error.domain, MSALErrorDomain);
         XCTAssertEqual(error.code, MSALErrorUnhandledResponse);
         
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
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"user.read", @"openid", @"profile", @"offline_access"]];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];
    
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

- (void)testAcquireTokenInteractive_whenInsufficientScopesReturned_shouldReturnNilResultAndError
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:DEFAULT_TEST_AUTHORITY];
    [MSIDTestURLSession addResponse:discoveryResponse];
    
    // Mock tenant discovery response
    MSIDTestURLResponse *oidcResponse =
    [MSIDTestURLResponse oidcResponseForAuthority:DEFAULT_TEST_AUTHORITY
                                      responseUrl:DEFAULT_TEST_AUTHORITY
                                            query:nil];
    
    [MSIDTestURLSession addResponse:oidcResponse];
    [self addTestTokenResponseWithResponseScopes:@"fakescope1 fakescope2 additional.scope additional.scope2"
                               requestParamsBody:@{ MSID_OAUTH2_CLIENT_ID : UNIT_TEST_CLIENT_ID,
                                                    MSID_OAUTH2_SCOPE : @"fakescope3 fakescope4 fakescope1 openid profile offline_access",
                                                    @"client_info" : @"1",
                                                    @"grant_type" : @"authorization_code",
                                                    @"code_verifier" : [MSIDTestRequireValueSentinel sentinel],
                                                    MSID_OAUTH2_REDIRECT_URI : UNIT_TEST_DEFAULT_REDIRECT_URI,
                                                    MSID_OAUTH2_CODE : @"i am an auth code" }
                                       authority:DEFAULT_TEST_AUTHORITY];
    
    // Check if instance_aware parameter is in start url
    [MSALTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(id obj, MSIDWebviewConfiguration *configuration, MSIDOauth2Factory *oauth2Factory, WKWebView *webview, id<MSIDRequestContext>context, MSIDWebviewAuthCompletionHandler completionHandler)
     {
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=i+am+an+auth+code"];
         
         MSIDWebAADAuthResponse *oauthResponse = [[MSIDWebAADAuthResponse alloc] initWithURL:[NSURL URLWithString:responseString]
                                                                                     context:nil error:nil];
         
         completionHandler(oauthResponse, nil);
     }];
    
    // Acquire token call
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                           authority:[DEFAULT_TEST_AUTHORITY msalAuthority]
                                                                                               error:&error];
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenInteractive"];
    __block MSALResult *result = nil;
    
    application.webviewType = MSALWebviewTypeWKWebView;
    [application acquireTokenForScopes:@[@"fakescope3", @"fakescope4", @"fakescope1"]
                  extraScopesToConsent:nil
                               account:nil
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:nil
                             authority:nil
                         correlationId:nil
                       completionBlock:^(MSALResult *rlt, NSError *error)
     {
         result = rlt;
         
         XCTAssertNotNil(error);
         XCTAssertNil(result);
         XCTAssertEqualObjects(error.domain, MSALErrorDomain);
         XCTAssertEqual(error.code, MSALErrorServerDeclinedScopes);
         
         NSArray *grantedScopesArr = @[@"fakescope1", @"fakescope2", @"additional.scope", @"additional.scope2"];
         XCTAssertEqualObjects(error.userInfo[MSALGrantedScopesKey], grantedScopesArr);
         
         NSArray *declinedScopesArr = @[@"fakescope3", @"fakescope4"];
         XCTAssertEqualObjects(error.userInfo[MSALDeclinedScopesKey], declinedScopesArr);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testAcquireTokenSilent_whenInsufficientScopesReturned_shouldReturnNilResultAndError
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    // Seed a cache object with a user and an AT
    NSMutableDictionary *json = [MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                          RT:@"i am a refresh token!"
                                                                      scopes:[[NSOrderedSet alloc] initWithArray:@[@"user.read user.scope2"]]
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
    
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:@"https://login.microsoftonline.com/1234-5678-90abcdefg"];
    [MSIDTestURLSession addResponse:discoveryResponse];
    
    // Mock tenant discovery response
    MSIDTestURLResponse *oidcResponse =
    [MSIDTestURLResponse oidcResponseForAuthority:@"https://login.microsoftonline.com/1234-5678-90abcdefg"
                                      responseUrl:@"https://login.microsoftonline.com/1234-5678-90abcdefg"
                                            query:nil];
    
    // Mock token response
    [MSIDTestURLSession addResponse:oidcResponse];
    [self addTestTokenResponseWithResponseScopes:@"user.read fakescope1 additional.scope additional.scope2"
                               requestParamsBody:@{ MSID_OAUTH2_CLIENT_ID : UNIT_TEST_CLIENT_ID,
                                                    MSID_OAUTH2_SCOPE : @"user.read fakescope1 fakescope2 fakescope3 openid profile offline_access",
                                                    @"client_info" : @"1",
                                                    @"grant_type" : @"refresh_token",
                                                    MSID_OAUTH2_REFRESH_TOKEN : @"i am a refresh token!" }
                                       authority:@"https://login.microsoftonline.com/1234-5678-90abcdefg"];
    
    // Call Acquire token silent call
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                           authority:[DEFAULT_TEST_AUTHORITY msalAuthority]
                                                                                               error:&error];
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilent"];
    
    application.webviewType = MSALWebviewTypeWKWebView;
    [application acquireTokenSilentForScopes:@[@"user.read", @"fakescope1", @"fakescope2", @"fakescope3"]
                                     account:account
                                   authority:[@"https://login.microsoftonline.com/common" msalAuthority]
                             completionBlock:^(MSALResult *result, NSError *error) {
                                 
                                 XCTAssertNotNil(error);
                                 XCTAssertNil(result);
                                 XCTAssertEqualObjects(error.domain, MSALErrorDomain);
                                 XCTAssertEqual(error.code, MSALErrorServerDeclinedScopes);
                                 
                                 NSArray *grantedScopesArr = @[@"user.read", @"fakescope1", @"additional.scope", @"additional.scope2"];
                                 XCTAssertEqualObjects(error.userInfo[MSALGrantedScopesKey], grantedScopesArr);
                                 
                                 NSArray *declinedScopesArr = @[@"fakescope2", @"fakescope3"];
                                 XCTAssertEqualObjects(error.userInfo[MSALDeclinedScopesKey], declinedScopesArr);
                                 
                                 [expectation fulfill];
                                 
                             }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testAcquireTokenSilent_whenATExpiredAndFamilyRefreshTokenInCache_shouldRefreshAccessTokenUsingFamilyRefreshToken
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
                                                                    familyId:@"1"].jsonDictionary.mutableCopy;
    [json setObject:@"-3600" forKey:MSID_OAUTH2_EXPIRES_IN];
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
    [tokenResponse setResponseURL:@"https://someresponseurl.com" code:200 headerFields:@{}];
    [MSIDTestURLSession addResponse:tokenResponse];
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                               error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = self.tokenCache;
    
    NSArray *allTokens = [application.tokenCache allTokensWithContext:nil error:nil];
    
    NSMutableArray *results = [NSMutableArray array];
    
    for (MSIDBaseToken *token in allTokens)
    {
        if (token.credentialType == MSIDRefreshTokenType)
        {
            [results addObject:token];
        }
    }
    //Check if both RT and FRT are in cache
    XCTAssertEqual([results count], 2);
    MSIDRefreshToken *refreshToken = results[1];
    NSError *removeRTError = nil;
    //remove RT from cache
    BOOL removeRTResult = [self.tokenCache validateAndRemoveRefreshToken:refreshToken context:nil error:&removeRTError];
    XCTAssertNil(error);
    XCTAssertTrue(removeRTResult);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    
    [application acquireTokenSilentForScopes:@[@"user.read"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we get back access token with extendedLifetimeToken being NO
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");
         XCTAssertEqual(result.extendedLifeTimeToken, NO);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

#pragma mark - Helpers

- (void)addTestTokenResponseWithResponseScopes:(NSString *)responseScopes
                             requestParamsBody:(NSDictionary *)requestParamsBody
                                     authority:(NSString *)authority
{
    NSDictionary *clientInfo = @{ @"uid" : @"1", @"utid" : [MSALTestIdTokenUtil defaultTenantId]};
    
    // Token request response.
    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:[MSIDTestRequireValueSentinel new] forKey:@"client-request-id"];
    
    NSString *url = [NSString stringWithFormat:@"%@/oauth2/v2.0/token", authority];
    
    MSIDTestURLResponse *tokenResponse =
    [MSIDTestURLResponse requestURLString:url
                           requestHeaders:reqHeaders
                        requestParamsBody:requestParamsBody
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"access_token" : @"i am an updated access token!",
                                             @"expires_in" : @"600",
                                             @"refresh_token" : @"i am a refresh token",
                                             @"id_token" : [MSALTestIdTokenUtil defaultIdToken],
                                             @"id_token_expires_in" : @"1200",
                                             @"client_info" : [clientInfo msidBase64UrlJson],
                                             MSID_OAUTH2_SCOPE: responseScopes
                                             }];
    
    [MSIDTestURLSession addResponse:tokenResponse];
}

@end
