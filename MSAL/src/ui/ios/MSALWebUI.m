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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <SafariServices/SafariServices.h>

#import "MSALWebUI.h"
#import "UIApplication+MSALExtensions.h"
#import "MSALTelemetry.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryUIEvent.h"
#import "MSIDTelemetryEventStrings.h"

static MSALWebUI *s_currentWebSession = nil;

@interface MSALWebUI () <SFSafariViewControllerDelegate>

@end

@implementation MSALWebUI
{
    NSURL *_url;
    SFSafariViewController *_safariViewController;
#ifdef __IPHONE_11_0
    id _authSession;
#endif
    MSALWebUICompletionBlock _completionBlock;
    id<MSALRequestContext> _context;
    NSString *_telemetryRequestId;
    MSIDTelemetryUIEvent *_telemetryEvent;
}

+ (void)startWebUIWithURL:(NSURL *)url
                  context:(id<MSALRequestContext>)context
           callbackScheme:(NSString *)callbackScheme
          completionBlock:(MSALWebUICompletionBlock)completionBlock
{
    CHECK_ERROR_COMPLETION(url, context, MSALErrorInternal, @"Attempted to start WebUI with nil URL");
    
    MSALWebUI *webUI = [MSALWebUI new];
    webUI->_context = context;
    [webUI startWithURL:url callbackScheme:callbackScheme completionBlock:completionBlock];
}

+ (MSALWebUI *)getAndClearCurrentWebSession
{
    MSALWebUI *webSession = nil;
    @synchronized ([MSALWebUI class])
    {
        webSession = s_currentWebSession;
        s_currentWebSession = nil;
    }
    
    return webSession;
}

+ (BOOL)cancelCurrentWebAuthSession
{
    MSALWebUI *webSession = [MSALWebUI getAndClearCurrentWebSession];
    if (!webSession)
    {
        return NO;
    }
    [webSession cancel];
    return YES;
}

- (BOOL)clearCurrentWebSession
{
    @synchronized ([MSALWebUI class])
    {
        if (s_currentWebSession != self)
        {
            // There's no error param because this isn't on a critical path. If we're seeing this error there is
            // a developer error somewhere in the code, but that won't necessarily prevent MSAL from otherwise
            // working.
            MSID_LOG_ERROR(_context, @"Trying to clear out someone else's session");
            return NO;
        }
        
        s_currentWebSession = nil;
        return YES;
    }
}

- (void)cancel
{
    [_telemetryEvent setIsCancelled:YES];
    [self completeSessionWithResponse:nil orError:CREATE_MSID_LOG_ERROR(_context, MSALErrorSessionCanceled, @"Authorization session was cancelled programatically")];
}

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller
{
    (void)controller;
    if (![self clearCurrentWebSession])
    {
        return;
    }
    
    [_telemetryEvent setIsCancelled:YES];
    [self completeSessionWithResponse:nil orError:CREATE_MSID_LOG_ERROR(_context, MSALErrorUserCanceled, @"User cancelled the authorization session.")];
}

- (void)startWithURL:(NSURL *)url
      callbackScheme:(NSString *)callbackScheme
     completionBlock:(MSALWebUICompletionBlock)completionBlock
{
    @synchronized ([MSALWebUI class])
    {
        CHECK_ERROR_COMPLETION((!s_currentWebSession), _context, MSALErrorInteractiveSessionAlreadyRunning, @"Only one interactive session is allowed at a time.");
        s_currentWebSession = self;
    }
    
    _telemetryRequestId = [_context telemetryRequestId];
    
    [[MSIDTelemetry sharedInstance] startEvent:_telemetryRequestId eventName:MSID_TELEMETRY_EVENT_UI_EVENT];
    _telemetryEvent = [[MSIDTelemetryUIEvent alloc] initWithName:MSID_TELEMETRY_EVENT_UI_EVENT
                                                       context:_context];
    
    [_telemetryEvent setIsCancelled:NO];
    
    dispatch_async(dispatch_get_main_queue(), ^{
#ifdef __IPHONE_11_0
        if (@available(iOS 11.0, *)) {
            _authSession =
            [[SFAuthenticationSession alloc] initWithURL:url
                                       callbackURLScheme:callbackScheme
                                       completionHandler:^(NSURL * _Nullable callbackURL, NSError * _Nullable error)
             {
                 [MSALWebUI getAndClearCurrentWebSession];
                 
                 if (error)
                 {
                     LOG_ERROR(_context, @"SFAuthenticationSession failed: %@", error);
                     LOG_ERROR_PII(_context, @"SFAuthenticationSession failed: %@", error);
                     completionBlock(nil, error);
                     return;
                 }
                 
                 completionBlock(callbackURL, nil);
             }];
            
            if (![(SFAuthenticationSession *)_authSession start])
            {
                [self clearCurrentWebSession];
                ERROR_COMPLETION(_context, MSALErrorInternal, @"Unable to start SFAuthenticationSession");
            }
            
            return;
        }
#else
        (void)callbackScheme;
#endif
        _safariViewController = [[SFSafariViewController alloc] initWithURL:url
                                  entersReaderIfAvailable:NO];
        _safariViewController.delegate = self;
        UIViewController *viewController = [UIApplication msalCurrentViewController];
        if (!viewController)
        {
            [self clearCurrentWebSession];
            ERROR_COMPLETION(_context, MSALErrorNoViewController, @"MSAL was unable to find the current view controller.");
        }
        
        [viewController presentViewController:_safariViewController animated:YES completion:nil];
        
        @synchronized (self)
        {
            _completionBlock = completionBlock;
        }
    });
}

+ (BOOL)handleResponse:(NSURL *)url
{
    if (!url)
    {
        MSID_LOG_ERROR(nil, @"nil passed into MSAL Web handle response");
        return NO;
    }
    
    MSALWebUI *webSession = [MSALWebUI getAndClearCurrentWebSession];
    if (!webSession)
    {
        MSID_LOG_ERROR(nil, @"Received MSAL web response without a current session running.");
        return NO;
    }
    
    return [webSession completeSessionWithResponse:url orError:nil];
}

- (void)cancelUI
{
#ifdef __IPHONE_11_0
    if (_authSession)
    {
        [_authSession cancel];
        
        _authSession = nil;
        return;
    }
#endif
    
    [_safariViewController dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)completeSessionWithResponse:(NSURL *)response
                            orError:(NSError *)error
{
    if ([NSThread isMainThread])
    {
        [self cancelUI];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self cancelUI];
        });
    }
    
    MSALWebUICompletionBlock completionBlock = nil;
    @synchronized (self)
    {
        completionBlock = _completionBlock;
        _completionBlock = nil;
    }
    
    _safariViewController = nil;
    
    if (!completionBlock)
    {
        MSID_LOG_ERROR(_context, @"MSAL response received but no completion block saved");
        return NO;
    }
    
    [[MSIDTelemetry sharedInstance] stopEvent:_telemetryRequestId event:_telemetryEvent];
    
    completionBlock(response, error);
    return YES;
}

@end
