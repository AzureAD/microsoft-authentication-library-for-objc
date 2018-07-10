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
#import "MSALAuthorityFactory.h"
#import "MSALAuthority_Internal.h"

@interface MSALTestAppAuthorityViewController ()

@end

@implementation MSALTestAppAuthorityViewController
{
    NSMutableArray <MSALAuthority *> *_authorities;
    NSMutableArray <MSALAuthority *> *_savedAuthorities;
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

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    __auto_type currentAuthority = MSALTestAppSettings.settings.authority;
    _authorities = [[MSALTestAppSettings authorities] mutableCopy];
    if (currentAuthority && ![_authorities containsObject:currentAuthority])
    {
        [_authorities addObject:currentAuthority];
    }

    _savedAuthorities = [[[NSUserDefaults standardUserDefaults] objectForKey:@"saved_authorities"] mutableCopy];

    if (!_savedAuthorities)
    {
        _savedAuthorities = [NSMutableArray array];
    }

    [_authorities addObjectsFromArray:_savedAuthorities];
    
    return self;
}

#pragma mark -
#pragma mark Methods for subclasses to override

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

        __auto_type authorityFactory = [MSALAuthorityFactory new];
        __auto_type authorityUrl = [[NSURL alloc] initWithString:controller.textFields[0].text];
        __auto_type authority = [authorityFactory authorityFromUrl:authorityUrl context:nil error:nil];
        
        [self saveAuthority:authority];
    }]];

    [self presentViewController:controller animated:YES completion:nil];

}

- (void)saveAuthority:(MSALAuthority *)authority
{
    [_savedAuthorities addObject:authority];
    [[NSUserDefaults standardUserDefaults] setObject:_savedAuthorities forKey:@"saved_authorities"];
    [_authorities addObject:authority];
    [super refresh];
}

- (void)refresh
{
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
    
    return _authorities[row - 1].msidAuthority.url.absoluteString;
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
        settings.authority = _authorities[row - 1];
    }
}

- (NSInteger)currentRow
{
    __auto_type currentAuthority = MSALTestAppSettings.settings.authority;
    if (currentAuthority == nil)
    {
        return 0;
    }
    return [_authorities indexOfObjectIdenticalTo:currentAuthority] + 1;
}

+ (NSString *)currentTitle
{
    __auto_type currentAuthority = MSALTestAppSettings.settings.authority;
    return currentAuthority ? currentAuthority.msidAuthority.url.absoluteString : @"(default)";
}


@end
