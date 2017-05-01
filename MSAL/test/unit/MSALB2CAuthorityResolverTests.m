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
#import "MSALTestURLSession.h"
#import "MSALTestSwizzle.h"
#import "MSALB2CAuthorityResolver.h"

@interface MSALB2CAuthorityResolverTests : MSALTestCase

@end

@implementation MSALB2CAuthorityResolverTests

#define AAD_INSTANCE_DISCOVERY_ENDPOINT @"https://login.microsoft.com/common/discovery/instance"

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDefaultOpenIdConfigurationEndpoint_whenAuthority_shouldReturnDefault
{
    MSALB2CAuthorityResolver *b2cResolver = [MSALB2CAuthorityResolver new];
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.in/tfp/tenant/policy"];
    
    // Test with authority
    NSString *endpoint = [b2cResolver defaultOpenIdConfigurationEndpointForAuthority:authority];
    XCTAssertEqualObjects(endpoint, @"https://login.microsoftonline.in/tfp/tenant/policy/v2.0/.well-known/openid-configuration");
}

- (void)testDefaultOpenIdConfigurationEndpoint_whenNoAuthority_shouldReturnNil
{
    MSALB2CAuthorityResolver *b2cResolver = [MSALB2CAuthorityResolver new];
    
    // Test with no authority
    XCTAssertNil([b2cResolver defaultOpenIdConfigurationEndpointForAuthority:nil]);
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenValidate_shouldReturnError
{
    MSALB2CAuthorityResolver *b2cResolver = [MSALB2CAuthorityResolver new];
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.in/tfp/tenant/policy"];
    
    [b2cResolver openIDConfigurationEndpointForAuthority:authority
                                       userPrincipalName:nil
                                                validate:YES
                                                 context:nil
                                         completionBlock:^(NSString *endpoint, NSError *error)
     {
         XCTAssertNil(endpoint);
         XCTAssertNotNil(error);
         
         XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"not supported"]);
         XCTAssertTrue(error.code == MSALErrorInvalidRequest);
     }];
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenKnownAuthorityAndValidate_shouldReturnDefaultAuthority
{
    MSALB2CAuthorityResolver *b2cResolver = [MSALB2CAuthorityResolver new];
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.com/tfp/tenant/policy"];
    
    [b2cResolver openIDConfigurationEndpointForAuthority:authority
                                       userPrincipalName:nil
                                                validate:YES
                                                 context:nil
                                         completionBlock:^(NSString *endpoint, NSError *error)
     {
         XCTAssertNotNil(endpoint);
         XCTAssertNil(error);
         
         XCTAssertEqualObjects(endpoint, [b2cResolver defaultOpenIdConfigurationEndpointForAuthority:authority]);
     }];
}

- (void)testOpenIDConfigurationEndpointForAuthority_whenAuthorityAndNoValidate_shouldReturnDefaultAuthority
{
    MSALB2CAuthorityResolver *b2cResolver = [MSALB2CAuthorityResolver new];
    NSURL *authority = [NSURL URLWithString:@"https://login.microsoftonline.in/tfp/tenant/policy"];
    
    [b2cResolver openIDConfigurationEndpointForAuthority:authority
                                       userPrincipalName:nil
                                                validate:NO
                                                 context:nil
                                         completionBlock:^(NSString *endpoint, NSError *error)
     {
         XCTAssertNotNil(endpoint);
         XCTAssertNil(error);
         
         XCTAssertEqualObjects(endpoint, [b2cResolver defaultOpenIdConfigurationEndpointForAuthority:authority]);
     }];
}


@end
