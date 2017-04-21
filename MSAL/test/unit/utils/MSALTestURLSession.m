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

#import "MSALTestURLSession.h"
#import "MSALTestURLSessionDataTask.h"
#import "NSString+MSALHelperMethods.h"
#import "NSDictionary+MSALExtensions.h"
#import "NSDictionary+MSALTestUtil.h"
#import "NSURL+MSALExtensions.h"

@implementation MSALTestURLResponse

+ (MSALTestURLResponse *)requestURLString:(NSString *)requestUrlString
                           requestHeaders:(NSDictionary *)requestHeaders
                        requestParamsBody:(id)requestParams
                        responseURLString:(NSString *)responseUrlString
                             responseCode:(NSInteger)responseCode
                         httpHeaderFields:(NSDictionary *)headerFields
                         dictionaryAsJSON:(NSDictionary *)data
{
    MSALTestURLResponse *response = [MSALTestURLResponse new];
    [response setRequestURL:[NSURL URLWithString:requestUrlString]];
    [response setResponseURL:responseUrlString code:responseCode headerFields:headerFields];
    response->_requestHeaders = requestHeaders;
    response->_requestParamsBody = requestParams;
    [response setJSONResponse:data];
    
    return response;
}

+ (MSALTestURLResponse *)request:(NSURL *)request
                  requestHeaders:(NSDictionary *)requestHeaders
               requestParamsBody:(id)requestParams
                respondWithError:(NSError *)error
{
    MSALTestURLResponse * response = [MSALTestURLResponse new];
    
    [response setRequestURL:request];
    response->_error = error;
    response->_requestHeaders = requestHeaders;
    response->_requestParamsBody = requestParams;
    
    return response;
}

+ (MSALTestURLResponse *)request:(NSURL *)request
                        response:(NSURLResponse *)urlResponse
                     reponseData:(NSData *)data
{
    MSALTestURLResponse * response = [MSALTestURLResponse new];
    
    [response setRequestURL:request];
    response->_response = urlResponse;
    response->_responseData = data;
    
    return response;
}

+ (MSALTestURLResponse *)request:(NSURL *)request
                         reponse:(NSURLResponse *)urlResponse
{
    MSALTestURLResponse * response = [MSALTestURLResponse new];
    
    [response setRequestURL:request];
    response->_response = urlResponse;
    
    return response;
}

+ (MSALTestURLResponse *)serverNotFoundResponseForURLString:(NSString *)requestUrlString
                                             requestHeaders:(NSDictionary *)requestHeaders
                                          requestParamsBody:(id)requestParams
{
    
    MSALTestURLResponse *response = [MSALTestURLResponse request:[NSURL URLWithString:requestUrlString]
                                                  requestHeaders:requestHeaders
                                               requestParamsBody:requestParams
                                                respondWithError:[NSError errorWithDomain:NSURLErrorDomain
                                                                                     code:NSURLErrorCannotFindHost
                                                                                 userInfo:nil]];
    return response;
}

- (void)setResponseURL:(NSString *)urlString
                  code:(NSInteger)code
          headerFields:(NSDictionary *)headerFields
{
    NSHTTPURLResponse * response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:urlString]
                                                               statusCode:code
                                                              HTTPVersion:@"1.1"
                                                             headerFields:headerFields];
    
    _response = response;
}

- (void)setJSONResponse:(id)jsonResponse
{
    if (!jsonResponse)
    {
        _responseData = nil;
        return;
    }
    
    NSError *error = nil;
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:jsonResponse options:0 error:&error];
    _responseData = responseData;
    
    NSAssert(_responseData, @"Invalid JSON object set for test response! %@", error);
}

- (void)setRequestURL:(NSURL *)requestURL
{
    
    _requestURL = requestURL;
    NSString *query = [requestURL query];
    _QPs = [NSString msalIsStringNilOrBlank:query] ? nil : [NSDictionary msalURLFormDecode:query];
}

- (BOOL)matchesURL:(NSURL *)url
{
    // Start with making sure the base URLs match up
    if ([url.scheme caseInsensitiveCompare:_requestURL.scheme] != NSOrderedSame)
    {
        return NO;
    }
    
    if ([[url msalHostWithPort] caseInsensitiveCompare:[_requestURL msalHostWithPort]] != NSOrderedSame)
    {
        return NO;
    }
    
    // Then the relative portions
    if ([url.relativePath caseInsensitiveCompare:_requestURL.relativePath] != NSOrderedSame)
    {
        return NO;
    }
    
    // And lastly, the tricky part. Query Params can come in any order so we need to process them
    // a bit instead of just a string compare
    NSString *query = [url query];
    if (![NSString msalIsStringNilOrBlank:query])
    {
        NSDictionary *QPs = [NSDictionary msalURLFormDecode:query];
        if (![QPs isEqualToDictionary:_QPs])
        {
            return NO;
        }
    }
    else if (_QPs)
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)matchesBody:(NSData *)body
{
    if (_requestParamsBody)
    {
        NSString * string = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        id obj = [NSDictionary msalURLFormDecode:string];
        return [obj isEqual:_requestParamsBody];
    }
    
    if (_requestBody)
    {
        return [_requestBody isEqualToData:body];
    }
    
    return YES;
}

- (BOOL)matchesHeaders:(NSDictionary *)headers
{
    if (!_requestHeaders)
    {
        if (!headers || headers.count == 0)
        {
            return YES;
        }
        // This wiil spit out to console the extra stuff that we weren't expecting
        [@{} compareDictionary:headers];
        return NO;
    }
    
    return [_requestHeaders compareDictionary:headers];
}

@end


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
@implementation NSURLSession (TestSessionOverride)

- (id)init
{
    @throw @"This constructor should not be used. If you're in test code use +[MSALTestURLSession createMockSession] if you're in product code use +[MSALURLSession createMSALSession:]";
}

+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration
                                  delegate:(id<NSURLSessionDelegate>)delegate
                             delegateQueue:(NSOperationQueue *)queue
{
    // We're not in the context of a test class here, so XCTAssert can't be used,
    // however I still want to make sure we're not inadvertantly creating any
    // NSURLSessions without the proper security settings.
    
    // If you're hitting this fix whatever code path is creating NSURLSessions
    // directly instad of using +[MSALURLSession createMSALSession:]
    assert(configuration != nil);
    assert(configuration.TLSMinimumSupportedProtocol == kTLSProtocol12);
    
    (void)configuration;
    return (NSURLSession *)[[MSALTestURLSession alloc] initWithDelegate:delegate delegateQueue:queue];
}

@end
#pragma clang diagnostic pop



@implementation MSALTestURLSession

+ (NSURLSession *)createMockSession
{
    return (NSURLSession *)[[MSALTestURLSession alloc] initWithDelegate:nil delegateQueue:nil];
}

static NSMutableArray *s_responses = nil;

- (id)initWithDelegate:(id)delegate delegateQueue:(NSOperationQueue *)delegateQueue
{
    if (!(self = [super init]))
    {
        return nil;
    }
    self.delegate = delegate;
    self.delegateQueue = delegateQueue;
    
    return self;
}

+ (void)initialize
{
    s_responses = [NSMutableArray new];
}

+ (void)addResponse:(MSALTestURLResponse *)response
{
    [s_responses addObject:response];
}


+ (MSALTestURLResponse *)removeResponseForRequest:(NSURLRequest *)request
{
    NSUInteger cResponses = [s_responses count];
    
    NSURL *requestURL = [request URL];
    
    NSData *body = [request HTTPBody];
    NSDictionary *headers = [request allHTTPHeaderFields];
    
    for (NSUInteger i = 0; i < cResponses; i++)
    {
        id obj = [s_responses objectAtIndex:i];
        MSALTestURLResponse *response = nil;
        
        if ([obj isKindOfClass:[MSALTestURLResponse class]])
        {
            response = (MSALTestURLResponse *)obj;
            
            if ([response matchesURL:requestURL] && [response matchesHeaders:headers] && [response matchesBody:body])
            {
                [s_responses removeObjectAtIndex:i];
                return response;
            }
        }
        
        if ([obj isKindOfClass:[NSMutableArray class]])
        {
            NSMutableArray *subResponses = [s_responses objectAtIndex:i];
            response = [subResponses objectAtIndex:0];
            
            if ([response matchesURL:requestURL] && [response matchesHeaders:headers] && [response matchesBody:body])
            {
                [subResponses removeObjectAtIndex:0];
                if ([subResponses count] == 0)
                {
                    [s_responses removeObjectAtIndex:i];
                }
                return response;
            }
        }
    }
    
    // This class is used in the test target only. If you're seeing this outside the test target that means you linked in the file wrong
    // take it out!
    //
    // No unit tests are allowed to hit network. This is done to ensure reliability of the test code. Tests should run quickly and
    // deterministically. If you're hitting this assert that means you need to add an expected request and response to ADTestURLConnection
    // using the ADTestRequestReponse class and add it using -[ADTestURLConnection addExpectedRequestResponse:] if you have a single
    // request/response or -[ADTestURLConnection addExpectedRequestsAndResponses:] if you have a series of network requests that you need
    // to ensure happen in the proper order.
    //
    // Example:
    //
    // MSALTestRequestResponse *response = [MSALTestRequestResponse requestURLString:@"https://requestURL"
    //                                                             responseURLString:@"https://idontknowwhatthisshouldbe.com"
    //                                                                  responseCode:400
    //                                                              httpHeaderFields:@{}
    //                                                              dictionaryAsJSON:@{@"tenant_discovery_endpoint" : @"totally valid!"}];
    //
    //  [MSALTestURLSession addResponse:response];
    
    NSAssert(nil, @"did not find a matching response for %@", requestURL.absoluteString);
    
    LOG_ERROR(nil, @"No matching response found, request url = %@", request.URL);
    
    return nil;
}




- (void)dispatchIfNeed:(void (^)(void))block
{
    if (_delegateQueue) {
        [_delegateQueue addOperationWithBlock:block];
    }
    else
    {
        block();
    }
}

#pragma mark - DataTask creation
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(MSALTestHttpCompletionBlock)completionHandler
{
    MSALTestURLSessionDataTask *task = [[MSALTestURLSessionDataTask alloc] initWithRequest:request
                                                                                   session:self completionHandler:completionHandler];
    
    return (NSURLSessionDataTask *)task;
}


#pragma mark - NSURLSession

// Invalidate
- (void)invalidateAndCancel{}


// Runtime methods for NSURLSession, needs to declare since this is a NSObject, not :NSURLSession
// For now though, of no real usage
- (void)set_isSharedSession:(BOOL)shared
{
    (void)shared;
}

- (void)_removeProtocolClassForDefaultSession:(Class)arg1
{
    (void)arg1;
}
- (bool)_prependProtocolClassForDefaultSession:(Class)arg1
{
    (void)arg1;
    return NO;
}


@end
