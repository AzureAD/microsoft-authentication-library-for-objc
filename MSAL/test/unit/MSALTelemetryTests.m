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
#import "MSIDTelemetryEventStrings.h"
#import "MSALTestTelemetryEventsObserver.h"
#import "XCTestCase+HelperMethods.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDTestContext.h"
#import "MSIDTelemetryHttpEvent.h"
#import "MSIDTelemetryAPIEvent.h"
#import "MSIDTelemetryCacheEvent.h"
#import "MSIDTelemetryUIEvent.h"
#import "MSIDTelemetryBrokerEvent.h"
#import "MSIDTelemetryAuthorityValidationEvent.h"
#import "MSALTelemetryConfig+Internal.h"

@interface MSALTelemetryDefaultTests : MSALTestCase

@property (nonatomic) NSArray<NSDictionary<NSString *, NSString *> *> *receivedEvents;
@property (nonatomic) MSALTestTelemetryEventsObserver *observer;

@end

@implementation MSALTelemetryDefaultTests

- (void)setUp
{
    [super setUp];
    
    self.dispatcher = [MSALTelemetryTestDispatcher new];
    
    [MSALTelemetryConfig.sharedInstance addDispatcher:self.dispatcher setTelemetryOnFailure:NO];
    
    __weak MSALTelemetryTests *weakSelf = self;
    [self.dispatcher setDispatcherCallback:^(NSArray<NSDictionary<NSString *, NSString *> *> *event)
     {
         weakSelf.receivedEvents = events;
     }];
    
    MSALTelemetryConfig.sharedInstance.piiEnabled = NO;
}

- (void)tearDown
{
    [super tearDown];
    
    self.observer = nil;
    
    [MSALTelemetry sharedInstance].piiEnabled = NO;
    [[MSALTelemetry sharedInstance] removeAllObservers];
    self.receivedEvents = nil;
    MSALTelemetryConfig.sharedInstance.piiEnabled = NO;
}

#pragma mark - Telemetry Pii Rules

- (void)testTelemetryPiiRules_whenPiiEnabledNo_shouldDeletePiiFields
{
    MSALTelemetryConfig.sharedInstance.piiEnabled = NO;
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSString *eventName = @"test event";
    MSIDTelemetryBaseEvent *event = [[MSIDTelemetryBaseEvent alloc] initWithName:eventName context:nil];
    [event setProperty:MSID_TELEMETRY_KEY_USER_ID value:@"id1234"];
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:event];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    NSDictionary *dictionary = [self getEventPropertiesByEventName:eventName];
    XCTAssertNotNil(dictionary);
    XCTAssertNil(dictionary[MSID_TELEMETRY_KEY_USER_ID]);
}

- (void)testTelemetryPiiRules_whenPiiEnabledYes_shouldHashPiiFields
{
    MSALTelemetryConfig.sharedInstance.piiEnabled = YES;
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
    MSALAssertStringEquals(dictionary[TELEMETRY_KEY(MSID_TELEMETRY_KEY_USER_ID)],  x);
}

#pragma mark - flush

- (void)testFlush_whenThereIsEventAndObserverIsSet_shouldSendEvents
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

- (void)testFlush_whenThereIsEventAndObserverRemoved_shouldNotSendEvents
{
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSString *eventName = @"test event";
    MSIDTelemetryBaseEvent *event = [[MSIDTelemetryBaseEvent alloc] initWithName:eventName context:nil];
    [event setProperty:MSID_TELEMETRY_KEY_USER_ID value:@"id1234"];
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:event];
    [[MSALTelemetry sharedInstance] removeObserver:self.observer];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    XCTAssertNil(self.receivedEvents);
}

- (void)testFlush_whenThereIsNoEventAndObserverIsSet_shouldNotSendEvents
{
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    
    // Flush without adding any additional events
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    XCTAssertNil(self.receivedEvents);
}

- (void)testFlush_whenThereAre2EventsAndObserverIsSet_shouldSendEvents
{
    [MSALTelemetry sharedInstance].piiEnabled = YES;
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSUUID *correlationId = [NSUUID UUID];
    __auto_type context = [MSIDTestContext new];
    context.telemetryRequestId = requestId;
    context.correlationId = correlationId;
    // API event
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:@"apiEvent"];
    MSIDTelemetryAPIEvent *apiEvent = [[MSIDTelemetryAPIEvent alloc] initWithName:@"apiEvent" context:context];
    [apiEvent setProperty:@"api_property" value:@"api_value"];
    [apiEvent setCorrelationId:correlationId];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:apiEvent];
    // HTTP event
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:@"httpEvent"];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId
                                        event:[[MSIDTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:context]];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    // Verify results: there should be 3 events (default, API, HTTP)
    XCTAssertEqual([self.receivedEvents count], 3);
    [self assertDefaultEvent:self.receivedEvents[0] piiEnabled:YES];
    [self assertAPIEvent:self.receivedEvents[1]];
    [self assertHTTPEvent:self.receivedEvents[2]];
}

- (void)testFlush_whenThereAre2EventsAndObserverIsSetAndSetTelemetryOnFailureYes_shouldFilterEvents
{
    [[MSALTelemetry sharedInstance] removeAllObservers];
    [[MSALTelemetry sharedInstance] addEventsObserver:self.observer setTelemetryOnFailure:YES aggregationRequired:NO];
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSUUID *correlationId = [NSUUID UUID];
    __auto_type context = [MSIDTestContext new];
    context.telemetryRequestId = requestId;
    context.correlationId = correlationId;
    // HTTP event
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:@"httpEvent"];
    MSIDTelemetryHttpEvent *httpEvent = [[MSIDTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:context];
    [httpEvent setHttpErrorCode:@"error_code_123"];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:httpEvent];

    [[MSIDTelemetry sharedInstance] flush:requestId];

    XCTAssertEqual([self.receivedEvents count], 2);
    [self assertDefaultEvent:self.receivedEvents[0] piiEnabled:NO];
    [self assertHTTPEvent:self.receivedEvents[1]];
    NSString *errorCode = self.receivedEvents[1][TELEMETRY_KEY(MSID_TELEMETRY_KEY_HTTP_RESPONSE_CODE)];
    XCTAssertNotNil(errorCode);
    XCTAssertEqualObjects(errorCode, @"error_code_123");
}

- (void)testFlush_whenThereIs1NonErrorEventsAndObserverIsSetAndSetTelemetryOnFailureYes_shouldNotSendEvents
{
    [[MSALTelemetry sharedInstance] removeAllObservers];
    [[MSALTelemetry sharedInstance] addEventsObserver:self.observer setTelemetryOnFailure:YES aggregationRequired:NO];
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSUUID* correlationId = [NSUUID UUID];
    __auto_type context = [MSIDTestContext new];
    context.telemetryRequestId = requestId;
    context.correlationId = correlationId;
    // HTTP event
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:@"httpEvent"];
    MSIDTelemetryHttpEvent *httpEvent = [[MSIDTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:context];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:httpEvent];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    XCTAssertNil(self.receivedEvents);
}

#pragma mark - Private

- (NSDictionary *)getEventPropertiesByEventName:(NSString *)eventName
{
    for (NSDictionary *eventInfo in self.receivedEvents)
    {
        if ([[eventInfo objectForKey:TELEMETRY_KEY(MSID_TELEMETRY_KEY_EVENT_NAME)] isEqualToString:eventName])
        {
            return eventInfo;
        }
    }
    
    return nil;
}

- (void)assertDefaultEvent:(NSDictionary *)eventInfo piiEnabled:(BOOL)piiEnabled
{
    __auto_type defaultEventPropertyNames = [[NSSet alloc] initWithArray:[eventInfo allKeys]];
    XCTAssertEqual([defaultEventPropertyNames count], piiEnabled ? 9 : 6);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.event_name"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.x_client_cpu"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.x_client_dm"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.x_client_os"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.x_client_sku"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.x_client_ver"]);
    XCTAssertEqualObjects(eventInfo[@"msal.event_name"], @"default_event");
    
    if (!piiEnabled) return;
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.application_name"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.application_version"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.device_id"]);
}

- (void)assertAPIEvent:(NSDictionary *)eventInfo
{
    __auto_type apiEventPropertyNames = [[NSSet alloc] initWithArray:[eventInfo allKeys]];
    XCTAssertTrue([apiEventPropertyNames containsObject:@"msal.start_time"]);
    XCTAssertTrue([apiEventPropertyNames containsObject:@"msal.stop_time"]);
    XCTAssertTrue([apiEventPropertyNames containsObject:@"msal.correlation_id"]);
    XCTAssertTrue([apiEventPropertyNames containsObject:@"msal.response_time"]);
    XCTAssertTrue([apiEventPropertyNames containsObject:@"msal.request_id"]);
    XCTAssertEqualObjects(eventInfo[@"msal.event_name"], @"apiEvent");
    XCTAssertEqualObjects(eventInfo[@"msal.api_property"], @"api_value");
}

- (void)assertHTTPEvent:(NSDictionary *)eventInfo
{
    __auto_type httpEventPropertyNames = [[NSSet alloc] initWithArray:[eventInfo allKeys]];
    XCTAssertTrue([httpEventPropertyNames containsObject:@"msal.start_time"]);
    XCTAssertTrue([httpEventPropertyNames containsObject:@"msal.stop_time"]);
    XCTAssertTrue([httpEventPropertyNames containsObject:@"msal.response_time"]);
    XCTAssertEqualObjects(eventInfo[@"msal.event_name"], @"httpEvent");
}

@end


