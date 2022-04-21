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

#ifndef YKFOATHCredentialUtils_h
#define YKFOATHCredentialUtils_h

#import "YKFOATHCredentialTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class YKFOATHCredential, YKFOATHCredentialTemplate, YKFSessionError;

@protocol YKFOATHCredentialIdentifier

/*!
 The credential type (HOTP or TOTP).
 */
@property (nonatomic, assign) YKFOATHCredentialType type;

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
 The Issuer of the credential as defined in the Key URI Format specifications:
 https://github.com/google/google-authenticator/wiki/Key-Uri-Format
 */
@property (nonatomic, nullable) NSString *issuer;

@end

@interface YKFOATHCredentialUtils: NSObject

+ (NSString *)labelFromCredentialIdentifier:(id<YKFOATHCredentialIdentifier>)credentialIdentifier;
+ (NSString *)keyFromCredentialIdentifier:(id<YKFOATHCredentialIdentifier>)credentialIdentifier;

+ (nullable YKFSessionError *)validateCredentialTemplate:(YKFOATHCredentialTemplate *)credentialTemplate;
+ (nullable YKFSessionError *)validateCredential:(YKFOATHCredential *)credential;

@end

NS_ASSUME_NONNULL_END

#endif /* YKFOATHCredentialUtils_h */
