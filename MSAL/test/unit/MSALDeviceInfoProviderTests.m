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
#import "MSALDeviceInformation.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSALWPJMetaData+Internal.h"

@interface MSALDeviceInfoProviderTests : XCTestCase

@end

@implementation MSALDeviceInfoProviderTests

#pragma mark - Get device info

- (void)testGetDeviceInfo_whenCurrentSSOExtensionRequestAlreadyPresent_shouldReturnNilAndFillError API_AVAILABLE(ios(13.0), macos(10.15))
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
    
    [self waitForExpectations:@[expectation, failExpectation] timeout:1];
}

- (void)testWPJMetaDataDeviceInfoWithRequestParameters_tenantIdNil API_AVAILABLE(ios(13.0), macos(10.15))
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

- (void)testWPJMetaDataDeviceInfoWithRequestParameters_tenantIdNil_noRegisterationInformation API_AVAILABLE(ios(13.0), macos(10.15))
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

- (void)testWPJMetaDataDeviceInfoWithRequestParameters_tenantIdNonNil API_AVAILABLE(ios(13.0), macos(10.15))
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

- (void)testGetDeviceInfo_whenSSOExtensionNotAvailable_shouldReturnDefaultDeviceInfo API_AVAILABLE(ios(13.0), macos(10.15))
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

- (void)testGetDeviceInfo_whenSSOExtensionNotAvailable_shouldReturnDefaultDeviceInfo_withWPJRegisterationInfo API_AVAILABLE(ios(13.0), macos(10.15))
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

- (void)testGetDeviceInfo_whenSSOExtensionPresent_encounteredError_shouldReturnError API_AVAILABLE(ios(13.0), macos(10.15))
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

- (void)testGetDeviceInfo_whenSSOExtensionPresent_andReturnedDeviceInfo_shouldReturnMSALDeviceInfo API_AVAILABLE(ios(13.0), macos(10.15))
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

- (void)testGetDeviceInfo_whenSSOExtensionPresent_notConfiguredForJIT_shouldReturnMSALDeviceInfoWithoutMdmIdAndObjectId API_AVAILABLE(ios(13.0), macos(10.15))
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
- (void)testGetDeviceInfo_whenSSOExtensionPresent_platformSSONotEnabled_shouldReturnPlatformSSONotEnabled API_AVAILABLE(ios(13.0), macos(10.15))
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
- (void)testGetDeviceInfo_whenSSOExtensionPresent_andReturnedDeviceInfo_shouldReturnMSALDeviceInfo_withWPJRegisterationInfo API_AVAILABLE(ios(13.0), macos(10.15))
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

@end
