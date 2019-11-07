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

#import <MSAL/MSAL.h>

#import "SampleMainViewController.h"

#import "SampleAppDelegate.h"
#import "SampleAppErrors.h"
#import "SampleCalendarUtil.h"
#import "SampleLoginViewController.h"
#import "SampleMSALUtil.h"
#import "SamplePhotoUtil.h"

@interface SampleMainViewController () <UITableViewDataSource>

@end

@implementation SampleMainViewController\
{
    NSDictionary<NSDate *, NSArray<SampleCalendarEvent *> *> *_events;
    NSArray<NSDate *> *_keys;
    
    NSDateFormatter *_dayFormatter;
    NSDateFormatter *_timeFormatter;
}

+ (instancetype)sharedViewController
{
    static SampleMainViewController *s_controller = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        s_controller = [[SampleMainViewController alloc] initWithNibName:@"SampleMainView" bundle:nil];
    });
    
    return s_controller;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        return nil;
    }
    
    _dayFormatter = [[NSDateFormatter alloc] init];
    _dayFormatter.dateStyle = NSDateFormatterFullStyle;
    _dayFormatter.timeStyle = NSDateFormatterNoStyle;
    
    _timeFormatter = [[NSDateFormatter alloc] init];
    _timeFormatter.dateStyle = NSDateFormatterNoStyle;
    _timeFormatter.timeStyle = NSDateFormatterShortStyle;
    
    return self;
}

- (void)setUserPhoto:(UIImage *)photo
{
    _profileImageView.image = photo;
    _profileImageView.layer.cornerRadius = _profileImageView.frame.size.width / 2;
    _profileImageView.layer.borderWidth = 4.0f;
    _profileImageView.layer.borderColor = UIColor.whiteColor.CGColor;
    _profileImageView.clipsToBounds = YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _tableView.dataSource = self;
}

- (void)viewWillAppear:(BOOL)animated
{
    // Set the photo first to "no_photo" so we have something there if we have
    // to wait for network lag
    [self loadPhoto];
    [self loadEvents];
    
    _nameLabel.text = [NSString stringWithFormat:@"Welcome, %@", [[SampleMSALUtil sharedUtil] currentAccount:nil].username];
}

- (void)loadPhoto
{
    SamplePhotoUtil *util = [SamplePhotoUtil sharedUtil];
    [self setUserPhoto:[util cachedPhoto]];
    [util checkUpdatePhotoWithParentController:self
                                    completion:^(UIImage *photo, NSError *error)
     {
         if (error)
         {
             [self showDialogForError:error];
             return;
         }
         
         [self setUserPhoto:photo];
     }];
}

- (void)loadEvents
{
    SampleCalendarUtil *util = [SampleCalendarUtil sharedUtil];
    _events = [util cachedEvents];
    [self updateKeys];
    
    [_tableView reloadData];
    [util getEventsWithParentController:self
                             completion:^(NSDictionary<NSDate *, NSArray<SampleCalendarEvent *> *> *events, NSError *error) {
        if (error)
        {
            return;
        }
        
        _events = events;
        [self updateKeys];
        
        [_tableView reloadData];
    }];
}

- (void)updateKeys
{
    _keys = [[_events allKeys] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
}

- (IBAction)signOut:(id)sender
{
    [[SampleMSALUtil sharedUtil] signOut];
    [SampleAppDelegate setCurrentViewController:[SampleLoginViewController sharedViewController]];
}

- (float)startY
{
    return 1.0f;
}

#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _keys.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _events[_keys[section]].count;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [_dayFormatter stringFromDate:_keys[section]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"eventCell"];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"eventCell"];
    }
    
    NSDate *section = _keys[[indexPath indexAtPosition:0]];
    SampleCalendarEvent *event = _events[section][[indexPath indexAtPosition:1]];
    
    cell.textLabel.text = event.subject;
    cell.detailTextLabel.text = [_timeFormatter stringFromDate:event.startDate];
    return cell;
}

@end
