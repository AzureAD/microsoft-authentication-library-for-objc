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
#import "MSALAuthority.h"
#import "MSALTestSwizzle.h"
#import "MSALAadAuthorityResolver.h"
#import "MSALTenantDiscoveryResponse.h"

@interface MSALAuthorityTests : MSALTestCase

@end

@implementation MSALAuthorityTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testCheckAuthorityString
{
    NSError *error = nil;
    NSURL *url = nil;
    
    url = [MSALAuthority checkAuthorityString:@"https://login.microsoftonline.com/common" error:&error];
    XCTAssertNotNil(url);
    XCTAssertNil(error);
    XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://login.microsoftonline.com/common"]);
    
    url = [MSALAuthority checkAuthorityString:nil error:&error];
    XCTAssertNil(url);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertNotNil(error.userInfo);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"nil"]);
    
    url = [MSALAuthority checkAuthorityString:@"http://login.microsoftonline.com/common" error:&error];
    XCTAssertNil(url);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertNotNil(error.userInfo);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"HTTPS"]);
    error = nil;
    
    url = [MSALAuthority checkAuthorityString:@"https://login.microsoftonline.com" error:&error];
    XCTAssertNil(url);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertNotNil(error.userInfo);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"tenant or common"]);
    
    url = [MSALAuthority checkAuthorityString:@"https login.microsoftonline.com common" error:&error];
    XCTAssertNil(url);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertNotNil(error.userInfo);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"must be a valid URI"]);
}


- (void)testIsKnownHost
{
    XCTAssertFalse([MSALAuthority isKnownHost:[NSURL URLWithString:@"https://www.noknownhost.com"]]);
    XCTAssertTrue([MSALAuthority isKnownHost:[NSURL URLWithString:@"https://login.windows.net"]]);
    XCTAssertTrue([MSALAuthority isKnownHost:[NSURL URLWithString:@"https://loginchinacloudapi.cn"]]);
    XCTAssertTrue([MSALAuthority isKnownHost:[NSURL URLWithString:@"login.microsoftonline.com"]]);
    XCTAssertTrue([MSALAuthority isKnownHost:[NSURL URLWithString:@"login.microsoftonline.de"]]);
}

- (void)testResolveEndpointsSuccess
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    NSURL *validAadAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    NSString *openIdConfigEndpoint = @"https://somopenidconfigendpointurl.com";
    
    [MSALTestSwizzle instanceMethod:@selector(openIDConfigurationEndpointForURL:userPrincipalName:validate:context:completionHandler:)
                              class:[MSALAadAuthorityResolver class]
                              block:(id)^(id obj,
                                          NSURL *authority,
                                          NSString *userPrincipalName,
                                          BOOL validate, id<MSALRequestContext> context,
                                          OpenIDConfigEndpointCallback completionHandler)
     {
         (void)obj;
         (void)userPrincipalName;
         (void)authority;
         (void)validate;
         (void)context;
         (void)completionHandler;
         
         completionHandler(openIdConfigEndpoint, nil);
     }];
     
    [MSALTestSwizzle instanceMethod:@selector(tenantDiscoveryEndpoint:context:completionBlock:)
                              class:[MSALAuthorityBaseResolver class]
                              block:(id)^(id obj,
                                          NSURL *authority,
                                          id<MSALRequestContext> context,
                                          TenantDiscoveryCallback completionBlock)
     {
         (void)obj;
         (void)authority;
         (void)context;
         (void)completionBlock;
      
         NSDictionary *jsonDict = @{@"authorization_endpoint":@"https://fs.contoso.com/adfs/oauth2/authorize/",
                                    @"token_endpoint":@"https://fs.contoso.com/adfs/oauth2/token/",
                                    @"issuer":@"https://fs.contoso.com/adfs/"};
         
         NSData* testJsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil];
         completionBlock([[MSALTenantDiscoveryResponse alloc] initWithData:testJsonData error:nil], nil);
     }];
    
    [MSALAuthority resolveEndpointsForAuthority:validAadAuthority
                              userPrincipalName:nil
                                       validate:YES
                                        context:nil
                                completionBlock:^(MSALAuthority *authority, NSError *error)
     {
         XCTAssertNotNil(authority);
         XCTAssertNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1.0
                                 handler:^(NSError * _Nullable error)
     {
         
         (void)error;
     }];
}

- (void)testResolveEndpointsOpenIDConfigError
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    NSURL *validAadAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    
    [MSALTestSwizzle instanceMethod:@selector(openIDConfigurationEndpointForURL:userPrincipalName:validate:context:completionHandler:)
                              class:[MSALAadAuthorityResolver class]
                              block:(id)^(id obj,
                                          NSURL *authority,
                                          NSString *userPrincipalName,
                                          BOOL validate, id<MSALRequestContext> context,
                                          OpenIDConfigEndpointCallback completionHandler)
     {
         (void)obj;
         (void)userPrincipalName;
         (void)authority;
         (void)validate;
         (void)context;
         (void)completionHandler;
         
         completionHandler(nil, MSALCreateError(MSALErrorInvalidResponse, @"Invalid response", nil, nil));
     }];
    
    [MSALAuthority resolveEndpointsForAuthority:validAadAuthority
                              userPrincipalName:nil
                                       validate:YES
                                        context:nil
                                completionBlock:^(MSALAuthority *authority, NSError *error)
     {
         XCTAssertNil(authority);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1.0
                                 handler:^(NSError * _Nullable error)
     {
         
         (void)error;
     }];
}

- (void)testResolveEndpointWithTenantEndpointError
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];
    
    NSURL *validAadAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/common"];
    NSString *openIdConfigEndpoint = @"https://somopenidconfigendpointurl.com";
    
    [MSALTestSwizzle instanceMethod:@selector(openIDConfigurationEndpointForURL:userPrincipalName:validate:context:completionHandler:)
                              class:[MSALAadAuthorityResolver class]
                              block:(id)^(id obj,
                                          NSURL *authority,
                                          NSString *userPrincipalName,
                                          BOOL validate, id<MSALRequestContext> context,
                                          OpenIDConfigEndpointCallback completionHandler)
     {
         (void)obj;
         (void)userPrincipalName;
         (void)authority;
         (void)validate;
         (void)context;
         (void)completionHandler;
         
         completionHandler(openIdConfigEndpoint, nil);
     }];
    
    [MSALTestSwizzle instanceMethod:@selector(tenantDiscoveryEndpoint:context:completionBlock:)
                              class:[MSALAuthorityBaseResolver class]
                              block:(id)^(id obj,
                                          NSURL *authority,
                                          id<MSALRequestContext> context,
                                          TenantDiscoveryCallback completionBlock)
     {
         (void)obj;
         (void)authority;
         (void)context;
         (void)completionBlock;
         
         completionBlock(nil, MSALCreateError(MSALErrorInvalidResponse, @"Invalid response", nil, nil));
     }];
    
    [MSALAuthority resolveEndpointsForAuthority:validAadAuthority
                              userPrincipalName:nil
                                       validate:YES
                                        context:nil
                                completionBlock:^(MSALAuthority *authority, NSError *error)
     {
         XCTAssertNil(authority);
         XCTAssertNotNil(error);
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1.0
                                 handler:^(NSError * _Nullable error)
     {
         
         (void)error;
     }];
}

@end
