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

#import "MSALTestAppAuthorityViewController.h"
#import "MSALTestAppSettings.h"
#import "MSALAuthority.h"
#import "MSIDAuthority.h"
#import "MSALAuthority_Internal.h"

@interface MSALTestAppAuthorityViewController ()

@end

@implementation MSALTestAppAuthorityViewController
{
    NSString *_userDefaultsKey;
}

+ (instancetype)sharedController
{
    static MSALTestAppAuthorityViewController *s_controller = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        s_controller = [[MSALTestAppAuthorityViewController alloc] init];
    });
    
    return s_controller;
}

- (instancetype)init
{
    return [self initWithAuthorities:[MSALTestAppSettings aadAuthorities]
              keyForSavedAuthorities:@"saved_aadAuthorities"];
}

- (instancetype)initWithAuthorities:(NSArray<NSString *> *)aadAuthorities
              keyForSavedAuthorities:(NSString *)key
{
    self = [super init];
    if(self)
    {
        _authorities = [aadAuthorities mutableCopy];
        _userDefaultsKey = key;
        _savedAuthorities = [[NSUserDefaults standardUserDefaults] objectForKey:key];
        if (!_savedAuthorities)
        {
            _savedAuthorities = [NSMutableArray array];
        }
        
        for(NSString* authority in _savedAuthorities)
        {
            if (![_authorities containsObject:authority])
            {
                [_authorities addObject:authority];
            }
        }
    }
    return self;
}

#pragma mark -
#pragma mark Methods for subclasses to override

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    (void)tableView;
    [self rowSelected:[indexPath indexAtPosition:1]];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)viewDidLoad
{
    self.navigationItem.title = @"Select Authority";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addAuthority:)];
    [super viewDidLoad];
}

- (void)addAuthority:(id)sender
{
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Add authority" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [controller addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Authority";
    }];
    
    [controller addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [controller addAction:[UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *authority = controller.textFields[0].text;
        [self saveAuthority:authority];
    }]];
    
    [self presentViewController:controller animated:YES completion:nil];
    
}

- (void)saveAuthority:(NSString *)authority
{
    if (![_authorities containsObject:authority])
    {
        [_authorities addObject:authority];
    }
    
    if (![_savedAuthorities containsObject:authority])
    {
        [_savedAuthorities addObject:authority];
    }

    [[NSUserDefaults standardUserDefaults] setObject:_savedAuthorities forKey:_userDefaultsKey];
    
    [self refresh];
}

- (NSInteger)numberOfRows
{
    return _authorities.count + 1;
}

- (NSString *)labelForRow:(NSInteger)row
{
    if (row == 0)
    {
        return @"(default)";
    }
    
    return _authorities[row - 1];
}

- (void)rowSelected:(NSInteger)row
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    if (row == 0)
    {
        settings.authority = nil;
    }
    else
    {
        NSURL *authorityURL = [NSURL URLWithString:_authorities[row - 1]];
        MSALAuthority *authority = [MSALAuthority authorityWithURL:authorityURL error:nil];
        settings.authority = authority;
    }
}

- (NSInteger)currentRow
{
    __auto_type currentAuthority = MSALTestAppSettings.settings.authority;
    if (currentAuthority == nil)
    {
        return 0;
    }
    return [_authorities indexOfObject:currentAuthority.url.absoluteString] + 1;
}

+ (NSString *)currentTitle
{
    __auto_type currentAuthority = MSALTestAppSettings.settings.authority;
    return currentAuthority ? currentAuthority.msidAuthority.url.absoluteString : @"(default)";
}


@end
