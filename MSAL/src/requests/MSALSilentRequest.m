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

@interface MSALSilentRequest()

@property (nonatomic) MSIDRefreshToken *refreshToken;
@property (nonatomic) MSIDRefreshToken *familyRefreshToken;
@property (nonatomic) NSString *familyId;

@end

@implementation MSALSilentRequest
{
    MSIDAccessToken *_extendedLifetimeAccessToken; //store valid AT in terms of ext_expires_in (if find any)
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
    _refreshToken = nil;
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
        
        [self acquireTokenImpl:completionBlock];
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
    
    [self tryRT:@"1" completionBlock:completionBlock];
}

- (MSIDRefreshToken *)getRefreshToken:(NSString *)familyId error:(NSError **)error
{
    self.familyId = familyId;
    MSIDConfiguration *msidConfiguration = _parameters.msidConfiguration;
    return [self.tokenCache getRefreshTokenWithAccount:_parameters.account.lookupAccountIdentifier
                                                           familyId:familyId
                                                      configuration:msidConfiguration
                                                            context:_parameters
                                                              error:error];
}

- (void)tryRT:(NSString *)familyID completionBlock:(MSALCompletionBlock)completionBlock
{
    //try looking for FRT first
    NSError *msidError = nil;
    self.familyRefreshToken = [self getRefreshToken:familyID error:&msidError];
    
    if (msidError)
    {
        completionBlock(nil, msidError);
        return;
    }
    
    //if FRT not found, try looking for MRRT
    if (!self.familyRefreshToken)
    {
        msidError = nil;
        self.refreshToken = [self getRefreshToken:nil error:&msidError];
        if (msidError)
        {
            completionBlock(nil, msidError);
            return;
        }
    }
    
    MSIDRefreshToken *currentRefreshToken = self.familyRefreshToken ? self.familyRefreshToken : self.refreshToken;
    
    [self refreshAccessToken:currentRefreshToken completionBlock:^(MSALResult *result, NSError *error)
     {
         if (error)
         {
             //If server returns invalid_grant and refresh token uses is FRT, try MRRT
             if([self isErrorRecoverableByUserInteraction:error])
             {
                 NSError *msidError = nil;
                 self.refreshToken = [self getRefreshToken:nil error:&msidError];
                 
                 if (msidError)
                 {
                     completionBlock(nil, msidError);
                     return;
                 }
                 
                 if(self.refreshToken.familyId && ![[self.refreshToken refreshToken] isEqualToString:[self.familyRefreshToken refreshToken]])
                 {
                     [self refreshAccessToken:self.refreshToken completionBlock:completionBlock];
                     return;
                 }
                 
                 NSError *interactionError = MSIDCreateError(MSALErrorDomain, MSALErrorInteractionRequired, @"User interaction is required", error.userInfo[MSALOAuthErrorKey], error.userInfo[MSALOAuthSubErrorKey], error, nil, nil);
                 
                 completionBlock(nil, interactionError);
                 return;
             }
             
             completionBlock(nil, error);
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
    
    [super acquireToken:^(MSALResult *result, NSError *error)
     {
         // Logic for returning extended lifetime token
         if (_parameters.extendedLifetimeEnabled && _extendedLifetimeAccessToken && [self isServerUnavailable:error])
         {
             MSIDIdToken *idToken = [self.tokenCache getIDTokenForAccount:_parameters.account.lookupAccountIdentifier
                                                            configuration:msidConfiguration
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
}

- (MSIDTokenRequest *)tokenRequest
{
    MSIDRefreshToken *refreshToken = [self.familyId isEqualToString:@"1"] ? self.familyRefreshToken : self.refreshToken;
    return [[MSIDAADRefreshTokenGrantRequest alloc] initWithEndpoint:[self tokenEndpoint]
                                                            clientId:_parameters.clientId
                                                               scope:[[self requestScopes:nil] msidToString]
                                                        refreshToken:[refreshToken refreshToken]
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

- (BOOL)isErrorRecoverableByUserInteraction:(NSError *)msidError
{
    if (msidError.code == MSALErrorInvalidGrant
        || msidError.code == MSALErrorInvalidRequest)
    {
        return YES;
    }
    
    return NO;
}

@end
