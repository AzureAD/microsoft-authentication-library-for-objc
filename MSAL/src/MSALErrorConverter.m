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

#import "MSALErrorConverter+Internal.h"
#import "MSALResult+Internal.h"
#import "MSALError.h"
#import "MSALOauth2Provider.h"

static NSDictionary *s_errorDomainMapping;
static NSDictionary *s_errorCodeMapping;
static NSDictionary *s_userInfoKeyMapping;
static NSSet *s_recoverableErrorCode;

@implementation MSALErrorConverter

+ (void)initialize
{
    s_errorDomainMapping = @{
                             MSIDErrorDomain : MSALErrorDomain,
                             MSIDOAuthErrorDomain : MSALErrorDomain,
                             MSIDKeychainErrorDomain : NSOSStatusErrorDomain,
                             MSIDHttpErrorCodeDomain : MSALErrorDomain
                             };

    s_errorCodeMapping = @{
                           MSALErrorDomain:@{
                                   // General
                                   @(MSIDErrorInternal) : @(MSALErrorInternal),
                                   @(MSIDErrorInvalidInternalParameter) : @(MSALErrorInternal),
                                   @(MSIDErrorInvalidDeveloperParameter) :@(MSALInternalErrorInvalidParameter),
                                   @(MSIDErrorUnsupportedFunctionality): @(MSALErrorInternal),
                                   @(MSIDErrorMissingAccountParameter): @(MSALInternalErrorAccountRequired),
                                   @(MSIDErrorInteractionRequired): @(MSALErrorInteractionRequired),
                                   @(MSIDErrorServerNonHttpsRedirect) : @(MSALInternalErrorNonHttpsRedirect),
                                   @(MSIDErrorMismatchedAccount): @(MSALInternalErrorMismatchedUser),
                                   @(MSIDErrorRedirectSchemeNotRegistered): @(MSALInternalErrorRedirectSchemeNotRegistered),

                                   // Cache
                                   @(MSIDErrorCacheMultipleUsers) : @(MSALErrorInternal),
                                   @(MSIDErrorCacheBadFormat) : @(MSALErrorInternal),
                                   // Authority Validation
                                   @(MSIDErrorAuthorityValidation) : @(MSALInternalErrorFailedAuthorityValidation),
                                   // Interactive flow
                                   @(MSIDErrorAuthorizationFailed) : @(MSALInternalErrorAuthorizationFailed),
                                   @(MSIDErrorUserCancel) : @(MSALErrorUserCanceled),
                                   @(MSIDErrorSessionCanceledProgrammatically) : @(MSALErrorUserCanceled),
                                   @(MSIDErrorInteractiveSessionStartFailure) : @(MSALErrorInternal),
                                   @(MSIDErrorInteractiveSessionAlreadyRunning) : @(MSALInternalErrorInteractiveSessionAlreadyRunning),
                                   @(MSIDErrorNoMainViewController) : @(MSALInternalErrorNoViewController),
                                   @(MSIDErrorAttemptToOpenURLFromExtension): @(MSALInternalErrorAttemptToOpenURLFromExtension),
                                   @(MSIDErrorUINotSupportedInExtension): @(MSALInternalErrorUINotSupportedInExtension),

                                   // Broker errors
                                   @(MSIDErrorBrokerResponseNotReceived): @(MSALInternalErrorBrokerResponseNotReceived),
                                   @(MSIDErrorBrokerNoResumeStateFound): @(MSALInternalErrorBrokerNoResumeStateFound),
                                   @(MSIDErrorBrokerBadResumeStateFound): @(MSALInternalErrorBrokerBadResumeStateFound),
                                   @(MSIDErrorBrokerMismatchedResumeState): @(MSALInternalErrorBrokerMismatchedResumeState),
                                   @(MSIDErrorBrokerResponseHashMissing): @(MSALInternalErrorBrokerResponseHashMissing),
                                   @(MSIDErrorBrokerCorruptedResponse): @(MSALInternalErrorBrokerCorruptedResponse),
                                   @(MSIDErrorBrokerResponseDecryptionFailed): @(MSALInternalErrorBrokerResponseDecryptionFailed),
                                   @(MSIDErrorBrokerResponseHashMismatch): @(MSALInternalErrorBrokerResponseHashMismatch),
                                   @(MSIDErrorBrokerKeyFailedToCreate): @(MSALInternalErrorBrokerKeyFailedToCreate),
                                   @(MSIDErrorBrokerKeyNotFound): @(MSALInternalErrorBrokerKeyNotFound),
                                   @(MSIDErrorWorkplaceJoinRequired): @(MSALErrorWorkplaceJoinRequired),
                                   @(MSIDErrorBrokerUnknown): @(MSALInternalErrorBrokerUnknown),

                                   // Oauth2 errors
                                   @(MSIDErrorServerOauth) : @(MSALInternalErrorAuthorizationFailed),
                                   @(MSIDErrorServerInvalidResponse) : @(MSALInternalErrorInvalidResponse),
                                   // We don't support this error code in MSAL. This error
                                   // exists specifically for ADAL.
                                   @(MSIDErrorServerRefreshTokenRejected) : @(MSALErrorInternal),
                                   @(MSIDErrorServerInvalidRequest) :@(MSALInternalErrorInvalidRequest),
                                   @(MSIDErrorServerInvalidClient) : @(MSALInternalErrorInvalidClient),
                                   @(MSIDErrorServerInvalidGrant) : @(MSALInternalErrorInvalidGrant),
                                   @(MSIDErrorServerInvalidScope) : @(MSALInternalErrorInvalidScope),
                                   @(MSIDErrorServerUnauthorizedClient): @(MSALInternalErrorUnauthorizedClient),
                                   @(MSIDErrorServerDeclinedScopes): @(MSALErrorServerDeclinedScopes),
                                   @(MSIDErrorServerInvalidState) : @(MSALInternalErrorInvalidState),
                                   @(MSIDErrorServerProtectionPoliciesRequired) : @(MSALErrorServerProtectionPoliciesRequired),
                                   @(MSIDErrorServerUnhandledResponse) : @(MSALInternalErrorUnhandledResponse)
                                   }
                           };
    
    s_userInfoKeyMapping = @{
                             MSIDHTTPHeadersKey : MSALHTTPHeadersKey,
                             MSIDHTTPResponseCodeKey : MSALHTTPResponseCodeKey,
                             MSIDCorrelationIdKey : MSALCorrelationIDKey,
                             MSIDErrorDescriptionKey : MSALErrorDescriptionKey,
                             MSIDOAuthErrorKey: MSALOAuthErrorKey,
                             MSIDOAuthSubErrorKey: MSALOAuthSubErrorKey,
                             MSIDDeclinedScopesKey: MSALDeclinedScopesKey,
                             MSIDGrantedScopesKey: MSALGrantedScopesKey,
                             MSIDUserDisplayableIdkey: MSALDisplayableUserIdKey,
                             MSIDBrokerVersionKey: MSALBrokerVersionKey,
                             MSIDHomeAccountIdkey: MSALHomeAccountIdKey
                             };
    
    s_recoverableErrorCode = [[NSSet alloc] initWithObjects:@(MSALErrorWorkplaceJoinRequired), @(MSALErrorInteractionRequired), @(MSALErrorServerDeclinedScopes), @(MSALErrorServerProtectionPoliciesRequired), @(MSALErrorUserCanceled), nil];
}

+ (NSError *)msalErrorFromMsidError:(NSError *)msidError
{
    return [self msalErrorFromMsidError:msidError classifyErrors:YES msalOauth2Provider:nil];
}

+ (NSError *)msalErrorFromMsidError:(NSError *)msidError
                     classifyErrors:(BOOL)shouldClassifyErrors
                 msalOauth2Provider:(MSALOauth2Provider *)oauth2Provider
{
    return [self errorWithDomain:msidError.domain
                            code:msidError.code
                errorDescription:msidError.userInfo[MSIDErrorDescriptionKey]
                      oauthError:msidError.userInfo[MSIDOAuthErrorKey]
                        subError:msidError.userInfo[MSIDOAuthSubErrorKey]
                 underlyingError:msidError.userInfo[NSUnderlyingErrorKey]
                   correlationId:msidError.userInfo[MSIDCorrelationIdKey]
                        userInfo:msidError.userInfo
                  classifyErrors:shouldClassifyErrors
              msalOauth2Provider:oauth2Provider];
}

+ (NSError *)errorWithDomain:(NSString *)domain
                        code:(NSInteger)code
            errorDescription:(NSString *)errorDescription
                  oauthError:(NSString *)oauthError
                    subError:(NSString *)subError
             underlyingError:(NSError *)underlyingError
               correlationId:(NSUUID *)correlationId
                    userInfo:(NSDictionary *)userInfo
              classifyErrors:(BOOL)shouldClassifyErrors
          msalOauth2Provider:(MSALOauth2Provider *)oauth2Provider
{
    if ([NSString msidIsStringNilOrBlank:domain])
    {
        return nil;
    }
    
    // Map domain
    NSString *mappedDomain = s_errorDomainMapping[domain];
    
    // Map errorCode
    // errorCode mapping is needed only if domain is mapped to MSALErrorDomain
    NSNumber *mappedCode = nil;
    NSNumber *internalCode = nil;
    if ([mappedDomain isEqualToString:MSALErrorDomain])
    {
        mappedCode = s_errorCodeMapping[mappedDomain][@(code)];
        if (mappedCode == nil)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning,nil, @"MSALErrorConverter could not find the error code mapping entry for domain (%@) + error code (%ld).", domain, (long)code);
            mappedCode = @(MSALErrorInternal);
        }
    }
    else if ([domain isEqualToString:MSALErrorDomain])
    {
        mappedCode = @(code);
    }
    
    if (shouldClassifyErrors && mappedCode != nil && ![s_recoverableErrorCode containsObject:mappedCode])
    {
        // If mapped code is MSALErrorInternal, set internalCode to MSALInternalErrorUnexpected
        // to avoid the case when both mapped and internal code are MSALErrorInternal.
        internalCode = [mappedCode isEqual:@(MSALErrorInternal)] ? @(MSALInternalErrorUnexpected) : mappedCode;
        mappedCode = @(MSALErrorInternal);
    }
    
    NSMutableDictionary *msalUserInfo = [NSMutableDictionary new];

    for (NSString *key in [userInfo allKeys])
    {
        NSString *mappedKey = s_userInfoKeyMapping[key] ? s_userInfoKeyMapping[key] : key;
        msalUserInfo[mappedKey] = userInfo[key];
    }

    msalUserInfo[MSALErrorDescriptionKey] = errorDescription;
    msalUserInfo[MSALOAuthErrorKey] = oauthError;
    msalUserInfo[MSALOAuthSubErrorKey] = subError;
    msalUserInfo[NSUnderlyingErrorKey] = underlyingError;
    msalUserInfo[MSALInternalErrorCodeKey] = internalCode;

    if (userInfo[MSIDInvalidTokenResultKey] && oauth2Provider)
    {
        NSError *resultError = nil;
        MSALResult *msalResult = [oauth2Provider resultWithTokenResult:userInfo[MSIDInvalidTokenResultKey] error:&resultError];

        if (!msalResult)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"MSALErrorConverter could not convert MSIDTokenResult to MSALResult %@", MSID_PII_LOG_MASKABLE(resultError));
        }
        else
        {
            msalUserInfo[MSALInvalidResultKey] = msalResult;
        }

        [msalUserInfo removeObjectForKey:MSIDInvalidTokenResultKey];
    }

    return [NSError errorWithDomain:mappedDomain ? : domain
                               code:(mappedCode != nil) ? mappedCode.integerValue : code
                           userInfo:msalUserInfo];
}

@end
