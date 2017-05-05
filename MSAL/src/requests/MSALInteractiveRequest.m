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
#import "MSALOAuth2Constants.h"
#import "MSALUIBehavior_Internal.h"
#import "MSALWebUI.h"
#import "MSALTelemetryApiId.h"

#import "MSALPkce.h"

#import "MSALTelemetryAPIEvent.h"
#import "MSALTelemetry+Internal.h"
#import "MSALTelemetryEventStrings.h"

static MSALInteractiveRequest *s_currentRequest = nil;

@implementation MSALInteractiveRequest
{
    NSString *_code;
    MSALPkce *_pkce;
}

- (id)initWithParameters:(MSALRequestParameters *)parameters
    extraScopesToConsent:(NSArray<NSString *> *)extraScopesToConsent
                behavior:(MSALUIBehavior)behavior
                   error:(NSError * __autoreleasing *)error
{
    if (!(self = [super initWithParameters:parameters
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
    _pkce = [MSALPkce new];
    
    return self;
}

+ (MSALInteractiveRequest *)currentActiveRequest
{
    return s_currentRequest;
}

- (NSMutableDictionary<NSString *, NSString *> *)authorizationParameters
{
    NSMutableDictionary<NSString *, NSString *> *parameters = [NSMutableDictionary new];
    if (_parameters.extraQueryParameters)
    {
        [parameters addEntriesFromDictionary:_parameters.extraQueryParameters];
    }
    MSALScopes *allScopes = [self requestScopes:_extraScopesToConsent];
    parameters[OAUTH2_CLIENT_ID] = _parameters.clientId;
    parameters[OAUTH2_SCOPE] = [allScopes msalToString];
    parameters[OAUTH2_RESPONSE_TYPE] = OAUTH2_CODE;
    parameters[OAUTH2_REDIRECT_URI] = [_parameters.redirectUri absoluteString];
    parameters[OAUTH2_CORRELATION_ID_REQUEST] = [_parameters.correlationId UUIDString];
    parameters[OAUTH2_LOGIN_HINT] = _parameters.loginHint;

    // PKCE:
    parameters[OAUTH2_CODE_CHALLENGE] = _pkce.codeChallenge;
    parameters[OAUTH2_CODE_CHALLENGE_METHOD] = _pkce.codeChallengeMethod;
    
    NSDictionary *msalId = [MSALLogger msalId];
    [parameters addEntriesFromDictionary:msalId];
    [parameters addEntriesFromDictionary:MSALParametersForBehavior(_uiBehavior)];
    
    return parameters;
}

- (NSURL *)authorizationUrl
{
    NSURLComponents *urlComponents =
    [[NSURLComponents alloc] initWithURL:_authority.authorizationEndpoint
                 resolvingAgainstBaseURL:NO];
    
    // Query parameters can come through from the OIDC discovery on the authorization endpoint as well
    // and we need to retain them when constructing our authorization uri
    NSMutableDictionary <NSString *, NSString *> *parameters = [self authorizationParameters];
    if (urlComponents.percentEncodedQuery)
    {
        NSDictionary *authorizationQueryParams = [NSDictionary msalURLFormDecode:urlComponents.percentEncodedQuery];
        if (authorizationQueryParams)
        {
            [parameters addEntriesFromDictionary:authorizationQueryParams];
        }
    }
    
    if (_parameters.sliceParameters)
    {
        [parameters addEntriesFromDictionary:_parameters.sliceParameters];
    }
    
    MSALUser *user = _parameters.user;
    if (user)
    {
        parameters[OAUTH2_LOGIN_HINT] = user.displayableId;
        parameters[OAUTH2_LOGIN_REQ] = user.uid;
        parameters[OAUTH2_DOMAIN_REQ] = user.utid;
    }
    
    _state = [[NSUUID UUID] UUIDString];
    parameters[OAUTH2_STATE] = _state;
    
    urlComponents.percentEncodedQuery = [parameters msalURLFormEncode];
    
    return [urlComponents URL];
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
    NSURL *authorizationUrl = [self authorizationUrl];
    
    LOG_INFO(_parameters, @"Launching Web UI");
    LOG_INFO_PII(_parameters, @"Launching Web UI with URL: %@", authorizationUrl);
    s_currentRequest = self;
    
    [MSALWebUI startWebUIWithURL:authorizationUrl
                         context:_parameters
                 completionBlock:^(NSURL *response, NSError *error)
     {
         s_currentRequest = nil;
         if (error)
         {
             MSALTelemetryAPIEvent *event = [self getTelemetryAPIEvent];
             [self stopTelemetryEvent:event error:error];
             
             completionBlock(nil, error);
             return;
         }
         
         if ([NSString msalIsStringNilOrBlank:response.absoluteString])
         {
             // This error case *really* shouldn't occur. If we're seeing it it's almost certainly a developer bug
             ERROR_COMPLETION(_parameters, MSALErrorNoAuthorizationResponse, @"No authorization response received from server.");
         }
         
         NSDictionary *params = [NSDictionary msalURLFormDecode:response.query];
         CHECK_ERROR_COMPLETION(params, _parameters, MSALErrorBadAuthorizationResponse, @"Authorization response from the server code not be decoded.");
         
         CHECK_ERROR_COMPLETION([_state isEqualToString:params[OAUTH2_STATE]], _parameters, MSALErrorInvalidState, @"State returned from the server does not match");
         
         _code = params[OAUTH2_CODE];
         if (_code)
         {
             [super acquireToken:completionBlock];
             return;
         }
         
         NSString *authorizationError = params[OAUTH2_ERROR];
         if (authorizationError)
         {
             NSString *errorDescription = params[OAUTH2_ERROR_DESCRIPTION];
             NSString *subError = params[OAUTH2_SUB_ERROR];
             MSALErrorCode code = MSALErrorCodeForOAuthError(authorizationError, MSALErrorAuthorizationFailed);
             MSALLogError(_parameters, MSALErrorDomain, code, errorDescription, authorizationError, subError, __FUNCTION__, __LINE__);
             
             NSError *msalError = MSALCreateError(MSALErrorDomain, code, errorDescription, authorizationError, subError, nil);
                          
             MSALTelemetryAPIEvent *event = [self getTelemetryAPIEvent];
             [self stopTelemetryEvent:event error:msalError];
             
             completionBlock(nil, msalError);
             return;
         }
         
         ERROR_COMPLETION(_parameters, MSALErrorBadAuthorizationResponse, @"No code or error in server response.");
     }];

    
}

- (void)addAdditionalRequestParameters:(NSMutableDictionary<NSString *, NSString *> *)parameters
{
    parameters[OAUTH2_GRANT_TYPE] = OAUTH2_AUTHORIZATION_CODE;
    parameters[OAUTH2_CODE] = _code;
    parameters[OAUTH2_REDIRECT_URI] = [_parameters.redirectUri absoluteString];
    
    // PKCE
    parameters[OAUTH2_CODE_VERIFIER] = _pkce.codeVerifier;
}

- (MSALTelemetryAPIEvent *)getTelemetryAPIEvent
{
    MSALTelemetryAPIEvent *event = [super getTelemetryAPIEvent];
    [event setUIBehavior:_uiBehavior];
    return event;
}

@end
