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

#import "MSALSilentRequest.h"
#import "MSALResult+Internal.h"
#import "MSALTelemetryAPIEvent.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSALAccount+Internal.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDConfiguration.h"
#import "MSALErrorConverter.h"
#import "MSIDAADV2Oauth2Factory.h"

@interface MSALSilentRequest()

@property (nonatomic) MSIDRefreshToken *refreshToken;

@end

@implementation MSALSilentRequest

- (id)initWithParameters:(MSALRequestParameters *)parameters
            forceRefresh:(BOOL)forceRefresh
              tokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
                   error:(NSError *__autoreleasing  _Nullable *)error;
{
    if (!(self = [super initWithParameters:parameters
                                tokenCache:tokenCache
                                     error:error]))
    {
        return nil;
    }
    
    _forceRefresh = forceRefresh;
    _refreshToken = nil;
    
    return self;
}

- (void)acquireToken:(MSALCompletionBlock)completionBlock
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
    
    [_parameters.unvalidatedAuthority resolveAndValidate:_parameters.validateAuthority
                                       userPrincipalName:upn
                                                 context:_parameters
                                         completionBlock:^(NSURL *openIdConfigurationEndpoint, BOOL validated, NSError *error)
     {
         [_parameters.unvalidatedAuthority loadOpenIdMetadataWithContext:_parameters completionBlock:^(MSIDOpenIdProviderMetadata *metadata, NSError *error)
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
    CHECK_ERROR_COMPLETION(_parameters.account, _parameters, MSALErrorAccountRequired, @"user parameter cannot be nil");

    MSIDConfiguration *msidConfiguration = _parameters.msidConfiguration;

    if (!_forceRefresh)
    {
        NSError *error = nil;
        MSIDAccessToken *accessToken = [self.tokenCache getAccessTokenForAccount:_parameters.account.lookupAccountIdentifier
                                                                   configuration:msidConfiguration
                                                                         context:_parameters
                                                                           error:&error];

        if (!accessToken && error)
        {
            MSALTelemetryAPIEvent *event = [self getTelemetryAPIEvent];
            [self stopTelemetryEvent:event error:error];

            completionBlock(nil, error);
            return;
        }

        if (accessToken && !accessToken.isExpired)
        {
            MSIDIdToken *idToken = [self.tokenCache getIDTokenForAccount:_parameters.account.lookupAccountIdentifier
                                                           configuration:msidConfiguration
                                                                 context:_parameters
                                                                   error:&error];

            MSALResult *result = [MSALResult resultWithAccessToken:accessToken idToken:idToken];

            MSALTelemetryAPIEvent *event = [self getTelemetryAPIEvent];
            [event setUser:result.account];
            [self stopTelemetryEvent:event error:nil];

            completionBlock(result, nil);
            return;
        }

        _parameters.unvalidatedAuthority = msidConfiguration.authority;
    }

    NSError *msidError = nil;

    self.refreshToken = [self.tokenCache getRefreshTokenWithAccount:_parameters.account.lookupAccountIdentifier
                                                           familyId:nil
                                                      configuration:msidConfiguration
                                                            context:_parameters
                                                              error:&msidError];

    if (msidError)
    {
        NSError *msalError = [MSALErrorConverter MSALErrorFromMSIDError:msidError];
        completionBlock(nil, msalError);
        return;
    }

    CHECK_ERROR_COMPLETION(self.refreshToken, _parameters, MSALErrorInteractionRequired, @"No token matching arguments found in the cache")

    MSID_LOG_INFO(_parameters, @"Refreshing access token");
    MSID_LOG_INFO_PII(_parameters, @"Refreshing access token");
    
    [super acquireToken:completionBlock];
}

- (void)addAdditionalRequestParameters:(NSMutableDictionary<NSString *,NSString *> *)parameters
{
    parameters[MSID_OAUTH2_GRANT_TYPE] = MSID_OAUTH2_REFRESH_TOKEN;
    parameters[MSID_OAUTH2_REFRESH_TOKEN] = [self.refreshToken refreshToken];
}

@end
