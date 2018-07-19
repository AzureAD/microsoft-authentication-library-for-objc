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
#import "MSIDClientInfo.h"
#import "MSIDAADV2IdTokenClaims.h"
#import "MSALAccount+Internal.h"
#import "MSIDAccount.h"
#import "MSALAccountId.h"
#import "MSIDAccountIdentifier.h"

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

- (void)testInitWithMSIDAccount_whenValidAccount_shouldInit
{
    MSIDAccount *msidAccount = [MSIDAccount new];
    msidAccount.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:@"user@contoso.com" homeAccountId:@"uid.utid"];
    msidAccount.username = @"user@contoso.com";
    msidAccount.name = @"User";
    msidAccount.localAccountId = @"localoid";
    msidAccount.authority = [NSURL URLWithString:@"https://login.microsoftonline.com/tid"];
    NSDictionary *clientInfoClaims = @{ @"uid" : @"uid",
                                        @"utid" : @"utid"
                                        };
    
    
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];
    msidAccount.clientInfo = clientInfo;

    MSALAccount *account = [[MSALAccount alloc] initWithMSIDAccount:msidAccount];

    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.homeAccountId.objectId, @"uid");
    XCTAssertEqualObjects(account.homeAccountId.tenantId, @"utid");
    XCTAssertEqualObjects(account.name, @"User");
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
}

- (void)testCopy_whenValidAccount_shouldCopy
{
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"displayableID"
                                                                 name:@"name"
                                                        homeAccountId:@"1.2"
                                                       localAccountId:@"2.3"
                                                          environment:@"login.microsoftonline.com"
                                                             tenantId:@"3"
                                                           clientInfo:nil];
    XCTAssertNotNil(account);

    MSALAccount *account2 = [account copy];
    
    XCTAssertNotNil(account2);
    // The two objects should have different pointers
    XCTAssertNotEqual(account, account2);
    
    XCTAssertEqualObjects(account.homeAccountId.objectId, account2.homeAccountId.objectId);
    XCTAssertEqualObjects(account.homeAccountId.tenantId, account2.homeAccountId.tenantId);
    XCTAssertEqualObjects(account.username, account2.username);
    XCTAssertEqualObjects(account.name, account2.name);
}

- (void)testEquals_whenEqual_shouldReturnTrue
{
    NSDictionary *clientInfoClaims = @{ @"uid" : @"uid",
                                        @"utid" : @"utid"
                                        };
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];

    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"displayableID"
                                                                 name:@"name"
                                                        homeAccountId:@"1.2"
                                                       localAccountId:@"2.3"
                                                          environment:@"login.microsoftonline.com"
                                                             tenantId:@"3"
                                                           clientInfo:clientInfo];
    
    XCTAssertNotNil(account);
    MSALAccount *account2 = [account copy];
    
    XCTAssertNotNil(account2);
    XCTAssertEqualObjects(account, account2);
}

@end
