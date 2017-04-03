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
#import "MSALKeychainTokenCache.h"
#import "MSALTelemetryApiId.h"

@interface MSALSilentRequest()
{
    BOOL _forceRefresh;
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
    
    MSALAccessTokenCacheItem *accessToken = nil;
    if (!_forceRefresh)
    {
#if TARGET_OS_IPHONE
        accessToken = [MSALKeychainTokenCache findAccessToken:_parameters];
#endif
    }
    
    if (accessToken)
    {
        MSALResult *result = [MSALResult resultWithAccessTokenItem:accessToken];
        completionBlock(result, nil);
        return;
    }

#if TARGET_OS_IPHONE
    _refreshToken = [MSALKeychainTokenCache findRefreshToken:_parameters];
#else
    //TODO: Mac support
    _refreshToken = [MSALRefreshTokenCacheItem new];

#endif
    
    CHECK_ERROR_COMPLETION(_refreshToken, _parameters, MSALErrorAuthorizationFailed, @"No token matching arguments found in the cache")
    
    LOG_INFO(_parameters, @"Refreshing access token");
    LOG_INFO_PII(_parameters, @"Refreshing access token");
    
    [super acquireToken:completionBlock];
}

- (void)addAdditionalRequestParameters:(NSMutableDictionary<NSString *,NSString *> *)parameters
{
    parameters[OAUTH2_GRANT_TYPE] = OAUTH2_REFRESH_TOKEN;
    parameters[OAUTH2_REFRESH_TOKEN] = [_refreshToken refreshToken];
}


@end
