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
#import "MSALBaseRequest.h"
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
#import "MSIDAADRefreshTokenGrantRequest.h"
#import "MSIDError.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDConstants.h"

@interface MSALSilentRequest()

@end

@implementation MSALSilentRequest
{
    MSIDAccessToken *_extendedLifetimeAccessToken; //store valid AT in terms of ext_expires_in (if find any)
    MSIDRefreshToken *_refreshToken;
    MSIDRefreshToken *_familyRefreshToken;
}

- (id)initWithParameters:(MSALRequestParameters *)parameters
            forceRefresh:(BOOL)forceRefresh
              tokenCache:(MSIDDefaultTokenCacheAccessor *)tokenCache
        expirationBuffer:(NSUInteger)expirationBuffer
                   error:(NSError *__autoreleasing  _Nullable *)error;
{
    if (!(self = [super initWithParameters:parameters
                                tokenCache:tokenCache
                                     error:error]))
    {
        return nil;
    }
    
    _forceRefresh = forceRefresh;
    _expirationBuffer = expirationBuffer;
    return self;
}

- (void)acquireToken:(MSALCompletionBlock)completionBlock
{
    [super resolveEndpoints:^(BOOL resolved, NSError *error) {

        if (!resolved)
        {
            completionBlock(nil, error);
            return;
        }
        
        _authority = _parameters.unvalidatedAuthority;
        [self acquireTokenImpl:completionBlock];
    }];
}

- (void)acquireTokenImpl:(MSALCompletionBlock)completionBlock
{
    CHECK_ERROR_COMPLETION(_parameters.account, _parameters, MSALErrorAccountRequired, @"user parameter cannot be nil");

    MSIDConfiguration *msidConfiguration = _parameters.msidConfiguration;

    if (!_forceRefresh && !_parameters.claims)
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
        
        if (accessToken && ![accessToken isExpiredWithExpiryBuffer:_expirationBuffer])
        {
            MSIDIdToken *idToken = [self.tokenCache getIDTokenForAccount:_parameters.account.lookupAccountIdentifier
                                                           configuration:msidConfiguration
                                                                 context:_parameters
                                                                   error:&error];

            NSError *error = nil;

            MSALResult *result = [MSALResult resultWithAccessToken:accessToken
                                                           idToken:idToken
                                           isExtendedLifetimeToken:NO
                                                             error:&error];

            MSALTelemetryAPIEvent *event = [self getTelemetryAPIEvent];
            [event setUser:result.account];
            [self stopTelemetryEvent:event error:nil];

            completionBlock(result, nil);
            return;
        }

        // If the access token is good in terms of extended lifetime then store it for later use
        if (accessToken && accessToken.isExtendedLifetimeValid)
        {
            _extendedLifetimeAccessToken = accessToken;
        }

        _parameters.unvalidatedAuthority = msidConfiguration.authority;
    }

    NSError *msidError = nil;
    NSArray<MSIDAppMetadataCacheItem *> *appMetadataEntries = [self.tokenCache getAppMetadataEntries:_parameters.msidConfiguration
                                                                                             context:_parameters
                                                                                               error:&msidError];
    
    if (msidError)
    {
        completionBlock(nil, msidError);
        return;
    }
    
    //On first network try, app metadata will be nil but on every subsequent attempt, it should reflect if clientId is part of family
    NSString *familyId = appMetadataEntries.firstObject ? appMetadataEntries.firstObject.familyId : @"1";
    if (![NSString msidIsStringNilOrBlank:familyId])
    {
        [self tryFRT:familyId appMetadata:appMetadataEntries.firstObject completionBlock:completionBlock];
    }
    else
    {
        [self tryMRRT:completionBlock];
    }
}

- (MSIDRefreshToken *)getRefreshToken:(NSString *)familyId error:(NSError **)error
{
    MSIDConfiguration *msidConfiguration = _parameters.msidConfiguration;
    return [self.tokenCache getRefreshTokenWithAccount:_parameters.account.lookupAccountIdentifier
                                              familyId:familyId
                                         configuration:msidConfiguration
                                               context:_parameters
                                                 error:error];
}

- (void)tryFRT:(NSString *)familyId appMetadata:(MSIDAppMetadataCacheItem *)appMetadata completionBlock:(MSALCompletionBlock)completionBlock
{
    NSError *msidError = nil;
    _familyRefreshToken = [self getRefreshToken:familyId error:&msidError];
    if (msidError)
    {
        completionBlock(nil, msidError);
        return;
    }

    //If no FRT found, try looking for app specific RT
    if (!_familyRefreshToken)
    {
        [self tryMRRT:completionBlock];
        return;
    }

    [self refreshAccessToken:_familyRefreshToken completionBlock:^(MSALResult *result, NSError *error)
     {
         if (error)
         {
             if ([self isErrorRecoverableByUserInteraction:error])
             {
                 //Udpate app metadata  by resetting familyId if server returns client_mismatch
                 NSError *msidError = nil;
                 [self updateAppMetadata:appMetadata
                             serverError:error
                              cacheError:&msidError
                         completionBlock:completionBlock];
                 
                 if (msidError)
                 {
                     completionBlock(nil, msidError);
                     return;
                 }
                 
                 //If server returns invalid grant on FRT, look for app specific RT
                 _refreshToken = [self getRefreshToken:nil error:&msidError];
                 _familyRefreshToken = nil;
                 if (msidError)
                 {
                     completionBlock(nil, msidError);
                     return;
                 }

                 // Check to see if the content of mrt and frt is not the same before initiating a network request
                 if (_refreshToken)
                 {
                     [self tryMRRT:completionBlock];
                     return;
                 }

                 NSError *interactionError = MSIDCreateError(MSALErrorDomain, MSALErrorInteractionRequired, @"User interaction is required", error.userInfo[MSALOAuthErrorKey], error.userInfo[MSALOAuthSubErrorKey], error, nil, nil);
                 
                 completionBlock(nil, interactionError);
             }
             else
             {
                 completionBlock(nil, error);
             }
         }
         else
         {
             completionBlock(result, nil);
         }
     }];
}

- (void)tryMRRT:(MSALCompletionBlock)completionBlock
{
    //Check if app specific RT already exists
    if (!_refreshToken)
    {
        NSError *msidError = nil;
        _refreshToken = [self getRefreshToken:nil error:&msidError];
        if (msidError)
        {
            completionBlock(nil, msidError);
            return;
        }
    }
    
    [self refreshAccessToken:_refreshToken completionBlock:^(MSALResult *result, NSError *error)
     {
         if (error)
         {
             //Check if server returns invalid_grant or invalid_request
             if ([self isErrorRecoverableByUserInteraction:error])
             {
                 NSError *interactionError = MSIDCreateError(MSALErrorDomain, MSALErrorInteractionRequired, @"User interaction is required", error.userInfo[MSALOAuthErrorKey], error.userInfo[MSALOAuthSubErrorKey], error, nil, nil);
                 
                 completionBlock(nil, interactionError);
                 return;
             }
             else
             {
                 completionBlock(nil, error);
             }
         }
         else
         {
             completionBlock(result, nil);
         }
     }];
}

- (void)refreshAccessToken:(MSIDRefreshToken *)refreshToken completionBlock:(MSALCompletionBlock)completionBlock
{
    CHECK_ERROR_COMPLETION(refreshToken, _parameters, MSALErrorInteractionRequired, @"No token matching arguments found in the cache")
    MSID_LOG_INFO(_parameters, @"Refreshing access token");
    MSID_LOG_INFO_PII(_parameters, @"Refreshing access token");
    MSIDConfiguration *msidConfiguration = _parameters.msidConfiguration;

    [self acquireTokenWithRefreshToken:refreshToken
                         configuration:msidConfiguration
                       completionBlock:completionBlock];
}

- (void)acquireTokenWithRefreshToken:(MSIDRefreshToken *)refreshToken
                       configuration:(MSIDConfiguration *)configuration
                     completionBlock:(MSALCompletionBlock)completionBlock
{
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

         [super acquireToken:^(MSALResult *result, NSError *error)
          {
              // Logic for returning extended lifetime token
              if (_parameters.extendedLifetimeEnabled && _extendedLifetimeAccessToken && [self isServerUnavailable:error])
              {
                  MSIDIdToken *idToken = [self.tokenCache getIDTokenForAccount:_parameters.account.lookupAccountIdentifier
                                                                 configuration:configuration
                                                                       context:_parameters
                                                                         error:&error];

                  NSError *resultError = nil;

                  result = [MSALResult resultWithAccessToken:_extendedLifetimeAccessToken
                                                     idToken:idToken
                                     isExtendedLifetimeToken:YES
                                                       error:&resultError];
                  error = resultError;
              }

              completionBlock(result, error);
          }];
     }];
}

- (MSIDTokenRequest *)tokenRequest
{
    MSIDRefreshToken *refreshToken = _familyRefreshToken ? _familyRefreshToken : _refreshToken;
    return [[MSIDAADRefreshTokenGrantRequest alloc] initWithEndpoint:[self tokenEndpoint]
                                                            clientId:_parameters.clientId
                                                        enrollmentId:nil
                                                               scope:[[self requestScopes:nil] msidToString]
                                                        refreshToken:[refreshToken refreshToken]
                                                              claims:[self claims]
                                                             context:_parameters];
}

- (BOOL)isServerUnavailable:(NSError *)error
{
    if (![error.domain isEqualToString:MSALErrorDomain])
    {
        return NO;
    }
    
    NSInteger responseCode = [[error.userInfo objectForKey:MSALHTTPResponseCodeKey] intValue];
    return error.code == MSALErrorUnhandledResponse && responseCode >= 500 && responseCode <= 599;
}

- (void)updateAppMetadata:(MSIDAppMetadataCacheItem *)appMetadata
              serverError:(NSError *)serverError
               cacheError:(NSError **)cacheError
          completionBlock:(MSALCompletionBlock)completionBlock
{
    //When FRT is used by client which is not part of family, the server returns "client_mismatch" as sub-error
    NSString *subError = serverError.userInfo[MSALOAuthSubErrorKey];
    if (subError && [subError isEqualToString:MSIDServerErrorClientMismatch])
    {
        //reset family id if set in app's metadata
        if (appMetadata && ![NSString msidIsStringNilOrBlank:appMetadata.familyId])
        {
            appMetadata.familyId = @"";
            [self.tokenCache updateAppMetadata:appMetadata context:_parameters error:cacheError];
        }
    }
}

@end
