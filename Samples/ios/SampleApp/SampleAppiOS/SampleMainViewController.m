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
#import "SampleMSALUtil.h"
#import "SampleAppErrors.h"
#import "SampleAppDelegate.h"
#import "SamplePhotoUtil.h"
#import "SampleLoginViewController.h"


@interface SampleMainViewController ()

@end

@implementation SampleMainViewController

+ (instancetype)sharedViewController
{
    static SampleMainViewController *s_controller = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        s_controller = [[SampleMainViewController alloc] initWithNibName:@"SampleMainView" bundle:nil];
    });
    
    return s_controller;
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
    
}

- (void)viewWillAppear:(BOOL)animated
{
    // Set the photo first to "no_photo" so we have something there if we have
    // to wait for network lag
    [self setUserPhoto:[UIImage imageNamed:@"no_photo"]];
    [self loadPhoto];
    
    _nameLabel.text = [NSString stringWithFormat:@"Welcome, %@", [SampleMSALUtil currentUser:nil].name];
    _resultView.text = @"";
}

- (void)loadPhoto
{
    [SamplePhotoUtil getUserPhoto:^(UIImage *photo, NSError *error)
     {
         if (error)
         {
             [self showDialogForError:error];
             return;
         }
         
         [self setUserPhoto:photo];
     }];
}

- (void)setResultText:(NSError *)error
                token:(NSString *)token
{
    NSString *resultText = nil;
    if (error)
    {
        resultText = error.description;
    }
    else
    {
        resultText = [NSString stringWithFormat:@"Retrieved token: %@", token];
    }
    
    _resultView.text = resultText;
    _resultView.hidden = NO;
}

- (IBAction)refreshPhoto:(id)sender
{
    [SamplePhotoUtil clearPhotoCache];
    [self loadPhoto];
}


- (IBAction)acquireTokenSilent:(id)sender
{
    [SampleMSALUtil acquireTokenSilentForCurrentUser:^(NSString *token, NSError *error) {
        [self setResultText:error token:token];
    }];
}

- (IBAction)acquireTokenInteractive:(id)sender

{
    [SampleMSALUtil acquireTokenInteractiveForCurrentUser:^(NSString *token, NSError *error) {
        [self setResultText:error token:token];
    }];
}

- (IBAction)signOut:(id)sender
{
    [SampleMSALUtil signOut];
    [SampleAppDelegate setCurrentViewController:[SampleLoginViewController sharedViewController]];
}

- (float)startY
{
    return 1.0f;
}

@end
