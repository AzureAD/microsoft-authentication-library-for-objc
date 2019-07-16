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

#import "MSALAutomationReadAccountsAction.h"
#import <MSAL/MSAL.h>
#import "MSIDAutomationTestResult.h"
#import "MSIDAutomationTestRequest.h"
#import "MSALUser+Automation.h"
#import "MSIDAutomationActionConstants.h"
#import "MSIDAutomationActionManager.h"
#import "MSIDAutomationAccountsResult.h"
#import "MSALAccount+Internal.h"
#import "MSALTenantProfile.h"

@implementation MSALAutomationReadAccountsAction

+ (void)load
{
    [[MSIDAutomationActionManager sharedInstance] registerAction:[MSALAutomationReadAccountsAction new]];
}

- (NSString *)actionIdentifier
{
    return MSID_AUTO_READ_ACCOUNTS_ACTION_IDENTIFIER;
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

    NSError *error = nil;
    NSArray *accounts = [application allAccounts:nil];

    if (error)
    {
        MSIDAutomationTestResult *result = [self testResultWithMSALError:error];
        completionBlock(result);
        return;
    }

    NSMutableArray *items = [NSMutableArray array];

    for (MSALAccount *account in accounts)
    {
        MSIDAutomationUserInformation *userInfo = [MSIDAutomationUserInformation new];
        userInfo.username = account.username;
        userInfo.homeAccountId = account.homeAccountId.identifier;
        userInfo.localAccountId = account.tenantProfiles[0].identifier;
        userInfo.homeObjectId = account.homeAccountId.objectId;
        userInfo.homeTenantId = account.homeAccountId.tenantId;
        userInfo.environment = account.environment;
        userInfo.objectId = account.tenantProfiles[0].claims[@"oid"];
        userInfo.tenantId = account.tenantProfiles[0].tenantId;
        [items addObject:userInfo];
    }

    MSIDAutomationAccountsResult *result = [[MSIDAutomationAccountsResult alloc] initWithAction:self.actionIdentifier accounts:items additionalInfo:nil];
    completionBlock(result);
}

@end
