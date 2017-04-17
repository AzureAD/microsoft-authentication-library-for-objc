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

#import "MSALTelemetryUIEvent.h"
#import "MSALTelemetryEventStrings.h"
#import "NSString+MSALHelperMethods.h"

@implementation MSALTelemetryUIEvent

- (void)setLoginHint:(NSString *)hint
{
    [self setProperty:MSAL_TELEMETRY_KEY_LOGIN_HINT value:[hint msalComputeSHA256Hex]];
}

- (void)setNtlm:(NSString *)ntlmHandled
{
    [self setProperty:MSAL_TELEMETRY_KEY_NTLM_HANDLED value:ntlmHandled];
}

- (void)setIsCancelled:(BOOL)cancelled
{
    [self setProperty:MSAL_TELEMETRY_KEY_UI_CANCELLED value:cancelled ? MSAL_TELEMETRY_VALUE_YES : MSAL_TELEMETRY_VALUE_NO];
}

@end
