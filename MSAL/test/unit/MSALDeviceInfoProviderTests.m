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
#import "MSALDeviceInfoProvider.h"
#import "MSIDTestSwizzle.h"
#import "MSIDSSOExtensionGetDeviceInfoRequest.h"
#import "MSIDTestParametersProvider.h"
#import "MSIDDeviceInfo.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDRequestParameters.h"
#import "MSALDeviceInformation.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSALWPJMetaData+Internal.h"
#import "MSALDeviceTokenParameters.h"
#import "MSIDDeviceTokenGrantRequest.h"
#import "MSIDNonceTokenRequest.h"
#import "MSIDWPJKeyPairWithCert.h"
#import "MSIDTokenResult.h"
#import "NSData+MSIDExtensions.h"

#pragma mark - Test doubles for device token flow

@interface MSALFakeNonceTokenRequest : MSIDNonceTokenRequest

@property (nonatomic) NSString *nonceToReturn;
@property (nonatomic) NSError *errorToReturn;

@end

@implementation MSALFakeNonceTokenRequest

- (void)executeRequestWithCompletion:(MSIDNonceRequestCompletion)completionBlock
{
    completionBlock(self.nonceToReturn, self.errorToReturn);
}

@end

@interface MSALFakeDeviceTokenGrantRequest : MSIDDeviceTokenGrantRequest

@property (nonatomic) MSIDTokenResult *tokenResultToReturn;
@property (nonatomic) NSError *errorToReturn;
@property (nonatomic) NSString *capturedNonce;
@property (nonatomic) XCTestExpectation *executeExpectation;

@end

@implementation MSALFakeDeviceTokenGrantRequest

- (void)executeRequestWithCompletion:(MSIDRequestCompletionBlock)completionBlock
{
    self.capturedNonce = self.nonce;
    [self.executeExpectation fulfill];
    completionBlock(self.tokenResultToReturn, self.errorToReturn);
}

@end

@interface MSALTestDeviceInfoProvider : MSALDeviceInfoProvider

@property (nonatomic) MSIDWPJKeyPairWithCert *wpjKeyPairStub;

@property (nonatomic) NSString *nonceStub;
@property (nonatomic) NSError *nonceErrorStub;

@property (nonatomic) MSIDTokenResult *deviceTokenResultStub;
@property (nonatomic) NSError *deviceTokenErrorStub;
@property (nonatomic) XCTestExpectation *deviceTokenExecuteExpectation;
@property (nonatomic) MSALFakeDeviceTokenGrantRequest *builtDeviceTokenGrantRequest;

@end

@implementation MSALTestDeviceInfoProvider

- (MSIDWPJKeyPairWithCert *)deviceRegistrationKeyPairForTenantId:(__unused NSString *)tenantId
                                                        context:(__unused id<MSIDRequestContext>)context
{
    return self.wpjKeyPairStub;
}

- (MSIDNonceTokenRequest *)nonceTokenRequestWithRequestParameters:(MSIDRequestParameters *)requestParameters
{
    MSALFakeNonceTokenRequest *request = [[MSALFakeNonceTokenRequest alloc] initWithRequestParameters:requestParameters];
    request.nonceToReturn = self.nonceStub;
    request.errorToReturn = self.nonceErrorStub;
    return request;
}

- (MSIDDeviceTokenGrantRequest *)deviceTokenGrantRequestWithEndpoint:(NSURL *)endpoint
                                                   requestParameters:(MSIDRequestParameters *)requestParameters
                                             registrationInformation:(MSIDWPJKeyPairWithCert *)registrationInformation
                                                            resource:(NSString *)resource
                                                        enrollmentId:(NSString *)enrollmentId
                                                tokenResponseHandler:(MSIDDeviceTokenResponseHandler *)tokenResponseHandler
                                                               error:(NSError *__autoreleasing *)error
{
    MSALFakeDeviceTokenGrantRequest *request = [[MSALFakeDeviceTokenGrantRequest alloc] initWithEndpoint:endpoint
                                                                                       requestParameters:requestParameters
                                                                                                  scopes:requestParameters.allTokenRequestScopes
                                                                                 registrationInformation:registrationInformation
                                                                                                resource:resource
                                                                                            enrollmentId:enrollmentId
                                                                                         extraParameters:nil
                                                                                              ssoContext:nil
                                                                                    tokenResponseHandler:tokenResponseHandler
                                                                                                   error:error];
    request.tokenResultToReturn = self.deviceTokenResultStub;
    request.errorToReturn = self.deviceTokenErrorStub;
    request.executeExpectation = self.deviceTokenExecuteExpectation;
    self.builtDeviceTokenGrantRequest = request;
    return request;
}

@end

@interface MSALDeviceInfoProviderTests : XCTestCase

@end

@implementation MSALDeviceInfoProviderTests

#pragma mark - Get device info

- (void)testGetDeviceInfo_whenCurrentSSOExtensionRequestAlreadyPresent_shouldReturnNilAndFillError
{
    XCTSkip("Skip flaky test.");
    
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(id obj)
    {
        return YES;
    }];
    
    MSALDeviceInfoProvider *deviceInfoProvider = [MSALDeviceInfoProvider new];
    
    __block dispatch_semaphore_t dsem = dispatch_semaphore_create(0);
    
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetDeviceInfoRequest  class]
                              block:(id)^(id obj, MSIDGetDeviceInfoRequestCompletionBlock callback)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            dispatch_semaphore_wait(dsem, DISPATCH_TIME_FOREVER);
            callback(nil, nil);
        });
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Get device info"];
    XCTestExpectation *failExpectation = [self expectationWithDescription:@"Failed expectation"];
    
    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    requestParams.validateAuthority = YES;
    
    [deviceInfoProvider deviceInfoWithRequestParameters:requestParams
                                        completionBlock:^(MSALDeviceInformation * _Nullable deviceInformation, NSError * _Nullable error)
    {
        [expectation fulfill];
    }];
    
    [deviceInfoProvider deviceInfoWithRequestParameters:requestParams
                                        completionBlock:^(MSALDeviceInformation * _Nullable deviceInformation, NSError * _Nullable error)
    {
        XCTAssertNil(deviceInformation);
        XCTAssertEqual(deviceInformation.deviceMode, MSALDeviceModeDefault);
        XCTAssertEqual(deviceInformation.extraDeviceInformation.count, 0);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInternal);
        [failExpectation fulfill];
        dispatch_semaphore_signal(dsem);
    }];
    
    [self waitForExpectations:@[expectation, failExpectation] timeout:2];
}

- (void)testWPJMetaDataDeviceInfoWithRequestParameters_tenantIdNil
{
    [MSIDTestSwizzle classMethod:@selector(getRegisteredDeviceMetadataInformation:tenantId:usePrimaryFormat:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id<MSIDRequestContext>)^(id<MSIDRequestContext>_Nullable context)
    {
        NSMutableDictionary *deviceMetadata = [NSMutableDictionary new];
        [deviceMetadata setValue:@"TestDevID" forKey:@"aadDeviceIdentifier"];
        [deviceMetadata setValue:@"TestUPN" forKey:@"userPrincipalName"];
        [deviceMetadata setValue:@"TestTenantID" forKey:@"aadTenantIdentifier"];
        return deviceMetadata;
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Get device info"];

    MSALDeviceInfoProvider *deviceInfoProvider = [MSALDeviceInfoProvider new];
    
    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    requestParams.validateAuthority = YES;
    
    [deviceInfoProvider wpjMetaDataDeviceInfoWithRequestParameters:requestParams
                                                          tenantId:nil
                                                   completionBlock:^(MSALWPJMetaData * _Nullable msalPJMetaDataInformation, NSError * _Nullable error)
    {
        [expectation fulfill];
        NSMutableDictionary *extraDeviceInfoDict = [NSMutableDictionary new];
        [msalPJMetaDataInformation addRegisteredDeviceMetadataInformation:extraDeviceInfoDict];
        XCTAssertEqual(msalPJMetaDataInformation.extraDeviceInformation.count, 3);
        XCTAssertEqualObjects(msalPJMetaDataInformation.extraDeviceInformation[@"aadDeviceIdentifier"], @"TestDevID");
        XCTAssertEqualObjects(msalPJMetaDataInformation.extraDeviceInformation[@"userPrincipalName"], @"TestUPN");
        XCTAssertEqualObjects(msalPJMetaDataInformation.extraDeviceInformation[@"aadTenantIdentifier"], @"TestTenantID");
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testWPJMetaDataDeviceInfoWithRequestParameters_tenantIdNil_noRegisterationInformation
{
    
    [MSIDTestSwizzle classMethod:@selector(getRegisteredDeviceMetadataInformation:tenantId:usePrimaryFormat:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id<MSIDRequestContext>)^(id<MSIDRequestContext>_Nullable context)
    {
        return nil;
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Get WPJMetaDataDeviceInfo"];

    MSALDeviceInfoProvider *deviceInfoProvider = [MSALDeviceInfoProvider new];
    
    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    requestParams.validateAuthority = YES;
    
    [deviceInfoProvider wpjMetaDataDeviceInfoWithRequestParameters:requestParams
                                                          tenantId:nil
                                                   completionBlock:^(MSALWPJMetaData * _Nullable msalPJMetaDataInformation, NSError * _Nullable error)
    {
        [expectation fulfill];
        XCTAssertEqual(msalPJMetaDataInformation.extraDeviceInformation.count, 0);
        XCTAssertNil(msalPJMetaDataInformation.extraDeviceInformation[@"aadDeviceIdentifier"]);
        XCTAssertNil(msalPJMetaDataInformation.extraDeviceInformation[@"userPrincipalName"]);
        XCTAssertNil(msalPJMetaDataInformation.extraDeviceInformation[@"aadTenantIdentifier"]);
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testWPJMetaDataDeviceInfoWithRequestParameters_tenantIdNonNil
{
    [MSIDTestSwizzle classMethod:@selector(getRegisteredDeviceMetadataInformation:tenantId:usePrimaryFormat:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id<MSIDRequestContext>)^(id<MSIDRequestContext>_Nullable context)
    {
        NSMutableDictionary *deviceMetadata = [NSMutableDictionary new];
        [deviceMetadata setValue:@"TestDevID" forKey:@"aadDeviceIdentifier"];
        [deviceMetadata setValue:@"TestUPN" forKey:@"userPrincipalName"];
        [deviceMetadata setValue:@"TestTenantID" forKey:@"aadTenantIdentifier"];
        return deviceMetadata;
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Get WPJMetaDataDeviceInfo"];

    MSALDeviceInfoProvider *deviceInfoProvider = [MSALDeviceInfoProvider new];
    
    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    requestParams.validateAuthority = YES;
    
    [deviceInfoProvider wpjMetaDataDeviceInfoWithRequestParameters:requestParams
                                                          tenantId:@"TestTenantID"
                                                   completionBlock:^(MSALWPJMetaData * _Nullable msalPJMetaDataInformation, NSError * _Nullable error)
    {
        [expectation fulfill];
        XCTAssertEqual(msalPJMetaDataInformation.extraDeviceInformation.count, 3);
        XCTAssertEqualObjects(msalPJMetaDataInformation.extraDeviceInformation[@"aadDeviceIdentifier"], @"TestDevID");
        XCTAssertEqualObjects(msalPJMetaDataInformation.extraDeviceInformation[@"userPrincipalName"], @"TestUPN");
        XCTAssertEqualObjects(msalPJMetaDataInformation.extraDeviceInformation[@"aadTenantIdentifier"], @"TestTenantID");
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testGetDeviceInfo_whenSSOExtensionNotAvailable_shouldReturnDefaultDeviceInfo
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(id obj)
    {
        return NO;
    }];
    
    MSALDeviceInfoProvider *deviceInfoProvider = [MSALDeviceInfoProvider new];
        
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    expectation.inverted = YES;
    
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetDeviceInfoRequest  class]
                              block:(id)^(id obj, MSIDGetDeviceInfoRequestCompletionBlock callback)
    {
        [expectation fulfill];
    }];
    
    XCTestExpectation *failExpectation = [self expectationWithDescription:@"Get device info"];
    
    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    requestParams.validateAuthority = YES;
    
    [deviceInfoProvider deviceInfoWithRequestParameters:requestParams
                                        completionBlock:^(MSALDeviceInformation * _Nullable deviceInformation, NSError * _Nullable error)
    {
        XCTAssertNotNil(deviceInformation);
        XCTAssertNil(error);
        XCTAssertEqual(deviceInformation.deviceMode, MSALDeviceModeDefault);
        [failExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation, failExpectation] timeout:1];
}

- (void)testGetDeviceInfo_whenSSOExtensionNotAvailable_shouldReturnDefaultDeviceInfo_withWPJRegisterationInfo
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(id obj)
    {
        return NO;
    }];

    MSALDeviceInfoProvider *deviceInfoProvider = [MSALDeviceInfoProvider new];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    expectation.inverted = YES;

    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetDeviceInfoRequest  class]
                              block:(id)^(id obj, MSIDGetDeviceInfoRequestCompletionBlock callback)
    {
        [expectation fulfill];
    }];

    [MSIDTestSwizzle classMethod:@selector(getRegisteredDeviceMetadataInformation:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id<MSIDRequestContext>)^(id<MSIDRequestContext>_Nullable context)
    {
        NSMutableDictionary *deviceMetadata = [NSMutableDictionary new];
        [deviceMetadata setValue:@"TestDevID" forKey:@"aadDeviceIdentifier"];
        [deviceMetadata setValue:@"TestUPN" forKey:@"userPrincipalName"];
        [deviceMetadata setValue:@"TestTenantID" forKey:@"aadTenantIdentifier"];
        return deviceMetadata;
    }];

    XCTestExpectation *failExpectation = [self expectationWithDescription:@"Get device info"];

    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    requestParams.validateAuthority = YES;

    [deviceInfoProvider deviceInfoWithRequestParameters:requestParams
                                        completionBlock:^(MSALDeviceInformation * _Nullable deviceInformation, NSError * _Nullable error)
    {
        XCTAssertNotNil(deviceInformation);
        XCTAssertNil(error);
        XCTAssertEqual(deviceInformation.deviceMode, MSALDeviceModeDefault);
        XCTAssertEqual(deviceInformation.extraDeviceInformation.count, 3);
        XCTAssertEqualObjects(deviceInformation.extraDeviceInformation[@"aadDeviceIdentifier"], @"TestDevID");
        XCTAssertEqualObjects(deviceInformation.extraDeviceInformation[@"userPrincipalName"], @"TestUPN");
        XCTAssertEqualObjects(deviceInformation.extraDeviceInformation[@"aadTenantIdentifier"], @"TestTenantID");
        [failExpectation fulfill];
    }];

    [self waitForExpectations:@[expectation, failExpectation] timeout:1];
}

- (void)testGetDeviceInfo_whenSSOExtensionPresent_encounteredError_shouldReturnError
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(id obj)
    {
        return YES;
    }];
    
    MSALDeviceInfoProvider *deviceInfoProvider = [MSALDeviceInfoProvider new];
        
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetDeviceInfoRequest  class]
                              block:(id)^(id obj, MSIDGetDeviceInfoRequestCompletionBlock callback)
    {
        [expectation fulfill];
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUnsupportedFunctionality, @"Unsupported functionality", nil, nil, nil, nil, nil, NO);
        callback(nil, error);
    }];
    
    [MSIDTestSwizzle classMethod:@selector(getRegisteredDeviceMetadataInformation:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id<MSIDRequestContext>)^(id<MSIDRequestContext>_Nullable context)
    {
        NSMutableDictionary *deviceMetadata = [NSMutableDictionary new];
        [deviceMetadata setValue:@"TestDevID" forKey:@"aadDeviceIdentifier"];
        [deviceMetadata setValue:@"TestUPN" forKey:@"userPrincipalName"];
        [deviceMetadata setValue:@"TestTenantID" forKey:@"aadTenantIdentifier"];
        return deviceMetadata;
    }];
    
    XCTestExpectation *failExpectation = [self expectationWithDescription:@"Get device info"];
    
    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    requestParams.validateAuthority = YES;
    
    [deviceInfoProvider deviceInfoWithRequestParameters:requestParams
                                        completionBlock:^(MSALDeviceInformation * _Nullable deviceInformation, NSError * _Nullable error)
    {
        XCTAssertNotNil(deviceInformation);
        XCTAssertEqual(deviceInformation.deviceMode, MSALDeviceModeDefault);
        XCTAssertEqual(deviceInformation.extraDeviceInformation.count, 3);
        XCTAssertEqualObjects(deviceInformation.extraDeviceInformation[@"aadDeviceIdentifier"], @"TestDevID");
        XCTAssertEqualObjects(deviceInformation.extraDeviceInformation[@"userPrincipalName"], @"TestUPN");
        XCTAssertEqualObjects(deviceInformation.extraDeviceInformation[@"aadTenantIdentifier"], @"TestTenantID");
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorUnsupportedFunctionality);
        [failExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation, failExpectation] timeout:1];
}

- (void)testGetDeviceInfo_whenSSOExtensionPresent_andReturnedDeviceInfo_shouldReturnMSALDeviceInfo
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(id obj)
    {
        return YES;
    }];
    
    MSALDeviceInfoProvider *deviceInfoProvider = [MSALDeviceInfoProvider new];
        
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetDeviceInfoRequest  class]
                              block:(id)^(id obj, MSIDGetDeviceInfoRequestCompletionBlock callback)
    {
        [expectation fulfill];
        
        MSIDDeviceInfo *deviceInfo = [MSIDDeviceInfo new];
        deviceInfo.brokerVersion = @"test";
        deviceInfo.deviceMode = MSIDDeviceModeShared;
        deviceInfo.ssoExtensionMode = MSIDSSOExtensionModeSilentOnly;
#if TARGET_OS_IPHONE
        NSMutableDictionary *extraDeviceInfoDict = [NSMutableDictionary new];
        extraDeviceInfoDict[MSID_BROKER_MDM_ID_KEY] = @"mdmId";
        extraDeviceInfoDict[MSID_ENROLLED_USER_OBJECT_ID_KEY] = @"objectId";
        extraDeviceInfoDict[MSID_IS_CALLER_MANAGED_KEY] = @"1";
        deviceInfo.extraDeviceInfo = extraDeviceInfoDict;
#endif
#if TARGET_OS_OSX && __MAC_OS_X_VERSION_MAX_ALLOWED >= 130000
        deviceInfo.platformSSOStatus = MSIDPlatformSSOEnabledAndRegistered;
#endif

        
        callback(deviceInfo, nil);
    }];
    
    XCTestExpectation *successExpectation = [self expectationWithDescription:@"Get device info"];
    
    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    requestParams.validateAuthority = YES;
    
    [deviceInfoProvider deviceInfoWithRequestParameters:requestParams
                                        completionBlock:^(MSALDeviceInformation * _Nullable deviceInformation, NSError * _Nullable error)
    {
        XCTAssertNotNil(deviceInformation);
        XCTAssertNil(error);
        XCTAssertEqual(deviceInformation.deviceMode, MSALDeviceModeShared);
        XCTAssertEqualObjects(deviceInformation.extraDeviceInformation[@"isSSOExtensionInFullMode"], @"No");
#if TARGET_OS_IPHONE
        XCTAssertEqualObjects(deviceInformation.extraDeviceInformation[MSID_BROKER_MDM_ID_KEY], @"mdmId");
        XCTAssertEqualObjects(deviceInformation.extraDeviceInformation[MSID_ENROLLED_USER_OBJECT_ID_KEY], @"objectId");
        XCTAssertEqualObjects(deviceInformation.extraDeviceInformation[MSID_IS_CALLER_MANAGED_KEY], @"1");
#endif
#if TARGET_OS_OSX && __MAC_OS_X_VERSION_MAX_ALLOWED >= 130000
        XCTAssertEqual(deviceInformation.platformSSOStatus, MSALPlatformSSOEnabledAndRegistered);
#endif
        [successExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation, successExpectation] timeout:1];
}

- (void)testGetDeviceInfo_whenSSOExtensionPresent_notConfiguredForJIT_shouldReturnMSALDeviceInfoWithoutMdmIdAndObjectId
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(id obj)
    {
        return YES;
    }];
    
    MSALDeviceInfoProvider *deviceInfoProvider = [MSALDeviceInfoProvider new];
        
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetDeviceInfoRequest  class]
                              block:(id)^(id obj, MSIDGetDeviceInfoRequestCompletionBlock callback)
    {
        [expectation fulfill];
        
        MSIDDeviceInfo *deviceInfo = [MSIDDeviceInfo new];
        deviceInfo.brokerVersion = @"test";
        deviceInfo.deviceMode = MSIDDeviceModeShared;
        deviceInfo.ssoExtensionMode = MSIDSSOExtensionModeSilentOnly;
#if TARGET_OS_IPHONE
        NSMutableDictionary *extraDeviceInfoDict = [NSMutableDictionary new];
        extraDeviceInfoDict[MSID_IS_CALLER_MANAGED_KEY] = @"1";
        deviceInfo.extraDeviceInfo = extraDeviceInfoDict;
#endif
        callback(deviceInfo, nil);
    }];
    
    XCTestExpectation *successExpectation = [self expectationWithDescription:@"Get device info"];
    
    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    requestParams.validateAuthority = YES;
    
    [deviceInfoProvider deviceInfoWithRequestParameters:requestParams
                                        completionBlock:^(MSALDeviceInformation * _Nullable deviceInformation, NSError * _Nullable error)
    {
        XCTAssertNotNil(deviceInformation);
        XCTAssertNil(error);
        XCTAssertEqual(deviceInformation.deviceMode, MSALDeviceModeShared);
        XCTAssertEqualObjects(deviceInformation.extraDeviceInformation[@"isSSOExtensionInFullMode"], @"No");
#if TARGET_OS_IPHONE
        XCTAssertEqualObjects(deviceInformation.extraDeviceInformation[MSID_IS_CALLER_MANAGED_KEY], @"1");
#endif
        XCTAssertNil(deviceInformation.extraDeviceInformation[MSID_BROKER_MDM_ID_KEY]);
        XCTAssertNil(deviceInformation.extraDeviceInformation[MSID_ENROLLED_USER_OBJECT_ID_KEY]);

        [successExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation, successExpectation] timeout:1];
}
#if TARGET_OS_OSX
- (void)testGetDeviceInfo_whenSSOExtensionPresent_platformSSONotEnabled_shouldReturnPlatformSSONotEnabled
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(id obj)
    {
        return YES;
    }];
    
    MSALDeviceInfoProvider *deviceInfoProvider = [MSALDeviceInfoProvider new];
        
    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];
    
    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetDeviceInfoRequest  class]
                              block:(id)^(id obj, MSIDGetDeviceInfoRequestCompletionBlock callback)
    {
        [expectation fulfill];
        
        MSIDDeviceInfo *deviceInfo = [MSIDDeviceInfo new];
        deviceInfo.brokerVersion = @"test";
        deviceInfo.deviceMode = MSIDDeviceModeShared;
        deviceInfo.platformSSOStatus = MSIDPlatformSSONotEnabled;
        NSMutableDictionary *extraDeviceInfoDict = [NSMutableDictionary new];
        deviceInfo.extraDeviceInfo = extraDeviceInfoDict;
        callback(deviceInfo, nil);
    }];
    
    XCTestExpectation *successExpectation = [self expectationWithDescription:@"Get device info"];
    
    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    requestParams.validateAuthority = YES;
    
    [deviceInfoProvider deviceInfoWithRequestParameters:requestParams
                                        completionBlock:^(MSALDeviceInformation * _Nullable deviceInformation, NSError * _Nullable error)
    {
        XCTAssertNotNil(deviceInformation);
        XCTAssertNil(error);
        XCTAssertEqual(deviceInformation.platformSSOStatus, MSALPlatformSSONotEnabled);
        [successExpectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation, successExpectation] timeout:1];
}

#endif
- (void)testGetDeviceInfo_whenSSOExtensionPresent_andReturnedDeviceInfo_shouldReturnMSALDeviceInfo_withWPJRegisterationInfo
{
    [MSIDTestSwizzle classMethod:@selector(canPerformRequest)
                           class:[MSIDSSOExtensionGetDeviceInfoRequest class]
                           block:(id)^(id obj)
    {
        return YES;
    }];

    [MSIDTestSwizzle classMethod:@selector(getRegisteredDeviceMetadataInformation:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id<MSIDRequestContext>)^(id<MSIDRequestContext>_Nullable context)
    {
        NSMutableDictionary *deviceMetadata = [NSMutableDictionary new];
        [deviceMetadata setValue:@"TestDevID" forKey:@"aadDeviceIdentifier"];
        [deviceMetadata setValue:@"TestUPN" forKey:@"userPrincipalName"];
        [deviceMetadata setValue:@"TestTenantID" forKey:@"aadTenantIdentifier"];
        return deviceMetadata;
    }];

    MSALDeviceInfoProvider *deviceInfoProvider = [MSALDeviceInfoProvider new];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Execute request"];

    [MSIDTestSwizzle instanceMethod:@selector(executeRequestWithCompletion:)
                              class:[MSIDSSOExtensionGetDeviceInfoRequest  class]
                              block:(id)^(id obj, MSIDGetDeviceInfoRequestCompletionBlock callback)
    {
        [expectation fulfill];

        MSIDDeviceInfo *deviceInfo = [MSIDDeviceInfo new];
        deviceInfo.brokerVersion = @"test";
        deviceInfo.deviceMode = MSIDDeviceModeShared;
        deviceInfo.ssoExtensionMode = MSIDSSOExtensionModeSilentOnly;

        callback(deviceInfo, nil);
    }];

    XCTestExpectation *successExpectation = [self expectationWithDescription:@"Get device info"];

    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    requestParams.validateAuthority = YES;

    [deviceInfoProvider deviceInfoWithRequestParameters:requestParams
                                        completionBlock:^(MSALDeviceInformation * _Nullable deviceInformation, NSError * _Nullable error)
    {
        XCTAssertNotNil(deviceInformation);
        XCTAssertNil(error);
        XCTAssertEqual(deviceInformation.deviceMode, MSALDeviceModeShared);
        XCTAssertEqualObjects(deviceInformation.extraDeviceInformation[@"isSSOExtensionInFullMode"], @"No");
        XCTAssertEqualObjects(deviceInformation.extraDeviceInformation[@"aadDeviceIdentifier"], @"TestDevID");
        XCTAssertEqualObjects(deviceInformation.extraDeviceInformation[@"userPrincipalName"], @"TestUPN");
        XCTAssertEqualObjects(deviceInformation.extraDeviceInformation[@"aadTenantIdentifier"], @"TestTenantID");
        XCTAssertNil(deviceInformation.extraDeviceInformation[MSID_BROKER_MDM_ID_KEY]);
        XCTAssertNil(deviceInformation.extraDeviceInformation[MSID_ENROLLED_USER_OBJECT_ID_KEY]);
        [successExpectation fulfill];
    }];

    [self waitForExpectations:@[expectation, successExpectation] timeout:1];
}

#pragma mark - deviceTokenWithRequestParameters

- (void)testDeviceTokenWithRequestParameters_whenNoWPJKeysForTenant_shouldReturnError
{
    [MSIDTestSwizzle classMethod:@selector(getWPJKeysWithTenantId:context:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id)^(id cls, NSString *tenantId, id<MSIDRequestContext> context)
    {
        return nil;
    }];

    MSALDeviceInfoProvider *deviceInfoProvider = [MSALDeviceInfoProvider new];
    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    MSALDeviceTokenParameters *deviceTokenParams = [[MSALDeviceTokenParameters alloc] initWithResource:@"https://resource.contoso.com"
                                                                                                scopes:nil
                                                                                           forTenantId:@"TestTenantID"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Device token completion"];

    [deviceInfoProvider deviceTokenWithRequestParameters:requestParams
                                   deviceTokenParameters:deviceTokenParams
                                         completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error)
    {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorWorkplaceJoinRequired);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testDeviceTokenWithRequestParameters_whenWPJKeysHaveNoCertificateData_shouldReturnError
{
    MSIDWPJKeyPairWithCert *mockKeyPair = [MSIDWPJKeyPairWithCert new];

    [MSIDTestSwizzle classMethod:@selector(getWPJKeysWithTenantId:context:)
                           class:[MSIDWorkPlaceJoinUtil class]
                           block:(id)^(id cls, NSString *tenantId, id<MSIDRequestContext> context)
    {
        return mockKeyPair;
    }];

    [MSIDTestSwizzle instanceMethod:@selector(certificateData)
                              class:[MSIDWPJKeyPairWithCert class]
                              block:(id)^(id obj)
    {
        return nil;
    }];

    MSALDeviceInfoProvider *deviceInfoProvider = [MSALDeviceInfoProvider new];
    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    MSALDeviceTokenParameters *deviceTokenParams = [[MSALDeviceTokenParameters alloc] initWithResource:@"https://resource.contoso.com"
                                                                                                scopes:nil
                                                                                           forTenantId:@"TestTenantID"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Device token completion"];

    [deviceInfoProvider deviceTokenWithRequestParameters:requestParams
                                   deviceTokenParameters:deviceTokenParams
                                         completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error)
    {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorInternal);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1];
}

- (void)testDeviceTokenWithRequestParameters_whenDeviceTokenRequestFails_shouldReturnError
{
    MSIDWPJKeyPairWithCert *mockKeyPair = [[MSIDWPJKeyPairWithCert alloc] initWithPrivateKey:self.dummyPrivateKeyForCertRef certificate:[self dummyCertRef:@"some-identifier"] certificateIssuer:@"some-issuer"];
    NSString *expectedNonce = @"test-nonce";

    XCTestExpectation *deviceTokenExecuteExpectation = [self expectationWithDescription:@"Device token request executed"];

    MSALTestDeviceInfoProvider *deviceInfoProvider = [MSALTestDeviceInfoProvider new];
    deviceInfoProvider.wpjKeyPairStub = mockKeyPair;
    deviceInfoProvider.nonceStub = expectedNonce;
    deviceInfoProvider.deviceTokenErrorStub = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerUnhandledResponse, @"Server error.", nil, nil, nil, nil, nil, YES);
    deviceInfoProvider.deviceTokenExecuteExpectation = deviceTokenExecuteExpectation;

    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    MSALDeviceTokenParameters *deviceTokenParams = [[MSALDeviceTokenParameters alloc] initWithResource:@"https://resource.contoso.com"
                                                                                                scopes:nil
                                                                                           forTenantId:@"TestTenantID"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Device token completion"];

    [deviceInfoProvider deviceTokenWithRequestParameters:requestParams
                                   deviceTokenParameters:deviceTokenParams
                                         completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error)
    {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
        XCTAssertEqual(error.code, MSIDErrorServerUnhandledResponse);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[deviceTokenExecuteExpectation, expectation] timeout:1];
    XCTAssertEqualObjects(deviceInfoProvider.builtDeviceTokenGrantRequest.capturedNonce, expectedNonce);
}

- (void)testDeviceTokenWithRequestParameters_whenNonceRequestFails_shouldReturnErrorWithoutExecutingDeviceTokenRequest
{
    MSIDWPJKeyPairWithCert *mockKeyPair = [[MSIDWPJKeyPairWithCert alloc] initWithPrivateKey:self.dummyPrivateKeyForCertRef certificate:[self dummyCertRef:@"some-identifier"] certificateIssuer:@"some-issuer"];
    NSError *nonceError = MSIDCreateError(MSIDErrorDomain, MSIDErrorServerUnhandledResponse, @"Nonce error.", nil, nil, nil, nil, nil, YES);

    XCTestExpectation *deviceTokenRequestExpectation = [self expectationWithDescription:@"Device token request should not execute"];
    deviceTokenRequestExpectation.inverted = YES;

    MSALTestDeviceInfoProvider *deviceInfoProvider = [MSALTestDeviceInfoProvider new];
    deviceInfoProvider.wpjKeyPairStub = mockKeyPair;
    deviceInfoProvider.nonceErrorStub = nonceError;
    deviceInfoProvider.deviceTokenExecuteExpectation = deviceTokenRequestExpectation;

    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    MSALDeviceTokenParameters *deviceTokenParams = [[MSALDeviceTokenParameters alloc] initWithResource:@"https://resource.contoso.com"
                                                                                                scopes:nil
                                                                                           forTenantId:@"TestTenantID"];

    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"Device token completion"];

    [deviceInfoProvider deviceTokenWithRequestParameters:requestParams
                                   deviceTokenParameters:deviceTokenParams
                                         completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error)
    {
        XCTAssertNil(result);
        XCTAssertEqualObjects(error, nonceError);
        [completionExpectation fulfill];
    }];

    [self waitForExpectations:@[deviceTokenRequestExpectation, completionExpectation] timeout:1];
}

- (void)testDeviceTokenWithRequestParameters_whenDeviceTokenRequestSucceeds_shouldReturnTokenResult
{
    MSIDWPJKeyPairWithCert *mockKeyPair = [[MSIDWPJKeyPairWithCert alloc] initWithPrivateKey:self.dummyPrivateKeyForCertRef certificate:[self dummyCertRef:@"some-identifier"] certificateIssuer:@"some-issuer"];
    NSString *expectedNonce = @"test-nonce";
    MSIDTokenResult *mockTokenResult = [MSIDTokenResult new];

    XCTestExpectation *deviceTokenExecuteExpectation = [self expectationWithDescription:@"Device token request executed"];

    MSALTestDeviceInfoProvider *deviceInfoProvider = [MSALTestDeviceInfoProvider new];
    deviceInfoProvider.wpjKeyPairStub = mockKeyPair;
    deviceInfoProvider.nonceStub = expectedNonce;
    deviceInfoProvider.deviceTokenResultStub = mockTokenResult;
    deviceInfoProvider.deviceTokenExecuteExpectation = deviceTokenExecuteExpectation;

    MSIDRequestParameters *requestParams = [MSIDTestParametersProvider testInteractiveParameters];
    MSALDeviceTokenParameters *deviceTokenParams = [[MSALDeviceTokenParameters alloc] initWithResource:@"https://resource.contoso.com"
                                                                                                scopes:nil
                                                                                           forTenantId:@"TestTenantID"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Device token completion"];

    [deviceInfoProvider deviceTokenWithRequestParameters:requestParams
                                   deviceTokenParameters:deviceTokenParams
                                         completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error)
    {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[deviceTokenExecuteExpectation, expectation] timeout:1];
    XCTAssertEqualObjects(deviceInfoProvider.builtDeviceTokenGrantRequest.capturedNonce, expectedNonce);
}

- (SecCertificateRef)dummyCertRef:(NSString *)certIdentifier
{
    NSString *drsIssuedCertificate = [self dummyCertificate];
    NSData *certData = [NSData msidDataFromBase64UrlEncodedString:drsIssuedCertificate];
    return SecCertificateCreateWithData(NULL, (__bridge CFDataRef)(certData));
}

- (NSString *)dummyCertificate
{
    return [NSString stringWithFormat: @"MIIEAjCCAuqgAwIBAgIQFc8t8z6QDoBGW1z8UDN+0zANBgkqhkiG9w0BAQsFADB4MXYwEQYKCZImiZPyLGQBGRYDbmV0MBUGCgmSJomT8ixkARkWB3dpbmRvd3MwHQYDVQQDExZNUy1Pcmdhbml6YXRpb24tQWNjZXNzMCsGA1UECxMkODJkYmFjYTQtM2U4MS00NmNhLTljNzMtMDk1MGMxZWFjYTk3MB4XDTE5MDgyOTIwMjU1NloXDTI5MDgyOTIwNTU1NlowLzEtMCsGA1UEAxMk%@MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1H1ZmEe+OrXboN63oF8i+H649IHZaPySEnjQYF61TXS6vg0j2EC5e43xql3AG43NgDVW7ZrwtFvm5xIvXKCnN3BoQCi6JtUN6K7eZCnFdQIdrAV2Pyq5zkl9RItziKKFg+Gf92Bz5TQVgP3i/mb2xZe5fabNa0Jdj9tMSlq1QppDTyV01NOqk+AfPNwJsFlMZegGFdjLC3thGIgJEywmCaJacg+SBx2Vp3DawnuFMhWp1WRHJweZWZScCTCApiE5HJY4zMI44NJPOLUkUnN6zc7Yzw0AXKIZBid99OWlhJ6jQ92ayQEzmfNZM0IRRtl1VeU5TOQ1NcvKSyQFQ5uyvQIDAQABo4HQMIHNMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwIwDgYDVR0PAQH/BAQDAgeAMCIGCyqGSIb3FAEFghwCBBMEgRA78+WeSZfnQ5VngxjqQSVLMCIGCyqGSIb3FAEFghwDBBMEgRBP+CztBI6eSJZu39covAlhMCIGCyqGSIb3FAEFghwFBBMEgRCS4qJehkWISIVqoGYSGf2rMBQGCyqGSIb3FAEFghwIBAUEgQJOQTATBgsqhkiG9xQBBYIcBwQEBIEBMDANBgkqhkiG9w0BAQsFAAOCAQEAn6nzvuRd1moZ78aNfaZwFlxJx9ycNQNHRVljw4/Asqc9X2ySq4vE+f3zpqq2Q0c6lZ/yykb0KmZXeqWgyRK82uR48gWNAVvbPJr4l6B2cnTHAwkc+PLmADr7sE2WgBGH3uSqMcDKSbE/VpH3zOAnxeC8RByy/EEvGdC3YasjR9IGL4sSkyLHrZNO6Pz7oApL/BA713xJcp+EkzDIFF09JILuP1IANz8uW26GyNLBtBfdulKbbzv1i0tWMukN+s8upm9mWJyn8hXmz/LUa5NQtP0mBrRbw1d7NXPOgO54dr+DPpKZxrQw6zpwCJ/waeKIJjHAIDAF6h1BjFCaAulhJA==", @"OWVlNWYzM2ItOTc0OS00M2U3LTk1NjctODMxOGVhNDEyNTRi"];
}

- (NSString *)dummyPrivateKeyForCert
{
    return @"MIIEowIBAAKCAQEA1H1ZmEe+OrXboN63oF8i+H649IHZaPySEnjQYF61TXS6vg0j2EC5e43xql3AG43NgDVW7ZrwtFvm5xIvXKCnN3BoQCi6JtUN6K7eZCnFdQIdrAV2Pyq5zkl9RItziKKFg+Gf92Bz5TQVgP3i/mb2xZe5fabNa0Jdj9tMSlq1QppDTyV01NOqk+AfPNwJsFlMZegGFdjLC3thGIgJEywmCaJacg+SBx2Vp3DawnuFMhWp1WRHJweZWZScCTCApiE5HJY4zMI44NJPOLUkUnN6zc7Yzw0AXKIZBid99OWlhJ6jQ92ayQEzmfNZM0IRRtl1VeU5TOQ1NcvKSyQFQ5uyvQIDAQABAoIBAEmRRI3GeQQWpn2h3m11wsPKC/sLYdxJZcFjdrGG2LqCaY0XO4vJjO5MDJlxb+uaQsXascf91sx67QyfbSpirMIy9sUP1LNRHEmtEW4YUDbcjq1aDsB76GyVYPt0VIG/0v4ABcQ97qIyUCeivw5ZU6LBjwUD1ScHiSEfSeCMWyk9YgRUozM3yZOpvugwjOF7efEjVlWvGvIfh9U/Xyeuj+NJ3r8zW87K+ySzGwrPwEmfBBfyd5LOqZzPJAKGJ3og8oaMDf4IWV7iSicCcPCbq6psj+B/i4HZc9u3MqE7YjKVbNG2S6qDsLUxpWfct72ZeKtfZcb3Kqa1nh0RximqUoECgYEA6UfzvsHg283KOTxQqX3v2IDbtwv73wKd/+V8sq8mhtjJhv5SpyJe99L/cuoxTu2ELUPmKIP++b7oyMvdRNyJaLIMRYDGGAKeLXXtWht//tCmHXyOZDhs9oHC3EMNHmqXBDSObL/CbN5puAQbCjofUX5zTNMdmq0qTOPYUezxjHECgYEA6S8JXstQ5RL+pmonoFlPWfuwXL8chpGJH1iOab1WYwjAbszSy1LJBQu5dWhKcqLl3EFywJgWRUKGFlQ/099XRVTHl4YhjEN054GEBxsTkZUhwXh0l0v6lPnsG6daWcTZ44gh4FXtqfPD/5/RcWUfhYQW0NoeIzviWt8MqZ6NIQ0CgYEA1TDpg/qBOb9vQTFq8grix7Szlyx/iYZFyNf8RvwktHWobxM7i/ywV8HfrDB00ZHlCs0TqRFAUxNygBc3Zzg455JX/qi54LV7w0YTnRamucQLG8V6CAM9KWbbIxqwAY0d6DzzsFTrJT151i8CWy1U89AhJSOG2ZXJo61SQ0TMVzECgYA6w8PUw+BLGpJaVf5OhrNctfUoKnGB6ENqRuL8+t4+bwIv6iZlXyORxfajA/lfEnZjH4tPxgQ2yCEKl4jOWEaiDk+OfBsQQh/AB//B2qz/z1mGbFjVmCw6RxGdlntKjDVtBe2jn4QZhHksfpZFwXpEJ5moYI+fyYOt6vBB/tcKMQKBgD7q4f036ad5TeX14vsFSSkGeOJrbUw0UqYeUit9B8DICwrV42/z60kTXxGg+2Wo8gL5Fo2tKCUe34BvvpMP92EKB/qbjoIirbZVnEDP9K1rCdGdEaYzDlRXsQ/p/bM6Tz3X++wpnqcDQhJp6lTDVLaX4faSQjWuVVIHVn1zpvIr";
}

- (SecKeyRef)dummyPrivateKeyForCertRef
{
    NSDictionary *keyAttr = @{(__bridge NSString*) kSecAttrKeyType : (__bridge NSString*)kSecAttrKeyTypeRSA,
                              (__bridge NSString*) kSecAttrKeyClass : (__bridge NSString*)kSecAttrKeyClassPrivate};
    
    NSString *privateKeyForCert = [self dummyPrivateKeyForCert];
    NSData *keyData = [NSData msidDataFromBase64UrlEncodedString:privateKeyForCert];
    return SecKeyCreateWithData((__bridge CFDataRef)keyData, (__bridge CFDictionaryRef) keyAttr, NULL);
}



@end
