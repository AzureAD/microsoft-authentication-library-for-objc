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

#import "MSALAutomationAcquireTokenSilentAction.h"
#import "MSIDAutomationTestRequest.h"
#import "MSALAuthority.h"
#import "MSALPublicClientApplication.h"
#import "MSIDAutomationActionConstants.h"
#import "MSIDAutomationActionManager.h"
#import "MSIDAutomationTestResult.h"
#import "MSIDAutomationErrorResult.h"
#import "MSALSilentTokenParameters.h"
#import "MSALError.h"
#import "MSALClaimsRequest.h"

@implementation MSALAutomationAcquireTokenSilentAction

+ (void)load
{
    [[MSIDAutomationActionManager sharedInstance] registerAction:[MSALAutomationAcquireTokenSilentAction new]];
}

- (NSString *)actionIdentifier
{
    return MSID_AUTO_ACQUIRE_TOKEN_SILENT_ACTION_IDENTIFIER;
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
    MSALPublicClientApplication *application = [self applicationWithParameters:testRequest error:nil];

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
        MSIDAutomationTestResult *result = nil;

        if (accountError)
        {
            result = [self testResultWithMSALError:accountError];
        }
        else
        {
            NSError *error = MSIDCreateError(MSALErrorDomain, MSALErrorInteractionRequired, @"no account", nil, nil, nil, nil, nil);

            result = [[MSIDAutomationErrorResult alloc] initWithAction:self.actionIdentifier
                                                                 error:error
                                                        additionalInfo:nil];
        }

        completionBlock(result);
        return;
    }

    NSOrderedSet *scopes = [NSOrderedSet msidOrderedSetFromString:testRequest.requestScopes];
    BOOL forceRefresh = testRequest.forceRefresh;
    NSUUID *correlationId = [NSUUID new];

    MSALAuthority *silentAuthority = nil;

    if (testRequest.acquireTokenAuthority)
    {
        // In case we want to pass a different authority to silent call, we can use "silent authority" parameter
        silentAuthority = [MSALAuthority authorityWithURL:[NSURL URLWithString:testRequest.acquireTokenAuthority] error:nil];
    }
    
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
    
    MSALSilentTokenParameters *parameters = [[MSALSilentTokenParameters alloc] initWithScopes:[scopes array] account:account];
    parameters.authority = silentAuthority;
    parameters.forceRefresh = forceRefresh;
    parameters.correlationId = correlationId;
    [application acquireTokenSilentWithParameters:parameters completionBlock:^(MSALResult *result, NSError *error)
     {
         MSIDAutomationTestResult *testResult = [self testResultWithMSALResult:result error:error];
         completionBlock(testResult);
     }];
}

@end
