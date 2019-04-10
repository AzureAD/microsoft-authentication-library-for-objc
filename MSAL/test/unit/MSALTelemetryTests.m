//------------------------------------------------------------------------------
//
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSALTestCase.h"
#import "MSALTelemetry.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryHttpEvent.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSALTestTelemetryEventsObserver.h"
#import "XCTestCase+HelperMethods.h"
#import "NSData+MSIDExtensions.h"

@interface MSALTelemetryTests : MSALTestCase

@property (nonatomic) NSArray<NSDictionary<NSString *, NSString *> *> *receivedEvents;
@property (nonatomic) MSALTestTelemetryEventsObserver *observer;

@end

@implementation MSALTelemetryTests

- (void)setUp
{
    [super setUp];
    
    self.observer = [MSALTestTelemetryEventsObserver new];
    
    [[MSALTelemetry sharedInstance] addEventsObserver:self.observer setTelemetryOnFailure:NO];
    
    __weak MSALTelemetryTests *weakSelf = self;
    [self.observer setEventsReceivedBlock:^(NSArray<NSDictionary<NSString *,NSString *> *> *events)
     {
         weakSelf.receivedEvents = events;
     }];
    
    [MSALTelemetry sharedInstance].piiEnabled = NO;
}

- (void)tearDown
{
    [super tearDown];
    
    self.observer = nil;
    
    [MSALTelemetry sharedInstance].piiEnabled = NO;
    [[MSALTelemetry sharedInstance] removeAllObservers];
    self.receivedEvents = nil;
}

#pragma mark - Telemetry Pii Rules

- (void)testTelemetryPiiRules_whenPiiEnabledNo_shouldDeletePiiFields
{
    [MSALTelemetry sharedInstance].piiEnabled = NO;
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSString *eventName = @"test event";
    MSIDTelemetryBaseEvent *event = [[MSIDTelemetryBaseEvent alloc] initWithName:eventName context:nil];
    [event setProperty:MSID_TELEMETRY_KEY_USER_ID value:@"id1234"];
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:event];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    NSDictionary *dictionary = [self getEventPropertiesByEventName:eventName];
    XCTAssertNotNil(dictionary);
    XCTAssertNil([dictionary objectForKey:MSID_TELEMETRY_KEY_USER_ID]);
}

- (void)testTelemetryPiiRules_whenPiiEnabledYes_shouldHashPiiFields
{
    [MSALTelemetry sharedInstance].piiEnabled = YES;
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSString *eventName = @"test event";
    MSIDTelemetryBaseEvent *event = [[MSIDTelemetryBaseEvent alloc] initWithName:eventName context:nil];
    [event setProperty:MSID_TELEMETRY_KEY_USER_ID value:@"id1234"];
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:event];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    NSDictionary *dictionary = [self getEventPropertiesByEventName:eventName];
    XCTAssertNotNil(dictionary);

    NSString *x = [@"id1234" dataUsingEncoding:NSUTF8StringEncoding].msidSHA256.msidHexString;
    MSALAssertStringEquals([dictionary objectForKey:TELEMETRY_KEY(MSID_TELEMETRY_KEY_USER_ID)],  x);
}

#pragma mark - flush

- (void)testFlush_whenThereIsObserver_shouldSendEvents
{
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSString *eventName = @"test event";
    MSIDTelemetryBaseEvent *event = [[MSIDTelemetryBaseEvent alloc] initWithName:eventName context:nil];
    [event setProperty:MSID_TELEMETRY_KEY_USER_ID value:@"id1234"];
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:event];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    NSDictionary *dictionary = [self getEventPropertiesByEventName:eventName];
    XCTAssertNotNil(dictionary);
    XCTAssertNil([dictionary objectForKey:MSID_TELEMETRY_KEY_USER_ID]);
}

- (void)testFlush_whenObserverRemoved_shouldNotSendEvents
{
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSString *eventName = @"test event";
    MSIDTelemetryBaseEvent *event = [[MSIDTelemetryBaseEvent alloc] initWithName:eventName context:nil];
    [event setProperty:MSID_TELEMETRY_KEY_USER_ID value:@"id1234"];
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:event];
    [[MSALTelemetry sharedInstance] removeObserver:self.observer];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    NSDictionary *dictionary = [self getEventPropertiesByEventName:eventName];
    XCTAssertNil(dictionary);
}

#pragma mark - Private

- (NSDictionary *)getEventPropertiesByEventName:(NSString *)eventName
{
    for (NSDictionary *eventInfo in self.receivedEvents) {
        if ([[eventInfo objectForKey:TELEMETRY_KEY(MSID_TELEMETRY_KEY_EVENT_NAME)] isEqualToString:eventName])
        {
            return eventInfo;
        }
    }
    
    return nil;
}

@end
