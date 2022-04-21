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
#import "YKFAccessoryDescription.h"

#import "YKFConnectionProtocol.h"
#import "YKFU2FSession.h"
#import "YKFFIDO2Session.h"
#import "YKFOATHSession.h"

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFAccessorySession Types
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 Defines the states of the YKFAccessorySession.
 */
typedef NS_ENUM(NSUInteger, YKFAccessoryConnectionState) {
    
    /// The session is closed. No commands can be sent to the key.
    YKFAccessoryConnectionStateClosed,
    
    /// The session is opened and ready to use. The application can send immediately commands to the key.
    YKFAccessoryConnectionStateOpen,
    
    /// The session is in an intermediary state between opened and closed. The application should not send commands
    /// to the key when the session is in this state.
    YKFAccessoryConnectionStateClosing,
    
    /// The session is in an intermediary state between closed and opened. The application should not send commands
    /// to the key when the session is in this state.
    YKFAccessoryConnectionStateOpening
};

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFAccessorySessionProtocol
 * ---------------------------------------------------------------------------------------------------------------------
 */

NS_ASSUME_NONNULL_BEGIN

/*!
 @class YKFAccessorySession
 
 @abstract
    Provides a list of services for interacting with the YubiKey.
 */
@interface YKFAccessoryConnection : NSObject<YKFConnectionProtocol>

/*!
 @property sessionState
 
 @abstract
    This property allows to check and observe the state of the connection with the YubiKey.
 
 NOTE:
    This is a KVO compliant property. Observe it to get updates when the key is connected.
 */
@property (nonatomic, assign, readonly) YKFAccessoryConnectionState connectionState __deprecated;

/*!
 @property accessoryDescription
 
 @returns
    The description of the connected key.
 
 NOTE:
    This property becomes available when the key is connected and is nil when the key is disconnected.
 */
@property (nonatomic, readonly, nullable) YKFAccessoryDescription *accessoryDescription __deprecated;

/*!
 @property isKeyConnected
 
 @returns
    YES if the key is connected to the device.
 */
@property (nonatomic, assign, readonly, getter=isKeyConnected) BOOL keyConnected __deprecated;

/*!
 @method start
 
 @abstract
    To allow the session to connect and interract with the YubiKey, the session needs to be started. Calling this
    method will enable the session to receive events when the key is connected or disconnected and tries to connect to
    the key if it is already plugged in.
 
 @discussion
    The session is not started automatically to allow a more granular approch on when the app should listen and interract
    with the key. When the app is requesting the user to use the key, the session needs to be started. When the app no longer
    requires the user to use the key, the session should be stopped. After calling this method the session will be opened
    asynchronously and the application can monitor the state by observing the sessionState property.
 */
- (void)start;

/*!
 @method startSynchronous
 
 @abstract
    Starts the session and blocks the execution of the calling thread until the session is started or the operation times out.
 
 @discussion
    This method should be used only when the application communicates with the key over the YKFSmartCardInterface and
    a certain operation requires to bulk multiple key requests over a temporary opened connection with the key.

 @warning
    This method should never be called from the main thread, to not block it. In debug configurations, if it's called
    from the main thread, it will fire an assertion.
 
 @returns
    YES if the session was started, otherwise NO.
 */
- (BOOL)startSynchronous __deprecated;

/*!
 @method stop
 
 @abstract
    Closes the communication with the key and disables the key connection events. After calling this method the session will
    be closed asynchronously and the application will receive events on the sessionState when the session is closed. After the
    session is closed the u2fService will become unavaliable.
 */
- (void)stop;

/*!
 @method stopSynchronous
 
 @abstract
    Stops the session and blocks the execution of the calling thread until the session is stopped or the operation times out.
 
 @discussion
    This method should be used only when the application communicates with the key over the Raw Command service and
    a certain operation requires to bulk multiple key requests over a temporary opened connection with the key.
 
 @warning
    This method should never be called from the main thread, to not block it. In debug configurations, if it's called
    from the main thread, it will fire an assertion.
 
 @returns
    YES if the session was stopped, otherwise NO.
 */
- (BOOL)stopSynchronous __deprecated;

/*!
 @method cancelCommands
 
 @abstract:
    Cancels all issued commands to the key, which are still in the processing queue but not yet started. This method
    would be usually called when the user wants to cancel an operation in the UI and the application also cancels the
    requests to the key.
 */
- (void)cancelCommands;

/*
 Not available: use the shared single instance from YubiKitManager.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
