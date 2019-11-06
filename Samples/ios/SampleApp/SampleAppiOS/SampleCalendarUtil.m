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

#import "SampleCalendarUtil.h"

#import "SampleAppErrors.h"
#import "SampleGraphRequest.h"
#import "SampleMSALUtil.h"

static NSString * const kLastEventsCheck = @"last_events_check";
static NSString * const kEvents = @"events";

@interface SampleEventRequest : SampleGraphRequest

- (void)getEvents:(void (^)(NSArray *events, NSError *error))completionBlock;

@end

static NSDateFormatter *s_df = nil;

@implementation SampleCalendarEvent

+ (void)initialize
{
    s_df = [NSDateFormatter new];
    s_df.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSSSSS";
    s_df.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
}

+ (instancetype)eventWithJson:(NSDictionary *)json
{
    if (!json)
    {
        return nil;
    }
    
    SampleCalendarEvent *event = [SampleCalendarEvent new];
    event.subject = json[@"subject"];
    NSDictionary *startDict = json[@"start"];
    if (!startDict || ![startDict isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }
    
    NSString *startTimeString = startDict[@"dateTime"];
    if (!startTimeString || ![startTimeString isKindOfClass:[NSString class]])
    {
        return nil;
    
    }
    NSDate *start = [s_df dateFromString:startTimeString];
    event.startDate = start;
    return event;
}

@end

@implementation SampleCalendarUtil
{
    NSDictionary<NSDate *, NSArray<SampleCalendarEvent *> *> *_cachedEvents;
}

+ (instancetype)sharedUtil
{
    static SampleCalendarUtil *s_util = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        s_util = [SampleCalendarUtil new];
    });
    
    return s_util;
}

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _cachedEvents = [self processEvents:[[NSUserDefaults standardUserDefaults] objectForKey:kEvents]];
    
    return self;
}

- (BOOL)checkTimestamp
{
    NSDate *lastChecked = [[NSUserDefaults standardUserDefaults] objectForKey:kLastEventsCheck];
    if (!lastChecked)
    {
        return YES;
    }
    
    // Only check for updated events every 30 minutes
    return (-[lastChecked timeIntervalSinceNow] > 30 * 60);
}

- (void)getEventsWithParentController:(UIViewController *)controller
                           completion:(void (^)(NSDictionary<NSDate *, NSArray<SampleCalendarEvent *> *> *events, NSError *error))completionBlock
{
    if (![self checkTimestamp])
    {
        return;
    }
    
    [[SampleMSALUtil sharedUtil] acquireTokenForCurrentAccount:@[@"Calendars.Read"]
                                              parentController:controller
                                               completionBlock:^(NSString *token, NSError *error)
     {
         if (error)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 completionBlock(nil, error);
             });
             return;
         }
         
         [[SampleEventRequest requestWithToken:token] getEvents:^(NSArray *events, NSError *error)
          {
              [self setLastChecked];
              
              NSDictionary<NSDate *, NSArray<SampleCalendarEvent *> *> *processedEvents = [self processEvents:events];
              
              dispatch_async(dispatch_get_main_queue(), ^{
                  if (!error)
                  {
                      [self storeEvents:events];
                      _cachedEvents = processedEvents;
                  }
                  
                  completionBlock(processedEvents, error);
              });
          }];
     }];
}

- (NSDictionary<NSDate *, NSArray<SampleCalendarEvent *> *> *)processEvents:(NSArray *)events
{
    if (!events || ![events isKindOfClass:[NSArray class]])
    {
        return nil;
    }
    
    NSMutableDictionary<NSDate *, NSMutableArray<SampleCalendarEvent *> *> *eventDictionary = [NSMutableDictionary new];
    NSCalendar *calender = [NSCalendar currentCalendar];
    
    for (NSDictionary *jsonEvent in events)
    {
        if (![jsonEvent isKindOfClass:[NSDictionary class]])
        {
            return nil;
        }
        
        SampleCalendarEvent *event = [SampleCalendarEvent eventWithJson:jsonEvent];
        if (!event)
        {
            continue;
        }
        
        if ([event.startDate timeIntervalSinceNow] < 0)
        {
            continue;
        }
        
        NSDate *day = [calender startOfDayForDate:event.startDate];
        NSMutableArray *eventsForDay = eventDictionary[day];
        if (!eventsForDay)
        {
            eventsForDay = [NSMutableArray new];
            eventDictionary[day] = eventsForDay;
        }
        
        [eventsForDay addObject:event];
    }
    
    return eventDictionary;
}

/*
 Returns cached events (if any) for the current user
 */
- (NSDictionary<NSDate *, NSArray<SampleCalendarEvent *> *> *)cachedEvents
{
    return _cachedEvents;
}

/*
 Clears any cached events for the current user
 */
- (void)clearCache
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLastEventsCheck];
    _cachedEvents = nil;
}

- (void)setLastChecked
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kLastEventsCheck];
}

- (void)storeEvents:(NSArray *)cachedEvents
{
    [[NSUserDefaults standardUserDefaults] setObject:cachedEvents forKey:kEvents];
}

@end

@implementation SampleEventRequest

- (void)getEvents:(void (^)(NSArray *events, NSError *error))completionBlock
{
    [super getJSON:@"me/events?$select=subject,start" completionHandler:^(NSDictionary *json, NSError *error)
    {
        if (error)
        {
            completionBlock(nil, error);
            return;
        }
        
        NSArray *events = json[@"value"];
        if (!events || ![events isKindOfClass:[NSArray class]])
        {
            completionBlock(nil, SA_ERROR(SampleAppServerInvalidResponseError, nil));
            return;
        }
        completionBlock(events, nil);
    }];
}

@end
