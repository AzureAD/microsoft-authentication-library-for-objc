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
#import "YKFRequest.h"
#import "YKFCBORType.h"

@class YKFAPDU;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, YKFFIDO2ClientPinRequestSubCommand) {
    YKFFIDO2ClientPinRequestSubCommandGetRetries         = 0x01,
    YKFFIDO2ClientPinRequestSubCommandGetKeyAgreement    = 0x02,
    YKFFIDO2ClientPinRequestSubCommandSetPIN             = 0x03,
    YKFFIDO2ClientPinRequestSubCommandChangePIN          = 0x04,
    YKFFIDO2ClientPinRequestSubCommandGetPINToken        = 0x05
};

@interface YKFFIDO2ClientPinRequest: YKFRequest

@property (nonatomic) YKFAPDU *apdu;

@property (nonatomic) NSUInteger pinProtocol;
@property (nonatomic) YKFFIDO2ClientPinRequestSubCommand subCommand;

/*!
 A COSE encoded EC public key used to generate a shared secret with the authenticator to send the PIN encripted.
 */
@property (nonatomic, nullable) YKFCBORMap *keyAgreement;
@property (nonatomic, nullable) NSData *pinAuth;
@property (nonatomic, nullable) NSData *pinEnc;
@property (nonatomic, nullable) NSData *pinHashEnc;

@end

NS_ASSUME_NONNULL_END
