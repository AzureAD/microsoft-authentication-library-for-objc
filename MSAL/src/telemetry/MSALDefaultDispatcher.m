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
#import "MSIDTelemetryEventInterface.h"
#import "MSALDefaultDispatcher.h"
#import "MSIDTelemetryEventInterface.h"
#import "MSIDTelemetryBaseEvent.h"
#import "MSALTelemetryDefaultEvent.h"
#import "MSIDTelemetryEventStrings.h"

@interface MSALDefaultDispatcher ()
{
    NSMutableDictionary* _objectsToBeDispatched;
    id<MSALTelemetryDispatcher> _dispatcher;
    NSLock* _dispatchLock;
    BOOL _setTelemetryOnFailure;
    NSMutableArray *_errorEvents;
    
    MSALTelemetryDefaultEvent *_defaultEvent;
}
@end

@implementation MSALDefaultDispatcher

- (id)initWithDispatcher:(id<MSALTelemetryDispatcher>)dispatcher setTelemetryOnFailure:(BOOL)setTelemetryOnFailure
{
    self = [super init];
    if (self)
    {
        _objectsToBeDispatched = [NSMutableDictionary new];
        _errorEvents = [NSMutableArray new];
        _dispatchLock = [NSLock new];
        
        _dispatcher = dispatcher;
        _setTelemetryOnFailure = setTelemetryOnFailure;
        
        _defaultEvent = [[MSALTelemetryDefaultEvent alloc] initWithName:MSID_TELEMETRY_EVENT_DEFAULT_EVENT context:nil];
    }
    return self;
}

- (BOOL)containsDispatcher:(id<MSALTelemetryDispatcher>)dispatcher
{
    return _dispatcher == dispatcher;
}

- (void)flush:(NSString *)requestId
{
    BOOL errorInEvent = [_errorEvents containsObject:requestId];
    
    [_dispatchLock lock];
    // Remove requestId as we won't need it anymore
    [_errorEvents removeObject:requestId];
    [_dispatchLock unlock];
    
    if (_setTelemetryOnFailure && !errorInEvent)
    {
        return;
    }
    
    [_dispatchLock lock]; //avoid access conflict when manipulating _objectsToBeDispatched
    NSArray* events = [_objectsToBeDispatched objectForKey:requestId];
    [_objectsToBeDispatched removeObjectForKey:requestId];
    [_dispatchLock unlock];
    
    if ([events count])
    {
        NSArray* eventsToBeDispatched = @[[_defaultEvent getProperties]];
        [self dispatchEvents:[eventsToBeDispatched arrayByAddingObjectsFromArray:events]];
    }
}

- (void)receive:(__unused NSString *)requestId
          event:(id<MSIDTelemetryEventInterface>)event
{
    if ([NSString msidIsStringNilOrBlank:requestId] || !event)
    {
        return;
        
    }
    
    [_dispatchLock lock]; //make sure no one changes _objectsToBeDispatched while using it
    NSMutableArray* eventsForRequestId = [_objectsToBeDispatched objectForKey:requestId];
    if (!eventsForRequestId)
    {
        eventsForRequestId = [NSMutableArray new];
        [_objectsToBeDispatched setObject:eventsForRequestId forKey:requestId];
    }
    
    [eventsForRequestId addObject:[event getProperties]];
    
    if ([event errorInEvent])
    {
        [_errorEvents addObject:requestId];
    }
    
    [_dispatchLock unlock];
}

- (void)dispatchEvents:(NSArray<NSDictionary<NSString *, NSString *> *> *)rawEvents;
{
    NSMutableArray *eventsToBeDispatched = [NSMutableArray new];
    
    for (NSDictionary *event in rawEvents)
    {
        [eventsToBeDispatched addObject:[self appendPrefixForEvent:event]];
    }
    
    [_dispatcher dispatchEvent:eventsToBeDispatched];
}

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
