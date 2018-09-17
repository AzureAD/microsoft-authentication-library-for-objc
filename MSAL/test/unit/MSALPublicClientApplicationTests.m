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
#import "MSALPublicClientApplication+Internal.h"
#import "MSALBaseRequest+TestExtensions.h"
#import "MSALTestSwizzle.h"
#import "MSALTestBundle.h"
#import "MSIDClientInfo.h"
#import "MSALTestConstants.h"
#import "MSIDClientInfo.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDAccount.h"
#import "MSALAccount+Internal.h"
#import "MSIDAADOauth2Factory.h"
#import "MSIDAADV2IdTokenClaims.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDAccountCredentialCache.h"
#import "MSALAccountId.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDAADAuthority.h"
#import "NSString+MSALTestUtil.h"
#import "MSALAADAuthority.h"
#import "MSALAuthority_Internal.h"
#import "MSIDMacTokenCache.h"
#import "MSIDAuthorityFactory.h"

@interface MSALFakeInteractiveRequest : NSObject

@property NSString *state;
@property MSALRequestParameters *parameters;

@end

@implementation MSALFakeInteractiveRequest

@end

@interface MSALPublicClientApplicationTests : MSALTestCase

@property (nonatomic) MSIDClientInfo *clientInfo;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCacheAccessor;

@end

@implementation MSALPublicClientApplicationTests

- (void)setUp
{
    [super setUp];
 
    NSString *base64String = [@{ @"uid" : @"1", @"utid" : @"1234-5678-90abcdefg"} msidBase64UrlJson];
    self.clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:base64String error:nil];

    id<MSIDTokenCacheDataSource> dataSource = nil;

#if TARGET_OS_IPHONE
    dataSource = MSIDKeychainTokenCache.defaultKeychainCache;
#else
    dataSource = MSIDMacTokenCache.defaultCache;
#endif

    self.tokenCacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil factory:[MSIDAADV2Oauth2Factory new]];
    [self.tokenCacheAccessor clearWithContext:nil error:nil];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testNilClientId
{
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:nil
                                                    error:&error];
    
    XCTAssertNil(application);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertNotNil(error.userInfo);
    XCTAssertNotNil(error.userInfo[MSALErrorDescriptionKey]);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"clientId"]);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
}

- (void)testInit
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                    error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
#if TARGET_OS_IPHONE
    XCTAssertEqualObjects(application.keychainGroup, @"com.microsoft.adalcache");
#endif
}

- (void)testInitWithClientIdAndAuthority_whenValidClientIdAndAuthority_shouldReturnApplicationAndNilError
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];

    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                                    error:&error];

    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.authority, authority);
    XCTAssertEqualObjects(application.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
#if TARGET_OS_IPHONE
    XCTAssertEqualObjects(application.keychainGroup, @"com.microsoft.adalcache");
#endif
}

- (void)testInitWithClientIdAndAuthorityAndRedirectUri_whenValidClientIdAndAuthorityAndRedirectUri_shouldReturnApplicationAndNilError
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"mycustom.redirect"] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];

    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                              redirectUri:@"mycustom.redirect://bundle_id"
                                                    error:&error];

    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.authority, authority);
    XCTAssertEqualObjects(application.redirectUri, @"mycustom.redirect://bundle_id");
#if TARGET_OS_IPHONE
    XCTAssertEqualObjects(application.keychainGroup, @"com.microsoft.adalcache");
#endif
}

#if TARGET_OS_IPHONE

- (void)testInitWithClientId_whenSchemeNotRegistered_shouldReturnNilApplicationAndFillError
{
    // By default the initializer for MSALPublicClientApplication should fail due to the redirect URI
    // not being listed in the info plist
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                    error:&error];

    XCTAssertNil(application);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorRedirectSchemeNotRegistered);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
}

- (void)testInitWithClientIdAndAuthorityAndRedirectUri_whenInvalidSchemeRegistered_shouldReturnNilApplicationAndFillError
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"mycustom.redirect"] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];

    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                              redirectUri:@"mycustom.wrong.redirect://bundle_id"
                                                    error:&error];

    XCTAssertNil(application);
    XCTAssertNotNil(error);
}

- (void)testInitWithClientIdAndKeychainGroup_whenAllValidParameters_shouldReturnApplicationAndNilError
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                            keychainGroup:@"com.contoso.msalcache"
                                                    error:&error];

    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
    XCTAssertEqualObjects(application.keychainGroup, @"com.contoso.msalcache");
}

- (void)testInitWithClientIdAndAuthorityAndKeychainGroup_whenAllValidParameters_shouldReturnApplicationAndNilError
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];

    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                            keychainGroup:@"com.contoso.msalcache"
                                                authority:authority
                                                    error:&error];

    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.authority, authority);
    XCTAssertEqualObjects(application.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
    XCTAssertEqualObjects(application.keychainGroup, @"com.contoso.msalcache");
}

- (void)testInitWithClientIdAndAuthorityAndRedirectUriAndKeychainGroup_whenAllValidParameters_shouldReturnApplicationAndNilError
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"mycustom.redirect"] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];

    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                            keychainGroup:@"com.contoso.msalcache"
                                                authority:authority
                                              redirectUri:@"mycustom.redirect://bundle_id"
                                                    error:&error];

    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.authority, authority);
    XCTAssertEqualObjects(application.redirectUri, @"mycustom.redirect://bundle_id");
    XCTAssertEqualObjects(application.keychainGroup, @"com.contoso.msalcache");
}

- (void)testInitWithClientId_whenKeychainGroupNotSpecified_shouldHaveDefaultKeychainGroup
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    MSALPublicClientApplication *app = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID error:nil];
    XCTAssertEqualObjects(app.keychainGroup, MSIDKeychainTokenCache.defaultKeychainGroup);
}

- (void)testInitWithClientIdAndAuthority_whenKeychainGroupNotSpecified_shouldHaveDefaultKeychainGroup
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    MSALPublicClientApplication *app = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID authority:authority error:nil];
    XCTAssertEqualObjects(app.keychainGroup, MSIDKeychainTokenCache.defaultKeychainGroup);
}

- (void)testInitWithClientIdAndAuthorityAndRedirectUri_whenKeychainGroupNotSpecified_shouldHaveDefaultKeychainGroup
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"mycustom.redirect"] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    MSALPublicClientApplication *app = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID authority:authority redirectUri:@"mycustom.redirect://bundle_id" error:nil];
    XCTAssertEqualObjects(app.keychainGroup, MSIDKeychainTokenCache.defaultKeychainGroup);
}



- (void)testInitWithClientIdAndAuthorityAndRedirectUriAndKeychainGroup_whenKeychainGroupSpecifiedNil_shouldHaveKeychainGroupWithBundleId
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"mycustom.redirect"] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                            keychainGroup:nil
                                                authority:authority
                                              redirectUri:@"mycustom.redirect://bundle_id"
                                                    error:nil];
    
    XCTAssertEqualObjects(application.keychainGroup, [[NSBundle mainBundle] bundleIdentifier]);
}

- (void)testInitWithClientIdAndAuthorityAndRedirectUriAndKeychainGroup_whenKeychainGroupCustomSpecified_shouldHaveCustomKeychainGroup
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"mycustom.redirect"] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                            keychainGroup:@"com.contoso.msalcache"
                                                authority:authority
                                              redirectUri:@"mycustom.redirect://bundle_id"
                                                    error:nil];
    
    XCTAssertEqualObjects(application.keychainGroup, @"com.contoso.msalcache");
}
#endif

#pragma 
#pragma mark - acquireToken

- (void)testAcquireTokenScopes
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    __auto_type authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                                    error:&error];
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    __block dispatch_semaphore_t dsem = dispatch_semaphore_create(0);
    
    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALInteractiveRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALInteractiveRequest class]]);
         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);
         
         XCTAssertEqual(params.apiId, MSALTelemetryApiIdAcquire);
         XCTAssertEqualObjects(params.unvalidatedAuthority, [@"https://login.microsoftonline.com/common" msalAuthority].msidAuthority);
         XCTAssertEqualObjects(params.scopes, [NSOrderedSet orderedSetWithObject:@"fakescope"]);
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         XCTAssertNil(params.extraQueryParameters);
         XCTAssertNil(params.loginHint);
         XCTAssertNil(params.logComponent);
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    [application acquireTokenForScopes:@[@"fakescope"]
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNil(error);
         
         dispatch_semaphore_signal(dsem);
     }];
    
    dispatch_semaphore_wait(dsem, DISPATCH_TIME_NOW);
    application = nil;
}

#pragma
#pragma mark - acquireToken using Login Hint

- (void)testAcquireScopesLoginHint
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    __auto_type authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                                    error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALInteractiveRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALInteractiveRequest class]]);
         
         XCTAssertNil(obj.extraScopesToConsent);
         XCTAssertEqual(obj.uiBehavior, MSALUIBehaviorDefault);
         
         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);
         
         XCTAssertEqual(params.apiId, MSALTelemetryApiIdAcquireWithHint);
         XCTAssertEqualObjects(params.unvalidatedAuthority.url.absoluteString, @"https://login.microsoftonline.com/common");
         XCTAssertEqualObjects(params.scopes, ([NSOrderedSet orderedSetWithObjects:@"fakescope1", @"fakescope2", nil]));
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         XCTAssertNotNil(params.correlationId);
         XCTAssertNil(params.extraQueryParameters);
         XCTAssertEqualObjects(params.loginHint, @"fakeuser@contoso.com");
         
         completionBlock(nil, nil);
     }];
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                             loginHint:@"fakeuser@contoso.com"
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNil(error);
     }];
}

- (void)testAcquireScopesLoginHintBehaviorEQPs
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    __auto_type authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                                    error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALInteractiveRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALInteractiveRequest class]]);
         
         XCTAssertNil(obj.extraScopesToConsent);
         XCTAssertEqual(obj.uiBehavior, MSALForceLogin);
         
         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);
         
         XCTAssertEqual(params.apiId, MSALTelemetryApiIdAcquireWithHintBehaviorAndParameters);
         XCTAssertEqualObjects(params.unvalidatedAuthority.url.absoluteString, @"https://login.microsoftonline.com/common");
         XCTAssertEqualObjects(params.scopes, ([NSOrderedSet orderedSetWithObjects:@"fakescope1", @"fakescope2", nil]));
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         XCTAssertNotNil(params.correlationId);
         XCTAssertEqualObjects(params.extraQueryParameters, (@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }));
         XCTAssertEqualObjects(params.loginHint, @"fakeuser@contoso.com");
         
         completionBlock(nil, nil);
     }];
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                             loginHint:@"fakeuser@contoso.com"
                            uiBehavior:MSALForceLogin
                  extraQueryParameters:@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNil(error);
     }];
}

- (void)testAcquireScopesAddlScopesLoginHintuiBehaviorEQPAuthorityCorrelationId
{
    NSError *error = nil;
    
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    __auto_type authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                                    error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    __block NSUUID *correlationId = [NSUUID new];
    
    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALInteractiveRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALInteractiveRequest class]]);
         
         XCTAssertEqualObjects(obj.extraScopesToConsent, [NSOrderedSet orderedSetWithArray:@[@"fakescope3"]]);
         XCTAssertEqual(obj.uiBehavior, MSALForceConsent);
         
         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);
         
         XCTAssertEqual(params.apiId, MSALTelemetryApiIdAcquireWithHintBehaviorParametersAuthorityAndCorrelationId);
         XCTAssertEqualObjects(params.unvalidatedAuthority.url.absoluteString, @"https://login.microsoftonline.com/contoso.com");
         XCTAssertEqualObjects(params.scopes, ([NSOrderedSet orderedSetWithObjects:@"fakescope1", @"fakescope2", nil]));
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         XCTAssertEqualObjects(params.correlationId, correlationId);
         XCTAssertEqualObjects(params.extraQueryParameters, (@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }));
         XCTAssertEqualObjects(params.loginHint, @"fakeuser@contoso.com");
         
         completionBlock(nil, nil);
     }];
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/contoso.com"];
    authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                      extraScopesToConsent:@[@"fakescope3"]
                             loginHint:@"fakeuser@contoso.com"
                            uiBehavior:MSALForceConsent
                  extraQueryParameters:@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }
                             authority:authority
                         correlationId:correlationId
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNil(error);
     }];
}

#pragma
#pragma mark - acquireToken using User

- (void)testAcquireScopesUser
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    __auto_type authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                                    error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);

    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:nil];
    
    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALInteractiveRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALInteractiveRequest class]]);
         XCTAssertNil(obj.extraScopesToConsent);
         XCTAssertEqual(obj.uiBehavior, MSALUIBehaviorDefault);
         
         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);
         
         XCTAssertEqual(params.apiId, MSALTelemetryApiIdAcquireWithUserBehaviorAndParameters);
         XCTAssertEqualObjects(params.unvalidatedAuthority.url.absoluteString, @"https://login.microsoftonline.com/common");
         XCTAssertEqualObjects(params.scopes, ([NSOrderedSet orderedSetWithObjects:@"fakescope1", @"fakescope2", nil]));
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         XCTAssertNotNil(params.correlationId);
         XCTAssertNil(params.extraQueryParameters);
         XCTAssertNil(params.loginHint);
         XCTAssertEqualObjects(params.account, account);
         
         completionBlock(nil, nil);
     }];
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                               account:account
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNil(error);
     }];
}


- (void)testAcquireScopesUserUiBehaviorEQP
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    __auto_type authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                                    error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:nil];
    
    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALInteractiveRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALInteractiveRequest class]]);
         XCTAssertNil(obj.extraScopesToConsent);
         XCTAssertEqual(obj.uiBehavior, MSALUIBehaviorDefault);
         
         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);
         
         XCTAssertEqual(params.apiId, MSALTelemetryApiIdAcquireWithUserBehaviorAndParameters);
         XCTAssertEqualObjects(params.unvalidatedAuthority.url.absoluteString, @"https://login.microsoftonline.com/common");
         XCTAssertEqualObjects(params.scopes, ([NSOrderedSet orderedSetWithObjects:@"fakescope1", @"fakescope2", nil]));
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         XCTAssertNotNil(params.correlationId);
         XCTAssertEqualObjects(params.extraQueryParameters, (@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }));
         XCTAssertNil(params.loginHint);
         XCTAssertEqualObjects(params.account, account);
         
         completionBlock(nil, nil);
     }];
    
     [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                                account:account
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }
                       completionBlock:^(MSALResult *result, NSError *error)
    {
        XCTAssertNil(result);
        XCTAssertNil(error);
    }];
}

- (void)testAcquireScopesAddlScopesUserUiBehaviorEQPAuthorityCorrelationId
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    __auto_type authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                                    error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    __block NSUUID *correlationId = [NSUUID new];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:nil];
    
    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALInteractiveRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALInteractiveRequest class]]);
         
         XCTAssertEqualObjects(obj.extraScopesToConsent, [NSOrderedSet orderedSetWithArray:@[@"fakescope3"]]);
         XCTAssertEqual(obj.uiBehavior, MSALUIBehaviorDefault);
         
         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);
         
         XCTAssertEqual(params.apiId, MSALTelemetryApiIdAcquireWithUserBehaviorParametersAuthorityAndCorrelationId);
         XCTAssertEqualObjects(params.unvalidatedAuthority.url.absoluteString, @"https://login.microsoftonline.com/contoso.com");
         XCTAssertEqualObjects(params.scopes, ([NSOrderedSet orderedSetWithObjects:@"fakescope1", @"fakescope2", nil]));
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         XCTAssertEqualObjects(params.correlationId, correlationId);
         XCTAssertEqualObjects(params.extraQueryParameters, (@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }));
         XCTAssertNil(params.loginHint);
         XCTAssertEqualObjects(params.account, account);
         
         completionBlock(nil, nil);
     }];
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/contoso.com"];
    authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                      extraScopesToConsent:@[@"fakescope3"]
                                    account:account
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }
                             authority:authority
                         correlationId:correlationId
                       completionBlock:^(MSALResult *result, NSError *error)
    {
        XCTAssertNil(result);
        XCTAssertNil(error);
    }];
   
}

#pragma
#pragma mark - acquireTokenSilent

- (void)testAcquireSilentScopesUser
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    __auto_type authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                                    error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALSilentRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALSilentRequest class]]);

         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);

         XCTAssertEqual(params.apiId, MSALTelemetryApiIdAcquireSilentWithUser);
         XCTAssertEqualObjects(params.account.username, @"user@contoso.com");
         XCTAssertEqualObjects(params.account.name, @"name");
         XCTAssertEqualObjects(params.account.homeAccountId.identifier, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.account.homeAccountId.tenantId, @"1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.account.homeAccountId.objectId, @"1");
         XCTAssertEqualObjects(params.account.environment, @"login.microsoftonline.com");
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         
         XCTAssertEqualObjects(params.unvalidatedAuthority, [@"https://login.microsoftonline.com/1234-5678-90abcdefg" msalAuthority].msidAuthority);
         
         XCTAssertFalse(obj.forceRefresh);
         
         XCTAssertEqualObjects(params.scopes, ([NSOrderedSet orderedSetWithObjects:@"fakescope1", @"fakescope2", nil]));
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:nil];
    
    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
                                 XCTAssertNil(result);
                                 XCTAssertNil(error);
     }];
}

- (void)testAcquireSilentScopesUserAuthority
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    __auto_type authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                                    error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALSilentRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALSilentRequest class]]);
         
         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);
         
         XCTAssertEqual(params.apiId, MSALTelemetryApiIdAcquireSilentWithUserAndAuthority);
         XCTAssertEqualObjects(params.account.username, @"user@contoso.com");
         XCTAssertEqualObjects(params.account.name, @"name");
         XCTAssertEqualObjects(params.account.homeAccountId.identifier, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.account.homeAccountId.tenantId, @"1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.account.homeAccountId.objectId, @"1");
         XCTAssertEqualObjects(params.account.environment, @"login.microsoftonline.com");
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         
         XCTAssertEqualObjects(params.unvalidatedAuthority.url.absoluteString, @"https://login.microsoft.com/1234-5678-90abcdefg");
         
         XCTAssertFalse(obj.forceRefresh);
         
         XCTAssertEqualObjects(params.scopes, ([NSOrderedSet orderedSetWithObjects:@"fakescope1", @"fakescope2", nil]));
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoft.com/common"];
    authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:nil];
    
    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
                                   authority:authority
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNil(error);
     }];
    
}

- (void)testAcquireSilentScopesUser_whenNoAuthority_andCommonAuthorityInPublicClientApplication_shouldUseAccountHomeAuthority
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    __auto_type authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];

    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                                    error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };

    XCTAssertNotNil(application);
    XCTAssertNil(error);

    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALSilentRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALSilentRequest class]]);

         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);

         XCTAssertEqual(params.apiId, MSALTelemetryApiIdAcquireSilentWithUser);
         XCTAssertEqualObjects(params.account.username, @"user@contoso.com");
         XCTAssertEqualObjects(params.account.name, @"name");
         XCTAssertEqualObjects(params.account.homeAccountId.identifier, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.account.homeAccountId.tenantId, @"1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.account.homeAccountId.objectId, @"1");
         XCTAssertEqualObjects(params.account.environment, @"login.microsoftonline.com");
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });

         XCTAssertEqualObjects(params.unvalidatedAuthority.url.absoluteString, @"https://login.microsoftonline.com/1234-5678-90abcdefg");

         XCTAssertFalse(obj.forceRefresh);

         XCTAssertEqualObjects(params.scopes, ([NSOrderedSet orderedSetWithObjects:@"fakescope1", @"fakescope2", nil]));
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);

         XCTAssertNotNil(params.correlationId);

         completionBlock(nil, nil);
     }];

    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"custom_guest_tenant"
                                                      clientInfo:nil];

    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNil(error);
     }];

}

- (void)testAcquireSilentScopesUser_whenNoAuthority_andNonCommonAuthorityInPublicClientApplication_shouldUseThatAuthority
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    __auto_type authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/custom_guest_tenant"];
    __auto_type authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];

    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                                    error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };

    XCTAssertNotNil(application);
    XCTAssertNil(error);

    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALSilentRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALSilentRequest class]]);

         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);

         XCTAssertEqual(params.apiId, MSALTelemetryApiIdAcquireSilentWithUser);
         XCTAssertEqualObjects(params.account.username, @"user@contoso.com");
         XCTAssertEqualObjects(params.account.name, @"name");
         XCTAssertEqualObjects(params.account.homeAccountId.identifier, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.account.homeAccountId.tenantId, @"1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.account.homeAccountId.objectId, @"1");
         XCTAssertEqualObjects(params.account.environment, @"login.microsoftonline.com");
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });

         XCTAssertEqualObjects(params.unvalidatedAuthority.url.absoluteString, @"https://login.microsoftonline.com/custom_guest_tenant");

         XCTAssertFalse(obj.forceRefresh);

         XCTAssertEqualObjects(params.scopes, ([NSOrderedSet orderedSetWithObjects:@"fakescope1", @"fakescope2", nil]));
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);

         XCTAssertNotNil(params.correlationId);

         completionBlock(nil, nil);
     }];

    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"custom_guest_tenant"
                                                      clientInfo:nil];

    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNil(error);
     }];

}

- (void)testAcquireSilentScopesUser_whenNilAuthority_andNonCommonAuthorityInPublicClientApplication_shouldUseThatAuthority
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    __auto_type authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/custom_guest_tenant"];
    __auto_type authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];

    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                                    error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };

    XCTAssertNotNil(application);
    XCTAssertNil(error);

    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALSilentRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALSilentRequest class]]);

         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);

         XCTAssertEqual(params.apiId, MSALTelemetryApiIdAcquireSilentWithUserAndAuthority);
         XCTAssertEqualObjects(params.account.username, @"user@contoso.com");
         XCTAssertEqualObjects(params.account.name, @"name");
         XCTAssertEqualObjects(params.account.homeAccountId.identifier, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.account.homeAccountId.tenantId, @"1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.account.homeAccountId.objectId, @"1");
         XCTAssertEqualObjects(params.account.environment, @"login.microsoftonline.com");
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });

         XCTAssertEqualObjects(params.unvalidatedAuthority.url.absoluteString, @"https://login.microsoftonline.com/custom_guest_tenant");

         XCTAssertFalse(obj.forceRefresh);

         XCTAssertEqualObjects(params.scopes, ([NSOrderedSet orderedSetWithObjects:@"fakescope1", @"fakescope2", nil]));
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);

         XCTAssertNotNil(params.correlationId);

         completionBlock(nil, nil);
     }];

    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"custom_guest_tenant"
                                                      clientInfo:nil];

    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
                                   authority:nil
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNil(error);
     }];

}

- (void)testAcquireSilentScopesUserAuthorityForceRefreshCorrelationId
{
    NSError *error = nil;

    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    __auto_type authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoftonline.com/common"];
    __auto_type authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                authority:authority
                                                    error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    __block NSUUID *correlationId = [NSUUID new];
    
    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALSilentRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALSilentRequest class]]);
         
         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);
         
         XCTAssertEqual(params.apiId, MSALTelemetryApiIdAcquireSilentWithUserAuthorityForceRefreshAndCorrelationId);
         XCTAssertEqualObjects(params.account.username, @"user@contoso.com");
         XCTAssertEqualObjects(params.account.name, @"name");
         XCTAssertEqualObjects(params.account.homeAccountId.identifier, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.account.homeAccountId.tenantId, @"1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.account.homeAccountId.objectId, @"1");
         XCTAssertEqualObjects(params.account.environment, @"login.microsoftonline.com");
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         
         XCTAssertEqualObjects(params.unvalidatedAuthority.url.absoluteString, @"https://login.microsoft.com/1234-5678-90abcdefg");
         
         XCTAssertTrue(obj.forceRefresh);
         
         XCTAssertEqualObjects(params.correlationId, correlationId);
         XCTAssertEqualObjects(params.scopes, ([NSOrderedSet orderedSetWithObjects:@"fakescope1", @"fakescope2", nil]));
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:nil];
    
    authorityUrl = [[NSURL alloc] initWithString:@"https://login.microsoft.com/common"];
    authority = [[MSALAADAuthority alloc] initWithURL:authorityUrl context:nil error:nil];
    
    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
                                   authority:authority
                                forceRefresh:YES
                               correlationId:correlationId
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNil(error);
     }];
    
}

#pragma
#pragma mark - remove user

#if TARGET_OS_IPHONE

- (void)testRemoveUser_whenUserExists_shouldRemoveUser
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    NSError *error = nil;

    NSString *clientId = UNIT_TEST_CLIENT_ID;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:clientId
                                                    error:nil];
    application.tokenCache = self.tokenCacheAccessor;

    // Make sure no users are showing up in the cache
    XCTAssertEqual([application accounts:nil].count, 0);

    [self msalStoreTokenResponseInCache];

    // Make sure that the user is properly showing up in the cache
    XCTAssertEqual([application accounts:nil].count, 1);

    MSIDAccount *account = [[MSIDAADV2Oauth2Factory new] accountFromResponse:[self msalDefaultTokenResponse] configuration:[self msalDefaultConfiguration]];
    MSALAccount *msalAccount = [[MSALAccount alloc] initWithMSIDAccount:account];

    XCTAssertEqualObjects([application accounts:nil][0], msalAccount);

    XCTAssertTrue([application removeAccount:msalAccount error:&error]);
    XCTAssertNil(error);
    
    // Make sure the user is now gone
    XCTAssertEqual([application accounts:nil].count, 0);
}

- (void)testAllAccounts_whenNoAccountsExist_shouldReturnEmptyArrayNoError
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    NSString *clientId = UNIT_TEST_CLIENT_ID;
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:clientId
                                                    error:&error];
    XCTAssertNil(error);
    application.tokenCache = self.tokenCacheAccessor;

    // Make sure no users are showing up in the cache
    NSArray *accounts = [application accounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 0);
}

- (void)testAllAccounts_whenAccountExists_shouldReturnAccountNoError
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    [self msalStoreTokenResponseInCache];

    NSString *clientId = UNIT_TEST_CLIENT_ID;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:clientId
                                                    error:nil];
    application.tokenCache = self.tokenCacheAccessor;

    NSError *error = nil;
    NSArray *accounts = [application accounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);

    MSALAccount *account = accounts[0];
    XCTAssertEqualObjects(account.username, @"fakeuser@contoso.com");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.homeAccountId.identifier, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97.0287f963-2d72-4363-9e3a-5705c5b0f031");
    XCTAssertEqualObjects(account.homeAccountId.objectId, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(account.homeAccountId.tenantId, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
}

- (void)testAccountWithHomeAccountId_whenAccountExists_shouldReturnAccountNoError
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    [self msalStoreTokenResponseInCache];

    NSString *clientId = UNIT_TEST_CLIENT_ID;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:clientId
                                                    error:nil];
    application.tokenCache = self.tokenCacheAccessor;

    NSError *error = nil;
    NSString *homeAccountId = @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97.0287f963-2d72-4363-9e3a-5705c5b0f031";
    MSALAccount *account = [application accountForHomeAccountId:homeAccountId error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(account);

    XCTAssertEqualObjects(account.username, @"fakeuser@contoso.com");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.homeAccountId.identifier, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97.0287f963-2d72-4363-9e3a-5705c5b0f031");
    XCTAssertEqualObjects(account.homeAccountId.objectId, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(account.homeAccountId.tenantId, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
}

- (void)testAccountWithHomeAccountId_whenAccountExistsButNotMatching_shouldReturnNoAccountNoError
{
    [self msalStoreTokenResponseInCache];

    NSString *clientId = UNIT_TEST_CLIENT_ID;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:clientId
                                                    error:nil];
    application.tokenCache = self.tokenCacheAccessor;

    NSError *error = nil;
    NSString *homeAccountId = @"other_uid.other_utid";
    MSALAccount *account = [application accountForHomeAccountId:homeAccountId error:&error];
    XCTAssertNil(error);
    XCTAssertNil(account);
}

- (void)testAccountWithUsername_whenAccountExists_shouldReturnAccountNoError
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    [self msalStoreTokenResponseInCache];

    NSString *clientId = UNIT_TEST_CLIENT_ID;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:clientId
                                                    error:nil];
    application.tokenCache = self.tokenCacheAccessor;

    NSError *error = nil;
    MSALAccount *account = [application accountForUsername:@"fakeuser@contoso.com" error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(account);

    XCTAssertEqualObjects(account.username, @"fakeuser@contoso.com");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.homeAccountId.identifier, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97.0287f963-2d72-4363-9e3a-5705c5b0f031");
    XCTAssertEqualObjects(account.homeAccountId.objectId, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(account.homeAccountId.tenantId, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
}

- (void)testAccountWithUsername_whenAccountExistsButNotMatching_shouldReturnNoAccountNoError
{
    [self msalStoreTokenResponseInCache];

    NSString *clientId = UNIT_TEST_CLIENT_ID;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:clientId
                                                    error:nil];
    application.tokenCache = self.tokenCacheAccessor;

    NSError *error = nil;
    MSALAccount *account = [application accountForUsername:@"nonexisting@contoso.com" error:&error];
    XCTAssertNil(error);
    XCTAssertNil(account);
}

#endif

- (void)testRemove_whenUserDontExist_shouldReturnTrueWithNoError
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    NSError *error = nil;

    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                    error:nil];

    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"
                                                      clientInfo:nil];
    XCTAssertTrue([application removeAccount:account error:&error]);
    XCTAssertNil(error);
}

- (void)testRemoveUser_whenKeychainError_shouldReturnNoWithError
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSError *error = nil;
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                    error:nil];

    MSALAccount *account = [MSALAccount new];

    [MSALTestSwizzle instanceMethod:@selector(clearCacheForAccount:environment:clientId:context:error:)
                              class:[MSIDDefaultTokenCacheAccessor class]
                              block:(id)^(id obj, id account, NSString *environment, NSString *clientId, id<MSIDRequestContext> ctx, NSError **error)
     {
         (void)environment;
         (void)account;
         (void)clientId;

         *error = MSIDCreateError(NSOSStatusErrorDomain, -34018, nil, nil, nil, nil, nil, nil);

         return NO;
     }];
    
    XCTAssertFalse([application removeAccount:account error:&error]);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, NSOSStatusErrorDomain);
}

#pragma mark - Helpers

- (void)msalStoreTokenResponseInCache
{
    //store at & rt in cache
    MSIDAADV2TokenResponse *msidResponse = [self msalDefaultTokenResponse];
    MSIDConfiguration *configuration = [self msalDefaultConfiguration];

    NSError *error = nil;
    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:configuration
                                                              response:msidResponse
                                                               context:nil
                                                                 error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (MSIDAADV2TokenResponse *)msalDefaultTokenResponse
{
    NSDictionary* idTokenClaims = @{ @"home_oid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"preferred_username": @"fakeuser@contoso.com"};
    NSDictionary* clientInfoClaims = @{ @"uid" : @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97", @"utid" : @"0287f963-2d72-4363-9e3a-5705c5b0f031"};

    NSString *rawIdToken = [NSString stringWithFormat:@"fakeheader.%@.fakesignature",
                            [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:idTokenClaims options:0 error:nil]]];
    NSString *rawClientInfo = [NSString msidBase64UrlEncodedStringFromData:[NSJSONSerialization dataWithJSONObject:clientInfoClaims options:0 error:nil]];

    MSIDAADV2TokenResponse *msidResponse =
    [[MSIDAADV2TokenResponse alloc] initWithJSONDictionary:@{
                                                             @"access_token": @"access_token",
                                                             @"refresh_token": @"fakeRefreshToken",
                                                             @"authority" : @"https://login.microsoftonline.com/common",
                                                             @"scope": @"fakescope1 fakescope2",
                                                             @"client_id": UNIT_TEST_CLIENT_ID,
                                                             @"id_token": rawIdToken,
                                                             @"client_info": rawClientInfo,
                                                             @"expires_on" : @"1"
                                                             }
                                                     error:nil];

    return msidResponse;
}

- (MSIDConfiguration *)msalDefaultConfiguration
{
    MSIDAuthorityFactory *factory = [MSIDAuthorityFactory new];
    MSIDAuthority *authority = [factory authorityFromUrl:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    return [[MSIDConfiguration alloc] initWithAuthority:authority
                                            redirectUri:UNIT_TEST_DEFAULT_REDIRECT_URI
                                               clientId:UNIT_TEST_CLIENT_ID
                                                 target:@"fakescope1 fakescope2"];
}

@end
