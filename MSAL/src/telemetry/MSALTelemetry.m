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

#import "MSALTelemetry.h"
#import "MSALTelemetry+Internal.h"
#import "MSALTelemetryEventInterface.h"
#import "MSALTelemetryEventStrings.h"
#import "MSALDefaultDispatcher.h"
#import "NSString+MSALHelperMethods.h"
#import "MSALTelemetryDefaultEvent.h"

static NSString* const s_delimiter = @"|";
static MSALTelemetryDefaultEvent *s_defaultEvent;

@interface MSALTelemetry()
{
    NSMutableArray<MSALDefaultDispatcher *> *_dispatchers;
    NSMutableDictionary *_eventTracking;
    NSMutableDictionary *_events;
    NSMutableArray *_errorEvents;
}

@end

@implementation MSALTelemetry

- (id)initInternal
{
    self = [super init];
    if (self)
    {
        _eventTracking = [NSMutableDictionary new];
        _dispatchers = [NSMutableArray new];
        _events = [NSMutableDictionary new];
        _errorEvents = [NSMutableArray new];
    }
    return self;
}

+ (MSALTelemetry *)sharedInstance
{
    static dispatch_once_t once;
    static MSALTelemetry* singleton = nil;
    
    dispatch_once(&once, ^{
        singleton = [[MSALTelemetry alloc] initInternal];
        s_defaultEvent = [[MSALTelemetryDefaultEvent alloc] initWithName:MSAL_TELEMETRY_EVENT_DEFAULT_EVENT context:nil];
    });
    
    return singleton;
}

- (void)addDispatcher:(nonnull id<MSALDispatcher>)dispatcher
setTelemetryOnFailure:(BOOL)setTelemetryOnFailure
{
    @synchronized(self)
    {
        [_dispatchers addObject:[[MSALDefaultDispatcher alloc] initWithDispatcher:dispatcher
                                                            setTelemetryOnFailure:setTelemetryOnFailure]];
    }
}

- (void)removeDispatcher:(nonnull id<MSALDispatcher>)dispatcher
{
    @synchronized(self)
    {
        for(MSALDefaultDispatcher *msalDispatcher in _dispatchers)
        {
            if ([msalDispatcher containsDispatcher:dispatcher])
            {
                [_dispatchers removeObject:msalDispatcher];
            }
        }
    }
}

- (void)removeAllDispatchers
{
    @synchronized(self)
    {
        [_dispatchers removeAllObjects];
    }
}

@end

@implementation MSALTelemetry (Internal)

- (NSString *)telemetryRequestId
{
    return [[NSUUID UUID] UUIDString];
}

- (void)startEvent:(NSString *)requestId
         eventName:(NSString *)eventName
{
    if ([NSString msalIsStringNilOrBlank:requestId] || [NSString msalIsStringNilOrBlank:eventName])
    {
        return;
    }
    
    NSDate *currentTime = [NSDate date];
    @synchronized(self)
    {
        [_eventTracking setObject:currentTime
                           forKey:[self getEventTrackingKey:requestId eventName:eventName]];
    }
}

- (void)stopEvent:(NSString *)requestId
            event:(id<MSALTelemetryEventInterface>)event
{
    NSDate *stopTime = [NSDate date];
    NSString *eventName = [self getPropertyFromEvent:event propertyName:MSAL_TELEMETRY_KEY_EVENT_NAME];
    
    if ([NSString msalIsStringNilOrBlank:requestId] || [NSString msalIsStringNilOrBlank:eventName] || !event)
    {
        return;
    }
    
    NSString *key = [self getEventTrackingKey:requestId eventName:eventName];
    
    NSDate *startTime = nil;
    
    @synchronized(self)
    {
        startTime = [_eventTracking objectForKey:key];
        if (!startTime)
        {
            return;
        }
    }
    
    [event setStartTime:startTime];
    [event setStopTime:stopTime];
    [event setResponseTime:[stopTime timeIntervalSinceDate:startTime]];
    
    @synchronized(self)
    {
        NSMutableArray *eventCollection = [_events objectForKey:requestId];
        
        if (!eventCollection)
        {
            eventCollection = [NSMutableArray array];
        }
        
        [eventCollection addObject:[event getProperties]];
        [_events setObject:eventCollection forKey:requestId];
        
        if ([event errorInEvent] && ![_errorEvents containsObject:requestId])
        {
            [_errorEvents addObject:requestId];
        }
        
        [_eventTracking removeObjectForKey:key];
    }
}

- (void)dispatchEventNow:(NSString *)requestId
                   event:(id<MSALTelemetryEventInterface>)event
{
    @synchronized(self)
    {
        for (MSALDefaultDispatcher *dispatcher in _dispatchers)
        {
            [dispatcher receive:requestId event:event];
        }
    }
}

- (NSString *)getEventTrackingKey:(NSString *)requestId
                       eventName:(NSString *)eventName
{
    return [NSString stringWithFormat:@"%@%@%@", requestId, s_delimiter, eventName];
}

- (NSString *)getPropertyFromEvent:(id<MSALTelemetryEventInterface>)event
                     propertyName:(NSString *)propertyName
{
    NSDictionary *properties = [event getProperties];
    return [properties objectForKey:propertyName];
}

- (void)flush:(NSString *)requestId
{
    @synchronized(self)
    {
        NSArray *events = [_events objectForKey:requestId];
        BOOL errorInEvent = [_errorEvents containsObject:requestId];
        
        if ([events count])
        {
            events = [@[[s_defaultEvent getProperties]] arrayByAddingObjectsFromArray:events];
        }
        
        for (MSALDefaultDispatcher *dispatcher in _dispatchers)
        {
            [dispatcher flush:events errorInEvent:errorInEvent];
        }
        
        [_events removeObjectForKey:requestId];
        [_errorEvents removeObject:requestId];
    }
}

@end

