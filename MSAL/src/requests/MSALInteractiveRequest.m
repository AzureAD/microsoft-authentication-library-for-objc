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

@implementation MSALInteractiveRequest
{
    NSString *_code;
}

- (id)initWithParameters:(MSALRequestParameters *)parameters
        additionalScopes:(NSArray<NSString *> *)additionalScopes
                behavior:(MSALUIBehavior)behavior
                   error:(NSError * __autoreleasing *)error
{
    if (!(self = [super initWithParameters:parameters
                                     error:error]))
    {
        return nil;
    }
    
    if (additionalScopes)
    {
        _additionalScopes = [[NSOrderedSet alloc] initWithArray:additionalScopes];
        if (![self validateScopeInput:_additionalScopes error:error])
        {
            return nil;
        }
    }
    
    _uiBehavior = behavior;
    
    return self;
}

- (NSMutableDictionary<NSString *, NSString *> *)authorizationParameters
{
    NSMutableDictionary<NSString *, NSString *> *parameters = [NSMutableDictionary new];
    if (_parameters.extraQueryParameters)
    {
        [parameters addEntriesFromDictionary:_parameters.extraQueryParameters];
    }
    MSALScopes *allScopes = [self requestScopes:_additionalScopes];
    parameters[OAUTH2_SCOPE] = [allScopes msalToString];
    parameters[OAUTH2_RESPONSE_TYPE] = OAUTH2_CODE;
    parameters[OAUTH2_REDIRECT_URI] = [_parameters.redirectUri absoluteString];
    parameters[OAUTH2_CORRELATION_ID_REQUEST] = [_parameters.correlationId UUIDString];
    
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
    
    NSMutableDictionary <NSString *, NSString *> *parameters = [self authorizationParameters];
    
    _state = [[NSUUID UUID] UUIDString];
    parameters[OAUTH2_STATE] = _state;
    
    urlComponents.percentEncodedQuery = [parameters msalURLFormEncode];
    
    return [urlComponents URL];
}

- (void)acquireToken:(MSALCompletionBlock)completionBlock
{
    NSURL *authorizationUrl = [self authorizationUrl];
    
    [MSALWebUI startWebUIWithURL:authorizationUrl
                         context:_parameters
                 completionBlock:^(NSURL *response, NSError *error)
     {
         if (error)
         {
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
             MSALLogError(_parameters, code, errorDescription, authorizationError, subError, __FUNCTION__, __LINE__);
             completionBlock(nil, MSALCreateError(code, errorDescription, authorizationError, subError, nil));
             return;
         }
         
         ERROR_COMPLETION(_parameters, MSALErrorBadAuthorizationResponse, @"No code or error in server response.");
     }];
    
    
}

- (void)addAdditionalRequestParameters:(NSMutableDictionary<NSString *, NSString *> *)parameters
{
    parameters[OAUTH2_GRANT_TYPE] = OAUTH2_CODE;
    parameters[OAUTH2_CODE] = _code;
    parameters[OAUTH2_REDIRECT_URI] = [_parameters.redirectUri absoluteString];
}

@end
