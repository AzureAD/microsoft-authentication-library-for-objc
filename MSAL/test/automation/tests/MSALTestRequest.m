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

#import "MSALTestRequest.h"

NSString *const MSAL_TEST_DEFAULT_NON_CONVERGED_REDIRECT_URI = @"x-msauth-msalautomationapp://com.microsoft.msal.automationapp";

@implementation MSALTestRequest

+ (MSALTestRequest *)convergedAppRequest
{
    MSALTestRequest *request = [MSALTestRequest new];

    if (request)
    {
        request.clientId = @"b6c69a37-df96-4db0-9088-2ab96e1d8215";
        request.redirectUri = @"msalb6c69a37-df96-4db0-9088-2ab96e1d8215://auth";
        request.validateAuthority = YES;
        request.webViewType = MSALWebviewTypeDefault;
    }

    return request;
}

+ (MSALTestRequest *)nonConvergedAppRequest
{
    MSALTestRequest *request = [MSALTestRequest new];

    if (request)
    {
        request.validateAuthority = YES;
        request.webViewType = MSALWebviewTypeDefault;
        request.redirectUri = MSAL_TEST_DEFAULT_NON_CONVERGED_REDIRECT_URI;
    }

    return request;
}

+ (MSALTestRequest *)b2CRequestWithSigninPolicyWithAccount:(MSIDTestAccount *)account
{
    MSALTestRequest *request = [MSALTestRequest new];

    if (request)
    {
        request.validateAuthority = YES;
        request.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/tfp/%@/B2C_1_Signin", account.tenantName];
        request.webViewType = MSALWebviewTypeDefault;
    }

    return request;
}

+ (MSALTestRequest *)b2CRequestWithProfilePolicyWithAccount:(MSIDTestAccount *)account
{
    MSALTestRequest *request = [MSALTestRequest new];

    if (request)
    {
        request.validateAuthority = YES;
        request.authority = [NSString stringWithFormat:@"https://login.microsoftonline.com/tfp/%@/B2C_1_Profile", account.tenantName];
        request.webViewType = MSALWebviewTypeDefault;
    }

    return request;
}

+ (MSALTestRequest *)fociRequestWithOfficeApp
{
    MSALTestRequest *request = [MSALTestRequest new];

    if (request)
    {
        request.validateAuthority = YES;
        request.webViewType = MSALWebviewTypeDefault;
        request.clientId = @"d3590ed6-52b3-4102-aeff-aad2292ab01c";
        request.redirectUri = @"urn:ietf:wg:oauth:2.0:oob";
    }

    return request;
}

 + (MSALTestRequest *)fociRequestWithOnedriveApp
{
    MSALTestRequest *request = [MSALTestRequest new];

    if (request)
    {
        request.validateAuthority = YES;
        request.webViewType = MSALWebviewTypeDefault;
        request.clientId = @"af124e86-4e96-495a-b70a-90f90ab96707";
        request.redirectUri = @"ms-onedrive://com.microsoft.skydrive";
    }

    return request;
}

- (BOOL)usesEmbeddedWebView
{
    return self.webViewType == MSALWebviewTypeWKWebView || self.usePassedWebView;
}

@end
