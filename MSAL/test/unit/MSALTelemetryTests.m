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
#import "MSALTelemetryAPIEvent.h"
#import "MSALTelemetry.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryHttpEvent.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSALTelemetryTestDispatcher.h"
#import "XCTestCase+HelperMethods.h"

@interface MSALTelemetryTests : MSALTestCase

@property (nonatomic) NSArray<NSDictionary<NSString *, NSString *> *> *receivedEvents;
@property (nonatomic) MSALTelemetryTestDispatcher *dispatcher;

@end

@implementation MSALTelemetryTests

- (void)setUp
{
    [super setUp];
    
    self.dispatcher = [MSALTelemetryTestDispatcher new];
    
    [[MSALTelemetry sharedInstance] addDispatcher:self.dispatcher setTelemetryOnFailure:NO];
    
    __weak MSALTelemetryTests *weakSelf = self;
    [self.dispatcher setDispatcherCallback:^(NSArray<NSDictionary<NSString *, NSString *> *> *event)
     {
         weakSelf.receivedEvents = event;
     }];
    
    [MSALTelemetry sharedInstance].piiEnabled = NO;
}

- (void)tearDown
{
    [super tearDown];
    
    self.dispatcher = nil;
    
    [MSALTelemetry sharedInstance].piiEnabled = NO;
}

- (void)test_telemetryPiiRules_whenPiiEnabledNo_shouldDeletePiiFields
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

- (void)test_telemetryPiiRules_whenPiiEnabledYes_shouldHashPiiFields
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
    MSALAssertStringEquals([dictionary objectForKey:TELEMETRY_KEY(MSID_TELEMETRY_KEY_USER_ID)], [@"id1234" msidComputeSHA256]);
}

#pragma mark - Private

- (NSDictionary *)getEventPropertiesByEventName:(NSString *)eventName
{
    for (NSDictionary *eventInfo in self.receivedEvents) {
        if ([[eventInfo objectForKey:TELEMETRY_KEY(MSID_TELEMETRY_KEY_EVENT_NAME)] isEqualToString:eventName]) {
            return eventInfo;
        }
    }
    
    return nil;
}

@end
