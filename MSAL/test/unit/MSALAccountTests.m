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
#import "MSIDClientInfo.h"
#import "MSIDAADV2IdTokenClaims.h"
#import "MSALAccount+Internal.h"
#import "MSIDAccount.h"
#import "MSALAccountId.h"
#import "MSIDAADAuthority.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAuthority+Internal.h"
#import "MSALTenantProfile.h"
#import "MSALTenantProfile+Internal.h"
#import "MSALAccount+Internal.h"

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
    msidAccount.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com" homeAccountId:@"uid.tid"];
    msidAccount.username = @"user@contoso.com";
    msidAccount.name = @"User";
    msidAccount.localAccountId = @"localoid";
    __auto_type authorityUrl = [NSURL URLWithString:@"https://login.microsoftonline.com/tid"];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    msidAccount.authority = authority;
    NSDictionary *clientInfoClaims = @{ @"uid" : @"uid",
                                        @"utid" : @"tid"
                                        };
    
    
    MSIDClientInfo *clientInfo = [[MSIDClientInfo alloc] initWithJSONDictionary:clientInfoClaims error:nil];
    msidAccount.clientInfo = clientInfo;
    
    NSDictionary *idTokenDictionary = @{ @"aud" : @"b6c69a37",
                                         @"oid" : @"ff9feb5a"
                                         };
    MSIDIdTokenClaims *idTokenClaims = [[MSIDIdTokenClaims alloc] initWithJSONDictionary:idTokenDictionary error:nil];
    XCTAssertNotNil(idTokenClaims);

    MSALAccount *account = [[MSALAccount alloc] initWithMSIDAccount:msidAccount idTokenClaims:idTokenClaims];

    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.homeAccountId.objectId, @"uid");
    XCTAssertEqualObjects(account.homeAccountId.tenantId, @"tid");
    XCTAssertEqualObjects(account.name, @"User");
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
    XCTAssertEqual(account.tenantProfiles.count, 1);
    XCTAssertEqualObjects(account.tenantProfiles[0].userObjectId, @"localoid");
    XCTAssertEqualObjects(account.tenantProfiles[0].tenantId, @"tid");
    XCTAssertEqual(account.tenantProfiles[0].isHomeTenant, YES);
}

- (void)testAddTenantProfiles_whenAddTenantProfiles_shouldAddTenantProfilesToExistingAccount
{
    NSDictionary *idTokenDictionary = @{ @"aud" : @"b6c69a37",
                                         @"oid" : @"ff9feb5a"
                                         };
    MSIDIdTokenClaims *idTokenClaims = [[MSIDIdTokenClaims alloc] initWithJSONDictionary:idTokenDictionary error:nil];
    XCTAssertNotNil(idTokenClaims);
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"displayableID"
                                                            name:@"name"
                                                   homeAccountId:@"1.2"
                                                  localAccountId:@"3"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"4"
                                                   idTokenClaims:idTokenClaims];
    XCTAssertNotNil(account);
    
    NSDictionary *idTokenDictionary2 = @{ @"aud" : @"j890k23",
                                         @"oid" : @"l89j924"
                                         };
    MSIDIdTokenClaims *idTokenClaims2 = [[MSIDIdTokenClaims alloc] initWithJSONDictionary:idTokenDictionary2 error:nil];
    MSALAccount *account2 = [[MSALAccount alloc] initWithUsername:@"displayableID"
                                                             name:@"name"
                                                    homeAccountId:@"1.2"
                                                   localAccountId:@"5"
                                                      environment:@"login.microsoftonline.com"
                                                         tenantId:@"2"
                                                    idTokenClaims:idTokenClaims2];
    XCTAssertNotNil(account2);
    
    [account addTenantProfiles:account2.tenantProfiles];
    
    XCTAssertEqual(account.tenantProfiles.count, 2);
    XCTAssertEqualObjects(account.tenantProfiles[0].userObjectId, @"3");
    XCTAssertEqualObjects(account.tenantProfiles[0].tenantId, @"4");
    XCTAssertEqual(account.tenantProfiles[0].isHomeTenant, NO);
    XCTAssertEqualObjects(account.tenantProfiles[1].userObjectId, @"5");
    XCTAssertEqualObjects(account.tenantProfiles[1].tenantId, @"2");
    XCTAssertEqual(account.tenantProfiles[1].isHomeTenant, YES);
}

- (void)testAddTenantProfiles_whenAddNilTenantProfiles_shouldNotAddToExistingAccount
{
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"displayableID"
                                                            name:@"name"
                                                   homeAccountId:@"1.2"
                                                  localAccountId:@"3"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"4"
                                                   idTokenClaims:nil];
    XCTAssertNotNil(account);
    
    [account addTenantProfiles:nil];
    
    XCTAssertEqual(account.tenantProfiles.count, 1);
    XCTAssertEqualObjects(account.tenantProfiles[0].userObjectId, @"3");
    XCTAssertEqualObjects(account.tenantProfiles[0].tenantId, @"4");
}

- (void)testAddTenantProfiles_whenAddEmptyTenantProfiles_shouldNotAddToExistingAccount
{
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"displayableID"
                                                            name:@"name"
                                                   homeAccountId:@"1.2"
                                                  localAccountId:@"3"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"4"
                                                   idTokenClaims:nil];
    XCTAssertNotNil(account);
    
    [account addTenantProfiles:[NSArray new]];
    
    XCTAssertEqual(account.tenantProfiles.count, 1);
    XCTAssertEqualObjects(account.tenantProfiles[0].userObjectId, @"3");
    XCTAssertEqualObjects(account.tenantProfiles[0].tenantId, @"4");
}

- (void)testCopy_whenValidAccount_shouldDeepCopy
{
    NSDictionary *idTokenDictionary = @{ @"aud" : @"b6c69a37",
                                         @"oid" : @"ff9feb5a"
                                         };
    MSIDIdTokenClaims *idTokenClaims = [[MSIDIdTokenClaims alloc] initWithJSONDictionary:idTokenDictionary error:nil];
    XCTAssertNotNil(idTokenClaims);
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"displayableID"
                                                                 name:@"name"
                                                        homeAccountId:@"1.2"
                                                       localAccountId:@"2.3"
                                                          environment:@"login.microsoftonline.com"
                                                             tenantId:@"2"
                                                   idTokenClaims:idTokenClaims];
    XCTAssertNotNil(account);
    
    MSALTenantProfile *tenantProfile = [[MSALTenantProfile alloc] initWithUserObjectId:@"4"
                                                                              tenantId:@"5"
                                                                          isHomeTenant:NO
                                                                       addtionalClaims:@{@"key1" : @"value1",
                                                                                         @"key2" : @"value2",
                                                                                         }];
    [account addTenantProfiles:@[tenantProfile]];
    XCTAssertEqual(account.tenantProfiles.count, 2);
    
    MSALAccount *account2 = [account copy];
    
    XCTAssertNotNil(account2);
    
    // The two objects should have different pointers
    XCTAssertNotEqual(account, account2);
    XCTAssertEqualObjects(account.homeAccountId.objectId, account2.homeAccountId.objectId);
    XCTAssertEqualObjects(account.homeAccountId.tenantId, account2.homeAccountId.tenantId);
    XCTAssertEqualObjects(account.username, account2.username);
    XCTAssertEqualObjects(account.name, account2.name);
    
    // tenantProfiles should be be deep copied
    XCTAssertNotEqual(account.tenantProfiles, account2.tenantProfiles);
    XCTAssertEqual(account.tenantProfiles.count, account2.tenantProfiles.count);
    XCTAssertNotEqual(account.tenantProfiles[0], account2.tenantProfiles[0]);
    XCTAssertNotEqual(account.tenantProfiles[1], account2.tenantProfiles[1]);
    
    XCTAssertEqualObjects(account.tenantProfiles[0].tenantId, account2.tenantProfiles[0].tenantId);
    XCTAssertEqualObjects(account.tenantProfiles[0].userObjectId, account2.tenantProfiles[0].userObjectId);
    XCTAssertEqual(account.tenantProfiles[0].isHomeTenant, account2.tenantProfiles[0].isHomeTenant);
    XCTAssertEqualObjects(account.tenantProfiles[1].tenantId, account2.tenantProfiles[1].tenantId);
    XCTAssertEqualObjects(account.tenantProfiles[1].userObjectId, account2.tenantProfiles[1].userObjectId);
    XCTAssertEqual(account.tenantProfiles[1].isHomeTenant, account2.tenantProfiles[1].isHomeTenant);
    
    // additionalClaims should be deep copied
    XCTAssertNotEqual(account.tenantProfiles[1].additionalClaims, account2.tenantProfiles[1].additionalClaims);
    XCTAssertEqualObjects(account.tenantProfiles[1].additionalClaims, account2.tenantProfiles[1].additionalClaims);
}

- (void)testEquals_whenEqual_shouldReturnTrue
{
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"displayableID"
                                                                 name:@"name"
                                                        homeAccountId:@"1.2"
                                                       localAccountId:@"2.3"
                                                          environment:@"login.microsoftonline.com"
                                                             tenantId:@"3"
                                                   idTokenClaims:nil];
    
    XCTAssertNotNil(account);
    MSALAccount *account2 = [account copy];
    
    XCTAssertNotNil(account2);
    XCTAssertEqualObjects(account, account2);
}

@end
