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

#import <Foundation/Foundation.h>
#import "MSALTelemetryBaseEvent.h"
#import "MSALHttpResponse.h"

@interface MSALTelemetryHttpEvent : MSALTelemtryBaseEvent

- (void)setHttpMethod:(NSString *)method;
- (void)setHttpURL:(NSURL *)url;
- (void)setHttpRequestIdHeader:(NSString *)requestIdHeader;
- (void)setHttpResponseCode:(NSString *)code;
- (void)setHttpResponseMethod:(NSString *)method;
- (void)setHttpRequestQueryParams:(NSString *)params;
- (void)setHttpUserAgent:(NSString *)userAgent;
- (void)setHttpErrorCode:(NSString *)code;
- (void)setOAuthErrorCode:(MSALHttpResponse *)response;
- (void)setHttpErrorDomain:(NSString *)errorDomain;

@end
