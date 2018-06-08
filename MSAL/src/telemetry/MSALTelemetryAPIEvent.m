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
#import "MSIDTelemetryEventStrings.h"
#import "NSOrderedSet+MSALExtensions.h"
#import "NSURL+MSIDExtensions.h"

@implementation MSALTelemetryAPIEvent

- (void)setUser:(MSALAccount *)user
{
    [self setProperty:MSID_TELEMETRY_KEY_USER_ID value:[user username]];
}

- (void)setLoginHint:(NSString *)loginHint
{
    [self setProperty:MSID_TELEMETRY_KEY_LOGIN_HINT value:loginHint];
}

- (void)setAuthorityType:(MSALAuthorityType)authorityType
{
    NSString *authorityTypeString;
    
    // set authority type
    switch (authorityType) {
        case AADAuthority:
            authorityTypeString = MSID_TELEMETRY_VALUE_AUTHORITY_AAD;
            
            break;
            
        case ADFSAuthority:
            authorityTypeString = MSID_TELEMETRY_VALUE_AUTHORITY_ADFS;
            break;
            
        case B2CAuthority:
            authorityTypeString = MSID_TELEMETRY_VALUE_AUTHORITY_B2C;
            break;
    }
    
    [super setAuthorityType:authorityTypeString];
}

- (void)setMSALApiId:(MSALTelemetryApiId)apiId
{
    [super setApiId:[NSString stringWithFormat:@"%d", (int)apiId]];
}

- (void)setUIBehavior:(MSALUIBehavior)uiBehavior
{
    NSString *uiBehaviorString = nil;
    
    switch (uiBehavior) {
        case MSALForceLogin:
            uiBehaviorString = @"force_login";
            break;
            
        case MSALForceConsent:
            uiBehaviorString = @"force_consent";
            break;
            
        case MSALSelectAccount:
            uiBehaviorString = @"select_account";
    }
    
    [self setProperty:MSID_TELEMETRY_KEY_UI_BEHAVIOR value:uiBehaviorString];
}

#pragma mark -
#pragma mark log error

- (void)setErrorCode:(MSALErrorCode)errorCode
{
    self.errorInEvent = YES;
    [self setProperty:MSID_TELEMETRY_KEY_API_ERROR_CODE value:MSALStringForErrorCode(errorCode)];
}

@end
