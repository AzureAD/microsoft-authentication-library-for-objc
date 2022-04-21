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

#import "YKFU2FError.h"
#import "YKFSessionError+Private.h"

static NSString* const YKFU2FErrorU2FSigningUnavailableDescription = @"A sign operation was performed without registration first."
                                                                         "Register the device before authenticating with it.";

@implementation YKFU2FError

static NSDictionary *errorMap = nil;

+ (YKFSessionError *)errorWithCode:(NSUInteger)code {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [YKFU2FError buildErrorMap];
    });
    
    NSString *errorDescription = errorMap[@(code)];
    if (!errorDescription) {
        return [super errorWithCode:code];
    }
    return [[YKFSessionError alloc] initWithCode:code message:errorDescription];
}

+ (void)buildErrorMap {
    errorMap = @{@(YKFU2FErrorCodeU2FSigningUnavailable): YKFU2FErrorU2FSigningUnavailableDescription };
}

@end
