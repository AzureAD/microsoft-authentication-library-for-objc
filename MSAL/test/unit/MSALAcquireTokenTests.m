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
#import "MSIDTestIdTokenUtil.h"
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
#import "MSIDAadAuthorityCache.h"
#import "MSIDAadAuthorityCacheRecord.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDRefreshToken.h"
#import "MSALResult.h"
#import "MSIDTestURLResponse+Util.h"

@interface MSALAcquireTokenTests : MSALTestCase

@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;
@property (nonatomic) MSIDAccountCredentialCache *accountCache;

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
    self.tokenCache = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    self.accountCache = [[MSIDAccountCredentialCache alloc] initWithDataSource:dataSource];
    [self.accountCache clearWithContext:nil error:nil];
    [self.tokenCache clearWithContext:nil error:nil];
    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = @"v2.0";
}

- (void)tearDown
{
    [super tearDown];
    
    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = nil;
}

- (void)testAcquireTokenInteractive_whenB2CAuthority_shouldCacheTokens
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    __auto_type authority = [@"https://login.microsoftonline.com/tfp/contosob2c/b2c_1_policy" msalAuthority];
    MSIDTestURLResponse *oidcResponse =
    [MSIDTestURLResponse oidcResponseForAuthority:authority.msidAuthority.url.absoluteString
                                      responseUrl:@"https://login.microsoftonline.com/contosob2c"
                                            query:nil];
    MSIDTestURLResponse *tokenResponse =
    [MSIDTestURLResponse authCodeResponse:@"iamauthcode"
                                authority:@"https://login.microsoftonline.com/contosob2c"
                                    query:nil
                                   scopes:[NSOrderedSet orderedSetWithArray:@[@"fakeb2cscopes", @"openid", @"profile", @"offline_access"]]
                                   claims:nil];
    
    [MSIDTestURLSession addResponses:@[oidcResponse, tokenResponse]];
    
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
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                                    error:&error];
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    application.webviewType = MSALWebviewTypeWKWebView;
    
    // Add authorities to cache
    MSIDAadAuthorityCacheRecord *record = [MSIDAadAuthorityCacheRecord new];
    record.networkHost = @"login.microsoftonline.com";
    record.cacheHost = @"login.windows.net";
    record.aliases = @[@"login.microsoftonline.com", @"login.windows.net", @"login.microsoft.com"];
    record.validated = YES;
    
    MSIDAadAuthorityCache *cache = [MSIDAadAuthorityCache sharedInstance];
    [cache setObject:record forKey:@"login.microsoftonline.com"];
    [cache setObject:record forKey:@"login.windows.net"];
    [cache setObject:record forKey:@"login.microsoft.com"];
    
    __block MSALAccount *resultAccount = nil;
    
    XCTestExpectation *interactiveExpectation = [self expectationWithDescription:@"acquireTokenForScopes"];
    [application acquireTokenForScopes:@[@"fakeb2cscopes"]
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");
         XCTAssertEqualObjects(result.authority.url.absoluteString, @"https://login.microsoftonline.com/tfp/1234-5678-90abcdefg/b2c_1_policy");
         
         resultAccount = result.account;
         XCTAssertNotNil(resultAccount);
         [interactiveExpectation fulfill];
     }];
    
    [self waitForExpectations:@[interactiveExpectation] timeout:1];
    
    // Now remove aliases, simulating app restart
    [[MSIDAadAuthorityCache sharedInstance] removeAllObjects];
    
    // Now test that we're able to retrieve cache successfully back
    XCTestExpectation *silentExpectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    
    [application acquireTokenSilentForScopes:@[@"fakeb2cscopes"]
                                     account:resultAccount
                             completionBlock:^(MSALResult *result, NSError *error) {
                                 
                                 XCTAssertNil(error);
                                 XCTAssertNotNil(result);
                                 XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");
                                 XCTAssertEqualObjects(result.authority.url.absoluteString, @"https://login.microsoftonline.com/tfp/1234-5678-90abcdefg/b2c_1_policy");
                                 [silentExpectation fulfill];
                             }];
    
    [self waitForExpectations:@[silentExpectation] timeout:1];
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
    [MSIDTestURLResponse authCodeResponse:@"iamauthcode"
                                authority:@"https://login.microsoftonline.com/contosob2c"
                                    query:@"p=b2c_1_policy"
                                   scopes:[NSOrderedSet orderedSetWithArray:@[@"fakeb2cscopes", @"openid", @"profile", @"offline_access"]]
                                   claims:nil];
    
    [MSIDTestURLSession addResponses:@[oidcResponse, tokenResponse]];
    
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
         XCTAssertEqualObjects(result.authority.url.absoluteString, @"https://login.microsoftonline.com/tfp/1234-5678-90abcdefg/b2c_1_policy");
         
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
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    // Add AT & RT.
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL result = [self.tokenCache saveTokensWithConfiguration:configuration
                                                      response:response
                                                       factory:[MSIDAADV2Oauth2Factory new]
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
    
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse errorRtResponseForScopes:expectedScopes authority:authority tenantId:nil account:account errorCode:@"invalid_grant" errorDescription:@"Refresh token revoked" subError:@"unauthorized_client" claims:nil refreshToken:nil];
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
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    // Add AT & RT.
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL result = [self.tokenCache saveTokensWithConfiguration:configuration
                                                      response:response
                                                       factory:[MSIDAADV2Oauth2Factory new]
                                                       context:nil
                                                         error:nil];
    XCTAssertTrue(result);
    
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                    error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = self.tokenCache;
    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    // Set up the network responses for OIDC discovery and the RT response
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"mail.read", @"openid", @"profile", @"offline_access"]];
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes authority:authority tenantId:nil user:account claims:nil];
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
    NSString *claims = @"{\"fake_claims\":\"fake_value\"}";
    
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
    [MSIDTestURLResponse authCodeResponse:@"iamauthcode"
                                authority:DEFAULT_TEST_AUTHORITY
                                    query:nil
                                   scopes:[NSOrderedSet orderedSetWithArray:@[@"fakescopes", @"openid", @"profile", @"offline_access"]]
                                   claims:claims];
    
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse, tokenResponse]];
    
    // Check claims is in start url
    [MSIDTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(id obj, MSIDWebviewConfiguration *configuration, MSIDOauth2Factory *oauth2Factory, WKWebView *webview, id<MSIDRequestContext>context, MSIDWebviewAuthCompletionHandler completionHandler)
     {
         NSURL *url = [oauth2Factory.webviewFactory startURLFromConfiguration:configuration requestState:[[NSUUID UUID] UUIDString]];
         XCTAssertNotNil(url);
         NSDictionary *QPs = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:url.query];
         
         NSMutableDictionary *expectedQPs =
         [@{
            @"claims" : claims, //claims should be in the QPs
            @"client-request-id" : [MSIDTestRequireValueSentinel sentinel],
            @"return-client-request-id" : @"true",
            @"state" : [MSIDTestRequireValueSentinel sentinel],
            @"prompt" : @"select_account",
            @"client_id" : UNIT_TEST_CLIENT_ID,
            @"scope" : @"fakescopes openid profile offline_access",
            @"client_info" : @"1",
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
         
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=%@&state=%@&client_info=%@", @"iamauthcode", QPs[@"state"], @"eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0"];
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

    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireToken"];
    application.webviewType = MSALWebviewTypeWKWebView;
    [application acquireTokenForScopes:@[@"fakescopes"]
                  extraScopesToConsent:nil
                               account:nil
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:@{@"eqpKey":@"eqpValue"}
                                claims:claims
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
    [MSIDTestURLResponse authCodeResponse:@"iamauthcode"
                                authority:DEFAULT_TEST_AUTHORITY
                                    query:nil
                                   scopes:[NSOrderedSet orderedSetWithArray:@[@"fakescopes", @"openid", @"profile", @"offline_access"]]
                                   claims:nil];
    
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse, tokenResponse]];
    
    // Check claims is in start url
    [MSIDTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
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
            @"client_info" : @"1",
            @"redirect_uri" : UNIT_TEST_DEFAULT_REDIRECT_URI,
            @"response_type" : @"code",
            @"code_challenge": [MSIDTestRequireValueSentinel sentinel],
            @"code_challenge_method" : @"S256",
            @"haschrome" : @"1",
            UT_SLICE_PARAMS_DICT
            } mutableCopy];
         [expectedQPs addEntriesFromDictionary:[MSIDDeviceId deviceId]];
         
         XCTAssertTrue([expectedQPs compareAndPrintDiff:QPs]);
         
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=%@&state=%@&client_info=%@", @"iamauthcode", QPs[@"state"], @"eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0"];
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

    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
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

    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireToken"];
    [application acquireTokenForScopes:@[@"fakescopes"]
                  extraScopesToConsent:nil
                               account:nil
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:@{@"eqpKey":@"eqpValue", @"claims":@"claims_value"}
                                claims:@"{\"fake_claims\":\"fake_value\"}"
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

- (void)testAcquireTokenInteractive_whenCapabilitiesSet_shouldSendCapabilitiesToServer
{
    NSString *expectedClaims = @"{\"access_token\":{\"xms_cc\":{\"values\":[\"llt\"]}}}";
    
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
    [MSIDTestURLResponse authCodeResponse:@"iamauthcode"
                                authority:DEFAULT_TEST_AUTHORITY
                                    query:nil
                                   scopes:[NSOrderedSet orderedSetWithArray:@[@"fakescopes", @"openid", @"profile", @"offline_access"]]
                                   claims:expectedClaims];
    
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse, tokenResponse]];
    
    // Check claims is in start url
    [MSIDTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(id obj, MSIDWebviewConfiguration *configuration, MSIDOauth2Factory *oauth2Factory, WKWebView *webview, id<MSIDRequestContext>context, MSIDWebviewAuthCompletionHandler completionHandler)
     {
         NSURL *url = [oauth2Factory.webviewFactory startURLFromConfiguration:configuration requestState:[[NSUUID UUID] UUIDString]];
         XCTAssertNotNil(url);
         NSDictionary *QPs = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:url.query];
         
         NSMutableDictionary *expectedQPs =
         [@{
            @"claims" : expectedClaims, //claims should be in the QPs
            @"client-request-id" : [MSIDTestRequireValueSentinel sentinel],
            @"return-client-request-id" : @"true",
            @"state" : [MSIDTestRequireValueSentinel sentinel],
            @"prompt" : @"select_account",
            @"client_id" : UNIT_TEST_CLIENT_ID,
            @"scope" : @"fakescopes openid profile offline_access",
            @"client_info" : @"1",
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
         
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=%@&state=%@&client_info=%@", @"iamauthcode", QPs[@"state"], @"eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0"];
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
    
    [application setClientCapabilities:@[@"llt"]];

    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireToken"];
    application.webviewType = MSALWebviewTypeWKWebView;
    [application acquireTokenForScopes:@[@"fakescopes"]
                  extraScopesToConsent:nil
                               account:nil
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:@{@"eqpKey":@"eqpValue"}
                                claims:nil
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


- (void)testAcquireTokenInteractive_whenClaimsIsPassedAndCapabilitiesSet_shouldSendClaimsToServer
{
    NSString *claims = @"{\"access_token\":{\"polids\":{\"values\":[\"5ce770ea-8690-4747-aa73-c5b3cd509cd4\"],\"essential\":true}}}";
    NSString *expectedClaims = @"{\"access_token\":{\"polids\":{\"values\":[\"5ce770ea-8690-4747-aa73-c5b3cd509cd4\"],\"essential\":true},\"xms_cc\":{\"values\":[\"llt\"]}}}";
    
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
    [MSIDTestURLResponse authCodeResponse:@"iamauthcode"
                                authority:DEFAULT_TEST_AUTHORITY
                                    query:nil
                                   scopes:[NSOrderedSet orderedSetWithArray:@[@"fakescopes", @"openid", @"profile", @"offline_access"]]
                                   claims:expectedClaims];
    
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse, tokenResponse]];
    
    // Check claims is in start url
    [MSIDTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(id obj, MSIDWebviewConfiguration *configuration, MSIDOauth2Factory *oauth2Factory, WKWebView *webview, id<MSIDRequestContext>context, MSIDWebviewAuthCompletionHandler completionHandler)
     {
         NSURL *url = [oauth2Factory.webviewFactory startURLFromConfiguration:configuration requestState:[[NSUUID UUID] UUIDString]];
         XCTAssertNotNil(url);
         NSDictionary *QPs = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:url.query];
         
         NSMutableDictionary *expectedQPs =
         [@{
            @"claims" : expectedClaims, //claims should be in the QPs
            @"client-request-id" : [MSIDTestRequireValueSentinel sentinel],
            @"return-client-request-id" : @"true",
            @"state" : [MSIDTestRequireValueSentinel sentinel],
            @"prompt" : @"select_account",
            @"client_id" : UNIT_TEST_CLIENT_ID,
            @"scope" : @"fakescopes openid profile offline_access",
            @"client_info" : @"1",
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
         
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=%@&state=%@&client_info=%@", @"iamauthcode", QPs[@"state"], @"eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0"];
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

    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    [application setClientCapabilities:@[@"llt"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireToken"];
    application.webviewType = MSALWebviewTypeWKWebView;
    [application acquireTokenForScopes:@[@"fakescopes"]
                  extraScopesToConsent:nil
                               account:nil
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:@{@"eqpKey":@"eqpValue"}
                                claims:claims
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

- (void)testAcquireTokenInteractive_whenClaimsIsPassedAndLoginHintNotNil_shouldSendClaimsAndLoginHintToServer
{
    NSString *claims = @"{\"access_token\":{\"polids\":{\"values\":[\"5ce770ea-8690-4747-aa73-c5b3cd509cd4\"],\"essential\":true}}}";
    
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:DEFAULT_TEST_AUTHORITY];
    
    // Mock tenant discovery response
    MSIDTestURLResponse *oidcResponse =
    [MSIDTestURLResponse oidcResponseForAuthority:DEFAULT_TEST_AUTHORITY
                                      responseUrl:DEFAULT_TEST_AUTHORITY
                                            query:nil];
    // Mock auth code grant response
    MSIDTestURLResponse *tokenResponse =
    [MSIDTestURLResponse authCodeResponse:@"iamanauthcode"
                                authority:DEFAULT_TEST_AUTHORITY
                                    query:nil
                                   scopes:[NSOrderedSet orderedSetWithArray:@[@"fakescopes", @"openid", @"profile", @"offline_access"]]
                                   claims:claims];
    
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse, tokenResponse]];
    
    // Check claims is in start url
    [MSIDTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(id obj, MSIDWebviewConfiguration *configuration, MSIDOauth2Factory *oauth2Factory, WKWebView *webview, id<MSIDRequestContext>context, MSIDWebviewAuthCompletionHandler completionHandler)
     {
         NSURL *url = [oauth2Factory.webviewFactory startURLFromConfiguration:configuration requestState:[[NSUUID UUID] UUIDString]];
         XCTAssertNotNil(url);
         NSDictionary *QPs = [NSDictionary msidDictionaryFromWWWFormURLEncodedString:url.query];
         
         NSMutableDictionary *expectedQPs =
         [@{
            @"claims" : claims, //claims should be in the QPs
            @"client-request-id" : [MSIDTestRequireValueSentinel sentinel],
            @"return-client-request-id" : @"true",
            @"state" : [MSIDTestRequireValueSentinel sentinel],
            @"client_id" : UNIT_TEST_CLIENT_ID,
            @"scope" : @"fakescopes openid profile offline_access",
            @"client_info" : @"1",
            @"redirect_uri" : UNIT_TEST_DEFAULT_REDIRECT_URI,
            @"response_type" : @"code",
            @"code_challenge": [MSIDTestRequireValueSentinel sentinel],
            @"code_challenge_method" : @"S256",
            @"haschrome" : @"1",
            @"eqpKey" : @"eqpValue",
            @"login_hint": @"upn@test.com"
            UT_SLICE_PARAMS_DICT
            } mutableCopy];
         [expectedQPs addEntriesFromDictionary:[MSIDDeviceId deviceId]];
         
         XCTAssertTrue([expectedQPs compareAndPrintDiff:QPs]);
         
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=%@&state=%@&client_info=%@", @"iamanauthcode", QPs[@"state"], @"eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0"];
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
    
    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireToken"];
    application.webviewType = MSALWebviewTypeWKWebView;
    [application acquireTokenForScopes:@[@"fakescopes"]
                  extraScopesToConsent:nil
                             loginHint:@"upn@test.com"
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:@{@"eqpKey":@"eqpValue"}
                                claims:claims
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

- (void)testAcquireTokenInteractive_whenClaimsNotProperJson_shouldReturnError
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

    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    [application setClientCapabilities:@[@"llt"]];
    
    NSString *claims = @"{\"notproper _json";
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireToken"];
    application.webviewType = MSALWebviewTypeWKWebView;
    [application acquireTokenForScopes:@[@"fakescopes"]
                  extraScopesToConsent:nil
                               account:nil
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:@{@"eqpKey":@"eqpValue"}
                                claims:claims
                             authority:nil
                         correlationId:nil
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNotNil(error);
         XCTAssertEqual(error.code, MSALErrorInvalidParameter);
         XCTAssertEqualObjects(error.userInfo[MSALErrorDescriptionKey], @"Claims is not proper JSON. Please make sure it is correct JSON claims parameter.");
         XCTAssertNil(result);
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
    [MSIDTestURLResponse authCodeResponse:@"iamauthcode"
                                authority:@"https://login.microsoftonline.de/common"
                                    query:nil
                                   scopes:[NSOrderedSet orderedSetWithArray:@[@"fakescopes", @"openid", @"profile", @"offline_access"]]
                                   claims:nil];
    
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse, tokenResponse]];
    
    MSIDTestURLResponse *sovereignOidcResponse =
    [MSIDTestURLResponse oidcResponseForAuthority:@"https://login.microsoftonline.de/1234-5678-90abcdefg"
                                      responseUrl:@"https://login.microsoftonline.de/1234-5678-90abcdefg"
                                            query:nil];
    
    [MSIDTestURLSession addResponse:sovereignOidcResponse];
    
    // Check if instance_aware parameter is in start url
    [MSIDTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
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
            @"client_info" : @"1",
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
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=%@&state=%@&cloud_instance_host_name=%@&client_info=%@", @"iamauthcode", QPs[@"state"], @"login.microsoftonline.de", @"eyJ1aWQiOiI5ZjQ4ODBkOC04MGJhLTRjNDAtOTdiYy1mN2EyM2M3MDMwODQiLCJ1dGlkIjoiZjY0NWFkOTItZTM4ZC00ZDFhLWI1MTAtZDFiMDlhNzRhOGNhIn0"];
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

    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
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
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL result = [self.tokenCache saveTokensWithConfiguration:configuration
                                                      response:response
                                                       factory:[MSIDAADV2Oauth2Factory new]
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
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes authority:authority tenantId:nil user:account claims:nil];
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
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL result = [self.tokenCache saveTokensWithConfiguration:configuration
                                                      response:response
                                                       factory:[MSIDAADV2Oauth2Factory new]
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
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes authority:authority tenantId:nil user:account claims:nil];
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
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL result = [self.tokenCache saveTokensWithConfiguration:configuration
                                                      response:response
                                                       factory:[MSIDAADV2Oauth2Factory new]
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
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes authority:authority tenantId:nil user:account claims:nil];
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
                                                    MSID_OAUTH2_CODE : @"iamauthcode" }
                                       authority:DEFAULT_TEST_AUTHORITY];
    
    // Check if instance_aware parameter is in start url
    [MSIDTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(id obj, MSIDWebviewConfiguration *configuration, MSIDOauth2Factory *oauth2Factory, WKWebView *webview, id<MSIDRequestContext>context, MSIDWebviewAuthCompletionHandler completionHandler)
     {
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=iamauthcode"];
         
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

    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
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
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL result = [self.tokenCache saveTokensWithConfiguration:configuration
                                                      response:response
                                                       factory:[MSIDAADV2Oauth2Factory new]
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

- (void)testAcquireTokenSilent_whenClaimsIsPassed_shouldSkipAtAndUseRt
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    // Add an AT and RT to cache
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                 RT:@"i am a refresh token!"
                                                                             scopes:[[NSOrderedSet alloc] initWithArray:@[@"user.read"]]
                                                                            idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                                uid:DEFAULT_TEST_UID
                                                                               utid:DEFAULT_TEST_UTID
                                                                           familyId:nil];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL tokenSetSuccessful = [self.tokenCache saveTokensWithConfiguration:configuration
                                                                  response:response
                                                                   factory:[MSIDAADV2Oauth2Factory new]
                                                                   context:nil
                                                                     error:nil];
    XCTAssertTrue(tokenSetSuccessful);
    
    // Add mock response for authority validation
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];
    
    // Add mock response for refresh token grant, claims should be in the request body
    NSString *claims = @"{\"access_token\":{\"polids\":{\"values\":[\"5ce770ea-8690-4747-aa73-c5b3cd509cd4\"],\"essential\":true}}}";
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"user.read", @"openid", @"profile", @"offline_access"]];
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes
                                                                        authority:authority
                                                                         tenantId:nil
                                                                             user:account
                                                                           claims:claims];
    NSMutableDictionary *json = [[response jsonDictionary] mutableCopy];
    json[@"access_token"] = @"i am an updated access token!";
    json[@"scope"] = [expectedScopes msidToString];
    [tokenResponse setResponseJSON:json];
    [MSIDTestURLSession addResponses:@[tokenResponse]];
    
    // Acquire a token silently
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                    error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = self.tokenCache;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"user.read"]
                                     account:account
                                   authority:nil
                                      claims:claims
                                forceRefresh:NO
                               correlationId:nil
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we skip the old access token and get back a new one
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");
         XCTAssertEqualObjects(result.authority.url.absoluteString, @"https://login.microsoftonline.com/" DEFAULT_TEST_UTID);
         XCTAssertEqual(result.extendedLifeTimeToken, NO);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:5];
}

- (void)testAcquireTokenSilent_whenClaimsEmpty_shouldNotSkipAccessToken
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    // Add an AT and RT to cache
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                 RT:@"i am a refresh token!"
                                                                             scopes:[[NSOrderedSet alloc] initWithArray:@[@"user.read"]]
                                                                            idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                                uid:DEFAULT_TEST_UID
                                                                               utid:DEFAULT_TEST_UTID
                                                                           familyId:nil];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL tokenSetSuccessful = [self.tokenCache saveTokensWithConfiguration:configuration
                                                                  response:response
                                                                   factory:[MSIDAADV2Oauth2Factory new]
                                                                   context:nil
                                                                     error:nil];
    XCTAssertTrue(tokenSetSuccessful);
    
    // Add mock response for authority validation
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];
    
    // Acquire a token silently
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                    error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = self.tokenCache;
    
    [application setClientCapabilities:@[@"cp1"]];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"user.read"]
                                     account:account
                                   authority:nil
                                      claims:@""
                                forceRefresh:NO
                               correlationId:nil
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we return access token in cache
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"access_token");
         XCTAssertEqualObjects(result.authority.url.absoluteString, @"https://login.microsoftonline.com/" DEFAULT_TEST_UTID);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:5];
}

- (void)testAcquireTokenSilent_whenCapabilitiesSet_shouldNotSkipAccessToken
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    // Add an AT and RT to cache
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                 RT:@"i am a refresh token!"
                                                                             scopes:[[NSOrderedSet alloc] initWithArray:@[@"user.read"]]
                                                                            idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                                uid:DEFAULT_TEST_UID
                                                                               utid:DEFAULT_TEST_UTID
                                                                           familyId:nil];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL tokenSetSuccessful = [self.tokenCache saveTokensWithConfiguration:configuration
                                                                  response:response
                                                                   factory:[MSIDAADV2Oauth2Factory new]
                                                                   context:nil
                                                                     error:nil];
    XCTAssertTrue(tokenSetSuccessful);
    
    // Add mock response for authority validation
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];
    
    // Acquire a token silently
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                    error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = self.tokenCache;
    
    [application setClientCapabilities:@[@"cp1"]];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"user.read"]
                                     account:account
                                   authority:nil
                                      claims:nil
                                forceRefresh:NO
                               correlationId:nil
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we return access token in cache
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"access_token");
         XCTAssertEqualObjects(result.authority.url.absoluteString, @"https://login.microsoftonline.com/" DEFAULT_TEST_UTID);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:5];
}

- (void)testAcquireTokenSilent_whenCapabilitiesSetAndExpiredAt_shouldSendCapabilitiesToServer
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    // Add an expired AT and valid RT to cache
    NSMutableDictionary *json = [MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                          RT:@"i am a refresh token!"
                                                                      scopes:[[NSOrderedSet alloc] initWithArray:@[@"user.read"]]
                                                                     idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                         uid:DEFAULT_TEST_UID
                                                                        utid:DEFAULT_TEST_UTID
                                                                    familyId:nil].jsonDictionary.mutableCopy;
    [json setValue:@"-1" forKey:MSID_OAUTH2_EXPIRES_IN];//expire the AT
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:json error:nil];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL tokenSetSuccessful = [self.tokenCache saveTokensWithConfiguration:configuration
                                                                  response:response
                                                                   factory:[MSIDAADV2Oauth2Factory new]
                                                                   context:nil
                                                                     error:nil];
    XCTAssertTrue(tokenSetSuccessful);
    
    // Add mock response for authority validation
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];
    
    // Add mock response for refresh token grant, claims should be in the request body
    NSString *expectedClaims =  @"{\"access_token\":{\"xms_cc\":{\"values\":[\"cp1\",\"llt\"]}}}";
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"user.read", @"openid", @"profile", @"offline_access"]];
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes
                                                                        authority:authority
                                                                         tenantId:nil
                                                                             user:account
                                                                           claims:expectedClaims];
    NSMutableDictionary *responseJson = [[response jsonDictionary] mutableCopy];
    responseJson[@"access_token"] = @"i am an updated access token!";
    responseJson[@"scope"] = [expectedScopes msidToString];
    [tokenResponse setResponseJSON:responseJson];
    [MSIDTestURLSession addResponses:@[tokenResponse]];
    
    // Acquire a token silently
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                    error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = self.tokenCache;
    
    [application setClientCapabilities:@[@"cp1", @"llt"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"user.read"]
                                     account:account
                                   authority:nil
                                      claims:nil
                                forceRefresh:NO
                               correlationId:nil
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we skip the old access token and get back a new one
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");
         XCTAssertEqualObjects(result.authority.url.absoluteString, @"https://login.microsoftonline.com/" DEFAULT_TEST_UTID);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:5];
}

- (void)testAcquireTokenSilent_whenClaimsIsPassedAndCapabilitiesSet_shouldSkipAtAndUseRt
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    // Add an AT and RT to cache
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                 RT:@"i am a refresh token!"
                                                                             scopes:[[NSOrderedSet alloc] initWithArray:@[@"user.read"]]
                                                                            idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                                uid:DEFAULT_TEST_UID
                                                                               utid:DEFAULT_TEST_UTID
                                                                           familyId:nil];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL tokenSetSuccessful = [self.tokenCache saveTokensWithConfiguration:configuration
                                                                  response:response
                                                                   factory:[MSIDAADV2Oauth2Factory new]
                                                                   context:nil
                                                                     error:nil];
    XCTAssertTrue(tokenSetSuccessful);
    
    // Add mock response for authority validation
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];
    
    // Add mock response for refresh token grant, claims should be in the request body
    NSString *claims = @"{\"access_token\":{\"polids\":{\"values\":[\"5ce770ea-8690-4747-aa73-c5b3cd509cd4\"],\"essential\":true}}}";
    NSString *expectedClaims = @"{\"access_token\":{\"polids\":{\"values\":[\"5ce770ea-8690-4747-aa73-c5b3cd509cd4\"],\"essential\":true},\"xms_cc\":{\"values\":[\"llt\"]}}}";
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"user.read", @"openid", @"profile", @"offline_access"]];
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes
                                                                        authority:authority
                                                                         tenantId:nil
                                                                             user:account
                                                                           claims:expectedClaims];
    NSMutableDictionary *json = [[response jsonDictionary] mutableCopy];
    json[@"access_token"] = @"i am an updated access token!";
    json[@"scope"] = [expectedScopes msidToString];
    [tokenResponse setResponseJSON:json];
    [MSIDTestURLSession addResponses:@[tokenResponse]];
    
    // Acquire a token silently
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                    error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = self.tokenCache;
    
    [application setClientCapabilities:@[@"llt"]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"user.read"]
                                     account:account
                                   authority:nil
                                      claims:claims
                                forceRefresh:NO
                               correlationId:nil
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we skip the old access token and get back a new one
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");
         XCTAssertEqualObjects(result.authority.url.absoluteString, @"https://login.microsoftonline.com/" DEFAULT_TEST_UTID);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:5];
}

- (void)testAcquireTokenSilent_whenClaimsIsPassedAndInvalidRt_shouldReturnInteractionRequired
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    // Add an AT and RT to cache
    MSIDAADV2TokenResponse *response = [MSIDTestTokenResponse v2TokenResponseWithAT:DEFAULT_TEST_ACCESS_TOKEN
                                                                                 RT:@"i am a refresh token!"
                                                                             scopes:[[NSOrderedSet alloc] initWithArray:@[@"user.read"]]
                                                                            idToken:[MSIDTestIdTokenUtil defaultV2IdToken]
                                                                                uid:DEFAULT_TEST_UID
                                                                               utid:DEFAULT_TEST_UTID
                                                                           familyId:nil];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL tokenSetSuccessful = [self.tokenCache saveTokensWithConfiguration:configuration
                                                                  response:response
                                                                   factory:[MSIDAADV2Oauth2Factory new]
                                                                   context:nil
                                                                     error:nil];
    XCTAssertTrue(tokenSetSuccessful);
    
    // Add mock response for authority validation
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];
    
    // Add mock error response for refresh token grant
    NSString *claims = @"{\"access_token\":{\"polids\":{\"values\":[\"5ce770ea-8690-4747-aa73-c5b3cd509cd4\"],\"essential\":true}}}";
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"user.read", @"openid", @"profile", @"offline_access"]];
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse errorRtResponseForScopes:expectedScopes
                                                                             authority:authority
                                                                              tenantId:nil
                                                                               account:account
                                                                             errorCode:@"invalid_grant"
                                                                      errorDescription:@"Refresh token revoked"
                                                                              subError:@"unauthorized_client"
                                                                                claims:claims
                                                                          refreshToken:nil];
    [MSIDTestURLSession addResponses:@[tokenResponse]];
    
    // Acquire a token silently
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                    error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = self.tokenCache;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"user.read"]
                                     account:account
                                   authority:nil
                                      claims:claims
                                forceRefresh:NO
                               correlationId:nil
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we skip the old access token and get back a new one
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

- (void)testAcquireTokenSilent_whenATExpiredAndFRTInCache_shouldRefreshAccessTokenUsingFRT
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
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL result = [self.tokenCache saveTokensWithConfiguration:configuration
                                                      response:response
                                                       factory:[MSIDAADV2Oauth2Factory new]
                                                       context:nil
                                                         error:nil];
    XCTAssertTrue(result);
    
    // Set up the network responses for OIDC discovery
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"user.read", @"openid", @"profile", @"offline_access"]];
    // Set up a 200 network responses
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes
                                                                        authority:authority
                                                                         tenantId:nil
                                                                             user:account
                                                                           claims:nil];
    [tokenResponse setResponseURL:@"https://someresponseurl.com" code:200 headerFields:@{}];
    
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse, tokenResponse]];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                               error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = self.tokenCache;
    [self removeRefreshTokenFromCache];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"user.read"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we get back access token with extendedLifetimeToken being NO
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testAcquireTokenSilent_whenATExpiredAndNoAppMetadataInCacheAndFRTInCache_shouldRefreshAccessTokenUsingFRT
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
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL result = [self.tokenCache saveTokensWithConfiguration:configuration
                                                      response:response
                                                       factory:[MSIDAADV2Oauth2Factory new]
                                                       context:nil
                                                         error:nil];
    XCTAssertTrue(result);
    
    // Set up the network responses for OIDC discovery
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"user.read", @"openid", @"profile", @"offline_access"]];
    
    // Set up a 200 network responses
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes
                                                                        authority:authority
                                                                         tenantId:nil
                                                                             user:account
                                                                           claims:nil];
    
    [tokenResponse setResponseURL:@"https://someresponseurl.com" code:200 headerFields:@{}];
    
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse, tokenResponse]];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                               error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = self.tokenCache;
    [self removeRefreshTokenFromCache];
    
    NSArray<MSIDAppMetadataCacheItem *> *metadataEntries = [self.tokenCache getAppMetadataEntries:configuration
                                                                                          context:nil
                                                                                            error:nil];
    
    XCTAssertEqual([metadataEntries count], 1);
    NSError *removeAppMTError = nil;
    BOOL removeAppMetadataResult = [self.accountCache removeAppMetadata:metadataEntries[0]
                                                                context:nil
                                                                  error:&removeAppMTError];
    XCTAssertNil(removeAppMTError);
    XCTAssertTrue(removeAppMetadataResult);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"user.read"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we get back access token with extendedLifetimeToken being NO
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testAcquireTokenSilent_whenFRTUsedAndServerReturnsClientMismatch_shouldUpdateAppMetadata
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
                                                                           familyId:@"1"];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    // Add AT, RT & FRT
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL result = [self.tokenCache saveTokensWithConfiguration:configuration
                                                      response:response
                                                       factory:[MSIDAADV2Oauth2Factory new]
                                                       context:nil
                                                         error:nil];
    XCTAssertTrue(result);
    
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                    error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = self.tokenCache;
    
    [self removeRefreshTokenFromCache];
    NSArray<MSIDAppMetadataCacheItem *> *metadataEntries = [self.tokenCache getAppMetadataEntries:configuration
                                                                                          context:nil
                                                                                            error:nil];
    
    XCTAssertEqual([metadataEntries count], 1);
    MSIDAppMetadataCacheItem *appMetadata = metadataEntries[0];
    XCTAssertEqualObjects(appMetadata.familyId, @"1");
    
    // Set up the network responses for OIDC discovery and the RT response
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"mail.read", @"openid", @"profile", @"offline_access"]];
    
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse errorRtResponseForScopes:expectedScopes
                                                                             authority:authority
                                                                              tenantId:nil account:account
                                                                             errorCode:@"invalid_grant"
                                                                      errorDescription:@"Refresh token revoked"
                                                                              subError:@"client_mismatch"
                                                                                claims:nil
                                                                          refreshToken:nil];
    
    [MSIDTestURLSession addResponses:@[tokenResponse]];
    
    // Acquire a token silently for a scope that does not exist in cache
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"mail.read"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we get back the proper access token
         NSArray<MSIDAppMetadataCacheItem *> *metadataEntries = [self.tokenCache getAppMetadataEntries:configuration
                                                                                               context:nil
                                                                                                 error:nil];
         
         XCTAssertEqual([metadataEntries count], 1);
         MSIDAppMetadataCacheItem *appMetadata = metadataEntries[0];
         XCTAssertEqualObjects(appMetadata.familyId,@"");
         XCTAssertNotNil(error);
         XCTAssertNil(result);
         XCTAssertEqual(error.code, MSALErrorInteractionRequired);
         XCTAssertEqualObjects(error.userInfo[MSALErrorDescriptionKey], @"User interaction is required");
         XCTAssertEqualObjects(error.userInfo[MSALOAuthErrorKey], @"invalid_grant");
         XCTAssertEqualObjects(error.userInfo[MSALOAuthSubErrorKey], @"client_mismatch");
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:5];
}

- (void)testAcquireTokenSilent_whenFRTUsedAndServerReturnsInvalidGrant_ShouldUseMRRTToRefreshAccessToken
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
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL result = [self.tokenCache saveTokensWithConfiguration:configuration
                                                      response:response
                                                       factory:[MSIDAADV2Oauth2Factory new]
                                                       context:nil
                                                         error:nil];
    XCTAssertTrue(result);

    MSIDRefreshToken *frt = [self.tokenCache getRefreshTokenWithAccount:account.lookupAccountIdentifier
                                                               familyId:@"1"
                                                          configuration:configuration
                                                                context:nil
                                                                  error:nil];
    // Update FRT entry so that MRRT and FRT are not the same, otherwise it will skip MRRT
    frt.refreshToken = @"updated frt token";
    [self.accountCache saveCredential:frt.tokenCacheItem context:nil error:nil];
    
    // Set up the network responses for OIDC discovery
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"user.read", @"openid", @"profile", @"offline_access"]];
    // Set up a 200 network responses
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes
                                                                        authority:authority
                                                                         tenantId:nil
                                                                             user:account
                                                                           claims:nil];
    
    [tokenResponse setResponseURL:@"https://someresponseurl.com" code:200 headerFields:@{}];
    
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    MSIDTestURLResponse *errorResponse = [MSIDTestURLResponse errorRtResponseForScopes:expectedScopes
                                                                             authority:authority
                                                                              tenantId:nil
                                                                               account:account
                                                                             errorCode:@"invalid_grant"
                                                                      errorDescription:@"Refresh token revoked"
                                                                              subError:@"client_mismatch"
                                                                                claims:nil
                                                                          refreshToken:@"updated frt token"];
    
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse, errorResponse, tokenResponse]];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                               error:&error];
    XCTAssertNotNil(application);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"user.read"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we get back access token with extendedLifetimeToken being NO
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:100];
}

- (void)testAcquireTokenSilent_whenNoFRTInCache_ShouldUseMRRTToRefreshAccessToken
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
    [json setObject:@"-3600" forKey:MSID_OAUTH2_EXPIRES_IN];
    MSIDAADV2TokenResponse *response = [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:json error:nil];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"preferredUserName"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    MSIDConfiguration *configuration = [MSIDTestConfiguration v2DefaultConfiguration];
    
    configuration.clientId = UNIT_TEST_CLIENT_ID;
    BOOL result = [self.tokenCache saveTokensWithConfiguration:configuration
                                                      response:response
                                                       factory:[MSIDAADV2Oauth2Factory new]
                                                       context:nil
                                                         error:nil];
    XCTAssertTrue(result);
    
    // Set up the network responses for OIDC discovery
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"user.read", @"openid", @"profile", @"offline_access"]];
    // Set up a 200 network responses
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes
                                                                        authority:authority
                                                                         tenantId:nil
                                                                             user:account
                                                                           claims:nil];
    
    [tokenResponse setResponseURL:@"https://someresponseurl.com" code:200 headerFields:@{}];
    
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse, tokenResponse]];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                               error:&error];
    XCTAssertNotNil(application);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"user.read"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we get back access token with extendedLifetimeToken being NO
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");
         [expectation fulfill];
     }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

#pragma mark - Helpers

- (void)addTestTokenResponseWithResponseScopes:(NSString *)responseScopes
                             requestParamsBody:(NSDictionary *)requestParamsBody
                                     authority:(NSString *)authority
{
    NSDictionary *clientInfo = @{ @"uid" : @"1", @"utid" : [MSIDTestIdTokenUtil defaultTenantId]};
    
    // Token request response.
    NSMutableDictionary *reqHeaders = [[MSIDTestURLResponse msalDefaultRequestHeaders] mutableCopy];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    
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
                                             @"id_token" : [MSIDTestIdTokenUtil defaultV2IdToken],
                                             @"id_token_expires_in" : @"1200",
                                             @"client_info" : [clientInfo msidBase64UrlJson],
                                             MSID_OAUTH2_SCOPE: responseScopes
                                             }];
    
    [MSIDTestURLSession addResponse:tokenResponse];
}

- (void)removeRefreshTokenFromCache
{
    NSArray *allTokens = [self.tokenCache allTokensWithContext:nil error:nil];
    NSMutableArray *results = [NSMutableArray array];
    for (MSIDBaseToken *token in allTokens)
    {
        if (token.credentialType == MSIDRefreshTokenType)
        {
            MSIDRefreshToken *refreshToken = (MSIDRefreshToken *)token;
            if ([NSString msidIsStringNilOrBlank:refreshToken.familyId])
            {
                [results addObject:token];
            }
        }
    }
    
    XCTAssertEqual([results count], 1);
    MSIDRefreshToken *refreshToken = results[0];
    NSError *removeRTError = nil;
    //remove RT from cache
    BOOL removeRTResult = [self.tokenCache validateAndRemoveRefreshToken:refreshToken context:nil error:&removeRTError];
    XCTAssertNil(removeRTError);
    XCTAssertTrue(removeRTResult);
}

@end
