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

#import <CommonCrypto/CommonCrypto.h>

#import "YKFOATHCredentialTemplate.h"
#import "YKFOATHCredential+Private.h"
#import "YKFAssert.h"
#import "YKFLogger.h"
#import "YKFNSDataAdditions.h"
#import "MF_Base32Additions.h"

@implementation YKFOATHCredentialTemplate

- (instancetype)initWithURL:(NSURL *)url {
    self = [super init];
    if (self) {
        if (![self parseUrl: url]) {
            self = nil;
        }
    }
    return self;
}

- (instancetype)initTOTPWithAlgorithm:(YKFOATHCredentialAlgorithm)algorithm
                               secret:(NSData *)secret
                               issuer:(NSString *_Nullable)issuer
                          accountName:(NSString *)accountName {
    return [self initTOTPWithAlgorithm:algorithm
                                secret:secret
                                issuer:issuer
                           accountName:accountName
                                digits:YKFOATHCredentialDefaultDigits
                                period:YKFOATHCredentialDefaultPeriod];
}

- (instancetype)initTOTPWithAlgorithm:(YKFOATHCredentialAlgorithm)algorithm
                               secret:(NSData *)secret
                               issuer:(NSString *_Nullable)issuer
                          accountName:(NSString *)accountName
                               digits:(NSUInteger)digits
                               period:(NSUInteger)period {
    return [self initWithType:YKFOATHCredentialTypeTOTP
                    algorithm:algorithm
                       secret:secret
                       issuer:issuer
                  accountName:accountName
                       digits:digits
                       period:period
                      counter:0];
}

- (instancetype)initHOTPWithAlgorithm:(YKFOATHCredentialAlgorithm)algorithm
                               secret:(NSData *)secret
                               issuer:(NSString *_Nullable)issuer
                              accountName:(NSString *)accountName {
    return [self initHOTPWithAlgorithm:algorithm
                                secret:secret
                                issuer:issuer
                               accountName:accountName
                                digits:YKFOATHCredentialDefaultDigits
                               counter:0];
}

- (instancetype)initHOTPWithAlgorithm:(YKFOATHCredentialAlgorithm)algorithm
                               secret:(NSData *)secret
                               issuer:(NSString *_Nullable)issuer
                          accountName:(NSString *)accountName
                               digits:(NSUInteger)digits
                              counter:(UInt32)counter {
    return [self initWithType:YKFOATHCredentialTypeHOTP
                    algorithm:algorithm
                       secret:secret
                       issuer:issuer
                  accountName:accountName
                       digits:digits
                       period:0
                      counter:counter];
}

- (instancetype)initWithType:(YKFOATHCredentialType)type
                   algorithm:(YKFOATHCredentialAlgorithm)algorithm
                      secret:(NSData *)secret
                      issuer:(NSString *_Nullable)issuer
                 accountName:(NSString *)accountName
                      digits:(NSUInteger)digits
                      period:(NSUInteger)period
                     counter:(UInt32)counter {
    self = [super init];
    if (self) {
        self.type = type;
        self.algorithm = algorithm;
        self.secret = secret;
        self.issuer = issuer;
        self.accountName = accountName;
        self.digits = digits;
        self.period = period;
        self.counter = counter;
    }
    return self;
}

#pragma mark - Properties Overrides

- (YKFOATHCredentialType)type {
    if (_type) {
        return _type;
    }
    return YKFOATHCredentialTypeTOTP;
}

- (YKFOATHCredentialAlgorithm)algorithm {
    if (_algorithm) {
        return _algorithm;
    }
    return YKFOATHCredentialAlgorithmSHA1;
}

- (NSUInteger)digits {
    if (_digits) {
        return _digits;
    }
    return YKFOATHCredentialDefaultDigits;
}

- (NSUInteger)period {
    if (_period) {
        return _period;
    }
    return self.type == YKFOATHCredentialTypeTOTP ? YKFOATHCredentialDefaultPeriod : 0;
}

- (void)setSecret:(NSData *)secret {
    YKFAssertReturn(secret.length, @"Cannot set empty OATH secret.");
    
    if (secret.length < YKFOATHCredentialMinSecretLength) {
        NSMutableData *paddedSecret = [[NSMutableData alloc] initWithData:secret];
        [paddedSecret increaseLengthBy: YKFOATHCredentialMinSecretLength - secret.length];
        _secret = [paddedSecret copy];
        return;
    }
    
    switch (self.algorithm) {
        case YKFOATHCredentialAlgorithmSHA1:
            if (secret.length > CC_SHA1_BLOCK_BYTES) {
                _secret = [secret ykf_SHA1];
            } else {
                _secret = secret;
            }
            break;
            
        case YKFOATHCredentialAlgorithmSHA256:
            if (secret.length > CC_SHA256_BLOCK_BYTES) {
                _secret = [secret ykf_SHA256];
            } else {
                _secret = secret;
            }
            break;
            
        case YKFOATHCredentialAlgorithmSHA512:
            if (secret.length > CC_SHA512_BLOCK_BYTES) {
                _secret = [secret ykf_SHA512];
            } else {
                _secret = secret;
            }
            break;
            
        default:
            YKFAssertReturn(NO, @"Unknown hash algorithm for credential.");
            break;
    }
}

#pragma mark - URL Parsing

- (BOOL)parseUrl:(NSURL *)url {
    YKFParameterAssertReturnValue(url, NO);
    
    NSURLComponents *urlComponents = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    
    // Check scheme
    if (![urlComponents.scheme isEqualToString:YKFOATHCredentialScheme]) {
        return NO;
    }
    
    if (![self parseTypeFromUrlComponents:urlComponents])       { return NO; }
    if (![self parseLabelFromUrlComponents:urlComponents])      { return NO; }
    if (![self parseIssuerFromUrlComponents:urlComponents])     { return NO; }
    if (![self parseAlgorithmFromUrlComponents:urlComponents])  { return NO; }
    if (![self parseDigitsFromUrlComponents:urlComponents])     { return NO; }
    if (![self parseSecretFromUrlComponents:urlComponents])     { return NO; }

    // Parse specific parameters
    if (self.type == YKFOATHCredentialTypeHOTP) {
        return [self parserHOTPParamsFromUrlComponents:urlComponents];
    } else {
        return [self parserTOTPParamsFromUrlComponents:urlComponents];
    }
}

#pragma mark - Specific Parameters

- (BOOL)parseDigitsFromUrlComponents:(NSURLComponents *)urlComponents {
    YKFParameterAssertReturnValue(urlComponents, NO);
    
    NSString *digits = [self queryParameterValueForName:YKFOATHCredentialURLParameterDigits inUrlComponents:urlComponents];
    if (digits) {
        int value = [digits intValue];
        if (value && (value == 6 || value == 7 || value == 8)) {
            self.digits = value;
        } else {
            return NO; // Invalid digits number
        }
    } else {
        self.digits = YKFOATHCredentialDefaultDigits;
    }
    return YES;
}

- (BOOL)parseAlgorithmFromUrlComponents:(NSURLComponents *)urlComponents {
    YKFParameterAssertReturnValue(urlComponents, NO);
    
    NSString *algorithm = [self queryParameterValueForName:YKFOATHCredentialURLParameterAlgorithm inUrlComponents:urlComponents];
    
    if (!algorithm || [algorithm isEqualToString:YKFOATHCredentialURLParameterValueSHA1]) {
        self.algorithm = YKFOATHCredentialAlgorithmSHA1;
    } else if ([algorithm isEqualToString:YKFOATHCredentialURLParameterValueSHA256]) {
        self.algorithm = YKFOATHCredentialAlgorithmSHA256;
    } else if ([algorithm isEqualToString:YKFOATHCredentialURLParameterValueSHA512]) {
        self.algorithm = YKFOATHCredentialAlgorithmSHA512;
    } else {
        return NO; // Unknown algorithm
    }
    
    return YES;
}

- (BOOL)parseIssuerFromUrlComponents:(NSURLComponents *)urlComponents {
    YKFParameterAssertReturnValue(urlComponents, NO);
    
    NSString *issuer = [self queryParameterValueForName:YKFOATHCredentialURLParameterIssuer inUrlComponents:urlComponents];
    if (issuer) {
        self.issuer = issuer;
    }
    return YES;
}

- (BOOL)parseSecretFromUrlComponents:(NSURLComponents *)urlComponents {
    YKFParameterAssertReturnValue(urlComponents, NO);
    
    NSString *base32EncodedSecret = [self queryParameterValueForName:YKFOATHCredentialURLParameterSecret inUrlComponents:urlComponents];
    if (!base32EncodedSecret) {
        return NO;
    }
    
    self.secret = [NSData dataWithBase32String:base32EncodedSecret];
    return self.secret.length > 0;
}

- (BOOL)parseLabelFromUrlComponents:(NSURLComponents *)urlComponents {
    YKFParameterAssertReturnValue(urlComponents, NO);
    
    NSString *label = urlComponents.path;
    label = [label stringByReplacingOccurrencesOfString:@"/" withString:@""];
    if (!label.length) {
        return NO;
    }
    if ([label containsString:@":"]) { // Issuer is present in the label
        NSArray *labelComponents = [label componentsSeparatedByString:@":"];
        self.issuer = labelComponents.firstObject; // It's fine if nil
        self.accountName = labelComponents.lastObject;
    } else {
        self.accountName = label;
    }
    
    return YES;
}

- (BOOL)parseTypeFromUrlComponents:(NSURLComponents *)urlComponents {
    YKFParameterAssertReturnValue(urlComponents, NO);
    
    if ([urlComponents.host isEqualToString:YKFOATHCredentialURLTypeHOTP]) {
        self.type = YKFOATHCredentialTypeHOTP;
    } else if ([urlComponents.host isEqualToString:YKFOATHCredentialURLTypeTOTP]) {
        self.type = YKFOATHCredentialTypeTOTP;
    } else {
        return NO;
    }
    return YES;
}

- (BOOL)parserHOTPParamsFromUrlComponents:(NSURLComponents *)urlComponents {
    YKFParameterAssertReturnValue(urlComponents, NO);
    
    NSString *counter = [self queryParameterValueForName:YKFOATHCredentialURLParameterCounter inUrlComponents:urlComponents];
    if (!counter) {
        return NO;
    }
    self.counter = MAX(0, [counter intValue]);
    return YES;
}

- (BOOL)parserTOTPParamsFromUrlComponents:(NSURLComponents *)urlComponents {
    YKFParameterAssertReturnValue(urlComponents, NO);
    
    NSString *period = [self queryParameterValueForName:YKFOATHCredentialURLParameterPeriod inUrlComponents:urlComponents];
    if (period) {
        int periodValue = [period intValue];
        self.period = periodValue > 0 ? periodValue : YKFOATHCredentialDefaultPeriod;
    } else {
        self.period = YKFOATHCredentialDefaultPeriod;
    }
    return YES;
}

#pragma mark - Helpers

- (NSString *)queryParameterValueForName:(NSString *)name inUrlComponents:(NSURLComponents *)urlComponents {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", name];
    return [urlComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject.value;
}

#pragma mark - NSCopying

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    YKFOATHCredentialTemplate *copy = [YKFOATHCredentialTemplate new];
    copy.accountName = [self.accountName copyWithZone:zone];
    copy.issuer = [self.issuer copyWithZone:zone];
    copy.period = self.period;
    copy.digits = self.digits;
    copy.type = self.type;
    copy.algorithm = self.algorithm;
    copy.counter = self.counter;
    if (self.secret) {
        copy.secret = [self.secret copyWithZone:zone];
    }
    return copy;
}

@end
