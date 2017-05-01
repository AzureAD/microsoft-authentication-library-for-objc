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

#import "SampleGraphRequest.h"

const NSErrorDomain SampleGraphErrorDomain = (NSErrorDomain)(@"SampleGraphErrorDomain");

@implementation SampleGraphRequest
{
    NSString *_token;
}

+ (NSURL *)graphURLWithPath:(NSString *)path
{
    NSString *urlString = [NSString stringWithFormat:@"https://graph.microsoft.com/beta/%@", path];
    return [NSURL URLWithString:urlString];
}

+ (instancetype)requestWithToken:(NSString *)token
{
    SampleGraphRequest *req = [self new];
    req->_token = token;
    return req;
}

- (void)getData:(NSString *)path completionHandler:(void (^)(NSData *, NSError *))completionBlock
{
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest new];
    urlRequest.URL = [SampleGraphRequest graphURLWithPath:path];
    urlRequest.HTTPMethod = @"GET";
    urlRequest.allHTTPHeaderFields = @{ @"Authorization" : [NSString stringWithFormat:@"Bearer %@", _token] };
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSURLSessionDataTask *task =
    [session dataTaskWithRequest:urlRequest
               completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
     {
         if (error)
         {
             completionBlock(nil, error);
             return;
         }
         
         NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
         if (httpResponse.statusCode != 200)
         {
             NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
             completionBlock(nil, [NSError errorWithDomain:SampleGraphErrorDomain code:httpResponse.statusCode userInfo:json[@"error"]]);
             return;
         }
         
         completionBlock(data, nil);
     }];
    [task resume];
}
- (void)getJSON:(NSString *)path completionHandler:(void(^)(NSDictionary *json, NSError *error))completionBlock
{
    [self getData:path completionHandler:^(NSData *data, NSError *error) {
        if (error)
        {
            completionBlock(nil, error);
            return;
        }
       
        NSError *localError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&localError];
        completionBlock(json, localError);
    }];
}

@end
