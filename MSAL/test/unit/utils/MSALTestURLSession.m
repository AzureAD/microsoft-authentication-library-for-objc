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

@implementation MSALTestURLResponse

+ (MSALTestURLResponse *)request:(NSURL *)request
               requestJSONBody:(NSDictionary *)requestBody
                      response:(NSURLResponse *)urlResponse
                   reponseData:(NSData *)data
{
    MSALTestURLResponse * response = [MSALTestURLResponse new];
    [response setRequestURL:request];
    response->_requestJSONBody = requestBody;
    response->_response = urlResponse;
    response->_responseData = data;
    
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

+ (MSALTestURLResponse *)serverNotFoundResponseForURLString:(NSString *)requestURLString
{
    NSURL *requestURL = [NSURL URLWithString:requestURLString];
    MSALTestURLResponse *response = [MSALTestURLResponse request:requestURL
                                                  requestHeaders:nil
                                               requestParamsBody:nil
                                            respondWithError:[NSError errorWithDomain:NSURLErrorDomain
                                                                                 code:NSURLErrorCannotFindHost
                                                                             userInfo:nil]];
    return response;
}

+ (MSALTestURLResponse *)responseValidAuthority:(NSString *)authority
{
    NSString* authorityValidationURL = [NSString stringWithFormat:@"https://login.windows.net/common/discovery/instance?api-version=1.0&authorization_endpoint=%@/oauth2/authorize", [authority lowercaseString]];
    MSALTestURLResponse *response = [MSALTestURLResponse requestURLString:authorityValidationURL
                                                    responseURLString:@"https://idontmatter.com"
                                                         responseCode:200
                                                     httpHeaderFields:@{}
                                                     dictionaryAsJSON:@{@"tenant_discovery_endpoint" : @"totally valid!"}];
    
    return response;
}

+ (MSALTestURLResponse *)responseInvalidAuthority:(NSString *)authority
{
    NSString* authorityValidationURL = [NSString stringWithFormat:@"https://login.windows.net/common/discovery/instance?api-version=1.0&authorization_endpoint=%@/oauth2/authorize", [authority lowercaseString]];
    MSALTestURLResponse *response = [MSALTestURLResponse requestURLString:authorityValidationURL
                                                    responseURLString:@"https://idontmatter.com"
                                                         responseCode:400
                                                     httpHeaderFields:@{}
                                                     dictionaryAsJSON:@{OAUTH2_ERROR : @"I'm an OAUTH server error!",
                                                                        OAUTH2_ERROR_DESCRIPTION : @" I'm an OAUTH error description!"}];
    
    return response;
}

+ (MSALTestURLResponse *)responseValidDrsPayload:(NSString *)domain
                                       onPrems:(BOOL)onPrems
                 passiveAuthenticationEndpoint:(NSString *)passiveAuthEndpoint
{
    NSString* validationPayloadURL = [NSString stringWithFormat:@"%@%@/enrollmentserver/contract?api-version=1.0",
                                      onPrems ? @"https://enterpriseregistration." : @"https://enterpriseregistration.windows.net/", domain];
    
    MSALTestURLResponse *response = [MSALTestURLResponse requestURLString:validationPayloadURL
                                                    responseURLString:@"https://idontmatter.com"
                                                         responseCode:200
                                                     httpHeaderFields:@{}
                                                     dictionaryAsJSON:@{@"DeviceRegistrationService" :
                                                                            @{@"RegistrationEndpoint" : @"https://idontmatter.com/EnrollmentServer/DeviceEnrollmentWebService.svc",
                                                                              @"RegistrationResourceId" : @"urn:ms-drs:UUID"
                                                                              },
                                                                        @"AuthenticationService" :
                                                                            @{@"AuthCodeEndpoint" : @"https://idontmatter.com/adfs/oauth2/authorize",
                                                                              @"TokenEndpoint" : @"https://idontmatter.com/adfs/oauth2/token"
                                                                              },
                                                                        @"IdentityProviderService" :
                                                                            @{@"PassiveAuthEndpoint" : passiveAuthEndpoint}
                                                                        }];
    return response;
}


+ (MSALTestURLResponse *)responseInvalidDrsPayload:(NSString *)domain
                                         onPrems:(BOOL)onPrems
{
    NSString* validationPayloadURL = [NSString stringWithFormat:@"%@%@/enrollmentserver/contract?api-version=1.0",
                                      onPrems ? @"https://enterpriseregistration." : @"https://enterpriseregistration.windows.net/", domain];
    
    MSALTestURLResponse *response = [MSALTestURLResponse requestURLString:validationPayloadURL
                                                    responseURLString:@"https://idontmatter.com"
                                                         responseCode:400
                                                     httpHeaderFields:@{}
                                                     dictionaryAsJSON:@{}];
    return response;
}


+ (MSALTestURLResponse *)responseUnreachableDrsService:(NSString *)domain
                                             onPrems:(BOOL)onPrems
{
    NSString *drsURL = [NSString stringWithFormat:@"%@%@/enrollmentserver/contract?api-version=1.0",
                        onPrems ? @"https://enterpriseregistration." : @"https://enterpriseregistration.windows.net/", domain];
    
    return [self serverNotFoundResponseForURLString:drsURL];
}


+ (MSALTestURLResponse *)responseValidWebFinger:(NSString *)passiveEndpoint
                                    authority:(NSString *)authority
{
    NSURL *endpointFullUrl = [NSURL URLWithString:passiveEndpoint.lowercaseString];
    NSString *url = [NSString stringWithFormat:@"https://%@/.well-known/webfinger?resource=%@", endpointFullUrl.host, authority];
    
    MSALTestURLResponse *response = [MSALTestURLResponse requestURLString:url
                                                    responseURLString:@"https://idontmatter.com"
                                                         responseCode:200
                                                     httpHeaderFields:@{}
                                                     dictionaryAsJSON:@{@"subject" : authority,
                                                                        @"links" : @[@{
                                                                                         @"rel" : @"http://schemas.microsoft.com/rel/trusted-realm",
                                                                                         @"href" : authority
                                                                                         }]
                                                                        }];
    return response;
}

+ (MSALTestURLResponse *)responseInvalidWebFinger:(NSString *)passiveEndpoint
                                      authority:(NSString *)authority
{
    NSURL *endpointFullUrl = [NSURL URLWithString:passiveEndpoint.lowercaseString];
    NSString *url = [NSString stringWithFormat:@"https://%@/.well-known/webfinger?resource=%@", endpointFullUrl.host, authority];
    
    MSALTestURLResponse *response = [MSALTestURLResponse requestURLString:url
                                                    responseURLString:@"https://idontmatter.com"
                                                         responseCode:400
                                                     httpHeaderFields:@{}
                                                     dictionaryAsJSON:@{}];
    return response;
}

+ (MSALTestURLResponse *)responseInvalidWebFingerNotTrusted:(NSString *)passiveEndpoint
                                                authority:(NSString *)authority
{
    NSURL *endpointFullUrl = [NSURL URLWithString:passiveEndpoint.lowercaseString];
    NSString *url = [NSString stringWithFormat:@"https://%@/.well-known/webfinger?resource=%@", endpointFullUrl.host, authority];
    
    MSALTestURLResponse *response = [MSALTestURLResponse requestURLString:url
                                                    responseURLString:@"https://idontmatter.com"
                                                         responseCode:200
                                                     httpHeaderFields:@{}
                                                     dictionaryAsJSON:@{@"subject" : authority,
                                                                        @"links" : @[@{
                                                                                         @"rel" : @"http://schemas.microsoft.com/rel/trusted-realm",
                                                                                         @"href" : @"idontmatch.com"
                                                                                         }]
                                                                        }];
    return response;
}

+ (MSALTestURLResponse *)responseUnreachableWebFinger:(NSString *)passiveEndpoint
                                          authority:(NSString *)authority

{
    (void)authority;
    NSURL *endpointFullUrl = [NSURL URLWithString:passiveEndpoint.lowercaseString];
    NSString *url = [NSString stringWithFormat:@"https://%@/.well-known/webfinger?resource=%@", endpointFullUrl.host, authority];
    
    return [self serverNotFoundResponseForURLString:url];
}


+ (MSALTestURLResponse *)requestURLString:(NSString*)requestUrlString
                      responseURLString:(NSString*)responseUrlString
                           responseCode:(NSInteger)responseCode
                       httpHeaderFields:(NSDictionary *)headerFields
                       dictionaryAsJSON:(NSDictionary *)data
{
    MSALTestURLResponse *response = [MSALTestURLResponse new];
    [response setRequestURL:[NSURL URLWithString:requestUrlString]];
    [response setResponseURL:responseUrlString code:responseCode headerFields:headerFields];
    [response setJSONResponse:data];
    
    return response;
}

+ (MSALTestURLResponse *)requestURLString:(NSString*)requestUrlString
                        requestJSONBody:(id)requestJSONBody
                      responseURLString:(NSString*)responseUrlString
                           responseCode:(NSInteger)responseCode
                       httpHeaderFields:(NSDictionary *)headerFields
                       dictionaryAsJSON:(NSDictionary *)data
{
    MSALTestURLResponse *response = [MSALTestURLResponse new];
    [response setRequestURL:[NSURL URLWithString:requestUrlString]];
    [response setResponseURL:responseUrlString code:responseCode headerFields:headerFields];
    response->_requestJSONBody = requestJSONBody;
    [response setJSONResponse:data];
    
    return response;
}

+ (MSALTestURLResponse *)requestURLString:(NSString*)requestUrlString
                         requestHeaders:(NSDictionary *)requestHeaders
                      requestParamsBody:(id)requestParams
                      responseURLString:(NSString*)responseUrlString
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
    
    if ([url.host caseInsensitiveCompare:_requestURL.host] != NSOrderedSame)
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
    if (_requestJSONBody)    {
        NSError* error = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:body options:NSJSONReadingAllowFragments error:&error];
        if ([obj isKindOfClass:[NSDictionary class]] && [_requestJSONBody isKindOfClass:[NSDictionary class]])
        {
            return [(NSDictionary *)_requestJSONBody compareDictionary:obj];
        }
        BOOL match = [obj isEqual:_requestJSONBody];
        return match;
    }
    
    if (_requestParamsBody)
    {
        NSString* string = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
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
    return (NSURLSession *)[[MSALTestURLSession alloc] initWithDelegate:nil delegateQueue:nil];
}

+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration
                                  delegate:(id<NSURLSessionDelegate>)delegate
                             delegateQueue:(NSOperationQueue *)queue
{
    (void)configuration;
    return (NSURLSession *)[[MSALTestURLSession alloc] initWithDelegate:delegate delegateQueue:queue];
}

@end
#pragma clang diagnostic pop



@implementation MSALTestURLSession

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
