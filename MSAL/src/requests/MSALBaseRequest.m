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
#import "MSALAccount.h"
#import "MSALWebAuthRequest.h"
#import "MSALTelemetryAPIEvent.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "NSString+MSALHelperMethods.h"
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

static MSALScopes *s_reservedScopes = nil;

@interface MSALBaseRequest()

@property (nullable, nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;
@property (nullable, nonatomic) MSIDAADV2Oauth2Factory *oauth2Factory;

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
    _oauth2Factory = [MSIDAADV2Oauth2Factory new];
    
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
    else if(_parameters.loginHint)
    {
        upn = _parameters.loginHint;
    }
    
    [MSALAuthority resolveEndpointsForAuthority:_parameters.unvalidatedAuthority
                              userPrincipalName:upn
                                       validate:_parameters.validateAuthority
                                        context:_parameters
                                completionBlock:completionBlock];
}

- (void)acquireToken:(nonnull MSALCompletionBlock)completionBlock
{
    NSMutableDictionary<NSString *, NSString *> *reqParameters = [NSMutableDictionary new];
    
    NSURLComponents *tokenEndpoint = [NSURLComponents componentsWithURL:_authority.tokenEndpoint resolvingAgainstBaseURL:NO];
    
    if (_cloudAuthority)
    {
        tokenEndpoint.host = _cloudAuthority.host;
    }
    
    NSMutableDictionary *endpointQPs = [[NSDictionary msidURLFormDecode:tokenEndpoint.percentEncodedQuery] mutableCopy];
    
    if (!endpointQPs)
    {
        endpointQPs = [NSMutableDictionary dictionary];
    }
    
    if (_parameters.sliceParameters)
    {
        [endpointQPs addEntriesFromDictionary:_parameters.sliceParameters];
    }
    
    tokenEndpoint.query = [endpointQPs msidURLFormEncode];
    
    MSALWebAuthRequest *authRequest = [[MSALWebAuthRequest alloc] initWithURL:tokenEndpoint.URL
                                                                      context:_parameters];
    
    reqParameters[MSID_OAUTH2_CLIENT_ID] = _parameters.clientId;
    reqParameters[MSID_OAUTH2_SCOPE] = [[self requestScopes:nil] msalToString];
    reqParameters[MSID_OAUTH2_CLIENT_INFO] = @"1";

    [self addAdditionalRequestParameters:reqParameters];
    authRequest.bodyParameters = reqParameters;
    
    [authRequest sendPost:^(MSALHttpResponse *response, NSError *error)
     {
         MSALTelemetryAPIEvent *event = [self getTelemetryAPIEvent];
         NSDictionary *jsonDictionary;
         
         if (!error)
         {
             jsonDictionary = [response.body msidToJsonDictionary:&error];
         }
         
         if (error)
         {
             [self stopTelemetryEvent:event error:error];
             
             completionBlock(nil, error);
             return;
         }
         
         MSIDAADV2TokenResponse *tokenResponse = (MSIDAADV2TokenResponse *)[self.oauth2Factory tokenResponseFromJSON:jsonDictionary context:nil error:&error];

         if (!tokenResponse)
         {
             [self stopTelemetryEvent:event error:error];
             
             completionBlock(nil, [MSALErrorConverter MSALErrorFromMSIDError:error]);
             return;
         }
         
         if (![self.oauth2Factory verifyResponse:tokenResponse context:nil error:&error])
         {
             [self stopTelemetryEvent:event error:error];
             
             completionBlock(nil, [MSALErrorConverter MSALErrorFromMSIDError:error]);
             return;
         }

         if (_parameters.account.homeAccountId.identifier != nil &&
             ![_parameters.account.homeAccountId.identifier isEqualToString:tokenResponse.clientInfo.accountIdentifier])
         {
             NSError *userMismatchError = CREATE_MSAL_LOG_ERROR(_parameters, MSALErrorMismatchedUser, @"Different user was returned from the server");
             completionBlock(nil, userMismatchError);
             return;
         }

         MSIDConfiguration *configuration = _parameters.msidConfiguration;

         BOOL isSaved = [self.tokenCache saveTokensWithConfiguration:configuration
                                                            response:tokenResponse
                                                             context:_parameters
                                                               error:&error];
         
         if (!isSaved)
         {
             completionBlock(nil, [MSALErrorConverter MSALErrorFromMSIDError:error]);
             return;
         }

         MSIDAccessToken *accessToken = [self.oauth2Factory accessTokenFromResponse:tokenResponse configuration:configuration];
         MSIDIdToken *idToken = [self.oauth2Factory idTokenFromResponse:tokenResponse configuration:configuration];
         
         MSALResult *result = [MSALResult resultWithAccessToken:accessToken idToken:idToken];
         
         [event setUser:result.account];
         [self stopTelemetryEvent:event error:nil];

         completionBlock(result, nil);
     }];
}

- (void)addAdditionalRequestParameters:(NSMutableDictionary<NSString *, NSString *> *)parameters
{
    (void)parameters;
}

- (MSALTelemetryAPIEvent *)getTelemetryAPIEvent
{
    MSALTelemetryAPIEvent *event = [[MSALTelemetryAPIEvent alloc] initWithName:MSID_TELEMETRY_EVENT_API_EVENT
                                                                       context:_parameters];
    
    [event setMSALApiId:_apiId];
    [event setCorrelationId:_parameters.correlationId];
    [event setAuthorityType:_authority.authorityType];
    [event setAuthority:_parameters.unvalidatedAuthority.absoluteString];
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
