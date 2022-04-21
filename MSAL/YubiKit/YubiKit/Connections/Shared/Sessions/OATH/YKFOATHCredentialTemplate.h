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

#ifndef YKFOATHCredentialTemplate_h
#define YKFOATHCredentialTemplate_h

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
@interface YKFOATHCredentialTemplate: NSObject <YKFOATHCredentialIdentifier, NSCopying>

/*!
 The credential type (HOTP or TOTP).
 */
@property (nonatomic, assign) YKFOATHCredentialType type;

/*!
 The hash algorithm to use for the OATH credential.
 */
@property (nonatomic, assign) YKFOATHCredentialAlgorithm algorithm;

/*!
 The Secret of the credential as defined in the Key URI Format specifications:
 https://github.com/google/google-authenticator/wiki/Key-Uri-Format
 */
@property (nonatomic) NSData *secret;

/*!
 The Issuer of the credential as defined in the Key URI Format specifications:
 https://github.com/google/google-authenticator/wiki/Key-Uri-Format
 */
@property (nonatomic, nullable) NSString *issuer;

/*!
 How long is the one-time passcode to display to the user. The value for this property can
 only be 6, 7 or 8. The default value is 6.
 */
@property (nonatomic, assign) NSUInteger digits;

/*!
 The validity period for a TOTP code, in seconds. The default value for this property is 30.
 If the credential is of HOTP type, this property returns 0.
 */
@property (nonatomic, assign) NSUInteger period;

/*!
 The counter parameter is required when the type is HOTP. It will set the initial counter value.
 If the credential is of TOTP type, this property returns 0.
 */
@property (nonatomic, assign) UInt32 counter;

/*!
 The account name extracted from the label. If the label does not contain the issuer, the
 name is the same as the label.
 */
@property (nonatomic) NSString *accountName;


/*!
 @method initWithURL:
 
 @abstract
    Convenience initializer which creates a new credential from an URL which conforms to ther Key URI Format
    specifications as defined in:
    https://github.com/google/google-authenticator/wiki/Key-Uri-Format
 
 @returns
    The credential object created from the URL or nil if the URL is incorrect.
 
 @param url
    The URL containing the credential properties.
 */
- (nullable instancetype)initWithURL:(NSURL *)url;

- (instancetype)initTOTPWithAlgorithm:(YKFOATHCredentialAlgorithm)algorithm
                               secret:(NSData *)secret
                               issuer:(NSString *_Nullable)issuer
                          accountName:(NSString *)accountName;

- (instancetype)initHOTPWithAlgorithm:(YKFOATHCredentialAlgorithm)algorithm
                               secret:(NSData *)secret
                               issuer:(NSString *_Nullable)issuer
                          accountName:(NSString *)accountName;

- (instancetype)initTOTPWithAlgorithm:(YKFOATHCredentialAlgorithm)algorithm
                               secret:(NSData *)secret
                               issuer:(NSString *_Nullable)issuer
                          accountName:(NSString *)accountName
                               digits:(NSUInteger)digits
                               period:(NSUInteger)period;

- (instancetype)initHOTPWithAlgorithm:(YKFOATHCredentialAlgorithm)algorithm
                               secret:(NSData *)secret
                               issuer:(NSString *_Nullable)issuer
                          accountName:(NSString *)accountName
                               digits:(NSUInteger)digits
                              counter:(UInt32)counter;

@end


NS_ASSUME_NONNULL_END


#endif /* YKFOATHCredentialTemplate_h */
