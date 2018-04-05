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
#import "MSALTestCacheDataUtil.h"
#import "MSALTestConstants.h"
#import "MSALTestSwizzle.h"
#import "MSIDTestURLSession+MSAL.h"
#import "MSALWebUI.h"

#import "NSURL+MSIDExtensions.h"
#import "MSIDDeviceId.h"
#import "MSIDTestURLResponse.h"

#import "MSALPublicClientApplication+Internal.h"
#import "MSIDTestURLSession+MSAL.h"
#import "MSIDTestURLSession.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDTestURLResponse+MSAL.h"
#import "MSIDAccessToken.h"
#import "MSIDSharedTokenCache.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccount.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDTestRequestParams.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDTestCacheIdentifiers.h"
#import "MSALUser+Internal.h"
#import "MSIDClientInfo.h"
#import "MSIDTestIdTokenUtil.h"
#import "MSALIdToken.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#import "MSIDMacTokenCache.h"
#import "MSIDAADV2Oauth2Strategy.h"

@interface MSALAcquireTokenTests : MSALTestCase

@end

@implementation MSALAcquireTokenTests

- (void)setUp
{
    [super setUp];
    
#if TARGET_OS_IPHONE
    [MSIDKeychainTokenCache reset];
#endif
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
    
    // Swizzle out the main entry point for WebUI, WebUI is tested in its own component tests
    [MSALTestSwizzle classMethod:@selector(startWebUIWithURL:context:completionBlock:)
                           class:[MSALWebUI class]
                           block:(id)^(id obj, NSURL *url, id<MSALRequestContext>context, MSALWebUICompletionBlock completionBlock)
     {
         (void)obj;
         (void)context;
         
         XCTAssertNotNil(url);
         XCTAssertEqualObjects(url.scheme, @"https");
         XCTAssertEqualObjects(url.msidHostWithPortIfNecessary, @"login.microsoftonline.com");
         XCTAssertEqualObjects(url.path, @"/contosob2c/v2.0/oauth/authorize");
         NSMutableDictionary *expectedQPs =
         [@{
           @"return-client-request-id" : [MSIDTestRequireValueSentinel sentinel],
           @"state" : [MSIDTestRequireValueSentinel sentinel],
           @"prompt" : @"select_account",
           @"client_id" : UNIT_TEST_CLIENT_ID,
           @"scope" : @"fakeb2cscopes openid profile offline_access",
           @"redirect_uri" : UNIT_TEST_DEFAULT_REDIRECT_URI,
           @"response_type" : @"code",
           @"code_challenge": [MSIDTestRequireValueSentinel sentinel],
           @"code_challenge_method" : @"S256",
           @"p" : @"b2c_1_policy",
           UT_SLICE_PARAMS_DICT
           } mutableCopy];
         [expectedQPs addEntriesFromDictionary:[MSIDDeviceId deviceId]];
         NSDictionary *QPs = [NSDictionary msidURLFormDecode:url.query];
         XCTAssertTrue([expectedQPs compareAndPrintDiff:QPs]);
         
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=%@&state=%@", @"i+am+an+auth+code", QPs[@"state"]];
         completionBlock([NSURL URLWithString:responseString], nil);
     }];
    
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:[MSALTestCacheDataUtil defaultClientId]
                                                authority:authority
                                                    error:&error];
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
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
    
    id<MSIDTokenCacheDataSource> dataSource;
#if TARGET_OS_IPHONE
    dataSource = MSIDKeychainTokenCache.defaultKeychainCache;
#else
    dataSource = MSIDMacTokenCache.defaultCache;
#endif
    MSIDDefaultTokenCacheAccessor *cacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource];
    MSIDSharedTokenCache *tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:cacheAccessor otherCacheAccessors:nil];
    
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
    __auto_type idToken = [[MSALIdToken alloc] initWithRawIdToken:[MSIDTestIdTokenUtil defaultV2IdToken]];
    
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:nil
                                                        uniqueUserId:clientInfo.userIdentifier];
    MSALUser *user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:account.authority.msidHostWithPortIfNecessary];
    
    // Add AT & RT.
    MSIDRequestParameters *requestParams = [MSIDTestRequestParams v2DefaultParams];
    requestParams.clientId = [MSALTestCacheDataUtil defaultClientId];
    MSIDAADV2Oauth2Strategy *strategy = [MSIDAADV2Oauth2Strategy new];
    BOOL result = [tokenCache saveTokensWithStrategy:strategy
                                       requestParams:requestParams
                                            response:response
                                             context:nil
                                               error:nil];
    XCTAssertTrue(result);
    
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:[MSALTestCacheDataUtil defaultClientId]
                                                    error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = tokenCache;

    // Set up the network responses for OIDC discovery and the RT response
    NSString *authority = @"https://login.microsoftonline.com/1234-5678-90abcdefg";
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"mail.read", @"openid", @"profile", @"offline_access"]];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    MSIDTestURLResponse *tokenResponse = [MSIDTestURLResponse rtResponseForScopes:expectedScopes authority:authority tenantId:nil user:user];
    NSMutableDictionary *json = [[response jsonDictionary] mutableCopy];
    json[@"access_token"] = @"i am an updated access token!";
    [tokenResponse setResponseJSON:json];
    [MSIDTestURLSession addResponses:@[oidcResponse, tokenResponse]];

    // Acquire a token silently for a scope that does not exist in cache
    XCTestExpectation *expectation = [self expectationWithDescription:@"acquireTokenSilentForScopes"];
    [application acquireTokenSilentForScopes:@[@"mail.read"]
                                        user:user
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we get back the proper access token
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");

         [expectation fulfill];
     }];

    [self waitForExpectations:@[expectation] timeout:1];
}

@end
