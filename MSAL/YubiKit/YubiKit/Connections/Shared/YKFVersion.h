// Copyright 2018-2021 Yubico AB
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

#ifndef YKFVersion_h
#define YKFVersion_h

NS_ASSUME_NONNULL_BEGIN

/*! Class represents firmware version of YubiKey
 */
@interface YKFVersion : NSObject

@property (nonatomic, readonly) UInt8 major;
@property (nonatomic, readonly) UInt8 minor;
@property (nonatomic, readonly) UInt8 micro;

- (instancetype)initWithData:(NSData *)data NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithBytes:(UInt8)major minor:(UInt8)minor micro:(UInt8)micro NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithString:(NSString *)versionString NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (NSComparisonResult)compare:(YKFVersion *)version;

@end


@protocol YKFVersionProtocol <NSObject>

@property (readonly) YKFVersion * version;

@end

NS_ASSUME_NONNULL_END

#endif /* YKFVersion_h */
