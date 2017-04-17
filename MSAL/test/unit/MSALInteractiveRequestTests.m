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

#import "NSDictionary+MSALTestUtil.h"
#import "NSString+MSALHelperMethods.h"
#import "MSALBaseRequest+TestExtensions.h"
#import "MSALPkce.h"
#import "MSALTestAuthority.h"
#import "MSALTestBundle.h"
#import "MSALTestIdTokenUtil.h"
#import "MSALTestTokenCache.h"
#import "MSALTestSwizzle.h"
#import "MSALTestURLSession.h"
#import "MSALUser.h"
#import "MSALWebUI.h"


@interface MSALInteractiveRequestTests : MSALTestCase

@end

@implementation MSALInteractiveRequestTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInit
{
    NSError *error = nil;
    
    __block NSUUID *correlationId = [NSUUID new];
    
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:@"x-msauth-com-microsoft-unittests://com.microsoft.unittests"];
    parameters.clientId = @"b92e0ba5-f86e-4411-8e18-6b5f928d968a";
    parameters.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    
    MSALInteractiveRequest *request =
    [[MSALInteractiveRequest alloc] initWithParameters:parameters
                                      additionalScopes:@[@"fakescope3"]
                                              behavior:MSALForceConsent
                                                 error:&error];
    
    XCTAssertNotNil(request);
    XCTAssertNil(error);
}

- (void)testAuthorizationUri
{
    NSError *error = nil;
    
    __block NSUUID *correlationId = [NSUUID new];
    
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:@"x-msauth-com-microsoft-unittests://com.microsoft.unittests"];
    parameters.clientId = @"b92e0ba5-f86e-4411-8e18-6b5f928d968a";
    parameters.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;

    [MSALTestSwizzle classMethod:@selector(randomUrlSafeStringOfSize:)
                              class:[NSString class]
                              block:(id)^(id obj, NSUInteger size)
     {
         (void)obj;
         (void)size;
         return @"randomValue";
     }];
    
    MSALPkce *pkce = [MSALPkce new];
    
    MSALInteractiveRequest *request =
    [[MSALInteractiveRequest alloc] initWithParameters:parameters
                                      additionalScopes:@[@"fakescope3"]
                                              behavior:MSALForceLogin
                                                 error:&error];
    
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    
    request.authority = [MSALTestAuthority AADAuthority:parameters.unvalidatedAuthority];
    
    NSURL *authorizationUrl = [request authorizationUrl];
    XCTAssertNotNil(authorizationUrl);
    XCTAssertEqualObjects(authorizationUrl.scheme, @"https");
    XCTAssertEqualObjects(authorizationUrl.host, @"login.microsoftonline.com");
    XCTAssertEqualObjects(authorizationUrl.path, @"/common/oauth2/v2.0/authorize");
    
    NSDictionary *msalId = [MSALLogger msalId];
    NSDictionary *expectedQPs =
    @{
      @"x-client-Ver" : MSAL_VERSION_NSSTRING,
#if TARGET_OS_IPHONE
      @"x-client-SKU" : @"iOS",
      @"x-client-DM" : msalId[@"x-client-DM"],
#else
      @"x-client-SKU" : @"OSX",
#endif
      @"x-client-OS" : msalId[@"x-client-OS"],
      @"x-client-CPU" : msalId[@"x-client-CPU"],
      @"return-client-request-id" : correlationId.UUIDString,
      @"state" : request.state,
      @"login_hint" : @"fakeuser@contoso.com",
      @"client_id" : @"b92e0ba5-f86e-4411-8e18-6b5f928d968a",
      @"prompt" : @"login",
      @"scope" : @"fakescope1 fakescope2 fakescope3 openid profile offline_access",
      @"eqp1" : @"val1",
      @"eqp2" : @"val2",
      @"redirect_uri" : @"x-msauth-com-microsoft-unittests://com.microsoft.unittests",
      @"response_type" : @"code",
      @"code_challenge": pkce.codeChallenge,
      @"code_challenge_method" : @"S256",
      @"uid" : @"true",
      @"slice" : @"testslice"
      };
    NSDictionary *QPs = [NSDictionary msalURLFormDecode:authorizationUrl.query];
    XCTAssertTrue([expectedQPs compareDictionary:QPs]);
}

- (void)testInteractiveRequestFlow
{
    NSError *error = nil;
    
    __block NSUUID *correlationId = [NSUUID new];
    
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSALTestURLSession createMockSession];
    parameters.scopes = [NSOrderedSet orderedSetWithArray:@[@"fakescope1", @"fakescope2"]];
    parameters.unvalidatedAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    parameters.redirectUri = [NSURL URLWithString:@"x-msauth-com-microsoft-unittests://com.microsoft.unittests"];
    parameters.clientId = @"b92e0ba5-f86e-4411-8e18-6b5f928d968a";
    parameters.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.correlationId = correlationId;
    parameters.tokenCache = [MSALTestTokenCache createTestAccessor];
    
    [MSALTestSwizzle classMethod:@selector(randomUrlSafeStringOfSize:)
                           class:[NSString class]
                           block:(id)^(id obj, NSUInteger size)
     {
         (void)obj;
         (void)size;
         return @"randomValue";
     }];
    
    MSALPkce *pkce = [MSALPkce new];
    
    __block MSALInteractiveRequest *request =
    [[MSALInteractiveRequest alloc] initWithParameters:parameters
                                      additionalScopes:@[@"fakescope3"]
                                              behavior:MSALForceConsent
                                                 error:&error];
    
    XCTAssertNotNil(request);
    XCTAssertNil(error);
    
    // Setting MSALAuthority ahead of time short-circuits authority validation for this test
    request.authority = [MSALTestAuthority AADAuthority:parameters.unvalidatedAuthority];
    
    // Swizzle out the main entry point for WebUI, WebUI is tested in its own component tests
    [MSALTestSwizzle classMethod:@selector(startWebUIWithURL:context:completionBlock:)
                           class:[MSALWebUI class]
                           block:(id)^(id obj, NSURL *url, id<MSALRequestContext>context, MSALWebUICompletionBlock completionBlock)
     {
         (void)obj;
         (void)context;
         XCTAssertNotNil(url);
         
         XCTAssertNotNil(url);
         XCTAssertEqualObjects(url.scheme, @"https");
         XCTAssertEqualObjects(url.host, @"login.microsoftonline.com");
         XCTAssertEqualObjects(url.path, @"/common/oauth2/v2.0/authorize");
         
         NSDictionary *msalId = [MSALLogger msalId];
         NSDictionary *expectedQPs =
         @{
           @"x-client-Ver" : MSAL_VERSION_NSSTRING,
#if TARGET_OS_IPHONE
           @"x-client-SKU" : @"iOS",
           @"x-client-DM" : msalId[@"x-client-DM"],
#else
           @"x-client-SKU" : @"OSX",
#endif
           @"x-client-OS" : msalId[@"x-client-OS"],
           @"x-client-CPU" : msalId[@"x-client-CPU"],
           @"return-client-request-id" : correlationId.UUIDString,
           @"state" : request.state,
           @"prompt" : @"consent",
           @"login_hint" : @"fakeuser@contoso.com",
           @"client_id" : @"b92e0ba5-f86e-4411-8e18-6b5f928d968a",
           @"scope" : @"fakescope1 fakescope2 fakescope3 openid profile offline_access",
           @"eqp1" : @"val1",
           @"eqp2" : @"val2",
           @"redirect_uri" : @"x-msauth-com-microsoft-unittests://com.microsoft.unittests",
           @"response_type" : @"code",
           @"code_challenge": pkce.codeChallenge,
           @"code_challenge_method" : @"S256",
           @"uid" : @"true",
           @"slice" : @"testslice"
           };
         NSDictionary *QPs = [NSDictionary msalURLFormDecode:url.query];
         XCTAssertTrue([expectedQPs compareDictionary:QPs]);
         
         NSString *responseString = [NSString stringWithFormat:@"x-msauth-com-microsoft-unittests://com.microsoft.unittests?code=%@&state=%@", @"iamafakecode", request.state];
         completionBlock([NSURL URLWithString:responseString], nil);
     }];

    [MSALTestSwizzle classMethod:@selector(resolveEndpointsForAuthority:userPrincipalName:validate:context:completionBlock:)
                           class:[MSALAuthority class]
                        block:(id)^(id obj, NSURL *unvalidatedAuthority, NSString *userPrincipalName, BOOL validate, id<MSALRequestContext> context, MSALAuthorityCompletion completionBlock)
     
    {
        (void)obj;
        (void)context;
        (void)userPrincipalName;
        (void)validate;
        
        completionBlock([MSALTestAuthority AADAuthority:unvalidatedAuthority], nil);
    }];
    
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    [reqHeaders setObject:correlationId.UUIDString forKey:@"client-request-id"];
    
    MSALTestURLResponse *response =
    [MSALTestURLResponse requestURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token?slice=testslice&uid=true"
                           requestHeaders:reqHeaders
                        requestParamsBody:@{ @"code" : @"iamafakecode",
                                             @"client_id" : @"b92e0ba5-f86e-4411-8e18-6b5f928d968a",
                                             @"scope" : @"fakescope1 fakescope2 openid profile offline_access",
                                             @"redirect_uri" : @"x-msauth-com-microsoft-unittests://com.microsoft.unittests",
                                             @"grant_type" : @"authorization_code",
                                             @"code_verifier" : pkce.codeVerifier,
                                             @"client_info" : @"1"}
                        responseURLString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"access_token" : @"i am a access token!",
                                             @"expires_in" : @"600",
                                             @"refresh_token" : @"i am a refresh token",
                                             @"id_token" : [MSALTestIdTokenUtil defaultIdToken],
                                             @"id_token_expires_in" : @"1200",
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} base64UrlJson]}];
    [MSALTestURLSession addResponse:response];
    
    __block dispatch_semaphore_t dsem = dispatch_semaphore_create(0);
    __block BOOL fAlreadyHit = NO;
    [request run:^(MSALResult *result, NSError *error)
     {
         XCTAssertFalse(fAlreadyHit);
         fAlreadyHit = YES;
         XCTAssertNotNil(result);
         XCTAssertNil(error);
         XCTAssertNotNil(result.user);
         XCTAssertEqualObjects(result.user.uid, @"1");
         XCTAssertEqualObjects(result.user.utid, @"1234-5678-90abcdefg");
         XCTAssertEqualObjects(result.user.name, [MSALTestIdTokenUtil defaultName]);
         XCTAssertEqualObjects(result.user.displayableId, [MSALTestIdTokenUtil defaultUsername]);
         XCTAssertNotNil(result.tenantId);
         XCTAssertEqualObjects(result.tenantId, [MSALTestIdTokenUtil defaultTenantId]);
         XCTAssertNotNil(result.accessToken);
         XCTAssertEqualObjects(result.accessToken, @"i am a access token!");
         XCTAssertNil(error);
         
         dispatch_semaphore_signal(dsem);
     }];
    
    dispatch_semaphore_wait(dsem, DISPATCH_TIME_FOREVER);
}

@end
