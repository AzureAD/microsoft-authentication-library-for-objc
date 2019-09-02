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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSALADFSBaseUITest.h"
#import "XCTestCase+TextFieldTap.h"

@implementation MSALADFSBaseUITest

- (NSString *)runSharedADFSInteractiveLoginWithRequest:(MSIDAutomationTestRequest *)request
{
    return [self runSharedADFSInteractiveLoginWithRequest:request closeResultView:YES];
}

- (NSString *)runSharedADFSInteractiveLoginWithRequest:(MSIDAutomationTestRequest *)request
                                       closeResultView:(BOOL)closeResultView
{
    // 1. Do interactive login
    NSDictionary *config = [self configWithTestRequest:request];
    [self acquireToken:config];

    [self acceptAuthSessionDialogIfNecessary:request];

    if (!request.loginHint)
    {
        [self aadEnterEmail];
    }

    [self enterADFSPassword];
    [self acceptMSSTSConsentIfNecessary:@"Accept" embeddedWebView:request.usesEmbeddedWebView];
    
    if (!request.usesEmbeddedWebView)
    {
        [self acceptSpeedBump];
    }

    NSString *homeAccountId = [self runSharedResultAssertionWithTestRequest:request];

    if (closeResultView)
    {
        [self closeResultView];
    }

    return homeAccountId;
}

- (void)enterADFSPassword
{
    XCUIElement *passwordTextField = self.testApp.secureTextFields[@"Password"];
    [self waitForElement:passwordTextField];
    [self tapElementAndWaitForKeyboardToAppear:passwordTextField];
    [passwordTextField typeText:[NSString stringWithFormat:@"%@\n", self.primaryAccount.password]];
}

@end
