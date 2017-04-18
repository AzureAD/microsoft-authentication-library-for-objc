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
#import "MSALTelemetry+Internal.h"
#import "MSALTelemetryHttpEvent.h"
#import "MSALTelemetryEventStrings.h"

@interface MSALTestRequestContext : NSObject<MSALRequestContext>
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

- (NSString *)component
{
    return nil;
}

- (NSURLSession *)urlSession
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

- (void)testDispatcherDefaultEvent
{
    MSALTelemetryTestDispatcher* dispatcher = [MSALTelemetryTestDispatcher new];
    
    __block NSArray<NSDictionary<NSString *, NSString *> *> *receivedEvents = nil;
    
    [dispatcher setDispatcherCallback:^(NSArray<NSDictionary<NSString *, NSString *> *> *event)
     {
         receivedEvents = event;
     }];
    
    [[MSALTelemetry sharedInstance] addDispatcher:dispatcher setTelemetryOnFailure:NO];
    
    // Verify results
    XCTAssertEqual([receivedEvents count], 1);
    
    NSDictionary *eventProperties = [receivedEvents objectAtIndex:0];
    NSArray *eventPropertyNames = [eventProperties allKeys];
    
    XCTAssertEqual([eventPropertyNames count], 10);
    XCTAssertTrue([eventPropertyNames containsObject:@"msal.application_name"]);
    XCTAssertTrue([eventPropertyNames containsObject:@"msal.application_version"]);
    XCTAssertTrue([eventPropertyNames containsObject:@"msal.device_id"]);
    XCTAssertTrue([eventPropertyNames containsObject:@"msal.device_ip_address"]);
    XCTAssertTrue([eventPropertyNames containsObject:@"msal.event_name"]);
    XCTAssertTrue([eventPropertyNames containsObject:@"msal.x_client_cpu"]);
    XCTAssertTrue([eventPropertyNames containsObject:@"msal.x_client_dm"]);
    XCTAssertTrue([eventPropertyNames containsObject:@"msal.x_client_os"]);
    XCTAssertTrue([eventPropertyNames containsObject:@"msal.x_client_sku"]);
    XCTAssertTrue([eventPropertyNames containsObject:@"msal.x_client_ver"]);
    
    XCTAssertTrue([[eventProperties objectForKey:@"msal.event_name"] compare:@"msal.default_event"
                                                                               options:NSCaseInsensitiveSearch] == NSOrderedSame);
}

- (void)testDispatcherAll
{
    MSALTelemetryTestDispatcher* dispatcher = [MSALTelemetryTestDispatcher new];
    
    __block NSArray<NSDictionary<NSString *, NSString *> *> *receivedEvents = nil;
    
    [[MSALTelemetry sharedInstance] addDispatcher:dispatcher setTelemetryOnFailure:NO];
    
    [dispatcher setDispatcherCallback:^(NSArray<NSDictionary<NSString *, NSString *> *> *event)
     {
         receivedEvents = event;
     }];
    
    NSString* requestId = [[MSALTelemetry sharedInstance] telemetryRequestId];
    NSUUID* correlationId = [NSUUID UUID];
    id<MSALRequestContext> ctx = [[MSALTestRequestContext alloc] initWithTelemetryRequestId:requestId
                                                                               correlationId:correlationId];
    
    // API event
    [[MSALTelemetry sharedInstance] startEvent:requestId eventName:@"apiEvent"];
    MSALTelemetryAPIEvent *apiEvent = [[MSALTelemetryAPIEvent alloc] initWithName:@"apiEvent" context:ctx];
    [apiEvent setProperty:@"api_property" value:@"api_value"];
    [[MSALTelemetry sharedInstance] stopEvent:requestId event:apiEvent];
    
    // HTTP event
    [[MSALTelemetry sharedInstance] startEvent:requestId eventName:@"httpEvent"];
    
    [[MSALTelemetry sharedInstance] stopEvent:requestId
                                        event:[[MSALTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:ctx]];
    
    [[MSALTelemetry sharedInstance] flush:requestId];
    
    // Verify results
    XCTAssertEqual([receivedEvents count], 2);
    
    // API event
    NSDictionary *apiEventProperties = [receivedEvents objectAtIndex:0];
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
    NSDictionary *httpEventProperties = [receivedEvents objectAtIndex:1];
    NSArray *httpEventPropertyNames = [httpEventProperties allKeys];
    XCTAssertTrue([httpEventPropertyNames containsObject:@"msal.start_time"]);
    XCTAssertTrue([httpEventPropertyNames containsObject:@"msal.stop_time"]);
    XCTAssertTrue([httpEventPropertyNames containsObject:@"msal.correlation_id"]);
    XCTAssertTrue([httpEventPropertyNames containsObject:@"msal.response_time"]);
    XCTAssertTrue([httpEventPropertyNames containsObject:@"msal.request_id"]);
    
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
    
    NSString* requestId = [[MSALTelemetry sharedInstance] telemetryRequestId];
    NSUUID* correlationId = [NSUUID UUID];
    id<MSALRequestContext> ctx = [[MSALTestRequestContext alloc] initWithTelemetryRequestId:requestId
                                                                               correlationId:correlationId];
    
    // HTTP event
    [[MSALTelemetry sharedInstance] startEvent:requestId eventName:@"httpEvent"];
    MSALTelemetryHttpEvent *httpEvent = [[MSALTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:ctx];
    [httpEvent setHttpErrorCode:@"error_code_123"];
    [[MSALTelemetry sharedInstance] stopEvent:requestId event:httpEvent];
    
    [[MSALTelemetry sharedInstance] flush:requestId];
    
    // Verify results
    XCTAssertEqual([receivedEvents count], 1);
    XCTAssertTrue([[[receivedEvents objectAtIndex:0] objectForKey:MSAL_TELEMETRY_KEY_OAUTH_ERROR_CODE] compare:@"error_code_123"
                                                                                                       options:NSCaseInsensitiveSearch] == NSOrderedSame);
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
    
    NSString* requestId = [[MSALTelemetry sharedInstance] telemetryRequestId];
    NSUUID* correlationId = [NSUUID UUID];
    id<MSALRequestContext> ctx = [[MSALTestRequestContext alloc] initWithTelemetryRequestId:requestId
                                                                               correlationId:correlationId];
    
    // HTTP event
    [[MSALTelemetry sharedInstance] startEvent:requestId eventName:@"httpEvent"];
    MSALTelemetryHttpEvent *httpEvent = [[MSALTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:ctx];
    [[MSALTelemetry sharedInstance] stopEvent:requestId event:httpEvent];
    
    [[MSALTelemetry sharedInstance] flush:requestId];
    
    // Verify results
    XCTAssertNil(receivedEvents);
}

@end
