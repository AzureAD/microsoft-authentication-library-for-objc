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
#import <UIKit/UIKit.h>

#import "YKFNFCConnection.h"
#import "YKFAccessoryConnection.h"


/*!
 @protocol YKFManagerDelegate
 
 @abstract
   Implement this protocol to get notifications when a connection to the YubiKey is established or broken.
 */
@protocol YKFManagerDelegate <NSObject>

/*!
 @method didConnectNFC:connection
 
 @abstract
    The YubiKey SDK did connect to a NFC Yubikey.
 
 @param connection
    The YKFNFCConnection to the YubiKey.
 */
- (void)didConnectNFC:(YKFNFCConnection *_Nonnull)connection;

/*!
 @method didDisconnectNFC:connection:error
 
 @abstract
    The YubiKey SDK did connect to a NFC Yubikey.

 @param connection
    The YKFNFCConnection to the YubiKey that did disconnect.
 
 @method error
    If the disconnection was unexpted an NSError will be passed.
  */
- (void)didDisconnectNFC:(YKFNFCConnection *_Nonnull)connection error:(NSError *_Nullable)error;

/*!
 @method didConnectAccessory:connection
 
 @abstract
    The YubiKey SDK did connect to a Accessory Yubikey.
 
 @param connection
    The YKFAccessoryConnection to the YubiKey.
 */
- (void)didConnectAccessory:(YKFAccessoryConnection *_Nonnull)connection;

/*!
 @method didDisconnectAccessory:connection:error
 
 @abstract
    The YubiKey SDK did connect to a Accessory Yubikey.

 @param connection
    The YKFAccessoryConnection to the YubiKey that did disconnect.
 
 @method error
    If the disconnection was unexpted an NSError will be passed.
  */
- (void)didDisconnectAccessory:(YKFAccessoryConnection *_Nonnull)connection error:(NSError *_Nullable)error;

/*!
 @method didFailConnectingNFC
 
 @abstract
    The YubiKey SDK did receive a NFC connection error. This is typically that the user pressed cancel (error code 200) in the
    NFC modal or it timed out (error code 201) waiting for a NFC YubiKey.

 @method error
    The NSError passed by the SDK.
  */
@optional
- (void)didFailConnectingNFC:(NSError *_Nonnull)error;

@end


/*!
 @interface YubiKitManager
 
 @abstract
    Provides the main access point interface for YubiKit.
 */
@interface YubiKitManager : NSObject

/*!
 @property delegate
 
 @abstract
    The delegate must conform to the YKFManagerDelegate protocol. Setting this delegate will allow you
    to get notifications when a connection to the YubiKey is established or broken. If a connection is
    already established when the delegate is assigned the didConnect delegate methods will be called
    immediately.
 */
@property(nonatomic, weak) id<YKFManagerDelegate> _Nullable delegate;

/*!
 @method startNFCConnection
 
 @abstract
    Start the NFC connection.
 */
- (void)startNFCConnection API_AVAILABLE(ios(13.0));

/*!
 @method stopNFCConnection
 
 @abstract
    Stop the NFC connection.
 
 @discussion
    This is typically done as soon as you have finished your operations on the YubiKey. Stopping the NFC connection
    will also dismiss the NFC system modal presented by iOS during NFC operations.
 */
- (void)stopNFCConnection API_AVAILABLE(ios(13.0));

/*!
 @method stopNFCConnectionWithMessage:
 
 @abstract
    Stop the NFC connection and display a message.
 
 @discussion
    Use this method to close the NFC connection and display a message to the user.
  */
- (void)stopNFCConnectionWithMessage:(NSString *_Nonnull)message API_AVAILABLE(ios(13.0)) NS_SWIFT_NAME(stopNFCConnection(withMessage:));

/*!
 @method stopNFCConnectionWithErrorMessage:
 
 @abstract
    Stop the NFC connection and display a error message.
 
 @discussion
    Use this method to close the NFC connection and display a message to the user when an error condition
    occurs after the app successfully executed a command. This type of error can occur if, for example,
    you send a password to unlock the YubiKey and it is not the matching password.
  */
- (void)stopNFCConnectionWithErrorMessage:(NSString *_Nonnull)errorMessage API_AVAILABLE(ios(13.0)) NS_SWIFT_NAME(stopNFCConnection(withErrorMessage:));

/*!
 @method startAccessoryConnection
 
 @abstract
    Start the accessory connection.
 
 @discussion
    Do this when the application becomes active to continuosly listen for a YubiKey inserted into the Lightning Port.
 */
- (void)startAccessoryConnection;

/*!
 @method stopAccessoryConnection
 
 @abstract
    Stop the accessory connection.
 */
- (void)stopAccessoryConnection;


/*!
 @property otpSession
 
 @abstract
    The YKFNFCOTPSession.
 */
@property(nonatomic, nonnull, readonly) YKFNFCOTPSession *otpSession API_AVAILABLE(ios(11.0));

/*!
 @property shared
 
 @abstract
    YubiKitManager is a singleton and should be accessed only by using the shared instance provided by this property.
 */
@property (class, nonatomic, readonly, nonnull) YubiKitManager *shared;

/*
 Not available: use the shared property from YubiKitManager to retreive the shared single instance.
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

@end
