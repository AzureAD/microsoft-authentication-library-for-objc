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
#import "MSALTestConstants.h"
#import "MSALTestSwizzle.h"
#import "MSALBaseRequest+TestExtensions.h"
#import "MSIDTestURLSession+MSAL.h"
#import "MSALWebUI.h"
#import "NSURL+MSIDExtensions.h"
#import "MSALTestIdTokenUtil.h"
#import "MSIDTestURLSession.h"
#import "MSIDTestURLResponse+MSAL.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#import "MSIDSharedTokenCache.h"
#import "MSIDDefaultTokenCacheAccessor.h"

@interface MSALB2CPolicyTests : MSALTestCase

@property (nonatomic) MSIDSharedTokenCache *tokenCache;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCacheAccessor;

@end

@implementation MSALB2CPolicyTests

- (void)setUp
{
    [super setUp];
    
    [MSIDKeychainTokenCache reset];
    
    self.tokenCacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:MSIDKeychainTokenCache.defaultKeychainCache];
    self.tokenCache = [[MSIDSharedTokenCache alloc] initWithPrimaryCacheAccessor:self.tokenCacheAccessor otherCacheAccessors:nil];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)setupURLSessionWithB2CAuthority:(NSString *)authority policy:(NSString *)policy
{
    NSString *query = [NSString stringWithFormat:@"p=%@", policy];
    
    MSIDTestURLResponse *oidcResponse =
    [MSIDTestURLResponse oidcResponseForAuthority:authority
                                      responseUrl:@"https://login.microsoftonline.com/contosob2c"
                                            query:query];
    
    NSString *uid = [NSString stringWithFormat:@"1-%@", policy];
    
    // User identifier should be uid-policy
    MSIDTestURLResponse *tokenResponse =
    [MSIDTestURLResponse authCodeResponse:@"i am an auth code"
                                authority:@"https://login.microsoftonline.com/contosob2c"
                                    query:query
                                   scopes:[NSOrderedSet orderedSetWithArray:@[@"fakeb2cscopes", @"openid", @"profile", @"offline_access"]]
                               clientInfo:@{ @"uid" : uid, @"utid" : [MSALTestIdTokenUtil defaultTenantId]}];
    
    [MSIDTestURLSession addResponses:@[oidcResponse, tokenResponse]];
}


/*
    This is an integraton test to verify that two acquireToken calls with two different B2C policies
    result in two fully functional users that can be retrieved and used.
 */

- (void)testAcquireToken_whenMultipleB2CPolicies_shouldHaveMultipleUsers
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    // Setup acquireToken with first policy (b2c_1_policy)
    NSString *firstAuthority = @"https://login.microsoftonline.com/tfp/contosob2c/b2c_1_policy";
    [self setupURLSessionWithB2CAuthority:firstAuthority policy:@"b2c_1_policy"];
    
    [MSALTestSwizzle classMethod:@selector(startWebUIWithURL:context:completionBlock:)
                           class:[MSALWebUI class]
                           block:(id)^(id obj, NSURL *url, id<MSALRequestContext>context, MSALWebUICompletionBlock completionBlock)
     {
         (void)obj;
         (void)context;
         
         XCTAssertNotNil(url);
         
         // State preserving and url are tested separately
         NSDictionary *QPs = [NSDictionary msidURLFormDecode:url.query];
         NSString *state = QPs[@"state"];
         
         NSString *responseString = [NSString stringWithFormat:UNIT_TEST_DEFAULT_REDIRECT_URI"?code=%@&state=%@", @"i+am+an+auth+code", state];
         completionBlock([NSURL URLWithString:responseString], nil);
     }];
    
    NSError *error = nil;
    
    // Create application object with the first policy as authority
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:firstAuthority
                                                    error:&error];
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    __block dispatch_semaphore_t dsem = dispatch_semaphore_create(0);
    
    [application acquireTokenForScopes:@[@"fakeb2cscopes"]
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(error);
         XCTAssertNotNil(result);
         
         NSString *userIdentifier = [NSString stringWithFormat:@"1-b2c_1_policy.%@", [MSALTestIdTokenUtil defaultTenantId]];
         XCTAssertEqualObjects(result.user.userIdentifier, userIdentifier);
         dispatch_semaphore_signal(dsem);
     }];
    
    while (dispatch_semaphore_wait(dsem, DISPATCH_TIME_NOW))
    {
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate: [NSDate distantFuture]];
    }
    
    // Now acquiretoken call with second policy (b2c_2_policy)
    NSString *secondAuthority = @"https://login.microsoftonline.com/tfp/contosob2c/b2c_2_policy";
    
    // Override oidc and token responses for the second policy
    [self setupURLSessionWithB2CAuthority:secondAuthority policy:@"b2c_2_policy"];
    
    // Use an authority with a different policy in the second acquiretoken call
    [application acquireTokenForScopes:@[@"fakeb2cscopes"]
                  extraScopesToConsent:nil
                             loginHint:nil
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:nil
                             authority:secondAuthority
                         correlationId:nil
                       completionBlock:^(MSALResult *result, NSError *error) {
                           
                           XCTAssertNil(error);
                           XCTAssertNotNil(result);
                           
                           NSString *userIdentifier = [NSString stringWithFormat:@"1-b2c_2_policy.%@", [MSALTestIdTokenUtil defaultTenantId]];
                           XCTAssertEqualObjects(result.user.userIdentifier, userIdentifier);
        
    }];
    
    __auto_type accessTokens = [self.tokenCacheAccessor getAllTokensOfType:MSIDTokenTypeAccessToken withClientId:UNIT_TEST_CLIENT_ID context:nil error:nil];
    __auto_type refreshTokens = [self.tokenCacheAccessor getAllTokensOfType:MSIDTokenTypeAccessToken withClientId:UNIT_TEST_CLIENT_ID context:nil error:nil];
    
    // Ensure we have two different accesstokens in cache
    // and that second call doesn't overwrite first one, since policies are different
    XCTAssertEqual(accessTokens.count, 2);
    XCTAssertEqual(refreshTokens.count, 2);
    XCTAssertEqual([[application accounts:nil] count], 2);
}

@end
