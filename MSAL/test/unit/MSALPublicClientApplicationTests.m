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
#import "MSIDTestSwizzle.h"
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
#import "MSIDAccountIdentifier.h"
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
#import "MSIDTestURLResponse.h"
#import "MSIDTestURLSession.h"
#import "MSIDDeviceId.h"
#import "MSIDAuthorityFactory.h"
#import "MSIDAADNetworkConfiguration.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDLocalInteractiveController.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSALTelemetryApiId.h"
#import "MSIDSilentController.h"
#import "MSALRedirectUri.h"

@interface MSALFakeInteractiveRequest : NSObject

@property NSString *state;
@property MSIDRequestParameters *parameters;

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
    
    self.tokenCacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    [self.tokenCacheAccessor clearWithContext:nil error:nil];
    
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Init

- (void)testInitWithClientId_whenClientIdIsNil_shouldReturnError
{
    NSError *error = nil;

    NSString *clientId = nil;
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId
                                                                              error:&error];
    
    XCTAssertNil(application);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertNotNil(error.userInfo);
    XCTAssertNotNil(error.userInfo[MSALErrorDescriptionKey]);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"clientId"]);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
}

- (void)testInitWithClientId_whenClientIdIsNotNil_shouldInit
{
    NSError *error = nil;
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                              error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.redirectUri.url.absoluteString, UNIT_TEST_DEFAULT_REDIRECT_URI);
#if TARGET_OS_IPHONE
    XCTAssertEqualObjects(application.keychainGroup, @"com.microsoft.adalcache");
#endif
    
    XCTAssertEqualObjects(MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion, @"v2.0");
}

- (void)testInitWithClientIdAndAuthority_whenValidClientIdAndAuthority_shouldReturnApplicationAndNilError
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    NSError *error = nil;
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                          authority:authority
                                                                              error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.authority, authority);
    XCTAssertEqualObjects(application.redirectUri.url.absoluteString, UNIT_TEST_DEFAULT_REDIRECT_URI);
#if TARGET_OS_IPHONE
    XCTAssertEqualObjects(application.keychainGroup, @"com.microsoft.adalcache");
#endif
}

- (void)testInitWithClientIdAndAuthorityAndRedirectUri_whenValidClientIdAndAuthorityAndRedirectUri_shouldReturnApplicationAndNilError
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"mycustom.redirect"] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    NSError *error = nil;
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                          authority:authority
                                                                        redirectUri:@"mycustom.redirect://bundle_id"
                                                                              error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.authority, authority);
    XCTAssertEqualObjects(application.redirectUri.url.absoluteString, @"mycustom.redirect://bundle_id");
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
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                              error:&error];
    
    XCTAssertNil(application);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorRedirectSchemeNotRegistered);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
}

- (void)testInitWithClientIdAndAuthorityAndRedirectUri_whenInvalidSchemeRegistered_shouldReturnNilApplicationAndFillError
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"mycustom.redirect"] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    NSError *error = nil;
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                          authority:authority
                                                                        redirectUri:@"mycustom.wrong.redirect://bundle_id"
                                                                              error:&error];
    
    XCTAssertNil(application);
    XCTAssertNotNil(error);
}

- (void)testInitWithClientIdAndKeychainGroup_whenAllValidParameters_shouldReturnApplicationAndNilError
{
    NSError *error = nil;
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                      keychainGroup:@"com.contoso.msalcache"
                                                                              error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.redirectUri.url.absoluteString, UNIT_TEST_DEFAULT_REDIRECT_URI);
    XCTAssertEqualObjects(application.keychainGroup, @"com.contoso.msalcache");
}

- (void)testInitWithClientIdAndAuthorityAndKeychainGroup_whenAllValidParameters_shouldReturnApplicationAndNilError
{
    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    NSError *error = nil;
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                      keychainGroup:@"com.contoso.msalcache"
                                                                          authority:authority
                                                                              error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.authority, authority);
    XCTAssertEqualObjects(application.redirectUri.url.absoluteString, UNIT_TEST_DEFAULT_REDIRECT_URI);
    XCTAssertEqualObjects(application.keychainGroup, @"com.contoso.msalcache");
}

- (void)testInitWithClientIdAndAuthorityAndRedirectUriAndKeychainGroup_whenAllValidParameters_shouldReturnApplicationAndNilError
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"mycustom.redirect"] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    NSError *error = nil;
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                      keychainGroup:@"com.contoso.msalcache"
                                                                          authority:authority
                                                                        redirectUri:@"mycustom.redirect://bundle_id"
                                                                              error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.authority, authority);
    XCTAssertEqualObjects(application.redirectUri.url.absoluteString, @"mycustom.redirect://bundle_id");
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

#pragma mark - acquireToken

- (void)testAcquireTokenScopes
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                          authority:authority
                                                                              error:&error];
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    __block dispatch_semaphore_t dsem = dispatch_semaphore_create(0);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         MSIDInteractiveRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);

         NSString *expectedTelemetryAPIId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquire];
         XCTAssertEqualObjects(params.telemetryApiId, expectedTelemetryAPIId);
         XCTAssertEqualObjects(params.authority, [@"https://login.microsoftonline.com/common" msalAuthority].msidAuthority);
         XCTAssertEqualObjects(params.target, @"fakescope");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         XCTAssertNil(params.extraQueryParameters);
         XCTAssertNil(params.loginHint);
         XCTAssertEqualObjects(params.logComponent, @"MSAL");
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];

    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    [application acquireTokenForScopes:@[@"fakescope"]
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
         
         dispatch_semaphore_signal(dsem);
     }];
    
    dispatch_semaphore_wait(dsem, DISPATCH_TIME_NOW);
    application = nil;
}

#pragma mark - acquireToken using Login Hint

- (void)testAcquireScopesLoginHint
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                          authority:authority
                                                                              error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);

         MSIDInteractiveRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);

         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireWithHint];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         XCTAssertNotNil(params.correlationId);
         XCTAssertNil(params.extraScopesToConsent);
         XCTAssertEqual(params.promptType, MSIDPromptTypePromptIfNecessary);
         XCTAssertNil(params.extraQueryParameters);
         XCTAssertEqualObjects(params.loginHint, @"fakeuser@contoso.com");
         
         completionBlock(nil, nil);
     }];

    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                             loginHint:@"fakeuser@contoso.com"
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
}


- (void)testAcquireScopesLoginHintBehaviorEQPs
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    NSError *error = nil;
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                          authority:authority
                                                                              error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);

         MSIDInteractiveRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);

         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireWithHintBehaviorAndParameters];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         XCTAssertNotNil(params.correlationId);
         XCTAssertEqualObjects(params.extraQueryParameters, (@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }));
         XCTAssertEqualObjects(params.loginHint, @"fakeuser@contoso.com");
         XCTAssertNil(params.extraScopesToConsent);
         XCTAssertEqual(params.promptType, MSIDPromptTypeLogin);
         
         completionBlock(nil, nil);
     }];

    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                             loginHint:@"fakeuser@contoso.com"
                            uiBehavior:MSALForceLogin
                  extraQueryParameters:@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
}

- (void)testAcquireScopesAddlScopesLoginHintuiBehaviorEQPAuthorityCorrelationId
{
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    NSError *error = nil;
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                          authority:authority
                                                                              error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    __block NSUUID *correlationId = [NSUUID new];
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);

         MSIDInteractiveRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);

         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireWithHintBehaviorParametersAuthorityAndCorrelationId];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/contoso.com");
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         XCTAssertEqualObjects(params.correlationId, correlationId);
         XCTAssertEqualObjects(params.extraQueryParameters, (@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }));
         XCTAssertEqualObjects(params.loginHint, @"fakeuser@contoso.com");
         XCTAssertEqualObjects(params.extraScopesToConsent, @"fakescope3");
         XCTAssertEqual(params.promptType, MSIDPromptTypeConsent);
         
         completionBlock(nil, nil);
     }];
    
    authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
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
         XCTAssertNotNil(error);
     }];
}

#pragma mark - acquireToken using User

- (void)testAcquireScopesWithAccount
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
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
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);

         MSIDInteractiveRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);

         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireWithUserBehaviorAndParameters];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         XCTAssertNotNil(params.correlationId);
         XCTAssertNil(params.extraQueryParameters);
         XCTAssertNil(params.loginHint);
         XCTAssertNil(params.extraScopesToConsent);
         XCTAssertEqual(params.promptType, MSIDPromptTypePromptIfNecessary);

         XCTAssertEqualObjects(params.accountIdentifier, account.lookupAccountIdentifier);
         
         completionBlock(nil, nil);
     }];

    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                               account:account
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
}

- (void)testAcquireScopesUserUiBehaviorEQP
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    NSError *error = nil;
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
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
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);

         MSIDInteractiveRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);

         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireWithUserBehaviorAndParameters];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         XCTAssertNotNil(params.correlationId);
         XCTAssertEqualObjects(params.extraQueryParameters, (@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }));
         XCTAssertNil(params.loginHint);
         XCTAssertNil(params.extraScopesToConsent);
         XCTAssertEqual(params.promptType, MSIDPromptTypePromptIfNecessary);
         XCTAssertEqualObjects(params.accountIdentifier, account.lookupAccountIdentifier);
         
         completionBlock(nil, nil);
     }];

    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                               account:account
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
}

- (void)testAcquireScopesAddlScopesUserUiBehaviorEQPAuthorityCorrelationId
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
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
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);

         MSIDInteractiveRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);

         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireWithUserBehaviorParametersAuthorityAndCorrelationId];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/contoso.com");
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         XCTAssertEqualObjects(params.correlationId, correlationId);
         XCTAssertEqualObjects(params.extraQueryParameters, (@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }));
         XCTAssertNil(params.loginHint);
         XCTAssertEqualObjects(params.accountIdentifier, account.lookupAccountIdentifier);
         XCTAssertEqualObjects(params.extraScopesToConsent, @"fakescope3");
         XCTAssertEqual(params.promptType, MSIDPromptTypePromptIfNecessary);
         
         completionBlock(nil, nil);
     }];
    
    authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    application.brokerAvailability = MSALBrokeredAvailabilityNone;
    
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
         XCTAssertNotNil(error);
     }];
    
}

#pragma
#pragma mark - acquireTokenSilent

- (void)testAcquireSilentScopesUser
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                          authority:authority
                                                                              error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDSilentController class]
                              block:(id)^(MSIDSilentController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDSilentController class]]);
         
         MSIDRequestParameters *params = [obj requestParameters];
         XCTAssertNotNil(params);

         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireSilentWithUser];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.accountIdentifier.legacyAccountId, @"user@contoso.com");
         XCTAssertEqualObjects(params.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         
         XCTAssertEqualObjects(params.authority, [@"https://login.microsoftonline.com/1234-5678-90abcdefg" msalAuthority].msidAuthority);
         
         XCTAssertFalse(obj.forceRefresh);
         
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
}

- (void)testAcquireSilentScopesUserAuthority
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                          authority:authority
                                                                              error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDSilentController class]
                              block:(id)^(MSIDSilentController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDSilentController class]]);

         MSIDRequestParameters *params = [obj requestParameters];
         XCTAssertNotNil(params);

         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireSilentWithUserAndAuthority];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.accountIdentifier.legacyAccountId, @"user@contoso.com");
         XCTAssertEqualObjects(params.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoft.com/1234-5678-90abcdefg");
         
         XCTAssertFalse(obj.forceRefresh);
         
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    authority = [@"https://login.microsoft.com/common" msalAuthority];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
                                   authority:authority
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
    
}

- (void)testAcquireSilentScopesUser_whenNoAuthority_andCommonAuthorityInPublicClientApplication_shouldUseAccountHomeAuthority
{
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                          authority:authority
                                                                              error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDSilentController class]
                              block:(id)^(MSIDSilentController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDSilentController class]]);

         MSIDRequestParameters *params = [obj requestParameters];
         XCTAssertNotNil(params);

         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireSilentWithUser];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.accountIdentifier.legacyAccountId, @"user@contoso.com");
         XCTAssertEqualObjects(params.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/1234-5678-90abcdefg");
         
         XCTAssertFalse(obj.forceRefresh);
         
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"custom_guest_tenant"];
    
    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
    
}

- (void)testAcquireSilentScopesUser_whenNoAuthority_andNonCommonAuthorityInPublicClientApplication_shouldUseThatAuthority
{
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/custom_guest_tenant" msalAuthority];
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                          authority:authority
                                                                              error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDSilentController class]
                              block:(id)^(MSIDSilentController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDSilentController class]]);

         MSIDRequestParameters *params = [obj requestParameters];
         XCTAssertNotNil(params);

         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireSilentWithUser];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.accountIdentifier.legacyAccountId, @"user@contoso.com");
         XCTAssertEqualObjects(params.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/custom_guest_tenant");
         
         XCTAssertFalse(obj.forceRefresh);
         
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"custom_guest_tenant"];
    
    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
    
}

- (void)testAcquireSilentScopesUser_whenNilAuthority_andNonCommonAuthorityInPublicClientApplication_shouldUseThatAuthority
{
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/custom_guest_tenant" msalAuthority];
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                          authority:authority
                                                                              error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDSilentController class]
                              block:(id)^(MSIDSilentController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDSilentController class]]);

         MSIDRequestParameters *params = [obj requestParameters];
         XCTAssertNotNil(params);

         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireSilentWithUserAndAuthority];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.accountIdentifier.legacyAccountId, @"user@contoso.com");
         XCTAssertEqualObjects(params.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/custom_guest_tenant");
         
         XCTAssertFalse(obj.forceRefresh);
         
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"custom_guest_tenant"];
    
    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
                                   authority:nil
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
    
}

- (void)testAcquireSilentScopesUserAuthorityForceRefreshCorrelationId
{
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                          authority:authority
                                                                              error:&error];
    application.component = @"unittests";
    application.sliceParameters = @{ @"slice" : @"myslice" };
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    __block NSUUID *correlationId = [NSUUID new];
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDSilentController class]
                              block:(id)^(MSIDSilentController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDSilentController class]]);

         MSIDRequestParameters *params = [obj requestParameters];
         XCTAssertNotNil(params);

         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireSilentWithUserAuthorityForceRefreshAndCorrelationId];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.accountIdentifier.legacyAccountId, @"user@contoso.com");
         XCTAssertEqualObjects(params.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.sliceParameters, @{ @"slice" : @"myslice" });
         
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoft.com/1234-5678-90abcdefg");
         
         XCTAssertTrue(obj.forceRefresh);
         
         XCTAssertEqualObjects(params.correlationId, correlationId);
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    authority = [@"https://login.microsoft.com/common" msalAuthority];
    
    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
                                   authority:authority
                                forceRefresh:YES
                               correlationId:correlationId
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
    
}

#if TARGET_OS_IPHONE

#pragma mark - allAccounts

- (void)testAllAccounts_whenNoAccountsExist_shouldReturnEmptyArrayNoError
{
    NSString *clientId = UNIT_TEST_CLIENT_ID;
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId error:&error];
    XCTAssertNil(error);
    application.tokenCache = self.tokenCacheAccessor;
    
    // Make sure no users are showing up in the cache
    NSArray *accounts = [application allAccounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 0);
}

- (void)testAllAccounts_whenAccountExists_shouldReturnAccountNoError
{
    [self msalStoreTokenResponseInCache];
    
    NSString *clientId = UNIT_TEST_CLIENT_ID;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId error:nil];
    application.tokenCache = self.tokenCacheAccessor;
    
    NSError *error = nil;
    NSArray *accounts = [application allAccounts:&error];
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

- (void)testAllAccounts_when2AccountExists_shouldReturn2Accounts
{
    [self msalStoreTokenResponseInCacheWithAuthority:@"https://login.microsoftonline.com/common"];
    [self msalStoreTokenResponseInCacheWithAuthority:@"https://example.com/common"];
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID error:nil];
    application.tokenCache = self.tokenCacheAccessor;
    
    NSError *error = nil;
    NSArray *accounts = [application allAccounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 2);
    
    MSALAccount *account = accounts[0];
    XCTAssertEqualObjects(account.username, @"fakeuser@contoso.com");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.homeAccountId.identifier, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97.0287f963-2d72-4363-9e3a-5705c5b0f031");
    XCTAssertEqualObjects(account.homeAccountId.objectId, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(account.homeAccountId.tenantId, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
    
    MSALAccount *account2 = accounts[1];
    XCTAssertEqualObjects(account2.username, @"fakeuser@contoso.com");
    XCTAssertEqualObjects(account2.environment, @"example.com");
    XCTAssertEqualObjects(account2.homeAccountId.identifier, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97.0287f963-2d72-4363-9e3a-5705c5b0f031");
    XCTAssertEqualObjects(account2.homeAccountId.objectId, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
    XCTAssertEqualObjects(account2.homeAccountId.tenantId, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
}

#pragma mark - allAccountsFilteredByAuthority

- (void)testAllAccountsFilteredByAuthority_when2AccountExists_shouldReturnAccountsFilteredByAuthority
{
    [self msalStoreTokenResponseInCacheWithAuthority:@"https://login.microsoftonline.com/common"];
    [self msalStoreTokenResponseInCacheWithAuthority:@"https://example.com/common"];
    [self msalAddDiscoveryResponse];
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID error:nil];
    application.tokenCache = self.tokenCacheAccessor;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Process Metadata."];
    [application allAccountsFilteredByAuthority:^(NSArray<MSALAccount *> *accounts, NSError *error)
    {
        XCTAssertNil(error);
        XCTAssertNotNil(accounts);
        XCTAssertEqual([accounts count], 1);
        
        MSALAccount *account = accounts[0];
        XCTAssertEqualObjects(account.username, @"fakeuser@contoso.com");
        XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
        XCTAssertEqualObjects(account.homeAccountId.identifier, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97.0287f963-2d72-4363-9e3a-5705c5b0f031");
        XCTAssertEqualObjects(account.homeAccountId.objectId, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
        XCTAssertEqualObjects(account.homeAccountId.tenantId, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
        
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllAccountsFilteredByAuthority_whenAccountWithAliasAuthorityExists_shouldReturnThatAccount
{
    [self msalStoreTokenResponseInCacheWithAuthority:@"https://login.windows.net/common"];
    [self msalStoreTokenResponseInCacheWithAuthority:@"https://example.com/common"];
    [self msalAddDiscoveryResponse];
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID error:nil];
    application.tokenCache = self.tokenCacheAccessor;
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Process Metadata."];
    [application allAccountsFilteredByAuthority:^(NSArray<MSALAccount *> *accounts, NSError *error)
     {
         XCTAssertNil(error);
         XCTAssertNotNil(accounts);
         XCTAssertEqual([accounts count], 1);
         
         MSALAccount *account = accounts[0];
         XCTAssertEqualObjects(account.username, @"fakeuser@contoso.com");
         XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
         XCTAssertEqualObjects(account.homeAccountId.identifier, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97.0287f963-2d72-4363-9e3a-5705c5b0f031");
         XCTAssertEqualObjects(account.homeAccountId.objectId, @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97");
         XCTAssertEqualObjects(account.homeAccountId.tenantId, @"0287f963-2d72-4363-9e3a-5705c5b0f031");
         
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - loadAccountForHomeAccountId

- (void)testAccountWithHomeAccountId_whenAccountExists_shouldReturnAccountNoError
{
    [self msalStoreTokenResponseInCache];
    
    NSString *clientId = UNIT_TEST_CLIENT_ID;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId error:nil];
    application.tokenCache = self.tokenCacheAccessor;
    NSString *homeAccountId = @"29f3807a-4fb0-42f2-a44a-236aa0cb3f97.0287f963-2d72-4363-9e3a-5705c5b0f031";
    
    NSError *error;
    __auto_type account = [application accountForHomeAccountId:homeAccountId error:&error];
    
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
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId error:nil];
    application.tokenCache = self.tokenCacheAccessor;
    NSString *homeAccountId = @"other_uid.other_utid";
    
    NSError *error;
    __auto_type account = [application accountForHomeAccountId:homeAccountId error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(account);
}

#pragma mark - loadAccountForUsername

- (void)testAccountWithUsername_whenAccountExists_shouldReturnAccountNoError
{
    [self msalStoreTokenResponseInCache];
    
    NSString *clientId = UNIT_TEST_CLIENT_ID;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId error:nil];
    application.tokenCache = self.tokenCacheAccessor;
    
    NSError *error;
    __auto_type account = [application accountForUsername:@"fakeuser@contoso.com" error:&error];
    
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
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId error:nil];
    application.tokenCache = self.tokenCacheAccessor;
    
    NSError *error;
    __auto_type account = [application accountForUsername:@"nonexisting@contoso.com" error:&error];
    
    XCTAssertNil(error);
    XCTAssertNil(account);
}

#pragma mark - removeAccount

- (void)testRemoveAccount_whenAccountExists_shouldRemoveAccount
{
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID error:nil];
    application.tokenCache = self.tokenCacheAccessor;
    
    // Make sure no users are showing up in the cache
    XCTAssertEqual([application allAccounts:nil].count, 0);
    
    [self msalStoreTokenResponseInCache];
    
    // Make sure that the user is properly showing up in the cache
    XCTAssertEqual([application allAccounts:nil].count, 1);
    
    MSIDAccount *account = [[MSIDAADV2Oauth2Factory new] accountFromResponse:[self msalDefaultTokenResponse]
                                                               configuration:[self msalDefaultConfiguration]];
    MSALAccount *msalAccount = [[MSALAccount alloc] initWithMSIDAccount:account];
    
    XCTAssertEqualObjects([application allAccounts:nil][0], msalAccount);
    
    NSError *error;
    BOOL result = [application removeAccount:msalAccount error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    // Make sure the user is now gone
    XCTAssertEqual([application allAccounts:nil].count, 0);
}

#endif

- (void)testRemove_whenUserDontExist_shouldReturnTrueWithNoError
{
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID error:nil];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                            name:@"name"
                                                   homeAccountId:@"1.1234-5678-90abcdefg"
                                                  localAccountId:@"1"
                                                     environment:@"login.microsoftonline.com"
                                                        tenantId:@"1234-5678-90abcdefg"];
    
    NSError *error;
    BOOL result = [application removeAccount:account error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testRemoveUser_whenKeychainError_shouldReturnNoWithError
{
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID error:nil];
    
    MSALAccount *account = [MSALAccount new];
    
    [MSIDTestSwizzle instanceMethod:@selector(clearCacheForAccount:authority:clientId:context:error:)
                              class:[MSIDDefaultTokenCacheAccessor class]
                              block:(id)^(id obj, id account, MSIDAuthority *authority, NSString *clientId, id<MSIDRequestContext> ctx, NSError **error)
     {
         (void)authority;
         (void)account;
         (void)clientId;
         
         *error = MSIDCreateError(NSOSStatusErrorDomain, -34018, nil, nil, nil, nil, nil, nil);
         
         return NO;
     }];
    
    NSError *error;
    BOOL result = [application removeAccount:account error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, NSOSStatusErrorDomain);
}

#pragma mark - Helpers

- (void)msalStoreTokenResponseInCache
{
    [self msalStoreTokenResponseInCacheWithAuthority:@"https://login.microsoftonline.com/common"];
}

- (void)msalStoreTokenResponseInCacheWithAuthority:(NSString *)authorityString
{
    //store at & rt in cache
    MSIDAADV2TokenResponse *msidResponse = [self msalDefaultTokenResponseWithAuthority:authorityString];
    MSIDConfiguration *configuration = [self msalDefaultConfigurationWithAuthority:authorityString];
    
    NSError *error = nil;
    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:configuration
                                                              response:msidResponse
                                                               factory:[MSIDAADV2Oauth2Factory new]
                                                               context:nil
                                                                 error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)msalAddDiscoveryResponse
{
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    __auto_type requestUrl = [@"https://login.microsoftonline.com/common/discovery/instance?api-version=1.1&authorization_endpoint=https%3A%2F%2Flogin.microsoftonline.com%2Fcommon%2Foauth2%2Fv2.0%2Fauthorize" msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    headers[@"Accept"] = @"application/json";
    response->_requestHeaders = headers;
    __auto_type responseJson = @{
                                 @"tenant_discovery_endpoint" : @"https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration",
                                 @"metadata" : @[
                                         @{
                                             @"preferred_network" : @"login.microsoftonline.com",
                                             @"preferred_cache" : @"login.windows.net",
                                             @"aliases" : @[@"login.microsoftonline.com", @"login.windows.net"]
                                             }
                                         ]
                                 };
    [response setResponseJSON:responseJson];
    [MSIDTestURLSession addResponse:response];
}

- (MSIDAADV2TokenResponse *)msalDefaultTokenResponse
{
    return [self msalDefaultTokenResponseWithAuthority:@"https://login.microsoftonline.com/common"];
}

- (MSIDAADV2TokenResponse *)msalDefaultTokenResponseWithAuthority:(NSString *)authorityString
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
                                                             @"authority" : authorityString,
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
    MSIDAuthority *authority = [MSIDAuthorityFactory authorityFromUrl:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];
    
    return [[MSIDConfiguration alloc] initWithAuthority:authority
                                            redirectUri:UNIT_TEST_DEFAULT_REDIRECT_URI
                                               clientId:UNIT_TEST_CLIENT_ID
                                                 target:@"fakescope1 fakescope2"];
}

- (MSIDConfiguration *)msalDefaultConfigurationWithAuthority:(NSString *)authorityString
{
    MSIDAuthority *authority = [MSIDAuthorityFactory authorityFromUrl:[NSURL URLWithString:authorityString] context:nil error:nil];
    
    return [[MSIDConfiguration alloc] initWithAuthority:authority
                                            redirectUri:UNIT_TEST_DEFAULT_REDIRECT_URI
                                               clientId:UNIT_TEST_CLIENT_ID
                                                 target:@"fakescope1 fakescope2"];
}

@end
