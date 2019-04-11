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

#import "MSALDefaultDispatcher+Internal.h"
#import "MSALTelemetry.h"
#import "MSIDTelemetryEventInterface.h"
#import "MSIDTelemetryEventInterface.h"
#import "MSIDTelemetryBaseEvent.h"
#import "MSALTelemetryDefaultEvent.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSALTelemetryEventsObserving.h"

@implementation MSALDefaultDispatcher

- (id)initWithObserver:(id<MSALTelemetryEventsObserving>)observer setTelemetryOnFailure:(BOOL)setTelemetryOnFailure
{
    self = [super init];
    if (self)
    {
        _eventsToBeDispatched = [NSMutableDictionary new];
        _errorEvents = [NSMutableSet new];
        _observer = observer;
        _setTelemetryOnFailure = setTelemetryOnFailure;
        NSString *queueName = [NSString stringWithFormat:@"com.microsoft.dispatcher-%@", [NSUUID UUID].UUIDString];
        _synchronizationQueue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)containsObserver:(id<MSALTelemetryEventsObserving>)dispatcher
{
    return self.observer == dispatcher;
}

- (void)flush:(NSString *)requestId
{
    NSArray<id<MSIDTelemetryEventInterface>> *events = [self popEventsForReuquestId:requestId];
    
    if ([events count])
    {
        __auto_type defaultEvent = [[MSALTelemetryDefaultEvent alloc] initWithName:MSID_TELEMETRY_EVENT_DEFAULT_EVENT context:nil];
        NSMutableArray *eventsToBeDispatched = [@[[defaultEvent getProperties]] mutableCopy];
        
        for (id<MSIDTelemetryEventInterface> event in events)
        {
            [eventsToBeDispatched addObject:[event getProperties]];
        }
        
        [self dispatchEvents:eventsToBeDispatched];
    }
}

- (void)receive:(NSString *)requestId
          event:(id<MSIDTelemetryEventInterface>)event
{
    if ([NSString msidIsStringNilOrBlank:requestId] || !event) return;
    
    dispatch_sync(self.synchronizationQueue, ^{
        NSMutableArray *eventsForRequestId = self.eventsToBeDispatched[requestId];
        if (!eventsForRequestId)
        {
            eventsForRequestId = [NSMutableArray new];
            [self.eventsToBeDispatched setObject:eventsForRequestId forKey:requestId];
        }
        
        [eventsForRequestId addObject:event];
        
        if (event.errorInEvent) [self.errorEvents addObject:requestId];
    });
}

- (void)dispatchEvents:(NSArray<NSDictionary<NSString *, NSString *> *> *)rawEvents
{
    NSMutableArray *eventsToBeDispatched = [NSMutableArray new];
    
    for (NSDictionary *event in rawEvents)
    {
        [eventsToBeDispatched addObject:[self appendPrefixForEvent:event]];
    }
    
    [self.observer onEventsReceived:eventsToBeDispatched];
}

#pragma mark - Protected

- (NSArray *)popEventsForReuquestId:(NSString *)requestId
{
    __block NSArray *events;
    dispatch_sync(self.synchronizationQueue, ^{
        BOOL errorInEvent = [self.errorEvents containsObject:requestId];
        
        // Remove requestId as we won't need it anymore
        [self.errorEvents removeObject:requestId];
        
        if (self.setTelemetryOnFailure && !errorInEvent) return;
        
        events = [self.eventsToBeDispatched[requestId] copy];
        [self.eventsToBeDispatched removeObjectForKey:requestId];
    });
    
    return events;
}

#pragma mark - Private

- (NSDictionary *)appendPrefixForEvent:(NSDictionary *)event
{
    NSMutableDictionary *eventWithPrefix = [NSMutableDictionary new];
    
    for (NSString *propertyName in [event allKeys])
    {
        [eventWithPrefix setValue:event[propertyName] forKey:TELEMETRY_KEY(propertyName)];
    }
    
    return eventWithPrefix;
}

@end
