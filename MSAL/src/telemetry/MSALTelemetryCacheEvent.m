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

#import "MSALTelemetryCacheEvent.h"
#import "MSALTelemetryEventStrings.h"

@implementation MSALTelemetryCacheEvent

- (void)setTokenType:(NSString *)tokenType
{
    [self setProperty:MSAL_TELEMETRY_KEY_TOKEN_TYPE value:tokenType];
}

- (void)setStatus:(NSString *)status
{
    [self setProperty:MSAL_TELEMETRY_KEY_RESULT_STATUS value:status];
}

- (void)setIsRT:(NSString *)isRT
{
    [self setProperty:MSAL_TELEMETRY_KEY_IS_RT value:isRT];
}

- (void)setIsMRRT:(NSString *)isMRRT
{
    [self setProperty:MSAL_TELEMETRY_KEY_IS_MRRT value:isMRRT];
}

- (void)setIsFRT:(NSString *)isFRT
{
    [self setProperty:MSAL_TELEMETRY_KEY_IS_FRT value:isFRT];
}

- (void)setRTStatus:(NSString *)status
{
    [self setProperty:MSAL_TELEMETRY_KEY_RT_STATUS value:status];
}

- (void)setMRRTStatus:(NSString *)status
{
    [self setProperty:MSAL_TELEMETRY_KEY_MRRT_STATUS value:status];
}

- (void)setFRTStatus:(NSString *)status
{
    [self setProperty:MSAL_TELEMETRY_KEY_FRT_STATUS value:status];
}

@end
