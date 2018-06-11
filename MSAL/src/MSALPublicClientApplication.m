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
#import "MSIDKeychainTokenCache.h"
#import "MSIDMacTokenCache.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccount.h"
#import "NSURL+MSIDExtensions.h"
#import "MSALAccount+Internal.h"
#import "MSIDRefreshToken.h"
#import "MSALIdToken.h"
#import "MSIDAADV2IdTokenClaims.h"
#import "MSALErrorConverter.h"
#import "MSALAccountId.h"
#import "MSIDAuthority.h"
#import "MSIDAADV2Oauth2Factory.h"

@interface MSALPublicClientApplication()

@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;

@end

@implementation MSALPublicClientApplication

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
    
#if TARGET_OS_IPHONE
    MSIDKeychainTokenCache *dataSource;
    if (self.keychainGroup)
    {
        dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:self.keychainGroup];
    }
    else
    {
        dataSource = MSIDKeychainTokenCache.defaultKeychainCache;
    }

    MSIDOauth2Factory *factory = [MSIDAADV2Oauth2Factory new];
    
    MSIDLegacyTokenCacheAccessor *legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil factory:factory];
    MSIDDefaultTokenCacheAccessor *defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:@[legacyAccessor] factory:factory];
    
    self.tokenCache = defaultAccessor;
#else
    __auto_type dataSource = MSIDMacTokenCache.defaultCache;

    MSIDDefaultTokenCacheAccessor *defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil factory:[MSIDAADV2Oauth2Factory new]];
    self.tokenCache = defaultAccessor;
#endif
    
    _validateAuthority = YES;
    
    _sliceParameters = [MSALPublicClientApplication defaultSliceParameters];
    
    return self;
}

- (NSArray <MSALAccount *> *)accounts:(NSError * __autoreleasing *)error
{
    NSError *msidError = nil;

    __auto_type msidAccounts = [self.tokenCache allAccountsForEnvironment:self.authority.msidHostWithPortIfNecessary
                                                                 clientId:self.clientId
                                                                 familyId:nil
                                                                  context:nil
                                                                    error:&msidError];


    if (msidError)
    {
        *error = [MSALErrorConverter MSALErrorFromMSIDError:msidError];
        return nil;
    }

    NSMutableSet *msalAccounts = [NSMutableSet new];

    for (MSIDAccount *msidAccount in msidAccounts)
    {
        MSALAccount *msalAccount = [[MSALAccount alloc] initWithMSIDAccount:msidAccount];

        if (msalAccount)
        {
            [msalAccounts addObject:msalAccount];
        }
    }

    return [msalAccounts allObjects];
}

- (MSALAccount *)accountForHomeAccountId:(NSString *)homeAccountId
                                   error:(NSError * __autoreleasing *)error
{
    NSArray<MSALAccount *> *accounts = [self accounts:error];

    for (MSALAccount *account in accounts)
    {
        if ([account.homeAccountId.identifier isEqualToString:homeAccountId])
        {
            return account;
        }
    }

    return nil;
}

- (MSALAccount *)accountForLocalAccountId:(NSString *)localAccountId
                                    error:(NSError * __autoreleasing *)error
{
    NSArray<MSALAccount *> *accounts = [self accounts:error];

    for (MSALAccount *account in accounts)
    {
        if ([account.localAccountId.identifier isEqualToString:localAccountId])
        {
            return account;
        }
    }

    return nil;
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
    
    if ([NSString msidIsStringNilOrBlank:response.query])
    {
        return NO;
    }
    
    NSDictionary *qps = [NSDictionary msidURLFormDecode:response.query];
    if (!qps)
    {
        return NO;
    }
    
    NSString *state = qps[MSID_OAUTH2_STATE];
    if (!state)
    {
        return NO;
    }
    
    if (![request.state isEqualToString:state])
    {
        MSID_LOG_ERROR(request.parameters, @"State in response \"%@\" does not match request \"%@\"", state, request.state);
        MSID_LOG_ERROR_PII(request.parameters, @"State in response \"%@\" does not match request \"%@\"", state, request.state);
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
                        account:nil
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
                        account:nil
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
                        account:nil
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
                        account:nil
                      loginHint:loginHint
                     uiBehavior:uiBehavior
           extraQueryParameters:extraQueryParameters
                      authority:authority
                  correlationId:correlationId
                          apiId:MSALTelemetryApiIdAcquireWithHintBehaviorParametersAuthorityAndCorrelationId
                completionBlock:completionBlock];
}

#pragma mark -
#pragma mark Account


- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                      account:(MSALAccount *)account
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                        account:account
                      loginHint:nil
                     uiBehavior:MSALUIBehaviorDefault
           extraQueryParameters:nil
                      authority:nil
                  correlationId:nil
                          apiId:MSALTelemetryApiIdAcquireWithUserBehaviorAndParameters
                completionBlock:completionBlock];
    
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
                      account:(MSALAccount *)account
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:nil
                        account:account
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
                      account:(MSALAccount *)account
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
                    authority:(NSString *)authority
                correlationId:(NSUUID *)correlationId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:extraScopesToConsent
                        account:account
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
                            account:(MSALAccount *)account
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenSilentForScopes:scopes
                              account:account
                            authority:nil
                         forceRefresh:NO
                        correlationId:nil
                                apiId:MSALTelemetryApiIdAcquireSilentWithUser
                      completionBlock:completionBlock];
}

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                            account:(MSALAccount *)account
                          authority:(NSString *)authority
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenSilentForScopes:scopes
                              account:account
                            authority:authority
                         forceRefresh:NO
                        correlationId:nil
                                apiId:MSALTelemetryApiIdAcquireSilentWithUserAndAuthority
                      completionBlock:completionBlock];
}

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                            account:(MSALAccount *)account
                          authority:(NSString *)authority
                       forceRefresh:(BOOL)forceRefresh
                      correlationId:(NSUUID *)correlationId
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenSilentForScopes:scopes
                              account:account
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
        MSID_LOG_ERROR(ctx, @"%@ returning with error: (%@, %ld)", operation, error.domain, (long)error.code);
        MSID_LOG_ERROR_PII(ctx, @"%@ returning with error: (%@, %ld) %@", operation, error.domain, (long)error.code, errorDescription);
    }
    
    if (result)
    {
        NSString *hashedAT = [result.accessToken msidTokenHash];
        MSID_LOG_INFO(ctx, @"%@ returning with at: %@ scopes:%@ expiration:%@", operation, _PII_NULLIFY(hashedAT), _PII_NULLIFY(result.scopes), result.expiresOn);
        MSID_LOG_INFO_PII(ctx, @"%@ returning with at: %@ scopes:%@ expiration:%@", operation, hashedAT, result.scopes, result.expiresOn);
    }
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
         extraScopesToConsent:(NSArray<NSString *> *)extraScopesToConsent
                      account:(MSALAccount *)account
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
    params.logComponent = _component;
    params.apiId = apiId;
    params.account = account;
    params.validateAuthority = _validateAuthority;
    params.sliceParameters = _sliceParameters;
    
    MSID_LOG_INFO(params,
             @"-[MSALPublicClientApplication acquireTokenForScopes:%@\n"
              "                               extraScopesToConsent:%@\n"
              "                                            account:%@\n"
              "                                          loginHint:%@\n"
              "                                         uiBehavior:%@\n"
              "                               extraQueryParameters:%@\n"
              "                                          authority:%@\n"
              "                                      correlationId:%@]",
             _PII_NULLIFY(scopes), _PII_NULLIFY(extraScopesToConsent), _PII_NULLIFY(account.homeAccountId), _PII_NULLIFY(loginHint), MSALStringForMSALUIBehavior(uiBehavior), extraQueryParameters, _PII_NULLIFY(authority), correlationId);
    MSID_LOG_INFO_PII(params,
                 @"-[MSALPublicClientApplication acquireTokenForScopes:%@\n"
                  "                               extraScopesToConsent:%@\n"
                  "                                            account:%@\n"
                  "                                          loginHint:%@\n"
                  "                                         uiBehavior:%@\n"
                  "                               extraQueryParameters:%@\n"
                  "                                          authority:%@\n"
                  "                                      correlationId:%@]",
                 scopes, extraScopesToConsent, account.homeAccountId, loginHint, MSALStringForMSALUIBehavior(uiBehavior), extraQueryParameters, authority, correlationId);
    
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
    params.urlSession = [MSALURLSession createMSALSession:params];
    
    MSALInteractiveRequest *request =
    [[MSALInteractiveRequest alloc] initWithParameters:params
                                      extraScopesToConsent:extraScopesToConsent
                                              behavior:uiBehavior
                                            tokenCache:self.tokenCache
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
                            account:(MSALAccount *)account
                          authority:(NSString *)authority
                       forceRefresh:(BOOL)forceRefresh
                      correlationId:(NSUUID *)correlationId
                              apiId:(MSALTelemetryApiId)apiId
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    NSString *authorityString = authority;

    if (!authorityString)
    {
        NSURL *defaultAuthority = self.authority;

        /*
         In the acquire token silent call we assume developer wants to get access token for account's home tenant,
         unless they override the default authority in the public client application with a tenanted authority.
         */
        if ([MSIDAuthority isTenantless:self.authority]
            || [MSIDAuthority isConsumerInstanceURL:self.authority])
        {
            defaultAuthority = [MSIDAuthority cacheUrlForAuthority:self.authority tenantId:account.homeAccountId.tenantId];
        }

        authorityString = defaultAuthority.absoluteString;
    }

    MSALRequestParameters* params = [MSALRequestParameters new];
    params.correlationId = correlationId ? correlationId : [NSUUID new];
    params.account = account;
    params.apiId = apiId;
    params.validateAuthority = _validateAuthority;
    params.sliceParameters = _sliceParameters;
    
    [params setScopesFromArray:scopes];
    
    MSID_LOG_INFO(params,
             @"-[MSALPublicClientApplication acquireTokenSilentForScopes:%@\n"
              "                                                  account:%@\n"
              "                                             forceRefresh:%@\n"
              "                                            correlationId:%@\n]",
             _PII_NULLIFY(scopes), _PII_NULLIFY(account), forceRefresh ? @"Yes" : @"No", correlationId);
    
    
    MSID_LOG_INFO_PII(params,
                 @"-[MSALPublicClientApplication acquireTokenSilentForScopes:%@\n"
                  "                                                  account:%@\n"
                  "                                             forceRefresh:%@\n"
                  "                                            correlationId:%@\n]",
                 scopes, account, forceRefresh ? @"Yes" : @"No", correlationId);
    
    MSALCompletionBlock block = ^(MSALResult *result, NSError *error)
    {
        [MSALPublicClientApplication logOperation:@"acquireTokenSilent" result:result error:error context:params];
        completionBlock(result, error);
    };

    NSError *error = nil;
    if (![params setAuthorityFromString:authorityString error:&error])
    {
        block(nil, error);
        return;
    }
    params.redirectUri = _redirectUri;
    params.clientId = _clientId;
    params.urlSession = [MSALURLSession createMSALSession:params];

    MSALSilentRequest *request = [[MSALSilentRequest alloc] initWithParameters:params
                                                                  forceRefresh:forceRefresh
                                                                    tokenCache:self.tokenCache
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

#pragma mark -
#pragma mark remove account from cache

- (BOOL)removeAccount:(MSALAccount *)account
                error:(NSError * __autoreleasing *)error
{
    if (!account)
    {
        return YES;
    }

    NSError *msidError = nil;

    BOOL result = [self.tokenCache clearCacheForAccount:account.lookupAccountIdentifier
                                            environment:self.authority.msidHostWithPortIfNecessary
                                               clientId:self.clientId
                                                context:nil
                                                  error:&msidError];

    if (msidError && error)
    {
        *error = [MSALErrorConverter MSALErrorFromMSIDError:msidError];
    }

    return result;
}

@end


@implementation MSALPublicClientApplication (Internal)

+ (NSDictionary *)defaultSliceParameters
{
    return @{ DEFAULT_SLICE_PARAMS };
}

@end
