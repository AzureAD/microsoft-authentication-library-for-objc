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

@class YKFU2FSignRequest, YKFU2FSignResponse, YKFU2FRegisterRequest, YKFU2FRegisterResponse;
/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name U2F Service Response Blocks
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @abstract
    Response block used by [executeSignRequest:completion:] to provide the result of a sign request.
 
 @param response
    The response of the request when it was successful. In case of error this parameter is nil.
 
 @param error
    In case of a failed request this parameter contains the error. If the request was successful
    this parameter is nil.
 */
typedef void (^YKFU2FSessionSignCompletionBlock)
    (YKFU2FSignResponse* _Nullable response, NSError* _Nullable error);

/*!
 @abstract
    Response block used by [executeRegisterRequest:completion:] to provide the result of a register request.
 
 @param response
    The response of the request when it was successful. In case of error this parameter is nil.
 
 @param error
    In case of a failed request this parameter contains the error. If the request was successful this
    parameter is nil.
 */
typedef void (^YKFU2FSessionRegisterCompletionBlock)
    (YKFU2FRegisterResponse* _Nullable response, NSError* _Nullable error);

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name U2F Service Types
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @abstract
    Enumerates the contextual states of the key when performing U2F requests.
 */
typedef NS_ENUM(NSUInteger, YKFU2FSessionKeyState) {
    
    /// The key is not performing any U2F operation.
    YYKFU2FSessionKeyStateIdle,
    
    /// The key is executing an U2F request.
    YKFU2FSessionKeyStateProcessingRequest,
    
    /// The user must touch the key to prove a human presence which allows the key to perform the current
    /// U2F operation.
    YKFU2FSessionKeyStateTouchKey
};

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name U2F Session
 * ---------------------------------------------------------------------------------------------------------------------
 */

NS_ASSUME_NONNULL_BEGIN

/*!
 @class YKFU2FSession
 
 @abstract
    Provides the interface for sending U2F requests to the YubiKey.
 @discussion
    The U2F session is mantained by the YKFConnection which controls its lifecycle. The application must not create one.
 */
@interface YKFU2FSession: YKFSession

/*!
 @property keyState
 
 @abstract
    This property provides the contextual state of the key when performing U2F requests.
 
 @discussion
    This property is useful for checking the status of an U2F request, when the operation requires the
    user presence. This property is KVO compliant and the application should observe it to ge asynchronous
    state updates of the U2F request.
 
 @note:
    The default behaviour of YubiKit is to always ask for human presence when performing an U2F operation. To detect
    asynchronously the touch state check for YKFU2FServiceKeyStateTouchKey.
 */
@property (nonatomic, assign, readonly) YKFU2FSessionKeyState keyState;

/*!
 @method registerWithChallenge:appId:completion:
 
 @abstract
    Sends to the key a U2F registration. The request is performed asynchronously on a background execution queue.
 
 @param challenge
    The U2F registration challenge which is usually received from the authentication server.
    Registration challenge message format as defined by the FIDO Alliance specifications:
    https://fidoalliance.org/specs/fido-u2f-v1.2-ps-20170411/fido-u2f-raw-message-formats-v1.2-ps-20170411.html#registration-messages
 
 @param appId
    The application ID (sometimes reffered as origin or facet ID) as described by the U2F standard.
    This is usually a domain which belongs to the application.
    Documentation for the application ID format:
    https://developers.yubico.com/U2F/App_ID.html
 
 @param completion
    The response block which gets executed after the request was processed by the key. The completion block will be
    executed on a background thread. If the intention is to update the UI, dispatch the results on the main thread
    to avoid an UIKit assertion.
 
 @note:
    This method is thread safe and can be invoked from the main or a background thread.
    The key can execute only one request at a time. If multiple requests are made against the service, they are
    queued in the order they are received and executed sequentially.
 */
- (void)registerWithChallenge:(NSString *)challenge
                        appId:(NSString *)appId
                   completion:(YKFU2FSessionRegisterCompletionBlock)completion;

/*!
 @method signWithChallenge:keyHandle:appId:completion:
 
 @abstract
    Sends to the key an U2F sign request. The operation is performed asynchronously on a background execution queue.
 
 @param challenge
    The U2F authentication challenge which is usually received from the authentication server.
    Authentication challenge message format as defined by the FIDO Alliance specifications:
    https://fidoalliance.org/specs/fido-u2f-v1.2-ps-20170411/fido-u2f-raw-message-formats-v1.2-ps-20170411.html#authentication-messages

 @param keyHandle
    The U2F authentication keyHandle which is usually received from the authentication server and used by
    the hardware key to identify the required cryptographic key for signing.
    Format as defined by the FIDO Alliance specifications:
    https://fidoalliance.org/specs/fido-u2f-v1.2-ps-20170411/fido-u2f-raw-message-formats-v1.2-ps-20170411.html#authentication-messages
 
 @param appId
    The application ID (sometimes reffered as origin or facet ID) as described by the U2F standard.
    This is usually a domain which belongs to the application.
    Documentation for the application ID format:
    https://developers.yubico.com/U2F/App_ID.html
 
 @param completion
    The response block which gets executed after the request was processed by the key. The completion block will be
    executed on a background thread. If the intention is to update the UI, dispatch the results on the main thread
    to avoid an UIKit assertion.
 
 NOTE:
    This method is thread safe and can be invoked from the main or a background thread.
    The key can execute only one request at a time. If multiple requests are made against the service, they are
    queued in the order they are received and executed sequentially.
 */
- (void)signWithChallenge:(NSString *)challenge
                keyHandle:(NSString *)keyHandle
                    appId:(NSString *)appId
                completion:(YKFU2FSessionSignCompletionBlock)completion;

/*
 Not available: use only the shared instance from the YKFAccessorySession.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

/*!
 @constant YKFU2FServiceProtocolKeyStatePropertyKey
 
 @abstract
    Helper property name to setup KVO paths in ObjC. For Swift there is a better built-in language support for
    composing keypaths.
 */
extern NSString* const YKFU2FServiceProtocolKeyStatePropertyKey;

NS_ASSUME_NONNULL_END
