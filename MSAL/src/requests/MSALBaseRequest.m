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
#import "MSALResult+Internal.h"
#import "MSALAccount.h"
#import "MSIDAADAuthorizationCodeGrantRequest.h"
#import "MSIDAADRefreshTokenGrantRequest.h"
#import "MSALInteractiveRequest.h"
#import "MSALTelemetryAPIEvent.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSALTelemetryApiId.h"
#import "MSIDClientInfo.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccessToken.h"
#import "MSALResult+Internal.h"
#import "MSIDAADV2TokenResponse.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "NSData+MSIDExtensions.h"
#import "MSALErrorConverter.h"
#import "MSALAccountId.h"
#import "MSALAuthority.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDAADNetworkConfiguration.h"

static MSALScopes *s_reservedScopes = nil;

@interface MSALBaseRequest()

@property (nullable, nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;
@property (nullable, nonatomic) MSIDOauth2Factory *oauth2Factory;

@end

@implementation MSALBaseRequest

+ (void)initialize
{
    s_reservedScopes = [NSOrderedSet orderedSetWithArray:@[@"openid", @"profile", @"offline_access"]];
}

- (id)initWithParameters:(MSALRequestParameters *)parameters
              tokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
                   error:(NSError * __nullable __autoreleasing * __nullable)error
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    // There's no reason why this should ever be nil.
    THROW_ON_NIL_ARGUMENT(parameters);
    _parameters = parameters;
    _apiId = parameters.apiId;
    
    if ([NSString msidIsStringNilOrBlank:_parameters.telemetryRequestId])
    {
        _parameters.telemetryRequestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    }
    
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
    
    _tokenCache = tokenCache;

    if (!_tokenCache)
    {
        REQUIRED_PARAMETER_ERROR(tokenCache, _parameters);
        return nil;
    }

    _oauth2Factory = _parameters.msidOAuthFactory;

    if (!_oauth2Factory)
    {
        REQUIRED_PARAMETER_ERROR(_parameters.msidOAuthFactory, _parameters);
        return nil;
    }

    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = @"v2.0";
    
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

- (void)run:(nonnull MSALCompletionBlock)completionBlock
{
    [[MSIDTelemetry sharedInstance] startEvent:_parameters.telemetryRequestId eventName:MSID_TELEMETRY_EVENT_API_EVENT];
    
    [self acquireToken:completionBlock];
}

- (void)resolveEndpoints:(MSALAuthorityCompletion)completionBlock
{
    NSString *upn = nil;
    if (_parameters.account)
    {
        upn = _parameters.account.username;
    }
    else if (_parameters.loginHint)
    {
        upn = _parameters.loginHint;
    }

    [_parameters.unvalidatedAuthority resolveAndValidate:_parameters.validateAuthority
                                       userPrincipalName:upn
                                                 context:_parameters
                                         completionBlock:^(NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         if (error)
         {
             MSALTelemetryAPIEvent *event = [self getTelemetryAPIEvent];
             [self stopTelemetryEvent:event error:error];

             completionBlock(NO, error);
             return;
         }

         completionBlock(YES, nil);
     }];
}

- (void)acquireToken:(nonnull MSALCompletionBlock)completionBlock
{
    CHECK_ERROR_COMPLETION(completionBlock, _parameters, MSALErrorInvalidParameter, @"completionBlock cannot be nil.");

    MSIDTokenRequest *authRequest = [self tokenRequest];
    
    [authRequest sendWithBlock:^(id response, NSError *error) {
        if (error)
        {
            if (!completionBlock)
            {
                return;
            }

            if ([self isErrorRecoverableByUserInteraction:error])
            {
                NSError *interactionError = MSIDCreateError(MSALErrorDomain, MSALErrorInteractionRequired, @"User interaction is required", error.userInfo[MSALOAuthErrorKey], error.userInfo[MSALOAuthSubErrorKey], error, nil, nil);

                completionBlock(nil, interactionError);

                return;
            }

            completionBlock(nil, error);
            return;
        }
        
        if (response && ![response isKindOfClass:[NSDictionary class]])
        {
            NSError *localError = CREATE_MSAL_LOG_ERROR(_parameters, MSALErrorInternal, @"response is not of the expected type: NSDictionary.");
            completionBlock(nil, localError);
            return;
        }
        
        NSDictionary *jsonDictionary = (NSDictionary *)response;
        NSError *localError = nil;
        MSIDAADV2TokenResponse *tokenResponse = (MSIDAADV2TokenResponse *)[self.oauth2Factory tokenResponseFromJSON:jsonDictionary context:nil error:&localError];
        
        if (!tokenResponse)
        {
            completionBlock(nil, localError);
            return;
        }

        NSError *verificationError = nil;
        if (![self verifyTokenResponse:tokenResponse error:&verificationError])
        {
            completionBlock(nil, verificationError);
            return;
        }
        
        NSError *savingError = nil;
        BOOL isSaved = [self.tokenCache saveTokensWithConfiguration:_parameters.msidConfiguration
                                                           response:tokenResponse
                                                            context:_parameters
                                                              error:&savingError];
        
        if (!isSaved)
        {
            completionBlock(nil, savingError);
            return;
        }

        NSError *scopesError = nil;
        if (![self verifyScopesWithResponse:tokenResponse error:&scopesError])
        {
            completionBlock(nil, scopesError);
            return;
        }

        NSError *resultError = nil;

        MSALResult *result = [self resultFromTokenResponse:tokenResponse error:&resultError];
        completionBlock(result, resultError);
    }];
}

- (BOOL)verifyTokenResponse:(MSIDAADV2TokenResponse *)tokenResponse
                      error:(NSError **)error
{
    NSError *msidError = nil;

    if (![self.oauth2Factory verifyResponse:tokenResponse context:nil error:&msidError])
    {
        if (!error)
        {
            return NO;
        }

        if ([self isErrorRecoverableByUserInteraction:msidError])
        {
            *error = MSIDCreateError(MSALErrorDomain, MSALErrorInteractionRequired, @"User interaction is required", msidError.userInfo[MSALOAuthErrorKey], msidError.userInfo[MSALOAuthSubErrorKey], msidError, nil, nil);
            return NO;
        }

        *error = msidError;
        return NO;
    }

    if (_parameters.account.homeAccountId.identifier != nil &&
        ![_parameters.account.homeAccountId.identifier isEqualToString:tokenResponse.clientInfo.accountIdentifier])
    {
        NSError *userMismatchError = CREATE_MSAL_LOG_ERROR(_parameters, MSALErrorMismatchedUser, @"Different user was returned from the server");
        if (error) *error = userMismatchError;

        return NO;
    }

    return YES;
}

/*
    Particular Oauth errors might be recoverable by interactive login.
    For those errors we'll return MSALErrorInteractionRequired error.
 */
- (BOOL)isErrorRecoverableByUserInteraction:(NSError *)msidError
{
    if (msidError.code == MSALErrorInvalidGrant
        || msidError.code == MSALErrorInvalidRequest)
    {
        return YES;
    }

    return NO;
}

- (MSALResult *)resultFromTokenResponse:(MSIDAADV2TokenResponse *)tokenResponse
                                  error:(NSError **)error
{
    MSIDAccessToken *accessToken = [self.oauth2Factory accessTokenFromResponse:tokenResponse configuration:_parameters.msidConfiguration];
    MSIDIdToken *idToken = [self.oauth2Factory idTokenFromResponse:tokenResponse configuration:_parameters.msidConfiguration];

    if (!accessToken || !idToken)
    {
        NSError *resultError = CREATE_MSAL_LOG_ERROR(_parameters, MSALErrorBadTokenResponse, @"Bad token response returned from the server");

        if (error) *error = resultError;
    }

    MSALResult *result = [MSALResult resultWithAccessToken:accessToken
                                                   idToken:idToken
                                   isExtendedLifetimeToken:NO
                                                     error:error];
    return result;
}

- (BOOL)verifyScopesWithResponse:(MSIDAADV2TokenResponse *)tokenResponse
                           error:(NSError **)error
{
    /*
        If server returns less scopes than developer requested,
        we'd like to throw an error and specify which scopes were granted and which ones not
     */

    NSOrderedSet *grantedScopes = [tokenResponse.scope msidScopeSet];
    MSIDConfiguration *configuration = _parameters.msidConfiguration;

    if (![configuration.scopes isSubsetOfOrderedSet:grantedScopes])
    {
        if (error)
        {
            NSMutableDictionary *additionalUserInfo = [NSMutableDictionary new];
            additionalUserInfo[MSALGrantedScopesKey] = [grantedScopes array];

            NSMutableOrderedSet *declinedScopeSet = [configuration.scopes mutableCopy];
            [declinedScopeSet minusOrderedSet:grantedScopes];

            additionalUserInfo[MSALDeclinedScopesKey] = [declinedScopeSet array];

            *error = MSIDCreateError(MSALErrorDomain, MSALErrorServerDeclinedScopes, @"Server returned less scopes than requested", nil, nil, nil, nil, additionalUserInfo);
        }

        return NO;
    }

    return YES;
}

- (MSIDTokenRequest *)tokenRequest
{
    // Implemented in subclasses
    return nil;
}

- (NSURL *)tokenEndpoint
{
    NSURLComponents *tokenEndpoint = [NSURLComponents componentsWithURL:_authority.metadata.tokenEndpoint resolvingAgainstBaseURL:NO];

    if (_parameters.cloudAuthority)
    {
        tokenEndpoint.host = _parameters.cloudAuthority.environment;
    }

    NSMutableDictionary *endpointQPs = [[NSDictionary msidDictionaryFromWWWFormURLEncodedString:tokenEndpoint.percentEncodedQuery] mutableCopy];

    if (!endpointQPs)
    {
        endpointQPs = [NSMutableDictionary dictionary];
    }
    
    if (_parameters.sliceParameters)
    {
        [endpointQPs addEntriesFromDictionary:_parameters.sliceParameters];
    }
    
    tokenEndpoint.query = [endpointQPs msidWWWFormURLEncode];

    return tokenEndpoint.URL;
}

- (MSALTelemetryAPIEvent *)getTelemetryAPIEvent
{
    MSALTelemetryAPIEvent *event = [[MSALTelemetryAPIEvent alloc] initWithName:MSID_TELEMETRY_EVENT_API_EVENT
                                                                       context:_parameters];
    
    [event setMSALApiId:_apiId];
    [event setCorrelationId:_parameters.correlationId];
    [event setAuthorityType:[_authority telemetryAuthorityType]];
    [event setAuthority:_parameters.unvalidatedAuthority.url.absoluteString];
    [event setClientId:_parameters.clientId];
    
    // Login hint is an optional parameter and might not be present
    if (_parameters.loginHint)
    {
        [event setLoginHint:_parameters.loginHint];
    }
    
    return event;
}

- (void)stopTelemetryEvent:(MSALTelemetryAPIEvent *)event error:(NSError *)error
{
    if (error)
    {
        [event setErrorCode:error.code];
        [event setErrorDomain:error.domain];
    }
    
    [[MSIDTelemetry sharedInstance] stopEvent:_parameters.telemetryRequestId event:event];
    [[MSIDTelemetry sharedInstance] flush:_parameters.telemetryRequestId];
}

@end
