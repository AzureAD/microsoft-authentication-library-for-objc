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

#import "MSALTelemetryBaseEvent.h"
#import "NSString+MSALHelperMethods.h"
#import "MSALTelemetryEventStrings.h"
#import "NSMutableDictionary+MSALExtension.h"

@interface MSALTelemtryBaseEvent ()
{
    NSMutableDictionary *_propertyMap;
}
@end

@implementation MSALTelemtryBaseEvent

@synthesize propertyMap = _propertyMap;
@synthesize errorInEvent = _errorInEvent;

- (id)initWithName:(NSString *)eventName
           context:(id<MSALRequestContext>)context
{
    (void)context;
    
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _errorInEvent = NO;
    _propertyMap = [NSMutableDictionary dictionary];
    
    [_propertyMap msalSetObjectIfNotNil:eventName forKey:MSAL_TELEMETRY_KEY_EVENT_NAME];
    
    return self;
}

#pragma mark -
#pragma mark MSALTelemetryEventInterface methods

- (void)setProperty:(NSString *)name value:(NSString *)value
{
    // value can be empty but not nil
    if ([NSString msalIsStringNilOrBlank:name] || !value)
    {
        return;
    }
    
    [_propertyMap setValue:value forKey:name];
}

- (NSDictionary *)getProperties
{
    return _propertyMap;
}

- (void)setStartTime:(NSDate *)time
{
    if (!time)
    {
        return;
    }
    
    [_propertyMap setValue:[self getStringFromDate:time] forKey:MSAL_TELEMETRY_KEY_START_TIME];
}

- (void)setStopTime:(NSDate *)time
{
    if (!time)
    {
        return;
    }
    
    [_propertyMap setValue:[self getStringFromDate:time] forKey:MSAL_TELEMETRY_KEY_END_TIME];
}

- (NSString *)getStringFromDate:(NSDate *)date
{
    static NSDateFormatter *s_dateFormatter = nil;
    static dispatch_once_t s_dateOnce;
    
    dispatch_once(&s_dateOnce, ^{
        s_dateFormatter = [[NSDateFormatter alloc] init];
        [s_dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
        [s_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSSS"];
    });
    
    return [s_dateFormatter stringFromDate:date];
}

- (void)setResponseTime:(NSTimeInterval)responseTime
{
    //the property is set in milliseconds
    [_propertyMap setValue:[NSString stringWithFormat:@"%f", responseTime * 1000] forKey:MSAL_TELEMETRY_KEY_ELAPSED_TIME];
}

@end
