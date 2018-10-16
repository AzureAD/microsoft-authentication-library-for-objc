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

#import "MSALUIBehavior_Internal.h"
#import "MSALTelemetryApiId.h"
#import "MSIDPkce.h"
#import "MSALTelemetryAPIEvent.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDDeviceId.h"
#import "MSALAccount+Internal.h"
#import "MSALAccountId.h"
#import "MSALAuthority.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDAuthority.h"
#import "MSIDAADAuthorizationCodeGrantRequest.h"
#import "MSIDWebviewAuthorization.h"
#import "MSIDWebAADAuthResponse.h"
#import "MSIDWebMSAuthResponse.h"
#import "MSIDWebOpenBrowserResponse.h"
#import "MSALErrorConverter.h"

#if TARGET_OS_IPHONE
#import "MSIDAppExtensionUtil.h"
#endif

#import "MSALWebviewType_Internal.h"

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

    if (parameters.claims)
    {
        if (![self validateClaims:parameters error:error]) return nil;
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
    [super resolveEndpoints:^(BOOL resolved, NSError *error) {

        if (!resolved)
        {
            completionBlock(nil, error);
            return;
        }

        [_parameters.unvalidatedAuthority loadOpenIdMetadataWithContext:_parameters
                                                        completionBlock:^(MSIDOpenIdProviderMetadata *metadata, NSError *error)
         {
             if (error)
             {
                 MSALTelemetryAPIEvent *event = [self getTelemetryAPIEvent];
                 [self stopTelemetryEvent:event error:error];

                 completionBlock(nil, error);
                 return;
             }

             _authority = _parameters.unvalidatedAuthority;
             [self acquireTokenImpl:completionBlock];
         }];
    }];
}

- (void)acquireTokenImpl:(MSALCompletionBlock)completionBlock
{
    MSIDWebviewConfiguration *config = [[MSIDWebviewConfiguration alloc] initWithAuthorizationEndpoint:_authority.metadata.authorizationEndpoint
                                                                                           redirectUri:_parameters.redirectUri
                                                                                              clientId:_parameters.clientId
                                                                                              resource:nil
                                                                                                scopes:[self requestScopes:_extraScopesToConsent]
                                                                                         correlationId:_parameters.correlationId
                                                                                            enablePkce:YES];
    config.promptBehavior = MSALParameterStringForBehavior(_uiBehavior);
    config.loginHint = _parameters.account ? _parameters.account.username : _parameters.loginHint;
    config.uid = _parameters.account.homeAccountId.objectId;
    config.utid = _parameters.account.homeAccountId.tenantId;
    config.extraQueryParameters = _parameters.extraQueryParameters;
    config.claims = _parameters.claims;
    config.sliceParameters = _parameters.sliceParameters;

    _webviewConfig = config;
    
    void (^webAuthCompletion)(MSIDWebviewResponse *, NSError *) = ^void(MSIDWebviewResponse *response, NSError *error)
    {
        if (error)
        {
            [self stopTelemetryEvent:[self getTelemetryAPIEvent] error:error];
            completionBlock(nil, error);
            return;
        }

        if ([response isKindOfClass:MSIDWebOAuth2Response.class])
        {
            MSIDWebOAuth2Response *oauthResponse = (MSIDWebOAuth2Response *)response;
            
            if (oauthResponse.authorizationCode)
            {
                _code = oauthResponse.authorizationCode;

                // handle instance aware flow (cloud host)
                if ([response isKindOfClass:MSIDWebAADAuthResponse.class])
                {
                    MSIDWebAADAuthResponse *aadResponse = (MSIDWebAADAuthResponse *)response;
                    [_parameters setCloudAuthorityWithCloudHostName:aadResponse.cloudHostName];
                }

                [super acquireToken:completionBlock];
                return;
            }
            

            [self stopTelemetryEvent:[self getTelemetryAPIEvent] error:oauthResponse.oauthError];
            completionBlock(nil, oauthResponse.oauthError);
            return;
        }
        
        else if ([response isKindOfClass:MSIDWebMSAuthResponse.class])
        {
            // Todo: Install broker prompt
        }
        
        else if ([response isKindOfClass:MSIDWebOpenBrowserResponse.class])
        {
            NSURL *browserURL = ((MSIDWebOpenBrowserResponse *)response).browserURL;
            
#if TARGET_OS_IPHONE
            if (![MSIDAppExtensionUtil isExecutingInAppExtension])
            {
                MSID_LOG_INFO(nil, @"Opening a browser");
                MSID_LOG_INFO_PII(nil, @"Opening a browser - %@", browserURL);
                [MSIDAppExtensionUtil sharedApplicationOpenURL:browserURL];
            }
            else
            {
                NSError *error = CREATE_MSAL_LOG_ERROR(nil, MSALErrorAttemptToOpenURLFromExtension, @"unable to redirect to browser from extension");
                [self stopTelemetryEvent:[self getTelemetryAPIEvent] error:error];
                completionBlock(nil, error);
                return;
            }
#else
            [[NSWorkspace sharedWorkspace] openURL:browserURL];
#endif
            NSError *error = CREATE_MSAL_LOG_ERROR(nil, MSALErrorSessionCanceled, @"Authorization session was cancelled programatically.");
            [self stopTelemetryEvent:[self getTelemetryAPIEvent] error:error];
            completionBlock(nil, error);
            return;
        }
    };

#if TARGET_OS_IPHONE
    BOOL useAuthenticationSession;
    BOOL allowSafariViewController;

    switch (_parameters.webviewType) {

        case MSALWebviewTypeAuthenticationSession:
            useAuthenticationSession = YES;
            allowSafariViewController = NO;
            break;

        case MSALWebviewTypeSafariViewController:
            useAuthenticationSession = NO;
            allowSafariViewController = YES;
            break;
        case MSALWebviewTypeDefault:
            useAuthenticationSession = YES;
            allowSafariViewController = YES;
            break;
        case MSALWebviewTypeWKWebView:
        {
            [MSIDWebviewAuthorization startEmbeddedWebviewAuthWithConfiguration:config
                                                                  oauth2Factory:_parameters.msidOAuthFactory
                                                                        webview:_parameters.customWebview
                                                                        context:_parameters
                                                              completionHandler:webAuthCompletion];
            return;
        }
    }
    [MSIDWebviewAuthorization startSystemWebviewAuthWithConfiguration:config
                                                        oauth2Factory:_parameters.msidOAuthFactory
                                             useAuthenticationSession:useAuthenticationSession
                                            allowSafariViewController:allowSafariViewController
                                                              context:_parameters
                                                    completionHandler:webAuthCompletion];
#else
    [MSIDWebviewAuthorization startEmbeddedWebviewAuthWithConfiguration:config
                                                          oauth2Factory:_parameters.msidOAuthFactory
                                                                webview:_parameters.customWebview
                                                                context:_parameters
                                                      completionHandler:webAuthCompletion];
#endif
}

- (MSIDTokenRequest *)tokenRequest
{
    return [[MSIDAADAuthorizationCodeGrantRequest alloc] initWithEndpoint:[self tokenEndpoint]
                                                                 clientId:_parameters.clientId
                                                                    scope:[[self requestScopes:nil] msidToString]
                                                              redirectUri:_parameters.redirectUri
                                                                     code:_code
                                                             codeVerifier:_webviewConfig.pkce.codeVerifier
                                                                  context:_parameters];
}

- (MSALTelemetryAPIEvent *)getTelemetryAPIEvent
{
    MSALTelemetryAPIEvent *event = [super getTelemetryAPIEvent];
    [event setUIBehavior:_uiBehavior];
    [event setWebviewType:MSALStringForMSALWebviewType(_parameters.webviewType)];
    return event;
}

- (BOOL)validateClaims:(MSALRequestParameters *)parameters
                 error:(NSError * __nullable __autoreleasing * __nullable)error

{
    if (!parameters.claims)
    {
        return YES;
    }
    
    if (parameters.extraQueryParameters[MSID_OAUTH2_CLAIMS])
    {
        MSAL_ERROR_PARAM(_parameters, MSALErrorInvalidParameter, @"Duplicate claims parameter is found in extraQueryParameters. Please remove it.");
        return NO;
    }
    
    return YES;
}

@end
