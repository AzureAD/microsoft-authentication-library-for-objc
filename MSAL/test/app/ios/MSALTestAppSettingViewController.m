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

#import "MSALTestAppSettingViewController.h"

@interface MSALTestAppSettingViewController () <UITableViewDelegate, UITableViewDataSource>

@end

@implementation MSALTestAppSettingViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.hidesBackButton = NO;
    
    CGRect screenFrame = UIScreen.mainScreen.bounds;
    _tableView = [[UITableView alloc] initWithFrame:screenFrame];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.allowsSelection = YES;
    
    self.view = _tableView;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    (void)animated;
    self.navigationController.navigationBarHidden = NO;

    [self refresh];
    [super viewWillAppear:animated];
}

#pragma mark -
#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    [self rowSelected:[indexPath indexAtPosition:1]];
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    (void)section;
    (void)tableView;
    return [self numberOfRows];
}

// Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
// Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MSALTestAppTableSettingRowCell"];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"MSALTestAppTableSettingRowCell"];
        
        cell.textLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        cell.textLabel.numberOfLines = 0;
    }
    
    cell.textLabel.text = [self labelForRow:[indexPath indexAtPosition:1]];
    cell.detailTextLabel.text = [self subLabelForRow:[indexPath indexAtPosition:1]];
    
    return cell;
}


#pragma mark -
#pragma mark Methods for subclasses to override

- (void)refresh
{
    [_tableView reloadData];

    NSInteger currentRow = [self currentRow];

    if (currentRow != -1)
    {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[self currentRow] inSection:0];
        [_tableView selectRowAtIndexPath:indexPath
                                animated:NO
                          scrollPosition:UITableViewScrollPositionNone];
    }
}

- (NSInteger)numberOfRows
{
    return 0;
}

- (NSString *)labelForRow:(NSInteger)row
{
    (void)row;
    return nil;
}

- (NSString *)subLabelForRow:(NSInteger)row
{
    (void)row;
    return nil;
}

- (void)rowSelected:(NSInteger)row
{
    (void)row;
}

- (NSInteger)currentRow
{
    return 0;
}

+ (NSString *)currentTitle
{
    return nil;
}

@end
