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
#import "MSIDAutomationMainViewController.h"
#import "MSIDAutomationTestRequest.h"
#import "MSIDAutomationActionConstants.h"
#import "MSIDAutomationActionManager.h"
#import "MSIDAutomationPassedInWebViewController.h"
#import "MSALInteractiveTokenParameters.h"
#import "MSALClaimsRequest.h"
#import "MSALWebviewParameters.h"

@implementation MSALAutomationAcquireTokenAction

+ (void)load
{
    [[MSIDAutomationActionManager sharedInstance] registerAction:[MSALAutomationAcquireTokenAction new]];
    [MSIDAutomationPassedInWebViewController setCancelTappedCallback:^{
        [MSALPublicClientApplication cancelCurrentWebAuthSession];
    }];
}

- (NSString *)actionIdentifier
{
    return MSID_AUTO_ACQUIRE_TOKEN_ACTION_IDENTIFIER;
}

- (BOOL)needsRequestParameters
{
    return YES;
}

- (void)performActionWithParameters:(MSIDAutomationTestRequest *)testRequest
                containerController:(MSIDAutomationMainViewController *)containerController
                    completionBlock:(MSIDAutoCompletionBlock)completionBlock
{
    NSError *applicationError = nil;
    MSALPublicClientApplication *application = [self applicationWithParameters:testRequest error:&applicationError];

    if (!application)
    {
        MSIDAutomationTestResult *result = [self testResultWithMSALError:applicationError];
        completionBlock(result);
        return;
    }

    NSError *accountError = nil;
    MSALAccount *account = [self accountWithParameters:testRequest application:application error:&accountError];

    if (accountError)
    {
        MSIDAutomationTestResult *result = [self testResultWithMSALError:applicationError];
        completionBlock(result);
        return;
    }

    NSOrderedSet *scopes = [NSOrderedSet msidOrderedSetFromString:testRequest.requestScopes];
    NSOrderedSet *extraScopes = [NSOrderedSet msidOrderedSetFromString:testRequest.extraScopes];
    NSUUID *correlationId = [NSUUID new];
    
    MSALClaimsRequest *claimsRequest = nil;
    
    if (testRequest.claims.length)
    {
        NSError *claimsError;
        claimsRequest = [[MSALClaimsRequest alloc] initWithJsonString:testRequest.claims error:&claimsError];
        if (claimsError)
        {
            MSIDAutomationTestResult *result = [self testResultWithMSALError:claimsError];
            completionBlock(result);
            return;
        }
    }
    
    NSDictionary *extraQueryParameters = testRequest.extraQueryParameters;

    MSALPromptType promptType = MSALPromptTypeDefault;

    if ([testRequest.promptBehavior isEqualToString:@"force"])
    {
        promptType = MSALPromptTypeLogin;
    }
    else if ([testRequest.promptBehavior isEqualToString:@"consent"])
    {
        promptType = MSALPromptTypeConsent;
    }
    else if ([testRequest.promptBehavior isEqualToString:@"prompt_if_necessary"])
    {
        promptType = MSALPromptTypePromptIfNecessary;
    }
    else if ([testRequest.promptBehavior isEqualToString:@"select_account"])
    {
        promptType = MSALPromptTypeSelectAccount;
    }

    MSALAuthority *acquireTokenAuthority = nil;

    if (testRequest.acquireTokenAuthority)
    {
        NSURL *authorityUrl = [[NSURL alloc] initWithString:testRequest.acquireTokenAuthority];
        acquireTokenAuthority = [MSALAuthority authorityWithURL:authorityUrl error:nil];
    }
    
    UIViewController *parentController = containerController;
    
    if (containerController.presentedViewController)
    {
        parentController = containerController.presentedViewController;
    }
    
    MSALWebviewParameters *webviewParameters= [[MSALWebviewParameters alloc] initWithParentViewController:parentController];
    
    MSIDWebviewType webviewSelection = testRequest.webViewType;
    
    switch (webviewSelection) {
        case MSIDWebviewTypeWKWebView:
            webviewParameters.webviewType = MSALWebviewTypeWKWebView;
            break;
            
        case MSIDWebviewTypeDefault:
            webviewParameters.webviewType = MSALWebviewTypeDefault;
            break;
            
        case MSIDWebviewTypeSafariViewController:
            webviewParameters.webviewType = MSALWebviewTypeSafariViewController;
            break;
            
        case MSIDWebviewTypeAuthenticationSession:
            webviewParameters.webviewType = MSALWebviewTypeAuthenticationSession;
            break;
            
        default:
            break;
    }
    
    if (testRequest.usePassedWebView)
    {
        webviewParameters.webviewType = MSALWebviewTypeWKWebView;
        webviewParameters.customWebview = containerController.passedinWebView;
        [containerController showPassedInWebViewControllerWithContext:@{@"context": application}];
        webviewParameters.parentViewController = containerController;
    }
    
    MSALInteractiveTokenParameters *parameters = [[MSALInteractiveTokenParameters alloc] initWithScopes:scopes.array
                                                                                          webviewParameters:webviewParameters];
    parameters.extraScopesToConsent = extraScopes.array;
    parameters.account = account;
    parameters.loginHint = testRequest.loginHint;
    parameters.promptType = promptType;
    parameters.extraQueryParameters = extraQueryParameters;
    parameters.claimsRequest = claimsRequest;
    parameters.authority = acquireTokenAuthority;
    parameters.correlationId = correlationId;
        
    [application acquireTokenWithParameters:parameters completionBlock:^(MSALResult *result, NSError *error)
     {
         MSIDAutomationTestResult *testResult = [self testResultWithMSALResult:result error:error];
         completionBlock(testResult);
     }];
}

@end
