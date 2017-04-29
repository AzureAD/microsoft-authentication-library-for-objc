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
#import "MSALRefreshTokenCacheItem.h"
#import "MSALAccessTokenCacheItem.h"
#import "MSALResult+Internal.h"
#import "MSALTokenCache.h"

#import "MSALTelemetryAPIEvent.h"
#import "MSALTelemetry+Internal.h"
#import "MSALTelemetryEventStrings.h"

#import "NSURL+MSALExtensions.h"

@interface MSALSilentRequest()
{
    MSALRefreshTokenCacheItem *_refreshToken;
}

@end

@implementation MSALSilentRequest

- (id)initWithParameters:(MSALRequestParameters *)parameters
            forceRefresh:(BOOL)forceRefresh
                   error:(NSError *__autoreleasing  _Nullable *)error;
{
    if (!(self = [super initWithParameters:parameters
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
    CHECK_ERROR_COMPLETION(_parameters.user, _parameters, MSALErrorInvalidParameter, @"user parameter cannot be nil");

    MSALTokenCache *cache = _parameters.tokenCache;
    
    if (!_forceRefresh)
    {
        NSString *foundAuthority = nil;
        NSError *error = nil;
        MSALAccessTokenCacheItem *accessToken = nil;
        if (![cache findAccessTokenWithAuthority:_parameters.unvalidatedAuthority
                                        clientId:_parameters.clientId
                                          scopes:_parameters.scopes
                                            user:_parameters.user
                                         context:_parameters
                                     accessToken:&accessToken
                                  authorityFound:&foundAuthority
                                           error:&error])
        {
            if (error == nil && !_parameters.unvalidatedAuthority)
            {
                error = CREATE_LOG_ERROR(_parameters, MSALErrorNoAccessTokensFound, @"Failed to find any access tokens matching user and client ID in cache, and we have no authority to use.");
            }
            
            if (error)
            {
                MSALTelemetryAPIEvent *event = [self getTelemetryAPIEvent];
                [self stopTelemetryEvent:event error:error];

                completionBlock(nil, error);
                return;
            }
        }
        
        if (accessToken)
        {
            MSALResult *result = [MSALResult resultWithAccessTokenItem:accessToken];
            
            MSALTelemetryAPIEvent *event = [self getTelemetryAPIEvent];
            [event setUser:result.user];
            [self stopTelemetryEvent:event error:nil];
            
            completionBlock(result, nil);
            return;
        }
        
        if (!_parameters.unvalidatedAuthority)
        {
            _parameters.unvalidatedAuthority = [NSURL URLWithString:foundAuthority];
        }
    }
    
    _refreshToken = [cache findRefreshTokenWithEnvironment:[_parameters.unvalidatedAuthority msalHostWithPort]
                                                  clientId:_parameters.clientId
                                            userIdentifier:_parameters.user.userIdentifier
                                                   context:_parameters
                                                     error:nil];
    
    CHECK_ERROR_COMPLETION(_refreshToken, _parameters, MSALErrorAuthorizationFailed, @"No token matching arguments found in the cache")
    
    [super resolveEndpoints:^(MSALAuthority *authority, NSError *error) {
        if (error)
        {
            MSALTelemetryAPIEvent *event = [self getTelemetryAPIEvent];
            [self stopTelemetryEvent:event error:error];
            
            completionBlock(nil, error);
            return;
        }
        
        LOG_INFO(_parameters, @"Refreshing access token");
        LOG_INFO_PII(_parameters, @"Refreshing access token");
        
        _authority = authority;
        
        [super acquireToken:completionBlock];
    }];
}

- (void)addAdditionalRequestParameters:(NSMutableDictionary<NSString *,NSString *> *)parameters
{
    parameters[OAUTH2_GRANT_TYPE] = OAUTH2_REFRESH_TOKEN;
    parameters[OAUTH2_REFRESH_TOKEN] = [_refreshToken refreshToken];
}


@end
