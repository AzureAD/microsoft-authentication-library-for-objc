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

#import "MSALHttpRequest.h"
#import "MSALHttpResponse.h"
#import "NSDictionary+MSALExtensions.h"
#import "MSALLogger+Internal.h"
#import "MSALOAuth2Constants.h"
#import "MSALTelemetry+Internal.h"
#import "MSALTelemetryEventStrings.h"
#import "NSString+MSALHelperMethods.h"
#import "MSALAuthority.h"
#import "MSALTelemetryHttpEvent.h"
#import "MSALTelemetry+Internal.h"

NSString *const MSALHttpHeaderAccept = @"Accept";
NSString *const MSALHttpHeaderApplicationJSON = @"application/json";

NSString *const MSALHttpHeaderContentType = @"Content-Type";
NSString *const MSALHttpHeaderFormURLEncoded = @"application/x-www-form-urlencoded";

@interface MSALHttpRequest()
{
    NSMutableDictionary *_bodyParameters;
    NSMutableDictionary<NSString *, NSString *> *_headers;
    NSMutableDictionary *_queryParameters;
    
    NSTimeInterval _timeOutInterval;
    NSURLRequestCachePolicy _cachePolicy;
}

@end

@implementation MSALHttpRequest

static NSString *const s_kHttpHeaderDelimeter = @",";

- (id)initWithURL:(NSURL *)endpoint context:(id<MSALRequestContext>)context
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _context = context;
    
    _endpointURL = endpoint;
    _session = [context urlSession];
    _headers = [NSMutableDictionary new];
    _bodyParameters = [NSMutableDictionary new];
    _queryParameters = [NSMutableDictionary new];
    
    // Default timeout for MSALHttpRequest is 30 seconds
    _timeOutInterval = 30;
    _cachePolicy = NSURLRequestReloadIgnoringCacheData;
    
    return self;
}

#pragma mark - Headers

- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field
{
    if (!value)
    {
        return;
    }
    
    NSString *existingValue = [_headers valueForKey:field];
    if (existingValue)
    {
        NSMutableString *newValue = [existingValue mutableCopy];
        [newValue appendString:s_kHttpHeaderDelimeter];
        [newValue appendString:value];
        
        [_headers setValue:newValue forKey:field];
    }
    else
    {
        [_headers setValue:value forKey:field];
    }
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field
{
    [_headers setValue:value forKey:field];
}

#pragma mark - Query parameters
- (void)setValue:(NSString *)value forQueryParameter:(NSString *)parameter
{
    [_queryParameters setValue:value forKey:parameter];
}

- (void)removeQueryParameter:(NSString *)parameter
{
    [_queryParameters removeObjectForKey:parameter];
}

#pragma mark - Body parameters

- (void)setValue:(NSString *)value forBodyParameter:(NSString *)parameter
{
    [_bodyParameters setValue:value forKey:parameter];
}

- (void)removeBodyParameter:(NSString *)parameter
{
    [_bodyParameters removeObjectForKey:parameter];
}

#pragma mark - Send

- (void)send:(MSALHttpRequestCallback)completionHandler
{
    // Telemetry
    [[MSALTelemetry sharedInstance] startEvent:[_context telemetryRequestId] eventName:MSAL_TELEMETRY_EVENT_HTTP_REQUEST];
    
    MSALTelemetryHttpEvent *event = [[MSALTelemetryHttpEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_HTTP_REQUEST
                                                                       context:_context];
    
    [_headers addEntriesFromDictionary:[MSALLogger msalId]];
    
    if (_context)
    {
        _headers[OAUTH2_CORRELATION_ID_REQUEST] = @"true";
        _headers[OAUTH2_CORRELATION_ID_REQUEST_VALUE] = [_context.correlationId UUIDString];
    }
    
    NSURL *newURL = nil;
    if (_isGetRequest && [_queryParameters allKeys].count > 0)
    {
        NSString *newURLString = [NSString stringWithFormat:@"%@?%@", _endpointURL.absoluteString, [_queryParameters msalURLFormEncode]];
        newURL = [NSURL URLWithString:newURLString];
    }
    
    NSData *bodyData = nil;
    if (!_isGetRequest && _bodyParameters)
    {
        bodyData = [[_bodyParameters msalURLFormEncode] dataUsingEncoding:NSUTF8StringEncoding];
        [self setContentTypeFormURLEncoded];
    }
    
    newURL = newURL? newURL : _endpointURL;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:newURL
                                                           cachePolicy:_cachePolicy
                                                       timeoutInterval:_timeOutInterval];
    request.HTTPMethod = _isGetRequest ? @"GET" : @"POST";
    request.allHTTPHeaderFields = _headers;
    request.HTTPBody = bodyData;
    
    [event setHttpMethod:request.HTTPMethod];
    [event setHttpURL:newURL];
    
    LOG_INFO(_context, @"HTTP request %@", [MSALAuthority isKnownHost:request.URL] ? request.URL.absoluteString : [request.URL.absoluteString msalShortSHA256Hex]);
    LOG_INFO_PII(_context, @"HTTP request %@", request.URL.absoluteString);
    
    NSURLSessionDataTask *task = [_session dataTaskWithRequest:request
                                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                                  {
                                      if (error)
                                      {
                                          [event setHttpErrorCode:[NSString stringWithFormat: @"%ld", (long)[error code]]];
                                          [event setHttpErrorDomain:[error domain]];
                                          [[MSALTelemetry sharedInstance] stopEvent:[_context telemetryRequestId] event:event];
                                          
                                          completionHandler(nil, error);
                                          return;
                                      }
                                      
                                      MSALHttpResponse *msalResponse = [[MSALHttpResponse alloc] initWithResponse:(NSHTTPURLResponse *)response
                                                                                                             data:data
                                                                                                            error:&error];
                                      
                                      [event setHttpResponseCode:[NSString stringWithFormat: @"%ld", (long)[msalResponse statusCode]]];
                                      [event setHttpRequestIdHeader:[msalResponse.headers objectForKey:OAUTH2_CORRELATION_ID_REQUEST_VALUE]];
                                      [event setOAuthErrorCode:msalResponse];
                                      
                                      [[MSALTelemetry sharedInstance] stopEvent:[_context telemetryRequestId] event:event];
                                      
                                      completionHandler(msalResponse, error);
                                  }];
    [task resume];
}

- (void)sendGet:(MSALHttpRequestCallback)completionHandler
{
    _isGetRequest = YES;
    [self send:completionHandler];
}


- (void)sendPost:(MSALHttpRequestCallback)completionHandler
{
    _isGetRequest = NO;
    [self send:completionHandler];
}


- (void)resend:(MSALHttpRequestCallback)completionHandler
{
    if (_isGetRequest)
    {
        [self sendGet:completionHandler];
    }
    else
    {
        [self sendPost:completionHandler];
    }
}

- (void)setAcceptJSON;
{
    [_headers setValue:MSALHttpHeaderApplicationJSON forKey:MSALHttpHeaderAccept];
}

- (void)setContentTypeFormURLEncoded;
{
    [_headers setValue:MSALHttpHeaderFormURLEncoded forKey:MSALHttpHeaderContentType];
}

@end
