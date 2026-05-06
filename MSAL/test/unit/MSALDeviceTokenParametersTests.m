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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  

#import <XCTest/XCTest.h>
#import "MSALDeviceTokenParameters.h"

@interface MSALDeviceTokenParametersTests : XCTestCase

@end

@implementation MSALDeviceTokenParametersTests

- (void)testInitWithResource_whenResourceIsNil_shouldReturnNil
{
    NSString *resource;
    MSALDeviceTokenParameters *parameters = [[MSALDeviceTokenParameters alloc] initWithResource:resource
                                                                                         scopes:@[@"scope.read"]
                                                                                    forTenantId:@"tenant-id"];

    XCTAssertNil(parameters);
}

- (void)testInitWithResource_whenResourceIsBlank_shouldReturnNil
{
    MSALDeviceTokenParameters *parameters = [[MSALDeviceTokenParameters alloc] initWithResource:@"   \n\t"
                                                                                         scopes:@[@"scope.read"]
                                                                                    forTenantId:@"tenant-id"];

    XCTAssertNil(parameters);
}

- (void)testInitWithResource_whenScopesAreNil_shouldInitializeWithEmptyScopes
{
    MSALDeviceTokenParameters *parameters = [[MSALDeviceTokenParameters alloc] initWithResource:@"https://resource.contoso.com"
                                                                                          scopes:nil
                                                                                     forTenantId:@"tenant-id"];

    XCTAssertNotNil(parameters);
    XCTAssertEqual(parameters.scopes.count, 0);
    XCTAssertEqualObjects(parameters.resource, @"https://resource.contoso.com");
    XCTAssertEqualObjects(parameters.tenantId, @"tenant-id");
}

- (void)testInitWithResource_whenScopesProvided_shouldPreserveScopesAndProperties
{
    NSArray<NSString *> *scopes = @[@"scope.read", @"scope.write"];
    MSALDeviceTokenParameters *parameters = [[MSALDeviceTokenParameters alloc] initWithResource:@"https://resource.contoso.com"
                                                                                          scopes:scopes
                                                                                     forTenantId:@"tenant-id"];

    XCTAssertNotNil(parameters);
    XCTAssertEqualObjects(parameters.scopes, scopes);
    XCTAssertEqualObjects(parameters.resource, @"https://resource.contoso.com");
    XCTAssertEqualObjects(parameters.tenantId, @"tenant-id");
}

- (void)testInitWithResource_whenTenantIdIsNil_shouldInitializeWithNilTenant
{
    NSString *tenantId;
    MSALDeviceTokenParameters *parameters = [[MSALDeviceTokenParameters alloc] initWithResource:@"https://resource.contoso.com"
                                                                                         scopes:@[@"scope.read"]
                                                                                    forTenantId:tenantId];

    XCTAssertNil(parameters);
}

@end
