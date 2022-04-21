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

#import <Foundation/Foundation.h>


/*!
 @class YKFOATHCalculateResponse
 
 @abstract
    Response from Calculate OATH credential request.
 */
@interface YKFOATHCode: NSObject

/*!
 The OTP value for the credential. The value of this string is numeric and may have
 only 6 or 8 characters.
 */
@property (nonatomic, readonly, nullable) NSString *otp;

/*!
 The validity of the OTP when the credential is TOTP. For HOTP this property is the
 interval [<time of request>, <date distant future>] because an HOTP credential does
 not have an expiration date.
 */
@property (nonatomic, readonly, nonnull) NSDateInterval *validity;

/*
 Not available: the library will create a response as the result of the Calculate request.
 */
- (instancetype _Nonnull)init NS_UNAVAILABLE;

@end

