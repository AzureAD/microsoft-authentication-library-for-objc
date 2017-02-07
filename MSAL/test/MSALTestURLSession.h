//
//  MSALTestURLSession.h
//  MSAL
//
//  Created by Jason Kim on 2/7/17.
//  Copyright © 2017 Microsoft. All rights reserved.
//

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

+ (MSALTestURLResponse *)requestURLString:(NSString *)requestUrlString
                        responseURLString:(NSString *)responseUrlString
                             responseCode:(NSInteger)responseCode
                         httpHeaderFields:(NSDictionary *)headerFields
                         dictionaryAsJSON:(NSDictionary *)data;

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
