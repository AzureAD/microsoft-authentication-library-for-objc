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
#import "MSIDKeychainTokenCache.h"
#import "MSIDTokenCacheKey.h"
#import "MSIDToken.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#import "MSALTestIdTokenUtil.h"
#import "MSALTokenResponse.h"
#import "MSIDJsonSerializer.h"
#import "NSURL+MSIDExtensions.h"
#import "NSDictionary+MSIDTestUtil.h"

@interface MSALKeychainTokenCacheAndMSIDKeychainTokenCacheIntegrationTests : XCTestCase

@property NSURL *testAuthority;
@property NSString *testClientId;
@property MSALTokenResponse *testTokenResponse;
@property NSString *testIdToken;
@property NSString *testClientInfo;

@end

@implementation MSALKeychainTokenCacheAndMSIDKeychainTokenCacheIntegrationTests

- (void)setUp
{
    [super setUp];
    
    [MSIDKeychainTokenCache reset];
    
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
    
    [MSIDKeychainTokenCache reset];
}

#pragma mark - Access token, MSALKeychainTokenCache -> MSIDKeychainTokenCache

- (void)test_saveAccessTokenInMSALKeychainTokenCache_MSIDKeychainShouldFindMSIDToken
{
    MSALKeychainTokenCache *msalKeychainTokenCache = [MSALKeychainTokenCache defaultKeychainCache];
    
    MSALAccessTokenCacheItem *item = [[MSALAccessTokenCacheItem alloc] initWithAuthority:self.testAuthority
                                                                                clientId:self.testClientId
                                                                                response:self.testTokenResponse];
    NSError *error;
    BOOL result = [msalKeychainTokenCache addOrUpdateAccessTokenItem:item context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    MSIDKeychainTokenCache *msidKeychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:nil];
    MSIDTokenCacheKey *msidTokenCacheKey = [MSIDTokenCacheKey new];
    msidTokenCacheKey.service = @"aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2NvbnRvc28uY29t$NWE0MzQ2OTEtY2NiMi00ZmQxLWI5N2ItYjY0YmNmYmMwM2Zj$bWFpbC5yZWFkIHVzZXIucmVhZA";
    msidTokenCacheKey.account = @"1297315377$Mi4xMjM0LTU2NzgtOTBhYmNkZWZn@bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ";
    
    MSIDToken *msidToken = [msidKeychainTokenCache itemWithKey:msidTokenCacheKey serializer:[MSIDJsonSerializer new] context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(msidToken);
}

#pragma mark - Refresh token, MSALKeychainTokenCache -> MSIDKeychainTokenCache

- (void)test_saveRefreshTokenInMSALKeychainTokenCache_MSIDKeychainShouldFindMSIDToken
{
    MSALKeychainTokenCache *msalKeychainTokenCache = [MSALKeychainTokenCache defaultKeychainCache];
    
    MSALRefreshTokenCacheItem *item = [[MSALRefreshTokenCacheItem alloc] initWithEnvironment:self.testAuthority.msidHostWithPortIfNecessary clientId:self.testClientId response:self.testTokenResponse];
    
    NSError *error;
    BOOL result = [msalKeychainTokenCache addOrUpdateRefreshTokenItem:item context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    MSIDKeychainTokenCache *msidKeychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:nil];
    MSIDTokenCacheKey *msidTokenCacheKey = [MSIDTokenCacheKey new];
    msidTokenCacheKey.service = @"NWE0MzQ2OTEtY2NiMi00ZmQxLWI5N2ItYjY0YmNmYmMwM2Zj";
    msidTokenCacheKey.account = @"1297315377$Mi4xMjM0LTU2NzgtOTBhYmNkZWZn@bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ";
    
    MSIDToken *msidToken = [msidKeychainTokenCache itemWithKey:msidTokenCacheKey serializer:[MSIDJsonSerializer new] context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(msidToken);
}

#pragma mark - Access token, MSIDKeychainTokenCache -> MSALKeychainTokenCache

- (void)test_saveMSIDTokenInMSIDKeychain_MSALKeychainTokenCacheShouldFindMSALAccessTokenCacheItem
{
    MSIDKeychainTokenCache *msidKeychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:nil];
    
    MSIDTokenCacheKey *msidTokenCacheKey = [MSIDTokenCacheKey new];
    msidTokenCacheKey.service = @"aHR0cHM6Ly9sb2dpbi5taWNyb3NvZnRvbmxpbmUuY29tL2NvbnRvc28uY29t$NWE0MzQ2OTEtY2NiMi00ZmQxLWI5N2ItYjY0YmNmYmMwM2Zj$bWFpbC5yZWFkIHVzZXIucmVhZA";
    msidTokenCacheKey.account = @"1297315377$Mg@bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ";
    
    MSIDToken *token = [MSIDToken new];
    NSOrderedSet *scopes = [[NSOrderedSet alloc] initWithArray:@[@"mail.read", @"user.read"]];
    [token setValue:@"fake-access-token" forKey:@"token"];
    [token setValue:[[NSNumber alloc] initWithInt:MSIDTokenTypeAccessToken] forKey:@"tokenType"];
    [token setValue:self.testIdToken forKey:@"idToken"];
    [token setValue:self.testAuthority forKey:@"authority"];
    [token setValue:self.testClientId forKey:@"clientId"];
    [token setValue:scopes forKey:@"scopes"];
    
    NSError *error;
    BOOL result = [msidKeychainTokenCache setItem:token key:msidTokenCacheKey serializer:[MSIDJsonSerializer new] context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    MSALAccessTokenCacheKey *key = [[MSALAccessTokenCacheKey alloc] initWithAuthority:self.testAuthority.absoluteString clientId:self.testClientId scope:scopes userIdentifier:@"2" environment:@"login.microsoftonline.com"];
    
    MSALKeychainTokenCache *msalKeychainTokenCache = [MSALKeychainTokenCache defaultKeychainCache];
    NSArray *items = [msalKeychainTokenCache getAccessTokenItemsWithKey:key context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertEqual(items.count, 1);
}

#pragma mark - Refresh token, MSIDKeychainTokenCache -> MSALKeychainTokenCache

- (void)test_saveMSIDTokenInMSIDKeychain_MSALKeychainTokenCacheShouldFindMSALRefreshTokenCacheItem
{
    MSIDKeychainTokenCache *msidKeychainTokenCache = [[MSIDKeychainTokenCache alloc] initWithGroup:nil];
    
    MSIDTokenCacheKey *msidTokenCacheKey = [MSIDTokenCacheKey new];
    msidTokenCacheKey.service = @"NWE0MzQ2OTEtY2NiMi00ZmQxLWI5N2ItYjY0YmNmYmMwM2Zj";
    msidTokenCacheKey.account = @"1297315377$Mg@bG9naW4ubWljcm9zb2Z0b25saW5lLmNvbQ";
    
    MSIDToken *token = [MSIDToken new];
    [token setValue:@"fake-refresh-token" forKey:@"token"];
    [token setValue:[[NSNumber alloc] initWithInt:MSIDTokenTypeRefreshToken] forKey:@"tokenType"];
    
    NSError *error;
    BOOL result = [msidKeychainTokenCache setItem:token key:msidTokenCacheKey serializer:[MSIDJsonSerializer new] context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(result);
    
    MSALRefreshTokenCacheKey *key = [[MSALRefreshTokenCacheKey alloc] initWithEnvironment:@"login.microsoftonline.com" clientId:self.testClientId userIdentifier:@"2"];
    
    MSALKeychainTokenCache *msalKeychainTokenCache = [MSALKeychainTokenCache defaultKeychainCache];
    MSALRefreshTokenCacheItem *item = [msalKeychainTokenCache getRefreshTokenItemForKey:key context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(item);
}

@end
