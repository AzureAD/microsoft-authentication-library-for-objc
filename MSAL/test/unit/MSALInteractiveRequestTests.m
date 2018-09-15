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

#import "MSALBaseRequest+TestExtensions.h"
#import "MSALTestBundle.h"
#import "MSALTestIdTokenUtil.h"
#import "MSALTestSwizzle.h"
#import "MSIDTestURLSession+MSAL.h"
#import "MSALAccount.h"
#import "NSURL+MSIDExtensions.h"
#import "MSALTestConstants.h"
#import "MSIDDeviceId.h"
#import "MSIDTestURLSession.h"
#import "MSIDTestURLResponse.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#import "MSIDMacTokenCache.h"
#import "MSALAccount+Internal.h"
#import "MSALAccountId.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "NSString+MSALTestUtil.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDTestURLResponse+MSAL.h"
#import "MSIDTestURLResponse+MSAL.h"
#import "MSIDWebviewAuthorization.h"
#import "MSIDWebAADAuthResponse.h"

@interface MSALInteractiveRequestTests : MSALTestCase

@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCacheAccessor;

@end

@implementation MSALInteractiveRequestTests

- (void)setUp
{
    [super setUp];

#if TARGET_OS_IPHONE
    self.tokenCacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache otherCacheAccessors:nil factory:[MSIDAADV2Oauth2Factory new]];
#else
    self.tokenCacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:[MSIDMacTokenCache new] otherCacheAccessors:nil];
#endif

    [self.tokenCacheAccessor clearWithContext:nil error:nil];

    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = @"v2.0";
}

- (void)tearDown
{
    [super tearDown];

    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = nil;
}

#pragma mark - Tests

- (void)testInitWithParameters_whenValidParams_shouldInit
{
    NSError *error = nil;

    __block NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/common" authority];
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;

    MSALInteractiveRequest *request =
    [[MSALInteractiveRequest alloc] initWithParameters:parameters
                                      extraScopesToConsent:@[@"fakescope3"]
                                              behavior:MSALForceConsent
                                            tokenCache:nil
                                                 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);
}

- (void)testInteractiveRequestFlow_whenValid_shouldReturnResultWithNoError
{
    NSError *error = nil;

    __block NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSIDTestURLSession createMockSession];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/common" authority];
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.webviewType = MSALWebviewTypeWKWebView;
    
    __block MSALInteractiveRequest *request =
    [[MSALInteractiveRequest alloc] initWithParameters:parameters
                                  extraScopesToConsent:@[@"fakescope3"]
                                              behavior:MSALForceConsent
                                            tokenCache:self.tokenCacheAccessor
                                                 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    // Setting MSALAuthority ahead of time short-circuits authority validation for this test
    request.authority = parameters.unvalidatedAuthority;

    // Swizzle out the main entry point for WebUI, WebUI is tested in its own component tests
    [MSALTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(id obj, MSIDWebviewConfiguration *configuration, MSIDOauth2Factory *oauth2Factory, WKWebView *webview, id<MSIDRequestContext>context, MSIDWebviewAuthCompletionHandler completionHandler)
     {
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=iamafakecode"];
         
         MSIDWebAADAuthResponse *oauthResponse = [[MSIDWebAADAuthResponse alloc] initWithURL:[NSURL URLWithString:responseString]
                                                                                    context:nil error:nil];
         completionHandler(oauthResponse, nil);
     }];

    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];
    
    NSString *url = @"https://login.microsoftonline.com/common/oauth2/v2.0/token";

    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:url
                           requestHeaders:reqHeaders
                        requestParamsBody:@{ @"code" : @"iamafakecode",
                                             @"client_id" : UNIT_TEST_CLIENT_ID,
                                             @"scope" : @"fakescope1 fakescope2 openid profile offline_access",
                                             @"redirect_uri" : UNIT_TEST_DEFAULT_REDIRECT_URI,
                                             @"grant_type" : @"authorization_code",
                                             @"code_verifier" : [MSIDTestRequireValueSentinel sentinel],
                                             @"client_info" : @"1"}
                        responseURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"access_token" : @"i am a access token!",
                                             @"expires_in" : @"600",
                                             @"refresh_token" : @"i am a refresh token",
                                             @"id_token" : [MSALTestIdTokenUtil defaultIdToken],
                                             @"id_token_expires_in" : @"1200",
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson],
                                             @"scope": @"fakescope1 fakescope2 openid profile offline_access"
                                             }];

    [response->_requestHeaders removeObjectForKey:@"Content-Length"];

    [MSIDTestURLSession addResponse:response];

    NSString *authority = @"https://login.microsoftonline.com/common";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Run request."];
    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNotNil(result);
         XCTAssertNil(error);
         XCTAssertNotNil(result.account);
         XCTAssertEqualObjects(result.account.homeAccountId.objectId, @"1");
         XCTAssertEqualObjects(result.account.homeAccountId.tenantId, @"1234-5678-90abcdefg");
         XCTAssertEqualObjects(result.account.name, [MSALTestIdTokenUtil defaultName]);
         XCTAssertEqualObjects(result.account.username, [MSALTestIdTokenUtil defaultUsername]);
         XCTAssertNotNil(result.tenantId);
         XCTAssertEqualObjects(result.tenantId, [MSALTestIdTokenUtil defaultTenantId]);
         XCTAssertNotNil(result.accessToken);
         XCTAssertEqualObjects(result.accessToken, @"i am a access token!");
         XCTAssertNil(error);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

// TODO: Re-introduce after instance aware flow
//- (void)testInteractiveRequestFlow_whenValidWithCloudHostName_shouldReturnResultWithNoError
//{
//    NSError *error = nil;
//    
//    __block NSUUID *correlationId = [NSUUID new];
//    
//    MSALRequestParameters *parameters = [MSALRequestParameters new];
//    parameters.urlSession = [MSIDTestURLSession createMockSession];
//    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
//    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
//    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
//    parameters.clientId = UNIT_TEST_CLIENT_ID;
//    parameters.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
//    parameters.loginHint = @"fakeuser@contoso.com";
//    parameters.correlationId = correlationId;
//    parameters.webviewType = MSALWebviewTypeWKWebView;
//    
//    __block MSALInteractiveRequest *request =
//    [[MSALInteractiveRequest alloc] initWithParameters:parameters
//                                  extraScopesToConsent:@[@"fakescope3"]
//                                              behavior:MSALForceConsent
//                                            tokenCache:self.tokenCacheAccessor
//                                                 error:&error];
//    
//    XCTAssertNotNil(request);
//    XCTAssertNil(error);
//    
//    // Setting MSALAuthority ahead of time short-circuits authority validation for this test
//    request.authority = [MSALTestAuthority AADAuthority:parameters.unvalidatedAuthority];
//    
//    // Swizzle out the main entry point for WebUI, WebUI is tested in its own component tests
//    [MSALTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
//                           class:[MSIDWebviewAuthorization class]
//                           block:(id)^(id obj, MSIDWebviewConfiguration *configuration, MSIDOauth2Factory *oauth2Factory, WKWebView *webview, id<MSIDRequestContext>context, MSIDWebviewAuthCompletionHandler completionHandler)
//     {
//         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=iamafakecode&cloud_instance_host_name=https%%3A%%2F%%2Fcloudhost.com"];
//         
//         MSIDWebAADAuthResponse *oauthResponse = [[MSIDWebAADAuthResponse alloc] initWithURL:[NSURL URLWithString:responseString]
//                                                                                     context:nil error:nil];
//    
//         completionHandler(oauthResponse, nil);
//     }];
//    
//    [MSALTestSwizzle classMethod:@selector(resolveEndpointsForAuthority:userPrincipalName:validate:context:completionBlock:)
//                           class:[MSALAuthority class]
//                           block:(id)^(id obj, NSURL *unvalidatedAuthority, NSString *userPrincipalName, BOOL validate, id<MSALRequestContext> context, MSALAuthorityCompletion completionBlock)
//     
//     {
//         (void)obj;
//         (void)context;
//         (void)userPrincipalName;
//         (void)validate;
//         
//         completionBlock([MSALTestAuthority AADAuthority:unvalidatedAuthority], nil);
//     }];
//    
//    [MSALTestSwizzle instanceMethod:@selector(codeVerifier) class:[MSIDPkce class] block:(id)^(id obj) { return @"code_verifier"; }];
//    
//    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
//    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
//    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
//    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
//    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];
//    
//    MSIDTestURLResponse *response =
//    [MSIDTestURLResponse requestURLString:@"https://cloudhost.com/common/oauth2/v2.0/token"
//                           requestHeaders:reqHeaders
//                        requestParamsBody:@{ @"code" : @"iamafakecode",
//                                             @"client_id" : UNIT_TEST_CLIENT_ID,
//                                             @"scope" : @"fakescope1 fakescope2 openid profile offline_access",
//                                             @"redirect_uri" : UNIT_TEST_DEFAULT_REDIRECT_URI,
//                                             @"grant_type" : @"authorization_code",
//                                             @"code_verifier" : @"code_verifier",
//                                             @"client_info" : @"1"}
//                        responseURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
//                             responseCode:200
//                         httpHeaderFields:nil
//                         dictionaryAsJSON:@{ @"access_token" : @"i am a access token!",
//                                             @"expires_in" : @"600",
//                                             @"refresh_token" : @"i am a refresh token",
//                                             @"id_token" : [MSALTestIdTokenUtil defaultIdToken],
//                                             @"id_token_expires_in" : @"1200",
//                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson]}];
//    
//    [response->_requestHeaders removeObjectForKey:@"Content-Length"];
//    
//    [MSIDTestURLSession addResponse:response];
//    
//    __block dispatch_semaphore_t dsem = dispatch_semaphore_create(0);
//    __block BOOL fAlreadyHit = NO;
//    [request run:^(MSALResult *result, NSError *error)
//     {
//         XCTAssertFalse(fAlreadyHit);
//         fAlreadyHit = YES;
//         XCTAssertNotNil(result);
//         XCTAssertNil(error);
//         XCTAssertNotNil(result.account);
//         XCTAssertEqualObjects(result.account.homeAccountId.objectId, @"1");
//         XCTAssertEqualObjects(result.account.homeAccountId.tenantId, @"1234-5678-90abcdefg");
//         XCTAssertEqualObjects(result.account.name, [MSALTestIdTokenUtil defaultName]);
//         XCTAssertEqualObjects(result.account.username, [MSALTestIdTokenUtil defaultUsername]);
//         XCTAssertNotNil(result.tenantId);
//         XCTAssertEqualObjects(result.tenantId, [MSALTestIdTokenUtil defaultTenantId]);
//         XCTAssertNotNil(result.accessToken);
//         XCTAssertEqualObjects(result.accessToken, @"i am a access token!");
//         XCTAssertNil(error);
//         
//         dispatch_semaphore_signal(dsem);
//     }];
//    
//    while (dispatch_semaphore_wait(dsem, DISPATCH_TIME_NOW))
//    {
//        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate: [NSDate distantFuture]];
//    }
//}


- (void)testInteractiveRequestFlow_whenValidWithUser_shouldReturnResultWithNoError
{
    NSError *error = nil;

    __block NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSIDTestURLSession createMockSession];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/common" authority];
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    parameters.correlationId = correlationId;
    parameters.webviewType = MSALWebviewTypeWKWebView;
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"User"
                                                                 name:@"user@contoso.com"
                                                        homeAccountId:@"1.1234-5678-90abcdefg"
                                                       localAccountId:@"1"
                                                          environment:@"login.microsoftonline.com"
                                                             tenantId:@"1234-5678-90abcdefg"
                                                           clientInfo:nil];
    parameters.account = account;

    __block MSALInteractiveRequest *request =
    [[MSALInteractiveRequest alloc] initWithParameters:parameters
                                      extraScopesToConsent:@[@"fakescope3"]
                                              behavior:MSALForceConsent
                                            tokenCache:self.tokenCacheAccessor
                                                 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    // Setting MSALAuthority ahead of time short-circuits authority validation for this test
    request.authority = parameters.unvalidatedAuthority;

    // Swizzle out the main entry point for WebUI, WebUI is tested in its own component tests
    [MSALTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(id obj, MSIDWebviewConfiguration *configuration, MSIDOauth2Factory *oauth2Factory, WKWebView *webview, id<MSIDRequestContext>context, MSIDWebviewAuthCompletionHandler completionHandler)
     {
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=iamafakecode"];
         
         MSIDWebAADAuthResponse *oauthResponse = [[MSIDWebAADAuthResponse alloc] initWithURL:[NSURL URLWithString:responseString]
                                                                                   context:nil error:nil];
         completionHandler(oauthResponse, nil);
     }];

    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];

    NSString *url = @"https://login.microsoftonline.com/common/oauth2/v2.0/token";

    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:url
                           requestHeaders:reqHeaders
                        requestParamsBody:@{ @"code" : @"iamafakecode",
                                             @"client_id" : UNIT_TEST_CLIENT_ID,
                                             @"scope" : @"fakescope1 fakescope2 openid profile offline_access",
                                             @"redirect_uri" : UNIT_TEST_DEFAULT_REDIRECT_URI,
                                             @"grant_type" : @"authorization_code",
                                             @"code_verifier" : [MSIDTestRequireValueSentinel sentinel],
                                             @"client_info" : @"1"}
                        responseURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"access_token" : @"i am a access token!",
                                             @"expires_in" : @"600",
                                             @"refresh_token" : @"i am a refresh token",
                                             @"id_token" : [MSALTestIdTokenUtil defaultIdToken],
                                             @"id_token_expires_in" : @"1200",
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson],
                                             @"scope": @"fakescope1 fakescope2"
                                             }];

    [response->_requestHeaders removeObjectForKey:@"Content-Length"];

    [MSIDTestURLSession addResponse:response];

    NSString *authority = @"https://login.microsoftonline.com/common";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Run request."];

    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNotNil(result);
         XCTAssertNil(error);
         XCTAssertNotNil(result.account);
         XCTAssertEqualObjects(result.account.homeAccountId.objectId, @"1");
         XCTAssertEqualObjects(result.account.homeAccountId.tenantId, @"1234-5678-90abcdefg");
         XCTAssertEqualObjects(result.account.name, [MSALTestIdTokenUtil defaultName]);
         XCTAssertEqualObjects(result.account.username, [MSALTestIdTokenUtil defaultUsername]);
         XCTAssertEqualObjects(result.account.environment, @"login.microsoftonline.com");
         XCTAssertNotNil(result.tenantId);
         XCTAssertEqualObjects(result.tenantId, [MSALTestIdTokenUtil defaultTenantId]);
         XCTAssertNotNil(result.idToken);
         XCTAssertEqualObjects(result.idToken, [MSALTestIdTokenUtil defaultIdToken]);
         XCTAssertNotNil(result.uniqueId);
         XCTAssertEqualObjects(result.uniqueId, [MSALTestIdTokenUtil defaultUniqueId]);
         XCTAssertNotNil(result.accessToken);
         XCTAssertEqualObjects(result.accessToken, @"i am a access token!");
         XCTAssertNil(error);
         XCTAssertNotNil(result.scopes);
         XCTAssertEqual([result.scopes count], 2);
         XCTAssertEqualObjects(result.scopes, (@[@"fakescope1", @"fakescope2"]));
         XCTAssertNotNil(result.expiresOn);
         XCTAssertEqualWithAccuracy([result.expiresOn timeIntervalSinceDate:[NSDate date]], 600, 10);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testInteractiveRequestFlow_whenUserMismatch_shouldReturnNilResultWithError
{
    NSError *error = nil;

    __block NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSIDTestURLSession createMockSession];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/common" authority];
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    parameters.correlationId = correlationId;
    parameters.webviewType = MSALWebviewTypeWKWebView;
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"User"
                                                            name:@"user@contoso.com"
                                                   homeAccountId:@"2.1234-5678-90abcdefg"
                                                  localAccountId:@"2"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:nil];
    parameters.account = account;

    __block MSALInteractiveRequest *request =
    [[MSALInteractiveRequest alloc] initWithParameters:parameters
                                      extraScopesToConsent:@[@"fakescope3"]
                                              behavior:MSALForceConsent
                                            tokenCache:self.tokenCacheAccessor
                                                 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    // Setting MSALAuthority ahead of time short-circuits authority validation for this test
    request.authority = parameters.unvalidatedAuthority;

    // Swizzle out the main entry point for WebUI, WebUI is tested in its own component tests
    [MSALTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(id obj, MSIDWebviewConfiguration *configuration, MSIDOauth2Factory *oauth2Factory, WKWebView *webview, id<MSIDRequestContext>context, MSIDWebviewAuthCompletionHandler completionHandler)
     {
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=iamafakecode"];
         
         MSIDWebAADAuthResponse *oauthResponse = [[MSIDWebAADAuthResponse alloc] initWithURL:[NSURL URLWithString:responseString]
                                                                                   context:nil error:nil];
         completionHandler(oauthResponse, nil);
     }];

    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];

    NSString *url = @"https://login.microsoftonline.com/common/oauth2/v2.0/token";

    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:url
                           requestHeaders:reqHeaders
                        requestParamsBody:@{ @"code" : @"iamafakecode",
                                             @"client_id" : UNIT_TEST_CLIENT_ID,
                                             @"scope" : @"fakescope1 fakescope2 openid profile offline_access",
                                             @"redirect_uri" : UNIT_TEST_DEFAULT_REDIRECT_URI,
                                             @"grant_type" : @"authorization_code",
                                             @"code_verifier" : [MSIDTestRequireValueSentinel sentinel],
                                             @"client_info" : @"1"}
                        responseURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"access_token" : @"i am a access token!",
                                             @"expires_in" : @"600",
                                             @"refresh_token" : @"i am a refresh token",
                                             @"id_token" : [MSALTestIdTokenUtil defaultIdToken],
                                             @"id_token_expires_in" : @"1200",
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson],
                                             @"scope": @"fakescope1 fakescope2"
                                             }];

    [response->_requestHeaders removeObjectForKey:@"Content-Length"];

    [MSIDTestURLSession addResponse:response];

    NSString *authority = @"https://login.microsoftonline.com/common";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Run request."];
    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
         XCTAssertEqual(error.code, MSALErrorMismatchedUser);

         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testInteractiveRequestFlow_whenNoAccessTokenReturned_shouldReturnError
{
    NSError *error = nil;

    __block NSUUID *correlationId = [NSUUID new];

    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSIDTestURLSession createMockSession];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [@"https://login.microsoftonline.com/common" authority];
    parameters.redirectUri = UNIT_TEST_DEFAULT_REDIRECT_URI;
    parameters.clientId = UNIT_TEST_CLIENT_ID;
    parameters.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.webviewType = MSALWebviewTypeWKWebView;

    __block MSALInteractiveRequest *request =
    [[MSALInteractiveRequest alloc] initWithParameters:parameters
                                  extraScopesToConsent:@[@"fakescope3"]
                                              behavior:MSALForceConsent
                                            tokenCache:self.tokenCacheAccessor
                                                 error:&error];

    XCTAssertNotNil(request);
    XCTAssertNil(error);

    // Setting MSALAuthority ahead of time short-circuits authority validation for this test
    request.authority = parameters.unvalidatedAuthority;

    // Swizzle out the main entry point for WebUI, WebUI is tested in its own component tests
    [MSALTestSwizzle classMethod:@selector(startEmbeddedWebviewAuthWithConfiguration:oauth2Factory:webview:context:completionHandler:)
                           class:[MSIDWebviewAuthorization class]
                           block:(id)^(id obj, MSIDWebviewConfiguration *configuration, MSIDOauth2Factory *oauth2Factory, WKWebView *webview, id<MSIDRequestContext>context, MSIDWebviewAuthCompletionHandler completionHandler)
     {
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=iamafakecode"];
         
         MSIDWebAADAuthResponse *oauthResponse = [[MSIDWebAADAuthResponse alloc] initWithURL:[NSURL URLWithString:responseString]
                                                                                   context:nil error:nil];
         completionHandler(oauthResponse, nil);
     }];

    NSMutableDictionary *reqHeaders = [[MSIDDeviceId deviceId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];
   
    NSString *url = @"https://login.microsoftonline.com/common/oauth2/v2.0/token";

    MSIDTestURLResponse *response =
    [MSIDTestURLResponse requestURLString:url
                           requestHeaders:reqHeaders
                        requestParamsBody:@{ @"code" : @"iamafakecode",
                                             @"client_id" : UNIT_TEST_CLIENT_ID,
                                             @"scope" : @"fakescope1 fakescope2 openid profile offline_access",
                                             @"redirect_uri" : UNIT_TEST_DEFAULT_REDIRECT_URI,
                                             @"grant_type" : @"authorization_code",
                                             @"code_verifier" : [MSIDTestRequireValueSentinel sentinel],
                                             @"client_info" : @"1"}
                        responseURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"refresh_token" : @"i am a refresh token",
                                             @"id_token" : [MSALTestIdTokenUtil defaultIdToken],
                                             @"id_token_expires_in" : @"1200",
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson]}];

    [response->_requestHeaders removeObjectForKey:@"Content-Length"];

    [MSIDTestURLSession addResponse:response];

    NSString *authority = @"https://login.microsoftonline.com/common";
    MSIDTestURLResponse *discoveryResponse = [MSIDTestURLResponse discoveryResponseForAuthority:authority];
    MSIDTestURLResponse *oidcResponse = [MSIDTestURLResponse oidcResponseForAuthority:authority];
    [MSIDTestURLSession addResponses:@[discoveryResponse, oidcResponse]];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Run request."];
    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);

         XCTAssertEqual(error.code, MSALErrorInternal);
         [expectation fulfill];
     }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}


@end
