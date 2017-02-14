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

- (void)testResolveEndpoints
{
    // TODO: Authority endpoint discovery
    
    __block dispatch_semaphore_t dsem = dispatch_semaphore_create(0);
    
    [MSALAuthority resolveEndpoints:@"fakeuser@contoso.com"
                 validatedAuthority:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                           validate:YES
                            context:nil
                    completionBlock:^(MSALAuthority *authority, NSError *error)
    {
        XCTAssertNil(error);
        XCTAssertNotNil(authority);
        
        XCTAssertEqualObjects(authority.authorizationEndpoint, [NSURL URLWithString:@"https://login.microsoftonline.com/common/oauth2/v2.0/authorize"]);
        XCTAssertEqualObjects(authority.tokenEndpoint, [NSURL URLWithString:@"https://login.microsoftonline.com/common/oauth2/v2.0/token"]);
        
        dispatch_semaphore_signal(dsem);
    }];
    
    dispatch_semaphore_wait(dsem, DISPATCH_TIME_FOREVER);
}

@end
