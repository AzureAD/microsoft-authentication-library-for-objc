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

@class YKFOATHSession, YKFU2FSession, YKFFIDO2Session, YKFPIVSession, YKFChallengeResponseSession, YKFManagementSession, YKFSmartCardInterface;

@protocol YKFConnectionProtocol<NSObject>

typedef void (^YKFOATHSessionCompletionBlock)(YKFOATHSession *_Nullable, NSError* _Nullable);

/// @abstract Returns a YKFOATHSession for interacting with the OATH application on the YubiKey.
/// @param completion The completion handler that gets called once the application is selected on
///                   the YubiKey. This handler is executed on a background thread.
- (void)oathSession:(YKFOATHSessionCompletionBlock _Nonnull)completion;

typedef void (^YKFU2FSessionCompletionBlock)(YKFU2FSession *_Nullable, NSError* _Nullable);

/// @abstract Returns a YKFU2FSession for interacting with the U2F application on the YubiKey.
/// @param completion The completion handler that gets called once the application is selected on
///                   the YubiKey. This handler is executed on a background thread.
- (void)u2fSession:(YKFU2FSessionCompletionBlock _Nonnull)completion;

typedef void (^YKFFIDO2SessionCompletionBlock)(YKFFIDO2Session *_Nullable, NSError* _Nullable);

/// @abstract Returns a YKFOATHSession for interacting with the OATH application on the YubiKey.
/// @param completion The completion handler that gets called once the application is selected on
///                   the YubiKey. This handler is executed on a background thread.
- (void)fido2Session:(YKFFIDO2SessionCompletionBlock _Nonnull)completion;

typedef void (^YKFPIVSessionCompletionBlock)(YKFPIVSession *_Nullable, NSError* _Nullable);

/// @abstract Returns a YKFPIVSession for interacting with the PIV application on the YubiKey.
/// @param completion The completion handler that gets called once the application is selected on
///                   the YubiKey. This handler is executed on a background thread.
- (void)pivSession:(YKFPIVSessionCompletionBlock _Nonnull)completion;

typedef void (^YKFChallengeResponseSessionCompletionBlock)(YKFChallengeResponseSession *_Nullable, NSError* _Nullable);

/// @abstract Returns a YKFChallengeResponseSession for interacting with the Challenge Response application on the YubiKey.
/// @param completion The completion handler that gets called once the application is selected on
///                   the YubiKey. This handler is executed on a background thread.
- (void)challengeResponseSession:(YKFChallengeResponseSessionCompletionBlock _Nonnull)completion;

typedef void (^YKFManagementSessionCompletion)(YKFManagementSession *_Nullable, NSError* _Nullable);

/// @abstract Returns a YKFManagementSession for interacting with the Management application on the YubiKey.
/// @param completion The completion handler that gets called once the application is selected on
///                   the YubiKey. This handler is executed on a background thread.
- (void)managementSession:(YKFManagementSessionCompletion _Nonnull)completion;

/// @abstract The smart card interface to the YubiKey.
/// @discussion Use this for communicating with the YubiKey by sending APDUs to the it. Only use this
///             when none of the supplied sessions can be used.
@property (nonatomic, readonly) YKFSmartCardInterface *_Nullable smartCardInterface;

@end
