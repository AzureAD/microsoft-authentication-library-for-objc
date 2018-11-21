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
#import "MSALError.h"
#import "MSALError_Internal.h"
#import "MSALUIBehavior_Internal.h"

#import "MSALTelemetryApiId.h"
#import "MSALTelemetry.h"
#if TARGET_OS_IPHONE
#import "MSIDKeychainTokenCache.h"
#import "MSIDCertAuthHandler+iOS.h"
#endif
#import "MSIDMacTokenCache.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccount.h"
#import "NSURL+MSIDExtensions.h"
#import "MSALAccount+Internal.h"
#import "MSIDRefreshToken.h"
#import "MSIDAADV2IdTokenClaims.h"
#import "MSALErrorConverter.h"
#import "MSALAccountId.h"
#import "MSALAuthority.h"
#import "MSALAuthority_Internal.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDAADAuthority.h"
#import "MSIDAuthorityFactory.h"
#import "MSALAADAuthority.h"
#import "MSALOauth2FactoryProducer.h"

static NSString *const s_defaultAuthorityUrlString = @"https://login.microsoftonline.com/common";

#import "MSIDAuthority.h"

#import "MSIDAADV2Oauth2Factory.h"
#import "MSALRedirectUriVerifier.h"

#import "MSIDWebviewAuthorization.h"
#import "MSIDWebviewSession.h"
#import "MSALAccountsProvider.h"
#import "MSIDAADNetworkConfiguration.h"
#import "MSALResult.h"
#import "MSIDRequestControllerFactory.h"
#import "MSIDRequestParameters.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDDefaultTokenRequestProvider.h"

@interface MSALPublicClientApplication()
{
    WKWebView *_customWebview;
    NSString *_defaultKeychainGroup;
    MSIDOauth2Factory *_oauth2Factory;
}

@property (nonatomic) MSIDDefaultTokenCacheAccessor *tokenCache;
#if TARGET_OS_IPHONE
@property (nonatomic, readwrite) NSString *keychainGroup;
#endif

@end

@implementation MSALPublicClientApplication

- (NSString *)defaultKeychainGroup
{
#if TARGET_OS_IPHONE
    return MSIDKeychainTokenCache.defaultKeychainGroup;
#else
    return nil;
#endif
}

// Make sure scheme is registered in info.plist
// If broker is enabled, make sure redirect uri has bundle id in it
// If no redirect uri is provided, generate a default one, which is compatible with broker if broker is enabled
- (BOOL)verifyRedirectUri:(NSString *)redirectUriString
                 clientId:(NSString *)clientId
                    error:(NSError * __autoreleasing *)error
{
    NSURL *generatedRedirectUri = [MSALRedirectUriVerifier generateRedirectUri:redirectUriString
                                                                      clientId:clientId
                                                                 brokerEnabled:NO
                                                                         error:error];

    if (!generatedRedirectUri)
    {
        return NO;
    }

    _redirectUri = generatedRedirectUri.absoluteString;

    return [MSALRedirectUriVerifier verifyRedirectUri:generatedRedirectUri
                                        brokerEnabled:NO
                                                error:error];
}

- (id)initWithClientId:(NSString *)clientId
                 error:(NSError * __autoreleasing *)error
{
    return [self initWithClientId:clientId
                    keychainGroup:self.defaultKeychainGroup
                        authority:nil
                      redirectUri:nil
                            error:error];
}

- (id)initWithClientId:(NSString *)clientId
             authority:(MSALAuthority *)authority
                 error:(NSError **)error
{
    return [self initWithClientId:clientId
                    keychainGroup:self.defaultKeychainGroup
                        authority:authority
                      redirectUri:nil
                            error:error];
}

- (id)initWithClientId:(NSString *)clientId
             authority:(MSALAuthority *)authority
           redirectUri:(NSString *)redirectUri
                 error:(NSError **)error
{
    return [self initWithClientId:clientId
                    keychainGroup:self.defaultKeychainGroup
                        authority:authority
                      redirectUri:redirectUri
                            error:error];
}

#if TARGET_OS_IPHONE

- (id)initWithClientId:(NSString *)clientId
         keychainGroup:(NSString *)keychainGroup
                 error:(NSError * __autoreleasing *)error
{
    return [self initWithClientId:clientId
                    keychainGroup:keychainGroup
                        authority:nil
                      redirectUri:nil
                            error:error];
}

- (id)initWithClientId:(NSString *)clientId
         keychainGroup:(NSString *)keychainGroup
             authority:(MSALAuthority *)authority
                 error:(NSError * __autoreleasing *)error
{
    return [self initWithClientId:clientId
                    keychainGroup:keychainGroup
                        authority:authority
                      redirectUri:nil
                            error:error];
}

#endif

- (id)initWithClientId:(NSString *)clientId
         keychainGroup:(NSString *)keychainGroup
             authority:(MSALAuthority *)authority
           redirectUri:(NSString *)redirectUri
                 error:(NSError * __autoreleasing *)error
{
    if (!(self = [super init]))
    {
        return nil;
    }

    if ([NSString msidIsStringNilOrBlank:clientId])
    {
        MSAL_ERROR_PARAM(nil, MSALErrorInvalidParameter, @"clientId is a required parameter and must not be nil or empty.");
        return nil;
    }

    _clientId = clientId;

    if (authority)
    {
        _authority = authority;
    }
    else
    {
        // TODO: Rationalize our default authority behavior (#93)
        NSURL *authorityURL = [NSURL URLWithString:s_defaultAuthorityUrlString];
        _authority = [[MSALAADAuthority alloc] initWithURL:authorityURL context:nil error:error];
    }

    _oauth2Factory = [MSALOauth2FactoryProducer msidOauth2FactoryForAuthority:_authority.url context:nil error:error];

    if (!_oauth2Factory)
    {
        MSID_LOG_ERROR(nil, @"Couldn't create Oauth2 factory");
        return nil;
    }

    BOOL redirectUriValid = [self verifyRedirectUri:redirectUri clientId:clientId error:error];

    if (!redirectUriValid) return nil;

#if TARGET_OS_IPHONE
    // Optional Paramater
    _keychainGroup = keychainGroup;

    MSIDKeychainTokenCache *dataSource;
    if (_keychainGroup == nil)
    {
        _keychainGroup = [[NSBundle mainBundle] bundleIdentifier];
    }
    
    dataSource = [[MSIDKeychainTokenCache alloc] initWithGroup:_keychainGroup];

    MSIDLegacyTokenCacheAccessor *legacyAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil factory:_oauth2Factory];
    MSIDDefaultTokenCacheAccessor *defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:@[legacyAccessor] factory:_oauth2Factory];
    
    self.tokenCache = defaultAccessor;
    
    _webviewType = MSALWebviewTypeDefault;
    
#else
    __auto_type dataSource = MSIDMacTokenCache.defaultCache;

    MSIDDefaultTokenCacheAccessor *defaultAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:dataSource otherCacheAccessors:nil factory:_oauth2Factory];
    self.tokenCache = defaultAccessor;
    _webviewType = MSALWebviewTypeWKWebView;
    
#endif
    
    _validateAuthority = YES;
    _extendedLifetimeEnabled = NO;
    
    _sliceParameters = [MSALPublicClientApplication defaultSliceParameters];
    
    MSIDAADNetworkConfiguration.defaultConfiguration.aadApiVersion = @"v2.0";
    _expirationBuffer = 300;  //in seconds, ensures catching of clock differences between the server and the device
    
    return self;
}

#pragma mark - Accounts

- (NSArray <MSALAccount *> *)allAccounts:(NSError * __autoreleasing *)error
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                          clientId:self.clientId];
    return [request allAccounts:error];
}

- (MSALAccount *)accountForHomeAccountId:(NSString *)homeAccountId
                                   error:(NSError * __autoreleasing *)error
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                          clientId:self.clientId];
    return [request accountForHomeAccountId:homeAccountId error:error];
}

- (MSALAccount *)accountForUsername:(NSString *)username
                              error:(NSError * __autoreleasing *)error
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                          clientId:self.clientId];
    return [request accountForUsername:username error:error];
}

- (void)allAccountsFilteredByAuthority:(MSALAccountsCompletionBlock)completionBlock
{
    MSALAccountsProvider *request = [[MSALAccountsProvider alloc] initWithTokenCache:self.tokenCache
                                                                          clientId:self.clientId];

    [request allAccountsFilteredByAuthority:self.authority completionBlock:completionBlock];
}

#pragma SafariViewController Support

#if TARGET_OS_IPHONE
+ (BOOL)handleMSALResponse:(NSURL *)response
{
    if ([MSIDWebviewAuthorization handleURLResponseForSystemWebviewController:response])
    {
        return YES;
    }
    
    return [MSIDCertAuthHandler completeCertAuthChallenge:response];
}
#endif

+ (BOOL)cancelCurrentWebAuthSession
{
    if ([MSIDWebviewAuthorization currentSession])
    {
        [MSIDWebviewAuthorization cancelCurrentSession];
        return YES;
    }
    
    return NO;
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
                         claims:nil
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
                         claims:nil
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
                         claims:nil
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
                    authority:(MSALAuthority *)authority
                correlationId:(NSUUID *)correlationId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:extraScopesToConsent
                        account:nil
                      loginHint:loginHint
                     uiBehavior:uiBehavior
           extraQueryParameters:extraQueryParameters
                         claims:nil
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
                         claims:nil
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
                         claims:nil
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
                    authority:(MSALAuthority *)authority
                correlationId:(NSUUID *)correlationId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:extraScopesToConsent
                        account:account
                      loginHint:nil
                     uiBehavior:uiBehavior
           extraQueryParameters:extraQueryParameters
                         claims:nil
                      authority:authority
                  correlationId:correlationId
                          apiId:MSALTelemetryApiIdAcquireWithUserBehaviorParametersAuthorityAndCorrelationId
                completionBlock:completionBlock];
    
}

- (void)acquireTokenForScopes:(NSArray<NSString *> *)scopes
         extraScopesToConsent:(NSArray<NSString *> *)extraScopesToConsent
                      account:(MSALAccount *)account
                   uiBehavior:(MSALUIBehavior)uiBehavior
         extraQueryParameters:(NSDictionary <NSString *, NSString *> *)extraQueryParameters
                       claims:(NSString *)claims
                    authority:(MSALAuthority *)authority
                correlationId:(NSUUID *)correlationId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenForScopes:scopes
           extraScopesToConsent:extraScopesToConsent
                        account:account
                      loginHint:nil
                     uiBehavior:uiBehavior
           extraQueryParameters:extraQueryParameters
                         claims:claims
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
                               claims:nil
                         forceRefresh:NO
                        correlationId:nil
                                apiId:MSALTelemetryApiIdAcquireSilentWithUser
                      completionBlock:completionBlock];
}

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                            account:(MSALAccount *)account
                          authority:(MSALAuthority *)authority
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenSilentForScopes:scopes
                              account:account
                            authority:authority
                               claims:nil
                         forceRefresh:NO
                        correlationId:nil
                                apiId:MSALTelemetryApiIdAcquireSilentWithUserAndAuthority
                      completionBlock:completionBlock];
}

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                            account:(MSALAccount *)account
                          authority:(MSALAuthority *)authority
                       forceRefresh:(BOOL)forceRefresh
                      correlationId:(NSUUID *)correlationId
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    [self acquireTokenSilentForScopes:scopes
                              account:account
                            authority:authority
                               claims:nil
                         forceRefresh:forceRefresh
                        correlationId:correlationId
                                apiId:MSALTelemetryApiIdAcquireSilentWithUserAuthorityForceRefreshAndCorrelationId
                      completionBlock:completionBlock];
}

- (void)acquireTokenSilentForScopes:(nonnull NSArray<NSString *> *)scopes
                            account:(nonnull MSALAccount *)account
                          authority:(nullable MSALAuthority *)authority
                             claims:(nullable NSString *)claims
                       forceRefresh:(BOOL)forceRefresh
                      correlationId:(nullable NSUUID *)correlationId
                    completionBlock:(nonnull MSALCompletionBlock)completionBlock
{
    [self acquireTokenSilentForScopes:scopes
                              account:account
                            authority:authority
                               claims:claims
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
             context:(id<MSIDRequestContext>)ctx
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
                       claims:(NSString *)claims
                    authority:(MSALAuthority *)authority
                correlationId:(NSUUID *)correlationId
                        apiId:(MSALTelemetryApiId)apiId
              completionBlock:(MSALCompletionBlock)completionBlock
{
    MSIDInteractiveRequestParameters *params = [MSIDInteractiveRequestParameters new];
    params.requestType = MSIDInteractiveRequestBrokeredType; // TODO: allow disabling broker
    params.uiBehaviorType = MSIDUIBehaviorPromptAlwaysType;
    params.loginHint = loginHint;
    params.useEmbeddedWebView = NO; // TODO: setup this correctly
    params.useSafariViewController = NO; // TODO: setup this correctly
    params.customWebview = _customWebview;
    params.parentViewController = nil; // TODO: no way to set this now
    params.extraScopesToConsent = [extraScopesToConsent componentsJoinedByString:@" "];
    params.promptType = MSALParameterStringForBehavior(uiBehavior);
    params.extraQueryParameters = extraQueryParameters;
    params.telemetryWebviewType = nil; // TODO: setup this correctly
    params.supportedBrokerProtocolScheme = @"msauth2"; // TODO: put it into constants
    params.authority = authority.msidAuthority ?: _authority.msidAuthority;
    params.redirectUri = _redirectUri;
    params.clientId = _clientId;
    params.target = [scopes componentsJoinedByString:@" "];
    params.oidcScope = @"openid offline_access profile";
    params.accountIdentifier = account.lookupAccountIdentifier;
    params.validateAuthority = _validateAuthority;
    params.sliceParameters = _sliceParameters;
    params.tokenExpirationBuffer = _expirationBuffer;
    params.extendedLifetimeEnabled = _extendedLifetimeEnabled;
    params.correlationId = correlationId ? correlationId : [NSUUID new];
    params.logComponent = @"MSAL";
    params.telemetryRequestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    params.telemetryApiId = [NSString stringWithFormat:@"%ld", (long)apiId];
    params.clientCapabilities = _clientCapabilities;
    
    MSID_LOG_INFO(params,
             @"-[MSALPublicClientApplication acquireTokenForScopes:%@\n"
              "                               extraScopesToConsent:%@\n"
              "                                            account:%@\n"
              "                                          loginHint:%@\n"
              "                                         uiBehavior:%@\n"
              "                               extraQueryParameters:%@\n"
              "                                          authority:%@\n"
              "                                      correlationId:%@\n"
              "                                       capabilities:%@\n"
              "                                             claims:%@]",
             _PII_NULLIFY(scopes), _PII_NULLIFY(extraScopesToConsent), _PII_NULLIFY(account.homeAccountId), _PII_NULLIFY(loginHint), MSALStringForMSALUIBehavior(uiBehavior), extraQueryParameters, _PII_NULLIFY(authority), correlationId, _clientCapabilities, claims);
    MSID_LOG_INFO_PII(params,
                 @"-[MSALPublicClientApplication acquireTokenForScopes:%@\n"
                  "                               extraScopesToConsent:%@\n"
                  "                                            account:%@\n"
                  "                                          loginHint:%@\n"
                  "                                         uiBehavior:%@\n"
                  "                               extraQueryParameters:%@\n"
                  "                                          authority:%@\n"
                  "                                      correlationId:%@\n"
                  "                                       capabilities:%@\n"
                  "                                             claims:%@]",
                 scopes, extraScopesToConsent, account.homeAccountId, loginHint, MSALStringForMSALUIBehavior(uiBehavior), extraQueryParameters, authority, correlationId, _clientCapabilities, claims);
    
    MSALCompletionBlock block = ^(MSALResult *result, NSError *error)
    {
        [MSALPublicClientApplication logOperation:@"acquireToken" result:result error:error context:params];
        completionBlock(result, error);
    };
    
    NSError *claimsError = nil;

    if (![params setClaimsFromJSON:claims error:&claimsError])
    {
        block(nil, claimsError);
        return;
    }

    NSError *requestError = nil;

    MSIDDefaultTokenRequestProvider *tokenRequestProvider = [[MSIDDefaultTokenRequestProvider alloc] initWithOauthFactory:_oauth2Factory defaultAccessor:_tokenCache];

    id<MSIDRequestControlling> controller = [MSIDRequestControllerFactory interactiveControllerForParameters:params tokenRequestProvider:tokenRequestProvider error:&requestError];

    if (!controller)
    {
        block(nil, requestError);
        return;
    }

    [controller acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        // TODO: create MSALResult from MSIDTokenResult
        // TODO: call completion block
    }];
}

- (void)acquireTokenSilentForScopes:(NSArray<NSString *> *)scopes
                            account:(MSALAccount *)account
                          authority:(MSALAuthority *)authority
                             claims:(NSString *)claims
                       forceRefresh:(BOOL)forceRefresh
                      correlationId:(NSUUID *)correlationId
                              apiId:(MSALTelemetryApiId)apiId
                    completionBlock:(MSALCompletionBlock)completionBlock
{
    MSIDAuthority *msidAuthority = authority.msidAuthority;

    if (!msidAuthority)
    {
        msidAuthority = self.authority.msidAuthority;
    }

    /*
     In the acquire token silent call we assume developer wants to get access token for account's home tenant,
     if authority is a common, organizations or consumers authority.
     */
    msidAuthority = [MSIDAuthorityFactory authorityFromUrl:msidAuthority.url rawTenant:account.homeAccountId.tenantId context:nil error:nil];

    MSIDRequestParameters *params = [MSIDRequestParameters new];
    params.authority = msidAuthority;
    params.correlationId = correlationId ? correlationId : [NSUUID new];
    params.accountIdentifier = account.lookupAccountIdentifier;
    params.telemetryApiId = [NSString stringWithFormat:@"%ld", (long)apiId];
    params.validateAuthority = _validateAuthority;
    params.extendedLifetimeEnabled = _extendedLifetimeEnabled;
    params.clientCapabilities = _clientCapabilities;
    params.sliceParameters = _sliceParameters;
    params.target = [scopes componentsJoinedByString:@" "];
    params.redirectUri = _redirectUri;
    params.clientId = _clientId;
    params.oidcScope = @"openid offline_access profile";
    params.tokenExpirationBuffer = _expirationBuffer;
    params.logComponent = @"MSAL";
    params.telemetryRequestId = [[MSIDTelemetry sharedInstance] generateRequestId];
    
    MSID_LOG_INFO(params,
             @"-[MSALPublicClientApplication acquireTokenSilentForScopes:%@\n"
              "                                                  account:%@\n"
              "                                                authority:%@\n"
              "                                             forceRefresh:%@\n"
              "                                            correlationId:%@\n"
              "                                             capabilities:%@\n"
              "                                                   claims:%@]",
             _PII_NULLIFY(scopes), _PII_NULLIFY(account), _PII_NULLIFY(authority), forceRefresh ? @"Yes" : @"No", correlationId, _clientCapabilities, claims);
    
    
    MSID_LOG_INFO_PII(params,
                 @"-[MSALPublicClientApplication acquireTokenSilentForScopes:%@\n"
                  "                                                  account:%@\n"
                  "                                                authority:%@\n"
                  "                                             forceRefresh:%@\n"
                  "                                            correlationId:%@\n"
                  "                                             capabilities:%@\n"
                  "                                                   claims:%@]",
                 scopes, account, _PII_NULLIFY(authority), forceRefresh ? @"Yes" : @"No", correlationId, _clientCapabilities, claims);
    
    MSALCompletionBlock block = ^(MSALResult *result, NSError *error)
    {
        [MSALPublicClientApplication logOperation:@"acquireTokenSilent" result:result error:error context:params];
        completionBlock(result, error);
    };

    NSError *claimsError = nil;

    if (![params setClaimsFromJSON:claims error:&claimsError])
    {
        block(nil, claimsError);
    }

    MSIDDefaultTokenRequestProvider *tokenRequestProvider = [[MSIDDefaultTokenRequestProvider alloc] initWithOauthFactory:_oauth2Factory defaultAccessor:_tokenCache];

    NSError *requestError = nil;

    id<MSIDRequestControlling> requestController = [MSIDRequestControllerFactory silentControllerForParameters:params forceRefresh:forceRefresh tokenRequestProvider:tokenRequestProvider error:&requestError];

    if (!requestController)
    {
        block(nil, requestError);
        return;
    }

    [requestController acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        // TODO: create MSALResult from MSIDTokenResult
        // TODO: call completion block
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
                                              authority:self.authority.msidAuthority
                                               clientId:self.clientId
                                                context:nil
                                                  error:&msidError];

    if (msidError && error)
    {
        *error = msidError;
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
