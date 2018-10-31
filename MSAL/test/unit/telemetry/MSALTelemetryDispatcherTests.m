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
#import "MSALTelemetryTestDispatcher.h"
#import "MSALTelemetryAPIEvent.h"
#import "MSALTelemetry.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryHttpEvent.h"
#import "MSIDTelemetryEventStrings.h"

@interface MSALTestRequestContext : NSObject<MSIDRequestContext>
{
    NSString *_requestId;
    NSUUID *_correlationId;
}

- (instancetype)initWithTelemetryRequestId:(NSString *)requestId correlationId:(NSUUID *)correlationId;

@end

@implementation MSALTestRequestContext

- (instancetype)initWithTelemetryRequestId:(NSString *)requestId correlationId:(NSUUID *)correlationId
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _requestId = requestId;
    _correlationId = correlationId;
    
    return self;
}

- (NSUUID *)correlationId
{
    return _correlationId;
}

- (NSString *)telemetryRequestId
{
    return _requestId;
}

- (NSString *)logComponent
{
    return nil;
}

- (NSDictionary *)appRequestMetadata
{
    return nil;
}


- (NSURLSession *)urlSession
{
    return nil;
}

- (NSDictionary *)appRequestMetadata
{
    return nil;
}

@end

@interface MSALTelemetryDispatcherTests : MSALTestCase

@end

@implementation MSALTelemetryDispatcherTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDispatcherEmpty
{
    MSALTelemetryTestDispatcher* dispatcher = [MSALTelemetryTestDispatcher new];
    
    __block NSArray<NSDictionary<NSString *, NSString *> *> *receivedEvents = nil;
    
    [dispatcher setDispatcherCallback:^(NSArray<NSDictionary<NSString *, NSString *> *> *event)
     {
         receivedEvents = event;
     }];
    
    [[MSALTelemetry sharedInstance] addDispatcher:dispatcher setTelemetryOnFailure:NO];
    
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    
    // Flush without adding any additional events
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    // Verify that default event is not added in such case
    XCTAssertEqual([receivedEvents count], 0);
}

- (void)testDispatcherAll
{
    [MSALTelemetry sharedInstance].piiEnabled = YES;
    MSALTelemetryTestDispatcher* dispatcher = [MSALTelemetryTestDispatcher new];
    
    __block NSArray<NSDictionary<NSString *, NSString *> *> *receivedEvents = nil;
    
    [[MSALTelemetry sharedInstance] addDispatcher:dispatcher setTelemetryOnFailure:NO];
    
    [dispatcher setDispatcherCallback:^(NSArray<NSDictionary<NSString *, NSString *> *> *event)
     {
         receivedEvents = event;
     }];
    
    NSString* requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSUUID* correlationId = [NSUUID UUID];
    id<MSIDRequestContext> ctx = [[MSALTestRequestContext alloc] initWithTelemetryRequestId:requestId
                                                                               correlationId:correlationId];
    
    // API event
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:@"apiEvent"];
    MSALTelemetryAPIEvent *apiEvent = [[MSALTelemetryAPIEvent alloc] initWithName:@"apiEvent" context:ctx];
    [apiEvent setProperty:@"api_property" value:@"api_value"];
    [apiEvent setCorrelationId:correlationId];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:apiEvent];
    
    // HTTP event
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:@"httpEvent"];
    
    [[MSIDTelemetry sharedInstance] stopEvent:requestId
                                        event:[[MSIDTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:ctx]];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    // Verify results: there should be 3 events (default, HTTP, API)
    XCTAssertEqual([receivedEvents count], 3);
    
    // Default event
    NSDictionary *defaultEventProperties = [receivedEvents objectAtIndex:0];
    NSArray *defaultEventPropertyNames = [defaultEventProperties allKeys];
    XCTAssertEqual([defaultEventPropertyNames count], 9);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.application_name"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.application_version"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.device_id"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.event_name"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.x_client_cpu"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.x_client_dm"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.x_client_os"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.x_client_sku"]);
    XCTAssertTrue([defaultEventPropertyNames containsObject:@"msal.x_client_ver"]);
    
    XCTAssertTrue([[defaultEventProperties objectForKey:@"msal.event_name"] compare:@"default_event"
                                                                            options:NSCaseInsensitiveSearch] == NSOrderedSame);
    
    // API event
    NSDictionary *apiEventProperties = [receivedEvents objectAtIndex:1];
    NSArray *apiEventPropertyNames = [apiEventProperties allKeys];
    XCTAssertTrue([apiEventPropertyNames containsObject:@"msal.start_time"]);
    XCTAssertTrue([apiEventPropertyNames containsObject:@"msal.stop_time"]);
    XCTAssertTrue([apiEventPropertyNames containsObject:@"msal.correlation_id"]);
    XCTAssertTrue([apiEventPropertyNames containsObject:@"msal.response_time"]);
    XCTAssertTrue([apiEventPropertyNames containsObject:@"msal.request_id"]);
    
    XCTAssertTrue([[apiEventProperties objectForKey:@"msal.event_name"] compare:@"apiEvent"
                                                                                  options:NSCaseInsensitiveSearch] == NSOrderedSame);
    XCTAssertTrue([[apiEventProperties objectForKey:@"api_property"] compare:@"api_value"
                                                                     options:NSCaseInsensitiveSearch] == NSOrderedSame);
    
    // HTTP event
    NSDictionary *httpEventProperties = [receivedEvents objectAtIndex:2];
    NSArray *httpEventPropertyNames = [httpEventProperties allKeys];
    XCTAssertTrue([httpEventPropertyNames containsObject:@"msal.start_time"]);
    XCTAssertTrue([httpEventPropertyNames containsObject:@"msal.stop_time"]);
    XCTAssertTrue([httpEventPropertyNames containsObject:@"msal.response_time"]);
    
    XCTAssertTrue([[httpEventProperties objectForKey:@"msal.event_name"] compare:@"httpEvent"
                                                                                   options:NSCaseInsensitiveSearch] == NSOrderedSame);
}

- (void)testDispatcherErrorOnlyWithError
{
    MSALTelemetryTestDispatcher* dispatcher = [MSALTelemetryTestDispatcher new];
    
    __block NSArray<NSDictionary<NSString *, NSString *> *> *receivedEvents = nil;
    
    [[MSALTelemetry sharedInstance] addDispatcher:dispatcher setTelemetryOnFailure:YES];
    
    [dispatcher setDispatcherCallback:^(NSArray<NSDictionary<NSString *, NSString *> *> *event)
     {
         receivedEvents = event;
     }];
    
    NSString* requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSUUID* correlationId = [NSUUID UUID];
    id<MSIDRequestContext> ctx = [[MSALTestRequestContext alloc] initWithTelemetryRequestId:requestId
                                                                               correlationId:correlationId];
    
    // HTTP event
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:@"httpEvent"];
    MSIDTelemetryHttpEvent *httpEvent = [[MSIDTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:ctx];
    [httpEvent setHttpErrorCode:@"error_code_123"];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:httpEvent];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    // Verify results
    XCTAssertEqual([receivedEvents count], 2);
    
    NSString *errorCode = [[receivedEvents objectAtIndex:1] objectForKey:TELEMETRY_KEY(MSID_TELEMETRY_KEY_HTTP_RESPONSE_CODE)];
    
    XCTAssertNotNil(errorCode);
    XCTAssertTrue([errorCode compare:@"error_code_123" options:NSCaseInsensitiveSearch] == NSOrderedSame);
}

- (void)testDispatcherErrorOnlyWithoutError
{
    MSALTelemetryTestDispatcher* dispatcher = [MSALTelemetryTestDispatcher new];
    
    __block NSArray<NSDictionary<NSString *, NSString *> *> *receivedEvents = nil;
    
    [[MSALTelemetry sharedInstance] addDispatcher:dispatcher setTelemetryOnFailure:YES];
    
    [dispatcher setDispatcherCallback:^(NSArray<NSDictionary<NSString *, NSString *> *> *event)
     {
         receivedEvents = event;
     }];
    
    NSString* requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSUUID* correlationId = [NSUUID UUID];
    id<MSIDRequestContext> ctx = [[MSALTestRequestContext alloc] initWithTelemetryRequestId:requestId
                                                                               correlationId:correlationId];
    
    // HTTP event
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:@"httpEvent"];
    MSIDTelemetryHttpEvent *httpEvent = [[MSIDTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:ctx];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:httpEvent];
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    // Verify results
    XCTAssertNil(receivedEvents);
}

@end
