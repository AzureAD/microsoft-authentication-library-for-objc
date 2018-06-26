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

+ (void)initialize
{
    s_errorDomainMapping = @{
                             MSIDErrorDomain : MSALErrorDomain,
                             MSIDOAuthErrorDomain : MSALErrorDomain,
                             MSIDKeychainErrorDomain : NSOSStatusErrorDomain,
                             };
    
    s_errorCodeMapping = @{
                           MSIDErrorDomain:@{
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
                                   },
                           MSIDOAuthErrorDomain:@{
                                   @(MSIDErrorInteractionRequired) : @(MSALErrorInteractionRequired),
                                   @(MSIDErrorServerOauth) : @(MSALErrorAuthorizationFailed),
                                   @(MSIDErrorServerInvalidResponse) : @(MSALErrorInvalidResponse),
                                   @(MSIDErrorServerRefreshTokenRejected) : @(MSALErrorRefreshTokenRejected),
                                   @(MSIDErrorServerInvalidRequest) :@(MSALErrorInvalidRequest),
                                   @(MSIDErrorServerInvalidClient) : @(MSALErrorInvalidClient),
                                   @(MSIDErrorServerInvalidGrant) : @(MSALErrorInvalidGrant),
                                   @(MSIDErrorServerInvalidScope) : @(MSALErrorInvalidScope),
                                   @(MSIDErrorServerInvalidState) : @(MSALErrorInvalidState),
                                   @(MSIDErrorServerNonHttpsRedirect) : @(MSALErrorNonHttpsRedirect)
                                   }
                           };
    
    s_userInfoKeyMapping = @{
                             MSIDHTTPHeadersKey : MSALHTTPHeadersKey,
                             MSIDHTTPResponseCodeKey : MSALHTTPResponseCodeKey
                             };
}

+ (NSError *)MSALErrorFromMSIDError:(NSError *)msidError
{
    if (!msidError)
    {
        return nil;
    }
    
    //Map domain
    NSString *domain = msidError.domain;
    if (domain && s_errorDomainMapping[domain])
    {
        domain = s_errorDomainMapping[domain];
    }
    
    // Map errorCode
    // errorCode mapping is needed only if domain is in s_errorCodeMapping
    NSInteger errorCode = msidError.code;
    if (msidError.domain && msidError.code && s_errorCodeMapping[msidError.domain])
    {
        NSNumber *mappedErrorCode = s_errorCodeMapping[msidError.domain][@(msidError.code)];
        if (mappedErrorCode)
        {
            errorCode = [mappedErrorCode integerValue];
        }
        else
        {
            MSID_LOG_ERROR(nil, @"MSALErrorConverter could not find the error code mapping entry for domain (%@) + error code (%ld).", msidError.domain, (long)msidError.code);
        }
    }
    
    NSMutableDictionary *userInfo = [NSMutableDictionary new];
    
    for (NSString *key in [msidError.userInfo allKeys])
    {
        NSString *mappedKey = s_userInfoKeyMapping[key] ? s_userInfoKeyMapping[key] : key;
        userInfo[mappedKey] = msidError.userInfo[key];
    }
    
    return MSALCreateError(domain,
                           errorCode,
                           msidError.userInfo[MSIDErrorDescriptionKey],
                           msidError.userInfo[MSIDOAuthErrorKey],
                           msidError.userInfo[MSIDOAuthSubErrorKey],
                           msidError.userInfo[NSUnderlyingErrorKey],
                           userInfo);
    
}

@end
