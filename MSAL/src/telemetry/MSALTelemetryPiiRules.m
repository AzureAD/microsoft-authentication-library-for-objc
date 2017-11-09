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

#import "MSALTelemetryPiiRules.h"
#import "MSALTelemetryEventStrings.h"

static NSSet *_piiFields;

@implementation MSALTelemetryPiiRules

+ (void)initialize
{
    _piiFields = [[NSSet alloc] initWithArray:@[MSAL_TELEMETRY_KEY_TENANT_ID,
                                                MSAL_TELEMETRY_KEY_USER_ID,
                                                MSAL_TELEMETRY_KEY_DEVICE_ID,
                                                MSAL_TELEMETRY_KEY_LOGIN_HINT,
                                                MSAL_TELEMETRY_KEY_CLIENT_ID,
                                                MSAL_TELEMETRY_KEY_ERROR_DESCRIPTION,
                                                MSAL_TELEMETRY_KEY_HTTP_PATH,
                                                MSAL_TELEMETRY_KEY_REQUEST_QUERY_PARAMS,
                                                MSAL_TELEMETRY_KEY_AUTHORITY]];
}


#pragma mark - Public

+ (BOOL)isPii:(NSString *)propertyName
{
    return [_piiFields containsObject:propertyName];
}

@end
