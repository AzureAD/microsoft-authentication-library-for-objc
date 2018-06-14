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

#import "MSALTestAppUserViewController.h"
#import "MSALPublicClientApplication.h"
#import "MSALTestAppSettings.h"
#import "MSALAccountId.h"

@interface MSALTestAppUserViewController ()

@end

@implementation MSALTestAppUserViewController
{
    NSArray<MSALAccount *> *_users;
}

+ (instancetype)sharedController
{
    static MSALTestAppUserViewController *s_controller = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        s_controller = [[MSALTestAppUserViewController alloc] init];
    });
    
    return s_controller;
}

- (void)viewDidLoad
{
    self.navigationItem.title = @"Select User";
    [super viewDidLoad];
}

#pragma mark -
#pragma mark Methods for subclasses to override

- (void)refresh
{
    _users = nil;
    
    NSError *error = nil;
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:TEST_APP_CLIENT_ID
                                                authority:settings.authority
                                                    error:&error];
    
    if (!application)
    {
        MSID_LOG_ERROR(nil, @"Failed to create public client application: %@", error);
        return;
    }
    
    _users = [application accounts:nil];
    
    [super refresh];
}

- (NSInteger)numberOfRows
{
    return _users.count + 1;
}

- (NSString *)labelForRow:(NSInteger)row
{
    if (row == 0)
    {
        return @"(nil)";
    }
    return _users[row - 1].username;
}

- (NSString *)subLabelForRow:(NSInteger)row
{
    if (row == 0)
    {
        return @"";
    }
    return _users[row - 1].environment;
}

- (void)rowSelected:(NSInteger)row
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    if (row == 0)
    {
        settings.currentAccount = nil;
    }
    else
    {
        settings.currentAccount = _users[row - 1];
    }
}

- (NSInteger)currentRow
{
    MSALAccount *currentAccount = MSALTestAppSettings.settings.currentAccount;
    if (!currentAccount)
    {
        return 0;
    }
    
    NSString *currentAccountId = currentAccount.homeAccountId.identifier;
    
    for (NSInteger i = 0; i < _users.count; i++)
    {
        if ([currentAccountId isEqualToString:_users[i].homeAccountId.identifier])
        {
            return i + 1;
        }
    }
    return -1;
}

+ (NSString *)currentTitle
{
    MSALAccount *currentAccount = MSALTestAppSettings.settings.currentAccount;
    return currentAccount ? currentAccount.username : @"(nil)";
}

@end
