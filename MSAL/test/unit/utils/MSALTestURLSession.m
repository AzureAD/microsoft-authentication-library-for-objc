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

#import "MSALTestConstants.h"
#import "MSALTestURLSessionDataTask.h"
#import "MSALTestIdTokenUtil.h"
#import "MSALTestCacheDataUtil.h"

#import "MSALPublicClientApplication+Internal.h"
#import "MSALUser.h"

#import "NSDictionary+MSALExtensions.h"
#import "NSDictionary+MSALTestUtil.h"
#import "NSOrderedSet+MSALExtensions.h"
#import "NSString+MSALHelperMethods.h"
#import "NSURL+MSALExtensions.h"

#include <assert.h>
#include <stdbool.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/sysctl.h>

// From https://developer.apple.com/library/content/qa/qa1361/_index.html
static bool AmIBeingDebugged(void)
// Returns true if the current process is being debugged (either
// running under the debugger or has a debugger attached post facto).
{
    int                 junk;
    int                 mib[4];
    struct kinfo_proc   info;
    size_t              size;
    
    // Initialize the flags so that, if sysctl fails for some bizarre
    // reason, we get a predictable result.
    
    info.kp_proc.p_flag = 0;
    
    // Initialize mib, which tells sysctl the info we want, in this case
    // we're looking for information about a specific process ID.
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = getpid();
    
    // Call sysctl.
    
    size = sizeof(info);
    junk = sysctl(mib, sizeof(mib) / sizeof(*mib), &info, &size, NULL, 0);
    assert(junk == 0);
    
    // We're being debugged if the P_TRACED flag is set.
    
    return ( (info.kp_proc.p_flag & P_TRACED) != 0 );
}

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

+ (MSALTestURLResponse *)oidcResponseForAuthority:(NSString *)authority
{
    NSMutableDictionary *oidcReqHeaders = [[MSALLogger msalId] mutableCopy];
    [oidcReqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [oidcReqHeaders setObject:[MSALTestSentinel new] forKey:@"client-request-id"];
    
    NSDictionary *oidcJson =
    @{ @"token_endpoint" : [NSString stringWithFormat:@"%@/v2.0/oauth/token", authority],
       @"authorization_endpoint" : [NSString stringWithFormat:@"%@/v2.0/oauth/authorize", authority],
       @"issuer" : @"issuer"
       };
    
    MSALTestURLResponse *oidcResponse =
    [MSALTestURLResponse requestURLString:[NSString stringWithFormat:@"%@/v2.0/.well-known/openid-configuration", authority]
                           requestHeaders:oidcReqHeaders
                        requestParamsBody:nil
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:oidcJson];
    
    return oidcResponse;
}

+ (MSALTestURLResponse *)oidcResponseForAuthority:(NSString *)authority
                                      responseUrl:(NSString *)responseAuthority
                                            query:(NSString *)query
{
    NSMutableDictionary *oidcReqHeaders = [[MSALLogger msalId] mutableCopy];
    [oidcReqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [oidcReqHeaders setObject:[MSALTestSentinel new] forKey:@"client-request-id"];
    
    NSDictionary *oidcJson =
    @{ @"token_endpoint" : [NSString stringWithFormat:@"%@/v2.0/oauth/token?%@", responseAuthority, query],
       @"authorization_endpoint" : [NSString stringWithFormat:@"%@/v2.0/oauth/authorize?%@", responseAuthority, query],
       @"issuer" : @"issuer"
       };
    
    MSALTestURLResponse *oidcResponse =
    [MSALTestURLResponse requestURLString:[NSString stringWithFormat:@"%@/v2.0/.well-known/openid-configuration", authority]
                           requestHeaders:oidcReqHeaders
                        requestParamsBody:nil
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:oidcJson];
    
    return oidcResponse;
}

+ (MSALTestURLResponse *)authCodeResponse:(NSString *)authcode
                                authority:(NSString *)authority
                                    query:(NSString *)query
                                   scopes:(MSALScopes *)scopes
{
    NSMutableDictionary *tokenReqHeaders = [[MSALLogger msalId] mutableCopy];
    [tokenReqHeaders setObject:@"application/json" forKey:@"Accept"];
    [tokenReqHeaders setObject:[MSALTestSentinel new] forKey:@"client-request-id"];
    [tokenReqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [tokenReqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    
    NSMutableDictionary *tokenQPs = [NSMutableDictionary new];
    [tokenQPs addEntriesFromDictionary:@{UT_SLICE_PARAMS_DICT}];
    if (query)
    {
        [tokenQPs addEntriesFromDictionary:[NSDictionary msalURLFormDecode:query]];
    }
    
    NSString *requestUrlStr = nil;
    if (tokenQPs.count > 0)
    {
        requestUrlStr = [NSString stringWithFormat:@"%@/v2.0/oauth/token?%@", authority, [tokenQPs msalURLFormEncode]];
    }
    else
    {
        requestUrlStr = [NSString stringWithFormat:@"%@/v2.0/oauth/token", authority];
    }
    
    MSALTestURLResponse *tokenResponse =
    [MSALTestURLResponse requestURLString:requestUrlStr
                           requestHeaders:tokenReqHeaders
                        requestParamsBody:@{ OAUTH2_CLIENT_ID : [MSALTestCacheDataUtil defaultClientId],
                                             OAUTH2_SCOPE : [scopes msalToString],
                                             @"client_info" : @"1",
                                             @"grant_type" : @"authorization_code",
                                             @"code_verifier" : [MSALTestSentinel sentinel],
                                             OAUTH2_REDIRECT_URI : UNIT_TEST_DEFAULT_REDIRECT_URI,
                                             OAUTH2_CODE : authcode }
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"access_token" : @"i am an updated access token!",
                                             @"expires_in" : @"600",
                                             @"refresh_token" : @"i am a refresh token",
                                             @"id_token" : [MSALTestIdTokenUtil defaultIdToken],
                                             @"id_token_expires_in" : @"1200",
                                             @"client_info" : [@{ @"uid" : @"1", @"utid" : [MSALTestIdTokenUtil defaultTenantId]} base64UrlJson] } ];
    
    return tokenResponse;
}

+ (MSALTestURLResponse *)rtResponseForScopes:(MSALScopes *)scopes
                                   authority:(NSString *)authority
                                    tenantId:(NSString *)tid
                                        user:(MSALUser *)user
{
    NSMutableDictionary *tokenReqHeaders = [[MSALLogger msalId] mutableCopy];
    [tokenReqHeaders setObject:@"application/json" forKey:@"Accept"];
    [tokenReqHeaders setObject:[MSALTestSentinel new] forKey:@"client-request-id"];
    [tokenReqHeaders setObject:@"true" forKey:@"return-client-request-id"];
    [tokenReqHeaders setObject:@"application/x-www-form-urlencoded" forKey:@"Content-Type"];
    
    MSALTestURLResponse *tokenResponse =
    [MSALTestURLResponse requestURLString:[NSString stringWithFormat:@"%@/v2.0/oauth/token" UT_SLICE_PARAMS_QUERY, authority]
                           requestHeaders:tokenReqHeaders
                        requestParamsBody:@{ OAUTH2_CLIENT_ID : [MSALTestCacheDataUtil defaultClientId],
                                             OAUTH2_SCOPE : [scopes msalToString],
                                             OAUTH2_REFRESH_TOKEN : @"i am a refresh token!",
                                             @"client_info" : @"1",
                                             @"grant_type" : @"refresh_token" }
                        responseURLString:@"https://someresponseurl.com"
                             responseCode:200
                         httpHeaderFields:nil
                         dictionaryAsJSON:@{ @"access_token" : @"i am an updated access token!",
                                             @"expires_in" : @"600",
                                             @"refresh_token" : @"i am a refresh token",
                                             @"id_token" : [MSALTestIdTokenUtil idTokenWithName:user.name
                                                                              preferredUsername:user.displayableId
                                                                                       tenantId:tid ? tid : user.utid],
                                             @"id_token_expires_in" : @"1200",
                                             @"client_info" : [@{ @"uid" : user.uid, @"utid" : user.utid} base64UrlJson] } ];
    
    return tokenResponse;
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
        if (![_QPs compareToActual:QPs])
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
        NSDictionary *obj = [NSDictionary msalURLFormDecode:string];
        return [_requestParamsBody compareToActual:obj];
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
        [@{} compareToActual:headers];
        return NO;
    }
    
    return [_requestHeaders compareToActual:headers];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %@>", NSStringFromClass(self.class), _requestURL];
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

+ (void)addResponses:(NSArray *)responses
{
    [s_responses addObject:[responses mutableCopy]];
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
    
    if (AmIBeingDebugged())
    {
        NSLog(@"Failed to find repsonse for %@\ncurrent responses: %@", requestURL, s_responses);
        // This will cause the tests to immediately stop execution right here if we're in the debugger,
        // hopefully making it a little easier to see why a test is failing. :)
        __builtin_trap();
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
- (void)invalidateAndCancel
{
    // No need to invalidate anything here.
}


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
