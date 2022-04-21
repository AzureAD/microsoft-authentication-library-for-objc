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

NSString* const YKFSessionErrorDomain = @"com.yubico";

#pragma mark - Error Descriptions
static NSString* const YKFSessionErrorReadTimeoutDescription = @"Unable to read from key. Operation timeout.";
static NSString* const YKFSessionErrorWriteTimeoutDescription = @"Unable to write to the key. Operation timeout.";
static NSString* const YKFSessionErrorTouchTimeoutDescription = @"Operation ended. User didn't touch the key.";
static NSString* const YKFSessionErrorKeyBusyDescription = @"The key is busy performing another operation.";
static NSString* const YKFSessionErrorMissingApplicationDescription = @"The requested functionality is missing or disabled in the key configuration.";
static NSString* const YKFSessionErrorConnectionLostDescription = @"Connection lost.";
static NSString* const YKFSessionErrorNoConnectionDescription = @"Connection is not found.";
static NSString* const YKFSessionErrorInvalidSessionStateDescription = @"Invalid session state.";

#pragma mark - YKFSessionError

@implementation YKFSessionError

static NSDictionary *errorMap = nil;

+ (YKFSessionError *)errorWithCode:(NSUInteger)code {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [YKFSessionError buildErrorMap];
    });
    
    NSString *errorDescription = errorMap[@(code)];
    if (!errorDescription) {
        errorDescription = [[NSString alloc] initWithFormat:@"Status error 0x%2lX returned by the key.", (unsigned long)code];
    }
    
    return [[YKFSessionError alloc] initWithCode:code message:errorDescription];
}

+ (void)buildErrorMap {
    errorMap =
    @{@(YKFSessionErrorReadTimeoutCode):                     YKFSessionErrorReadTimeoutDescription,
      @(YKFSessionErrorWriteTimeoutCode):                    YKFSessionErrorWriteTimeoutDescription,
      @(YKFSessionErrorTouchTimeoutCode):                    YKFSessionErrorTouchTimeoutDescription,
      @(YKFSessionErrorKeyBusyCode):                         YKFSessionErrorKeyBusyDescription,
      @(YKFSessionErrorMissingApplicationCode):              YKFSessionErrorMissingApplicationDescription,
      @(YKFSessionErrorConnectionLost):                      YKFSessionErrorConnectionLostDescription,
      @(YKFSessionErrorNoConnection):                        YKFSessionErrorNoConnectionDescription,
      @(YKFSessionErrorInvalidSessionStateStatusCode):       YKFSessionErrorInvalidSessionStateDescription,
      };
}

#pragma mark - Initializers

- (instancetype)initWithCode:(NSInteger)code message:(NSString *)message {
    return [super initWithDomain:YKFSessionErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: message}];
}

@end
