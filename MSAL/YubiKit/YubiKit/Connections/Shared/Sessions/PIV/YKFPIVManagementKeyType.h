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

#ifndef YKFPIVManagementKeyType_h
#define YKFPIVManagementKeyType_h

NS_ASSUME_NONNULL_BEGIN

extern NSString * const YKFPIVManagementKeyTypeTripleDES;
extern NSString * const YKFPIVManagementKeyTypeAES;

@interface YKFPIVManagementKeyType : NSObject

+ (YKFPIVManagementKeyType *)TripleDES;
+ (YKFPIVManagementKeyType *)AES128;
+ (YKFPIVManagementKeyType *)AES192;
+ (YKFPIVManagementKeyType *)AES256;
+ (YKFPIVManagementKeyType * _Nullable)fromValue:(UInt8)value;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) UInt8 value;
@property (nonatomic, readonly) int keyLenght;
@property (nonatomic, readonly) int challengeLength;

NS_ASSUME_NONNULL_END

- (nonnull instancetype)init NS_UNAVAILABLE;

@end

@interface NSString (CryptoNameMapping)

- (uint32_t)ykfCCAlgorithm;

@end

#endif
