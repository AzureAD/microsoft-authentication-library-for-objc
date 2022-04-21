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

#import "YKFPIVError.h"
#import "YKFSessionError+Private.h"

@implementation YKFPIVError

+ (YKFSessionError *)errorWithCode:(NSUInteger)code {
    NSString *message;
    switch (code) {
        case YKFPIVErrorCodeBadResponse:
            message = @"Bad response";
            break;
        default:
            message = @"Unknown error";
            break;
    }
    return [[YKFPIVError alloc] initWithCode:code message:message];
}
    
+ (YKFSessionError *)errorUnpackingTLVExpected:(NSUInteger)expected got:(NSUInteger)got {
    return [[YKFSessionError alloc] initWithCode:YKFPIVErrorCodeBadResponse message:[[NSString alloc] initWithFormat:@"Exptected tag: %02lx, got %02lx", (unsigned long)expected, (unsigned long)got]];
}

@end
