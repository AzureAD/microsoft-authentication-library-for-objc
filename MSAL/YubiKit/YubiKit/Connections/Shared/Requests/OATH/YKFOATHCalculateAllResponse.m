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

#import "YKFOATHCalculateAllResponse.h"
#import "YKFOATHCredential.h"
#import "YKFOATHCredential+Private.h"
#import "YKFOATHCode.h"
#import "YKFOATHCode+Private.h"
#import "YKFAssert.h"
#import "YKFNSStringAdditions.h"
#import "YKFNSDataAdditions+Private.h"
#import "YKFOATHCredentialWithCode.h"

static const UInt8 YKFOATHCalculateAllNameTag = 0x71;
static const UInt8 YKFOATHCalculateAllResponseHOTPTag = 0x77;
static const UInt8 YKFOATHCalculateAllResponseFullResponseTag = 0x75;
static const UInt8 YKFOATHCalculateAllResponseTruncatedResponseTag = 0x76;
static const UInt8 YKFOATHCalculateAllResponseTouchTag = 0x7C;

static NSUInteger const YKFOATHCredentialCalculateResultDefaultPeriod = 30; // seconds

@interface YKFOATHCalculateAllResponse()

@property (nonatomic, readwrite) NSArray *credentials;

@end

@implementation YKFOATHCalculateAllResponse

- (instancetype)initWithKeyResponseData:(NSData *)responseData requestTimetamp:(NSDate *)timestamp {
    YKFAssertAbortInit(responseData);
    
    self = [super init];
    if (self) {
        NSMutableArray *responseCredentials = [[NSMutableArray alloc] init];
        UInt8 *responseBytes = (UInt8 *)responseData.bytes;
        NSUInteger readIndex = 0;
        
        while (readIndex < responseData.length && responseBytes[readIndex] == YKFOATHCalculateAllNameTag) {
            YKFOATHCredential *credential = [[YKFOATHCredential alloc] init];
            
            ++readIndex;
            YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
            
            UInt8 nameLength = responseBytes[readIndex];
            YKFAssertAbortInit(nameLength > 0);
            
            ++readIndex;
            NSRange nameRange = NSMakeRange(readIndex, nameLength);
            YKFAssertAbortInit([responseData ykf_containsRange:nameRange]);
            
            NSData *nameData = [responseData subdataWithRange:nameRange];
            credential.key = [[NSString alloc] initWithData:nameData encoding:NSUTF8StringEncoding];
            
            readIndex += nameLength;
            YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
            
            UInt8 responseTag = responseBytes[readIndex];
            switch (responseTag) {
                case YKFOATHCalculateAllResponseHOTPTag:
                    credential.type = YKFOATHCredentialTypeHOTP;
                    break;
                    
                case YKFOATHCalculateAllResponseFullResponseTag:
                case YKFOATHCalculateAllResponseTruncatedResponseTag:
                case YKFOATHCalculateAllResponseTouchTag:
                    credential.type = YKFOATHCredentialTypeTOTP;
                    break;
                
                default:
                    credential.type = YKFOATHCredentialTypeUnknown;
            }
            YKFAssertAbortInit(credential.type != YKFOATHCredentialTypeUnknown);
            
            ++readIndex;
            YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
            
            UInt8 responseLength = responseBytes[readIndex];
            YKFAssertAbortInit(responseLength > 0);
            
            ++readIndex;
            YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
            
            UInt8 digits = responseBytes[readIndex];
            YKFAssertAbortInit(digits == 6 || digits == 7 || digits == 8);
            
            // Parse the period, account and issuer from the key.
            
            NSString *credentialKey = credential.key;
            NSUInteger period = 0;
            NSString *issuer = nil;
            NSString *account = nil;
            NSString *label = nil;
            
            [credentialKey ykf_OATHKeyExtractPeriod:&period issuer:&issuer account:&account label:&label];
            
            credential.issuer = issuer;
            credential.accountName = account;
            if (credential.type == YKFOATHCredentialTypeTOTP) {
                credential.period = period ? period : YKFOATHCredentialCalculateResultDefaultPeriod;
            }
            
            // Parse the OTP value when TOTP and touch is not required.
            NSString *otp;
            if (credential.type == YKFOATHCredentialTypeTOTP && responseTag != YKFOATHCalculateAllResponseTouchTag) {
                ++readIndex;
                YKFAssertAbortInit([responseData ykf_containsIndex:readIndex]);
                
                UInt8 otpBytesLength = responseLength - 1;
                YKFAssertAbortInit(otpBytesLength == 4);
                
                otp = [responseData ykf_parseOATHOTPFromIndex:readIndex digits:digits];
                YKFAssertAbortInit(otp.length == digits);
                
                readIndex += otpBytesLength; // Jump to the next extry.
            } else {
                // No result for TOTP with touch or HOTP
                if (credential.type == YKFOATHCredentialTypeTOTP) {
                    credential.requiresTouch = YES;
                }
                ++readIndex;
            }
            
            // Calculate validity
            NSDateInterval *validity;
            if (credential.type == YKFOATHCredentialTypeTOTP && responseTag != YKFOATHCalculateAllResponseTouchTag) {
                NSUInteger timestampTimeInterval = [timestamp timeIntervalSince1970]; // truncate to seconds
                
                NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:timestampTimeInterval - timestampTimeInterval % credential.period];
                validity = [[NSDateInterval alloc] initWithStartDate:startDate duration:credential.period];
            } else {
                validity = [[NSDateInterval alloc] initWithStartDate:timestamp endDate:[NSDate distantFuture]];
            }

            YKFOATHCode *code = [[YKFOATHCode alloc] initWithOtp:otp validity:validity];
            YKFOATHCredentialWithCode *result = [[YKFOATHCredentialWithCode alloc] initWithCredential:credential code:code];
            [responseCredentials addObject:result];
        }
        self.credentials = [responseCredentials copy];
    }
    return self;
}

@end
