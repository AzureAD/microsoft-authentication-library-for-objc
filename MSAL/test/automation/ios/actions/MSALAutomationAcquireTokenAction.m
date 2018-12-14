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

#import "MSALAutomationAcquireTokenAction.h"
#import "MSIDAutomation.h"
#import "MSIDAutomationTestResult.h"
#import <MSAL/MSAL.h>
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSALAutomationConstants.h"
#import "MSIDAutomationMainViewController.h"

@implementation MSALAutomationAcquireTokenAction

- (NSString *)actionIdentifier
{
    return @"acquire_token";
}

- (BOOL)needsRequestParameters
{
    return YES;
}

- (void)performActionWithParameters:(NSDictionary *)parameters
                containerController:(MSIDAutomationMainViewController *)containerController
                    completionBlock:(MSIDAutoCompletionBlock)completionBlock
{
    NSError *applicationError = nil;
    MSALPublicClientApplication *application = [self applicationWithParameters:parameters error:&applicationError];

    if (!application)
    {
        MSIDAutomationTestResult *result = [self testResultWithMSALError:applicationError];
        completionBlock(result);
        return;
    }

    NSError *accountError = nil;
    MSALAccount *account = [self accountWithParameters:parameters application:application error:&accountError];

    if (accountError)
    {
        MSIDAutomationTestResult *result = [self testResultWithMSALError:applicationError];
        completionBlock(result);
        return;
    }

    NSOrderedSet *scopes = [NSOrderedSet msidOrderedSetFromString:parameters[MSAL_SCOPES_PARAM]];
    NSOrderedSet *extraScopes = [NSOrderedSet msidOrderedSetFromString:parameters[MSAL_EXTRA_SCOPES_PARAM]];
    NSUUID *correlationId = parameters[MSAL_CORRELATION_ID_PARAM] ? [[NSUUID alloc] initWithUUIDString:parameters[MSAL_CORRELATION_ID_PARAM]] : nil;
    NSString *claims = parameters[MSAL_CLAIMS_PARAM];
    NSDictionary *extraQueryParameters = parameters[MSAL_EXTRA_QP_PARAM];

    MSALUIBehavior uiBehavior = MSALUIBehaviorDefault;

    if ([parameters[MSAL_UI_BEHAVIOR] isEqualToString:@"force"])
    {
        uiBehavior = MSALForceLogin;
    }
    else if ([parameters[MSAL_UI_BEHAVIOR] isEqualToString:@"consent"])
    {
        uiBehavior = MSALForceConsent;
    }
    else if ([parameters[MSAL_UI_BEHAVIOR] isEqualToString:@"prompt_if_necessary"])
    {
        uiBehavior = MSALPromptIfNecessary;
    }

    NSString *webviewSelection = parameters[MSAL_AUTOMATION_WEBVIEWSELECTION_PARAM];
    if ([webviewSelection isEqualToString:MSAL_AUTOMATION_WEBVIEWSELECTION_VALUE_EMBEDDED])
    {
        application.webviewType = MSALWebviewTypeWKWebView;
    }
    else if ([webviewSelection isEqualToString:MSAL_AUTOMATION_WEBVIEWSELECTION_VALUE_SYSTEM])
    {
        application.webviewType = MSALWebviewTypeDefault;
    }
    else if ([webviewSelection isEqualToString:MSAL_AUTOMATION_WEBVIEWSELECTION_VALUE_SAFARI])
    {
        application.webviewType = MSALWebviewTypeSafariViewController;
    }
    else if ([webviewSelection isEqualToString:MSAL_AUTOMATION_WEBVIEWSELECTION_VALUE_PASSED])
    {
        application.webviewType = MSALWebviewTypeWKWebView;
        application.customWebview = containerController.passedinWebView;
        [containerController showPassedInWebViewControllerWithContext:@{@"context": application}];
    }

    if (account)
    {
        [application acquireTokenForScopes:scopes.array
                      extraScopesToConsent:extraScopes.array
                                   account:account
                                uiBehavior:uiBehavior
                      extraQueryParameters:extraQueryParameters
                                    claims:claims
         // TODO: separate PUB authority from acquire token authority
                                 authority:nil // Will use the authority passed in with the application object
                             correlationId:correlationId
                           completionBlock:^(MSALResult *result, NSError *error)
         {
             MSIDAutomationTestResult *testResult = [self testResultWithMSALResult:result error:error];
             completionBlock(testResult);
         }];
    }
    else
    {
        NSString *loginHint = parameters[MSAL_LOGIN_HINT_PARAM];

        [application acquireTokenForScopes:scopes.array
                      extraScopesToConsent:extraScopes.array
                                 loginHint:loginHint
                                uiBehavior:uiBehavior
                      extraQueryParameters:extraQueryParameters
                                 authority:nil
                             correlationId:correlationId
                           completionBlock:^(MSALResult *result, NSError *error) {

                               MSIDAutomationTestResult *testResult = [self testResultWithMSALResult:result error:error];
                               completionBlock(testResult);
                           }];
    }
}

@end
