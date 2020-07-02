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
#import "MSIDKeychainUtil.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSALPublicClientApplicationConfig.h"
#import "MSALCacheConfig.h"

static NSArray* s_profileRows = nil;
static NSArray* s_deviceRows = nil;

NSString *const MSID_DEVICE_INFORMATION_UPN_ID_KEY        = @"userPrincipalName";
NSString *const MSID_DEVICE_INFORMATION_AAD_DEVICE_ID_KEY = @"aadDeviceIdentifier";
NSString *const MSID_DEVICE_INFORMATION_AAD_TENANT_ID_KEY = @"aadTenantIdentifier";

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
    
    MSALTestAppSettingsRow *clientIdRow = [MSALTestAppSettingsRow rowWithTitle:MSAL_APP_CLIENT_ID];
    NSDictionary *currentProfile = [MSALTestAppSettings currentProfile];
    NSString *clientId = [currentProfile objectForKey:MSAL_APP_CLIENT_ID];
    clientIdRow.valueBlock = ^NSString *{ return clientId; };
    MSALTestAppSettingsRow* redirectUriRow = [MSALTestAppSettingsRow rowWithTitle:MSAL_APP_REDIRECT_URI];
    NSString *redirectUri = [currentProfile objectForKey:MSAL_APP_REDIRECT_URI];
    redirectUriRow.valueBlock = ^NSString *{ return redirectUri; };
    
    MSALPublicClientApplicationConfig *pcaConfig = [[MSALPublicClientApplicationConfig alloc] initWithClientId:clientId
                                                                                                   redirectUri:redirectUri
                                                                                                     authority:nil];
    
    NSString *accessGroup = pcaConfig.cacheConfig.keychainSharingGroup;
    NSString *keychainGroup = [[MSIDKeychainUtil sharedInstance] accessGroup:accessGroup];
    NSString *keychainSharingGroup = keychainGroup? keychainGroup : @"<No Keychain Group Found>";
    
    MSALTestAppSettingsRow* keychainGroupRow = [MSALTestAppSettingsRow rowWithTitle:MSAL_APP_KEYCHAIN_GROUP];
    keychainGroupRow.valueBlock = ^NSString *{ return keychainSharingGroup; };
    
    _profileRows = @[ clientIdRow, redirectUriRow, keychainGroupRow];

    NSString *userPrincipalName = @"<No User Info Found>";
    NSString *aadDeviceIdentifier = @"<No Device Info Group Found>";
    NSString *tenantIdentifier = @"<No Tenant Info Group Found>";
    
    NSDictionary *regInfo = [MSIDWorkPlaceJoinUtil getRegisteredDeviceMetadataInformation:nil];

    if ([regInfo count])
    {
        userPrincipalName = [regInfo objectForKey:MSID_DEVICE_INFORMATION_UPN_ID_KEY];
        aadDeviceIdentifier = [regInfo objectForKey:MSID_DEVICE_INFORMATION_AAD_DEVICE_ID_KEY];
        tenantIdentifier = [regInfo objectForKey:MSID_DEVICE_INFORMATION_AAD_TENANT_ID_KEY];
    }
    
    _deviceRows = @[ [MSALTestAppSettingsRow rowWithTitle:@"Device_Info - User UPN"
                                                    value:^NSString *{ return userPrincipalName; }],
                     [MSALTestAppSettingsRow rowWithTitle:@"Device_Info - Device Id" value:^NSString *{ return aadDeviceIdentifier; }],
                     [MSALTestAppSettingsRow rowWithTitle:@"Device_Info - Tenant Id" value:^NSString *{ return tenantIdentifier; }]];
    
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
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
