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

#import "MSALDeviceInfoProvider.h"
#import "MSIDRequestParameters.h"
#import "MSALDefinitions.h"
#import "MSIDSSOExtensionGetDeviceInfoRequest.h"
#import "MSIDRequestParameters+Broker.h"
#import "MSALDeviceInformation+Internal.h"

#import "MSIDWorkPlaceJoinConstants.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDRegistrationInformation.h"

@implementation MSALDeviceInfoProvider

- (void)deviceInfoWithRequestParameters:(MSIDRequestParameters *)requestParameters
                        completionBlock:(MSALDeviceInformationCompletionBlock)completionBlock
{
    MSALDeviceInformation *deviceInformation = [MSALDeviceInformation new];

    MSIDRegistrationInformation* regInfo = [MSIDWorkPlaceJoinUtil getRegistrationInformation:nil urlChallenge:nil];
    if (regInfo && regInfo.isWorkPlaceJoined)
    {
        // Certificate subject is nothing but the AAD deviceID
        NSString *deviceId = regInfo.certificateSubject;
        if (deviceId)
        {
            [deviceInformation addWorkPlaceJoinedDeviceId:deviceId];
        }

        NSString *upn = [MSIDWorkPlaceJoinUtil getWPJStringData:nil identifier:kMSIDUPNKeyIdentifier error:nil];
        if (upn)
        {
            [deviceInformation addWorkPlaceJoinedUPN:upn];
        }

        NSString *tenantID = [MSIDWorkPlaceJoinUtil getWPJStringData:nil identifier:kMSIDTenantKeyIdentifier error:nil];
        if (tenantID)
        {
            [deviceInformation addWorkPlaceJoinedTenantId:tenantID];
        }
    }

    if (@available(iOS 13.0, macOS 10.15, *))
    {
        if (![requestParameters shouldUseBroker])
        {
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorBrokerNotAvailable, @"Broker is not enabled for this operation. Please make sure you have enabled broker support for your application", nil, nil, nil, nil, nil, YES);
            completionBlock(deviceInformation, error);
            return;
        }

        if (![MSIDSSOExtensionGetDeviceInfoRequest canPerformRequest])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, requestParameters, @"Broker is not present on this device. Defaulting to personal mode");

            deviceInformation.deviceMode = MSALDeviceModeDefault;
            completionBlock(deviceInformation, nil);
            return;
        }

        NSError *requestError;
        MSIDSSOExtensionGetDeviceInfoRequest *ssoExtensionRequest = [[MSIDSSOExtensionGetDeviceInfoRequest alloc] initWithRequestParameters:requestParameters
                                                                                                                                      error:&requestError];

        if (!ssoExtensionRequest)
        {
            completionBlock(deviceInformation, requestError);
            return;
        }

        if (![self setCurrentSSOExtensionRequest:ssoExtensionRequest])
        {
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Trying to start a get accounts request while one is already executing", nil, nil, nil, nil, nil, YES);
            completionBlock(deviceInformation, error);
            return;
        }

        [ssoExtensionRequest executeRequestWithCompletion:^(MSIDDeviceInfo * _Nullable deviceInfo, NSError * _Nullable error)
        {
            [self copyAndClearCurrentSSOExtensionRequest];

            if (!deviceInfo)
            {
                completionBlock(deviceInformation, error);
                return;
            }

            [deviceInformation addExtraDeviceInformation:deviceInfo];
            completionBlock(deviceInformation, nil);
        }];
    } else {
        completionBlock(deviceInformation, nil);
    }
}

@end
