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

#import "MSIDInteractiveRequestParameters+MSALRequest.h"
#import "MSALWebviewParameters.h"
#import "MSALAccount+Internal.h"
#import "MSALGlobalConfig.h"
#import "MSALWebviewType_Internal.h"

@implementation MSIDInteractiveRequestParameters (MSALRequest)

- (BOOL)fillWithWebViewParameters:(MSALWebviewParameters *)webParameters
   useWebviewTypeFromGlobalConfig:(BOOL)useWebviewTypeFromGlobalConfig
                    customWebView:(WKWebView *)customWebView
                            error:(NSError **)error
{
    __typeof__(webParameters.parentViewController) parentViewController = webParameters.parentViewController;
    
#if TARGET_OS_IPHONE
    if (parentViewController == nil)
    {
        NSError *msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"parentViewController is a required parameter on iOS.", nil, nil, nil, nil, nil, YES);
        if (error) *error = msidError;
        return NO;
    }
    
    if (parentViewController.view.window == nil)
    {
        NSError *msidError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"parentViewController has no window! Provide a valid controller with view and window.", nil, nil, nil, nil, nil, YES);
        if (error) *error = msidError;
        return NO;
    }
    
    self.presentationType = webParameters.presentationStyle;
#endif
        
    self.parentViewController = parentViewController;
        
    if (@available(macOS 10.15, *))
    {
        self.prefersEphemeralWebBrowserSession = webParameters.prefersEphemeralWebBrowserSession;
    }
        
        // Configure webview
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    MSALWebviewType webviewType = useWebviewTypeFromGlobalConfig ? MSALGlobalConfig.defaultWebviewType : webParameters.webviewType;
#pragma clang diagnostic pop
        
    NSError *msidWebviewError = nil;
    MSIDWebviewType msidWebViewType = MSIDWebviewTypeFromMSALType(webviewType, &msidWebviewError);
        
    if (msidWebviewError)
    {
        if (error) *error = msidWebviewError;
        return NO;
    }
        
    self.webviewType = msidWebViewType;
    self.telemetryWebviewType = MSALStringForMSALWebviewType(webviewType);
    self.customWebview = webParameters.customWebview ?: customWebView;
    return YES;
}

- (void)setAccountIdentifierFromMSALAccount:(MSALAccount *)account
{
    self.accountIdentifier = account.lookupAccountIdentifier;
}

@end
