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


#import <XCTest/XCTest.h>
#import "MSALAuthenticationSchemePop.h"
#import "MSALAuthenticationSchemeBearer.h"
#import "MSALAuthenticationSchemeProtocol.h"
#import "MSALDefinitions.h"
#import "MSIDAccessToken.h"
#import "MSIDDevicePopManager.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAccessTokenWithAuthScheme.h"
#import "MSIDAuthenticationScheme.h"
#import "MSALAuthenticationSchemeBearer.h"
#import "MSIDAuthenticationSchemePop.h"
#import "MSIDOAuth2Constants.h"
#import "MSIDDevicePopManager.h"
#import "MSIDCacheConfig.h"
#import "MSIDAssymetricKeyKeychainGenerator.h"
#import "MSIDAssymetricKeyLookupAttributes.h"
#import "MSIDAssymetricKeyPair.h"
#if !TARGET_OS_IPHONE
#import "MSIDAssymetricKeyLoginKeychainGenerator.h"
#endif
#import "MSIDConstants.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDMacKeychainTokenCache.h"
#import "MSALDevicePopManagerUtil.h"

@interface MSALAuthSchemeTests : XCTestCase

@end

@implementation MSALAuthSchemeTests

- (void)testBearerInit_shouldReturnAuthBearer_AndAllBearerAttributes
{
    MSALAuthenticationSchemeBearer *authScheme = [MSALAuthenticationSchemeBearer new];
    XCTAssertEqual(authScheme.scheme, MSALAuthSchemeBearer);
    XCTAssertTrue([authScheme.authenticationScheme isEqualToString:@"Bearer"]);
    
    MSIDAccessToken *msidAccessToken = [self populateBearerMSIDAccessToken];
    NSString *bearerAccessToken = [authScheme getClientAccessToken:msidAccessToken popManager:nil error:nil];
    XCTAssertEqual(bearerAccessToken, msidAccessToken.accessToken);
    
    NSString *expectAuthorHeader = @"Bearer token";
    XCTAssertTrue([[authScheme getAuthorizationHeader:bearerAccessToken] isEqualToString:expectAuthorHeader]);
    
    MSIDDevicePopManager *deviceManager = [MSIDDevicePopManager new];
    XCTAssertEqual([[authScheme getSchemeParameters:deviceManager] count], 0);
}

- (void)testInitWithPopParam_shouldReturnAuthPop
{
    
    MSALAuthenticationSchemePop *authScheme = [self generateAuthSchemePopInstance];
    XCTAssertEqual(authScheme.scheme, MSALAuthSchemePop);
    XCTAssertTrue([authScheme.authenticationScheme isEqualToString:@"Pop"]);
    
    MSIDAccessTokenWithAuthScheme *msidAccessToken = [self populatePopMSIDAccessToken];
    
    NSString *expectAuthorHeader = @"Pop token\0";
    XCTAssertFalse([[authScheme getAuthorizationHeader:msidAccessToken.accessToken] isEqualToString:expectAuthorHeader]);
}

- (void)test_CreateMSIDAuthSchemeWithCorrectParams_fromBearer_shouldReturnBearerScheme
{
    MSALAuthenticationSchemeBearer *authScheme = [MSALAuthenticationSchemeBearer new];

    MSIDAuthenticationScheme *msidAuthScheme = [authScheme createMSIDAuthenticationSchemeWithParams:[NSDictionary new]];
    XCTAssertTrue([msidAuthScheme isMemberOfClass:MSIDAuthenticationScheme.class]);
}

- (void)test_CreateMSIDAuthSchemeWithCorrectParams_fromPop_shouldReturnPopScheme
{
    MSALAuthenticationSchemePop *authScheme = [self generateAuthSchemePopInstance];
    MSIDAuthenticationScheme *msidAuthScheme = [authScheme createMSIDAuthenticationSchemeWithParams:[self preparePopSchemeParameter]];
    
    XCTAssertNotNil(msidAuthScheme);
    XCTAssertTrue([msidAuthScheme isMemberOfClass:MSIDAuthenticationSchemePop.class]);
}

- (void)test_CreateMSIDAuthSchemeWithIncorrectParams_fromPop_shouldReturnNil
{
    MSALAuthenticationSchemePop *authScheme = [self generateAuthSchemePopInstance];
    
    NSMutableDictionary *params = [NSMutableDictionary new];
    [params setObject:@"Pop1" forKey:MSID_OAUTH2_TOKEN_TYPE];
    [params setObject:@"eyJraWQiOiJYaU1hYWdoSXdCWXQwLWU2RUFydWxuaWtLbExVdVlrcXVHRk05YmE5RDF3In0" forKey:MSID_OAUTH2_REQUEST_CONFIRMATION];
    
    MSIDAuthenticationScheme *msidAuthScheme = [authScheme createMSIDAuthenticationSchemeWithParams:params];
    XCTAssertNil(msidAuthScheme);
}

- (void)test_getAccessToken_fromPopAuthScheme_InvalidAuthInput_shouldReturnNilStringAndError
{
    MSALAuthenticationSchemePop *authScheme = [self generateAuthSchemePopInstance];
    [authScheme setValue:nil forKey:@"requestUrl"];
    MSIDDevicePopManager *devicePopManager = [MSALDevicePopManagerUtil test_initWithValidCacheConfig];
    MSIDAccessTokenWithAuthScheme *msidAccessToken = [self populatePopMSIDAccessToken];
    NSError *error;
    // get signed access token for client
    NSString *signedAccessToken = [authScheme getClientAccessToken:msidAccessToken popManager:devicePopManager error:&error];
    XCTAssertTrue([NSString msidIsStringNilOrBlank:signedAccessToken]);
    XCTAssertNotNil(error);
}

- (void)test_getAccessToken_fromPopAuthScheme_InvalidDeviceManager_shouldReturnNilStringAndError
{
    MSALAuthenticationSchemePop *authScheme = [self generateAuthSchemePopInstance];
    [authScheme setValue:nil forKey:@"requestUrl"];
    MSIDDevicePopManager *devicePopManager = nil;
    MSIDAccessTokenWithAuthScheme *msidAccessToken = [self populatePopMSIDAccessToken];
    NSError *error;
    // get signed access token for client
    NSString *signedAccessToken = [authScheme getClientAccessToken:msidAccessToken popManager:devicePopManager error:&error];
    XCTAssertTrue([NSString msidIsStringNilOrBlank:signedAccessToken]);
    XCTAssertNotNil(error);
}

- (void)test_getAccessToken_fromPopAuthScheme_InvalidAccessToken_shouldReturnNilStringAndError
{
    MSALAuthenticationSchemePop *authScheme = [self generateAuthSchemePopInstance];
    [authScheme setValue:nil forKey:@"requestUrl"];
    MSIDDevicePopManager *devicePopManager = nil;
    MSIDAccessTokenWithAuthScheme *msidAccessToken = nil;
    NSError *error;
    // get signed access token for client
    NSString *signedAccessToken = [authScheme getClientAccessToken:msidAccessToken popManager:devicePopManager error:&error];
    XCTAssertTrue([NSString msidIsStringNilOrBlank:signedAccessToken]);
    XCTAssertNotNil(error);
}

- (void)test_getAccessToken_fromBearerAuthScheme_ValidInput_shouldReturnAT
{
    MSALAuthenticationSchemeBearer *authScheme = [MSALAuthenticationSchemeBearer new];
    MSIDDevicePopManager *devicePopManager = [MSALDevicePopManagerUtil test_initWithValidCacheConfig];
    MSIDAccessToken *msidAccessToken = [self populateBearerMSIDAccessToken];
    NSError *error;
    // get signed access token for client
    NSString *signedAccessToken = [authScheme getClientAccessToken:msidAccessToken popManager:devicePopManager error:&error];
    XCTAssertFalse([NSString msidIsStringNilOrBlank:signedAccessToken]);
    XCTAssertTrue([signedAccessToken isEqualToString:msidAccessToken.accessToken]);
}

- (MSALAuthenticationSchemePop *) generateAuthSchemePopInstance
{
    MSALAuthenticationSchemePop *authScheme;
    NSURL *requestUrl = [NSURL URLWithString:@"https://signedhttprequest.azurewebsites.net/api/validateSHR"];
    authScheme = [[MSALAuthenticationSchemePop alloc] initWithHttpMethod:MSALHttpMethodPOST requestUrl:requestUrl nonce:nil additionalParameters:nil];
    return authScheme;
}

- (NSDictionary *) preparePopSchemeParameter
{
    NSMutableDictionary *params = [NSMutableDictionary new];
    [params setObject:@"Pop" forKey:MSID_OAUTH2_TOKEN_TYPE];
    [params setObject:@"eyJraWQiOiJYaU1hYWdoSXdCWXQwLWU2RUFydWxuaWtLbExVdVlrcXVHRk05YmE5RDF3In0" forKey:MSID_OAUTH2_REQUEST_CONFIRMATION];
    return params;
}

- (MSIDAccessToken *)populateBearerMSIDAccessToken
{
    MSIDAccessToken *token = [MSIDAccessToken new];
    token.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy_id" homeAccountId:@"uid.utid"];
    token.environment = @"contoso.com";
    token.realm = @"common";
    token.clientId = @"clientId";
    token.additionalServerInfo = @{@"spe_info" : @"value2"};
    token.expiresOn = [NSDate dateWithTimeIntervalSince1970:1500000000];
    token.cachedAt = [NSDate dateWithTimeIntervalSince1970:1500000000];
    token.accessToken = @"token";
    token.resource = @"target";
    token.enrollmentId = @"enrollmentId";
    
    return token;
}

- (MSIDAccessTokenWithAuthScheme *)populatePopMSIDAccessToken
{
    MSIDAccessTokenWithAuthScheme *token = [MSIDAccessTokenWithAuthScheme new];
    token.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"legacy_id" homeAccountId:@"uid.utid"];
    token.environment = @"contoso.com";
    token.realm = @"common";
    token.clientId = @"clientId";
    token.additionalServerInfo = @{@"spe_info" : @"value2"};
    token.expiresOn = [NSDate dateWithTimeIntervalSince1970:1500000000];
    token.cachedAt = [NSDate dateWithTimeIntervalSince1970:1500000000];
    token.accessToken = @"token";
    token.resource = @"target";
    token.enrollmentId = @"enrollmentId";
    return token;
}

@end
