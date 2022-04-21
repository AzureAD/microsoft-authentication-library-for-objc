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

#import "YKFOATHCredential.h"
#import "YKFOATHCredential+Private.h"
#import "YKFAssert.h"
#import "YKFLogger.h"
#import "YKFNSDataAdditions.h"

#import "MF_Base32Additions.h"

@implementation YKFOATHCredential

#pragma mark - Properties Overrides

- (YKFOATHCredentialType)type {
    if (_type) {
        return _type;
    }
    return YKFOATHCredentialTypeTOTP;
}

- (NSUInteger)period {
    if (_period) {
        return _period;
    }
    return self.type == YKFOATHCredentialTypeTOTP ? YKFOATHCredentialDefaultPeriod : 0;
}

- (NSString *)key {
    if (!_key) {
        return [YKFOATHCredentialUtils keyFromCredentialIdentifier:self];
    }
    return _key;
}

- (NSString *)label {
    YKFAssertReturnValue(self.accountName, @"Missing OATH credential account. Cannot build the credential label.", nil);
    
    if (self.issuer) {
        return [NSString stringWithFormat:@"%@:%@", self.issuer, self.accountName];
    } else {
        return self.accountName;
    }
}

#pragma mark - NSCopying

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    YKFOATHCredential *copy = [YKFOATHCredential new];
    copy.accountName = [self.accountName copyWithZone:zone];
    copy.issuer = [self.issuer copyWithZone:zone];
    copy.period = self.period;
    copy.type = self.type;
    return copy;
}

@end
