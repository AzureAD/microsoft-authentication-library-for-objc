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

#import "MSALInteractiveRequest.h"

#import "MSALAuthority.h"
#import "MSALUIBehavior_Internal.h"
#import "MSALTelemetryApiId.h"
#import "MSIDPkce.h"
#import "MSALTelemetryAPIEvent.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDDeviceId.h"
#import "MSALAccount+Internal.h"
#import "MSALAccountId.h"
#import "MSIDWebviewAuthorization.h"
#import "MSIDWebAADAuthResponse.h"
#import "MSIDWebMSAuthResponse.h"

@implementation MSALInteractiveRequest
{
    MSIDWebviewConfiguration *_webviewConfig;
    
    NSString *_code;
}

- (id)initWithParameters:(MSALRequestParameters *)parameters
    extraScopesToConsent:(NSArray<NSString *> *)extraScopesToConsent
                behavior:(MSALUIBehavior)behavior
              tokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
                   error:(NSError * __autoreleasing *)error
{
    if (!(self = [super initWithParameters:parameters
                                tokenCache:tokenCache
                                     error:error]))
    {
        return nil;
    }
    
    if (extraScopesToConsent)
    {
        _extraScopesToConsent = [[NSOrderedSet alloc] initWithArray:extraScopesToConsent];
        if (![self validateScopeInput:_extraScopesToConsent error:error])
        {
            return nil;
        }
    }
    
    _uiBehavior = behavior;
    
    return self;
}


- (void)run:(MSALCompletionBlock)completionBlock
{
    [super run:^(MSALResult *result, NSError *error)
     {
         // Make sure that any response to an interactive request is returned on
         // the main thread.
         dispatch_async(dispatch_get_main_queue(), ^{
             completionBlock(result, error);
         });
     }];
}

- (void)acquireToken:(MSALCompletionBlock)completionBlock
{
    [super resolveEndpoints:^(MSALAuthority *authority, NSError *error) {
        if (error)
        {
            MSALTelemetryAPIEvent *event = [self getTelemetryAPIEvent];
            [self stopTelemetryEvent:event error:error];
            
            completionBlock(nil, error);
            return;
        }
        
        _authority = authority;
        [self acquireTokenImpl:completionBlock];
    }];
}


- (void)acquireTokenImpl:(MSALCompletionBlock)completionBlock
{
    
    MSIDWebviewConfiguration *config = [[MSIDWebviewConfiguration alloc] initWithAuthorizationEndpoint:_authority.authorizationEndpoint
                                                                                           redirectUri:_parameters.redirectUri
                                                                                              clientId:_parameters.clientId resource:nil
                                                                                                scopes:[self requestScopes:_extraScopesToConsent]
                                                                                         correlationId:_parameters.correlationId
                                                                                            enablePkce:YES];
    config.promptBehavior = MSALParameterStringForBehavior(_uiBehavior);
    config.loginHint = _parameters.loginHint;
    config.extraQueryParameters = _parameters.extraQueryParameters;

    _webviewConfig = config;
    
    void (^webAuthCompletion)(MSIDWebviewResponse *, NSError *) = ^void(MSIDWebviewResponse *response, NSError *error)
    {
        if ([response isKindOfClass:MSIDWebAADAuthResponse.class])
        {
            MSIDWebAADAuthResponse *oauthResponse = (MSIDWebAADAuthResponse *)response;
            
            if (oauthResponse.authorizationCode)
            {
                _code = oauthResponse.authorizationCode;
                _cloudAuthority = [NSURL URLWithString:((MSIDWebAADAuthResponse *)response).cloudHostName];
                
                [super acquireToken:completionBlock];
                return;
            }
            
            completionBlock(nil, oauthResponse.oauthError);
            return;
        }
        
        else if([response isKindOfClass:MSIDWebMSAuthResponse.class])
        {
            // Todo: Install broker prompt
        }
        
        completionBlock(nil, error);
    };
    
    switch (_parameters.webviewType) {
        
#if TARGET_OS_IPHONE
        case MSALWebviewTypeAuthenticationSession:
            [MSIDWebviewAuthorization startSystemWebviewAuthWithConfiguration:config
                                                                oauth2Factory:_parameters.msidOAuthFactory
                                                     useAuthenticationSession:YES
                                                    allowSafariViewController:NO
                                                                      context:_parameters
                                                            completionHandler:webAuthCompletion];
            break;

        case MSALWebviewTypeSafariViewController:
            [MSIDWebviewAuthorization startSystemWebviewAuthWithConfiguration:config
                                                                oauth2Factory:_parameters.msidOAuthFactory
                                                     useAuthenticationSession:NO
                                                    allowSafariViewController:YES
                                                                      context:_parameters
                                                            completionHandler:webAuthCompletion];
            break;
        case MSALWebviewTypeAutomatic:
            [MSIDWebviewAuthorization startSystemWebviewAuthWithConfiguration:config
                                                                oauth2Factory:_parameters.msidOAuthFactory
                                                     useAuthenticationSession:YES
                                                    allowSafariViewController:YES
                                                                      context:_parameters
                                                            completionHandler:webAuthCompletion];
            break;
#else
        case MSALWebviewTypeAutomatic:
#endif
        case MSALWebviewTypeWKWebView:
            [MSIDWebviewAuthorization startEmbeddedWebviewAuthWithConfiguration:config
                                                                  oauth2Factory:_parameters.msidOAuthFactory
                                                                        webview:_parameters.customWebview
                                                                        context:_parameters
                                                              completionHandler:webAuthCompletion];
            break;
    }
}

- (void)addAdditionalRequestParameters:(NSMutableDictionary<NSString *, NSString *> *)parameters
{
    parameters[MSID_OAUTH2_GRANT_TYPE] = MSID_OAUTH2_AUTHORIZATION_CODE;
    parameters[MSID_OAUTH2_CODE] = _code;
    parameters[MSID_OAUTH2_REDIRECT_URI] = _parameters.redirectUri;
    
    // PKCE
    parameters[MSID_OAUTH2_CODE_VERIFIER] = _webviewConfig.pkce.codeVerifier;
}

- (MSALTelemetryAPIEvent *)getTelemetryAPIEvent
{
    MSALTelemetryAPIEvent *event = [super getTelemetryAPIEvent];
    [event setUIBehavior:_uiBehavior];
    return event;
}

@end
