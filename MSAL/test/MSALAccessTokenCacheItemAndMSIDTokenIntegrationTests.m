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

#import <XCTest/XCTest.h>
#import "MSALAccessTokenCacheItem.h"
#import "MSIDTokenCacheItem.h"
#import "MSALTokenResponse.h"
#import "MSALTestIdTokenUtil.h"
#import "MSIDJsonSerializer.h"
#import "MSALClientInfo.h"
#import "NSURL+MSIDExtensions.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSALAccessTokenCacheItemAndMSIDTokenIntegrationTests : XCTestCase

@property NSURL *testAuthority;
@property NSString *testClientId;
@property MSALTokenResponse *testTokenResponse;
@property NSString *testIdToken;
@property NSString *testClientInfo;

@end

@implementation MSALAccessTokenCacheItemAndMSIDTokenIntegrationTests

- (void)setUp
{
    [super setUp];
    
    _testAuthority = [NSURL URLWithString:@"https://login.microsoftonline.com/contoso.com"];
    _testClientId = @"5a434691-ccb2-4fd1-b97b-b64bcfbc03fc";
    _testIdToken = [MSALTestIdTokenUtil idTokenWithName:@"User 2" preferredUsername:@"user2@contoso.com"];
    _testClientInfo = [@{ @"uid" : @"2", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    
    NSDictionary *testResponse2Claims =
    @{ @"token_type" : @"Bearer",
       @"scope" : @"mail.read user.read",
       @"authority" : _testAuthority,
       @"expires_in" : @"3599",
       @"ext_expires_in" : @"10800",
       @"access_token" : @"fake-access-token",
       @"refresh_token" : @"fake-refresh-token",
       @"id_token" : _testIdToken,
       @"client_info" : _testClientInfo};
    
    _testTokenResponse = [[MSALTokenResponse alloc] initWithJson:testResponse2Claims error:nil];
}

- (void)tearDown
{
    [super tearDown];
}

// Todo:
// Because we don't read old MSAL tokens, comment out the following tests
// But we still need tests to init MSAL tokens by MSIDTokens.

//#pragma mark - MSALAccessTokenCacheItem -> MSIDToken
//
//- (void)testDeserialize_whenMSALAccessToken_shouldReturnAccessMSIDToken
//{
//    MSIDJsonSerializer *serializer = [MSIDJsonSerializer new];
//    MSALAccessTokenCacheItem *item = [[MSALAccessTokenCacheItem alloc] initWithAuthority:self.testAuthority
//                                                                                  clientId:self.testClientId
//                                                                                  response:self.testTokenResponse];
//    NSData *data = [item serialize:nil];
//    
//    MSIDToken *resultToken = [serializer deserialize:data];
//    
//    XCTAssertNotNil(resultToken);
//    XCTAssertTrue([resultToken isKindOfClass:MSIDToken.class]);
//    XCTAssertNil(resultToken.resource);
//    XCTAssertEqualObjects(resultToken.authority.absoluteString, item.authority);
//    XCTAssertEqualObjects(resultToken.clientId, item.clientId);
//    XCTAssertEqualObjects(resultToken.token, item.accessToken);
//    XCTAssertEqual(resultToken.tokenType, MSIDTokenTypeAccessToken);
//    XCTAssertEqualObjects(resultToken.expiresOn, item.expiresOn);
//    XCTAssertEqualObjects(resultToken.idToken, item.rawIdToken);
//    XCTAssertNil(resultToken.additionalServerInfo);
//    XCTAssertEqualObjects(resultToken.scopes, item.scope);
//    XCTAssertEqualObjects(resultToken.clientInfo.rawClientInfo, self.testClientInfo);
//}
//
//#pragma mark - MSIDToken -> MSALAccessTokenCacheItem
//
//- (void)testSerialize_whenAccessMSIDToken_shouldUnarchiveAsMSALAccessToken
//{
//    MSIDToken *msidToken = [self createAccessMSIDToken];
//    MSIDJsonSerializer *serializer = [MSIDJsonSerializer new];
//    NSData *data = [serializer serialize:msidToken];
//    NSError *error;
//    
//    MSALAccessTokenCacheItem *item = [[MSALAccessTokenCacheItem alloc] initWithData:data error:&error];
//    
//    XCTAssertNotNil(item);
//    XCTAssertNil(error);
//    XCTAssertEqualObjects(item.accessToken, msidToken.token);
//    XCTAssertEqualObjects(item.rawIdToken, msidToken.idToken);
//    XCTAssertEqualObjects(item.expiresOn, msidToken.expiresOn);
//    MSALClientInfo * expectedClientInfo = [[MSALClientInfo alloc] initWithRawClientInfo:msidToken.clientInfo.rawClientInfo error:nil];
//    XCTAssertEqualObjects(item.clientInfo.userIdentifier, expectedClientInfo.userIdentifier);
//    XCTAssertEqualObjects(item.authority, msidToken.authority.absoluteString);
//    XCTAssertEqualObjects(item.clientId, msidToken.clientId);
//    XCTAssertEqualObjects(item.scope, msidToken.scopes);
//}
//
//#pragma mark - MSALRefreshTokenCacheItem -> MSIDToken
//
//- (void)testDeserialize_whenMSALRefreshTokenCacheItem_shouldReturnRefreshMSIDToken
//{
//    MSIDJsonSerializer *serializer = [MSIDJsonSerializer new];
//    MSALRefreshTokenCacheItem *item = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:self.testAuthority.msidHostWithPortIfNecessary clientId:self.testClientId response:self.testTokenResponse];
//    NSData *data = [item serialize:nil];
//    
//    MSIDToken *resultToken = [serializer deserialize:data];
//    
//    XCTAssertNotNil(resultToken);
//    XCTAssertTrue([resultToken isKindOfClass:MSIDToken.class]);
//    XCTAssertNil(resultToken.resource);
//    XCTAssertEqualObjects(resultToken.authority.absoluteString, @"https://login.microsoftonline.com/common");
//    XCTAssertEqualObjects(resultToken.clientId, item.clientId);
//    XCTAssertEqualObjects(resultToken.token, item.refreshToken);
//    XCTAssertEqual(resultToken.tokenType, MSIDTokenTypeRefreshToken);
//    XCTAssertNil(resultToken.expiresOn);
//    XCTAssertNil(resultToken.idToken);
//    XCTAssertNil(resultToken.additionalServerInfo);
//    XCTAssertNil(resultToken.scopes);
//    XCTAssertEqualObjects(resultToken.clientInfo.rawClientInfo, self.testClientInfo);
//    XCTAssertEqualObjects(resultToken.clientId, item.clientId);
//}
//
//#pragma mark - MSIDToken -> MSALRefreshTokenCacheItem
//
//- (void)testSerialize_whenRefreshMSIDToken_shouldUnarchiveAsMSALRefreshTokenCacheItem
//{
//    MSIDToken *msidToken = [self createRefreshMSIDToken];
//    MSIDJsonSerializer *serializer = [MSIDJsonSerializer new];
//    NSData *data = [serializer serialize:msidToken];
//    NSError *error;
//    
//    MSALRefreshTokenCacheItem *item = [[MSALRefreshTokenCacheItem alloc] initWithData:data error:&error];
//    
//    XCTAssertNotNil(item);
//    XCTAssertNil(error);
//    XCTAssertEqualObjects(item.clientId, msidToken.clientId);
//    MSALClientInfo * expectedClientInfo = [[MSALClientInfo alloc] initWithRawClientInfo:msidToken.clientInfo.rawClientInfo error:nil];
//    XCTAssertEqualObjects(item.clientInfo.userIdentifier, expectedClientInfo.userIdentifier);
//    XCTAssertEqualObjects(item.refreshToken, msidToken.token);
//    XCTAssertEqualObjects(item.environment, @"login.microsoftonline.com");
//    XCTAssertNil(item.displayableId);
//    XCTAssertNil(item.name);
//    XCTAssertNil(item.identityProvider);
//}
//
//#pragma mark - Private
//
//- (MSIDToken *)createAccessMSIDToken
//{
//    MSIDToken *token = [MSIDToken new];
//    [token setValue:@"fake-access-token" forKey:@"token"];
//    [token setValue:self.testIdToken forKey:@"idToken"];
//    [token setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
//    [token setValue:@"familyId value" forKey:@"familyId"];
//    MSIDClientInfo *clientInfo = [MSIDClientInfo new];
//    [clientInfo setValue:self.testClientInfo forKey:@"rawClientInfo"];
//    [token setValue:clientInfo forKey:@"clientInfo"];
//    [token setValue:@{@"key2" : @"value2"} forKey:@"additionalServerInfo"];
//    [token setValue:@"test resource" forKey:@"resource"];
//    [token setValue:self.testAuthority forKey:@"authority"];
//    [token setValue:self.testClientId forKey:@"clientId"];
//    [token setValue:[[NSOrderedSet alloc] initWithArray:@[@"mail.read", @"user.read"]] forKey:@"scopes"];
//    
//    return token;
//}
//
//- (MSIDToken *)createRefreshMSIDToken
//{
//    MSIDToken *token = [MSIDToken new];
//    [token setValue:@"fake-refresh-token" forKey:@"token"];
//    [token setValue:[[NSNumber alloc] initWithInt:MSIDTokenTypeRefreshToken] forKey:@"tokenType"];
//    [token setValue:self.testIdToken forKey:@"idToken"];
//    [token setValue:[NSDate dateWithTimeIntervalSince1970:1500000000] forKey:@"expiresOn"];
//    [token setValue:@"familyId value" forKey:@"familyId"];
//    MSIDClientInfo *clientInfo = [MSIDClientInfo new];
//    [clientInfo setValue:self.testClientInfo forKey:@"rawClientInfo"];
//    [token setValue:clientInfo forKey:@"clientInfo"];
//    [token setValue:@{@"key2" : @"value2"} forKey:@"additionalServerInfo"];
//    [token setValue:@"test resource" forKey:@"resource"];
//    [token setValue:self.testAuthority forKey:@"authority"];
//    [token setValue:self.testClientId forKey:@"clientId"];
//    [token setValue:[[NSOrderedSet alloc] initWithArray:@[@"mail.read", @"user.read"]] forKey:@"scopes"];
//    
//    return token;
//}

@end
