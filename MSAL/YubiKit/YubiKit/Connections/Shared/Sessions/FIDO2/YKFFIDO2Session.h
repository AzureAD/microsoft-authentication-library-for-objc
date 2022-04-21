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
#import "YKFSession.h"

@class YKFFIDO2MakeCredentialRequest, YKFFIDO2GetAssertionRequest, YKFFIDO2VerifyPinRequest, YKFFIDO2SetPinRequest, YKFFIDO2ChangePinRequest, YKFFIDO2GetInfoResponse, YKFFIDO2MakeCredentialResponse, YKFFIDO2GetAssertionResponse, YKFFIDO2PublicKeyCredentialRpEntity, YKFFIDO2PublicKeyCredentialUserEntity;

NS_ASSUME_NONNULL_BEGIN

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name Option Keys
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @abstract
    Resident Key option key to set in the create credential options dictionary.
 
 @discusion
    Instructs the authenticator to store the key material on the device. Set this key in the options dictionary of
    when necessary.
 */
extern NSString* const YKFFIDO2OptionRK;

/*!
 @abstract
    User Verification option key to set in the create credential options dictionary.
 
 @discussion
    Instructs the authenticator to require a gesture that verifies the user to complete the request. Examples of such
    gestures are fingerprint scan or a PIN. Set this key in the options dictionary when necessary.
 */
extern NSString* const YKFFIDO2OptionUV;

/*!
 @abstract
    User Presence option key to set in the request options dictionary.
 
 @discussion
    Instructs the authenticator to require user consent to complete the operation. Set this key in the options
    dictionary when necessary.
 */
extern NSString* const YKFFIDO2OptionUP;


/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name FIDO2 Service Response Blocks
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @abstract
    Response block used by FIDO2 requests which do not provide a result for the request.
 
 @param error
    In case of a failed request this parameter contains the error. If the request was successful
    this parameter is nil.
 */
typedef void (^YKFFIDO2SessionGenericCompletionBlock)
    (NSError* _Nullable error);

/*!
 @abstract
    Response block for [executeGetInfoRequestWithCompletion:] which provides the result for the execution
    of the Get Info request.
 
 @param response
    The response of the request when it was successful. In case of error this parameter is nil.
 
 @param error
    In case of a failed request this parameter contains the error. If the request was successful this
    parameter is nil.
 */
typedef void (^YKFFIDO2SessionGetInfoCompletionBlock)
    (YKFFIDO2GetInfoResponse* _Nullable response, NSError* _Nullable error);

/*!
 @abstract
    Response block for [executeMakeCredentialRequest:completion:] which provides the result for the execution
    of the Make Credential request.
 
 @param response
    The response of the request when it was successful. In case of error this parameter is nil.
 
 @param error
    In case of a failed request this parameter contains the error. If the request was successful this
    parameter is nil.
 */
typedef void (^YKFFIDO2SessionMakeCredentialCompletionBlock)
    (YKFFIDO2MakeCredentialResponse* _Nullable response, NSError* _Nullable error);

/*!
 @abstract
    Response block for [executeGetAssertionRequest:completion:] which provides the result for the execution
    of the Get Assertion request.
 
 @param response
    The response of the request when it was successful. In case of error this parameter is nil.
 
 @param error
    In case of a failed request this parameter contains the error. If the request was successful this
    parameter is nil.
 */
typedef void (^YKFFIDO2SessionGetAssertionCompletionBlock)
    (YKFFIDO2GetAssertionResponse* _Nullable response, NSError* _Nullable error);

/*!
 @abstract
    Response block for [executeGetPinRetriesRequestWithCompletion:] which provides available number
    of PIN retries.
 
 @param retries
    The number of PIN retries.
 
 @param error
    In case of a failed request this parameter contains the error. If the request was successful this
    parameter is nil.
 */
typedef void (^YKFFIDO2SessionGetPinRetriesCompletionBlock)
    (NSUInteger retries, NSError* _Nullable error);

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name FIDO2 Service Types
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 Enumerates the contextual states of the key when performing FIDO2 requests.
 */
typedef NS_ENUM(NSUInteger, YKFFIDO2SessionKeyState) {
    
    /// The key is not performing any FIDO2 operation.
    YKFFIDO2SessionKeyStateIdle,
    
    /// The key is executing a FIDO2 request.
    YKFFIDO2SessionKeyStateProcessingRequest,
    
    /// The user must touch the key to prove a human presence which allows the key to perform the current operation.
    YKFFIDO2SessionKeyStateTouchKey
};



/*!
 @abstract
    This delegate protocol provides the contextual state of the key when performing FIDO2 requests.
 
 @discussion
    This delegate will be called with the new key state when the status of the Yubikey changes.
 */
@protocol YKFFIDO2SessionKeyStateDelegate

- (void)keyStateChanged:(YKFFIDO2SessionKeyState)keyState;

@end

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFFIDO2Session
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @class YKFFIDO2Session
 
 @abstract
    Provides the interface for executing FIDO2/CTAP2 requests with the key.
 @discussion
    The FIDO2 service is mantained by the key session which controls its lifecycle. The application must not
    create one. It has to use only the single shared instance from YKFAccessorySession and sync its usage with
    the session state.
 */
@interface YKFFIDO2Session: YKFSession

/*!
 @abstract
   The FIDO2Session's key state delegate.
 
 @discussion
    The delegate must conform to the YKFFIDO2SessionKeyStateDelegate protocol. Setting this
    delegate you will get notificed to changes to the the key state.
  */
@property (nonatomic, assign, readwrite) id<YKFFIDO2SessionKeyStateDelegate> delegate;

/*!
 @abstract
    This property provides the contextual state of the key when performing FIDO2 requests.
 
 @discussion
    This property is useful for checking the status of a FIDO2 request, when the default or specified
    behaviour of the request requires UP. This property is KVO compliant and the application should
    observe it to get asynchronous state updates.
 */
@property (nonatomic, assign, readonly) YKFFIDO2SessionKeyState keyState;

/*!
 @method getInfoWithCompletion:
 
 @abstract
    Sends to the key a FIDO2 Get Info request to retrieve the authenticator properties. The request
    is performed asynchronously on a background execution queue.
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)getInfoWithCompletion:(YKFFIDO2SessionGetInfoCompletionBlock)completion;

/*!
 @method verifyPin:completion:
 
 @abstract
    Authenticates the session with the FIDO2 application from the key. This should be done once
    per session lifetime (while the key is plugged in) or after the user verification was cleared
    by calling [clearUserVerification].
 
 @discussion
    Once authenticated, the library will automatically attach the required PIN authentication parameters
    to the subsequent requests against the key, when necessary.
 
 @param pin
    The pin to use for authentication.
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)verifyPin:(NSString *)pin completion:(YKFFIDO2SessionGenericCompletionBlock)completion;

/*!
 @method clearUserVerification

 @abstract
    Clears the cached user verification if the user authenticated with [executeVerifyPinRequest:completion:].
 */
- (void)clearUserVerification;

/*!
 @method executeSetPinRequest:completion:
 
 @abstract
    Sets a PIN for the key FIDO2 application.
 
 @discussion
    If the key FIDO2 application has a PIN this method will return an error and change PIN should be used
    instead. The PIN can be an alphanumeric string with the length in the range [4, 255].
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)setPin:(NSString *)pin completion:(YKFFIDO2SessionGenericCompletionBlock)completion;

/*!
 @method executeChangePinRequest:completion:
 
 @abstract
    Changes the existing PIN for the key FIDO2 application.
 
 @discussion
    If the key FIDO2 application doesn't have a PIN, this method will return an error and set PIN should
    be used instead. The PIN can be an alphanumeric string with the length in the range [4, 255].
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)changePin:(NSString *)oldPin to:(NSString *)newPin completion:(YKFFIDO2SessionGenericCompletionBlock)completion;

/*!
 @method executeGetPinRetriesWithCompletion:
 
 @abstract
    Requests the number of PIN retries from the key FIDO2 application.
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)getPinRetriesWithCompletion:(YKFFIDO2SessionGetPinRetriesCompletionBlock)completion;

/*!
 @method makeCredentialWithClientDataHash:clientDataHash:rp:user:pubKeyCredParams:exludeList:options:completion:
 
 @abstract
    Sends a command to the key to create/update a FIDO2 credential. This command maps to the
    authenticatorMakeCredential command from CTAP2 protocol:
    https://fidoalliance.org/specs/fido-v2.0-rd-20180702/fido-client-to-authenticator-protocol-v2.0-rd-20180702.pdf
    The request is performed asynchronously on a background execution queue.
 
 @param clientDataHash
    Hash of the ClientData contextual binding specified by host.
    This property is required by the key to fulfil the request. The value should be a SHA256 of the received
    Client Data from the WebAuthN server. If missing, the FIDO2 Session will return an error when trying to
    execute the request.
 
 @param rp
    This property describes a Relying Party with which the new public key credential will be associated.
    This property is required by the key to fulfil the request. If missing, the FIDO2 Service will return
    an error when trying to execute the request.
 
 @param user
    This property describes the user account to which the new public key credential will be associated at the RP.
    This property is required by the key to fulfil the request. If missing, the FIDO2 Service will return
    an error when trying to execute the request.
 
 @param pubKeyCredParams
    A list of YKFFIDO2PublicKeyCredentialParam objects with algorithm identifiers which are values registered in
    the IANA COSE Algorithms registry. This sequence is ordered from most preferred (by the RP) to least preferred.
    This property is required by the key to fulfil the request. If missing, the FIDO2 Service will return
    an error when trying to execute the request.

 @param excludeList
    A list of YKFFIDO2PublicKeyCredentialDescriptor to be excluded when creating a new credential.
    The authenticator returns an error if the authenticator already contains one of the credentials enumerated in
    this sequence. This allows RPs to limit the creation of multiple credentials for the same account on a single
    authenticator. This property is optional.
 
 @param options
    Parameters to influence authenticator operation, as specified in in the table below.
    This parameter is optional.

    @code
    Key           | Definition
    -------------------------------------------------------------------
    rk            | resident key: Instructs the authenticator to store
                    the key material on the device.
    ----------------------------------------------------------------------------------------
    uv            | user verification: Instructs the authenticator to
                    require a gesture that verifies the user to complete
                    the request. Examples of such gestures are fingerprint
                    scan or a PIN. This key is not supported by the 5Ci
                    nor the NFC Yubikeys.
    -------------------------------------------------------------------
    up            | user presence: The key will return an error if this
                    parameter is set when creating a credential.
                    UP cannot be configured when creating a credential
                    because it's implicitly set to true.
    @endcode
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)makeCredentialWithClientDataHash:(NSData *)clientDataHash
                                      rp:(YKFFIDO2PublicKeyCredentialRpEntity *)rp
                                    user:(YKFFIDO2PublicKeyCredentialUserEntity *)user
                        pubKeyCredParams:(NSArray *)pubKeyCredParams
                              excludeList:(NSArray * _Nullable)excludeList
                                 options:(NSDictionary  * _Nullable)options
                              completion:(YKFFIDO2SessionMakeCredentialCompletionBlock)completion;

/*!
 @method getAssertionWithClientDataHash:rpId:allowList:options:completion:
 
 @abstract
    Sends to the key a FIDO2 Get Assertion request to retrieve signatures for FIDO2 credentials. The request
    is performed asynchronously on a background execution queue.
 
 @param clientDataHash
    Hash of the serialized client data collected by the host as defined in WebAuthN.
    This property is required by the key to fulfil the request. The value should be a SHA256 of the received
    Client Data from the WebAuthN server. If missing, the FIDO2 Session will return an error when trying to
    execute the request.
 
 @param rpId
    Relying party identifier as defined in WebAuthN.
    This property is required by the key to fulfil the request. If missing, the FIDO2 Service will return an error
    when trying to execute the request.
 
 @param allowList
    A sequence of YKFFIDO2PublicKeyCredentialDescriptor objects, each denoting a credential. The authenticator
    will generate a signature for each credential.
    This property is optional but it's recommended to always specify a credential in the list and not make
    assumtions on the number of credentials generated by the key.
 
 @param options
    The options provide a list of properties to influence authenticator operation when signing, as specified
    in in the table below. This parameter is optional.
    
    @code
    Key           | Default value      | Definition
    ----------------------------------------------------------------------------------------
    uv            | false              | user verification: Instructs the authenticator to
                                         require a gesture that verifies the user to complete
                                         the request. Examples of such gestures are fingerprint
                                         scan or a PIN.
    ----------------------------------------------------------------------------------------
    up            | true               | user presence: Instructs the authenticator to require
                                         user consent to complete the operation.
    @endcode
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)getAssertionWithClientDataHash:(NSData *)clientDataHash
                                  rpId:(NSString *)rpId
                             allowList:(NSArray * _Nullable)allowList
                               options:(NSDictionary * _Nullable)options
                            completion:(YKFFIDO2SessionGetAssertionCompletionBlock)completion;

/*!
 @method getNextAssertionWithCompletion:completion:
 
 @abstract
    Sends to the key a FIDO2 Get Next Assertion request to retrieve the next assertion from the list of
    specified FIDO2 credentials in a previous Get Assertion request. The request is performed asynchronously on
    a background execution queue.
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)getNextAssertionWithCompletion:(YKFFIDO2SessionGetAssertionCompletionBlock)completion;

/*!
 @method resetWithCompletion:
 
 @abstract
    Sends to the key a FIDO2 Reset to revert the key FIDO2 application to factory settings.
 
 @discussion
    The reset operation is destructive. It will delete all stored credentials, including the possibility to
    compute the non-resident keys which were created with the authenticator before resetting it. To avoid an
    accidental reset during the regular operation, the reset request must be executed within 5 seconds after
    the key was powered up (plugged in) and it requires user presence (touch).
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)resetWithCompletion:(YKFFIDO2SessionGenericCompletionBlock)completion;

/*
 Not available: use only the shared instance from the YKFAccessorySession.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
