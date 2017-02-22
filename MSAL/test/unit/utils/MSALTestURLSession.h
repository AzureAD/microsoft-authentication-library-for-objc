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

typedef void (^MSALTestHttpCompletionBlock)(NSData *data, NSURLResponse *response, NSError *error);

@interface MSALTestURLResponse : NSObject
{
    @public
    NSURL *_requestURL;
    id _requestJSONBody;
    id _requestParamsBody;
    NSDictionary *_requestHeaders;
    NSData *_requestBody;
    NSDictionary *_QPs;
    NSDictionary *_expectedRequestHeaders;
    NSData *_responseData;
    NSURLResponse *_response;
    NSError *_error;
}

+ (MSALTestURLResponse*)requestURLString:(NSString *)requestUrlString
                     responseURLString:(NSString *)responseUrlString
                          responseCode:(NSInteger)responseCode
                      httpHeaderFields:(NSDictionary *)headerFields
                      dictionaryAsJSON:(NSDictionary *)data;

+ (MSALTestURLResponse*)requestURLString:(NSString *)requestUrlString
                       requestJSONBody:(id)requestJSONBody
                     responseURLString:(NSString *)responseUrlString
                          responseCode:(NSInteger)responseCode
                      httpHeaderFields:(NSDictionary *)headerFields
                      dictionaryAsJSON:(NSDictionary *)data;

+ (MSALTestURLResponse*)requestURLString:(NSString *)requestUrlString
                        requestHeaders:(NSDictionary *)requestHeaders
                     requestParamsBody:(id)requestParams
                     responseURLString:(NSString *)responseUrlString
                          responseCode:(NSInteger)responseCode
                      httpHeaderFields:(NSDictionary *)headerFields
                      dictionaryAsJSON:(NSDictionary *)data;

+ (MSALTestURLResponse*)request:(NSURL *)request
                     response:(NSURLResponse *)response
                  reponseData:(NSData *)data;

+ (MSALTestURLResponse*)request:(NSURL *)request
                      reponse:(NSURLResponse *)response;

+ (MSALTestURLResponse*)request:(NSURL *)request
             respondWithError:(NSError *)error;

+ (MSALTestURLResponse*)serverNotFoundResponseForURLString:(NSString *)requestURLString;

+ (MSALTestURLResponse*)responseValidAuthority:(NSString *)authority;
+ (MSALTestURLResponse*)responseInvalidAuthority:(NSString *)authority;

+ (MSALTestURLResponse*)responseValidDrsPayload:(NSString *)domain
                                      onPrems:(BOOL)onPrems
                passiveAuthenticationEndpoint:(NSString *)passiveAuthEndpoint;
+ (MSALTestURLResponse*)responseInvalidDrsPayload:(NSString *)domain
                                        onPrems:(BOOL)onPrems;
+ (MSALTestURLResponse*)responseUnreachableDrsService:(NSString *)domain
                                            onPrems:(BOOL)onPrems;
+ (MSALTestURLResponse*)responseValidWebFinger:(NSString *)passiveEndpoint
                                   authority:(NSString *)authority;
+ (MSALTestURLResponse*)responseInvalidWebFinger:(NSString *)passiveEndpoint
                                     authority:(NSString *)authority;
+ (MSALTestURLResponse*)responseInvalidWebFingerNotTrusted:(NSString *)passiveEndpoint
                                               authority:(NSString *)authority;
+ (MSALTestURLResponse*)responseUnreachableWebFinger:(NSString *)passiveEndpoint
                                         authority:(NSString *)authority;

@end

@interface MSALTestURLSession : NSObject

@property id delegate;
@property NSOperationQueue* delegateQueue;

- (id)initWithDelegate:(id)delegate delegateQueue:(NSOperationQueue *)delegateQueue;

// This adds an expected request, and response to it.
+ (void)addResponse:(MSALTestURLResponse *)response;


// Helper method to retrieve a response for a request
+ (MSALTestURLResponse *)removeResponseForRequest:(NSURLRequest *)request;

// Helper dispatch method that URLSessionTask can utilize
- (void)dispatchIfNeed:(void (^)(void))block;

@end
