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

#import "MSALTelemetryHttpEvent.h"
#import "MSALTelemetryEventStrings.h"
#import "NSString+MSALHelperMethods.h"
#import "NSDictionary+MSALExtensions.h"
#import "NSURL+MSALExtensions.h"

@implementation MSALTelemetryHttpEvent

- (void)setHttpMethod:(NSString *)method
{
    [self setProperty:MSAL_TELEMETRY_KEY_HTTP_METHOD value:method];
}

- (void)setHttpURL:(NSURL *)url
{
    NSURL *urlWithoutParameters = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@%@", url.scheme, [url msalHostWithPort], url.path]];
    [self setProperty:MSAL_TELEMETRY_KEY_HTTP_PATH value:[urlWithoutParameters scrubbedHttpPath]];
}

- (void)setHttpRequestIdHeader:(NSString *)requestIdHeader
{
    [self setProperty:MSAL_TELEMETRY_KEY_HTTP_REQUEST_ID_HEADER value:requestIdHeader];
}

- (void)setHttpResponseCode:(NSString *)code
{
    [self setProperty:MSAL_TELEMETRY_KEY_HTTP_RESPONSE_CODE value:code];
}

- (void)setHttpErrorCode:(NSString *)code
{
    self.errorInEvent = ![NSString msalIsStringNilOrBlank:code];
    
    [self setProperty:MSAL_TELEMETRY_KEY_HTTP_RESPONSE_CODE value:code];
}

- (void)setOAuthErrorCode:(MSALHttpResponse *)response
{
    if (!response.body)
    {
        return;
    }
    
    NSError *jsonError  = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:response.body options:0 error:&jsonError];
    
    if (!jsonObject || ![jsonObject isKindOfClass:[NSDictionary class]])
    {
        return;
    }
    
    NSString *oauthError = [(NSDictionary *)jsonObject objectForKey:OAUTH2_ERROR];
    [self setProperty:MSAL_TELEMETRY_KEY_OAUTH_ERROR_CODE value:oauthError];
    
    self.errorInEvent = ![NSString msalIsStringNilOrBlank:oauthError];
}

- (void)setHttpResponseMethod:(NSString *)method
{
    [self setProperty:MSAL_TELEMETRY_KEY_HTTP_RESPONSE_METHOD value:method];
}

- (void)setHttpRequestQueryParams:(NSString *)params
{
    if ([NSString msalIsStringNilOrBlank:params])
    {
        return;
    }
    
    NSArray *parameterKeys = [[NSDictionary msalURLFormDecode:params] allKeys];
    
    [self setProperty:MSAL_TELEMETRY_KEY_REQUEST_QUERY_PARAMS value:[parameterKeys componentsJoinedByString:@";"]];
}

- (void)setHttpUserAgent:(NSString *)userAgent
{
    [self setProperty:MSAL_TELEMETRY_KEY_USER_AGENT value:userAgent];
}

- (void)setHttpErrorDomain:(NSString *)errorDomain
{
    [self setProperty:MSAL_TELEMETRY_KEY_HTTP_ERROR_DOMAIN value:errorDomain];
}

@end
