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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SampleCalendarEvent : NSObject

@property NSDate *startDate;
@property NSString *subject;

@end

@interface SampleCalendarUtil : NSObject

+ (instancetype)sharedUtil;

/*
    Retrieves updated calendar event information from Microsoft graph
 */
- (void)getEventsWithParentController:(UIViewController *)controller
                           completion:(void (^)(NSDictionary<NSDate *, NSArray<SampleCalendarEvent *> *> *events, NSError *error))completionBlock;

/*
    Returns cached calendar events (if any) for the current user
 */
- (NSDictionary<NSDate *, NSArray<SampleCalendarEvent *> *> *)cachedEvents;

/*
    Clears any cached events for the current user
 */
- (void)clearCache;

@end
