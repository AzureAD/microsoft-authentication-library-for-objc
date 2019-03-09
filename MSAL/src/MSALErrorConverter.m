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
#import "MSALError_Internal.h"
#import "MSALResult+Internal.h"

static NSDictionary *s_errorDomainMapping;
static NSDictionary *s_errorCodeMapping;
static NSDictionary *s_userInfoKeyMapping;

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
                                   @(MSIDErrorInvalidDeveloperParameter) :@(MSALErrorInvalidParameter),
                                   @(MSIDErrorUnsupportedFunctionality): @(MSALErrorInternal),
                                   @(MSIDErrorMissingAccountParameter): @(MSALErrorAccountRequired),
                                   @(MSIDErrorInteractionRequired): @(MSALErrorInteractionRequired),
                                   @(MSIDErrorServerNonHttpsRedirect) : @(MSALErrorNonHttpsRedirect),
                                   @(MSIDErrorMismatchedAccount): @(MSALErrorMismatchedUser),

                                   // Cache
                                   @(MSIDErrorCacheMultipleUsers) : @(MSALErrorInternal),
                                   @(MSIDErrorCacheBadFormat) : @(MSALErrorInternal),
                                   // Authority Validation
                                   @(MSIDErrorAuthorityValidation) : @(MSALErrorFailedAuthorityValidation),
                                   // Interactive flow
                                   @(MSIDErrorAuthorizationFailed) : @(MSALErrorAuthorizationFailed),
                                   @(MSIDErrorUserCancel) : @(MSALErrorUserCanceled),
                                   @(MSIDErrorSessionCanceledProgrammatically) : @(MSALErrorSessionCanceled),
                                   @(MSIDErrorInteractiveSessionStartFailure) : @(MSALErrorInternal),
                                   @(MSIDErrorInteractiveSessionAlreadyRunning) : @(MSALErrorInteractiveSessionAlreadyRunning),
                                   @(MSIDErrorNoMainViewController) : @(MSALErrorNoViewController),
                                   @(MSIDErrorAttemptToOpenURLFromExtension): @(MSALErrorAttemptToOpenURLFromExtension),
                                   @(MSIDErrorUINotSupportedInExtension): @(MSALErrorUINotSupportedInExtension),

                                   // Broker errors
                                   @(MSIDErrorBrokerResponseNotReceived): @(MSALErrorBrokerResponseNotReceived),
                                   @(MSIDErrorBrokerNoResumeStateFound): @(MSALErrorBrokerNoResumeStateFound),
                                   @(MSIDErrorBrokerBadResumeStateFound): @(MSALErrorBrokerBadResumeStateFound),
                                   @(MSIDErrorBrokerMismatchedResumeState): @(MSALErrorBrokerMismatchedResumeState),
                                   @(MSIDErrorBrokerResponseHashMissing): @(MSALErrorBrokerResponseHashMissing),
                                   @(MSIDErrorBrokerCorruptedResponse): @(MSALErrorBrokerCorruptedResponse),
                                   @(MSIDErrorBrokerResponseDecryptionFailed): @(MSALErrorBrokerResponseDecryptionFailed),
                                   @(MSIDErrorBrokerResponseHashMismatch): @(MSALErrorBrokerResponseHashMismatch),
                                   @(MSIDErrorBrokerKeyFailedToCreate): @(MSALErrorBrokerKeyFailedToCreate),
                                   @(MSIDErrorBrokerKeyNotFound): @(MSALErrorBrokerKeyNotFound),
                                   @(MSIDErrorWorkplaceJoinRequired): @(MSALErrorWorkplaceJoinRequired),
                                   @(MSIDErrorBrokerUnknown): @(MSALErrorBrokerUnknown),

                                   // Oauth2 errors
                                   @(MSIDErrorServerOauth) : @(MSALErrorAuthorizationFailed),
                                   @(MSIDErrorServerInvalidResponse) : @(MSALErrorInvalidResponse),
                                   // We don't support this error code in MSAL. This error
                                   // exists specifically for ADAL.
                                   @(MSIDErrorServerRefreshTokenRejected) : @(MSALErrorInternal),
                                   @(MSIDErrorServerInvalidRequest) :@(MSALErrorInvalidRequest),
                                   @(MSIDErrorServerInvalidClient) : @(MSALErrorInvalidClient),
                                   @(MSIDErrorServerInvalidGrant) : @(MSALErrorInvalidGrant),
                                   @(MSIDErrorServerInvalidScope) : @(MSALErrorInvalidScope),
                                   @(MSIDErrorServerUnauthorizedClient): @(MSALErrorUnauthorizedClient),
                                   @(MSIDErrorServerDeclinedScopes): @(MSALErrorServerDeclinedScopes),
                                   @(MSIDErrorServerInvalidState) : @(MSALErrorInvalidState),
                                   @(MSIDErrorServerProtectionPoliciesRequired) : @(MSALErrorServerProtectionPoliciesRequired),
                                   @(MSIDErrorServerUnhandledResponse) : @(MSALErrorUnhandledResponse)
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
}

+ (NSError *)msalErrorFromMsidError:(NSError *)msidError
{
    return [self errorWithDomain:msidError.domain
                            code:msidError.code
                errorDescription:msidError.userInfo[MSIDErrorDescriptionKey]
                      oauthError:msidError.userInfo[MSIDOAuthErrorKey]
                        subError:msidError.userInfo[MSIDOAuthSubErrorKey]
                 underlyingError:msidError.userInfo[NSUnderlyingErrorKey]
                   correlationId:msidError.userInfo[MSIDCorrelationIdKey]
                        userInfo:msidError.userInfo];
}

+ (NSError *)errorWithDomain:(NSString *)domain
                        code:(NSInteger)code
            errorDescription:(NSString *)errorDescription
                  oauthError:(NSString *)oauthError
                    subError:(NSString *)subError
             underlyingError:(NSError *)underlyingError
               correlationId:(NSUUID *)correlationId
                    userInfo:(NSDictionary *)userInfo
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
    if (mappedDomain == MSALErrorDomain)
    {
        mappedCode = s_errorCodeMapping[mappedDomain][@(code)];
        if (!mappedCode)
        {
            MSID_LOG_WARN(nil, @"MSALErrorConverter could not find the error code mapping entry for domain (%@) + error code (%ld).", domain, (long)code);
            mappedCode = @(MSALErrorInternal);
        }
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
    msalUserInfo[NSUnderlyingErrorKey]  = underlyingError;

    if (userInfo[MSIDInvalidTokenResultKey])
    {
        NSError *resultError = nil;
        MSALResult *msalResult = [MSALResult resultWithTokenResult:userInfo[MSIDInvalidTokenResultKey] error:&resultError];

        if (!msalResult)
        {
            MSID_LOG_WARN(nil, @"MSALErrorConverter could not convert MSIDTokenResult to MSALResult %ld, %@", (long)resultError.code, resultError.domain);
            MSID_LOG_WARN_PII(nil, @"MSALErrorConverter could not convert MSIDTokenResult to MSALResult %@", resultError);
        }
        else
        {
            msalUserInfo[MSALInvalidResultKey] = msalResult;
        }

        [msalUserInfo removeObjectForKey:MSIDInvalidTokenResultKey];
    }

    return [NSError errorWithDomain:mappedDomain ? : domain
                               code:mappedCode ? mappedCode.integerValue : code
                           userInfo:msalUserInfo];
}

@end
