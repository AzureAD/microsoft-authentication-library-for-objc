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
#import "MSALTestAuthority.h"

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

- (void)testCheckAuthorityString_whenCommon_shouldPass
{
    NSError *error = nil;
    NSURL *url = nil;
    
    url = [MSALAuthority checkAuthorityString:@"https://login.microsoftonline.com/common" error:&error];
    XCTAssertNotNil(url);
    XCTAssertNil(error);
    XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://login.microsoftonline.com/common"]);
}

- (void)testCheckAuthorityString_whenNil_shouldFail
{
    NSError *error = nil;
    NSURL *url = [MSALAuthority checkAuthorityString:nil error:&error];
    
    XCTAssertNil(url);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertNotNil(error.userInfo);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"nil"]);
}

- (void)testCheckAuthorityString_whenHttp_shouldFail
{
    NSError *error = nil;
    NSURL *url = [MSALAuthority checkAuthorityString:@"http://login.microsoftonline.com/common" error:&error];
    
    XCTAssertNil(url);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertNotNil(error.userInfo);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"HTTPS"]);
    error = nil;
}

- (void)testCheckAuthorityString_whenNoTenant_shouldFail
{
    NSError *error = nil;
    NSURL *url = [MSALAuthority checkAuthorityString:@"https://login.microsoftonline.com" error:&error];
    
    XCTAssertNil(url);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertNotNil(error.userInfo);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"tenant or common"]);
}

- (void)testCheckAuthorityString_whenB2CNoPolicy_shouldFail
{
    NSError *error = nil;
    NSURL *url = [MSALAuthority checkAuthorityString:@"https://somehost.com/tfp/" error:&error];
    
    XCTAssertNil(url);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertNotNil(error.userInfo);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"tenant"]);
}

- (void)testCheckAuthorityString_whenNotValidUri_shouldFail
{
    NSError *error = nil;
    NSURL *url = [MSALAuthority checkAuthorityString:@"https login.microsoftonline.com common" error:&error];
    
    XCTAssertNil(url);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertNotNil(error.userInfo);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"must be a valid URI"]);
}


- (void)testCacheURLAuthority_whenCommon
{
    NSURL *url = [MSALAuthority cacheUrlForAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] tenantId:@"tenant"];
    
    XCTAssertNotNil(url);
    XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://login.microsoftonline.com/tenant"]);
}

- (void)testCacheURLAuthority_whenCommonWithPort
{
    NSURL *url = [MSALAuthority cacheUrlForAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com:8080/common"] tenantId:@"tenant"];
    
    XCTAssertNotNil(url);
    XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://login.microsoftonline.com:8080/tenant"]);
}

- (void)testCacheURLAuthority_whenTenantSpecified
{
    NSURL *url = [MSALAuthority cacheUrlForAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com/tenant2"] tenantId:@"tenant1"];
    
    XCTAssertNotNil(url);
    XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://login.microsoftonline.com/tenant2"]);
}

- (void)testCacheURLAuthority_whenTenantSpecifiedWithPort
{
    NSURL *url = [MSALAuthority cacheUrlForAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com:8080/tenant2"] tenantId:@"tenant1"];
    
    XCTAssertNotNil(url);
    XCTAssertEqualObjects(url, [NSURL URLWithString:@"https://login.microsoftonline.com:8080/tenant2"]);
}


- (void)testIsKnownHost
{
    XCTAssertFalse([MSALAuthority isKnownHost:[NSURL URLWithString:@"https://www.noknownhost.com"]]);
    XCTAssertTrue([MSALAuthority isKnownHost:[NSURL URLWithString:@"https://login.windows.net"]]);
    XCTAssertTrue([MSALAuthority isKnownHost:[NSURL URLWithString:@"https://login.chinacloudapi.cn"]]);
    XCTAssertTrue([MSALAuthority isKnownHost:[NSURL URLWithString:@"https://login.microsoftonline.com"]]);
    XCTAssertTrue([MSALAuthority isKnownHost:[NSURL URLWithString:@"https://login.microsoftonline.de"]]);
    XCTAssertTrue([MSALAuthority isKnownHost:[NSURL URLWithString:@"https://login-us.microsoftonline.com"]]);
}


- (void)testValidatedAuthorityCache
{
    MSALAuthority *aadAuthority = [MSALTestAuthority AADAuthority:[NSURL URLWithString:@"https://login.microsoftonline.in/common"]];
    MSALAuthority *b2cAuthority = [MSALTestAuthority B2CAuthority:[NSURL URLWithString:@"https://login.microsoftonline.in/tfp"]];
    MSALAuthority *adfsAuthority = [MSALTestAuthority ADFSAuthority:[NSURL URLWithString:@"https://fs.contoso.com/adfs/"]];
    
    // Add non valid authority
    XCTAssertFalse([MSALAuthority addToValidatedAuthority:nil userPrincipalName:nil]);
    XCTAssertFalse([MSALAuthority addToValidatedAuthority:adfsAuthority userPrincipalName:nil]);
    
    // Add valid authority
    XCTAssertTrue([MSALAuthority addToValidatedAuthority:aadAuthority userPrincipalName:nil]);
    XCTAssertTrue([MSALAuthority addToValidatedAuthority:b2cAuthority userPrincipalName:nil]);
    XCTAssertTrue([MSALAuthority addToValidatedAuthority:adfsAuthority userPrincipalName:@"user@contoso.com"]);

    // Check if valid authority returned
    MSALAuthority *retrivedAuthority = [MSALAuthority authorityFromCache:aadAuthority.canonicalAuthority userPrincipalName:nil];
    XCTAssertNotNil(retrivedAuthority);
    XCTAssertTrue([retrivedAuthority.canonicalAuthority isEqual:aadAuthority.canonicalAuthority]);
    
    MSALAuthority *retrivedAdfsAuthority = [MSALAuthority authorityFromCache:adfsAuthority.canonicalAuthority userPrincipalName:@"user@contoso.com"];
    XCTAssertNotNil(retrivedAdfsAuthority);
    XCTAssertTrue([retrivedAdfsAuthority.canonicalAuthority isEqual:adfsAuthority.canonicalAuthority]);
    
    
    // Check if non valid authority was not returned
    XCTAssertNil([MSALAuthority authorityFromCache:[NSURL URLWithString:@"https://somehost.com/"] userPrincipalName:nil]);
}

- (void)testResolveEndpointsSuccess
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expectation"];

    NSURL *validAadAuthority = [NSURL URLWithString:@"https://login.microsoftonline.in/mytenant.com"];
    NSString *openIdConfigEndpoint = @"https://login.microsoftonline.in/mytenant.com/.well-known/openid-configuration";
    
    [MSALTestSwizzle instanceMethod:@selector(openIDConfigurationEndpointForAuthority:userPrincipalName:validate:context:completionBlock:)
                              class:[MSALAadAuthorityResolver class]
                              block:(id)^(id obj,
                                          NSURL *authority,
                                          NSString *userPrincipalName,
                                          BOOL validate, id<MSALRequestContext> context,
                                          OpenIDConfigEndpointCallback completionBlock)
     {
         (void)obj;
         (void)userPrincipalName;
         (void)authority;
         (void)validate;
         (void)context;
         (void)completionBlock;
         
         completionBlock(openIdConfigEndpoint, nil);
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
      
         NSString *filePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"OpenIdConfiguration.json"];
         XCTAssertNotNil(filePath);
         
         NSData *data = [NSData dataWithContentsOfFile:filePath options:0 error:nil];
         NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
         
         NSData* testJsonData = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
         completionBlock([[MSALTenantDiscoveryResponse alloc] initWithData:testJsonData error:nil], nil);
     }];
    
    [MSALAuthority resolveEndpointsForAuthority:validAadAuthority
                              userPrincipalName:nil
                                       validate:YES
                                        context:nil
                                completionBlock:^(MSALAuthority *authority, NSError *error)
     {
         XCTAssertNotNil(authority);
         
         XCTAssertEqualObjects(authority.authorizationEndpoint.absoluteString, @"https://login.microsoftonline.com/6babcaad-604b-40ac-a9d7-9fd97c0b779f/oauth2/authorize");
         XCTAssertEqualObjects(authority.tokenEndpoint.absoluteString, @"https://login.microsoftonline.com/6babcaad-604b-40ac-a9d7-9fd97c0b779f/oauth2/token");
         XCTAssertEqualObjects(authority.selfSignedJwtAudience, @"https://sts.windows.net/6babcaad-604b-40ac-a9d7-9fd97c0b779f/");
         
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
    
    NSURL *validAadAuthority = [NSURL URLWithString:@"https://login.microsoftonline.in/mytenant.com"];
    
    [MSALTestSwizzle instanceMethod:@selector(openIDConfigurationEndpointForAuthority:userPrincipalName:validate:context:completionBlock:)
                              class:[MSALAadAuthorityResolver class]
                              block:(id)^(id obj,
                                          NSURL *authority,
                                          NSString *userPrincipalName,
                                          BOOL validate, id<MSALRequestContext> context,
                                          OpenIDConfigEndpointCallback completionBlock)
     {
         (void)obj;
         (void)userPrincipalName;
         (void)authority;
         (void)validate;
         (void)context;
         (void)completionBlock;
         
         completionBlock(nil, MSALCreateError(MSALErrorInvalidResponse, @"Invalid response", nil, nil, nil));
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
    
    NSURL *validAadAuthority = [NSURL URLWithString:@"https://login.microsoftonline.in/mytenant.com"];
    NSString *openIdConfigEndpoint = @"https://login.microsoftonline.in/mytenant.com/.well-known/openid-configuration";

    [MSALTestSwizzle instanceMethod:@selector(openIDConfigurationEndpointForAuthority:userPrincipalName:validate:context:completionBlock:)
                              class:[MSALAadAuthorityResolver class]
                              block:(id)^(id obj,
                                          NSURL *authority,
                                          NSString *userPrincipalName,
                                          BOOL validate, id<MSALRequestContext> context,
                                          OpenIDConfigEndpointCallback completionBlock)
     {
         (void)obj;
         (void)userPrincipalName;
         (void)authority;
         (void)validate;
         (void)context;
         (void)completionBlock;
         
         completionBlock(openIdConfigEndpoint, nil);
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
         
         completionBlock(nil, MSALCreateError(MSALErrorInvalidResponse, @"Invalid response", nil, nil, nil));
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
