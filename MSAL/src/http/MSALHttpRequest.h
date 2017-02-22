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

#import <Foundation/Foundation.h>

@class MSALHttpResponse;

extern NSString *const MSALHttpHeaderAccept;
extern NSString *const MSALHttpHeaderApplicationJSON;

extern NSString *const MSALHttpHeaderContentType;
extern NSString *const MSALHttpHeaderFormURLEncoded;

/*! The completion block declaration. */
typedef void(^MSALHttpRequestCallback)(MSALHttpResponse *response, NSError  *error);


@interface MSALHttpRequest : NSObject

@property (readonly) id<MSALRequestContext> context;

@property (readonly) NSURLSession *session;
@property (readonly) NSURL *endpointURL;

@property (readonly) BOOL isGetRequest;

/*! Key/value pairs that are included in the HTTP headers of the request */
@property (copy) NSDictionary<NSString *, NSString *> *headers;

/*! Key/value pairs that are url encoded and included in the body of a POST request */
@property (copy) NSDictionary<NSString *, NSString *> *bodyParameters;

/*! Key/value pairs that are included in a GET request */
@property (copy) NSDictionary<NSString *, NSString *> *queryParameters;

- (id)initWithURL:(NSURL *)endpoint context:(id<MSALRequestContext>)context;

// Add value to header field of the request. If a value was previously set, the
// supplied value is appeneded with comma delimeter
- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field;

// Set value to header field of the request. If a value was previously set,
// Any existing value will be replaced by the new value
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;

// Query parameter setters
- (void)setValue:(NSString *)value forQueryParameter:(NSString *)parameter;
- (void)removeQueryParameter:(NSString *)parameter;

// Body parameter setters
- (void)setValue:(NSString *)value forBodyParameter:(NSString *)parameter;
- (void)removeBodyParameter:(NSString *)parameter;

// Send 
- (void)sendPost:(MSALHttpRequestCallback)completionHandler;
- (void)sendGet:(MSALHttpRequestCallback)completionHandler;

- (void)resend:(MSALHttpRequestCallback)completionHandler;

// Sets Accept:Application/json to the header.
- (void)setAcceptJSON;

@end


