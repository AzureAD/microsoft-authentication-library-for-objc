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

#import "MSALTestAppSettingsViewController.h"
#import "MSALTestAppSettings.h"
#import "MSIDAuthority.h"
#import "MSALAuthority.h"
#import "MSALAuthority_Internal.h"

static NSArray* s_profileRows = nil;
static NSArray* s_deviceRows = nil;

@interface MSALTestAppSettingsRow : NSObject

@property (nonatomic, retain) NSString* title;
@property (nonatomic, copy) NSString*(^valueBlock)(void);
@property (nonatomic, copy) void(^action)(void);

+ (MSALTestAppSettingsRow*)rowWithTitle:(NSString *)title;

@end

@implementation MSALTestAppSettingsRow

+ (MSALTestAppSettingsRow*)rowWithTitle:(NSString *)title
{
    MSALTestAppSettingsRow* row = [MSALTestAppSettingsRow new];
    row.title = title;
    return row;
}

+ (MSALTestAppSettingsRow*)rowWithTitle:(NSString *)title
                                value:(NSString*(^)(void))value
{
    MSALTestAppSettingsRow* row = [MSALTestAppSettingsRow new];
    row.title = title;
    row.valueBlock = value;
    return row;
}

@end

@interface MSALTestAppSettingsViewController () <UITableViewDelegate, UITableViewDataSource>

@end

@implementation MSALTestAppSettingsViewController
{
    UITableView* _tableView;
    
    NSArray* _profileRows;
    NSArray* _deviceRows;
    
    NSString* _keychainId;
    NSString* _wpjState;
}

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Settings"
                                                    image:[UIImage imageNamed:@"Settings"]
                                                      tag:0];
    
    // TODO: Keychain ID
    /*
    NSString* teamId = [ADKeychainUtil keychainTeamId:nil];
    _keychainId = teamId ? teamId : @"<No Team ID>";*/
    
    MSALTestAppSettingsRow* clientIdRow = [MSALTestAppSettingsRow rowWithTitle:@"clientId"];
    NSDictionary *currentProfile = [MSALTestAppSettings currentProfile];
    NSString *clientId = [currentProfile objectForKey:MSAL_APP_CLIENT_ID];
    clientIdRow.valueBlock = ^NSString *{ return clientId; };
    MSALTestAppSettingsRow* authorityRow = [MSALTestAppSettingsRow rowWithTitle:@"authority"];
    authorityRow.valueBlock = ^NSString *{ return MSALTestAppSettings.settings.authority.msidAuthority.url.absoluteString; };
    
    _profileRows = @[ authorityRow, clientIdRow ];
    
    
    
    _deviceRows = @[ [MSALTestAppSettingsRow rowWithTitle:@"TeamID" value:^NSString *{ return _keychainId; }],
                     [MSALTestAppSettingsRow rowWithTitle:@"WPJ State" value:^NSString *{ return _wpjState; }]];
    
    return self;
}

- (void)loadView
{
    CGRect screenFrame = UIScreen.mainScreen.bounds;
    _tableView = [[UITableView alloc] initWithFrame:screenFrame];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.allowsSelection = YES;
    
    self.view = _tableView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}



- (void)viewWillAppear:(BOOL)animated
{
    (void)animated;
    
    // TODO: WPJ state
    /*
    ADRegistrationInformation* regInfo =
    [ADWorkPlaceJoinUtil getRegistrationInformation:nil error:nil];
    
    NSString* wpjLabel = @"No WPJ Registration Found";
    
    if (regInfo.userPrincipalName)
    {
        wpjLabel = regInfo.userPrincipalName;
    }
    else if (regInfo)
    {
        wpjLabel = @"WPJ Registration Found";
    }
    
    _wpjState = wpjLabel;
     */
    
    self.navigationController.navigationBarHidden = YES;
    
    [_tableView reloadData];
    [super viewWillAppear:animated];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    (void)tableView;
    if (section == 0)
        return _profileRows.count;
    if (section == 1)
        return _deviceRows.count;
    
    return 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
{
    (void)tableView;
    return 2;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    (void)tableView;
    if (section == 0)
        return @"Authentication Settings";
    if (section == 1)
        return @"Device State";
    
    return nil;
}


- (MSALTestAppSettingsRow*)rowForIndexPath:(NSIndexPath *)indexPath
{
    NSInteger section = [indexPath indexAtPosition:0];
    NSInteger row = [indexPath indexAtPosition:1];
    
    if (section == 0)
    {
        return _profileRows[row];
    }
    
    if (section == 1)
    {
        return _deviceRows[row];
    }
    
    return nil;
}

- (nullable NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    MSALTestAppSettingsRow* row = [self rowForIndexPath:indexPath];
    if (!row.action)
        return nil;
    
    row.action();
    return nil;
}

// Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
// Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"settingsCell"];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"settingsCell"];
    }
    
    MSALTestAppSettingsRow* row = [self rowForIndexPath:indexPath];
    cell.textLabel.text = row.title;
    cell.detailTextLabel.text = row.valueBlock();
    
    if (row.action)
    {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    MSALTestAppSettingsRow* row = [self rowForIndexPath:indexPath];
    if (row.action)
    {
        row.action();
    }
}



@end
