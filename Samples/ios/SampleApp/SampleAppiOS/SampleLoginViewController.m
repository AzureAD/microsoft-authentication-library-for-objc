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

#import "SampleLoginViewController.h"
#import "SampleAppErrors.h"
#import "SampleAppDelegate.h"
#import "SampleMSALUtil.h"
#import "SampleMainViewController.h"

@interface SampleLoginViewController ()

@end

@implementation SampleLoginViewController

+ (instancetype)sharedViewController
{
    static SampleLoginViewController *s_controller = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        s_controller = [[SampleLoginViewController alloc] initWithNibName:@"SampleLoginView" bundle:nil];
    });
    
    return s_controller;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)signIn:(id)sender
{
    [[SampleMSALUtil sharedUtil] signInAccountWithParentController:self
                                                        completion:^(MSALAccount *account, NSString *token, NSError *error)
    {
        if (error)
        {
            // Don't bother showing an error if the user cancels the sign in flow.
            if (!([error.domain isEqualToString:MSALErrorDomain] && error.code == MSALErrorUserCanceled))
            {
                [self showDialogForError:error];
            }
            
            return;
        }
        
        [SampleAppDelegate setCurrentViewController:[SampleMainViewController sharedViewController]];
    }];
}

- (float)startY
{
    return -1.0f;
}

@end
