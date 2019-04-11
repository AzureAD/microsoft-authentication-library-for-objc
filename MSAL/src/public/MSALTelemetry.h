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

@protocol MSALTelemetryEventsObserving;

NS_ASSUME_NONNULL_BEGIN

/*!
 @class MSALTelemetry
 
 The central class for MSAL telemetry.
 
 Usage: Get a singleton instance of MSALTelemetry; register an observer for receiving telemetry events.
 */
@interface MSALTelemetry : NSObject

- (instancetype _Nullable)init NS_UNAVAILABLE;
+ (instancetype _Nullable)new NS_UNAVAILABLE;

/*!
 Get a singleton instance of MSALTelemetry.
 */
+ (MSALTelemetry *)sharedInstance;

/*!
 Setting piiEnabled to YES, will allow MSAL to return fields with user information in the telemetry events. MSAL does not send telemetry data by itself to any server. If apps want to collect MSAL telemetry with user information they must setup the telemetry callback and set this flag on. By default MSAL will not return any user information in telemetry.
 */
@property (nonatomic) BOOL piiEnabled;

/*!
 Registers the observer object for receiving telemetry events.
 
 @param observer                An instance of MSALTelemetryEventsObserving implementation.
 @param setTelemetryOnFailure   If set YES, telemetry events are only dispatched when errors occurred;
                                If set NO, MSAL will dispatch all events.
 @param aggregationRequired     If set NO, all telemetry events collected by MSAL will be dispatched;
                                If set YES, MSAL will dispatch only one event for each acquire token call,
                                where the event is a brief summary (but with far less details) of all telemetry events for that acquire token call.
 */
- (void)addEventsObserver:(id<MSALTelemetryEventsObserving>)observer
    setTelemetryOnFailure:(BOOL)setTelemetryOnFailure
      aggregationRequired:(BOOL)aggregationRequired;

/*!
 Remove a telemetry observer added for receiving telemetry events.
 
 @param observer An instance of MSALTelemetryEventsObserving implementation added to the observers before.
 */
- (void)removeObserver:(id<MSALTelemetryEventsObserving>)observer;

/*!
 Remove all telemetry observers added to the observers collection.
 */
- (void)removeAllObservers;

@end

NS_ASSUME_NONNULL_END
