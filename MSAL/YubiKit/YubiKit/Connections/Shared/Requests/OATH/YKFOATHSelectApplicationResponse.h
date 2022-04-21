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
#import "YKFOATHCredential.h"
#import "YKFVersion.h"

NS_ASSUME_NONNULL_BEGIN

@interface YKFOATHSelectApplicationResponse : NSObject

@property (nonatomic, readonly) NSData *selectID;
@property (nonatomic, readonly, nullable) NSData *challenge;
@property (nonatomic, assign, readonly) YKFOATHCredentialAlgorithm algorithm;
@property (nonatomic, readonly, nullable) YKFVersion *version;

- (nullable instancetype)initWithResponseData:(NSData *)responseData NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
