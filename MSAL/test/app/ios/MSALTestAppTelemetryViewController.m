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

#import "MSALTestAppTelemetryViewController.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSALTelemetry.h"
#import <MSAL/MSALGlobalConfig.h>
#import <MSAL/MSALTelemetryConfig.h>

@interface MSALTestAppTelemetryViewController ()
{
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *_telemetryEvents;
    NSInteger _expandedRowIndex;
}

@end

@implementation MSALTestAppTelemetryViewController

#pragma mark -
#pragma mark - Init

+ (instancetype)sharedController
{
    static MSALTestAppTelemetryViewController *s_controller = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        s_controller = [[MSALTestAppTelemetryViewController alloc] init];
    });
    
    return s_controller;
}

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _telemetryEvents = [NSMutableArray array];
    _expandedRowIndex = -1;
    
    return self;
}

#pragma mark - Tracking

- (void)startTracking
{
    MSALGlobalConfig.telemetryConfig.telemetryCallback = ^(NSDictionary<NSString *, NSString *> *event)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_telemetryEvents addObject:event];
            [self refresh];
        });
    };
}

- (void)stopTracking
{
    MSALGlobalConfig.telemetryConfig.telemetryCallback = nil;
}

#pragma mark - UI Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIBarButtonItem *clearTelemetryItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStyleDone target:self action:@selector(clearTelemetry:)];
    self.navigationItem.rightBarButtonItem = clearTelemetryItem;
    
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 140;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBarHidden = NO;
}

#pragma mark - Methods for subclasses to override

- (void)refresh
{
    self.navigationItem.title = [NSString stringWithFormat:@"%ld events", (unsigned long)[_telemetryEvents count]];
    [_tableView reloadData];
}

- (NSInteger)numberOfRows
{
    return [_telemetryEvents count];
}

- (NSString *)labelForRow:(NSInteger)row
{
    NSDictionary *event = _telemetryEvents[row];
    
    if (row == _expandedRowIndex)
    {
        return [self eventAsString:event];
    }
    else
    {
        return [self eventAsShortString:event];
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    
    if (indexPath.row == _expandedRowIndex)
    {
        _expandedRowIndex = -1;
    }
    else
    {
        _expandedRowIndex = indexPath.row;
    }
    
    [self refresh];
}

#pragma mark - Actions

- (IBAction)clearTelemetry:(id)sender
{
    (void)sender;
    
    _telemetryEvents = [NSMutableArray array];
    [self refresh];
}

#pragma mark - Helpers

- (NSString *)eventAsShortString:(NSDictionary *)telemetryEvent
{
    NSString *eventName = telemetryEvent[TELEMETRY_KEY(MSID_TELEMETRY_KEY_EVENT_NAME)];
    NSString *startTime = telemetryEvent[TELEMETRY_KEY(MSID_TELEMETRY_KEY_START_TIME)];
    
    return [NSString stringWithFormat:@"[%@]\n%@", startTime ? startTime : @"N/A", eventName];
}

- (NSString *)eventAsString:(NSDictionary *)telemetryEvent
{
    NSString *eventLog = @"----------------------\n";
    
    for (NSString *key in [telemetryEvent allKeys])
    {
        eventLog = [eventLog stringByAppendingFormat:@"\t%@ :: %@\n", key, telemetryEvent[key]];
    }
    
    eventLog = [eventLog stringByAppendingString:@"----------------------"];
    
    return eventLog;
}

@end
