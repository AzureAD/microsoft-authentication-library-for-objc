// Copyright 2018-2020 Yubico AB
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

#ifndef YKFOATHCredentialTypes_h
#define YKFOATHCredentialTypes_h
#import <Foundation/Foundation.h>

static NSUInteger const YKFOATHCredentialDefaultDigits = 6;
static NSUInteger const YKFOATHCredentialDefaultPeriod = 30; // seconds
static NSUInteger const YKFOATHCredentialMinSecretLength = 14; // bytes

static NSString* const YKFOATHCredentialScheme = @"otpauth";

static NSString* const YKFOATHCredentialURLTypeHOTP = @"hotp";
static NSString* const YKFOATHCredentialURLTypeTOTP = @"totp";

static NSString* const YKFOATHCredentialURLParameterSecret = @"secret";
static NSString* const YKFOATHCredentialURLParameterIssuer = @"issuer";
static NSString* const YKFOATHCredentialURLParameterDigits = @"digits";
static NSString* const YKFOATHCredentialURLParameterPeriod = @"period";
static NSString* const YKFOATHCredentialURLParameterCounter = @"counter";
static NSString* const YKFOATHCredentialURLParameterAlgorithm = @"algorithm";

static NSString* const YKFOATHCredentialURLParameterValueSHA1 = @"SHA1";
static NSString* const YKFOATHCredentialURLParameterValueSHA256 = @"SHA256";
static NSString* const YKFOATHCredentialURLParameterValueSHA512 = @"SHA512";

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name OATH Credential Types
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 The type of the credential as defined in https://developers.yubico.com/OATH/YKOATH_Protocol.html section TYPES
 */
typedef NS_ENUM(NSUInteger, YKFOATHCredentialType) {
    YKFOATHCredentialTypeUnknown    = 0x00,
    YKFOATHCredentialTypeHOTP       = 0x10,
    YKFOATHCredentialTypeTOTP       = 0x20
};

/*!
 The OATH algorithm as defined in https://developers.yubico.com/OATH/YKOATH_Protocol.html section ALGORITHMS
 */
typedef NS_ENUM(NSUInteger, YKFOATHCredentialAlgorithm) {
    YKFOATHCredentialAlgorithmUnknown   = 0x00,
    YKFOATHCredentialAlgorithmSHA1      = 0x01,
    YKFOATHCredentialAlgorithmSHA256    = 0x02,
    YKFOATHCredentialAlgorithmSHA512    = 0x03
};

#endif /* YKFOATHCredentialTypes_h */
