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
#import "XCTestCase+HelperMethods.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDTestContext.h"
#import "MSIDTelemetryHttpEvent.h"
#import "MSIDTelemetryAPIEvent.h"
#import "MSIDTelemetryCacheEvent.h"
#import "MSIDTelemetryUIEvent.h"
#import "MSIDTelemetryBrokerEvent.h"
#import "MSIDTelemetryAuthorityValidationEvent.h"
#import "MSALGlobalConfig.h"
#import "MSALTelemetryConfig.h"

@interface MSALTelemetryAggregatedTests : MSALTestCase

@property (nonatomic) NSDictionary<NSString *, NSString *> *receivedEvent;
@property (nonatomic) NSString *requestId;
@property (nonatomic) MSIDTestContext *context;

@end

@implementation MSALTelemetryAggregatedTests

- (void)setUp
{
    [super setUp];
    
    MSALGlobalConfig.telemetryConfig.telemetryCallback = ^(NSDictionary<NSString *, NSString *> *event)
    {
        self.receivedEvent = event;
    };
    
    MSALGlobalConfig.telemetryConfig.piiEnabled = NO;
    MSIDTelemetry.sharedInstance.notifyOnFailureOnly = NO;
    
    self.requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    
    __auto_type context = [MSIDTestContext new];
    context.telemetryRequestId = self.requestId;
    context.correlationId = [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000001"];
    self.context = context;
}

- (void)tearDown
{
    [super tearDown];
    
    MSALGlobalConfig.telemetryConfig.telemetryCallback = nil;
    self.receivedEvent = nil;
}

#pragma mark - flush aggregated

- (void)testFlush_whenThereIsOneHttpEvent_shouldSendAggregatedEvent
{
    // HTTP event
    MSIDTelemetryHttpEvent *httpEvent = [[MSIDTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:self.context];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:@"httpEvent"];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:httpEvent];
    
    [[MSIDTelemetry sharedInstance] flush:self.requestId];
    
    XCTAssertNotNil(self.receivedEvent);
    NSDictionary *eventInfo = self.receivedEvent;
#if TARGET_OS_IPHONE
    XCTAssertEqual(eventInfo.count, 10);
    XCTAssertNotNil(eventInfo[@"msal.x_client_dm"]);
#else
    XCTAssertEqual(eventInfo.count, 9);
#endif
    XCTAssertEqualObjects(eventInfo[@"msal.correlation_id"], @"00000000-0000-0000-0000-000000000001");
    XCTAssertEqualObjects(eventInfo[@"msal.http_event_count"], @1);
    XCTAssertEqualObjects(eventInfo[@"msal.oauth_error_code"], @"");
    XCTAssertNotNil(eventInfo[@"msal.request_id"]);
    XCTAssertEqualObjects(eventInfo[@"msal.response_code"], @"");
    XCTAssertNotNil(eventInfo[@"msal.x_client_cpu"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_os"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_sku"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_ver"]);
}

- (void)testFlush_whenThereAreTwoHttpEvents_shouldSendAggregatedEvent
{
    // HTTP event #1
    MSIDTelemetryHttpEvent *httpEvent = [[MSIDTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:self.context];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:@"httpEvent"];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:httpEvent];
    // HTTP event #2
    httpEvent = [[MSIDTelemetryHttpEvent alloc] initWithName:@"httpEvent2" context:self.context];
    [httpEvent setHttpResponseCode:@"200"];
    [httpEvent setProperty:MSID_TELEMETRY_KEY_OAUTH_ERROR_CODE value:@"invalid_grant"];
    [httpEvent setProperty:MSID_TELEMETRY_KEY_SERVER_ERROR_CODE value:@"123"];
    [httpEvent setProperty:MSID_TELEMETRY_KEY_SERVER_SUBERROR_CODE value:@"1234"];
    [httpEvent setProperty:MSID_TELEMETRY_KEY_RT_AGE value:@"255.0643"];
    [httpEvent setProperty:MSID_TELEMETRY_KEY_SPE_INFO value:@"some info"];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:@"httpEvent2"];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:httpEvent];
    
    [[MSIDTelemetry sharedInstance] flush:self.requestId];
    
    XCTAssertNotNil(self.receivedEvent);
    NSDictionary *eventInfo = self.receivedEvent;
#if TARGET_OS_IPHONE
    XCTAssertEqual(eventInfo.count, 14);
    XCTAssertNotNil(eventInfo[@"msal.x_client_dm"]);
#else
    XCTAssertEqual(eventInfo.count, 13);
#endif
    XCTAssertEqualObjects(eventInfo[@"msal.correlation_id"], @"00000000-0000-0000-0000-000000000001");
    XCTAssertEqualObjects(eventInfo[@"msal.http_event_count"], @2);
    XCTAssertEqualObjects(eventInfo[@"msal.oauth_error_code"], @"invalid_grant");
    XCTAssertNotNil(eventInfo[@"msal.request_id"]);
    XCTAssertEqualObjects(eventInfo[@"msal.response_code"], @"200");
    XCTAssertEqualObjects(eventInfo[@"msal.server_error_code"], @"123");
    XCTAssertEqualObjects(eventInfo[@"msal.server_sub_error_code"], @"1234");
    XCTAssertEqualObjects(eventInfo[@"msal.rt_age"], @"255.0643");
    XCTAssertEqualObjects(eventInfo[@"msal.spe_info"], @"some info");
    XCTAssertNotNil(eventInfo[@"msal.x_client_cpu"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_os"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_sku"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_ver"]);
}

- (void)testFlush_whenThereIsOneApiEvent_shouldSendAggregatedEvent
{
    // API event #1
    __auto_type eventName = @"api event";
    __auto_type event = [[MSIDTelemetryAPIEvent alloc] initWithName:eventName context:self.context];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:event];
    
    [[MSIDTelemetry sharedInstance] flush:self.requestId];
    
    XCTAssertNotNil(self.receivedEvent);
    NSDictionary *eventInfo = self.receivedEvent;
#if TARGET_OS_IPHONE
    XCTAssertEqual(eventInfo.count, 8);
    XCTAssertNotNil(eventInfo[@"msal.x_client_dm"]);
#else
    XCTAssertEqual(eventInfo.count, 7);
#endif
    XCTAssertEqualObjects(eventInfo[@"msal.correlation_id"], @"00000000-0000-0000-0000-000000000001");
    XCTAssertNotNil(eventInfo[@"msal.response_time"]);
    XCTAssertNotNil(eventInfo[@"msal.request_id"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_cpu"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_os"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_sku"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_ver"]);
}

- (void)testFlush_whenThereAreTwoApiEvents_shouldSendAggregatedEvent
{
    // API event #1
    __auto_type eventName = @"api event";
    __auto_type event = [[MSIDTelemetryAPIEvent alloc] initWithName:eventName context:self.context];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:event];
    // API event #2
    eventName = @"api event2";
    event = [[MSIDTelemetryAPIEvent alloc] initWithName:eventName context:self.context];
    [event setExtendedExpiresOnSetting:@"no"];
    [event setPromptType:MSIDPromptTypeLogin];
    [event setResultStatus:@"succeeded"];
    [event setProperty:MSID_TELEMETRY_KEY_TENANT_ID value:@"6fd1f5cd-a94c-4335-889b-6c598e6d8048"];
    [event setProperty:MSID_TELEMETRY_KEY_USER_ID value:@"1234"];
    [event setProperty:MSID_TELEMETRY_KEY_CLIENT_ID value:@"c3c7f5e5-7153-44d4-90e6-329686d48d76"];
    [event setProperty:MSID_TELEMETRY_KEY_API_ID value:@"8"];
    [event setProperty:MSID_TELEMETRY_KEY_API_ERROR_CODE value:@"some error code"];
    [event setProperty:MSID_TELEMETRY_KEY_ERROR_DOMAIN value:@"some domain"];
    [event setProperty:MSID_TELEMETRY_KEY_PROTOCOL_CODE value:@"some protocol code"];
    [event setProperty:MSID_TELEMETRY_KEY_IS_SUCCESSFUL value:@"yes"];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:event];
    
    [[MSIDTelemetry sharedInstance] flush:self.requestId];
    
    XCTAssertNotNil(self.receivedEvent);
    NSDictionary *eventInfo = self.receivedEvent;
#if TARGET_OS_IPHONE
    XCTAssertEqual(eventInfo.count, 16);
    XCTAssertNotNil(eventInfo[@"msal.x_client_dm"]);
#else
    XCTAssertEqual(eventInfo.count, 15);
#endif
    XCTAssertEqualObjects(eventInfo[@"msal.correlation_id"], @"00000000-0000-0000-0000-000000000001");
    XCTAssertNotNil(eventInfo[@"msal.response_time"]);
    XCTAssertNotNil(eventInfo[@"msal.request_id"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_cpu"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_os"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_sku"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_ver"]);
    XCTAssertEqualObjects(eventInfo[@"msal.api_error_code"], @"some error code");
    XCTAssertEqualObjects(eventInfo[@"msal.api_id"], @"8");
    XCTAssertEqualObjects(eventInfo[@"msal.error_domain"], @"some domain");
    XCTAssertEqualObjects(eventInfo[@"msal.error_protocol_code"], @"some protocol code");
    XCTAssertEqualObjects(eventInfo[@"msal.extended_expires_on_setting"], @"no");
    XCTAssertEqualObjects(eventInfo[@"msal.is_successfull"], @"yes");
    XCTAssertEqualObjects(eventInfo[@"msal.prompt_behavior"], @"login");
    XCTAssertEqualObjects(eventInfo[@"msal.status"], @"succeeded");
}

- (void)testFlush_whenThereIsOneCacheEvent_shouldSendAggregatedEvent
{
    // Cache event #1
    __auto_type eventName = @"cache event";
    __auto_type event = [[MSIDTelemetryCacheEvent alloc] initWithName:eventName context:self.context];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:event];
    
    [[MSIDTelemetry sharedInstance] flush:self.requestId];
    
    XCTAssertNotNil(self.receivedEvent);
    NSDictionary *eventInfo = self.receivedEvent;
#if TARGET_OS_IPHONE
    XCTAssertEqual(eventInfo.count, 8);
    XCTAssertNotNil(eventInfo[@"msal.x_client_dm"]);
#else
    XCTAssertEqual(eventInfo.count, 7);
#endif
    XCTAssertEqualObjects(eventInfo[@"msal.correlation_id"], @"00000000-0000-0000-0000-000000000001");
    XCTAssertEqualObjects(eventInfo[@"msal.cache_event_count"], @1);
    XCTAssertNotNil(eventInfo[@"msal.request_id"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_cpu"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_os"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_sku"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_ver"]);
}

- (void)testFlush_whenThereAreTwoCacheEvents_shouldSendAggregatedEvent
{
    // Cache event #1
    __auto_type eventName = @"cache event";
    __auto_type event = [[MSIDTelemetryCacheEvent alloc] initWithName:eventName context:self.context];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:event];
    // Cache event #2
    eventName = @"cache event 2";
    event = [[MSIDTelemetryCacheEvent alloc] initWithName:eventName context:self.context];
    [event setProperty:MSID_TELEMETRY_KEY_RT_STATUS value:@"1"];
    [event setProperty:MSID_TELEMETRY_KEY_FRT_STATUS value:@"2"];
    [event setProperty:MSID_TELEMETRY_KEY_MRRT_STATUS value:@"3"];
    [event setProperty:MSID_TELEMETRY_KEY_SPE_INFO value:@"4"];
    [event setProperty:MSID_TELEMETRY_KEY_WIPE_APP value:@"5"];
    [event setProperty:MSID_TELEMETRY_KEY_WIPE_TIME value:@"6"];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:event];
    
    [[MSIDTelemetry sharedInstance] flush:self.requestId];
    
    XCTAssertNotNil(self.receivedEvent);
    NSDictionary *eventInfo = self.receivedEvent;
#if TARGET_OS_IPHONE
    XCTAssertEqual(eventInfo.count, 14);
    XCTAssertNotNil(eventInfo[@"msal.x_client_dm"]);
#else
    XCTAssertEqual(eventInfo.count, 13);
#endif
    XCTAssertEqualObjects(eventInfo[@"msal.correlation_id"], @"00000000-0000-0000-0000-000000000001");
    XCTAssertEqualObjects(eventInfo[@"msal.cache_event_count"], @2);
    XCTAssertEqualObjects(eventInfo[@"msal.token_rt_status"], @"1");
    XCTAssertEqualObjects(eventInfo[@"msal.token_frt_status"], @"2");
    XCTAssertEqualObjects(eventInfo[@"msal.token_mrrt_status"], @"3");
    XCTAssertEqualObjects(eventInfo[@"msal.spe_info"], @"4");
    XCTAssertEqualObjects(eventInfo[@"msal.wipe_app"], @"5");
    XCTAssertEqualObjects(eventInfo[@"msal.wipe_time"], @"6");
    XCTAssertNotNil(eventInfo[@"msal.request_id"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_cpu"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_os"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_sku"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_ver"]);
}

- (void)testFlush_whenThereIsOneUiEvent_shouldSendAggregatedEvent
{
    // UI event #1
    __auto_type eventName = @"UI event";
    __auto_type event = [[MSIDTelemetryUIEvent alloc] initWithName:eventName context:self.context];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:event];
    
    [[MSIDTelemetry sharedInstance] flush:self.requestId];
    
    XCTAssertNotNil(self.receivedEvent);
    NSDictionary *eventInfo = self.receivedEvent;
#if TARGET_OS_IPHONE
    XCTAssertEqual(eventInfo.count, 10);
    XCTAssertNotNil(eventInfo[@"msal.x_client_dm"]);
#else
    XCTAssertEqual(eventInfo.count, 9);
#endif
    XCTAssertEqualObjects(eventInfo[@"msal.correlation_id"], @"00000000-0000-0000-0000-000000000001");
    XCTAssertNotNil(eventInfo[@"msal.request_id"]);
    XCTAssertEqualObjects(eventInfo[@"msal.ntlm"], @"");
    XCTAssertEqualObjects(eventInfo[@"msal.ui_event_count"], @1);
    XCTAssertEqualObjects(eventInfo[@"msal.user_cancel"], @"");
    XCTAssertNotNil(eventInfo[@"msal.x_client_cpu"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_os"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_sku"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_ver"]);
}

- (void)testFlush_whenThereAreTwoUiEvents_shouldSendAggregatedEvent
{
    MSALGlobalConfig.telemetryConfig.piiEnabled = YES;
    // UI event #1
    __auto_type eventName = @"UI event";
    __auto_type event = [[MSIDTelemetryUIEvent alloc] initWithName:eventName context:self.context];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:event];
    // UI event #2
    eventName = @"UI event 2";
    event = [[MSIDTelemetryUIEvent alloc] initWithName:eventName context:self.context];
    [event setProperty:MSID_TELEMETRY_KEY_USER_CANCEL value:@"1"];
    [event setProperty:MSID_TELEMETRY_KEY_LOGIN_HINT value:@"2"];
    [event setProperty:MSID_TELEMETRY_KEY_NTLM_HANDLED value:@"3"];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:event];
    
    [[MSIDTelemetry sharedInstance] flush:self.requestId];
    
    XCTAssertNotNil(self.receivedEvent);
    NSDictionary *eventInfo = self.receivedEvent;
#if TARGET_OS_IPHONE
    XCTAssertEqual(eventInfo.count, 14);
    XCTAssertNotNil(eventInfo[@"msal.x_client_dm"]);
    XCTAssertNotNil(eventInfo[@"msal.application_version"]);
#else
    XCTAssertEqual(eventInfo.count, 13);
#endif
    XCTAssertEqualObjects(eventInfo[@"msal.correlation_id"], @"00000000-0000-0000-0000-000000000001");
    XCTAssertNotNil(eventInfo[@"msal.request_id"]);
    XCTAssertEqualObjects(eventInfo[@"msal.ntlm"], @"3");
    XCTAssertEqualObjects(eventInfo[@"msal.ui_event_count"], @2);
    XCTAssertEqualObjects(eventInfo[@"msal.user_cancel"], @"1");
    XCTAssertEqualObjects(eventInfo[@"msal.login_hint"], @"d4735e3a265e16eee03f59718b9b5d03019c07d8b6c51f90da3a666eec13ab35");
    XCTAssertNotNil(eventInfo[@"msal.x_client_cpu"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_os"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_sku"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_ver"]);
    XCTAssertNotNil(eventInfo[@"msal.application_name"]);
    XCTAssertNotNil(eventInfo[@"msal.device_id"]);
}

- (void)testFlush_whenThereIsOneBrokerEvent_shouldSendAggregatedEvent
{
    // Broker event #1
    __auto_type eventName = @"Broker event";
    __auto_type event = [[MSIDTelemetryBrokerEvent alloc] initWithName:eventName context:self.context];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:event];
    
    [[MSIDTelemetry sharedInstance] flush:self.requestId];
    
    XCTAssertNotNil(self.receivedEvent);
    NSDictionary *eventInfo = self.receivedEvent;
#if TARGET_OS_IPHONE
    XCTAssertEqual(eventInfo.count, 8);
    XCTAssertNotNil(eventInfo[@"msal.x_client_dm"]);
#else
    XCTAssertEqual(eventInfo.count, 7);
#endif
    XCTAssertEqualObjects(eventInfo[@"msal.correlation_id"], @"00000000-0000-0000-0000-000000000001");
    XCTAssertEqualObjects(eventInfo[@"msal.broker_app"], @"Microsoft Authenticator");
    XCTAssertNotNil(eventInfo[@"msal.request_id"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_cpu"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_os"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_sku"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_ver"]);
}

- (void)testFlush_whenThereAreTwoBrokerEvents_shouldSendAggregatedEvent
{
    // Broker event #1
    __auto_type eventName = @"Broker event";
    __auto_type event = [[MSIDTelemetryBrokerEvent alloc] initWithName:eventName context:self.context];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:event];
    // Broker event #2
    eventName = @"Broker event 2";
    event = [[MSIDTelemetryBrokerEvent alloc] initWithName:eventName context:self.context];
    [event setProperty:MSID_TELEMETRY_KEY_BROKER_VERSION value:@"134"];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:event];
    
    [[MSIDTelemetry sharedInstance] flush:self.requestId];
    
    XCTAssertNotNil(self.receivedEvent);
    NSDictionary *eventInfo = self.receivedEvent;
#if TARGET_OS_IPHONE
    XCTAssertEqual(eventInfo.count, 9);
    XCTAssertNotNil(eventInfo[@"msal.x_client_dm"]);
#else
    XCTAssertEqual(eventInfo.count, 8);
#endif
    XCTAssertEqualObjects(eventInfo[@"msal.correlation_id"], @"00000000-0000-0000-0000-000000000001");
    XCTAssertEqualObjects(eventInfo[@"msal.broker_app"], @"Microsoft Authenticator");
    XCTAssertEqualObjects(eventInfo[@"msal.broker_version"], @"134");
    XCTAssertNotNil(eventInfo[@"msal.request_id"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_cpu"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_os"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_sku"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_ver"]);
}

- (void)testFlush_whenThereIsOneAuthorityValidationEvent_shouldSendAggregatedEvent
{
    // Authority validation event #1
    __auto_type eventName = @"Authority validation event";
    __auto_type event = [[MSIDTelemetryAuthorityValidationEvent alloc] initWithName:eventName context:self.context];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:event];
    
    [[MSIDTelemetry sharedInstance] flush:self.requestId];
    
    XCTAssertNotNil(self.receivedEvent);
    NSDictionary *eventInfo = self.receivedEvent;
#if TARGET_OS_IPHONE
    XCTAssertEqual(eventInfo.count, 7);
    XCTAssertNotNil(eventInfo[@"msal.x_client_dm"]);
#else
    XCTAssertEqual(eventInfo.count, 6);
#endif
    XCTAssertEqualObjects(eventInfo[@"msal.correlation_id"], @"00000000-0000-0000-0000-000000000001");
    XCTAssertNotNil(eventInfo[@"msal.request_id"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_cpu"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_os"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_sku"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_ver"]);
}

- (void)testFlush_whenThereAreTwoAuthorityValidationEvents_shouldSendAggregatedEvent
{
    MSALGlobalConfig.telemetryConfig.piiEnabled = YES;
    // Authority validation event #1
    __auto_type eventName = @"Authority validation event";
    __auto_type event = [[MSIDTelemetryAuthorityValidationEvent alloc] initWithName:eventName context:self.context];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:event];
    // Authority validation event #2
    eventName = @"Authority validation event 2";
    event = [[MSIDTelemetryAuthorityValidationEvent alloc] initWithName:eventName context:self.context];
    [event setProperty:MSID_TELEMETRY_KEY_AUTHORITY_VALIDATION_STATUS value:@"1"];
    [event setProperty:MSID_TELEMETRY_KEY_AUTHORITY_TYPE value:@"2"];
    [event setProperty:MSID_TELEMETRY_KEY_AUTHORITY value:@"3"];
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:event];
    
    [[MSIDTelemetry sharedInstance] flush:self.requestId];
    
    XCTAssertNotNil(self.receivedEvent);
    NSDictionary *eventInfo = self.receivedEvent;
#if TARGET_OS_IPHONE
    XCTAssertEqual(eventInfo.count, 13);
    XCTAssertNotNil(eventInfo[@"msal.x_client_dm"]);
    XCTAssertNotNil(eventInfo[@"msal.application_version"]);
#else
    XCTAssertEqual(eventInfo.count, 12);
#endif
    XCTAssertEqualObjects(eventInfo[@"msal.correlation_id"], @"00000000-0000-0000-0000-000000000001");
    XCTAssertEqualObjects(eventInfo[@"msal.authority_validation_status"], @"1");
    XCTAssertEqualObjects(eventInfo[@"msal.authority_type"], @"2");
    XCTAssertEqualObjects(eventInfo[@"msal.authority"], @"3");
    XCTAssertNotNil(eventInfo[@"msal.request_id"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_cpu"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_os"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_sku"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_ver"]);
    XCTAssertNotNil(eventInfo[@"msal.application_name"]);
    XCTAssertNotNil(eventInfo[@"msal.device_id"]);
}

- (void)testFlush_whenThereIsEventAndObserverRemoved_shouldNotSendEvents
{
    NSString *requestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    NSString *eventName = @"test event";
    MSIDTelemetryBaseEvent *event = [[MSIDTelemetryBaseEvent alloc] initWithName:eventName context:nil];
    [event setProperty:MSID_TELEMETRY_KEY_USER_ID value:@"id1234"];
    [[MSIDTelemetry sharedInstance] startEvent:requestId eventName:eventName];
    [[MSIDTelemetry sharedInstance] stopEvent:requestId event:event];
    MSALGlobalConfig.telemetryConfig.telemetryCallback = nil;
    
    [[MSIDTelemetry sharedInstance] flush:requestId];
    
    XCTAssertNil(self.receivedEvent);
}

- (void)testFlush_whenThereAre2EventsAndObserverIsSetAndSetTelemetryOnFailureYes_shouldFilterEvents
{
    MSALGlobalConfig.telemetryConfig.notifyOnFailureOnly = YES;
    // HTTP event
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:@"httpEvent"];
    MSIDTelemetryHttpEvent *httpEvent = [[MSIDTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:self.context];
    [httpEvent setHttpErrorCode:@"error_code_123"];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:httpEvent];
    
    [[MSIDTelemetry sharedInstance] flush:self.requestId];
    
    NSDictionary *eventInfo = self.receivedEvent;
#if TARGET_OS_IPHONE
    XCTAssertEqual(eventInfo.count, 10);
    XCTAssertNotNil(eventInfo[@"msal.x_client_dm"]);
#else
    XCTAssertEqual(eventInfo.count, 9);
#endif
    XCTAssertEqualObjects(eventInfo[@"msal.correlation_id"], @"00000000-0000-0000-0000-000000000001");
    XCTAssertEqualObjects(eventInfo[@"msal.http_event_count"], @1);
    XCTAssertEqualObjects(eventInfo[@"msal.oauth_error_code"], @"");
    XCTAssertEqualObjects(eventInfo[@"msal.response_code"], @"error_code_123");
    XCTAssertNotNil(eventInfo[@"msal.request_id"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_cpu"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_os"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_sku"]);
    XCTAssertNotNil(eventInfo[@"msal.x_client_ver"]);
}

- (void)testFlush_whenThereIs1NonErrorEventsAndObserverIsSetAndSetTelemetryOnFailureYes_shouldNotSendEvents
{
    MSALGlobalConfig.telemetryConfig.notifyOnFailureOnly = YES;
    // HTTP event
    [[MSIDTelemetry sharedInstance] startEvent:self.requestId eventName:@"httpEvent"];
    MSIDTelemetryHttpEvent *httpEvent = [[MSIDTelemetryHttpEvent alloc] initWithName:@"httpEvent" context:self.context];
    [[MSIDTelemetry sharedInstance] stopEvent:self.requestId event:httpEvent];
    
    [[MSIDTelemetry sharedInstance] flush:self.requestId];
    
    XCTAssertNil(self.receivedEvent);
}

@end
