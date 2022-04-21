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

#import "YKFOATHCode.h"
#import "YKFOATHCode+Private.h"
#import "YKFAssert.h"
#import "YKFNSDataAdditions+Private.h"

typedef NS_ENUM(NSUInteger, YKFOATHCalculateResponseType) {
    YKFOATHCalculateResponseTypeFull = 0x75,
    YKFOATHCalculateResponseTypeTruncated = 0x76
};

@interface YKFOATHCode()

@property (nonatomic, readwrite) NSString *otp;
@property (nonatomic, readwrite) NSDateInterval *validity;

@end

@implementation YKFOATHCode

- (instancetype)initWithOtp:(nullable NSString *)otp validity:(nonnull NSDateInterval *)validity {
    self = [self init];
    if (self) {
        self.otp = otp;
        self.validity = validity;
    }
    return self;
}

- (nullable instancetype)initWithKeyResponseData:(nonnull NSData *)responseData requestTimetamp:(NSDate *)timestamp requestPeriod:(NSUInteger)period {
    YKFAssertAbortInit(responseData.length);
    YKFAssertAbortInit(timestamp);
    
    self = [super init];
    if (self) {
        YKFAssertAbortInit(responseData.length > 3)

        UInt8 *bytes = (UInt8 *)responseData.bytes;

        UInt8 responseType = bytes[0];
        YKFAssertAbortInit(responseType == YKFOATHCalculateResponseTypeTruncated);
        
        YKFAssertAbortInit([responseData ykf_containsRange:NSMakeRange(1, 2)]);
        UInt8 responseLength = bytes[1];
        UInt8 digits = bytes[2];
        YKFAssertAbortInit(digits == 6 || digits == 7 || digits == 8);
        UInt8 otpBytesLength = responseLength - 1;
        UInt8 offset = 3;
        YKFAssertAbortInit(otpBytesLength == 4);
        self.otp = [responseData ykf_parseOATHOTPFromIndex:offset digits:digits];
        YKFAssertAbortInit(self.otp);
        
        if (period > 0) {
            // TOTP
            NSUInteger timestampTimeInterval = [timestamp timeIntervalSince1970]; // truncate to seconds
            
            NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:timestampTimeInterval - timestampTimeInterval % period];
            NSDate *endDate = [startDate dateByAddingTimeInterval:period];
            self.validity = [[NSDateInterval alloc] initWithStartDate:startDate endDate:endDate];
        } else {
            // HOTP
            self.validity = [[NSDateInterval alloc] initWithStartDate:timestamp endDate:[NSDate distantFuture]];
        }        
    }
    return self;
}

@end
