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


#import "MSALAutomationExpireATAction.h"
#import <MSAL/MSAL.h>
#import "MSIDAutomationTestRequest.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDConfiguration.h"
#import "MSALAuthority_Internal.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccessToken.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDAutomationTestResult.h"
#import "MSIDAutomationActionConstants.h"
#import "MSIDAutomationActionManager.h"

@implementation MSALAutomationExpireATAction

+ (void)load
{
    [[MSIDAutomationActionManager sharedInstance] registerAction:[MSALAutomationExpireATAction new]];
}

- (NSString *)actionIdentifier
{
    return MSID_AUTO_EXPIRE_AT_ACTION_IDENTIFIER;
}

- (BOOL)needsRequestParameters
{
    return YES;
}

- (void)performActionWithParameters:(MSIDAutomationTestRequest *)testRequest
                containerController:(MSIDAutoViewController *)containerController
                    completionBlock:(MSIDAutoCompletionBlock)completionBlock
{
    NSString *authority = testRequest.cacheAuthority ?: testRequest.configurationAuthority;
    NSURL *authorityUrl = [NSURL URLWithString:authority];

    MSALAuthority *msalAuthority = [MSALAuthority authorityWithURL:authorityUrl error:nil];

    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:nil homeAccountId:testRequest.homeAccountIdentifier];

    MSIDConfiguration *configuration = [[MSIDConfiguration alloc] initWithAuthority:msalAuthority.msidAuthority
                                                                        redirectUri:nil
                                                                           clientId:testRequest.clientId
                                                                             target:testRequest.requestScopes];

    MSIDAccessToken *accessToken = [self.defaultAccessor getAccessTokenForAccount:account
                                                                    configuration:configuration
                                                                          context:nil
                                                                            error:nil];

    if (!accessToken)
    {
        MSIDAutomationTestResult *testResult = [[MSIDAutomationTestResult alloc] initWithAction:self.actionIdentifier success:NO additionalInfo:nil];
        completionBlock(testResult);
        return;
    }

    accessToken.expiresOn = [NSDate dateWithTimeIntervalSinceNow:-1.0];
    BOOL result = [self.accountCredentialCache saveCredential:accessToken.tokenCacheItem context:nil error:nil];

    MSIDAutomationTestResult *testResult = [[MSIDAutomationTestResult alloc] initWithAction:self.actionIdentifier success:result additionalInfo:nil];
    testResult.actionCount = 1;
    completionBlock(testResult);
}

@end
