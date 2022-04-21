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

@class YKFOATHCredential, YKFOATHCode, YKFOATHCredentialWithCode;

/*!
 @class YKFOATHCalculateAllResponse
 
 @abstract
    Response from Calculate All request for calculating all OATH credentials saved on the key.
 */
@interface YKFOATHCalculateAllResponse : NSObject

/*!
 The list of credentials (YKFOATHCredentialWithCode type) with the calculated OTPs.
 If the key does not contain any OATH credentials, this property returns an empty array.
 */
@property (nonatomic, readonly, nonnull) NSArray<YKFOATHCredentialWithCode *> *credentials;

- (nullable instancetype)initWithKeyResponseData:(nonnull NSData *)responseData requestTimetamp:(nonnull NSDate *)timestamp NS_DESIGNATED_INITIALIZER;

/*
 Not available: the library will create a response as the result of the Calculate All request.
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

@end

