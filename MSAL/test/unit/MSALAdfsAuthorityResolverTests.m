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
#import "MSALAdfsAuthorityResolver.h"

#import "MSALDrsDiscoveryResponse.h"
#import "MSALWebFingerResponse.h"

#import "MSALTestURLSession.h"

#define TRUSTED_REALM @"http://schemas.microsoft.com/rel/trusted-realm"

typedef void (^MSALDrsCompletionBlock)(MSALDrsDiscoveryResponse *response, NSError *error);
typedef void (^MSALWebFingerCompletionBlock)(MSALWebFingerResponse *response, NSError *error);

@interface MSALAdfsAuthorityResolverTests : MSALTestCase

@end

@implementation MSALAdfsAuthorityResolverTests
{
    NSURL *authority;
    NSString *upn;
    NSString *domain;
    
    NSString *expectedEndpoint;
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    authority = [NSURL URLWithString:@"https://fs.fabrikam.com/adfs/"];
    upn = @"user@contoso.com";
    domain = @"contoso.com";
    
    expectedEndpoint = @"https://fs.fabrikam.com/adfs/.well-known/openid-configuration";
}

- (void)addDrsDiscoverySuccessResponseForCloud:(NSDictionary *)customResponse
{
    [self addDrsDiscoverySuccessResponse:customResponse onPrems:NO];
    
}

- (void)addDrsDiscoverySuccessResponseForOnPrems:(NSDictionary *)customResponse
{
    [self addDrsDiscoverySuccessResponse:customResponse onPrems:YES];
}

- (void)addDrsDiscoverySuccessResponse:(NSDictionary *)customResponse onPrems:(BOOL)onPrems
{
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    
    NSDictionary *resultJson = customResponse? customResponse :
    @{ @"IdentityProviderService" : @{ @"PassiveAuthEndpoint" : @"https://fs.fabrikam.com/adfs/ls" }};
    
    NSString *url = onPrems?
    @"https://enterpriseregistration.contoso.com/enrollmentserver/contract?api-version=1.0" :
    @"https://enterpriseregistration.windows.net/contoso.com/enrollmentserver/contract?api-version=1.0";
    
    MSALTestURLResponse *response =
    [MSALTestURLResponse requestURLString:url
                           requestHeaders:reqHeaders
                        requestParamsBody:nil
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:resultJson];
     [MSALTestURLSession addResponse:response];
}

- (void)addDrsDiscoveryForOnPremsFailureResponse
{
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    
    [MSALTestURLSession addResponse:
     [MSALTestURLResponse serverNotFoundResponseForURLString:@"https://enterpriseregistration.contoso.com/enrollmentserver/contract?api-version=1.0"
                                              requestHeaders:reqHeaders
                                           requestParamsBody:nil]];
    
}

- (void)addDrsDiscoveryForCloudFailureResponse
{
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    
    [MSALTestURLSession addResponse:
     [MSALTestURLResponse serverNotFoundResponseForURLString:@"https://enterpriseregistration.windows.net/contoso.com/enrollmentserver/contract?api-version=1.0"
                                              requestHeaders:reqHeaders
                                           requestParamsBody:nil]];
}

- (void)addWebFingerSuccessResponse:(NSDictionary *)customResponse
{
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    
    NSDictionary *resultJson = customResponse? customResponse :
    @{ @"links" : @[@{ @"rel" : TRUSTED_REALM, @"href" : @"https://fs.fabrikam.com/adfs/"}]};
    
    MSALTestURLResponse *response =
    [MSALTestURLResponse requestURLString:@"https://fs.fabrikam.com/.well-known/webfinger?resource=https://fs.fabrikam.com/adfs/"
                           requestHeaders:reqHeaders
                        requestParamsBody:nil
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:resultJson];
    [MSALTestURLSession addResponse:response];

}


- (void)addWebFingerFailureResponse
{
    NSMutableDictionary *reqHeaders = [[MSALLogger msalId] mutableCopy];
    [reqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [reqHeaders setObject:@"application/json" forKey:@"Accept"];
    
    MSALTestURLResponse *response =
    [MSALTestURLResponse serverNotFoundResponseForURLString:@"https://fs.fabrikam.com/.well-known/webfinger?resource=https://fs.fabrikam.com/adfs/"
                                             requestHeaders:reqHeaders
                                          requestParamsBody:nil];
    [MSALTestURLSession addResponse:response];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDefaultOpenIdConfigurationEndpointForAuthority_whenAuthority_shouldReturnURLString
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    NSString *endpoint = [resolver defaultOpenIdConfigurationEndpointForAuthority:authority];
    
    XCTAssertEqualObjects(endpoint, expectedEndpoint);
}

- (void)testDefaultOpenIdConfigurationEndpointForAuthority_whenNilAuthority_shouldReturnNil
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    XCTAssertNil([resolver defaultOpenIdConfigurationEndpointForAuthority:nil]);
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenNoValidate_shouldReturnEndpoint
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:NO
                                              context:nil
                                      completionBlock:^(NSString *endpoint, NSError *error)
    {
        
        XCTAssertNil(error);
        XCTAssertNotNil(endpoint);
        
        XCTAssertEqualObjects(endpoint, expectedEndpoint);
    }];
}

- (void)testUrlForDrsDiscoveryForDomain_whenNoDomain_shouldReturnNil
{
    XCTAssertNil([MSALAdfsAuthorityResolver urlForDrsDiscoveryForDomain:nil adfsType:MSAL_ADFS_CLOUD]);
    XCTAssertNil([MSALAdfsAuthorityResolver urlForDrsDiscoveryForDomain:nil adfsType:MSAL_ADFS_ON_PREMS]);
}

- (void)testUrlForDrsDiscoveryForDomain_whenDomainAndOnPrems_shouldReturnUrl
{
    NSString *expectedUrlString = @"https://enterpriseregistration.somedomain.com/enrollmentserver/contract?api-version=1.0";
    NSURL *resultUrl = [MSALAdfsAuthorityResolver urlForDrsDiscoveryForDomain:@"somedomain.com" adfsType:MSAL_ADFS_ON_PREMS];
    XCTAssertNotNil(resultUrl);
    XCTAssertEqualObjects(resultUrl.absoluteString, expectedUrlString);
}

- (void)testUrlForDrsDiscoveryForDomain_whenDomainAndOnCloud_shouldReturnUrl
{
    NSString *expectedUrlString = @"https://enterpriseregistration.windows.net/somedomain.com/enrollmentserver/contract?api-version=1.0";
    NSURL *resultUrl = [MSALAdfsAuthorityResolver urlForDrsDiscoveryForDomain:@"somedomain.com" adfsType:MSAL_ADFS_CLOUD];
    XCTAssertNotNil(resultUrl);
    XCTAssertEqualObjects(resultUrl.absoluteString, expectedUrlString);
}

- (void)testUrlForWebFinger_whenNoAuthenticationEndpoint_shouldReturnNil
{
    XCTAssertNil([MSALAdfsAuthorityResolver urlForWebFinger:nil absoluteAuthority:@"https://login.microsoftonline.com/common"]);
}

- (void)testUrlForWebFinger_whenNoAuthority_shouldReturnNil
{
    XCTAssertNil([MSALAdfsAuthorityResolver urlForWebFinger:@"https://someUrl.com" absoluteAuthority:nil]);
}

- (void)testUrlForWebFinger_whenAuthenticationEndpointAndAuthority_shouldReturnUrl
{
    NSString *authenticationEndpoint = @"https://someauthendpoint.com";
    NSString *someAuthority = @"https://someauthority.com";
    
    NSString *expectedUrlString = @"https://someauthendpoint.com/.well-known/webfinger?resource=https://someauthority.com";
    
    NSURL *url = [MSALAdfsAuthorityResolver urlForWebFinger:authenticationEndpoint absoluteAuthority:someAuthority];
    
    XCTAssertNotNil(url);
    XCTAssertEqualObjects(url.absoluteString, expectedUrlString);
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenBadUpn_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    NSString *badUpn = @"displayable";

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:badUpn
                                             validate:YES
                                              context:nil
                                      completionBlock:^(NSString *endpoint, NSError *error)
     {
         
         XCTAssertNotNil(error);
         XCTAssertNil(endpoint);
         
         XCTAssertTrue(error.code == MSALErrorInvalidParameter);
         XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"UPN"]);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenNilUpn_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:nil
                                             validate:YES
                                              context:nil
                                      completionBlock:^(NSString *endpoint, NSError *error)
     {
         
         XCTAssertNotNil(error);
         XCTAssertNil(endpoint);
         
         XCTAssertTrue(error.code == MSALErrorInvalidParameter);
         XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"UPN"]);
         
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenDrsDiscoveryValidFromOnPremsAndWebFingerValid_shouldReturnEndpoint
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSALTestURLSession createMockSession];
    
    [self addDrsDiscoverySuccessResponseForOnPrems:nil];
    [self addWebFingerSuccessResponse:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:parameters
                                      completionBlock:^(NSString *endpoint, NSError *error) {
                                          XCTAssertNotNil(endpoint);
                                          XCTAssertNil(error);
                                          
                                          XCTAssertEqualObjects(endpoint, expectedEndpoint);
                                          [expectation fulfill];
                                      }];
    
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenDrsDiscoveryValidFromCloudAndWebFingerValid_shouldReturnEndpoint
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSALTestURLSession createMockSession];
    
    [self addDrsDiscoveryForOnPremsFailureResponse];
    [self addDrsDiscoverySuccessResponseForCloud:nil];
    [self addWebFingerSuccessResponse:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:parameters
                                      completionBlock:^(NSString *endpoint, NSError *error) {
                                          XCTAssertNotNil(endpoint);
                                          XCTAssertNil(error);
                                          
                                          XCTAssertEqualObjects(endpoint, expectedEndpoint);
                                          [expectation fulfill];
                                      }];
    
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenDrsDiscoveryServerError_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSALTestURLSession createMockSession];
    
    [self addDrsDiscoveryForOnPremsFailureResponse];
    [self addDrsDiscoveryForCloudFailureResponse];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:parameters
                                      completionBlock:^(NSString *endpoint, NSError *error) {
                                          XCTAssertNil(endpoint);
                                          XCTAssertNotNil(error);
                                         
                                          [expectation fulfill];
                                      }];
    
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];    
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenDrsResponseMissingPassiveAuthEndpoint_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSALTestURLSession createMockSession];
    
    [self addDrsDiscoverySuccessResponseForOnPrems:@{ @"IdentityProviderService" : @{ } }];
    [self addWebFingerSuccessResponse:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:parameters
                                      completionBlock:^(NSString *endpoint, NSError *error) {
                                          XCTAssertNotNil(error);
                                          XCTAssertNil(endpoint);
                                          
                                          XCTAssertTrue(error.code == MSALErrorFailedAuthorityValidation);
                                          XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"DRS discovery"]);
                                          
                                          [expectation fulfill];
                                      }];
    
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenDrsResponseMissingIdentityProviderService_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSALTestURLSession createMockSession];
    
    [self addDrsDiscoverySuccessResponseForOnPrems:@{ }];
    [self addWebFingerSuccessResponse:nil];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:parameters
                                      completionBlock:^(NSString *endpoint, NSError *error) {
                                          XCTAssertNotNil(error);
                                          XCTAssertNil(endpoint);
                                          
                                          XCTAssertTrue(error.code == MSALErrorFailedAuthorityValidation);
                                          XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"DRS discovery"]);
                                          
                                          [expectation fulfill];
                                      }];
    
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenWebFingerResponseMissing_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSALTestURLSession createMockSession];
    
    [self addDrsDiscoveryForOnPremsFailureResponse];
    [self addDrsDiscoverySuccessResponseForCloud:nil];
    [self addWebFingerSuccessResponse:@{}];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:parameters
                                      completionBlock:^(NSString *endpoint, NSError *error) {
                                          XCTAssertNotNil(error);
                                          XCTAssertNil(endpoint);
                                          
                                          XCTAssertTrue(error.code == MSALErrorFailedAuthorityValidation);
                                          XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"WebFinger"]);
                                          [expectation fulfill];
                                      }];
    
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenWebFingerResponseRealmNotTrusted_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSALTestURLSession createMockSession];
    
    [self addDrsDiscoveryForOnPremsFailureResponse];
    [self addDrsDiscoverySuccessResponseForCloud:nil];
    [self addWebFingerSuccessResponse:@{ @"links" : @[ @{@"href" : @"https://fs.fabrikam.com/adfs/",
                                                         @"rel" : @"https://schemas.somehost.com/rel/not-trusted"}] }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:parameters
                                      completionBlock:^(NSString *endpoint, NSError *error) {
                                          XCTAssertNotNil(error);
                                          XCTAssertNil(endpoint);
                                          
                                          XCTAssertTrue(error.code == MSALErrorFailedAuthorityValidation);
                                          XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"WebFinger"]);
                                          [expectation fulfill];
                                      }];
    
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenWebFingerLinkHrefNotMatchAuthority_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSALTestURLSession createMockSession];
    
    [self addDrsDiscoveryForOnPremsFailureResponse];
    [self addDrsDiscoverySuccessResponseForCloud:nil];
    [self addWebFingerSuccessResponse:@{ @"links" : @[ @{@"href" : @"https://someref_not_match_authority.com",
                                                         @"rel" : TRUSTED_REALM}] }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:parameters
                                      completionBlock:^(NSString *endpoint, NSError *error) {
                                          XCTAssertNotNil(error);
                                          XCTAssertNil(endpoint);
                                          
                                          XCTAssertTrue(error.code == MSALErrorFailedAuthorityValidation);
                                          XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"WebFinger"]);
                                          [expectation fulfill];
                                      }];
    
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
    
    [parameters.urlSession invalidateAndCancel];
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenWebFingerResponseEmptyLinks_shouldReturnError
{
    MSALAdfsAuthorityResolver *resolver = [MSALAdfsAuthorityResolver new];
    MSALRequestParameters *parameters = [MSALRequestParameters new];
    parameters.urlSession = [MSALTestURLSession createMockSession];
    
    [self addDrsDiscoveryForOnPremsFailureResponse];
    [self addDrsDiscoverySuccessResponseForCloud:nil];
    [self addWebFingerSuccessResponse:@{ @"links" : @[] }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    [resolver openIDConfigurationEndpointForAuthority:authority
                                    userPrincipalName:upn
                                             validate:YES
                                              context:parameters
                                      completionBlock:^(NSString *endpoint, NSError *error) {
                                          XCTAssertNotNil(error);
                                          XCTAssertNil(endpoint);
                                          
                                          XCTAssertTrue(error.code == MSALErrorFailedAuthorityValidation);
                                          XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"WebFinger"]);
                                          [expectation fulfill];
                                      }];
    
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error)
     {
         XCTAssertNil(error);
     }];
}

@end
