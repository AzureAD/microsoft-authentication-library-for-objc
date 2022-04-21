// Copyright 2018-2021 Yubico AB
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

#ifndef YKFPIVSession_h
#define YKFPIVSession_h

#import "YKFVersion.h"
#import "YKFSession.h"
#import "YKFPIVKeyType.h"

/// Touch policy for PIV application.
typedef NS_ENUM(NSUInteger, YKFPIVTouchPolicy) {
    YKFPIVTouchPolicyDefault = 0x0,
    YKFPIVTouchPolicyNever = 0x1,
    YKFPIVTouchPolicyAlways = 0x2,
    YKFPIVTouchPolicyCached = 0x3
};

/// Pin policy for PIV application.
typedef NS_ENUM(NSUInteger, YKFPIVPinPolicy) {
    YKFPIVPinPolicyDefault = 0x0,
    YKFPIVPinPolicyNever = 0x1,
    YKFPIVPinPolicyOnce = 0x2,
    YKFPIVPinPolicyAlways = 0x3
};

/// Available slots for PIV application.
typedef NS_ENUM(NSUInteger, YKFPIVSlot) {
    YKFPIVSlotAuthentication = 0x9a,
    YKFPIVSlotSignature = 0x9c,
    YKFPIVSlotKeyManagement = 0x9d,
    YKFPIVSlotCardAuth = 0x9e,
    YKFPIVSlotAttestation = 0xf9
};

/// PIV error domain.
extern NSString* _Nonnull const YKFPIVFErrorDomain;

/// PIV error codes.
typedef NS_ENUM(NSUInteger, YKFPIVFErrorCode) {
    YKFPIVFErrorCodeInvalidCipherTextLength = 1,
    YKFPIVFErrorCodeUnsupportedOperation = 2,
    YKFPIVFErrorCodeDataParseError = 3,
    YKFPIVFErrorCodeUnknownKeyType = 4,
    YKFPIVFErrorCodeInvalidPin = 5,
    YKFPIVFErrorCodePinLocked = 6,
    YKFPIVFErrorCodeInvalidResponse = 7,
    YKFPIVFErrorCodeAuthenticationFailed = 8
};

@class YKFPIVSessionFeatures, YKFPIVManagementKeyType, YKFPIVManagementKeyMetadata;

NS_ASSUME_NONNULL_BEGIN

/// @abstract Generic response block which provides an error if the execution failed.
/// @param error An error object that indicates why the request failed, or nil if the request was successful.
typedef void (^YKFPIVSessionGenericCompletionBlock)
    (NSError* _Nullable error);

/// @abstract Response block for [signWithKeyInSlot:type:algorithm:message:completion:] which provides the
///           signature or an error.
///  @param signature The signature resulting signature.
///  @param error An error object that indicates why the request failed, or nil if the request was successful.
typedef void (^YKFPIVSessionSignCompletionBlock)
    (NSData* _Nullable signature, NSError* _Nullable error);

/// @abstract Response block for [decryptWithKeyInSlot:algorithm:encrypted:completion:] which provides the decrypted data or an error.
/// @param decrypted The decrypted data.
/// @param error An error object that indicates why the request failed, or nil if the request was successful.
typedef void (^YKFPIVSessionDecryptCompletionBlock)
    (NSData* _Nullable decrypted, NSError* _Nullable error);

/// @abstract Response block for [calculateSecretKeyInSlot:peerPublicKey:completion:] which provides the shared secret or an error.
/// @param secret The shared secret.
/// @param error An error object that indicates why the request failed, or nil if the request was successful.
typedef void (^YKFPIVSessionCalculateSecretCompletionBlock)
    (NSData* _Nullable secret, NSError* _Nullable error);

/// @abstract Response block for [attestKeyInSlot:completion:] which provides a attestation certificate or an error.
/// @param certificate The certificate.
/// @param error An error object that indicates why the request failed, or nil if the request was successful.
typedef void (^YKFPIVSessionAttestKeyCompletionBlock)
    (SecCertificateRef _Nullable certificate, NSError* _Nullable error);

/// @abstract Response block for [generateKeyInSlot:type:pinPolicy:touchPolicy:completion:] and
///           [generateKeyInSlot:type:completion:] which provides the public key or an error.
/// @param key The public key.
/// @param error An error object that indicates why the request failed, or nil if the request was successful.
typedef void (^YKFPIVSessionReadKeyCompletionBlock)
    (SecKeyRef _Nullable key, NSError* _Nullable error);

/// @abstract Response block for [putKeyInSlot:key:pinPolicy:touchPolicy:completion:] and
///           [putKeyInSlot:key:completion:] which returns the type of the stored key or an error.
/// @param keyType The key type.
/// @param error An error object that indicates why the request failed, or nil if the request was successful.
typedef void (^YKFPIVSessionPutKeyCompletionBlock)
    (YKFPIVKeyType keyType, NSError* _Nullable error);

/// @abstract Response block for [readCertificateFromSlot:completion:] which provides a certificate or an error.
/// @param certificate The certificate.
/// @param error An error object that indicates why the request failed, or nil if the request was successful.
typedef void (^YKFPIVSessionReadCertCompletionBlock)
    (SecCertificateRef _Nullable certificate, NSError* _Nullable error);

/// @abstract Response block for [getSerialNumberWithCompletion:completion:] which provides the serial number of the
///           YubiKey or an error.
/// @param serialNumber The serial number of the YubiKey.
/// @param error An error object that indicates why the request failed, or nil if the request was successful.
typedef void (^YKFPIVSessionSerialNumberCompletionBlock)
    (int serialNumber, NSError* _Nullable error);

/// @abstract Response block for [verifyPin:completion:] which provides the serial number of the YubiKey or an error.
/// @param retries The number of retries left or -1 if an error occured. If 0 pin authentication has been blocked.
/// @param error An error object that indicates why the request failed, or nil if the request was successful.
typedef void (^YKFPIVSessionVerifyPinCompletionBlock)
    (int retries, NSError* _Nullable error);

/// @abstract Response block for [getPinMetadata:completion:] which provides the PIN metadata or an error.
/// @param isDefault Returns true if the current PIN is the default PIN.
/// @param retriesTotal The total number of retries configured.
/// @param retriesRemaining The number of retries left.
/// @param error An error object that indicates why the request failed, or nil if the request was successful.
typedef void (^YKFPIVSessionPinPukMetadataCompletionBlock)
    (bool isDefault, int retriesTotal, int retriesRemaining, NSError* _Nullable error);

/// @abstract Response block for [getPinAttempts:completion:] which provides the number of PIN attempts left or an error.
/// @param retriesRemaining The number of retries left.
/// @param error An error object that indicates why the request failed, or nil if the request was successful.
typedef void (^YKFPIVSessionPinAttemptsCompletionBlock)
    (int retriesRemaining, NSError* _Nullable error);

/// @abstract Response block for [getManagementKeyMetadata:completion:] which provides the management key metadata or an error.
/// @param metaData The management key metadata.
/// @param error An error object that indicates why the request failed, or nil if the request was successful.
typedef void (^YKFPIVSessionManagementKeyMetadataCompletionBlock)
    (YKFPIVManagementKeyMetadata* _Nullable metaData, NSError* _Nullable error);

/// @class YKFPIVSession
/// @abstract Provides the interface for executing PIV requests with the key.
/// @discussion The PIV session is mantained by the YKFConnection which controls its lifecycle. The application
///             must not create one.
@interface YKFPIVSession: YKFSession <YKFVersionProtocol>

/// @abstract This property provides the version of the currently connected YubiKey.
@property (nonatomic, readonly) YKFVersion * _Nonnull version;

/// @abstract This property provides a mean to test what PIV features are supported by the currently connected YubiKey.
/// @discussion This property is useful for checking what features the currently connected YubiKey supports before you
///             execute any commands.
@property (nonatomic, readonly) YKFPIVSessionFeatures * _Nonnull features;

/// @abstract Create a signature for a given message.
/// @param slot The slot containing the private key to use.
/// @param keyType The type of the key stored in the slot.
/// @param algorithm The signing algorithm to use.
/// @param message The message to hash.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the
///                   request. This handler is executend on a background queue.
/// @note This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)signWithKeyInSlot:(YKFPIVSlot)slot type:(YKFPIVKeyType)keyType algorithm:(SecKeyAlgorithm)algorithm message:(nonnull NSData *)message completion:(nonnull YKFPIVSessionSignCompletionBlock)completion;

/// @abstract Decrypt a RSA-encrypted message.
/// @param slot The slot containing the private key to use.
/// @param algorithm The algorithm used for encryption.
/// @param encrypted The encrypted data to decrypt.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   This handler is executed on a background queue.
/// @note: This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)decryptWithKeyInSlot:(YKFPIVSlot)slot algorithm:(SecKeyAlgorithm)algorithm encrypted:(nonnull NSData *)encrypted completion:(nonnull YKFPIVSessionDecryptCompletionBlock)completion;

/// @abstract Perform an ECDH operation with a given public key to compute a shared secret.
/// @param slot The slot containing the private EC key to use.
/// @param peerPublicKey The peer public key for the operation.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the
///                   request. This handler is executed on a background queue.
/// @note: This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)calculateSecretKeyInSlot:(YKFPIVSlot)slot peerPublicKey:(SecKeyRef)peerPublicKey completion:(nonnull YKFPIVSessionCalculateSecretCompletionBlock)completion;

/// @abstract Creates an attestation certificate for a private key which was generated on the YubiKey.
/// @discussion This method requires authentication.
/// @discussion A high level description of the thinking and how this can be used can be found at
///             https://developers.yubico.com/PIV/Introduction/PIV_attestation.html
///             Attestation works through a special key slot called "f9" this comes pre-loaded from factory
///             with a key and cert signed by Yubico, but can be overwritten. After a key has been generated
///             in a normal slot it can be attested by this special key
/// @param slot The slot containing the private key to use.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the
///                   request. This handler is executed on a background queue.
/// @note This functionality requires support for attestation, available on
///       YubiKey 4.3 or later. This method is thread safe and can be invoked from any thread
///       (main or a background thread).
- (void)attestKeyInSlot:(YKFPIVSlot)slot completion:(nonnull YKFPIVSessionAttestKeyCompletionBlock)completion;

/// @abstract Generates a new key pair within the YubiKey.
/// @discussion This method requires authentication and pin verification.
/// @param slot The slot to generate the new key in.
/// @param type Which algorithm is used for key generation.
/// @param pinPolicy The PIN policy for using the private key.
/// @param touchPolicy The touch policy for using the private key.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the
///                   request and contains the public key of the key pair. This handler is executed on a background queue.
/// @note YubiKey FIPS does not allow RSA1024 nor PinProtocol.NEVER.
///       RSA key types require RSA generation, available on YubiKeys OTHER THAN 4.2.6-4.3.4.
///       KeyType P348 requires P384 support, available on YubiKey 4 or later.
///       PinPolicy or TouchPolicy other than default require support for usage policy, available on YubiKey 4 or later.
///       TouchPolicy.CACHED requires support for touch cached, available on YubiKey 4.3 or later.
///       This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)generateKeyInSlot:(YKFPIVSlot)slot type:(YKFPIVKeyType)type pinPolicy:(YKFPIVPinPolicy)pinPolicy touchPolicy:(YKFPIVTouchPolicy)touchPolicy completion:(nonnull YKFPIVSessionReadKeyCompletionBlock)completion;

/// @abstract Generates a new key pair within the YubiKey.
/// @discussion This method requires authentication and pin verification.
/// @param slot The slot to generate the new key in.
/// @param type Which algorithm is used for key generation.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the
///                   request and contains the public key of the key pair. This handler is executed on a background queue.
/// @note YubiKey FIPS does not allow RSA1024 nor PinProtocol.NEVER.
///       RSA key types require RSA generation, available on YubiKeys OTHER THAN 4.2.6-4.3.4.
///       KeyType P348 requires P384 support, available on YubiKey 4 or later.
///       PinPolicy or TouchPolicy other than default require support for usage policy, available on YubiKey 4 or later.
///       TouchPolicy.CACHED requires support for touch cached, available on YubiKey 4.3 or later.
///       This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)generateKeyInSlot:(YKFPIVSlot)slot type:(YKFPIVKeyType)type completion:(nonnull YKFPIVSessionReadKeyCompletionBlock)completion;

/// @abstract Import a private key into a slot.
/// @discussion This method requires authentication.
/// @param key The private key to import.
/// @param slot The slot to write the key to.
/// @param pinPolicy The PIN policy for using the private key.
/// @param touchPolicy The touch policy for using the private key.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the
///                   request and contains the key type of the imported key. This handler is executed on a
///                    background queue.
/// @note YubiKey FIPS does not allow RSA1024 nor YKFPIVPinPolicyNever.
///       KeyType P348 requires P384 support, available on YubiKey 4 or later.
///       PinPolicy or TouchPolicy other than default require support for usage policy, available on YubiKey 4 or later.
///       This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)putKey:(SecKeyRef)key inSlot:(YKFPIVSlot)slot pinPolicy:(YKFPIVPinPolicy)pinPolicy touchPolicy:(YKFPIVTouchPolicy)touchPolicy completion:(nonnull YKFPIVSessionPutKeyCompletionBlock)completion
        NS_SWIFT_NAME(putKey(_:inSlot:pinPolicy:touchPolicy:completion:));

/// @abstract Import a private key into a slot.
/// @discussion This method requires authentication.
/// @param key The private key to import.
/// @param slot The slot to write the key to.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the
///                   request and contains the key type of the imported key. This handler is executed on a
///                    background queue.
/// @note YubiKey FIPS does not allow RSA1024 nor YKFPIVPinPolicyNever.
///       KeyType P348 requires P384 support, available on YubiKey 4 or later.
///       PinPolicy or TouchPolicy other than default require support for usage policy, available on YubiKey 4 or later.
///       This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)putKey:(SecKeyRef)key inSlot:(YKFPIVSlot)slot completion:(nonnull YKFPIVSessionPutKeyCompletionBlock)completion
        NS_SWIFT_NAME(putKey(_:inSlot:completion:));

/// @abstract Writes an X.509 certificate to a slot on the YubiKey.
/// @discussion This method requires authentication.
/// @param certificate Certificate to write.
/// @param slot The slot to write the certificate to.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   This handler is executed on a background queue.
///  @note YubiKey FIPS does not allow RSA1024 nor PinProtocol.NEVER.
///        RSA key types require RSA generation, available on YubiKeys OTHER THAN 4.2.6-4.3.4.
///        KeyType P348 requires P384 support, available on YubiKey 4 or later.
///        PinPolicy or TouchPolicy other than default require support for usage policy, available on YubiKey 4 or later.
///        TouchPolicy.CACHED requires support for touch cached, available on YubiKey 4.3 or later.
///        This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)putCertificate:(SecCertificateRef)certificate inSlot:(YKFPIVSlot)slot completion:(YKFPIVSessionGenericCompletionBlock)completion
        NS_SWIFT_NAME(putCertificate(_:inSlot:completion:));

/// @abstract Reads the X.509 certificate stored in the specified slot on the YubiKey.
/// @param slot The slot where the certificate is stored.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   This handler is executed on a background queue.
- (void)getCertificateInSlot:(YKFPIVSlot)slot completion:(nonnull YKFPIVSessionReadCertCompletionBlock)completion;

/// @abstract Deletes the X.509 certificate stored in the specified slot on the YubiKey.
/// @discussion This method requires authentication.
/// @param slot The slot where the certificate is stored.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   This handler is executed on a background queue.
/// @note This does NOT delete any corresponding private key.
///       This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)deleteCertificateInSlot:(YKFPIVSlot)slot completion:(nonnull YKFPIVSessionGenericCompletionBlock)completion;

/// @abstract Set a new management key.
/// @discussion This method requires authentication.
/// @param managementKey The new management key as NSData.
/// @param type The management key type.
/// @param requiresTouch Set to true to require touch for authentication.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   This handler is executed on a background queue.
/// @note Setting requriesTouch to true requires support for usage policy, available in YubiKey 4 or later.
///       This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)setManagementKey:(nonnull NSData *)managementKey type:(nonnull YKFPIVManagementKeyType *)type requiresTouch:(BOOL)requiresTouch completion:(nonnull YKFPIVSessionGenericCompletionBlock)completion;

/// @abstract Authenticate with the Management Key.
/// @param managementKey The management key as NSData.
/// @param type The management key type.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   This handler is executed on a background queue.
/// @note: This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)authenticateWithManagementKey:(nonnull NSData *)managementKey type:(nonnull YKFPIVManagementKeyType *)type completion:(nonnull YKFPIVSessionGenericCompletionBlock)completion;

/// @abstract Resets the PIV application to just-installed state.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   This handler is executed on a background queue.
/// @note: This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)resetWithCompletion:(nonnull YKFPIVSessionGenericCompletionBlock)completion;

/// @abstract Authenticate with pin.
/// @param pin The UTF8 encoded pin. Default pin code is 123456.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   The completion handler returns the number of retries left. If 0 pin authentication has been
///                   blocked. Note that 15 is the higheset number of retries left that will be returned even if
///                   remaining tries is higher. This handler is executed on a background queue.
/// @note: This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)verifyPin:(nonnull NSString *)pin completion:(nonnull YKFPIVSessionVerifyPinCompletionBlock)completion;

/// @abstract Set a new pin code for the YubiKey.
/// @param pin The new UTF8 encoded pin.
/// @param oldPin Old pin code. UTF8 encoded.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   This handler is executed on a background queue.
/// @note: This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)setPin:(nonnull NSString *)pin oldPin:(nonnull NSString *)oldPin completion:(nonnull YKFPIVSessionGenericCompletionBlock)completion;

/// @abstract Set a new puk code for the YubiKey.
/// @param puk The new UTF8 encoded puk.
/// @param oldPuk Old puk code. UTF8 encoded.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   This handler is executed on a background queue.
/// @note: This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)setPuk:(nonnull NSString *)puk oldPuk:(nonnull NSString *)oldPuk completion:(nonnull YKFPIVSessionGenericCompletionBlock)completion;

/// @abstract Set a new puk code for the YubiKey.
/// @param puk The UTF8 encoded puk.
/// @param newPin The new UTF8 encoded pin code.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   This handler is executed on a background queue.
/// @note: This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)unblockPinWithPuk:(nonnull NSString *)puk newPin:(nonnull NSString *)newPin completion:(nonnull YKFPIVSessionGenericCompletionBlock)completion;

/// @abstract Get the serial number from the YubiKey.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   This handler is executed on a background queue.
/// @note This requires the SERIAL_API_VISIBILE flag to be set on one of the YubiOTP slots (it is set by default).
///       This functionality requires support for feature serial, available on YubiKey 5 or later.
/// @note: This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)getSerialNumberWithCompletion:(nonnull YKFPIVSessionSerialNumberCompletionBlock)completion;

/// @abstract Reads metadata about the card management key.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   This handler is executed on a background queue.
/// @note This functionality requires support for feature metadata, available on YubiKey 5.3 or later.
/// @note: This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)getManagementKeyMetadataWithCompletion:(nonnull YKFPIVSessionManagementKeyMetadataCompletionBlock)completion;

/// @abstract Reads metadata about the pin, such as total number of retries, attempts left, and if the pin has
///           been changed from the default value.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   This handler is executed on a background queue.
/// @note This functionality requires support for feature metadata, available on YubiKey 5.3 or later.
///       This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)getPinMetadataWithCompletion:(nonnull YKFPIVSessionPinPukMetadataCompletionBlock)completion;

/// @abstract Reads metadata about the puk, such as total number of retries, attempts left, and if the puk has
///           been changed from the default value.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   This handler is executed on a background queue.
/// @note This functionality requires support for feature metadata, available on YubiKey 5.3 or later.
///       This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)getPukMetadataWithCompletion:(nonnull YKFPIVSessionPinPukMetadataCompletionBlock)completion;

/// @abstract Retrieve the number of pin attempts left for the YubiKey.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   This handler is executed on a background queue.
/// @note If this command is run in a session where the correct pin has already been verified,
///       the correct value will not be retrievable, and the value returned may be incorrect if the
///       number of total attempts has been changed from the default.
///       This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)getPinAttemptsWithCompletion:(nonnull YKFPIVSessionPinAttemptsCompletionBlock)completion;

/// @abstract Set the number of retries available for pin and puk entry.
/// @discussion This method requires authentication and pin verification.
/// @param pinAttempts The number of attempts to allow for pin entry before blocking the pin.
/// @param pukAttempts The number of attempts to allow for puk entry before blocking the puk.
/// @param completion The completion handler that gets called once the YubiKey has finished processing the request.
///                   This handler is executed on a background queue.
/// @note This method is thread safe and can be invoked from any thread (main or a background thread).
- (void)setPinAttempts:(int)pinAttempts pukAttempts:(int)pukAttempts completion:(nonnull YKFPIVSessionGenericCompletionBlock)completion;

/// Not available. Use only the instance from the YKFAccessoryConnection or YKFNFCConnection.
- (nonnull instancetype)init NS_UNAVAILABLE;

NS_ASSUME_NONNULL_END

@end

#endif
