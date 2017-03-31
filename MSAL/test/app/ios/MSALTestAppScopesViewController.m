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

#import "MSALTestAppScopesViewController.h"
#import "MSALTestAppSettings.h"

@interface MSALTestAppScopesViewController () <UITableViewDelegate, UITableViewDataSource>
{
    // Data source
    NSArray *_availableScopes;
    MSALTestAppSettings *_settings;
    
    // View
    UITableView *_tableView;

}

@end

@implementation MSALTestAppScopesViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    CGRect screenFrame = UIScreen.mainScreen.bounds;
    _tableView = [[UITableView alloc] initWithFrame:screenFrame];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.allowsSelection = YES;
    self.view = _tableView;
    
    _settings = [MSALTestAppSettings settings];
    
    self.navigationItem.title = @"Select Scopes";
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


+ (instancetype)sharedController
{
    static MSALTestAppScopesViewController *s_controller = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        s_controller = [[MSALTestAppScopesViewController alloc] init];
    });
    
    return s_controller;
}

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _availableScopes = [MSALTestAppSettings availableScopes];

    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    (void)animated;
    self.navigationController.navigationBarHidden = NO;
    [super viewWillAppear:animated];
}

#pragma mark -
#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    NSString *scope = _availableScopes[indexPath.row];
    
    if ([settings.scopes containsObject:scope])
    {
        [settings removeScope:scope];
    }
    else
    {
        [settings addScope:scope];
    }
    
    [tableView reloadData];
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    (void)tableView;
    (void)section;
    
    return _availableScopes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MSALTestAppTableSettingRowCell"];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"MSALTestAppTableSettingRowCell"];
        
    }
    
    NSString *scope = _availableScopes[indexPath.row];
    if ([[_settings scopes] containsObject:scope])
    {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    else
    {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    cell.textLabel.text = scope;
    
    return cell;
}


@end
