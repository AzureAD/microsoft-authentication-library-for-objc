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
#import "MSALWPJMetaData+Internal.h"

#import "MSIDWorkPlaceJoinConstants.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDRegistrationInformation.h"

@implementation MSALDeviceInfoProvider

- (void)deviceInfoWithRequestParameters:(MSIDRequestParameters *)requestParameters
                        completionBlock:(MSALDeviceInformationCompletionBlock)completionBlock
{
    void (^fillDeviceInfoCompletionBlock)(MSALDeviceInformation *, NSError *) = ^void(MSALDeviceInformation *msalDeviceInfo, NSError *error)
    {
        if (!msalDeviceInfo)
        {
            msalDeviceInfo = [MSALDeviceInformation new];
        }

        NSDictionary *deviceRegMetaDataInfo = [MSIDWorkPlaceJoinUtil getRegisteredDeviceMetadataInformation:requestParameters];
        if (deviceRegMetaDataInfo)
        {
            [msalDeviceInfo addRegisteredDeviceMetadataInformation:deviceRegMetaDataInfo];
        }
        
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"GetDeviceInfo: Completing filling device info: %@, error: %@", MSID_PII_LOG_MASKABLE(msalDeviceInfo), MSID_PII_LOG_MASKABLE(error));
        completionBlock(msalDeviceInfo, error);
    };
    
    if (![requestParameters shouldUseBroker])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, requestParameters, @"GetDeviceInfo: Should use broker decision: %i", NO);
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorBrokerNotAvailable, @"Broker is not enabled for this operation. Please make sure you have enabled broker support for your application", nil, nil, nil, nil, nil, YES);
        completionBlock(nil, error);
        return;
    }

    BOOL canCallSSOExtension = NO;
    if (@available(macOS 10.15, *))
    {
        canCallSSOExtension = [MSIDSSOExtensionGetDeviceInfoRequest canPerformRequest];
    }

    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, requestParameters, @"GetDeviceInfo: Should call Sso Extension decision: %i", canCallSSOExtension);
    if (!canCallSSOExtension)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelInfo, requestParameters, @"Broker is not present on this device. Defaulting to personal mode");

        fillDeviceInfoCompletionBlock(nil, nil);
        return;
    }
    
    if (@available(macOS 10.15, *))
    {
        // We are here means canCallSSOExtension is TRUE
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, requestParameters, @"GetDeviceInfo: Creating Sso Extension request");
        NSError *requestError;
        MSIDSSOExtensionGetDeviceInfoRequest *ssoExtensionRequest = [[MSIDSSOExtensionGetDeviceInfoRequest alloc] initWithRequestParameters:requestParameters
                                                                                                                                      error:&requestError];
        if (!ssoExtensionRequest)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, requestParameters, @"GetDeviceInfo: Get error when creating ssoExtensionRequest: %@", MSID_PII_LOG_MASKABLE(requestError));
            completionBlock(nil, requestError);
            return;
        }

        if (![self setCurrentSSOExtensionRequest:ssoExtensionRequest])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, requestParameters, @"GetDeviceInfo: Cannot start Sso Extension as another is in progress");
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Trying to start a get accounts request while one is already executing", nil, nil, nil, nil, nil, YES);
            completionBlock(nil, error);
            return;
        }

        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, requestParameters, @"GetDeviceInfo: Invoking Sso Extension with ssoExtensionRequest: %@", MSID_PII_LOG_MASKABLE(ssoExtensionRequest));
        [ssoExtensionRequest executeRequestWithCompletion:^(MSIDDeviceInfo * _Nullable deviceInfo, NSError * _Nullable error)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, requestParameters, @"GetDeviceInfo: Receiving results from Sso Extension with device info: %@, error: %@", MSID_PII_LOG_MASKABLE(deviceInfo), MSID_PII_LOG_MASKABLE(error));
            [self copyAndClearCurrentSSOExtensionRequest];

            if (!deviceInfo)
            {
                // We are returing registration details irrespective of failures due to SSO extension request as registration details must have for few clients
                // Once we identify and fix the intermittent SSO extension issue then we should return either deviceInfo or error
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"GetDeviceInfo: Error getting device info: %@", MSID_PII_LOG_MASKABLE(error));
                fillDeviceInfoCompletionBlock(nil, error);
                return;
            }

            MSALDeviceInformation *msalDeviceInfo = [[MSALDeviceInformation alloc] initWithMSIDDeviceInfo:deviceInfo];
            fillDeviceInfoCompletionBlock(msalDeviceInfo, nil);
            return;
        }];
    }
}

- (void)wpjMetaDataDeviceInfoWithRequestParameters:(MSIDRequestParameters *)requestParameters
                                          tenantId:(nullable NSString *)tenantId
                                   completionBlock:(MSALWPJMetaDataCompletionBlock)completionBlock
{
    MSALWPJMetaData *wpjMetaData = [MSALWPJMetaData new];
    
    NSDictionary *deviceRegMetaDataInfo = [MSIDWorkPlaceJoinUtil getRegisteredDeviceMetadataInformation:requestParameters tenantId:tenantId usePrimaryFormat:NO];
    if (deviceRegMetaDataInfo)
    {
        [wpjMetaData addRegisteredDeviceMetadataInformation:deviceRegMetaDataInfo];
    }
    
    MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, requestParameters, @"wpjMetaDataDeviceInfo: Completing filling device info for tenant Id: %@ %@", MSID_PII_LOG_MASKABLE(wpjMetaData),  MSID_PII_LOG_MASKABLE(tenantId));
    completionBlock(wpjMetaData, nil);
}

@end
