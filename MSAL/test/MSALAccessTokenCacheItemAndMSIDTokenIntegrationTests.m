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
#import "MSIDClientInfo.h"
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
// Because we don't read old MSAL tokens, removed the following tests
// But we still need tests to init MSAL tokens by MSIDTokens.

@end
