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
    
    XCTAssertEqual([eventPropertyNames count], 8);
    XCTAssertTrue([eventPropertyNames containsObject:@"Microsoft.ADAL.device_id"]);
    XCTAssertTrue([eventPropertyNames containsObject:@"Microsoft.ADAL.device_ip_address"]);
    XCTAssertTrue([eventPropertyNames containsObject:@"Microsoft.ADAL.event_name"]);
    XCTAssertTrue([eventPropertyNames containsObject:@"Microsoft.ADAL.x_client_cpu"]);
    XCTAssertTrue([eventPropertyNames containsObject:@"Microsoft.ADAL.x_client_dm"]);
    XCTAssertTrue([eventPropertyNames containsObject:@"Microsoft.ADAL.x_client_os"]);
    XCTAssertTrue([eventPropertyNames containsObject:@"Microsoft.ADAL.x_client_sku"]);
    XCTAssertTrue([eventPropertyNames containsObject:@"Microsoft.ADAL.x_client_ver"]);
    
    XCTAssertTrue([[eventProperties objectForKey:@"Microsoft.ADAL.event_name"] compare:@"Microsoft.MSAL.default_event"
                                                                               options:NSCaseInsensitiveSearch] == NSOrderedSame);
}

- (void)testDispatcherAll
{
    MSALTelemetryTestDispatcher* dispatcher = [MSALTelemetryTestDispatcher new];
    
    __block NSArray<NSDictionary<NSString *, NSString *> *> *receivedEvents = nil;
    NSUUID* correlationId = [NSUUID UUID];
    
    [[MSALTelemetry sharedInstance] addDispatcher:dispatcher setTelemetryOnFailure:NO];
    
    [dispatcher setDispatcherCallback:^(NSArray<NSDictionary<NSString *, NSString *> *> *event)
     {
         receivedEvents = event;
     }];
    
    NSString* requestId = [[MSALTelemetry sharedInstance] registerNewRequest];
    
    // API event
    [[MSALTelemetry sharedInstance] startEvent:requestId eventName:@"apiEvent"];
    MSALTelemetryAPIEvent *apiEvent = [[MSALTelemetryAPIEvent alloc] initWithName:@"apiEvent"
                                                                      requestId:requestId
                                                                  correlationId:correlationId];
    [apiEvent setProperty:@"api_property" value:@"api_value"];
    [[MSALTelemetry sharedInstance] stopEvent:requestId event:apiEvent];
    
    // HTTP event
    [[MSALTelemetry sharedInstance] startEvent:requestId eventName:@"httpEvent"];
    
    [[MSALTelemetry sharedInstance] stopEvent:requestId
                                        event:[[MSALTelemetryHttpEvent alloc] initWithName:@"httpEvent"
                                                                                 requestId:requestId
                                                                             correlationId:correlationId]];
    
    [[MSALTelemetry sharedInstance] flush:requestId];
    
    // Verify results
    XCTAssertEqual([receivedEvents count], 2);
    
    // API event
    NSDictionary *apiEventProperties = [receivedEvents objectAtIndex:0];
    NSArray *apiEventPropertyNames = [apiEventProperties allKeys];
    XCTAssertTrue([apiEventPropertyNames containsObject:@"Microsoft.ADAL.start_time"]);
    XCTAssertTrue([apiEventPropertyNames containsObject:@"Microsoft.ADAL.stop_time"]);
    XCTAssertTrue([apiEventPropertyNames containsObject:@"Microsoft.ADAL.correlation_id"]);
    XCTAssertTrue([apiEventPropertyNames containsObject:@"Microsoft.ADAL.response_time"]);
    XCTAssertTrue([apiEventPropertyNames containsObject:@"Microsoft.ADAL.request_id"]);
    
    XCTAssertTrue([[apiEventProperties objectForKey:@"Microsoft.ADAL.event_name"] compare:@"apiEvent"
                                                                                  options:NSCaseInsensitiveSearch] == NSOrderedSame);
    XCTAssertTrue([[apiEventProperties objectForKey:@"api_property"] compare:@"api_value"
                                                                     options:NSCaseInsensitiveSearch] == NSOrderedSame);
    
    // HTTP event
    NSDictionary *httpEventProperties = [receivedEvents objectAtIndex:1];
    NSArray *httpEventPropertyNames = [httpEventProperties allKeys];
    XCTAssertTrue([httpEventPropertyNames containsObject:@"Microsoft.ADAL.start_time"]);
    XCTAssertTrue([httpEventPropertyNames containsObject:@"Microsoft.ADAL.stop_time"]);
    XCTAssertTrue([httpEventPropertyNames containsObject:@"Microsoft.ADAL.correlation_id"]);
    XCTAssertTrue([httpEventPropertyNames containsObject:@"Microsoft.ADAL.response_time"]);
    XCTAssertTrue([httpEventPropertyNames containsObject:@"Microsoft.ADAL.request_id"]);
    
    XCTAssertTrue([[httpEventProperties objectForKey:@"Microsoft.ADAL.event_name"] compare:@"httpEvent"
                                                                                   options:NSCaseInsensitiveSearch] == NSOrderedSame);
}

- (void)testDispatcherErrorOnlyWithError
{
    MSALTelemetryTestDispatcher* dispatcher = [MSALTelemetryTestDispatcher new];
    
    __block NSArray<NSDictionary<NSString *, NSString *> *> *receivedEvents = nil;
    NSUUID* correlationId = [NSUUID UUID];
    
    [[MSALTelemetry sharedInstance] addDispatcher:dispatcher setTelemetryOnFailure:YES];
    
    [dispatcher setDispatcherCallback:^(NSArray<NSDictionary<NSString *, NSString *> *> *event)
     {
         receivedEvents = event;
     }];
    
    NSString* requestId = [[MSALTelemetry sharedInstance] registerNewRequest];
    
    // HTTP event
    [[MSALTelemetry sharedInstance] startEvent:requestId eventName:@"httpEvent"];
    MSALTelemetryHttpEvent *httpEvent = [[MSALTelemetryHttpEvent alloc] initWithName:@"httpEvent"
                                                                           requestId:requestId
                                                                       correlationId:correlationId];
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
    NSUUID* correlationId = [NSUUID UUID];
    
    [[MSALTelemetry sharedInstance] addDispatcher:dispatcher setTelemetryOnFailure:YES];
    
    [dispatcher setDispatcherCallback:^(NSArray<NSDictionary<NSString *, NSString *> *> *event)
     {
         receivedEvents = event;
     }];
    
    NSString* requestId = [[MSALTelemetry sharedInstance] registerNewRequest];
    
    // HTTP event
    [[MSALTelemetry sharedInstance] startEvent:requestId eventName:@"httpEvent"];
    MSALTelemetryHttpEvent *httpEvent = [[MSALTelemetryHttpEvent alloc] initWithName:@"httpEvent"
                                                                      requestId:requestId
                                                                  correlationId:correlationId];
    [[MSALTelemetry sharedInstance] stopEvent:requestId event:httpEvent];
    
    [[MSALTelemetry sharedInstance] flush:requestId];
    
    // Verify results
    XCTAssertNil(receivedEvents);
}

@end
