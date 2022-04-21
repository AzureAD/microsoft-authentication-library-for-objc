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

#import "YKFSessionError.h"

typedef NS_ENUM(NSUInteger, YKFAPDUErrorCode) {
    YKFAPDUErrorCodeNoError                  = 0x9000,
    YKFAPDUErrorCodeFIDO2TouchRequired       = 0x9100,
    YKFAPDUErrorCodeConditionNotSatisfied    = 0x6985,
    
    YKFAPDUErrorCodeAuthenticationRequired   = 0x6982,
    YKFAPDUErrorCodeDataInvalid              = 0x6984,
    YKFAPDUErrorCodeWrongLength              = 0x6700,
    YKFAPDUErrorCodeWrongData                = 0x6A80,
    YKFAPDUErrorCodeInsNotSupported          = 0x6D00,
    YKFAPDUErrorCodeCLANotSupported          = 0x6E00,
    YKFAPDUErrorCodeCommandAborted           = 0x6F00,
    YKFAPDUErrorCodeMissingFile              = 0x6A82,
    
    // Application/Applet short codes
    
    YKFAPDUErrorCodeMoreData                 = 0x61 // 0x61XX
};

NS_ASSUME_NONNULL_BEGIN

@interface YKFAPDUError: YKFSessionError
@end

NS_ASSUME_NONNULL_END
