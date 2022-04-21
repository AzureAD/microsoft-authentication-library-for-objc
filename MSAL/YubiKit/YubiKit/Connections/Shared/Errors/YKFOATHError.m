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

#import "YKFOATHError.h"
#import "YKFSessionError+Private.h"

static NSString* const YKFOATHErrorNameTooLongDescription = @"The credential has a name longer then the maximum allowed size by the key (64 bytes).";
static NSString* const YKFOATHErrorSecretTooLongDescription = @"The credential has a secret longer then the size of the hash algorithm size.";
static NSString* const YKFOATHErrorBadCalculationResponseDescription = @"The key returned a malformed response to the calculate request.";
static NSString* const YKFOATHErrorBadListResponseDescription = @"The key returned a malformed response to the list request.";
static NSString* const YKFOATHErrorBadApplicationSelectionResponseDescription = @"The key returned a malformed response when selecting OATH.";
static NSString* const YKFOATHErrorAuthenticationRequiredDescription = @"Authentication required.";
static NSString* const YKFOATHErrorMalformedValidationResponseDescription = @"The key returned a malformed response when validating.";
static NSString* const YKFOATHErrorBadCalculateAllResponseDescription = @"The key returned a malformed response when calculating all credentials.";
static NSString* const YKFOATHErrorCodeTouchTimeoutDescription = @"The key did time out, waiting for touch.";
static NSString* const YKFOATHErrorCodeWrongPasswordDescription = @"Wrong password.";
static NSString* const YKFOATHErrorCodeNoSuchObjectDescription = @"Credential not found.";

@implementation YKFOATHError

static NSDictionary *errorMap = nil;

+ (YKFSessionError *)errorWithCode:(NSUInteger)code {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [YKFOATHError buildErrorMap];
    });
    
    NSString *errorDescription = errorMap[@(code)];
    if (!errorDescription) {
        return [super errorWithCode:code];
    }
    return [[YKFSessionError alloc] initWithCode:code message:errorDescription];
}

+ (void)buildErrorMap {
    errorMap =
    @{@(YKFOATHErrorCodeNameTooLong): YKFOATHErrorNameTooLongDescription,
      @(YKFOATHErrorCodeSecretTooLong): YKFOATHErrorSecretTooLongDescription,
      @(YKFOATHErrorCodeBadCalculationResponse): YKFOATHErrorBadCalculationResponseDescription,
      @(YKFOATHErrorCodeBadListResponse): YKFOATHErrorBadListResponseDescription,
      @(YKFOATHErrorCodeBadApplicationSelectionResponse): YKFOATHErrorBadApplicationSelectionResponseDescription,
      @(YKFOATHErrorCodeAuthenticationRequired): YKFOATHErrorAuthenticationRequiredDescription,
      @(YKFOATHErrorCodeBadValidationResponse): YKFOATHErrorMalformedValidationResponseDescription,
      @(YKFOATHErrorCodeBadCalculateAllResponse): YKFOATHErrorBadCalculateAllResponseDescription,
      @(YKFOATHErrorCodeTouchTimeout): YKFOATHErrorCodeTouchTimeoutDescription,
      @(YKFOATHErrorCodeWrongPassword): YKFOATHErrorCodeWrongPasswordDescription,
      @(YKFOATHErrorCodeNoSuchObject): YKFOATHErrorCodeNoSuchObjectDescription
      };
}

@end
