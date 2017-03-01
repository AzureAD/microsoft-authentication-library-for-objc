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

#import "MSALBaseRequest.h"

#import "MSALAuthority.h"
#import "MSALHttpResponse.h"
#import "MSALResult+Internal.h"
#import "MSALTokenResponse.h"
#import "MSALUser.h"
#import "MSALWebAuthRequest.h"


static MSALScopes *s_reservedScopes = nil;

@implementation MSALBaseRequest

+ (void)initialize
{
    s_reservedScopes = [NSOrderedSet orderedSetWithArray:@[@"openid", @"profile", @"offline_access"]];
}

- (id)initWithParameters:(MSALRequestParameters *)parameters
                   error:(NSError * __nullable __autoreleasing * __nullable)error
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    // There's no reason why this should ever be nil.
    THROW_ON_NIL_ARGUMENT(parameters);
    _parameters = parameters;
    
    if (!parameters.scopes || parameters.scopes.count == 0)
    {
        REQUIRED_PARAMETER_ERROR(scopes, _parameters);
        return nil;
    }
    
    if (![self validateScopeInput:parameters.scopes
                            error:error])
    {
        return nil;
    }
    
    return self;
}

- (BOOL)validateScopeInput:(MSALScopes *)scopes
                     error:(NSError * __nullable __autoreleasing * __nullable)error

{
    if (!scopes)
    {
        return YES;
    }
    
    if ([scopes intersectsOrderedSet:s_reservedScopes])
    {
        MSAL_ERROR_PARAM(_parameters, MSALErrorInvalidParameter, @"%@ are reserved scopes and may not be specified in the acquire token call.", s_reservedScopes);
        return NO;
    }
    
    if (scopes.count > 1 && [scopes containsObject:_parameters.clientId])
    {
        MSAL_ERROR_PARAM(_parameters, MSALErrorInvalidParameter, @"clientId may only be provided as a singular scope on a acquireToken call.");
        return NO;
    }
    
    return YES;
}

- (MSALScopes *)requestScopes:(MSALScopes *)extraScopes
{
    NSMutableOrderedSet *requestScopes = [_parameters.scopes mutableCopy];
    if (extraScopes)
    {
        [requestScopes unionOrderedSet:extraScopes];
    }
    [requestScopes unionOrderedSet:s_reservedScopes];
    [requestScopes removeObject:_parameters.clientId];
    return requestScopes;
}

- (void)run:(MSALCompletionBlock)completionBlock
{
    NSString *upn = nil;
    if (_parameters.user)
    {
        upn = _parameters.user.upn;
    }
    else if(_parameters.loginHint)
    {
        upn = _parameters.loginHint;
    }
    
    [MSALAuthority resolveEndpointsForAuthority:_parameters.unvalidatedAuthority
                              userPrincipalName:upn
                                       validate:_parameters.validateAuthority
                                        context:_parameters
                                completionBlock:^(MSALAuthority *authority, NSError *error)
     {
        if (error)
        {
            completionBlock(nil, error);
            return;
        }
        
        _authority = authority;
        [self acquireToken:completionBlock];
    }];
}

- (void)acquireToken:(nonnull MSALCompletionBlock)completionBlock
{
    NSMutableDictionary<NSString *, NSString *> *reqParameters = [NSMutableDictionary new];
    
    MSALWebAuthRequest *authRequest = [[MSALWebAuthRequest alloc] initWithURL:_authority.tokenEndpoint
                                                                      context:_parameters];
    
    reqParameters[OAUTH2_CLIENT_ID] = _parameters.clientId;
    reqParameters[OAUTH2_SCOPE] = [[self requestScopes:nil] msalToString];
    [self addAdditionalRequestParameters:reqParameters];
    authRequest.bodyParameters = reqParameters;
    
    [authRequest sendPost:^(MSALHttpResponse *response, NSError *error)
     {
         if (error)
         {
             completionBlock(nil, error);
             return;
         }
         
         MSALTokenResponse *tokenResponse =
         [[MSALTokenResponse alloc] initWithData:response.body
                                           error:&error];
         if (!tokenResponse)
         {
             completionBlock(nil, error);
             return;
         }
         
         NSString *oauthError = tokenResponse.error;
         if (oauthError)
         {
             MSALErrorCode code = MSALErrorCodeForOAuthError(oauthError, MSALErrorInteractionRequired);
             completionBlock(nil, MSALCreateAndLogError(_parameters, code, oauthError, tokenResponse.subError, nil, __FUNCTION__, __LINE__, @"%@", tokenResponse.errorDescription));
             return;
         }
         
         if ([NSString msalIsStringNilOrBlank:tokenResponse.scope])
         {
             LOG_INFO(_parameters, @"No scope in server response, using passed in scope instead.");
             LOG_INFO_PII(_parameters, @"No scope in server response, using passed in scope instead.");
             tokenResponse.scope = _parameters.scopes.msalToString;
         }
         
         // For silent flow, with grant type being OAUTH2_REFRESH_TOKEN, this value may be missing from the response.
         // In this case, we simply return the refresh token in the request.
         if ([reqParameters[OAUTH2_GRANT_TYPE] isEqualToString:OAUTH2_REFRESH_TOKEN])
         {
             if (!tokenResponse.refreshToken)
             {
                 tokenResponse.refreshToken = reqParameters[OAUTH2_REFRESH_TOKEN];
                 LOG_WARN(_parameters, @"Refresh token was missing from the token refresh response, so the refresh token in the request is returned instead");
                 LOG_WARN_PII(_parameters, @"Refresh token was missing from the token refresh response, so the refresh token in the request is returned instead");
             }
         }
         
         MSALResult *result =
         [MSALResult resultWithAccessToken:tokenResponse.accessToken
                                 expiresOn:tokenResponse.expiresOn
                                  tenantId:nil // TODO: tenantId
                                      user:nil // TODO: user
                                    scopes:[tokenResponse.scope componentsSeparatedByString:@","]];
         completionBlock(result, nil);
     }];
}

- (void)addAdditionalRequestParameters:(NSMutableDictionary<NSString *, NSString *> *)parameters
{
    (void)parameters;
}

@end
