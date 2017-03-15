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

#import "MSALTelemetryAPIEvent.h"
#import "MSALTelemetryEventStrings.h"
#import "NSOrderedSet+MSALExtensions.h"

@implementation MSALTelemetryAPIEvent

//- (void)setResultStatus:(MSALAuthenticationResultStatus)status
//{
//    NSString* statusStr = nil;
//    switch (status) {
//        case AD_SUCCEEDED:
//            statusStr = AD_TELEMETRY_VALUE_SUCCEEDED;
//            [self setProperty:AD_TELEMETRY_KEY_IS_SUCCESSFUL value:AD_TELEMETRY_VALUE_YES];
//            break;
//        case AD_FAILED:
//            statusStr = AD_TELEMETRY_VALUE_FAILED;
//            [self setProperty:AD_TELEMETRY_KEY_IS_SUCCESSFUL value:AD_TELEMETRY_VALUE_NO];
//            break;
//        case AD_USER_CANCELLED:
//            statusStr = AD_TELEMETRY_VALUE_CANCELLED;
//            [self setProperty:AD_TELEMETRY_KEY_USER_CANCEL value:AD_TELEMETRY_VALUE_YES];
//            [self setProperty:AD_TELEMETRY_KEY_IS_SUCCESSFUL value:AD_TELEMETRY_VALUE_NO];
//            break;
//        default:
//            statusStr = AD_TELEMETRY_VALUE_UNKNOWN;
//    }
//    
//    [self setProperty:AD_TELEMETRY_KEY_RESULT_STATUS value:statusStr];
//}

- (void)setCorrelationId:(NSUUID *)correlationId
{
    [self setProperty:MSAL_TELEMETRY_KEY_CORRELATION_ID value:[correlationId UUIDString]];
}

- (void)setExtendedExpiresOnSetting:(NSString *)extendedExpiresOnSetting
{
    [self setProperty:MSAL_TELEMETRY_KEY_EXTENDED_EXPIRES_ON_SETTING value:extendedExpiresOnSetting];
}

//- (void)setUserInformation:(MSALUserInformation *)userInfo
//{
//    [self setProperty:AD_TELEMETRY_KEY_USER_ID value:[[userInfo userId] adComputeSHA256]];
//    [self setProperty:AD_TELEMETRY_KEY_TENANT_ID value:[[userInfo tenantId] adComputeSHA256]];
//    [self setProperty:AD_TELEMETRY_KEY_IDP value:[userInfo identityProvider]];
//}

- (void)setUserId:(NSString *)userId
{
    [self setProperty:MSAL_TELEMETRY_KEY_USER_ID value:[userId msalComputeSHA256]];
}

- (void)setClientId:(NSString *)clientId
{
    [self setProperty:MSAL_TELEMETRY_KEY_CLIENT_ID value:clientId];
}

- (void)setIsExtendedLifeTimeToken:(NSString *)isExtendedLifeToken
{
    [self setProperty:MSAL_TELEMETRY_KEY_IS_EXTENED_LIFE_TIME_TOKEN value:isExtendedLifeToken];
}

- (void)setErrorCode:(NSString *)errorCode
{
    [self setProperty:MSAL_TELEMETRY_KEY_API_ERROR_CODE value:errorCode];
}

- (void)setProtocolCode:(NSString *)protocolCode
{
    [self setProperty:MSAL_TELEMETRY_KEY_PROTOCOL_CODE value:protocolCode];
}

- (void)setErrorDescription:(NSString *)errorDescription
{
    [self setProperty:MSAL_TELEMETRY_KEY_ERROR_DESCRIPTION value:errorDescription];
}

- (void)setErrorDomain:(NSString *)errorDomain
{
    [self setProperty:MSAL_TELEMETRY_KEY_ERROR_DOMAIN value:errorDomain];
}

- (void)setAuthorityValidationStatus:(NSString *)status
{
    [self setProperty:MSAL_TELEMETRY_KEY_AUTHORITY_VALIDATION_STATUS value:status];
}

- (void)setAuthority:(NSString *)authority
{
    [self setProperty:MSAL_TELEMETRY_KEY_AUTHORITY value:authority];
    
    // set authority type
    NSString *authorityType = MSAL_TELEMETRY_VALUE_AUTHORITY_AAD;
//    if ([ADHelpers isADFSInstance:authority])
//    {
//        authorityType = MSAL_TELEMETRY_VALUE_AUTHORITY_ADFS;
//    }
    [self setProperty:MSAL_TELEMETRY_KEY_AUTHORITY_TYPE value:authorityType];
}

- (void)setGrantType:(NSString *)grantType
{
    [self setProperty:MSAL_TELEMETRY_KEY_GRANT_TYPE value:grantType];
}

- (void)setAPIStatus:(NSString *)status
{
    [self setProperty:MSAL_TELEMETRY_KEY_API_STATUS value:status];
}

- (void)setApiId:(NSString *)apiId
{
    [self setProperty:MSAL_TELEMETRY_KEY_API_ID value:apiId];
}

//- (void)setPromptBehavior:(ADPromptBehavior)promptBehavior
//{
//    NSString* promptBehaviorString = nil;
//    switch (promptBehavior) {
//        case AD_PROMPT_AUTO:
//            promptBehaviorString = @"AD_PROMPT_AUTO";
//            break;
//        case AD_PROMPT_ALWAYS:
//            promptBehaviorString = @"AD_PROMPT_ALWAYS";
//            break;
//        case AD_PROMPT_REFRESH_SESSION:
//            promptBehaviorString = @"AD_PROMPT_REFRESH_SESSION";
//            break;
//        case AD_FORCE_PROMPT:
//            promptBehaviorString = @"AD_FORCE_PROMPT";
//            break;
//        default:
//            promptBehaviorString = AD_TELEMETRY_VALUE_UNKNOWN;
//    }
//    
//    [self setProperty:AD_TELEMETRY_KEY_PROMPT_BEHAVIOR value:promptBehaviorString];
//}

@end
