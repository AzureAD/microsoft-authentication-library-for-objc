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

#import "YKFSessionError.h"

typedef NS_ENUM(NSUInteger, YKFPIVErrorCode) {
    
    /*! Unexpected reply from the YubiKey.
     */
    YKFPIVErrorCodeBadResponse = 0x01,
    YKFPIVErrorCodeBadKeyLength = 0x02
};


NS_ASSUME_NONNULL_BEGIN
/*!
 @class
    YKFPIVError
 @abstract
    Error type returned by the YKFPIVSession.
 */
@interface YKFPIVError: YKFSessionError

+ (YKFSessionError *)errorUnpackingTLVExpected:(NSUInteger)expected got:(NSUInteger)got;

@end

NS_ASSUME_NONNULL_END
