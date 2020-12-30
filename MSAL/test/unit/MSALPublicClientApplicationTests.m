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
#import "XCTestCase+HelperMethods.h"
#import "MSALPublicClientApplication+Internal.h"
#import "MSIDTestSwizzle.h"
#import "MSIDTestBundle.h"
#import "MSALTestConstants.h"
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
#import "MSIDTestURLResponse.h"
#import "MSIDTestURLSession.h"
#import "MSIDDeviceId.h"
#import "NSString+MSIDTestUtil.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSIDLocalInteractiveController.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSALTelemetryApiId.h"
#import "MSIDSilentController.h"
#import "MSIDRedirectUri.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDTestURLResponse+Util.h"
#import "MSALTenantProfile.h"
#import "MSALSliceConfig.h"
#import "MSALCacheConfig.h"
#import "MSALB2CAuthority.h"
#import "MSALAccountId+Internal.h"
#import "MSALCacheConfig.h"
#import "MSALAccount+MultiTenantAccount.h"
#import "MSALAccountEnumerationParameters.h"
#import "MSALAccount+Internal.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDTestCacheDataSource.h"
#import "MSALOauth2ProviderFactory.h"
#import "MSALInteractiveTokenParameters.h"
#import "MSALWebviewParameters.h"
#import "MSALSilentTokenParameters.h"
#import "MSALSignoutParameters.h"
#import "MSIDSignoutController.h"
#import "MSIDSSOExtensionGetAccountsRequest.h"
#import "MSALPublicClientApplication+SingleAccount.h"
#import "MSALDeviceInfoProvider.h"
#import "MSALDeviceInformation+Internal.h"
#import "MSIDDeviceInfo.h"
#import "MSALTestCacheTokenResponse.h"
#import "MSALAuthenticationSchemePop.h"
#if TARGET_OS_IPHONE
#import "MSIDApplicationTestUtil.h"
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface MSALFakeInteractiveRequest : NSObject

@property NSString *state;
@property MSIDRequestParameters *parameters;

@end

@implementation MSALFakeInteractiveRequest

@end

@interface MSALPublicClientApplicationTests : MSALTestCase

@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCacheAccessor;
@property (nonatomic) MSIDAccountMetadataCacheAccessor *accountMetadataCache;

@end

@implementation MSALPublicClientApplicationTests

- (void)setUp
{
    [super setUp];
    
#if TARGET_OS_IPHONE
    id<MSIDExtendedTokenCacheDataSource> dataSource = MSIDKeychainTokenCache.defaultKeychainCache;
    self.tokenCacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil];
    self.accountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
#else
    self.tokenCacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:[MSIDTestCacheDataSource new] otherCacheAccessors:nil];
    self.accountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:[MSIDTestCacheDataSource new]];
#endif
    
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    [self.tokenCacheAccessor clearWithContext:nil error:nil];
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
    XCTAssertEqual(error.code, MSALErrorInternal);
    NSInteger internalErrorCode = [error.userInfo[MSALInternalErrorCodeKey] integerValue];
    XCTAssertEqual(internalErrorCode, MSALInternalErrorInvalidParameter);
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
    XCTAssertEqualObjects(application.configuration.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.configuration.redirectUri, nil);
#if TARGET_OS_IPHONE
    XCTAssertEqualObjects(application.configuration.cacheConfig.keychainSharingGroup, @"com.microsoft.adalcache");
#endif
    
    XCTAssertEqualObjects(MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion, @"v2.0");
}

- (void)testInitWithClientIdAndAuthority_whenValidClientIdAndAuthority_shouldReturnApplicationAndNilError
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    NSError *error = nil;
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                          authority:authority
                                                                              error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.configuration.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.configuration.authority, authority);
    XCTAssertEqualObjects(application.configuration.redirectUri, nil);
    
#if TARGET_OS_IPHONE
    XCTAssertEqualObjects(application.configuration.cacheConfig.keychainSharingGroup, @"com.microsoft.adalcache");
#endif
}

- (void)test_non_nil_sdkVersion
{
    NSString *versionFromInfo = [[NSBundle bundleForClass:MSALPublicClientApplication.class] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *version = [MSALPublicClientApplication sdkVersion];
    XCTAssertNotNil(version);
    XCTAssertEqualObjects(version, versionFromInfo);
}

- (void)testInitWithClientIdAndAuthorityAndRedirectUri_whenValidClientIdAndAuthorityAndRedirectUri_shouldReturnApplicationAndNilError
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"mycustom.redirect"] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    NSError *error = nil;
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                          authority:authority
                                                                        redirectUri:@"mycustom.redirect://bundle_id"
                                                                              error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.configuration.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.configuration.authority, authority);
    XCTAssertEqualObjects(application.configuration.redirectUri, @"mycustom.redirect://bundle_id");
#if TARGET_OS_IPHONE
    XCTAssertEqualObjects(application.configuration.cacheConfig.keychainSharingGroup, @"com.microsoft.adalcache");
#endif
}

#if TARGET_OS_IPHONE

- (void)testInitWithClientId_whenSchemeNotRegistered_shouldReturnNilApplicationAndFillError
{
    // By default the initializer for MSALPublicClientApplication should fail due to the redirect URI
    // not being listed in the info plist
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    NSError *error = nil;
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                              error:&error];
    
    XCTAssertNil(application);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInternal);
    NSInteger internalErrorCode = [error.userInfo[MSALInternalErrorCodeKey] integerValue];
    XCTAssertEqual(internalErrorCode, MSALInternalErrorRedirectSchemeNotRegistered);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
}

- (void)testInitWithClientId_whenBrokerQuerySchemeIsNotRegistered_shouldReturnNilApplicationAndFillError
{
    NSArray *schemes = @[@"msauthv2", @"msauthv-wrong"];
    [MSIDTestBundle overrideObject:schemes forKey:@"LSApplicationQueriesSchemes"];
    
    NSArray *urlTypes = @[@{@"CFBundleURLSchemes": @[@"msauth.test.bundle.identifier"]}];
    [MSIDTestBundle overrideObject:urlTypes forKey:@"CFBundleURLTypes"];
    [MSIDTestBundle overrideBundleId:@"test.bundle.identifier"];
    
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityAuto;
    
    NSError *error;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                              error:&error];
    
    XCTAssertNil(application);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInternal);
    NSInteger internalErrorCode = [error.userInfo[MSALInternalErrorCodeKey] integerValue];
    XCTAssertEqual(internalErrorCode, MSALInternalErrorRedirectSchemeNotRegistered);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
}

- (void)testInitWithClientIdAndAuthorityAndRedirectUri_whenInvalidSchemeRegistered_shouldReturnNilApplicationAndFillError
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"mycustom.redirect"] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
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
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID];
    config.cacheConfig.keychainSharingGroup = @"com.contoso.msalcache";
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.configuration.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.configuration.redirectUri, nil);
    XCTAssertEqualObjects(application.configuration.cacheConfig.keychainSharingGroup, @"com.contoso.msalcache");
}

- (void)testInitWithClientIdAndAuthorityAndKeychainGroup_whenAllValidParameters_shouldReturnApplicationAndNilError
{
    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    NSError *error = nil;
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:authority];
    config.cacheConfig.keychainSharingGroup = @"com.contoso.msalcache";
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.configuration.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.configuration.authority, authority);
    XCTAssertEqualObjects(application.configuration.redirectUri, nil);
    XCTAssertEqualObjects(application.configuration.cacheConfig.keychainSharingGroup, @"com.contoso.msalcache");
}

- (void)testInitWithClientIdAndAuthorityAndRedirectUriAndKeychainGroup_whenAllValidParameters_shouldReturnApplicationAndNilError
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"mycustom.redirect"] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    NSError *error = nil;
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:@"mycustom.redirect://bundle_id" authority:authority];
    config.cacheConfig.keychainSharingGroup = @"com.contoso.msalcache";
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.configuration.clientId, UNIT_TEST_CLIENT_ID);
    XCTAssertEqualObjects(application.configuration.authority, authority);
    XCTAssertEqualObjects(application.configuration.redirectUri, @"mycustom.redirect://bundle_id");
    XCTAssertEqualObjects(application.configuration.cacheConfig.keychainSharingGroup, @"com.contoso.msalcache");
}

- (void)testInitWithClientId_whenKeychainGroupNotSpecified_shouldHaveDefaultKeychainGroup
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    MSALPublicClientApplication *app = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID error:nil];
    XCTAssertEqualObjects(app.configuration.cacheConfig.keychainSharingGroup, MSIDKeychainTokenCache.defaultKeychainGroup);
}

- (void)testInitWithClientIdAndAuthority_whenKeychainGroupNotSpecified_shouldHaveDefaultKeychainGroup
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[UNIT_TEST_DEFAULT_REDIRECT_SCHEME] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    MSALPublicClientApplication *app = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID authority:authority error:nil];
    XCTAssertEqualObjects(app.configuration.cacheConfig.keychainSharingGroup, MSIDKeychainTokenCache.defaultKeychainGroup);
}

- (void)testInitWithClientIdAndAuthorityAndRedirectUri_whenKeychainGroupNotSpecified_shouldHaveDefaultKeychainGroup
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"mycustom.redirect"] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    MSALPublicClientApplication *app = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID authority:authority redirectUri:@"mycustom.redirect://bundle_id" error:nil];
    XCTAssertEqualObjects(app.configuration.cacheConfig.keychainSharingGroup, MSIDKeychainTokenCache.defaultKeychainGroup);
}

- (void)testInitWithClientIdAndAuthorityAndRedirectUriAndKeychainGroup_whenKeychainGroupSpecifiedNil_shouldHaveKeychainGroupDefault
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"mycustom.redirect"] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:@"mycustom.redirect://bundle_id" authority:authority];
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:nil];
    
    XCTAssertEqualObjects(application.configuration.cacheConfig.keychainSharingGroup, @"com.microsoft.adalcache");
}

- (void)testInitWithClientIdAndAuthorityAndRedirectUriAndKeychainGroup_whenKeychainGroupCustomSpecified_shouldHaveCustomKeychainGroup
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"mycustom.redirect"] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    MSALAuthority *authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:@"mycustom.redirect://bundle_id" authority:authority];
    config.cacheConfig.keychainSharingGroup = @"com.contoso.msalcache";
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:nil];
    
    XCTAssertEqualObjects(application.configuration.cacheConfig.keychainSharingGroup, @"com.contoso.msalcache");
}
#endif

#pragma mark - acquireToken

- (void)testAcquireTokenScopes
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:authority];
    config.sliceConfig = [MSALSliceConfig configWithSlice:@"slice" dc:@"dc"];
    
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    __block dispatch_semaphore_t dsem = dispatch_semaphore_create(0);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         MSIDInteractiveTokenRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);
         
         NSString *expectedTelemetryAPIId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquire];
         XCTAssertEqualObjects(params.telemetryApiId, expectedTelemetryAPIId);
         XCTAssertEqualObjects(params.authority, [@"https://login.microsoftonline.com/common" msalAuthority].msidAuthority);
         XCTAssertEqualObjects(params.target, @"fakescope");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.extraURLQueryParameters, (@{ @"slice" : @"slice", @"dc" : @"dc" }));
         XCTAssertTrue(params.extraAuthorizeURLQueryParameters.count == 0);
         XCTAssertNil(params.loginHint);
         XCTAssertEqualObjects(params.logComponent, @"MSAL");
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];

    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;

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

#pragma mark - Known authorities

- (void)testAcquireToken_whenKnownAADAuthority_shouldNotForceValidation
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:authority];
    config.knownAuthorities = @[authority];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         
         MSIDInteractiveTokenRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);
         
         XCTAssertFalse(params.validateAuthority);
         completionBlock(nil, nil);
     }];
    
#if TARGET_OS_IPHONE
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
#endif
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                             loginHint:@"fakeuser@contoso.com"
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
}

- (void)testAcquireToken_whenKnownCustomAADAuthority_shouldNotForceValidation
{
    __auto_type authority = [@"https://login.custom.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:authority];
    config.knownAuthorities = @[authority];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         
         MSIDInteractiveTokenRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);
         
         XCTAssertFalse(params.validateAuthority);
         XCTAssertTrue(params.authority.isDeveloperKnown);
         completionBlock(nil, nil);
     }];
    
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                             loginHint:@"fakeuser@contoso.com"
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
}

- (void)testAcquireToken_whenCustomCompletionBlockQueue_shouldExecuteOnThatQueue_BearerFlow
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:authority];
    config.knownAuthorities = @[authority];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         completionBlock(nil, nil);
     }];
    
    MSALInteractiveTokenParameters *params = nil;
    
#if TARGET_OS_IPHONE
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    UIViewController *controller = nil;
    MSALWebviewParameters *webParams = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:controller];
    params = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"fakescope1", @"fakescope2"] webviewParameters:webParams];
    params.parentViewController = [self.class sharedViewControllerStub];
#else
    params = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"fakescope1", @"fakescope2"]];
#endif
    params.completionBlockQueue = dispatch_queue_create([@"test.queue" cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    const char *l1 = dispatch_queue_get_label(params.completionBlockQueue);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];
    
    [application acquireTokenWithParameters:params
                            completionBlock:^(MSALResult * _Nullable result, NSError * _Nullable error) {
                                
                                const char *l2 = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
                                XCTAssertEqual(l1, l2);
                                [expectation fulfill];
                            }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireToken_whenCustomCompletionBlockQueue_shouldExecuteOnThatQueue_PopFlow
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:authority];
    config.knownAuthorities = @[authority];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
        XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
        completionBlock(nil, nil);
    }];
    
    MSALInteractiveTokenParameters *params = nil;
    
#if TARGET_OS_IPHONE
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    UIViewController *controller = nil;
    MSALWebviewParameters *webParams = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:controller];
    params = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"fakescope1", @"fakescope2"] webviewParameters:webParams];
    params.parentViewController = [self.class sharedViewControllerStub];
#else
    params = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"fakescope1", @"fakescope2"]];
#endif
    
    NSURL *requestUrl = [NSURL URLWithString:@"https://signedhttprequest.azurewebsites.net/api/validateSHR"];
    params.authenticationScheme = [[MSALAuthenticationSchemePop alloc] initWithHttpMethod:MSALHttpMethodPOST requestUrl:requestUrl nonce:nil additionalParameters:nil];

    params.completionBlockQueue = dispatch_queue_create([@"test.queue" cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    const char *l1 = dispatch_queue_get_label(params.completionBlockQueue);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];
    
    [application acquireTokenWithParameters:params
                            completionBlock:^(MSALResult * _Nullable result, NSError * _Nullable error) {
        
        const char *l2 = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
        XCTAssertEqual(l1, l2);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}
#if TARGET_OS_IPHONE
- (void)testAcquireToken_whenCustomCompletionBlockQueueAndParentControllerNilError_shouldExecuteOnThatQueue
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:authority];
    config.knownAuthorities = @[authority];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         completionBlock(nil, nil);
     }];
    
    MSALInteractiveTokenParameters *params = nil;
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
    UIViewController *controller = nil;
    MSALWebviewParameters *webParams = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:controller];
    params = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"fakescope1", @"fakescope2"] webviewParameters:webParams];
    params.completionBlockQueue = dispatch_queue_create([@"test.queue" cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    const char *l1 = dispatch_queue_get_label(params.completionBlockQueue);
    
    [application acquireTokenWithParameters:params
                            completionBlock:^(MSALResult * _Nullable result, NSError * _Nullable error) {
                                
                                const char *l2 = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
                                XCTAssertEqual(l1, l2);
                            }];
}

- (void)testAcquireToken_whenCustomCompletionBlockQueueAndWindowNilError_shouldExecuteOnThatQueue
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:authority];
    config.knownAuthorities = @[authority];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         completionBlock(nil, nil);
     }];
    
    MSALInteractiveTokenParameters *params = nil;
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;

    static dispatch_once_t once;
    static UIViewController *controller;
    
    dispatch_once(&once, ^{
        controller = [UIViewController new];
    });
    
    MSALWebviewParameters *webParams = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:controller];
    params = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"fakescope1", @"fakescope2"] webviewParameters:webParams];
    params.parentViewController = controller;
    params.parentViewController.view = nil;
    params.completionBlockQueue = dispatch_queue_create([@"test.queue" cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    const char *l1 = dispatch_queue_get_label(params.completionBlockQueue);
    
    [application acquireTokenWithParameters:params
                            completionBlock:^(MSALResult * _Nullable result, NSError * _Nullable error) {
                                
                                const char *l2 = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
                                XCTAssertEqual(l1, l2);
                            }];
}
#endif

- (void)testAcquireToken_whenCustomCompletionBlockQueueAndScopeIsReservedError_shouldExecuteOnThatQueue
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:authority];
    config.knownAuthorities = @[authority];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         completionBlock(nil, nil);
     }];
    
    MSALInteractiveTokenParameters *params = nil;
    #if TARGET_OS_IPHONE
        MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
        
        UIViewController *controller = nil;
        MSALWebviewParameters *webParams = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:controller];
        params = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"profile"] webviewParameters:webParams];
        params.parentViewController = [self.class sharedViewControllerStub];
    #else
        params = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"profile"]];
    #endif
    params.completionBlockQueue = dispatch_queue_create([@"test.queue" cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    const char *l1 = dispatch_queue_get_label(params.completionBlockQueue);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];
    
    [application acquireTokenWithParameters:params
                            completionBlock:^(MSALResult * _Nullable result, NSError * _Nullable error) {
                                
                                const char *l2 = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
                                XCTAssertEqual(l1, l2);
                                [expectation fulfill];
                            }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenCustomCompletionBlockQueue_shouldExecuteOnThatQueue_BearerFlow
{
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:[@"https://login.microsoftonline.com/common" msalAuthority]];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDSilentController class]
                              block:(id)^(MSIDSilentController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDSilentController class]]);
         completionBlock(nil, nil);
     }];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"username"
                                                   homeAccountId:[[MSALAccountId alloc] initWithAccountIdentifier:@"kk" objectId:@"oid" tenantId:@"tid"]
                                                     environment:@"env"
                                                  tenantProfiles:nil];
    
    MSALSilentTokenParameters *params = [[MSALSilentTokenParameters alloc] initWithScopes:@[@"fakescope1", @"fakescope2"] account:account];
    
    params.completionBlockQueue = dispatch_queue_create([@"test.queue" cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    const char *l1 = dispatch_queue_get_label(params.completionBlockQueue);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];
    
    [application acquireTokenSilentWithParameters:params
                                  completionBlock:^(MSALResult * _Nullable result, NSError * _Nullable error) {
                                      const char *l2 = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
                                      XCTAssertEqual(l1, l2);
                                      [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenCustomCompletionBlockQueue_shouldExecuteOnThatQueue_PopFlow
{
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:[@"https://login.microsoftonline.com/common" msalAuthority]];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDSilentController class]
                              block:(id)^(MSIDSilentController *obj, MSIDRequestCompletionBlock completionBlock)
     {
        XCTAssertTrue([obj isKindOfClass:[MSIDSilentController class]]);
        completionBlock(nil, nil);
    }];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"username"
                                                   homeAccountId:[[MSALAccountId alloc] initWithAccountIdentifier:@"kk" objectId:@"oid" tenantId:@"tid"]
                                                     environment:@"env"
                                                  tenantProfiles:nil];
    
    MSALSilentTokenParameters *params = [[MSALSilentTokenParameters alloc] initWithScopes:@[@"fakescope1", @"fakescope2"] account:account];
    NSURL *requestUrl = [NSURL URLWithString:@"https://signedhttprequest.azurewebsites.net/api/validateSHR"];
    params.authenticationScheme = [[MSALAuthenticationSchemePop alloc] initWithHttpMethod:MSALHttpMethodPOST requestUrl:requestUrl nonce:nil additionalParameters:nil];

    params.completionBlockQueue = dispatch_queue_create([@"test.queue" cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    const char *l1 = dispatch_queue_get_label(params.completionBlockQueue);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];
    
    [application acquireTokenSilentWithParameters:params
                                  completionBlock:^(MSALResult * _Nullable result, NSError * _Nullable error) {
        const char *l2 = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
        XCTAssertEqual(l1, l2);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireTokenSilent_whenCustomCompletionBlockQueueAndScopeIsReservedError_shouldExecuteOnThatQueue
{
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:[@"https://login.microsoftonline.com/common" msalAuthority]];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDSilentController class]
                              block:(id)^(MSIDSilentController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDSilentController class]]);
         completionBlock(nil, nil);
     }];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"username"
                                                   homeAccountId:[[MSALAccountId alloc] initWithAccountIdentifier:@"kk" objectId:@"oid" tenantId:@"tid"]
                                                     environment:@"env"
                                                  tenantProfiles:nil];
    
    MSALSilentTokenParameters *params = [[MSALSilentTokenParameters alloc] initWithScopes:@[@"profile"] account:account];
    
    params.completionBlockQueue = dispatch_queue_create([@"test.queue" cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
    const char *l1 = dispatch_queue_get_label(params.completionBlockQueue);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];
    
    [application acquireTokenSilentWithParameters:params
                                  completionBlock:^(MSALResult * _Nullable result, NSError * _Nullable error) {
                                      const char *l2 = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
                                      XCTAssertEqual(l1, l2);
                                      [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireToken_whenNoCustomCompletionBlockQueue_andInvokedFromBackgroundQueue_shouldExecuteOnMainQueue
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:authority];
    config.knownAuthorities = @[authority];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         completionBlock(nil, nil);
     }];
    
    MSALInteractiveTokenParameters *params = nil;
    
#if TARGET_OS_IPHONE
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    UIViewController *controller = nil;
    MSALWebviewParameters *webParams = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:controller];
    params = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"fakescope1", @"fakescope2"] webviewParameters:webParams];
#else
    params = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"fakescope1", @"fakescope2"]];
#endif
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token"];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [application acquireTokenWithParameters:params
                                completionBlock:^(MSALResult * _Nullable result, NSError * _Nullable error) {
                                    
                                    XCTAssertTrue([NSThread isMainThread]);
                                    [expectation fulfill];
                                }];
    });
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testAcquireToken_whenKnownB2CAuthority_shouldNotValidate_BearerFlow
{
    NSURL *authorityURL = [NSURL URLWithString:@"https://myb2c.authority.com/mypath/mypath2/mypolicy/mypolicy2?policyId=queryParam"];
    MSALB2CAuthority *b2cAuthority = [[MSALB2CAuthority alloc] initWithURL:authorityURL error:nil];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:b2cAuthority];
    config.knownAuthorities = @[b2cAuthority];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         
         MSIDInteractiveTokenRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);
         
         XCTAssertFalse(params.validateAuthority);
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://myb2c.authority.com/mypath/mypath2/mypolicy/mypolicy2");
         completionBlock(nil, nil);
     }];
    
#if TARGET_OS_IPHONE
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
#endif
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                             loginHint:@"fakeuser@contoso.com"
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
}

- (void)testAcquireToken_whenKnownB2CAuthority_shouldNotValidate_PopFlow
{
    NSURL *authorityURL = [NSURL URLWithString:@"https://myb2c.authority.com/mypath/mypath2/mypolicy/mypolicy2?policyId=queryParam"];
    MSALB2CAuthority *b2cAuthority = [[MSALB2CAuthority alloc] initWithURL:authorityURL error:nil];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:b2cAuthority];
    config.knownAuthorities = @[b2cAuthority];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
        XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
        
        MSIDInteractiveTokenRequestParameters *params = [obj interactiveRequestParamaters];
        
        XCTAssertNotNil(params);
        
        XCTAssertFalse(params.validateAuthority);
        XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://myb2c.authority.com/mypath/mypath2/mypolicy/mypolicy2");
        completionBlock(nil, nil);
    }];
    
#if TARGET_OS_IPHONE
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
#endif
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                             loginHint:@"fakeuser@contoso.com"
                       completionBlock:^(MSALResult *result, NSError *error)
     {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
    }];
}

- (void)testAcquireTokenSilent_whenKnownB2CAuthority_shouldNotValidate
{
    NSURL *authorityURL = [NSURL URLWithString:@"https://contoso.b2clogin.com/tfp/contoso.onmicrosoft.com/B2C_1_signup-signin"];
    MSALB2CAuthority *b2cAuthority = [[MSALB2CAuthority alloc] initWithURL:authorityURL error:nil];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:b2cAuthority];
    config.knownAuthorities = @[b2cAuthority];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
#if TARGET_OS_IPHONE
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
#endif
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDSilentController class]
                              block:(id)^(MSIDSilentController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDSilentController class]]);
         
         MSIDRequestParameters *params = [obj requestParameters];
         XCTAssertNotNil(params);
         
         XCTAssertFalse(params.validateAuthority);
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://contoso.b2clogin.com/tfp/contoso.onmicrosoft.com/B2C_1_signup-signin");
         completionBlock(nil, nil);
     }];
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"uid.utid" objectId:@"uid" tenantId:@"utid"];
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:nil homeAccountId:accountId environment:@"myb2c.authority.com" tenantProfiles:nil];
    
    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
                             completionBlock:^(MSALResult * _Nullable result, NSError * _Nullable error) {
                                 
                                 XCTAssertNil(result);
                                 XCTAssertNotNil(error);
                             }];
}

- (void)testAcquireTokenSilent_whenNoTfpAuthority_shouldNotValidate
{
    NSURL *authorityURL = [NSURL URLWithString:@"https://contoso.b2clogin.com/contoso.onmicrosoft.com/nontfp_path/B2C_1_signup-signin"];
    MSALB2CAuthority *b2cAuthority = [[MSALB2CAuthority alloc] initWithURL:authorityURL error:nil];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID redirectUri:nil authority:b2cAuthority];
    config.knownAuthorities = @[b2cAuthority];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
#if TARGET_OS_IPHONE
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
#endif
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDSilentController class]
                              block:(id)^(MSIDSilentController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDSilentController class]]);
         
         MSIDRequestParameters *params = [obj requestParameters];
         XCTAssertNotNil(params);
         
         XCTAssertFalse(params.validateAuthority);
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://contoso.b2clogin.com/contoso.onmicrosoft.com/nontfp_path/B2C_1_signup-signin");
         completionBlock(nil, nil);
     }];
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"uid.utid" objectId:@"uid" tenantId:@"utid"];
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:nil homeAccountId:accountId environment:@"myb2c.authority.com" tenantProfiles:nil];
    
    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
                             completionBlock:^(MSALResult * _Nullable result, NSError * _Nullable error) {
                                 
                                 XCTAssertNil(result);
                                 XCTAssertNotNil(error);
                             }];
}

#pragma mark - acquireToken using Login Hint

- (void)testAcquireScopesLoginHint
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    config.sliceConfig = [MSALSliceConfig configWithSlice:@"slice" dc:@"dc"];
    
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         
         MSIDInteractiveTokenRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);
         
         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireWithHint];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.extraURLQueryParameters, (@{ @"slice" : @"slice", @"dc" : @"dc" }));;
         XCTAssertNotNil(params.correlationId);
         XCTAssertNil(params.extraScopesToConsent);
         XCTAssertEqual(params.promptType, MSIDPromptTypePromptIfNecessary);
         XCTAssertTrue(params.extraAuthorizeURLQueryParameters.count == 0);
         XCTAssertEqualObjects(params.loginHint, @"fakeuser@contoso.com");
         
         completionBlock(nil, nil);
     }];
    
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                             loginHint:@"fakeuser@contoso.com"
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
}


- (void)testAcquireScopesLoginHintBehaviorEQPs_andCustomKeychainGroup
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    config.sliceConfig = [MSALSliceConfig configWithSlice:@"slice" dc:@"dc"];
    config.cacheConfig.keychainSharingGroup = @"com.mycustom.group";
    
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         
         MSIDInteractiveTokenRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);
         
         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireWithTokenParameters];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.extraURLQueryParameters, (@{ @"slice" : @"slice", @"dc" : @"dc" }));
         XCTAssertNotNil(params.correlationId);
         XCTAssertEqualObjects(params.extraAuthorizeURLQueryParameters, (@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }));
         XCTAssertEqualObjects(params.loginHint, @"fakeuser@contoso.com");
         XCTAssertNil(params.extraScopesToConsent);
         XCTAssertEqual(params.promptType, MSIDPromptTypeLogin);
         XCTAssertEqualObjects(params.keychainAccessGroup, @"com.mycustom.group");
         
         completionBlock(nil, nil);
     }];
    
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
#if TARGET_OS_IPHONE
    UIViewController *parentController = nil;
    MSALWebviewParameters *webParameters = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:parentController];
    webParameters.webviewType = MSALWebviewTypeWKWebView;
#else
    MSALWebviewParameters *webParameters = [MSALWebviewParameters new];
#endif
    MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"fakescope1", @"fakescope2"]
                                                                                      webviewParameters:webParameters];
    
    parameters.promptType = MSALPromptTypeLogin;
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    
    [application acquireTokenWithParameters:parameters
                            completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
}

- (void)testAcquireScopesAddlScopesLoginHintuiBehaviorEQPAuthorityCorrelationId
{
    [MSIDTestBundle overrideBundleId:@"com.microsoft.unit-test-host"];
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    config.sliceConfig = [MSALSliceConfig configWithSlice:@"slice" dc:@"dc"];
    
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    __block NSUUID *correlationId = [NSUUID new];
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         
         MSIDInteractiveTokenRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);
         
         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireWithTokenParameters];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/contoso.com");
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.extraURLQueryParameters, (@{ @"slice" : @"slice", @"dc" : @"dc" }));
         XCTAssertEqualObjects(params.correlationId, correlationId);
         XCTAssertEqualObjects(params.extraAuthorizeURLQueryParameters, (@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }));
         XCTAssertEqualObjects(params.loginHint, @"fakeuser@contoso.com");
         XCTAssertEqualObjects(params.extraScopesToConsent, @"fakescope3");
         XCTAssertEqual(params.promptType, MSIDPromptTypeConsent);
         
         completionBlock(nil, nil);
     }];
    
    authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
#if TARGET_OS_IPHONE
    UIViewController *parentController = nil;
    MSALWebviewParameters *webParameters = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:parentController];
    webParameters.webviewType = MSALWebviewTypeWKWebView;
#else
    MSALWebviewParameters *webParameters = [MSALWebviewParameters new];
#endif
    MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"fakescope1", @"fakescope2"]
                                                                                      webviewParameters:webParameters];
    
    parameters.promptType = MSALPromptTypeConsent;
    parameters.extraScopesToConsent = @[@"fakescope3"];
    parameters.loginHint = @"fakeuser@contoso.com";
    parameters.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    parameters.authority = authority;
    parameters.correlationId = correlationId;
    
    [application acquireTokenWithParameters:parameters
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
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    config.sliceConfig = [MSALSliceConfig configWithSlice:@"slice" dc:@"dc"];
    
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"1.1234-5678-90abcdefg" objectId:nil tenantId:nil];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:nil];
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         
         MSIDInteractiveTokenRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);
         
         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireWithUserPromptTypeAndParameters];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
         XCTAssertEqualObjects(params.providedAuthority.url.absoluteString, @"https://login.microsoftonline.com/common");
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.extraURLQueryParameters, (@{ @"slice" : @"slice", @"dc" : @"dc" }));
         XCTAssertNotNil(params.correlationId);
         XCTAssertTrue(params.extraAuthorizeURLQueryParameters.count == 0);
         XCTAssertNil(params.loginHint);
         XCTAssertNil(params.extraScopesToConsent);
         XCTAssertEqual(params.promptType, MSIDPromptTypePromptIfNecessary);
         
         XCTAssertEqualObjects(params.accountIdentifier, account.lookupAccountIdentifier);
         
         completionBlock(nil, nil);
     }];
    
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
    
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
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    config.sliceConfig = [MSALSliceConfig configWithSlice:@"slice" dc:@"dc"];
    
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"1.1234-5678-90abcdefg" objectId:nil tenantId:nil];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:nil];
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         
         MSIDInteractiveTokenRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);
         
         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireWithTokenParameters];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.extraURLQueryParameters, (@{ @"slice" : @"slice", @"dc" : @"dc" }));
         XCTAssertNotNil(params.correlationId);
         XCTAssertEqualObjects(params.extraAuthorizeURLQueryParameters, (@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }));
         XCTAssertNil(params.loginHint);
         XCTAssertNil(params.extraScopesToConsent);
         XCTAssertEqual(params.promptType, MSIDPromptTypePromptIfNecessary);
         XCTAssertEqualObjects(params.accountIdentifier, account.lookupAccountIdentifier);
         
         completionBlock(nil, nil);
     }];
    
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
#if TARGET_OS_IPHONE
    UIViewController *parentController = nil;
    MSALWebviewParameters *webParameters = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:parentController];
    webParameters.webviewType = MSALWebviewTypeWKWebView;
#else
    MSALWebviewParameters *webParameters = [MSALWebviewParameters new];
#endif
    MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"fakescope1", @"fakescope2"]
                                                                                      webviewParameters:webParameters];
    
    parameters.promptType = MSALPromptTypeDefault;
    parameters.account = account;
    parameters.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    
    [application acquireTokenWithParameters:parameters
                            completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
}

- (void)testAcquireScopesAddlScopesUserUiBehaviorEQPAuthorityCorrelationId
{
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    config.sliceConfig = [MSALSliceConfig configWithSlice:@"slice" dc:@"dc"];
    
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    __block NSUUID *correlationId = [NSUUID new];
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"1.1234-5678-90abcdefg" objectId:nil tenantId:nil];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:nil];
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDLocalInteractiveController class]
                              block:(id)^(MSIDLocalInteractiveController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDLocalInteractiveController class]]);
         
         MSIDInteractiveTokenRequestParameters *params = [obj interactiveRequestParamaters];
         XCTAssertNotNil(params);
         
         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireWithTokenParameters];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/contoso.com");
         XCTAssertEqualObjects(params.providedAuthority.url.absoluteString, @"https://login.microsoftonline.com/contoso.com");
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.redirectUri, UNIT_TEST_DEFAULT_REDIRECT_URI);
         XCTAssertEqualObjects(params.extraURLQueryParameters, (@{ @"slice" : @"slice", @"dc" : @"dc" }));
         XCTAssertEqualObjects(params.correlationId, correlationId);
         XCTAssertEqualObjects(params.extraAuthorizeURLQueryParameters, (@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }));
         XCTAssertNil(params.loginHint);
         XCTAssertEqualObjects(params.accountIdentifier, account.lookupAccountIdentifier);
         XCTAssertEqualObjects(params.extraScopesToConsent, @"fakescope3");
         XCTAssertEqual(params.promptType, MSIDPromptTypePromptIfNecessary);
         
         completionBlock(nil, nil);
     }];
    
    authority = [@"https://login.microsoftonline.com/contoso.com" msalAuthority];
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
#if TARGET_OS_IPHONE
    UIViewController *parentController = nil;
    MSALWebviewParameters *webParameters = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:parentController];
    webParameters.webviewType = MSALWebviewTypeWKWebView;
#else
    MSALWebviewParameters *webParameters = [MSALWebviewParameters new];
#endif
    MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:@[@"fakescope1", @"fakescope2"]
                                                                                      webviewParameters:webParameters];
    
    parameters.promptType = MSALPromptTypeDefault;
    parameters.extraScopesToConsent = @[@"fakescope3"];
    parameters.account = account;
    parameters.extraQueryParameters = @{ @"eqp1" : @"val1", @"eqp2" : @"val2" };
    parameters.authority = authority;
    parameters.correlationId = correlationId;
    
    [application acquireTokenWithParameters:parameters
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
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    config.sliceConfig = [MSALSliceConfig configWithSlice:@"slice" dc:@"dc"];
    
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
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
         XCTAssertEqualObjects(params.accountIdentifier.displayableId, @"user@contoso.com");
         XCTAssertEqualObjects(params.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.extraURLQueryParameters, (@{ @"slice" : @"slice", @"dc" : @"dc" }));
         
         XCTAssertEqualObjects(params.authority, [@"https://login.microsoftonline.com/1234-5678-90abcdefg" msalAuthority].msidAuthority);
         
         XCTAssertFalse(obj.forceRefresh);
         
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"1.1234-5678-90abcdefg" objectId:@"1" tenantId:@"1234-5678-90abcdefg"];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:nil];
    
    application.accountMetadataCache = self.accountMetadataCache;
    application.msalOauth2Provider = [MSALOauth2ProviderFactory oauthProviderForAuthority:authority
                                                                                 clientId:UNIT_TEST_CLIENT_ID
                                                                               tokenCache:self.tokenCacheAccessor
                                                                     accountMetadataCache:self.accountMetadataCache
                                                                                  context:nil
                                                                                    error:nil];
    // Save account metadata authority map from common to the specific tenant id.
    [self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/1234-5678-90abcdefg"]
                                    forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] homeAccountId:accountId.identifier
                                         clientId:UNIT_TEST_CLIENT_ID
                                    instanceAware:NO
                                          context:nil
                                            error:nil];
    
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
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    config.sliceConfig = [MSALSliceConfig configWithSlice:@"slice" dc:@"dc"];
    
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
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
         XCTAssertEqualObjects(params.accountIdentifier.displayableId, @"user@contoso.com");
         XCTAssertEqualObjects(params.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.extraURLQueryParameters, (@{ @"slice" : @"slice", @"dc" : @"dc" }));
         
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.providedAuthority.url.absoluteString, @"https://login.microsoftonline.com/common");
         
         XCTAssertFalse(obj.forceRefresh);
         
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"1.1234-5678-90abcdefg" objectId:@"1" tenantId:@"1234-5678-90abcdefg"];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:nil];
    
    // Save account metadata authority map from common to the specific tenant id.
    [self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/1234-5678-90abcdefg"]
                                    forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                    homeAccountId:@"1.1234-5678-90abcdefg"
                                         clientId:UNIT_TEST_CLIENT_ID instanceAware:NO context:nil error:nil];
    
    application.accountMetadataCache = self.accountMetadataCache;
    application.msalOauth2Provider = [MSALOauth2ProviderFactory oauthProviderForAuthority:authority
                                                                                 clientId:UNIT_TEST_CLIENT_ID
                                                                               tokenCache:self.tokenCacheAccessor
                                                                     accountMetadataCache:self.accountMetadataCache
                                                                                  context:nil
                                                                                    error:nil];
    
    
    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
                                   authority:authority
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
    
}

- (void)testAcquireTokenSilent_whenNoAuthority_andCommonAuthorityInPublicClientApplication_andNoAccountMetadata_shouldUseHomeAuthority
{
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSIDTestSwizzle instanceMethod:@selector(acquireToken:)
                              class:[MSIDSilentController class]
                              block:(id)^(MSIDSilentController *obj, MSIDRequestCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSIDSilentController class]]);
         
         MSIDRequestParameters *params = [obj requestParameters];
         XCTAssertNotNil(params);
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/1234-5678-90abcdefg");
         completionBlock(nil, nil);
     }];
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"1.1234-5678-90abcdefg" objectId:@"1" tenantId:@"1234-5678-90abcdefg"];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:nil];
    
    application.accountMetadataCache = self.accountMetadataCache;
    application.msalOauth2Provider = [MSALOauth2ProviderFactory oauthProviderForAuthority:authority
                                                                                 clientId:UNIT_TEST_CLIENT_ID
                                                                               tokenCache:self.tokenCacheAccessor
                                                                     accountMetadataCache:self.accountMetadataCache
                                                                                  context:nil
                                                                                    error:nil];
    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
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
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    config.sliceConfig = [MSALSliceConfig configWithSlice:@"slice" dc:@"dc"];
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
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
         XCTAssertEqualObjects(params.accountIdentifier.displayableId, @"user@contoso.com");
         XCTAssertEqualObjects(params.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.extraURLQueryParameters, (@{ @"slice" : @"slice", @"dc" : @"dc" }));
         
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/1234-5678-90abcdefg");
         
         XCTAssertFalse(obj.forceRefresh);
         
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"1.1234-5678-90abcdefg" objectId:@"1" tenantId:@"1234-5678-90abcdefg"];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:nil];
    
    application.accountMetadataCache = self.accountMetadataCache;
    application.msalOauth2Provider = [MSALOauth2ProviderFactory oauthProviderForAuthority:authority
                                                                                 clientId:UNIT_TEST_CLIENT_ID
                                                                               tokenCache:self.tokenCacheAccessor
                                                                     accountMetadataCache:self.accountMetadataCache
                                                                                  context:nil
                                                                                    error:nil];
    // Save account metadata authority map from common to the specific tenant id.
    [self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/1234-5678-90abcdefg"]
                                    forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] homeAccountId:accountId.identifier clientId:UNIT_TEST_CLIENT_ID instanceAware:NO context:nil error:nil];
    
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
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    config.sliceConfig = [MSALSliceConfig configWithSlice:@"slice" dc:@"dc"];
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
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
         XCTAssertEqualObjects(params.accountIdentifier.displayableId, @"user@contoso.com");
         XCTAssertEqualObjects(params.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.extraURLQueryParameters, (@{ @"slice" : @"slice", @"dc" : @"dc" }));
         
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/custom_guest_tenant");
         
         XCTAssertFalse(obj.forceRefresh);
         
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"1.1234-5678-90abcdefg" objectId:@"1" tenantId:@"1234-5678-90abcdefg"];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:nil];
    
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
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    config.sliceConfig = [MSALSliceConfig configWithSlice:@"slice" dc:@"dc"];
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
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
         XCTAssertEqualObjects(params.accountIdentifier.displayableId, @"user@contoso.com");
         XCTAssertEqualObjects(params.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.extraURLQueryParameters, (@{ @"slice" : @"slice", @"dc" : @"dc" }));
         
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/custom_guest_tenant");
         
         XCTAssertFalse(obj.forceRefresh);
         
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"1.1234-5678-90abcdefg" objectId:@"1" tenantId:@"1234-5678-90abcdefg"];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:nil];
    
    [application acquireTokenSilentForScopes:@[@"fakescope1", @"fakescope2"]
                                     account:account
                                   authority:nil
                             completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNotNil(error);
     }];
    
}

- (void)testAcquireSilentScopesUserAuthorityForceRefreshCorrelationId_andCustomKeychainGroup
{
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    config.sliceConfig = [MSALSliceConfig configWithSlice:@"slice" dc:@"dc"];
    config.cacheConfig.keychainSharingGroup = @"com.mycustom.group";
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
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
         
         NSString *expectedApiId = [NSString stringWithFormat:@"%ld", (long)MSALTelemetryApiIdAcquireSilentWithTokenParameters];
         XCTAssertEqualObjects(params.telemetryApiId, expectedApiId);
         XCTAssertEqualObjects(params.accountIdentifier.displayableId, @"user@contoso.com");
         XCTAssertEqualObjects(params.accountIdentifier.homeAccountId, @"1.1234-5678-90abcdefg");
         XCTAssertEqualObjects(params.extraURLQueryParameters, (@{ @"slice" : @"slice", @"dc" : @"dc" }));
         
         XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/1234-5678-90abcdefg");
         
         XCTAssertTrue(obj.forceRefresh);
         
         XCTAssertEqualObjects(params.correlationId, correlationId);
         XCTAssertEqualObjects(params.target, @"fakescope1 fakescope2");
         XCTAssertEqualObjects(params.oidcScope, @"openid profile offline_access");
         XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
         XCTAssertEqualObjects(params.keychainAccessGroup, @"com.mycustom.group");
         
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"1.1234-5678-90abcdefg" objectId:@"1" tenantId:@"1234-5678-90abcdefg"];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:nil];
    
    application.accountMetadataCache = self.accountMetadataCache;
    application.msalOauth2Provider = [MSALOauth2ProviderFactory oauthProviderForAuthority:authority
                                                                                 clientId:UNIT_TEST_CLIENT_ID
                                                                               tokenCache:self.tokenCacheAccessor
                                                                     accountMetadataCache:self.accountMetadataCache
                                                                                  context:nil
                                                                                    error:nil];
    application.msalOauth2Provider = [MSALOauth2ProviderFactory oauthProviderForAuthority:authority
                                                                                 clientId:UNIT_TEST_CLIENT_ID
                                                                               tokenCache:self.tokenCacheAccessor
                                                                     accountMetadataCache:self.accountMetadataCache
                                                                                  context:nil
                                                                                    error:nil];
    
    // Save account metadata authority map from common to the specific tenant id.
    [self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/1234-5678-90abcdefg"]
                                    forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] homeAccountId:accountId.identifier clientId:UNIT_TEST_CLIENT_ID instanceAware:NO context:nil error:nil];
    
    MSALSilentTokenParameters *silentParameters = [[MSALSilentTokenParameters alloc] initWithScopes:@[@"fakescope1", @"fakescope2"] account:account];
    silentParameters.correlationId = correlationId;
    silentParameters.forceRefresh = YES;
    silentParameters.authority = authority;
    
    [application acquireTokenSilentWithParameters:silentParameters
                                  completionBlock:^(MSALResult * _Nullable result, NSError * _Nullable error) {
        
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
    XCTAssertEqualObjects(account.homeAccountId.identifier, @"myuid.utid");
    XCTAssertEqualObjects(account.homeAccountId.objectId, @"myuid");
    XCTAssertEqualObjects(account.homeAccountId.tenantId, @"utid");
    XCTAssertEqual(account.tenantProfiles.count, 1);
    XCTAssertTrue(account.tenantProfiles[0].isHomeTenantProfile);
}

- (void)testAllAccounts_when2AccountExists_shouldReturn2Accounts
{
    [self msalStoreTokenResponseInCacheWithAuthority:@"https://login.microsoftonline.com/common" uid:@"myuid"
                                                utid:@"utid"];
    [self msalStoreTokenResponseInCacheWithAuthority:@"https://example.com/common" uid:@"myuid2"
                                                utid:@"utid2"];
    
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID error:nil];
    application.tokenCache = self.tokenCacheAccessor;
    
    NSError *error = nil;
    NSArray<MSALAccount *> *accounts = [application allAccounts:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 2);
    
    MSALAccount *account;
    MSALAccount *account2;
    if ([@"login.microsoftonline.com" isEqualToString:accounts[0].environment])
    {
        account = accounts[0];
        account2 = accounts[1];
    }
    else
    {
        account = accounts[1];
        account2 = accounts[0];
    }
    
    XCTAssertEqualObjects(account.username, @"fakeuser@contoso.com");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.homeAccountId.identifier, @"myuid.utid");
    XCTAssertEqualObjects(account.homeAccountId.objectId, @"myuid");
    XCTAssertEqualObjects(account.homeAccountId.tenantId, @"utid");
    
    XCTAssertEqualObjects(account2.username, @"fakeuser@contoso.com");
    XCTAssertEqualObjects(account2.environment, @"example.com");
    XCTAssertEqualObjects(account2.homeAccountId.identifier, @"myuid2.utid2");
    XCTAssertEqualObjects(account2.homeAccountId.objectId, @"myuid2");
    XCTAssertEqualObjects(account2.homeAccountId.tenantId, @"utid2");
}

- (void)testAllAccount_whenFociTokenExistsForOtherClient_andAppMetadataWithSameFamilyIdInCache_shouldReturnAccountNoError
{
    //store at & rt in cache with foci flag
    MSIDAADV2TokenResponse *msidResponse = [MSALTestCacheTokenResponse msalDefaultTokenResponseWithFamilyId:@"1"];
    MSIDConfiguration *configuration = [MSALTestCacheTokenResponse msalDefaultConfigurationWithAuthority:@"https://login.microsoftonline.com/common"];
    
    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:configuration
                                                              response:msidResponse
                                                               factory:[MSIDAADV2Oauth2Factory new]
                                                               context:nil
                                                                 error:nil];
    XCTAssertTrue(result);
    XCTAssertEqual([[self.tokenCacheAccessor allTokensWithContext:nil error:nil] count], 4);
    
    NSString *clientId = @"myclient";

    [self.tokenCacheAccessor updateAppMetadataWithFamilyId:@"1" clientId:clientId authority:configuration.authority context:nil error:nil];

    // Retrieve cache for a different clientId
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"msalmyclient"] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSError *appError = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId error:&appError];
    XCTAssertNil(appError);
    application.tokenCache = self.tokenCacheAccessor;
    
    NSError *error = nil;
    NSArray *allAccounts = [application allAccounts:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertEqual([allAccounts count], 1);
}

- (void)testAllAccount_whenFociTokenExistsForOtherClient_andAppMetadataWithNoFamilyIdInCache_shouldReturnNoAccountNoError
{
    //store at & rt in cache with foci flag
    MSIDAADV2TokenResponse *msidResponse = [MSALTestCacheTokenResponse msalDefaultTokenResponseWithFamilyId:@"1"];
    MSIDConfiguration *configuration = [MSALTestCacheTokenResponse msalDefaultConfigurationWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSError *error = nil;
    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:configuration
                                                              response:msidResponse
                                                               factory:[MSIDAADV2Oauth2Factory new]
                                                               context:nil
                                                                 error:&error];
    XCTAssertTrue(result);
    XCTAssertEqual([[self.tokenCacheAccessor allTokensWithContext:nil error:nil] count], 4);
    
    NSString *clientId = @"myclient";

    [self.tokenCacheAccessor updateAppMetadataWithFamilyId:@"" clientId:clientId authority:configuration.authority context:nil error:nil];

    // Retrieve cache for a different clientId
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"msalmyclient"] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSError *appError = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId error:&appError];
    XCTAssertNil(appError);
    application.tokenCache = self.tokenCacheAccessor;
    
    NSArray *allAccounts = [application allAccounts:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertEqual([allAccounts count], 0);
}

- (void)testAllAccount_whenAccountExistsForOtherClient_andNotFociClient_shouldReturnNoAccountNoError
{
    //store at & rt in cache with foci flag
    MSIDAADV2TokenResponse *msidResponse = [MSALTestCacheTokenResponse msalDefaultTokenResponseWithFamilyId:nil];
    MSIDConfiguration *configuration = [MSALTestCacheTokenResponse msalDefaultConfigurationWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSError *error = nil;
    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:configuration
                                                              response:msidResponse
                                                               factory:[MSIDAADV2Oauth2Factory new]
                                                               context:nil
                                                                 error:&error];
    XCTAssertTrue(result);
    XCTAssertEqual([[self.tokenCacheAccessor allTokensWithContext:nil error:nil] count], 3);

    NSString *clientId = @"myclient";
    
    // Retrieve cache for a different clientId
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"msalmyclient"] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSError *appError = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId error:&appError];
    XCTAssertNil(appError);
    application.tokenCache = self.tokenCacheAccessor;
    
    NSArray *allAccounts = [application allAccounts:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(allAccounts);
    XCTAssertEqual([allAccounts count], 0);
}


#if TARGET_OS_IPHONE
#pragma mark - All accounts from device
 
- (void)testAllAccountsFromDevice_whenBrokerEnabled_andEncounteredError_shouldReturnError API_AVAILABLE(ios(13.0), macos(10.15))
{
    NSString *scheme = [NSString stringWithFormat:@"msauth.%@", [[NSBundle mainBundle] bundleIdentifier]];
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[scheme] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                                    error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityAuto;
    
    XCTAssertEqual([application allAccounts:nil].count, 0);
    
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetAccountsRequest class]
                           block:(id)^(id obj)
    {
        return YES;
    }];
      
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetAccountsRequest  class]
                              block:(id)^(id obj, MSIDGetAccountsRequestCompletionBlock callback)
    {
        [expectation fulfill];
        
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInteractionRequired, @"test error", nil, nil, nil, nil, nil, NO);
        callback(nil, NO, error);
    }];
    
    XCTestExpectation *accountsExpectation = [self expectationWithDescription:@"Accounts from device"];
    
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:@"uid.utid"];
    
    [application accountsFromDeviceForParameters:params
                                 completionBlock:^(NSArray<MSALAccount *> * _Nullable accounts, NSError * _Nullable error) {
        
        XCTAssertNil(accounts);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSALErrorDomain);
        XCTAssertEqual(error.code, MSALErrorInteractionRequired);
        [accountsExpectation fulfill];
        
    }];
    
    [self waitForExpectations:@[expectation, accountsExpectation] timeout:1];
}

- (void)testAllAccountsFromDevice_whenBrokerEnabled_andFoundAccounts_shouldReturnAccounts API_AVAILABLE(ios(13.0), macos(10.15))
{
    NSString *scheme = [NSString stringWithFormat:@"msauth.%@", [[NSBundle mainBundle] bundleIdentifier]];
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[scheme] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSArray *querySchemes = @[@"myotherscheme", @"msauthv2", @"msauthv3"];
    [MSIDTestBundle overrideObject:querySchemes forKey:@"LSApplicationQueriesSchemes"];
    
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                                    error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityAuto;
    
    XCTAssertEqual([application allAccounts:nil].count, 0);
    
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetAccountsRequest class]
                           block:(id)^(id obj)
    {
        return YES;
    }];
      
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetAccountsRequest  class]
                              block:(id)^(id obj, MSIDGetAccountsRequestCompletionBlock callback)
    {
        [expectation fulfill];
        
        MSIDAccount *account2 = [MSIDAccount new];
        account2.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com" homeAccountId:@"uid.tid"];
        account2.environment = @"login.windows.net";
        
        MSIDAccount *account3 = [MSIDAccount new];
        account3.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user2@contoso.com" homeAccountId:@"uid2.utid"];
        account3.environment = @"login.windows.net";
        
        callback(@[account2, account3], NO, nil);
    }];
    
    XCTestExpectation *accountsExpectation = [self expectationWithDescription:@"Accounts from device"];
    
    MSALAccountEnumerationParameters *params = [MSALAccountEnumerationParameters new];
    
    [application accountsFromDeviceForParameters:params
                                 completionBlock:^(NSArray<MSALAccount *> * _Nullable accounts, NSError * _Nullable error) {
        
        XCTAssertNotNil(accounts);
        XCTAssertEqual([accounts count], 2);
        
        MSALAccount *firstAccount = accounts[0];
        XCTAssertEqualObjects(firstAccount.identifier, @"uid.tid");
        
        MSALAccount *secondAccount = accounts[1];
        XCTAssertEqualObjects(secondAccount.identifier, @"uid2.utid");
        
        XCTAssertNil(error);
        [accountsExpectation fulfill];
        
    }];
    
    [self waitForExpectations:@[expectation, accountsExpectation] timeout:1];
}

- (void)testAllAccountsFromDevice_whenBrokerEnabled_andFoundAccounts_andAccountEnumerationParametersProvided_shouldReturnFilteredAccounts API_AVAILABLE(ios(13.0), macos(10.15))
{
    NSString *scheme = [NSString stringWithFormat:@"msauth.%@", [[NSBundle mainBundle] bundleIdentifier]];
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[scheme] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSArray *querySchemes = @[@"myotherscheme", @"msauthv2", @"msauthv3"];
    [MSIDTestBundle overrideObject:querySchemes forKey:@"LSApplicationQueriesSchemes"];
    
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                                    error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityAuto;
    
    XCTAssertEqual([application allAccounts:nil].count, 0);
    
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetAccountsRequest class]
                           block:(id)^(id obj)
    {
        return YES;
    }];
          
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetAccountsRequest  class]
                              block:(id)^(id obj, MSIDGetAccountsRequestCompletionBlock callback)
    {
        MSIDAccount *account2 = [MSIDAccount new];
        account2.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com" homeAccountId:@"uid.tid"];
        account2.environment = @"login.windows.net";
        account2.localAccountId = @"local.oid";
        
        MSIDAccount *account3 = [MSIDAccount new];
        account3.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user2@contoso.com" homeAccountId:@"uid2.utid"];
        account3.environment = @"login.windows.net";
        account3.localAccountId = @"local.oid2";
        
        callback(@[account2, account3], NO, nil);
    }];
    
    XCTestExpectation *accountIdExpectation = [self expectationWithDescription:@"Accounts from device filtered by identifier"];
    
    // 1. Filter by home account id
    MSALAccountEnumerationParameters *params = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:@"uid2.utid"];
    
    [application accountsFromDeviceForParameters:params
                                 completionBlock:^(NSArray<MSALAccount *> * _Nullable accounts, NSError * _Nullable error) {
        
        XCTAssertNotNil(accounts);
        XCTAssertEqual([accounts count], 1);
        
        MSALAccount *firstAccount = accounts[0];
        XCTAssertEqualObjects(firstAccount.identifier, @"uid2.utid");
        
        XCTAssertNil(error);
        [accountIdExpectation fulfill];
        
    }];
    
    [self waitForExpectations:@[accountIdExpectation] timeout:1];
    
    XCTestExpectation *usernameExpectation = [self expectationWithDescription:@"Accounts from device filtered by username"];
    
    // 2. Filter by username
    params = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:nil username:@"user2@contoso.com"];
    
    [application accountsFromDeviceForParameters:params
                                 completionBlock:^(NSArray<MSALAccount *> * _Nullable accounts, NSError * _Nullable error) {
        
        XCTAssertNotNil(accounts);
        XCTAssertEqual([accounts count], 1);
        
        MSALAccount *firstAccount = accounts[0];
        XCTAssertEqualObjects(firstAccount.identifier, @"uid2.utid");
        
        XCTAssertNil(error);
        [usernameExpectation fulfill];
        
    }];
    
    [self waitForExpectations:@[usernameExpectation] timeout:1];
    
    XCTestExpectation *localAccountIdExpectation = [self expectationWithDescription:@"Accounts from device filtered by tenant profile identifier"];
    
    // 3. Filter by local id
    params = [[MSALAccountEnumerationParameters alloc] initWithTenantProfileIdentifier:@"local.oid2"];
    
    [application accountsFromDeviceForParameters:params
                                 completionBlock:^(NSArray<MSALAccount *> * _Nullable accounts, NSError * _Nullable error) {
        
        XCTAssertNotNil(accounts);
        XCTAssertEqual([accounts count], 1);
        
        MSALAccount *firstAccount = accounts[0];
        XCTAssertEqualObjects(firstAccount.identifier, @"uid2.utid");
        
        XCTAssertNil(error);
        [localAccountIdExpectation fulfill];
        
    }];
    
    [self waitForExpectations:@[localAccountIdExpectation] timeout:1];
    
    XCTestExpectation *combinedExpectation = [self expectationWithDescription:@"Accounts from device filtered by username and account id"];
    
    // 4. Filter by both accountId and username
    params = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:@"uid2.utid" username:@"nonexistent@contoso.com"];
    
    [application accountsFromDeviceForParameters:params
                                 completionBlock:^(NSArray<MSALAccount *> * _Nullable accounts, NSError * _Nullable error) {
        
        XCTAssertNotNil(accounts);
        XCTAssertEqual([accounts count], 0);
        
        XCTAssertNil(error);
        [combinedExpectation fulfill];
        
    }];
    
    [self waitForExpectations:@[combinedExpectation] timeout:1];
}

#pragma mark - Get device info

- (void)testGetDeviceInfo_whenBrokerEnabled_andFoundDeviceInfo_shouldReturnDeviceInfoAndNilError API_AVAILABLE(ios(13.0), macos(10.15))
{
    NSString *scheme = [NSString stringWithFormat:@"msauth.%@", [[NSBundle mainBundle] bundleIdentifier]];
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[scheme] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSArray *querySchemes = @[@"msauthv2", @"msauthv3"];
    [MSIDTestBundle overrideObject:querySchemes forKey:@"LSApplicationQueriesSchemes"];
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID error:nil];
    
    XCTAssertNotNil(application);
      
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    
    [MSIDTestSwizzle instanceMethod:@selector(deviceInfoWithRequestParameters:completionBlock:)
                              class:[MSALDeviceInfoProvider  class]
                              block:(id)^(id obj, MSIDRequestParameters *requestParameters, MSALDeviceInformationCompletionBlock callback)
    {
        [expectation fulfill];
        
        MSIDDeviceInfo *msidDeviceInfo = [MSIDDeviceInfo new];
        msidDeviceInfo.deviceMode = MSIDDeviceModeShared;
        MSALDeviceInformation *deviceInfo = [[MSALDeviceInformation alloc] initWithMSIDDeviceInfo:msidDeviceInfo];
        callback(deviceInfo, nil);
    }];
    
    XCTestExpectation *deviceInfoExpectation = [self expectationWithDescription:@"Get device info"];
    
    [application getDeviceInformationWithParameters:nil
                                    completionBlock:^(MSALDeviceInformation * _Nullable deviceInformation, NSError * _Nullable error)
    {
        XCTAssertNotNil(deviceInformation);
        XCTAssertNil(error);
        XCTAssertEqual(deviceInformation.deviceMode, MSALDeviceModeShared);
        [deviceInfoExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation, deviceInfoExpectation] timeout:1];
}

#pragma mark - Get current account

- (void)testCurrentAccount_whenBrokerDisabled_shouldReturnCurrentLocalAccount API_AVAILABLE(ios(13.0), macos(10.15))
{
    [self msalStoreTokenResponseInCache];
    
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                                    error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
        
    XCTestExpectation *accountsExpectation = [self expectationWithDescription:@"Accounts from device"];
        
    [application getCurrentAccountWithParameters:nil
                                 completionBlock:^(MSALAccount * _Nullable account, MSALAccount * _Nullable previousAccount, NSError * _Nullable error) {
        
        XCTAssertNil(error);
        XCTAssertNil(previousAccount);
        XCTAssertNotNil(account);
        XCTAssertEqualObjects(account.identifier, @"myuid.utid");
        [accountsExpectation fulfill];
    }];
    
    [self waitForExpectations:@[accountsExpectation] timeout:1];
}

- (void)testCurrentAccount_whenBrokerDisabled_andMultipleAccounts_shouldReturnError API_AVAILABLE(ios(13.0), macos(10.15))
{
    [self msalStoreTokenResponseInCacheWithAuthority:@"https://login.microsoftonline.com/common"uid:@"myuid"
                                                utid:@"utid"];
    [self msalStoreTokenResponseInCacheWithAuthority:@"https://example.com/common"uid:@"myuid2"
                                                utid:@"utid2"];
    
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                                    error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
        
    XCTestExpectation *accountsExpectation = [self expectationWithDescription:@"Accounts from device"];
        
    [application getCurrentAccountWithParameters:nil
                                 completionBlock:^(MSALAccount * _Nullable account, MSALAccount * _Nullable previousAccount, NSError * _Nullable error) {
        
        XCTAssertNotNil(error);
        XCTAssertNil(previousAccount);
        XCTAssertNil(account);
        XCTAssertEqualObjects(error.domain, MSALErrorDomain);
        XCTAssertEqual(error.code, MSALErrorInternal);
        XCTAssertEqual([error.userInfo[MSALInternalErrorCodeKey] integerValue], MSALInternalErrorAmbiguousAccount);
        [accountsExpectation fulfill];
    }];
    
    [self waitForExpectations:@[accountsExpectation] timeout:1];
}

- (void)testCurrentAccount_whenBrokerEnabled_andSingleAccount_andNoPreviousAccount_shouldReturnCurrentAccount API_AVAILABLE(ios(13.0), macos(10.15))
{
    NSString *scheme = [NSString stringWithFormat:@"msauth.%@", [[NSBundle mainBundle] bundleIdentifier]];
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[scheme] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                                    error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityAuto;
    
    XCTAssertEqual([application allAccounts:nil].count, 0);
    
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetAccountsRequest class]
                           block:(id)^(id obj)
    {
        return YES;
    }];
      
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetAccountsRequest  class]
                              block:(id)^(id obj, MSIDGetAccountsRequestCompletionBlock callback)
    {
        [expectation fulfill];
        
        MSIDAccount *account2 = [MSIDAccount new];
        account2.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com" homeAccountId:@"uid.tid"];
        account2.environment = @"login.windows.net";
        
        callback(@[account2], YES, nil);
    }];
    
    XCTestExpectation *accountsExpectation = [self expectationWithDescription:@"Accounts from device"];
        
    [application getCurrentAccountWithParameters:nil
                                 completionBlock:^(MSALAccount * _Nullable account, MSALAccount * _Nullable previousAccount, NSError * _Nullable error) {
        
        XCTAssertNil(error);
        XCTAssertNil(previousAccount);
        XCTAssertNotNil(account);
        XCTAssertEqualObjects(account.identifier, @"uid.tid");
        [accountsExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation, accountsExpectation] timeout:1];
}

- (void)testCurrentAccount_whenBrokerEnabled_andSingleAccount_andPreviousAccount_shouldReturnCurrentAccount_andPreviousAccount API_AVAILABLE(ios(13.0), macos(10.15))
{
    [self msalStoreTokenResponseInCache];
    
    NSString *scheme = [NSString stringWithFormat:@"msauth.%@", [[NSBundle mainBundle] bundleIdentifier]];
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[scheme] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSArray *querySchemes = @[@"myotherscheme", @"msauthv2", @"msauthv3"];
    [MSIDTestBundle overrideObject:querySchemes forKey:@"LSApplicationQueriesSchemes"];
    
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                                    error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityAuto;
        
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetAccountsRequest class]
                           block:(id)^(id obj)
    {
        return YES;
    }];
      
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    expectation.expectedFulfillmentCount = 2;
    
    __block NSString *b_accountIdSuffix;
    
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetAccountsRequest  class]
                              block:(id)^(id obj, MSIDGetAccountsRequestCompletionBlock callback)
    {
        [expectation fulfill];
        
        MSIDAccount *account2 = [MSIDAccount new];
        NSString *homeAccountId = [NSString stringWithFormat:@"myuid.utid%@", b_accountIdSuffix ?: @""];
        account2.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"user@contoso.com" homeAccountId:homeAccountId];
        account2.environment = @"login.windows.net";
        account2.username = @"user@contoso.com";
        
        callback(@[account2], YES, nil);
    }];
    
    XCTestExpectation *accountsExpectation1 = [self expectationWithDescription:@"Accounts from device call 1"];
        
    [application getCurrentAccountWithParameters:nil
                                 completionBlock:^(MSALAccount * _Nullable account, MSALAccount * _Nullable previousAccount, NSError * _Nullable error) {
        
        XCTAssertNil(error);
        XCTAssertNil(previousAccount);
        XCTAssertNotNil(account);
        XCTAssertEqualObjects(account.identifier, @"myuid.utid");
        [accountsExpectation1 fulfill];
    }];
    
    [self waitForExpectations:@[accountsExpectation1] timeout:1];
    
    b_accountIdSuffix = @".second.account";
    
    XCTestExpectation *accountsExpectation2 = [self expectationWithDescription:@"Accounts from device call 2"];
    
    // Call second time
    [application getCurrentAccountWithParameters:nil
                                 completionBlock:^(MSALAccount * _Nullable account, MSALAccount * _Nullable previousAccount, NSError * _Nullable error) {
        
        XCTAssertNil(error);
        XCTAssertNotNil(previousAccount);
        XCTAssertNotNil(account);
        XCTAssertEqualObjects(account.identifier, @"myuid.utid.second.account");
        XCTAssertEqualObjects(previousAccount.identifier, @"myuid.utid");
        [accountsExpectation2 fulfill];
    }];
    
    [self waitForExpectations:@[expectation, accountsExpectation2] timeout:1];
}

#endif

#pragma mark - allAccountsFilteredByAuthority

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)testAllAccountsFilteredByAuthority_when2AccountExists_shouldReturnAccountsFilteredByAuthority
{
    [self msalStoreTokenResponseInCacheWithAuthority:@"https://login.microsoftonline.com/common" uid:@"myuid"
                                                utid:@"utid"];
    [self msalStoreTokenResponseInCacheWithAuthority:@"https://example.com/common" uid:@"myuid2"
                                                utid:@"utid2"];
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
         XCTAssertEqualObjects(account.homeAccountId.identifier, @"myuid.utid");
         XCTAssertEqualObjects(account.homeAccountId.objectId, @"myuid");
         XCTAssertEqualObjects(account.homeAccountId.tenantId, @"utid");
         
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllAccountsFilteredByAuthority_whenAccountWithAliasAuthorityExists_shouldReturnThatAccount
{
    [self msalStoreTokenResponseInCacheWithAuthority:@"https://login.windows.net/common" uid:@"myuid"
                                                utid:@"utid"];
    [self msalStoreTokenResponseInCacheWithAuthority:@"https://example.com/common" uid:@"myuid2"
                                                utid:@"utid2"];
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
         XCTAssertEqualObjects(account.homeAccountId.identifier, @"myuid.utid");
         XCTAssertEqualObjects(account.homeAccountId.objectId, @"myuid");
         XCTAssertEqualObjects(account.homeAccountId.tenantId, @"utid");
         
         [expectation fulfill];
     }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}
#pragma clang diagnostic pop

#pragma mark - loadAccountForHomeAccountId

- (void)testAccountWithHomeAccountId_whenAccountExists_shouldReturnAccountNoError
{
    [self msalStoreTokenResponseInCache];
    
    NSString *clientId = UNIT_TEST_CLIENT_ID;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId error:nil];
    application.tokenCache = self.tokenCacheAccessor;
    NSString *homeAccountId = @"myuid.utid";
    
    NSError *error;
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:homeAccountId];
    __auto_type accounts = [application accountsForParameters:parameters error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertEqual([accounts count], 1);
    MSALAccount *account = accounts[0];
    XCTAssertEqualObjects(account.username, @"fakeuser@contoso.com");
    XCTAssertEqualObjects(account.environment, @"login.microsoftonline.com");
    XCTAssertEqualObjects(account.homeAccountId.identifier, @"myuid.utid");
    XCTAssertEqualObjects(account.homeAccountId.objectId, @"myuid");
    XCTAssertEqualObjects(account.homeAccountId.tenantId, @"utid");
}

- (void)testAccountWithHomeAccountId_whenAccountExistsButNotMatching_shouldReturnNoAccountNoError
{
    [self msalStoreTokenResponseInCache];
    
    NSString *clientId = UNIT_TEST_CLIENT_ID;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId error:nil];
    application.tokenCache = self.tokenCacheAccessor;
    NSString *homeAccountId = @"other_uid.other_utid";
    
    NSError *error;
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:homeAccountId];
    __auto_type accounts = [application accountsForParameters:parameters error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual([accounts count], 0);
}

- (void)testAccountWithHomeAccountId_whenFociTokenExistsForOtherClient_andAppMetadataInCache_shouldReturnAccountNoError
{
    //store at & rt in cache with foci flag
    MSIDAADV2TokenResponse *msidResponse = [MSALTestCacheTokenResponse msalDefaultTokenResponseWithFamilyId:@"1"];
    MSIDConfiguration *configuration = [MSALTestCacheTokenResponse msalDefaultConfigurationWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSError *error = nil;
    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:configuration
                                                              response:msidResponse
                                                               factory:[MSIDAADV2Oauth2Factory new]
                                                               context:nil
                                                                 error:&error];
    XCTAssertTrue(result);
    XCTAssertEqual([[self.tokenCacheAccessor allTokensWithContext:nil error:nil] count], 4);
    
    NSString *clientId = @"myclient";
    
    MSIDAppMetadataCacheItem *appMetadata = [MSIDAppMetadataCacheItem new];
    appMetadata.clientId = clientId;
    appMetadata.environment = @"login.microsoftonline.com";
    appMetadata.familyId = @"1";

    [self.tokenCacheAccessor updateAppMetadataWithFamilyId:@"1" clientId:clientId authority:configuration.authority context:nil error:nil];

    // Retrieve cache for a different clientId
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"msalmyclient"] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSError *appError = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId error:&appError];
    XCTAssertNil(appError);
    application.tokenCache = self.tokenCacheAccessor;
    
    NSString *homeAccountId = @"myuid.utid";
    MSALAccountEnumerationParameters *parameters = [[MSALAccountEnumerationParameters alloc] initWithIdentifier:homeAccountId];
    __auto_type accounts = [application accountsForParameters:parameters error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(accounts);
    XCTAssertTrue([accounts count]);
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
    XCTAssertEqualObjects(account.homeAccountId.identifier, @"myuid.utid");
    XCTAssertEqualObjects(account.homeAccountId.objectId, @"myuid");
    XCTAssertEqualObjects(account.homeAccountId.tenantId, @"utid");
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

- (void)testAccountWithUsername_whenFociTokenExistsForOtherClient_andNoAppMetadataInCache_shouldReturnAccountNoError
{
    //store at & rt in cache with foci flag
    MSIDAADV2TokenResponse *msidResponse = [MSALTestCacheTokenResponse msalDefaultTokenResponseWithFamilyId:@"1"];
    MSIDConfiguration *configuration = [MSALTestCacheTokenResponse msalDefaultConfigurationWithAuthority:@"https://login.microsoftonline.com/common"];
    
    NSError *error = nil;
    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:configuration
                                                              response:msidResponse
                                                               factory:[MSIDAADV2Oauth2Factory new]
                                                               context:nil
                                                                 error:&error];
    XCTAssertTrue(result);
    XCTAssertEqual([[self.tokenCacheAccessor allTokensWithContext:nil error:nil] count], 4);
    
    // Retrieve cache for a different clientId
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"msalmyclient"] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSString *clientId = @"myclient";
    NSError *appError = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId error:&appError];
    XCTAssertNil(appError);
    application.tokenCache = self.tokenCacheAccessor;
    
    __auto_type account = [application accountForUsername:@"fakeuser@contoso.com" error:&error];
    
    XCTAssertNil(error);
    XCTAssertNotNil(account);
}

- (void)testFetchAccountWithEmptyUsername_shouldReturnError
{
    [self msalStoreTokenResponseInCache];
    
    NSString *clientId = UNIT_TEST_CLIENT_ID;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId error:nil];
    application.tokenCache = self.tokenCacheAccessor;
    
    NSError *error;
    __auto_type account = [application accountForUsername:@"" error:&error];
    XCTAssertNotNil(error);
    XCTAssertNil(account);
}

- (void)testFetchAccountWithNilUsername_shouldReturnError
{
    [self msalStoreTokenResponseInCache];
    
    NSString *clientId = UNIT_TEST_CLIENT_ID;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId error:nil];
    application.tokenCache = self.tokenCacheAccessor;
    
    NSString *username = nil;
    
    NSError *error;
    __auto_type account = [application accountForUsername:username error:&error];
    XCTAssertNotNil(error);
    XCTAssertNil(account);
}

- (void)testFetchAccountWithNilUsernameAndNilErrorPointer_shouldNotCrash
{
    [self msalStoreTokenResponseInCache];
    
    NSString *clientId = UNIT_TEST_CLIENT_ID;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:clientId error:nil];
    application.tokenCache = self.tokenCacheAccessor;
    
    NSString *username = nil;
    
    __auto_type account = [application accountForUsername:username error:nil];
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
    MSALAccount *msalAccount = [[MSALAccount alloc] initWithMSIDAccount:account createTenantProfile:NO];
    
    XCTAssertEqualObjects([application allAccounts:nil][0], msalAccount);
    
    NSError *error;
    BOOL result = [application removeAccount:msalAccount error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    // Make sure the user is now gone
    XCTAssertEqual([application allAccounts:nil].count, 0);
    
    // Account metadata should mark account as signed out
    MSIDAccountMetadataState signInState = [self.accountMetadataCache signInStateForHomeAccountId:@"myuid.utid" clientId:UNIT_TEST_CLIENT_ID context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertEqual(signInState, MSIDAccountMetadataStateSignedOut);
}

- (void)testRemoveAccount_whenAccountExists_andIsFociClient_shouldRemoveAccount_andMarkClientNonFoci
{
    // 1. Save response for a different clientId
    NSString *authorityUrl = @"https://login.microsoftonline.com/utid";
    
    MSIDAADV2TokenResponse *msidResponse = [MSALTestCacheTokenResponse msalDefaultTokenResponseWithFamilyId:@"1"];
    MSIDConfiguration *configuration = [MSALTestCacheTokenResponse msalDefaultConfigurationWithAuthority:authorityUrl];

    BOOL result = [self.tokenCacheAccessor saveTokensWithConfiguration:configuration
                                                              response:msidResponse
                                                               factory:[MSIDAADV2Oauth2Factory new]
                                                               context:nil
                                                                 error:nil];

    XCTAssertTrue(result);
    XCTAssertEqual([[self.tokenCacheAccessor allTokensWithContext:nil error:nil] count], 4);

    // 2. Create PublicClientApplication for a different app
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"msalmyclient"] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];

    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:@"myclient" error:nil];
    application.tokenCache = self.tokenCacheAccessor;
    [self.tokenCacheAccessor updateAppMetadataWithFamilyId:@"1" clientId:@"myclient" authority:configuration.authority context:nil error:nil];

    MSIDAuthority *authority = [authorityUrl aadAuthority];

    configuration = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                     redirectUri:UNIT_TEST_DEFAULT_REDIRECT_URI
                                                        clientId:@"myclient"
                                                          target:@"fakescope1 fakescope2"];

    MSIDAccount *account = [[MSIDAADV2Oauth2Factory new] accountFromResponse:msidResponse
                                                               configuration:configuration];
    MSALAccount *msalAccount = [[MSALAccount alloc] initWithMSIDAccount:account createTenantProfile:NO];

    XCTAssertEqualObjects([application allAccounts:nil][0], msalAccount);

    // 3. Remove account
    NSError *error = nil;
    result = [application removeAccount:msalAccount error:&error];

    XCTAssertTrue(result);
    XCTAssertNil(error);

    // 4. Make sure the account is now gone
    XCTAssertEqual([application allAccounts:nil].count, 0);

    // 5. Make sure account and FOCI tokens are still in cache
    MSIDAccount *cachedAccount = [self.tokenCacheAccessor getAccountForIdentifier:account.accountIdentifier authority:authority realmHint:nil context:nil error:nil];
    XCTAssertNotNil(cachedAccount);

    MSIDRefreshToken *fociToken = [self.tokenCacheAccessor getRefreshTokenWithAccount:account.accountIdentifier familyId:@"1" configuration:configuration context:nil error:nil];
    XCTAssertNotNil(fociToken);

    MSIDRefreshToken *mrrtToken = [self.tokenCacheAccessor getRefreshTokenWithAccount:account.accountIdentifier familyId:nil configuration:configuration context:nil error:nil];
    XCTAssertNil(mrrtToken);

    [self msalAddDiscoveryResponse:authorityUrl appendDefaultHeaders:YES];

    // 5. Try to acquire token silently, expecting to get interaction required back
    // That means FOCI wasn't used by the app although present
    XCTestExpectation *expectation = [self expectationWithDescription:@"Acquire token silent"];

    [application acquireTokenSilentForScopes:@[@"fakescope1"]
                                     account:msalAccount
                             completionBlock:^(MSALResult * _Nullable result, NSError * _Nullable error) {


                                 XCTAssertNil(result);
                                 XCTAssertNotNil(error);
                                 XCTAssertEqual(error.code, MSALErrorInteractionRequired);
                                 [expectation fulfill];
                             }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#endif

#if TARGET_OS_IPHONE

- (void)testRemove_whenUserDontExist_shouldReturnTrueWithNoError
{
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID error:nil];
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"1.1234-5678-90abcdefg" objectId:@"1" tenantId:@"1234-5678-90abcdefg"];
    
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:@"user@contoso.com"
                                                   homeAccountId:accountId
                                                     environment:@"login.microsoftonline.com"
                                                  tenantProfiles:nil];
    
    NSError *error;
    BOOL result = [application removeAccount:account error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

#endif

- (void)testRemoveUser_whenKeychainError_shouldReturnNoWithError
{
    __auto_type application = [[MSALPublicClientApplication alloc] initWithClientId:UNIT_TEST_CLIENT_ID error:nil];
    
    MSALAccountId *accountId = [[MSALAccountId alloc] initWithAccountIdentifier:@"uid.utid" objectId:@"uid" tenantId:@"utid"];
    MSALAccount *account = [[MSALAccount alloc] initWithUsername:nil homeAccountId:accountId environment:@"contoso.com" tenantProfiles:nil];
    
    [MSIDTestSwizzle instanceMethod:@selector(clearCacheForAccount:authority:clientId:familyId:clearAccounts:context:error:)
                              class:[MSIDDefaultTokenCacheAccessor class]
                              block:(id)^(id obj, id account, MSIDAuthority *authority, NSString *clientId, NSString *familyId, BOOL clearAccounts, id<MSIDRequestContext> ctx, NSError **error)
     {
         (void)authority;
         (void)account;
         (void)clientId;
         
         *error = MSIDCreateError(NSOSStatusErrorDomain, -34018, nil, nil, nil, nil, nil, nil, YES);
         
         return NO;
     }];
    
    NSError *error;
    BOOL result = [application removeAccount:account error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, NSOSStatusErrorDomain);
}

#pragma mark - Signout

- (void)testSignoutWithAccount_whenNilAccount_shouldReturnError
{
    MSALAccount *account = nil;
    
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
#if TARGET_OS_IPHONE
    MSALWebviewParameters *webParams = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:[self.class sharedViewControllerStub]];
#else
    MSALWebviewParameters *webParams = [MSALWebviewParameters new];
#endif
    MSALSignoutParameters *parameters = [[MSALSignoutParameters alloc] initWithWebviewParameters:webParams];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Signout"];
    
    [application signoutWithAccount:account
                  signoutParameters:parameters completionBlock:^(BOOL success, NSError * _Nullable error) {
        
        XCTAssertFalse(success);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSALErrorDomain);
        XCTAssertEqual(error.code, MSALErrorInternal);
        XCTAssertEqual([error.userInfo[MSALInternalErrorCodeKey] integerValue], MSALInternalErrorInvalidParameter);
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

#if TARGET_OS_IPHONE

- (void)testSignoutWithAccount_whenNonNilaccount_andSignoutFromBrowserFalse_andBrokerDisabled_shouldRemoveAccountLocallyOnly
{
    [self msalStoreTokenResponseInCache];
    
    MSIDAccount *account = [[MSIDAADV2Oauth2Factory new] accountFromResponse:[self msalDefaultTokenResponse]
                                                               configuration:[self msalDefaultConfiguration]];
    MSALAccount *msalAccount = [[MSALAccount alloc] initWithMSIDAccount:account createTenantProfile:NO];
        
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                                    error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    MSALWebviewParameters *webParams = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:[self.class sharedViewControllerStub]];
    MSALSignoutParameters *parameters = [[MSALSignoutParameters alloc] initWithWebviewParameters:webParams];
    parameters.signoutFromBrowser = NO;
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    XCTAssertEqual([application allAccounts:nil].count, 1);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Signout"];
    
    [application signoutWithAccount:msalAccount
                  signoutParameters:parameters completionBlock:^(BOOL success, NSError * _Nullable error) {
        
        XCTAssertTrue(success);
        XCTAssertNil(error);

        XCTAssertEqual([application allAccounts:nil].count, 0);
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testSignoutWithAccount_whenSignoutFromBrowserFalse_andNilWebViewParameters_shouldremoveAccount
{
    [self msalStoreTokenResponseInCache];
    
    MSIDAccount *account = [[MSIDAADV2Oauth2Factory new] accountFromResponse:[self msalDefaultTokenResponse]
                                                               configuration:[self msalDefaultConfiguration]];
    MSALAccount *msalAccount = [[MSALAccount alloc] initWithMSIDAccount:account createTenantProfile:NO];
        
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                                    error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    MSALSignoutParameters *parameters = [MSALSignoutParameters new];
    parameters.signoutFromBrowser = NO;
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    XCTAssertEqual([application allAccounts:nil].count, 1);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Signout"];
    
    [application signoutWithAccount:msalAccount
                  signoutParameters:parameters completionBlock:^(BOOL success, NSError * _Nullable error) {
        
        XCTAssertTrue(success);
        XCTAssertNil(error);

        XCTAssertEqual([application allAccounts:nil].count, 0);
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testSignoutWithAccount_whenSignoutFromBrowserTrue_andNilWebViewParameters_shouldFailWithError_andNotRemoveAccount
{
    [self msalStoreTokenResponseInCache];
    
    MSIDAccount *account = [[MSIDAADV2Oauth2Factory new] accountFromResponse:[self msalDefaultTokenResponse]
                                                               configuration:[self msalDefaultConfiguration]];
    MSALAccount *msalAccount = [[MSALAccount alloc] initWithMSIDAccount:account createTenantProfile:NO];
        
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                                    error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    MSALSignoutParameters *parameters = [MSALSignoutParameters new];
    parameters.signoutFromBrowser = YES;
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    XCTAssertEqual([application allAccounts:nil].count, 1);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Signout"];
    
    [application signoutWithAccount:msalAccount
                  signoutParameters:parameters completionBlock:^(BOOL success, NSError * _Nullable error) {
        
        XCTAssertFalse(success);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, MSALErrorInternal);
        XCTAssertEqual([error.userInfo[MSALInternalErrorCodeKey] integerValue], MSALInternalErrorInvalidParameter);

        XCTAssertEqual([application allAccounts:nil].count, 1);
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testSignoutWithAccount_whenNonNilAccount_andSignoutFromBrowserTrue_andBrokerDisabled_shouldRemoveAccountFromBrowser
{
    [self msalStoreTokenResponseInCache];
    [self msalStoreSecondAppTokenResponseInCache];
    
    MSIDAccount *account = [[MSIDAADV2Oauth2Factory new] accountFromResponse:[self msalDefaultTokenResponse]
                                                               configuration:[self msalDefaultConfiguration]];
    MSALAccount *msalAccount = [[MSALAccount alloc] initWithMSIDAccount:account createTenantProfile:NO];
        
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                                    error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    MSALPublicClientApplication *secondApplication = [self createSecondTestAppWithAuthority:authority];
    XCTAssertNotNil(secondApplication);
    
    MSALWebviewParameters *webParams = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:[self.class sharedViewControllerStub]];
    MSALSignoutParameters *parameters = [[MSALSignoutParameters alloc] initWithWebviewParameters:webParams];
    parameters.signoutFromBrowser = YES;
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    XCTAssertEqual([application allAccounts:nil].count, 1);
    XCTAssertEqual([secondApplication allAccounts:nil].count, 1);
    
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                             class:[MSIDSignoutController class]
                             block:(id)^(MSIDSignoutController *obj, MSIDSignoutRequestCompletionBlock completionBlock)
    {
        XCTAssertTrue([obj isKindOfClass:[MSIDSignoutController class]]);
        
        MSIDInteractiveRequestParameters *params = [obj parameters];
        XCTAssertNotNil(params);
        
        XCTAssertEqualObjects(params.accountIdentifier.displayableId, @"fakeuser@contoso.com");
        XCTAssertEqualObjects(params.accountIdentifier.homeAccountId, @"myuid.utid");
        
        XCTAssertEqualObjects(params.authority.url.absoluteString, @"https://login.microsoftonline.com/common");
        XCTAssertEqualObjects(params.clientId, UNIT_TEST_CLIENT_ID);
        
        XCTAssertNotNil(params.correlationId);
        
        completionBlock(YES, nil);
    }];
    
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Signout"];
    
    [application signoutWithAccount:msalAccount
                  signoutParameters:parameters completionBlock:^(BOOL success, NSError * _Nullable error) {
        
        XCTAssertTrue(success);
        XCTAssertNil(error);

        XCTAssertEqual([application allAccounts:nil].count, 0);
        XCTAssertEqual([secondApplication allAccounts:nil].count, 1);
        
        MSALAccountEnumerationParameters *accountEnumerationOptions = [MSALAccountEnumerationParameters new];
        accountEnumerationOptions.returnOnlySignedInAccounts = NO;
        
        NSArray *firstAppSignedOutAccounts = [application accountsForParameters:accountEnumerationOptions error:nil];
        XCTAssertEqual([firstAppSignedOutAccounts count], 1);
        
        NSArray *secondAppSignedOutAccounts = [application accountsForParameters:accountEnumerationOptions error:nil];
        XCTAssertEqual([secondAppSignedOutAccounts count], 1);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testSignoutWithAccount_whenNonNilAccount_andWipeAccountTrue_andBrokerDisabled_shouldWipeAccount
{
    // Save default response
    [self msalStoreTokenResponseInCache];
    
    // Save tokens for the same account for a different client
    [self msalStoreSecondAppTokenResponseInCache];
    
    MSIDAccount *account = [[MSIDAADV2Oauth2Factory new] accountFromResponse:[self msalDefaultTokenResponse]
                                                               configuration:[self msalDefaultConfiguration]];
    MSALAccount *msalAccount = [[MSALAccount alloc] initWithMSIDAccount:account createTenantProfile:NO];
        
    NSError *error = nil;
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                                    error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    MSALPublicClientApplication *secondApplication = [self createSecondTestAppWithAuthority:authority];
    XCTAssertNotNil(secondApplication);
    
    MSALWebviewParameters *webParams = [[MSALWebviewParameters alloc] initWithAuthPresentationViewController:[self.class sharedViewControllerStub]];
    MSALSignoutParameters *parameters = [[MSALSignoutParameters alloc] initWithWebviewParameters:webParams];
    parameters.wipeAccount = YES;
    MSALGlobalConfig.brokerAvailability = MSALBrokeredAvailabilityNone;
    
    XCTAssertEqual([application allAccounts:nil].count, 1);
    XCTAssertEqual([secondApplication allAccounts:nil].count, 1);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Signout"];
    
    [application signoutWithAccount:msalAccount
                  signoutParameters:parameters completionBlock:^(BOOL success, NSError * _Nullable error) {
        
        XCTAssertTrue(success);
        XCTAssertNil(error);

        XCTAssertEqual([application allAccounts:nil].count, 0);
        XCTAssertEqual([secondApplication allAccounts:nil].count, 0);
        
        MSALAccountEnumerationParameters *accountEnumerationOptions = [MSALAccountEnumerationParameters new];
        accountEnumerationOptions.returnOnlySignedInAccounts = NO;
        
        NSArray *firstAppSignedOutAccounts = [application accountsForParameters:accountEnumerationOptions error:nil];
        XCTAssertEqual([firstAppSignedOutAccounts count], 0);
        
        NSArray *secondAppSignedOutAccounts = [application accountsForParameters:accountEnumerationOptions error:nil];
        XCTAssertEqual([secondAppSignedOutAccounts count], 0);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

#endif

- (void)testInitWithConfiguration_WhenBypassRedirectURIIsDefault_ShouldBlockInvalidURI
{
    MSALPublicClientApplicationConfig *pcaConfig = [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"test_client_id"
                                                                                                   redirectUri:@"invalid_uri"
                                                                                                     authority:nil];
    NSError *error;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:pcaConfig error:&error];
    XCTAssertTrue(error);
    XCTAssertNil(application);
}

- (void)testInitWithConfiguration_WhenBypassRedirectURIIsDYes_ShouldAllowInvalidURI
{
    MSALPublicClientApplicationConfig *pcaConfig = [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"test_client_id"
                                                                                                   redirectUri:@"invalid_uri"
                                                                                                     authority:nil];
    pcaConfig.bypassRedirectURIValidation = YES;
    NSError *error;
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithConfiguration:pcaConfig error:&error];
    XCTAssertTrue(application);
    XCTAssertNil(error);
}

#pragma mark - Broker Availability

- (void)testIsCompatibleAADBrokerAvailable_whenUniversalLinkRedirectUri_andOldBrokerPresent_shouldReturnNo
{
#if TARGET_OS_IPHONE
    MSIDApplicationTestUtil.canOpenURLSchemes = @[@"msauthv2"];
    
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:@"https://abc.com"
                                                                                                  authority:authority];
    
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    XCTAssertFalse([application isCompatibleAADBrokerAvailable]);
#endif
}

- (void)testIsCompatibleAADBrokerAvailable_whenUniversalLinkRedirectUri_andNewBrokerPresent_shouldReturnNo
{
#if TARGET_OS_IPHONE
    MSIDApplicationTestUtil.canOpenURLSchemes = @[@"msauthv2", @"msauthv3"];
    
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:@"https://abc.com"
                                                                                                  authority:authority];
    
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    XCTAssertTrue([application isCompatibleAADBrokerAvailable]);
#endif
}

- (void)testIsCompatibleAADBrokerAvailable_whenMacOS_shouldReturnNo
{
#if !TARGET_OS_IPHONE
    __auto_type authority = [@"https://login.microsoftonline.com/common" msalAuthority];
    
    MSALPublicClientApplicationConfig *config = [[MSALPublicClientApplicationConfig alloc] initWithClientId:UNIT_TEST_CLIENT_ID
                                                                                                redirectUri:nil
                                                                                                  authority:authority];
    
    NSError *error = nil;
    __auto_type application = [[MSALPublicClientApplication alloc] initWithConfiguration:config
                                                                                   error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    XCTAssertFalse([application isCompatibleAADBrokerAvailable]);
#endif
}

#pragma mark - Broker Availability

#pragma mark - Helpers

- (MSALPublicClientApplication *)createSecondTestAppWithAuthority:(MSALAuthority *)authority
{
    NSArray *override = @[ @{ @"CFBundleURLSchemes" : @[@"msauth.com.microsoft.unit-test-host"] } ];
    [MSIDTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    NSArray *schemes = @[@"msauthv2", @"msauthv3"];
    [MSIDTestBundle overrideObject:schemes forKey:@"LSApplicationQueriesSchemes"];
    
    MSALPublicClientApplicationConfig *secondAppConfig = [[MSALPublicClientApplicationConfig alloc] initWithClientId:@"second_clientId"
                                                                                                         redirectUri:nil
                                                                                                           authority:authority];
    
    NSError *error = nil;
    MSALPublicClientApplication *secondApplication = [[MSALPublicClientApplication alloc] initWithConfiguration:secondAppConfig error:&error];
    
    XCTAssertNotNil(secondApplication);
    XCTAssertNil(error);
    
    return secondApplication;
}

- (void)msalStoreTokenResponseInCacheWithAuthority:(NSString *)authorityString
                                               uid:(NSString *)uid
                                              utid:(NSString *)utid
{
    NSError *error = nil;
    BOOL result = [MSALTestCacheTokenResponse msalStoreTokenResponseInCacheWithAuthority:authorityString
                                                                                     uid:uid
                                                                                    utid:utid
                                                                      tokenCacheAccessor:self.tokenCacheAccessor
                                                                                   error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)msalStoreTokenResponseInCache
{
    [self msalStoreTokenResponseInCacheWithAuthority:@"https://login.microsoftonline.com/common" uid:@"myuid" utid:@"utid"];
}

- (void)msalStoreSecondAppTokenResponseInCache
{
    // Save tokens for the same account for a different client
    MSIDAADV2TokenResponse *msidResponse = [MSALTestCacheTokenResponse msalDefaultTokenResponseWithFamilyId:nil];
    MSIDConfiguration *configuration = [MSALTestCacheTokenResponse msalDefaultConfigurationWithAuthority:@"https://login.microsoftonline.com/common"];
    configuration.clientId = @"second_clientId";
    
    [self.tokenCacheAccessor saveTokensWithConfiguration:configuration
                                                response:msidResponse
                                                 factory:[MSIDAADV2Oauth2Factory new]
                                                 context:nil
                                                   error:nil];
}

- (void)msalAddDiscoveryResponse
{
    [self msalAddDiscoveryResponse:@"https://login.microsoftonline.com/common" appendDefaultHeaders:NO];
}

- (void)msalAddDiscoveryResponse:(NSString *)authority appendDefaultHeaders:(BOOL)appendDefaultHeaders
{
    __auto_type httpResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL new] statusCode:200 HTTPVersion:nil headerFields:nil];
    __auto_type requestUrlString = [NSString stringWithFormat:@"https://login.microsoftonline.com/common/discovery/instance?api-version=1.1&authorization_endpoint=%@%%2Foauth2%%2Fv2.0%%2Fauthorize", authority.msidWWWFormURLEncode];
    __auto_type requestUrl = [requestUrlString msidUrl];
    MSIDTestURLResponse *response = [MSIDTestURLResponse request:requestUrl
                                                         reponse:httpResponse];
    NSMutableDictionary *headers = [[MSIDDeviceId deviceId] mutableCopy];
    
    if (appendDefaultHeaders)
    {
        [headers addEntriesFromDictionary:[MSIDTestURLResponse msidDefaultRequestHeaders]];
    }
    
    headers[@"Accept"] = @"application/json";
    headers[@"x-ms-PkeyAuth"] = @"1.0";
    response->_requestHeaders = headers;
    
    NSString *endpoint = [NSString stringWithFormat:@"%@/v2.0/.well-known/openid-configuration", authority];
    
    __auto_type responseJson = @{
                                 @"tenant_discovery_endpoint" : endpoint,
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
    return [MSALTestCacheTokenResponse msalDefaultTokenResponseWithFamilyId:nil];
}

- (MSIDConfiguration *)msalDefaultConfiguration
{
    MSIDAuthority *authority = [@"https://login.microsoftonline.com/common" aadAuthority];
    
    return [[MSIDConfiguration alloc] initWithAuthority:authority
                                            redirectUri:UNIT_TEST_DEFAULT_REDIRECT_URI
                                               clientId:UNIT_TEST_CLIENT_ID
                                                 target:@"fakescope1 fakescope2"];
}

@end

#pragma clang diagnostic pop
