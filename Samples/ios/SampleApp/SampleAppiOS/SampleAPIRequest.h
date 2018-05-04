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

// For these errors the error will be a HTTP error code, and the userInfo dictionary will be the
// error dictionary from the JSON response in the body (if any)
extern const NSErrorDomain SampleAPIErrorDomain;

@interface SampleAPIRequest : NSObject

+ (instancetype)requestWithToken:(NSString *)token;

- (void)getJSONWithURL:(NSURL *)url completionHandler:(void(^)(NSObject *json, NSError *error))completionBlock;
- (void)getDataWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSError *))completionBlock;

- (void)postDataWithURL:(NSURL *)url
               httpBody:(NSData *)body
            contentType:(NSString *)contentType
      completionHandler:(void (^)(NSData *data, NSError *error))completionBlock;

- (void)postJSONWithURL:(NSURL *)url
                   json:(NSData *)jsonData
      completionHandler:(void (^)(NSData *data, NSError *error))completionBlock;

@end
