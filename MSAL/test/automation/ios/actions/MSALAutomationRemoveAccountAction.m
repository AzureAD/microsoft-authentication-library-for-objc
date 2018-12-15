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

#import "MSALAutomationRemoveAccountAction.h"
#import "MSIDAutomationTestRequest.h"
#import "MSIDAutomationTestResult.h"
#import <MSAL/MSAL.h>
#import "MSIDAutomationActionConstants.h"
#import "MSIDAutomationActionManager.h"

@implementation MSALAutomationRemoveAccountAction

+ (void)load
{
    [[MSIDAutomationActionManager sharedInstance] registerAction:[MSALAutomationRemoveAccountAction new]];
}

- (NSString *)actionIdentifier
{
    return MSID_AUTO_REMOVE_ACCOUNT_ACTION_IDENTIFIER;
}

- (BOOL)needsRequestParameters
{
    return YES;
}

- (void)performActionWithParameters:(MSIDAutomationTestRequest *)testRequest
                containerController:(MSIDAutoViewController *)containerController
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

    if (!account)
    {
        MSIDAutomationTestResult *result = [self testResultWithMSALError:accountError];
        completionBlock(result);
        return;
    }

    NSError *removeError = nil;
    BOOL removeResult = [application removeAccount:account error:&removeError];

    if (!removeResult)
    {
        MSIDAutomationTestResult *result = [self testResultWithMSALError:removeError];
        completionBlock(result);
        return;
    }

    MSIDAutomationTestResult *result = [[MSIDAutomationTestResult alloc] initWithAction:self.actionIdentifier success:YES additionalInfo:nil];
    completionBlock(result);
}

@end
