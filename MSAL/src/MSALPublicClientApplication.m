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


#import "MSALPublicClientApplication+Internal.h"

#import "MSALAuthority.h"
#import "MSALError.h"
#import "MSALError_Internal.h"
#import "MSALInteractiveRequest.h"
#import "MSALSilentRequest.h"
#import "MSALRequestParameters.h"
#import "MSALUIBehavior_Internal.h"
#import "MSALURLSession.h"
#import "MSALWebUI.h"
#import "MSALTelemetryApiId.h"
#import "MSALTelemetry.h"

@implementation MSALPublicClientApplication
{
    MSALTokenCache *_tokenCache;
}

- (BOOL)generateRedirectUriWithClientId:(NSString *)clientId
                                  error:(NSError * __autoreleasing *)error
{
    NSString *scheme = [NSString stringWithFormat:@"msal%@", clientId];
    
    NSArray* urlTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
    
    for (NSDictionary* urlRole in urlTypes)
    {
        NSArray* urlSchemes = [urlRole objectForKey:@"CFBundleURLSchemes"];
        if ([urlSchemes containsObject:scheme])
        {
            NSString *redirectUri = [NSString stringWithFormat:@"%@://auth", scheme];
            _redirectUri = [NSURL URLWithString:redirectUri];
            return YES;
        }
    }
    
    MSAL_ERROR_PARAM(nil, MSALErrorRedirectSchemeNotRegistered, @"The required app scheme (%@) is not registered in the app's info.plist file. Make sure the URI scheme matches exactly \"msal<clientID>\" format without any whitespaces.", scheme);
    
    return NO;
}

- (id)initWithClientId:(NSString *)clientId
                 error:(NSError * __autoreleasing *)error
{
    return [self initWithClientId:clientId authority:nil error:error];
}

- (id)initWithClientId:(NSString *)clientId
             authority:(NSString *)authority
                 error:(NSError * __autoreleasing *)error
{
    if (!(self = [super init]))
    {
        return nil;
    }
    REQUIRED_PARAMETER(clientId, nil);
    _clientId = clientId;
    
    if (authority)
    {
        _authority = [MSALAuthority checkAuthorityString:authority error:error];
        CHECK_RETURN_NIL(_authority);
    }
    else
    {
        // TODO: Rationalize our default authority behavior (#93)
        _authority = [MSALAuthority defaultAuthority];
    }
    
    CHECK_RETURN_NIL([self generateRedirectUriWithClientId:_clientId
                                                     error:error]);
    
    id<MSALTokenCacheAccessor> dataSource;
#if TARGET_OS_IPHONE
    dataSource = [MSALKeychainTokenCache defaultKeychainCache];
#else
    dataSource = [MSALWrapperTokenCache defaultCache];
#endif
    _tokenCache = [[MSALTokenCache alloc] initWithDataSource:dataSource];
    
    _validateAuthority = YES;
    
    _sliceParameters = [MSALPublicClientApplication defaultSliceParameters];
    
    return self;
}

- (NSArray <MSALUser *> *)users:(NSError * __autoreleasing *)error
{
    return [_tokenCache getUsers:self.clientId context:nil error:error];
}

- (MSALUser *)userForIdentifier:(NSString *)identifier
                          error:(NSError * __autoreleasing *)error
{
    return [_tokenCache getUserForIdentifier:identifier
                                    clientId:self.clientId
                                 environment:[self.authority host]
                                       error:error];
}

#pragma SafariViewController Support

+ (BOOL)handleMSALResponse:(NSURL *)response
{
    if (!response)
    {
        return NO;
    }
    
    MSALInteractiveRequest *request = [MSALInteractiveRequest currentActiveRequest];
    if (!request)
    {
        return NO;
    }
    
    if ([NSString msalIsStringNilOrBlank:response.query])
    {
        return NO;
    }
    
    NSDictionary *qps = [NSDictionary msalURLFormDecode:response.query];
    if (!qps)
    {
        return NO;
    }
    
    NSString *state = qps[OAUTH2_STATE];
    if (!state)
    {
        return NO;
    }
    
    if (![request.state isEqualToString:state])
    {
        LOG_ERROR(request.parameters, @"State in response \"%@\" does not match request \"%@\"", state, request.state);
        LOG_ERROR_PII(request.parameters, @"State in response \"%@\" does not match request \"%@\"", state, request.state);
        return NO;
    }
    
    return [MSALWebUI handleResponse:response];
}

+ (void)cancelCurrentWebAuthSession
{
    [MSALWebUI cancelCurrentWebAuthSession];
}

#pragma mark -
#pragma mark acquireToken

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                           user:nil
                      loginHint:nil
                     uiBehavior:MSALUIBehaviorDefault
           extraQueryParameters:nil
                      authority:nil
                  correlationId:nil
                          apiId:MSALTelemetryApiIdAcquire
                completionBlock:completionBlock];
}

#pragma mark -
#pragma mark Login Hint

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                    loginHint:(NSString *)loginHint
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                           user:nil
                      loginHint:loginHint
                     uiBehavior:MSALUIBehaviorDefault
           extraQueryParameters:nil
                      authority:nil
                  correlationId:nil
                          apiId:MSALTelemetryApiIdAcquireWithHint
                completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                    loginHint:(NSString *)loginHint
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                           user:nil
                      loginHint:loginHint
                     uiBehavior:uiBehavior
           extraQueryParameters:extraQueryParameters
                      authority:nil
                  correlationId:nil
                          apiId:MSALTelemetryApiIdAcquireWithHintBehaviorAndParameters
                completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
         extraScopesToConsent:(NSArray<NSString *> *)extraScopesToConsent
                    loginHint:(NSString *)loginHint
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
                    authority:(NSString *)authority
                correlationId:(NSUUID *)correlationId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:extraScopesToConsent
                           user:nil
                      loginHint:loginHint
                     uiBehavior:uiBehavior
           extraQueryParameters:extraQueryParameters
                      authority:authority
                  correlationId:correlationId
                          apiId:MSALTelemetryApiIdAcquireWithHintBehaviorParametersAuthorityAndCorrelationId
                completionBlock:completionBlock];
}

#pragma mark -
#pragma mark User


- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                         user:(MSALUser *)user
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                           user:user
                      loginHint:nil
                     uiBehavior:MSALUIBehaviorDefault
           extraQueryParameters:nil
                      authority:nil
                  correlationId:nil
                          apiId:MSALTelemetryApiIdAcquireWithUserBehaviorAndParameters
                completionBlock:completionBlock];
    
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                         user:(MSALUser *)user
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                           user:user
                      loginHint:nil
                     uiBehavior:uiBehavior
           extraQueryParameters:extraQueryParameters
                      authority:nil
                  correlationId:nil
                          apiId:MSALTelemetryApiIdAcquireWithUserBehaviorAndParameters
                completionBlock:completionBlock];
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
         extraScopesToConsent:(NSArray<NSString *> *)extraScopesToConsent
                         user:(MSALUser *)user
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
                    authority:(NSString *)authority
                correlationId:(NSUUID *)correlationId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:extraScopesToConsent
                           user:user
                      loginHint:nil
                     uiBehavior:uiBehavior
           extraQueryParameters:extraQueryParameters
                      authority:authority
                  correlationId:correlationId
                          apiId:MSALTelemetryApiIdAcquireWithUserBehaviorParametersAuthorityAndCorrelationId
                completionBlock:completionBlock];
    
}

#pragma mark -
#pragma mark Silent

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                               user:(MSALUser *)user
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenSilentForScopes:scopes
                                 user:user
                            authority:nil
                         forceRefresh:NO
                        correlationId:nil
                                apiId:MSALTelemetryApiIdAcquireSilentWithUser
                      completionBlock:completionBlock];
}

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                               user:(MSALUser *)user
                          authority:(NSString *)authority
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenSilentForScopes:scopes
                                 user:user
                            authority:authority
                         forceRefresh:NO
                        correlationId:nil
                                apiId:MSALTelemetryApiIdAcquireSilentWithUserAndAuthority
                      completionBlock:completionBlock];
}

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                               user:(MSALUser *)user
                          authority:(NSString *)authority
                       forceRefresh:(BOOL)forceRefresh
                      correlationId:(NSUUID *)correlationId
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenSilentForScopes:scopes
                                 user:user
                            authority:authority
                         forceRefresh:forceRefresh
                        correlationId:correlationId
                                apiId:MSALTelemetryApiIdAcquireSilentWithUserAuthorityForceRefreshAndCorrelationId
                      completionBlock:completionBlock];
}

#pragma mark -
#pragma mark - private methods

+ (void)logOperation:(NSString *)operation
              result:(MSALResult *)result
               error:(NSError *)error
             context:(id<MSALRequestContext>)ctx
{
    if (error)
    {
        NSString *errorDescription = error.userInfo[MSALErrorDescriptionKey];
        errorDescription = errorDescription ? errorDescription : @"";
        LOG_ERROR(ctx, @"%@ returning with error: (%@, %ld) %@", operation, error.domain, (long)error.code, errorDescription);
        LOG_ERROR_PII(ctx, @"%@ returning with error: (%@, %ld) %@", operation, error.domain, (long)error.code, errorDescription);
    }
    
    if (result)
    {
        NSString *hashedAT = [result.accessToken msalShortSHA256Hex];
        LOG_INFO(ctx, @"%@ returning with at: %@ scopes:%@ expiration:%@", operation, hashedAT, result.scopes, result.expiresOn);
        LOG_INFO_PII(ctx, @"%@ returning with at: %@ scopes:%@ expiration:%@", operation, hashedAT, result.scopes, result.expiresOn);
    }
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
         extraScopesToConsent:(NSArray<NSString *> *)extraScopesToConsent
                         user:(MSALUser *)user
                    loginHint:(NSString *)loginHint
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
                    authority:(NSString *)authority
                correlationId:(NSUUID *)correlationId
                        apiId:(MSALTelemetryApiId)apiId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    MSALRequestParameters* params = [MSALRequestParameters new];
    params.correlationId = correlationId ? correlationId : [NSUUID new];
    params.component = _component;
    params.apiId = apiId;
    params.user = user;
    params.validateAuthority = _validateAuthority;
    params.sliceParameters = _sliceParameters;
    
    LOG_INFO(params,
             @"-[MSALPublicClientApplication acquireTokenForScopes:%@\n"
              "                               extraScopesToConsent:%@\n"
              "                                               user:%@\n"
              "                                          loginHint:%@\n"
              "                                         uiBehavior:%@\n"
              "                               extraQueryParameters:%@\n"
              "                                          authority:%@\n"
              "                                      correlationId:%@]",
             scopes, extraScopesToConsent, _PII(user.userIdentifier), _PII(loginHint), MSALStringForMSALUIBehavior(uiBehavior), extraQueryParameters, _PII(authority), correlationId);
    LOG_INFO_PII(params,
                 @"-[MSALPublicClientApplication acquireTokenForScopes:%@\n"
                  "                               extraScopesToConsent:%@\n"
                  "                                               user:%@\n"
                  "                                          loginHint:%@\n"
                  "                                         uiBehavior:%@\n"
                  "                               extraQueryParameters:%@\n"
                  "                                          authority:%@\n"
                  "                                      correlationId:%@]",
                 scopes, extraScopesToConsent, user.userIdentifier, loginHint, MSALStringForMSALUIBehavior(uiBehavior), extraQueryParameters, authority, correlationId);
    
    MSALCompletionBlock block = ^(MSALResult *result, NSError *error)
    {
        [MSALPublicClientApplication logOperation:@"acquireToken" result:result error:error context:params];
        completionBlock(result, error);
    };
    
    [params setScopesFromArray:scopes];
    params.loginHint = loginHint;
    params.extraQueryParameters = extraQueryParameters;
    NSError *error = nil;
    if (!authority)
    {
        params.unvalidatedAuthority = _authority;
    }
    else if (![params setAuthorityFromString:authority error:&error])
    {
        block(nil, error);
        return;
    }
    
    params.redirectUri = _redirectUri;
    params.clientId = _clientId;
    params.tokenCache = _tokenCache;
    params.urlSession = [MSALURLSession createMSALSession:params];
    
    MSALInteractiveRequest *request =
    [[MSALInteractiveRequest alloc] initWithParameters:params
                                      extraScopesToConsent:extraScopesToConsent
                                              behavior:uiBehavior
                                                 error:&error];
    if (!request)
    {
        [params.urlSession invalidateAndCancel];
        block(nil, error);
        return;
    }
    
    [request run:^(MSALResult *result, NSError *error) {
        [params.urlSession invalidateAndCancel];
        block(result, error);
    }];
}

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                               user:(MSALUser *)user
                          authority:(NSString *)authority
                       forceRefresh:(BOOL)forceRefresh
                      correlationId:(NSUUID *)correlationId
                              apiId:(MSALTelemetryApiId)apiId
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    MSALRequestParameters* params = [MSALRequestParameters new];
    params.correlationId = correlationId ? correlationId : [NSUUID new];
    params.user = user;
    params.apiId = apiId;
    params.validateAuthority = _validateAuthority;
    params.sliceParameters = _sliceParameters;
    
    [params setScopesFromArray:scopes];
    
    LOG_INFO(params,
             @"-[MSALPublicClientApplication acquireTokenSilentForScopes:%@\n"
              "                                                     user:%@\n"
              "                                             forceRefresh:%@\n"
              "                                            correlationId:%@\n]",
             scopes, _PII(user), forceRefresh ? @"Yes" : @"No", correlationId);
    
    
    LOG_INFO_PII(params,
                 @"-[MSALPublicClientApplication acquireTokenSilentForScopes:%@\n"
                  "                                                     user:%@\n"
                  "                                             forceRefresh:%@\n"
                  "                                            correlationId:%@\n]",
                 scopes, user, forceRefresh ? @"Yes" : @"No", correlationId);
    
    MSALCompletionBlock block = ^(MSALResult *result, NSError *error)
    {
        [MSALPublicClientApplication logOperation:@"acquireTokenSilent" result:result error:error context:params];
        completionBlock(result, error);
    };

    NSError *error = nil;
    if (![params setAuthorityFromString:authority error:&error])
    {
        block(nil, error);
        return;
    }
    params.redirectUri = _redirectUri;
    params.clientId = _clientId;
    params.tokenCache = _tokenCache;
    params.urlSession = [MSALURLSession createMSALSession:params];

    MSALSilentRequest *request =
    [[MSALSilentRequest alloc] initWithParameters:params forceRefresh:forceRefresh error:&error];
    
    if (!request)
    {
        [params.urlSession invalidateAndCancel];
        block(nil, error);
        return;
    }
    
    [request run:^(MSALResult *result, NSError *error) {
        [params.urlSession invalidateAndCancel];
        block(result, error);
    }];
}

#pragma mark -
#pragma mark remove user from cache

- (BOOL)removeUser:(MSALUser *)user
             error:(NSError * __autoreleasing *)error
{
    if (!user)
    {
        return YES;
    }
    
    return [_tokenCache deleteAllTokensForUser:user clientId:self.clientId context:nil error:error];
}

@end


@implementation MSALPublicClientApplication (Internal)

- (MSALTokenCache *)tokenCache
{
    return _tokenCache;
}

- (void)setTokenCache:(MSALTokenCache *)tokenCache
{
    _tokenCache = tokenCache;
}

+ (NSDictionary *)defaultSliceParameters
{
    return @{ DEFAULT_SLICE_PARAMS };
}

@end
