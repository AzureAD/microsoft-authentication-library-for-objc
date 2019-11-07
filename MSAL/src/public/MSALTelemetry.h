// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 The central class for MSAL telemetry.
 
 Usage: Get a singleton instance of MSALTelemetry; register a callback (`telemetryCallback`) for receiving telemetry events.
 
 @note MSALTelemetry is deprecated. Use `MSALTelemetryConfig` instead to register a `telemetryCallback` and changing telemetry configuration.
 
 */
@interface MSALTelemetry : NSObject

#pragma mark - Unavailable initializers

/**
 Get a singleton instance of MSALTelemetry instead.
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

/**
Get a singleton instance of MSALTelemetry instead.
*/
+ (nonnull instancetype)new NS_UNAVAILABLE;

#pragma mark - Getting a shared instance

/**
 Get a singleton instance of MSALTelemetry.
 */
+ (nonnull MSALTelemetry *)sharedInstance DEPRECATED_MSG_ATTRIBUTE("use MSALGlobalConfig.telemetryConfig instead");

#pragma mark - Configuring telemetry collection

/**
 Setting piiEnabled to YES, will allow MSAL to return fields with user information in the telemetry events. MSAL does not send telemetry data by itself to any server. If apps want to collect MSAL telemetry with user information they must setup the telemetry callback and set this flag on. By default MSAL will not return any user information in telemetry.
 */
@property (atomic) BOOL piiEnabled DEPRECATED_MSG_ATTRIBUTE("use MSALGlobalConfig.telemetryConfig.piiEnabled instead");

/**
 If set YES, telemetry events are only dispatched when errors occurred;
 If set NO, MSAL will dispatch all events.
 */
@property (atomic) BOOL notifyOnFailureOnly DEPRECATED_MSG_ATTRIBUTE("use MSALGlobalConfig.telemetryConfig.notifyOnFailureOnly instead");

/**
 Invoked when telemetry data is received.
 */
@property (atomic, copy, nullable) MSALTelemetryCallback telemetryCallback DEPRECATED_MSG_ATTRIBUTE("use MSALGlobalConfig.telemetryConfig.telemetryCallback instead");


@end

NS_ASSUME_NONNULL_END
