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

#import "MSALTestBundle.h"
#import "MSALTestCacheDataUtil.h"
#import "MSALTestURLSession.h"
#import "NSDictionary+MSALTestUtil.h"

#import "MSALPublicClientApplication+Internal.h"

@interface MSALAcquireTokenTests : MSALTestCase

@end

@implementation MSALAcquireTokenTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testAcquireTokenSilent_whenNoATForScopeInCache_shouldUseRTAndReturnNewAT
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[@"x-msauth-com-microsoft-unittests", @"adaliosxformsapp"] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    // Seed a cache object with a user and existing AT that does not match the scope we will ask for
    MSALTestCacheDataUtil *cacheUtil = [MSALTestCacheDataUtil defaultUtil];
    MSALUser *user = [cacheUtil addUserWithDisplayId:@"user1@contoso.com"];
    XCTAssertNotNil(user);
    XCTAssertNotNil([cacheUtil addATforScopes:@[@"user.read"] tenant:@"contoso" user:user]);
    XCTAssertEqual(cacheUtil.allAccessTokens.count, 1);
    
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:[MSALTestCacheDataUtil defaultClientId]
                                                    error:&error];
    XCTAssertNotNil(application);
    application.tokenCache = cacheUtil.cache;
    
    
    
    // Set up the network responses for OIDC discovery and the RT response
    NSString *authority = @"https://login.microsoftonline.com/contoso";
    NSOrderedSet *expectedScopes = [NSOrderedSet orderedSetWithArray:@[@"mail.read", @"openid", @"profile", @"offline_access"]];
    MSALTestURLResponse *oidcResponse = [MSALTestURLResponse oidResponseForAuthority:authority];
    MSALTestURLResponse *tokenResponse = [MSALTestURLResponse rtResponseForScopes:expectedScopes authority:authority tenantId:nil user:user];
    [MSALTestURLSession addResponses:@[oidcResponse, tokenResponse]];
    
    __block dispatch_semaphore_t dsem = dispatch_semaphore_create(0);
    
    // Acquire a token silently for a scope that does not exist in cache
    [application acquireTokenSilentForScopes:@[@"mail.read"]
                                        user:user
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         // Ensure we get back the proper access token
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         XCTAssertEqualObjects(result.accessToken, @"i am an updated access token!");
         
         dispatch_semaphore_signal(dsem);
     }];
    
    dispatch_semaphore_wait(dsem, DISPATCH_TIME_FOREVER);
    
    // Ensure we now have two access tokens in the cache, as the updated token should not overwrite the
    // existing one as there is a mismatch in scopes.
    XCTAssertEqual(cacheUtil.allAccessTokens.count, 2);
    
    application = nil;
}

@end
