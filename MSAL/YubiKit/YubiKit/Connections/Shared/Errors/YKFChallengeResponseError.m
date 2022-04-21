//
//  YKFChallengeResponseError.m
//  YubiKit
//
//  Created by Irina Makhalova on 12/30/19.
//  Copyright © 2019 Yubico. All rights reserved.
//

#import "YKFChallengeResponseError.h"
#import "YKFSessionError+Private.h"

static NSString* const YKFChallengeResponseNoConnectionDescription = @"YubiKey is not connected";
static NSString* const YKFChallengeResponseEmptyResponseDescription = @"Response is empty. Make sure that YubiKey have programmed challenge-response secret";

@implementation YKFChallengeResponseError

static NSDictionary *errorMap = nil;

+ (YKFSessionError *)errorWithCode:(NSUInteger)code {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [YKFChallengeResponseError buildErrorMap];
    });
    
    NSString *errorDescription = errorMap[@(code)];
    if (!errorDescription) {
        return [super errorWithCode:code];
    }
    return [[YKFSessionError alloc] initWithCode:code message:errorDescription];
}

+ (void)buildErrorMap {
    errorMap =
    @{@(YKFChallengeResponseErrorCodeNoConnection): YKFChallengeResponseNoConnectionDescription,
      @(YKFChallengeResponseErrorCodeEmptyResponse): YKFChallengeResponseEmptyResponseDescription,
      };
}

@end
