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

#import "MSALAutomationBaseAction.h"
#import <MSAL/MSAL.h>
#import "MSALAutomationConstants.h"
#import "MSALAuthorityFactory.h"

@implementation MSALAutomationBaseAction

- (MSALPublicClientApplication *)applicationWithParameters:(NSDictionary *)parameters
                                                     error:(NSError **)error
{
    BOOL validateAuthority = parameters[MSAL_VALIDATE_AUTHORITY_PARAM] ? [parameters[MSAL_VALIDATE_AUTHORITY_PARAM] boolValue] : YES;

    MSALAuthority *authority = nil;

    if (parameters[MSAL_AUTHORITY_PARAM])
    {
        __auto_type authorityUrl = [[NSURL alloc] initWithString:parameters[MSAL_AUTHORITY_PARAM]];
        authority = [MSALAuthorityFactory authorityFromUrl:authorityUrl context:nil error:nil];
    }

    MSALPublicClientApplication *clientApplication =
    [[MSALPublicClientApplication alloc] initWithClientId:parameters[MSAL_CLIENT_ID_PARAM]
                                                authority:authority
                                              redirectUri:parameters[MSAL_REDIRECT_URI_PARAM]
                                                    error:error];

    clientApplication.validateAuthority = validateAuthority;
    clientApplication.sliceParameters = parameters[MSAL_SLICE_PARAMS];

    return clientApplication;
}

- (MSALAccount *)accountWithParameters:(NSDictionary *)parameters
                           application:(MSALPublicClientApplication *)application
                                 error:(NSError **)error
{
    NSString *accountIdentifier = parameters[MSAL_ACCOUNT_IDENTIFIER_PARAM];

    if (accountIdentifier)
    {
        return [application accountForHomeAccountId:accountIdentifier error:error];
    }
    else if (parameters[MSAL_LEGACY_USER_PARAM])
    {
        return [application accountForUsername:parameters[MSAL_LEGACY_USER_PARAM] error:error];
    }

    return nil;
}

- (MSIDAutomationTestResult *)testResultWithMSALError:(NSError *)error
{
    // TODO
    return nil;
}

- (MSIDAutomationTestResult *)testResultWithMSALResult:(MSALResult *)msalResult error:(NSError *)error
{
    // TODO
    return nil;
}

@end
