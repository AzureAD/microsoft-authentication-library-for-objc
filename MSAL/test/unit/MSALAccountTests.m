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
#import "MSALAuthority.h"
#import "MSALAccountId+Internal.h"
#import "MSALAccount+MultiTenantAccount.h"

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

- (void)testInitWithMSIDAccount_whenValidAccountAndCreateTenantProfileYes_shouldInitAndCreateTenantProfile
{
    MSIDAccount *msidAccount = [MSIDAccount new];
    msidAccount.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com" homeAccountId:@"uid.tid"];
    msidAccount.username = @"user@contoso.com";
    msidAccount.name = @"User";
    msidAccount.localAccountId = @"localoid";
    __auto_type authorityUrl = [NSURL URLWithString:@"https://login.microsoftonline.com/tid"];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    msidAccount.environment = authority.environment;
    msidAccount.realm = authority.realm;
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
    msidAccount.idTokenClaims = idTokenClaims;
    MSALAccount *account = [[MSALAccount alloc] initWithMSIDAccount:msidAccount createTenantProfile:YES];

    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.homeAccountId.objectId, @"uid");
    XCTAssertEqualObjects(account.homeAccountId.tenantId, @"tid");
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
    XCTAssertEqualObjects(account.identifier, @"uid.tid");
    XCTAssertNil(account.accountClaims);
    XCTAssertEqual(account.tenantProfiles.count, 1);
    XCTAssertEqualObjects(account.tenantProfiles[0].identifier, @"localoid");
    XCTAssertEqualObjects(account.tenantProfiles[0].tenantId, @"tid");
    XCTAssertEqual(account.tenantProfiles[0].isHomeTenantProfile, YES);
    XCTAssertEqualObjects(account.tenantProfiles[0].environment, authority.environment);
    XCTAssertEqualObjects(account.tenantProfiles[0].tenantId, authority.realm);
    XCTAssertEqualObjects(account.tenantProfiles[0].claims, idTokenDictionary);
}

- (void)testInitWithMSIDAccount_whenValidAccountAndCreateTenantProfileNo_shouldInitAndNotCreateTenantProfile
{
    MSIDAccount *msidAccount = [MSIDAccount new];
    msidAccount.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com" homeAccountId:@"uid.tid"];
    msidAccount.username = @"user@contoso.com";
    msidAccount.name = @"User";
    msidAccount.localAccountId = @"localoid";
    __auto_type authorityUrl = [NSURL URLWithString:@"https://login.microsoftonline.com/tid"];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    msidAccount.environment = authority.environment;
    msidAccount.realm = authority.realm;
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
    msidAccount.idTokenClaims = idTokenClaims;
    MSALAccount *account = [[MSALAccount alloc] initWithMSIDAccount:msidAccount createTenantProfile:NO];
    
    XCTAssertNotNil(account);
    XCTAssertEqualObjects(account.homeAccountId.objectId, @"uid");
    XCTAssertEqualObjects(account.homeAccountId.tenantId, @"tid");
    XCTAssertEqualObjects(account.username, @"user@contoso.com");
    XCTAssertEqualObjects(account.identifier, @"uid.tid");
    XCTAssertNil(account.accountClaims);
    XCTAssertNil(account.tenantProfiles);
}

- (void)testAddTenantProfiles_whenAddValidTenantProfiles_shouldAddIt
{
    // Create MSAL account 1
    MSIDAccount *msidAccount = [MSIDAccount new];
    msidAccount.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com" homeAccountId:@"uid.tid"];
    msidAccount.username = @"user@contoso.com";
    msidAccount.accountType = MSIDAccountTypeMSSTS;
    msidAccount.name = @"User";
    msidAccount.localAccountId = @"guest_oid";
    __auto_type authorityUrl = [NSURL URLWithString:@"https://login.microsoftonline.com/guest_tid"];
    __auto_type authority = [[MSIDAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    msidAccount.environment = authority.environment;
    msidAccount.realm = authority.realm;
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
    msidAccount.idTokenClaims = idTokenClaims;
    MSALAccount *account = [[MSALAccount alloc] initWithMSIDAccount:msidAccount createTenantProfile:YES];
    
    // Create MSAL account 2
    MSIDAccount *msidAccount2 = [msidAccount copy];
    msidAccount2.localAccountId = @"oid";
    __auto_type homeAuthorityUrl = [NSURL URLWithString:@"https://login.microsoftonline.com/tid"];
    __auto_type homeAuthority = [[MSIDAADAuthority alloc] initWithURL:homeAuthorityUrl context:nil error:nil];
    msidAccount2.environment = homeAuthority.environment;
    msidAccount2.realm = homeAuthority.realm;
    
    MSALAccount *account2 = [[MSALAccount alloc] initWithMSIDAccount:msidAccount2 createTenantProfile:YES];
    XCTAssertNotNil(account2);
    
    // Add tenant profiles
    [account addTenantProfiles:account2.tenantProfiles];
    
    XCTAssertEqual(account.tenantProfiles.count, 2);
    XCTAssertEqualObjects(account.tenantProfiles[0].identifier, @"guest_oid");
    XCTAssertEqualObjects(account.tenantProfiles[0].tenantId, @"guest_tid");
    XCTAssertEqual(account.tenantProfiles[0].isHomeTenantProfile, NO);
    XCTAssertEqualObjects(account.tenantProfiles[1].identifier, @"oid");
    XCTAssertEqualObjects(account.tenantProfiles[1].tenantId, @"tid");
    XCTAssertEqual(account.tenantProfiles[1].isHomeTenantProfile, YES);
}

- (void)testAddTenantProfiles_whenAddNilTenantProfiles_shouldNotAddToExistingAccount
{
    MSALAuthority *authority = [MSALAuthority authorityWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/tid"]
                                                         error:nil];
    XCTAssertNotNil(authority);
    MSALTenantProfile *tenantProfile = [[MSALTenantProfile alloc] initWithIdentifier:@"1"
                                                                            tenantId:@"2"
                                                                         environment:@"login.microsoftonline.com"
                                                                 isHomeTenantProfile:YES
                                                                              claims:@{@"key" : @"value"}];
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"1.2" objectId:@"1" tenantId:@"2"];
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"displayableID"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:@[tenantProfile]];
    XCTAssertNotNil(account);
    
    [account addTenantProfiles:nil];
    
    XCTAssertEqual(account.tenantProfiles.count, 1);
    XCTAssertEqualObjects(account.tenantProfiles[0].identifier, @"1");
    XCTAssertEqualObjects(account.tenantProfiles[0].tenantId, @"2");
}

- (void)testAddTenantProfiles_whenAddEmptyTenantProfiles_shouldNotAddToExistingAccount
{
    MSALAuthority *authority = [MSALAuthority authorityWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/tid"]
                                                         error:nil];
    XCTAssertNotNil(authority);
    
    MSALTenantProfile *tenantProfile = [[MSALTenantProfile alloc] initWithIdentifier:@"1"
                                                                            tenantId:@"tid"
                                                                         environment:@"login.microsoftonline.com"
                                                                 isHomeTenantProfile:YES
                                                                              claims:@{@"key" : @"value"}];
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"1.2" objectId:@"1" tenantId:@"2"];
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"displayableID"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:@[tenantProfile]];
    XCTAssertNotNil(account);

    [account addTenantProfiles:[NSArray new]];

    XCTAssertEqual(account.tenantProfiles.count, 1);
    XCTAssertEqualObjects(account.tenantProfiles[0].identifier, @"1");
    XCTAssertEqualObjects(account.tenantProfiles[0].tenantId, @"tid");
}

- (void)testCopy_whenValidAccount_shouldDeepCopy
{
    MSALAuthority *authority = [MSALAuthority authorityWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/tid"]
                                                         error:nil];
    XCTAssertNotNil(authority);
    
    MSALTenantProfile *tenantProfile = [[MSALTenantProfile alloc] initWithIdentifier:@"oid"
                                                                            tenantId:@"tid"
                                                                         environment:@"login.microsoftonline.com"
                                                                 isHomeTenantProfile:YES
                                                                              claims:@{@"key" : @"value"}];
    
    authority = [MSALAuthority authorityWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/tid2"]
                                          error:nil];
    XCTAssertNotNil(authority);
    
    MSALTenantProfile *tenantProfile2 = [[MSALTenantProfile alloc] initWithIdentifier:@"oid2"
                                                                             tenantId:@"tid2"
                                                                          environment:@"login.microsoftonline.com"
                                                                  isHomeTenantProfile:YES
                                                                               claims:@{@"key" : @"value"}];
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"1.2" objectId:@"1" tenantId:@"2"];
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"displayableID"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:@[tenantProfile, tenantProfile2]];
    XCTAssertNotNil(account);
    XCTAssertEqual(account.tenantProfiles.count, 2);
    
    MSALAccount *account2 = [account copy];
    
    XCTAssertNotNil(account2);
    
    // The two objects should have different pointers
    XCTAssertNotEqual(account, account2);
    XCTAssertEqualObjects(account.homeAccountId.objectId, account2.homeAccountId.objectId);
    XCTAssertEqualObjects(account.homeAccountId.tenantId, account2.homeAccountId.tenantId);
    XCTAssertEqualObjects(account.environment, account2.environment);
    XCTAssertEqualObjects(account.username, account2.username);
    XCTAssertEqualObjects(account.identifier, account2.identifier);
    XCTAssertEqualObjects(account.accountClaims, account2.accountClaims);
    
    // tenantProfiles should be deep copied and have different pointers
    XCTAssertNotEqual(account.tenantProfiles, account2.tenantProfiles);
    XCTAssertEqual(account.tenantProfiles.count, account2.tenantProfiles.count);
    XCTAssertNotEqual(account.tenantProfiles[0], account2.tenantProfiles[0]);
    XCTAssertNotEqual(account.tenantProfiles[1], account2.tenantProfiles[1]);
    
    XCTAssertEqualObjects(account.tenantProfiles[0].tenantId, account2.tenantProfiles[0].tenantId);
    XCTAssertEqualObjects(account.tenantProfiles[0].identifier, account2.tenantProfiles[0].identifier);
    XCTAssertEqualObjects(account.tenantProfiles[0].environment, account2.tenantProfiles[0].environment);
    XCTAssertEqualObjects(account.tenantProfiles[0].tenantId, account2.tenantProfiles[0].tenantId);
    XCTAssertEqual(account.tenantProfiles[0].isHomeTenantProfile, account2.tenantProfiles[0].isHomeTenantProfile);
    
    XCTAssertEqualObjects(account.tenantProfiles[1].tenantId, account2.tenantProfiles[1].tenantId);
    XCTAssertEqualObjects(account.tenantProfiles[1].identifier, account2.tenantProfiles[1].identifier);
    XCTAssertEqualObjects(account.tenantProfiles[1].environment, account2.tenantProfiles[1].environment);
    XCTAssertEqualObjects(account.tenantProfiles[1].tenantId, account2.tenantProfiles[1].tenantId);
    XCTAssertEqual(account.tenantProfiles[1].isHomeTenantProfile, account2.tenantProfiles[1].isHomeTenantProfile);
    
    // claims should be deep copied
    XCTAssertNotEqual(account.tenantProfiles[0].claims, account2.tenantProfiles[0].claims);
    XCTAssertEqualObjects(account.tenantProfiles[0].claims, account2.tenantProfiles[0].claims);
    XCTAssertNotEqual(account.tenantProfiles[1].claims, account2.tenantProfiles[1].claims);
    XCTAssertEqualObjects(account.tenantProfiles[1].claims, account2.tenantProfiles[1].claims);
}

- (void)testEquals_whenEqual_shouldReturnTrue
{
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"1.2" objectId:@"1" tenantId:@"2"];
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"displayableID"
                                                        homeAccountId:accountId
                                                          environment:@"login.microsoftonline.com"
                                                  tenantProfiles:nil];
    
    XCTAssertNotNil(account);
    MSALAccount *account2 = [account copy];
    
    XCTAssertNotNil(account2);
    XCTAssertEqualObjects(account, account2);
}

@end
