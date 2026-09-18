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

#import "MSALTestAppBoundSPAViewController.h"
#import "MSALTestAppBoundSPAHarness.h"

static NSString *const MSALTestAppBoundSPADefaultJSON =
    @"{\n"
     "  \"sender\": \"https://<test-spa-host>\",\n"
     "  \"request\": {\n"
     "    \"clientId\": \"<registered-spa-client-id>\",\n"
     "    \"authority\": \"https://login.microsoftonline.com/<tenant-id>\",\n"
     "    \"scope\": \"<consented-resource-scope>\",\n"
     "    \"redirectUri\": \"https://<test-spa-host>/<registered-callback>\",\n"
     "    \"prompt\": \"select_account\",\n"
     "    \"canShowUI\": true\n"
     "  }\n"
     "}";

@interface MSALTestAppBoundSPAViewController ()
    <UITextFieldDelegate, UITextViewDelegate>

@property (nonatomic) MSALTestAppBoundSPAHarness *harness;
@property (nonatomic) UITextField *originTextField;
@property (nonatomic) UITextView *requestTextView;
@property (nonatomic) UISegmentedControl *modeControl;
@property (nonatomic) UILabel *statusLabel;
@property (nonatomic) UITextView *resultTextView;
@property (nonatomic) UIButton *runButton;
@property (nonatomic) UIBarButtonItem *doneButton;

@end

@implementation MSALTestAppBoundSPAViewController

- (instancetype)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _harness = [MSALTestAppBoundSPAHarness new];
        self.title = @"Bound SPA GetToken";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    self.doneButton = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                             target:self
                             action:@selector(close)];
    self.navigationItem.rightBarButtonItem = self.doneButton;

    UIScrollView *scrollView = [UIScrollView new];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scrollView];

    UIStackView *stackView = [UIStackView new];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 12.0;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:stackView];

    UILabel *warningLabel = [self labelWithText:
        @"This is a controlled native caller. The origin below is test-supplied "
         "context, not a verified browser origin. A cold restart cannot restore "
         "the original in-memory completion block. Inspect bound-refresh-token "
         "metadata in the Cache tab using com.microsoft.adalcache; delete only "
         "the selected test SPA/account credential for missing-BART testing."];
    warningLabel.textColor = UIColor.systemOrangeColor;
    [stackView addArrangedSubview:warningLabel];

    [stackView addArrangedSubview:[self labelWithText:@"Explicit test origin"]];
    self.originTextField = [UITextField new];
    self.originTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.originTextField.autocapitalizationType =
        UITextAutocapitalizationTypeNone;
    self.originTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.originTextField.keyboardType = UIKeyboardTypeURL;
    self.originTextField.text = @"https://<test-spa-host>";
    self.originTextField.delegate = self;
    self.originTextField.accessibilityIdentifier = @"bound-spa-origin";
    [stackView addArrangedSubview:self.originTextField];

    [stackView addArrangedSubview:[self labelWithText:@"Run mode"]];
    self.modeControl = [[UISegmentedControl alloc]
        initWithItems:@[@"Interactive", @"Silent only", @"Recovery"]];
    self.modeControl.selectedSegmentIndex = 0;
    self.modeControl.accessibilityIdentifier = @"bound-spa-mode";
    [self.modeControl addTarget:self
                         action:@selector(contextChanged)
               forControlEvents:UIControlEventValueChanged];
    [stackView addArrangedSubview:self.modeControl];

    [stackView addArrangedSubview:[self labelWithText:@"GetToken JSON"]];
    self.requestTextView = [self textViewWithHeight:280.0];
    self.requestTextView.text = MSALTestAppBoundSPADefaultJSON;
    self.requestTextView.delegate = self;
    self.requestTextView.editable = YES;
    self.requestTextView.accessibilityIdentifier = @"bound-spa-request";
    [stackView addArrangedSubview:self.requestTextView];

    self.runButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.runButton setTitle:@"Run Bound SPA GetToken"
                    forState:UIControlStateNormal];
    self.runButton.titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
    self.runButton.accessibilityIdentifier = @"bound-spa-run";
    [self.runButton addTarget:self
                       action:@selector(runBoundSPARequest)
             forControlEvents:UIControlEventTouchUpInside];
    [self.runButton.heightAnchor constraintEqualToConstant:44.0].active = YES;
    [stackView addArrangedSubview:self.runButton];

    self.statusLabel = [self labelWithText:@""];
    self.statusLabel.accessibilityIdentifier = @"bound-spa-status";
    [stackView addArrangedSubview:self.statusLabel];
    [self updateModeStatus:@"Ready"];

    [stackView addArrangedSubview:
        [self labelWithText:@"Redacted result / actionable error"]];
    self.resultTextView = [self textViewWithHeight:240.0];
    self.resultTextView.editable = NO;
    self.resultTextView.accessibilityIdentifier = @"bound-spa-result";
    [stackView addArrangedSubview:self.resultTextView];

    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],
        [stackView.leadingAnchor
            constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor
                          constant:16.0],
        [stackView.trailingAnchor
            constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor
                          constant:-16.0],
        [stackView.topAnchor
            constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor
                          constant:16.0],
        [stackView.bottomAnchor
            constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor
                          constant:-16.0],
        [stackView.widthAnchor
            constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor
                          constant:-32.0]
    ]];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if (self.isMovingFromParentViewController
        || self.navigationController.isBeingDismissed)
    {
        [self.harness invalidateContext];
    }
}

#pragma mark - Actions

- (void)close
{
    if (self.harness.isRequestInFlight)
    {
        [self updateModeStatus:@"A request is in flight; wait for its callback."];
        return;
    }

    [self.harness invalidateContext];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)contextChanged
{
    [self.harness invalidateContext];
    NSString *state = self.harness.isRequestInFlight
        ? @"Context changed; the pending result will be discarded."
        : @"Ready";
    [self updateModeStatus:state];
}

- (void)runBoundSPARequest
{
    [self.view endEditing:YES];

    NSDictionary *effectiveRequest = nil;
    NSError *error = nil;
    MSALTestAppBoundSPAMode mode =
        (MSALTestAppBoundSPAMode)self.modeControl.selectedSegmentIndex;
    __weak typeof(self) weakSelf = self;
    BOOL started = [self.harness
        submitJSONString:self.requestTextView.text
              testOrigin:self.originTextField.text
                    mode:mode
        effectiveRequest:&effectiveRequest
              completion:^(NSString *presentation,
                           NSError *completionError,
                           BOOL stale)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf)
            {
                return;
            }

            strongSelf.runButton.enabled = YES;
            strongSelf.doneButton.enabled = YES;
            strongSelf.modalInPresentation = NO;
            if (stale)
            {
                [strongSelf updateModeStatus:
                    @"Discarded a stale result after the test context changed."];
                return;
            }

            strongSelf.resultTextView.text = presentation;
            [strongSelf updateModeStatus:completionError
                ? @"Completed with error"
                : @"Completed successfully"];
        });
    }
                   error:&error];
    if (!started)
    {
        self.resultTextView.text = [NSString stringWithFormat:
            @"Validation failed\n"
             "domain: %@\n"
             "code: %ld\n"
             "description: %@",
            error.domain,
            (long)error.code,
            error.localizedDescription];
        [self updateModeStatus:@"Request not submitted"];
        return;
    }

    NSData *effectiveData = [NSJSONSerialization
        dataWithJSONObject:effectiveRequest
                   options:NSJSONWritingPrettyPrinted
                     error:nil];
    if (effectiveData)
    {
        self.requestTextView.text =
            [[NSString alloc] initWithData:effectiveData
                                  encoding:NSUTF8StringEncoding];
    }

    self.resultTextView.text =
        @"Request submitted through "
         "MSALPublicClientApplication.acquireBoundSPATokenWithRequest.";
    self.runButton.enabled = NO;
    self.doneButton.enabled = NO;
    self.modalInPresentation = YES;
    [self updateModeStatus:@"In flight"];
}

#pragma mark - Controls

- (UILabel *)labelWithText:(NSString *)text
{
    UILabel *label = [UILabel new];
    label.text = text;
    label.numberOfLines = 0;
    label.font = [UIFont systemFontOfSize:13.0];
    return label;
}

- (UITextView *)textViewWithHeight:(CGFloat)height
{
    UITextView *textView = [UITextView new];
    textView.font = [UIFont monospacedSystemFontOfSize:12.0
                                               weight:UIFontWeightRegular];
    textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textView.autocorrectionType = UITextAutocorrectionTypeNo;
    textView.spellCheckingType = UITextSpellCheckingTypeNo;
    textView.smartDashesType = UITextSmartDashesTypeNo;
    textView.smartQuotesType = UITextSmartQuotesTypeNo;
    textView.layer.borderColor = UIColor.systemGray4Color.CGColor;
    textView.layer.borderWidth = 1.0;
    textView.layer.cornerRadius = 6.0;
    [textView.heightAnchor constraintEqualToConstant:height].active = YES;
    return textView;
}

- (void)updateModeStatus:(NSString *)status
{
    MSALTestAppBoundSPAMode mode =
        (MSALTestAppBoundSPAMode)self.modeControl.selectedSegmentIndex;
    self.statusLabel.text = [NSString stringWithFormat:
        @"Effective mode: %@\n%@",
        [MSALTestAppBoundSPAHarness displayNameForMode:mode],
        status];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidChangeSelection:(UITextField *)textField
{
    (void)textField;
    [self contextChanged];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView
{
    (void)textView;
    [self contextChanged];
}

@end
