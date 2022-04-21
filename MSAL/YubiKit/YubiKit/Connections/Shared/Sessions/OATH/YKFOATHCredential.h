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
#import "YKFOATHCredentialTypes.h"
#import "YKFOATHCredentialUtils.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name OATH Credential
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @class YKFOATHCredential
 
 @abstract
    The YKFOATHCredential is a data model which contains a list of properties defining an OATH credential.
 */
@interface YKFOATHCredential: NSObject <YKFOATHCredentialIdentifier, NSCopying>

/*!
 The credential type (HOTP or TOTP).
 */
@property (nonatomic, assign) YKFOATHCredentialType type;

/*!
 The Label of the credential as defined in the Key URI Format specifications:
 https://github.com/google/google-authenticator/wiki/Key-Uri-Format
 */
@property (nonatomic, nullable, readonly) NSString *label;

/*!
 The Issuer of the credential as defined in the Key URI Format specifications:
 https://github.com/google/google-authenticator/wiki/Key-Uri-Format
 */
@property (nonatomic, nullable) NSString *issuer;

/*!
 The validity period for a TOTP code, in seconds. The default value for this property is 30.
 If the credential is of HOTP type, this property returns 0.
 */
@property (nonatomic, assign) NSUInteger period;

/*!
 The account name extracted from the label. If the label does not contain the issuer, the
 name is the same as the label.
 */
@property (nonatomic) NSString *accountName;

/*!
 The credential requires the user to touch the key to generate it.
 */
@property (nonatomic) BOOL requiresTouch;

@end

NS_ASSUME_NONNULL_END
