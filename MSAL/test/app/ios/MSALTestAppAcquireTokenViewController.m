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

#import "MSALTestAppAcquireTokenViewController.h"
#import "MSALTestAppSettings.h"
#import "MSALTestAppAcquireLayoutBuilder.h"
#import "MSALTestAppAuthorityViewController.h"
#import "MSALTestAppUserViewController.h"
#import "MSALTestAppScopesViewController.h"
#import "MSALTestAppTelemetryViewController.h"
#import "MSALStressTestHelper.h"

@interface MSALTestAppAcquireTokenViewController () <UITextFieldDelegate>

@end

@implementation MSALTestAppAcquireTokenViewController
{
    UIView *_acquireSettingsView;
    
    UIButton *_authorityButton;
    UISegmentedControl *_validateAuthority;
    
    UITextField *_loginHintField;
    UIButton *_userButton;
    UIButton *_scopesButton;
    
    UIButton *_acquireSilentButton;
    
    UISegmentedControl *_uiBehavior;
    
    UITextView *_resultView;
    
    NSLayoutConstraint *_bottomConstraint;
    NSLayoutConstraint *_bottomConstraint2;
    
    BOOL _userIdEdited;
}

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    UITabBarItem *tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Acquire" image:nil tag:0];
    [self setTabBarItem:tabBarItem];
    
    [self setEdgesForExtendedLayout:UIRectEdgeTop];
    
    [[MSALTestAppTelemetryViewController sharedController] startTracking];
    
    return self;
}

- (void)dealloc
{
    [[MSALTestAppTelemetryViewController sharedController] stopTracking];
}

- (UIView *)createTwoItemLayoutView:(UIView *)item1
                             item2:(UIView *)item2
{
    item1.translatesAutoresizingMaskIntoConstraints = NO;
    item2.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIView *view = [[UIView alloc] init];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:item1];
    [view addSubview:item2];
    
    NSDictionary *views = @{@"item1" : item1, @"item2" : item2 };
    NSArray *verticalConstraints1 = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[item1(20)]|" options:0 metrics:NULL views:views];
    NSArray *verticalConstraints2 = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[item2(20)]|" options:0 metrics:NULL views:views];
    NSArray *horizontalConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[item1]-[item2]|" options:0 metrics:NULL views:views];
    
    [view addConstraints:verticalConstraints1];
    [view addConstraints:verticalConstraints2];
    [view addConstraints:horizontalConstraints];
    
    return view;
}

- (UIButton *)buttonWithTitle:(NSString *)title
                       action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    return button;
}

- (UIView *)createSettingsAndResultView
{
    CGRect screenFrame = UIScreen.mainScreen.bounds;
    
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:screenFrame];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.scrollEnabled = YES;
    scrollView.showsVerticalScrollIndicator = YES;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.userInteractionEnabled = YES;
    MSALTestAppAcquireLayoutBuilder *layout = [MSALTestAppAcquireLayoutBuilder new];
    
    _authorityButton = [self buttonWithTitle:[MSALTestAppAuthorityViewController currentTitle]
                                      action:@selector(selectAuthority:)];
    [layout addControl:_authorityButton title:@"authority"];
    _validateAuthority = [[UISegmentedControl alloc] initWithItems:@[@"Yes", @"No"]];
    [layout addControl:_validateAuthority title:@"valAuth"];
    
    _loginHintField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 400, 20)];
    _loginHintField.borderStyle = UITextBorderStyleRoundedRect;
    _loginHintField.delegate = self;
    [layout addControl:_loginHintField title:@"loginHint"];
    
    _userButton = [self buttonWithTitle:[MSALTestAppUserViewController currentTitle]
                                 action:@selector(selectUser:)];
    [layout addControl:_userButton title:@"user"];
    
    _scopesButton = [self buttonWithTitle:@"scopes"
                                   action:@selector(selectScope:)];
    [layout addControl:_scopesButton title:@"scopes"];
    
    _uiBehavior = [[UISegmentedControl alloc] initWithItems:@[@"Select", @"Login", @"Consent"]];
    _uiBehavior.selectedSegmentIndex = 0;
    [layout addControl:_uiBehavior title:@"behavior"];
    
    
    
    UIButton *clearCache = [UIButton buttonWithType:UIButtonTypeSystem];
    [clearCache setTitle:@"Clear Cache" forState:UIControlStateNormal];
    [clearCache addTarget:self action:@selector(clearCache:) forControlEvents:UIControlEventTouchUpInside];

    [layout addCenteredView:clearCache key:@"clearCache"];
    
    UIButton *telemetryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [telemetryButton setTitle:@"Show telemetry" forState:UIControlStateNormal];
    [telemetryButton addTarget:self action:@selector(showTelemetry:) forControlEvents:UIControlEventTouchUpInside];
    
    [layout addCenteredView:telemetryButton key:@"telemetry"];
    
    UIButton *stressTestButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [stressTestButton setTitle:@"Stress test" forState:UIControlStateNormal];
    [stressTestButton addTarget:self action:@selector(runStressTest:) forControlEvents:UIControlEventTouchUpInside];
    
    [layout addCenteredView:stressTestButton key:@"stressTest"];
    
    _resultView = [[UITextView alloc] init];
    _resultView.layer.borderWidth = 1.0f;
    _resultView.layer.borderColor = [UIColor colorWithRed:0.9f green:0.9f blue:0.9f alpha:1.0f].CGColor;
    _resultView.layer.cornerRadius = 8.0f;
    _resultView.backgroundColor = [UIColor colorWithRed:0.96f green:0.96f blue:0.96f alpha:1.0f];
    _resultView.editable = NO;
    [layout addView:_resultView key:@"result"];
    
    UIView *contentView = [layout contentView];
    [scrollView addSubview:contentView];
    
    NSDictionary *views = @{ @"contentView" : contentView, @"scrollView" : scrollView };
    [scrollView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[contentView]|" options:0 metrics:nil views:views]];
    [scrollView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[contentView]|" options:0 metrics:nil views:views]];
    [scrollView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[contentView(==scrollView)]" options:0 metrics:nil views:views]];
    
    return scrollView;
}

- (UIView *)createAcquireButtonsView
{
    UIButton *acquireButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [acquireButton setTitle:@"acquireToken" forState:UIControlStateNormal];
    [acquireButton addTarget:self action:@selector(acquireTokenInteractive:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *acquireSilentButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [acquireSilentButton setTitle:@"acquireTokenSilent" forState:UIControlStateNormal];
    [acquireSilentButton addTarget:self action:@selector(acquireTokenSilent:) forControlEvents:UIControlEventTouchUpInside];
    
    _acquireSilentButton = acquireSilentButton;
    
    UIView *acquireButtonsView = [self createTwoItemLayoutView:acquireButton item2:acquireSilentButton];
    UIVisualEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    UIVisualEffectView *acquireBlurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    acquireBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    [acquireBlurView.contentView addSubview:acquireButtonsView];
    
    // Constraint to center the acquire buttons in the blur view
    [acquireBlurView addConstraint:[NSLayoutConstraint constraintWithItem:acquireButtonsView
                                                                attribute:NSLayoutAttributeCenterX
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:acquireBlurView
                                                                attribute:NSLayoutAttributeCenterX
                                                               multiplier:1.0
                                                                 constant:0.0]];
    NSDictionary *views = @{ @"buttons" : acquireButtonsView };
    [acquireBlurView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-6-[buttons]-6-|" options:0 metrics:nil views:views]];
    
    return acquireBlurView;
}


- (void)loadView
{
    CGRect screenFrame = UIScreen.mainScreen.bounds;
    UIView *mainView = [[UIView alloc] initWithFrame:screenFrame];
    
    UIView *settingsView = [self createSettingsAndResultView];
    [mainView addSubview:settingsView];
    
    UIView *acquireBlurView = [self createAcquireButtonsView];
    [mainView addSubview:acquireBlurView];
    
    self.view = mainView;
    
    NSDictionary *views = @{ @"settings" : settingsView, @"acquire" : acquireBlurView };
    // Set up constraints for the web overlay
    
    // Set up constraints to make the settings scroll view take up the whole screen
    [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[settings]|" options:0 metrics:nil views:views]];
    [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[settings(>=200)]" options:0 metrics:nil views:views]];
    _bottomConstraint2 = [NSLayoutConstraint constraintWithItem:settingsView
                                                      attribute:NSLayoutAttributeBottom
                                                      relatedBy:NSLayoutRelationEqual
                                                         toItem:self.bottomLayoutGuide
                                                      attribute:NSLayoutAttributeTop
                                                     multiplier:1.0
                                                       constant:0];
    [mainView addConstraint:_bottomConstraint2];
    
    
    // And more constraints to make the acquire buttons view float on top
    [mainView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[acquire]|" options:0 metrics:nil views:views]];
    
    // This constraint is the one that gets adjusted when the keyboard hides or shows. It moves the acquire buttons to make sure
    // they remain in view above the keyboard
    _bottomConstraint = [NSLayoutConstraint constraintWithItem:acquireBlurView
                                                     attribute:NSLayoutAttributeBottom
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self.bottomLayoutGuide
                                                     attribute:NSLayoutAttributeTop
                                                    multiplier:1.0
                                                      constant:0];
    [mainView addConstraint:_bottomConstraint];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)keyboardWillShow:(NSNotification *)aNotification
{
    NSDictionary *userInfo = aNotification.userInfo;
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    
    CGRect keyboardFrameEnd = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    keyboardFrameEnd = [self.view convertRect:keyboardFrameEnd fromView:nil];
    
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState | curve animations:^{
        _bottomConstraint.constant = -keyboardFrameEnd.size.height + 49.0; // 49.0 is the height of a tab bar
        _bottomConstraint2.constant = -keyboardFrameEnd.size.height + 49.0;
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)keyboardWillHide:(NSNotification *)note {
    NSDictionary *userInfo = note.userInfo;
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState | curve animations:^{
        _bottomConstraint.constant = 0;
        _bottomConstraint2.constant = 0;
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    NSString *loginHint = settings.loginHint;
    if (![NSString msalIsStringNilOrBlank:loginHint])
    {
        _loginHintField.text = loginHint;
    }
    
    self.navigationController.navigationBarHidden = YES;
    _validateAuthority.selectedSegmentIndex = settings.validateAuthority ? 0 : 1;
    
    [_authorityButton setTitle:[MSALTestAppAuthorityViewController currentTitle]
                      forState:UIControlStateNormal];
    [_userButton setTitle:[MSALTestAppUserViewController currentTitle]
                 forState:UIControlStateNormal];

    [_scopesButton setTitle:(settings.scopes.count == 0) ? @"select scopes" : [settings.scopes.allObjects componentsJoinedByString:@","]
                   forState:UIControlStateNormal];
    
    [super viewWillAppear:animated];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.

}

- (void)updateResultViewError:(NSError *)error
{
    NSString *resultText = [NSString stringWithFormat:@"%@", error];
    [_resultView setText:resultText];
    
    NSLog(@"%@", resultText);
}

- (void)updateResultView:(MSALResult *)result
{
    NSString *resultText = [NSString stringWithFormat:@"{\n\taccessToken = %@\n\texpiresOn = %@\n\ttenantId = %@\t\nuser = %@\t\nscopes = %@\n}",
                            [result.accessToken msalShortSHA256Hex], result.expiresOn, result.tenantId, result.user, result.scopes];
    
    [_resultView setText:resultText];
    
    NSLog(@"%@", resultText);
}

- (MSALUIBehavior)uiBehavior
{
    NSString *label = [_uiBehavior titleForSegmentAtIndex:_uiBehavior.selectedSegmentIndex];
    
    if ([label isEqualToString:@"Select"])
        return MSALSelectAccount;
    if ([label isEqualToString:@"Login"])
        return MSALForceLogin;
    if ([label isEqualToString:@"Consent"])
        return MSALForceConsent;
    
    @throw @"Do not recognize prompt behavior";
}

- (void)acquireTokenInteractive:(id)sender
{
    (void)sender;
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    NSString *authority = [settings authority];
    NSString *clientId = TEST_APP_CLIENT_ID;
    //NSURL* redirectUri = [settings redirectUri];
    
    NSError *error = nil;
    MSALPublicClientApplication *application = 
    [[MSALPublicClientApplication alloc] initWithClientId:clientId authority:authority error:&error];
    if (!application)
    {
        NSString *resultText = [NSString stringWithFormat:@"Failed to create PublicClientApplication:\n%@", error];
        [_resultView setText:resultText];
        return;
    }
    
    application.validateAuthority = (_validateAuthority.selectedSegmentIndex == 0);
    
    __block BOOL fBlockHit = NO;
    
    [application acquireTokenForScopes:[settings.scopes allObjects]
                                  user:settings.currentUser
                            uiBehavior:MSALUIBehaviorDefault
                  extraQueryParameters:nil
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         if (fBlockHit)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error!"
                                                                                message:@"Completion block was hit multiple times!"
                                                                         preferredStyle:UIAlertControllerStyleAlert];
                 [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil]];
                 [self presentViewController:alert animated:YES completion:nil];
             });
             
             return;
         }
         fBlockHit = YES;
         
         dispatch_async(dispatch_get_main_queue(), ^{
             if (result)
             {
                 [self updateResultView:result];
             }
             else
             {
                 [self updateResultViewError:error];
             }
             [[NSNotificationCenter defaultCenter] postNotificationName:MSALTestAppCacheChangeNotification object:self];
         });
     }];
}

- (IBAction)cancelAuth:(id)sender
{
    (void)sender;
    [MSALPublicClientApplication cancelCurrentWebAuthSession];
}

- (IBAction)acquireTokenSilent:(id)sender
{
    (void)sender;
    
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    
    if (!settings.currentUser)
    {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error!"
                                                                       message:@"User needs to be selected for acquire token silent call"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    NSString *authority = [settings authority];
    NSString *clientId = TEST_APP_CLIENT_ID;
    
    NSError *error = nil;
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:clientId authority:authority error:&error];
    if (!application)
    {
        NSString *resultText = [NSString stringWithFormat:@"Failed to create PublicClientApplication:\n%@", error];
        [_resultView setText:resultText];
        return;
    }
    
    application.validateAuthority = (_validateAuthority.selectedSegmentIndex == 0);
    
    __block BOOL fBlockHit = NO;
    _acquireSilentButton.enabled = NO;
    
    [application acquireTokenSilentForScopes:[settings.scopes allObjects]
                                        user:settings.currentUser
                             completionBlock:^(MSALResult *result, NSError *error)
    {
        if (fBlockHit)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                _acquireSilentButton.enabled = YES;
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error!"
                                                                               message:@"Completion block was hit multiple times!"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            });
            
            return;
        }
        fBlockHit = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            _acquireSilentButton.enabled = YES;
            if (result)
            {
                [self updateResultView:result];
            }
            else
            {
                [self updateResultViewError:error];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:MSALTestAppCacheChangeNotification object:self];
        });
    }];
}

- (IBAction)clearCache:(id)sender
{
    (void)sender;
    
    NSDictionary *query = [[MSALKeychainTokenCache defaultKeychainCache] defaultKeychainQuery];
    OSStatus status = SecItemDelete((CFDictionaryRef)query);
    
    if (status == errSecSuccess || status == errSecItemNotFound)
    {
        _resultView.text = @"Successfully cleared cache.";
        
        MSALTestAppSettings *settings = [MSALTestAppSettings settings];
        settings.currentUser = nil;
        
        [_userButton setTitle:[MSALTestAppUserViewController currentTitle]
                     forState:UIControlStateNormal];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:MSALTestAppCacheChangeNotification object:self];
    }
    else
    {
        _resultView.text = [NSString stringWithFormat:@"Failed to clear cache, error = %d", (int)status];
    }
}

- (IBAction)showTelemetry:(id)sender
{
    (void)sender;
    [self.navigationController pushViewController:[MSALTestAppTelemetryViewController sharedController] animated:YES];
}

- (IBAction)selectAuthority:(id)sender
{
    (void)sender;
    [self.navigationController pushViewController:[MSALTestAppAuthorityViewController sharedController] animated:YES];
}

- (IBAction)selectUser:(id)sender
{
    (void)sender;
    [self.navigationController pushViewController:[MSALTestAppUserViewController sharedController] animated:YES];
}

- (void)selectScope:(id)sender
{
    (void)sender;
    [self.navigationController pushViewController:[MSALTestAppScopesViewController sharedController] animated:YES];
}

#pragma mark - Stress tests

- (void)runStressTest:(id)sender
{
    (void)sender;
    
    UIAlertController *stressTestController = [UIAlertController alertControllerWithTitle:@"Select stress test type"
                                                                                  message:nil
                                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    [stressTestController addAction:[UIAlertAction actionWithTitle:@"Acquire token silent (no expiring)"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                                                               
                                                               (void)action;
                                                               [self runStressTestWithType:MSALStressTestWithSameToken];
                                                           }]];
    
    [stressTestController addAction:[UIAlertAction actionWithTitle:@"Acquire token silent (with expiring)"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                                                               
                                                               (void)action;
                                                               [self runStressTestWithType:MSALStressTestWithExpiredToken];
                                                           }]];
    
    [stressTestController addAction:[UIAlertAction actionWithTitle:@"Acquire token silent (with multiple users)"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                                                               
                                                               (void)action;
                                                               [self runStressTestWithType:MSALStressTestWithMultipleUsers];
                                                           }]];
    
    [stressTestController addAction:[UIAlertAction actionWithTitle:@"Acquire token silent (until success)"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                                                               
                                                               (void)action;
                                                               [self runStressTestWithType:MSALStressTestOnlyUntilSuccess];
                                                           }]];
    
    [stressTestController addAction:[UIAlertAction actionWithTitle:@"Stop stress test"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                                                               
                                                               (void)action;
                                                               [self stopStressTest];
                                                           }]];
    
    [stressTestController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                             style:UIAlertActionStyleCancel
                                                           handler:nil]];
    
    [self presentViewController:stressTestController animated:YES completion:nil];
}

- (void)runStressTestWithType:(MSALStressTestType)type
{
    MSALTestAppSettings *settings = [MSALTestAppSettings settings];
    
    if (![[settings.scopes allObjects] count])
    {
        _resultView.text = @"Please select the scope!";
        return;
    }
    
    NSString *authority = [settings authority];
    NSString *clientId = TEST_APP_CLIENT_ID;
    
    NSError *error = nil;
    
    MSALPublicClientApplication *application = [[MSALPublicClientApplication alloc] initWithClientId:clientId authority:authority error:&error];
    
    if (!application)
    {
        _resultView.text = [NSString stringWithFormat:@"Failed to create PublicClientApplication:\n%@", error];
        return;
    }
    
    NSUInteger existingUserCount = [[application users:nil] count];
    NSUInteger requiredUserCount = [MSALStressTestHelper numberOfUsersNeededForTestType:type];
    
    if (existingUserCount != requiredUserCount)
    {
        _resultView.text = [NSString stringWithFormat:@"Wrong number of users in cache (existing %ld, required %ld)", (unsigned long)existingUserCount, (unsigned long)requiredUserCount];
        return;
    }
    
    [[MSALTestAppTelemetryViewController sharedController] stopTracking];
    [[MSALLogger sharedLogger] setLevel:MSALLogLevelNothing];
    
    if ([MSALStressTestHelper runStressTestWithType:type application:application])
    {
        _resultView.text = [NSString stringWithFormat:@"Started running a stress test at %@", [NSDate date]];
    }
    else
    {
        _resultView.text = @"Cannot start test, because other test is currently running!";
    }
}

- (void)stopStressTest
{
    [MSALStressTestHelper stopStressTest];
    
    _resultView.text = [NSString stringWithFormat:@"Stopped the currently running stress test at %@", [NSDate date]];
    
    [[MSALTestAppTelemetryViewController sharedController] startTracking];
    [[MSALLogger sharedLogger] setLevel:MSALLogLevelVerbose];
}

@end
