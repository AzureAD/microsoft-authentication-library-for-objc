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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSALTestCase.h"
#import "MSALIdToken.h"
#import "MSALClientInfo.h"

@interface MSALUserTests : MSALTestCase

@end

@implementation MSALUserTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInitWithJSON
{
    NSDictionary *idTokenClaims = @{ @"name" : @"User",
                                     @"preferred_username" : @"user@contoso.com",
                                     @"iss" : @"issuer",
                                     @"tid" : @"id_token_tid"
                                     };
    
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims
                                                       error:nil];
    NSDictionary *clientInfoClaims = @{ @"uid" : @"uid",
                                        @"utid" : @"utid"
                                        };
    MSALClientInfo *clientInfo = [[MSALClientInfo alloc] initWithJson:clientInfoClaims
                                                                error:nil];
    
    MSALUser *user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:@"login.microsoftonline.com"];
    
    XCTAssertNotNil(user);
    XCTAssertEqualObjects(user.uid, @"uid");
    XCTAssertEqualObjects(user.utid, @"utid");
    XCTAssertEqualObjects(user.identityProvider, @"issuer");
    XCTAssertEqualObjects(user.name, @"User");
    XCTAssertEqualObjects(user.displayableId, @"user@contoso.com");
}

- (void)testCopy
{
    NSDictionary *idTokenClaims = @{ @"name" : @"User",
                                     @"preferred_username" : @"user@contoso.com",
                                     @"iss" : @"issuer",
                                     @"tid" : @"id_token_tid"
                                     };
    
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims
                                                       error:nil];
    NSDictionary *clientInfoClaims = @{ @"uid" : @"uid",
                                        @"utid" : @"utid"
                                        };
    MSALClientInfo *clientInfo = [[MSALClientInfo alloc] initWithJson:clientInfoClaims
                                                                error:nil];
    
    MSALUser *user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:@"login.microsoftonline.com"];
    XCTAssertNotNil(user);
    MSALUser *user2 = [user copy];
    
    XCTAssertNotNil(user2);
    // The two objects should have different pointers
    XCTAssertNotEqual(user2, user);
    
    XCTAssertEqualObjects(user.uid, user2.uid);
    XCTAssertEqualObjects(user.utid, user2.utid);
    XCTAssertEqualObjects(user.identityProvider, user2.identityProvider);
    XCTAssertEqualObjects(user.name, user2.name);
}

- (void)testEquals
{
    NSDictionary *idTokenClaims = @{ @"preferred_username" : @"User",
                                     @"iss" : @"issuer",
                                     @"tid" : @"id_token_tid"
                                     };
    
    MSALIdToken *idToken = [[MSALIdToken alloc] initWithJson:idTokenClaims
                                                       error:nil];
    NSDictionary *clientInfoClaims = @{ @"uid" : @"uid",
                                        @"utid" : @"utid"
                                        };
    MSALClientInfo *clientInfo = [[MSALClientInfo alloc] initWithJson:clientInfoClaims
                                                                error:nil];
    
    MSALUser *user = [[MSALUser alloc] initWithIdToken:idToken clientInfo:clientInfo environment:@"login.microsoftonline.com"];
    XCTAssertNotNil(user);
    MSALUser *user2 = [user copy];
    
    XCTAssertNotNil(user2);
    XCTAssertEqualObjects(user, user2);
}

@end
