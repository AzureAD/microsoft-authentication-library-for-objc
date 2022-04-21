// Copyright 2018-2019 Yubico AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

@class YKFOATHCredential;

NS_ASSUME_NONNULL_BEGIN

/*!
 @class YKFOATHListResponse
 
 @abstract
    Response from List OATH credentials request.
 */
@interface YKFOATHListResponse : NSObject

/*!
 The list of stored credentials (YKFOATHCredential type) on the key.
 */
@property (nonatomic, readonly, nonnull) NSArray<YKFOATHCredential*> *credentials;


- (nullable instancetype)initWithKeyResponseData:(nonnull NSData *)responseData NS_DESIGNATED_INITIALIZER;

/*
 Not available: the library will create a response as the result of the List request.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
