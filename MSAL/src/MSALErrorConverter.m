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

#import "MSALErrorConverter.h"
#import "MSALError_Internal.h"

static NSDictionary *s_errorDomainMapping;
static NSDictionary *s_errorCodeMapping;
static NSDictionary *s_userInfoKeyMapping;

@implementation MSALErrorConverter

+ (void)load
{
    MSIDErrorConverter.errorConverter = [MSALErrorConverter new];
}

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
                                   // Cache
                                   @(MSIDErrorCacheMultipleUsers) : @(MSALErrorInternal),
                                   @(MSIDErrorCacheBadFormat) : @(MSALErrorWrapperCacheFailure),
                                   // Authority Validation
                                   @(MSIDErrorAuthorityValidation) : @(MSALErrorFailedAuthorityValidation),
                                   // Interactive flow
                                   @(MSIDErrorAuthorizationFailed) : @(MSALErrorAuthorizationFailed),
                                   @(MSIDErrorUserCancel) : @(MSALErrorUserCanceled),
                                   @(MSIDErrorSessionCanceledProgrammatically) : @(MSALErrorSessionCanceled),
                                   @(MSIDErrorInteractiveSessionStartFailure) : @(MSALErrorInternal),
                                   @(MSIDErrorInteractiveSessionAlreadyRunning) : @(MSALErrorInteractiveSessionAlreadyRunning),
                                   @(MSIDErrorNoMainViewController) : @(MSALErrorNoViewController),
                                   // Oauth2 errors
                                   @(MSIDErrorInteractionRequired) : @(MSALErrorInteractionRequired),
                                   @(MSIDErrorServerOauth) : @(MSALErrorAuthorizationFailed),
                                   @(MSIDErrorServerInvalidResponse) : @(MSALErrorInvalidResponse),
                                   @(MSIDErrorServerRefreshTokenRejected) : @(MSALErrorRefreshTokenRejected),
                                   @(MSIDErrorServerInvalidRequest) :@(MSALErrorInvalidRequest),
                                   @(MSIDErrorServerInvalidClient) : @(MSALErrorInvalidClient),
                                   @(MSIDErrorServerInvalidGrant) : @(MSALErrorInvalidGrant),
                                   @(MSIDErrorServerInvalidScope) : @(MSALErrorInvalidScope),
                                   @(MSIDErrorServerInvalidState) : @(MSALErrorInvalidState),
                                   @(MSIDErrorServerNonHttpsRedirect) : @(MSALErrorNonHttpsRedirect),
                                   @(MSIDErrorServerProtectionPoliciesRequired) : @(MSALErrorServerProtectionPoliciesRequired),
                                   @(MSIDErrorServerUnhandledResponse) : @(MSALErrorUnhandledResponse)
                                   },
                           MSIDHttpErrorCodeDomain: @{
                                   @(MSIDErrorServerUnhandledResponse) : @(MSALErrorUnhandledResponse)
                                   }
                           };
    
    s_userInfoKeyMapping = @{
                             MSIDHTTPHeadersKey : MSALHTTPHeadersKey,
                             MSIDHTTPResponseCodeKey : MSALHTTPResponseCodeKey,
                             MSIDCorrelationIdKey : MSALCorrelationIDKey,
                             MSIDErrorDescriptionKey : MSALErrorDescriptionKey,
                             MSIDOAuthErrorKey: MSALOAuthErrorKey,
                             MSIDOAuthSubErrorKey: MSALOAuthSubErrorKey
                             };
}

#pragma mark - MSIDErrorConverting

- (NSError *)errorWithDomain:(NSString *)domain
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

    NSString *msalDomain = domain;

    // Map domain
    NSString *newDomain = s_errorDomainMapping[domain];
    if (newDomain)
    {
        msalDomain = newDomain;
    }

    // Map errorCode
    // errorCode mapping is needed only if domain is mapped
    NSInteger msalErrorCode = code;
    if (msalDomain && msalErrorCode && s_errorCodeMapping[msalDomain])
    {
        NSNumber *mappedErrorCode = s_errorCodeMapping[msalDomain][@(msalErrorCode)];
        if (mappedErrorCode != nil)
        {
            msalErrorCode = [mappedErrorCode integerValue];
        }
        else
        {
            MSID_LOG_WARN(nil, @"MSALErrorConverter could not find the error code mapping entry for domain (%@) + error code (%ld).", domain, (long)msalErrorCode);
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

    return [NSError errorWithDomain:msalDomain code:msalErrorCode userInfo:msalUserInfo];
}

@end
