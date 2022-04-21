// Copyright 2018-2020 Yubico AB
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



#ifndef YKFSelectApplicationAPDU_h
#define YKFSelectApplicationAPDU_h


#import "YKFAPDU.h"

typedef NS_ENUM(NSUInteger, YKFSelectApplicationAPDUName) {
    
    YKFSelectApplicationAPDUNameManagement,
    
    YKFSelectApplicationAPDUNameChalResp,
    
    YKFSelectApplicationAPDUNameFIDO2,
    
    YKFSelectApplicationAPDUNameOATH,

    YKFSelectApplicationAPDUNamePIV,
    
    YKFSelectApplicationAPDUNameU2F
};

@interface YKFSelectApplicationAPDU : YKFAPDU

- (instancetype)initWithData:(NSData *)data  NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithApplicationName:(YKFSelectApplicationAPDUName)application;

@end

#endif
