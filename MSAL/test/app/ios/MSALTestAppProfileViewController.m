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

#import "MSALTestAppProfileViewController.h"
#import "MSALTestAppSettings.h"

@interface MSALTestAppProfileViewController ()

@end

@implementation MSALTestAppProfileViewController

+ (instancetype)sharedController
{
    static MSALTestAppProfileViewController *s_controller = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        s_controller = [[MSALTestAppProfileViewController alloc] init];
    });
    
    return s_controller;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _profiles = [MSALTestAppSettings profiles];
    }
    return self;
}

#pragma mark -
#pragma mark Methods for subclasses to override

- (void)viewDidLoad
{
    self.navigationItem.title = @"Select Profile";
    [super viewDidLoad];
}

- (NSInteger)numberOfRows
{
    return _profiles.count;
}

- (NSString *)labelForRow:(NSInteger)row
{
    return [MSALTestAppSettings profileTitleForIndex:row];
}

- (void)rowSelected:(NSInteger)row
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    [settings setCurrentProfile:row];
}

+ (NSString *)currentTitle
{
    return [MSALTestAppSettings currentProfileName];
}

@end
