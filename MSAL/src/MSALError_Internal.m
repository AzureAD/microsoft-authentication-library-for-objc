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

#import "MSALError_Internal.h"

#define STRING_CASE(_CASE) case _CASE: return @#_CASE

NSString *MSALStringForErrorCode(MSALErrorCode code)
{
    switch (code)
    {
        STRING_CASE(MSALErrorInvalidParameter);
        STRING_CASE(MSALErrorInvalidClient);
        STRING_CASE(MSALErrorInvalidRequest);
        STRING_CASE(MSALErrorRedirectSchemeNotRegistered);
        STRING_CASE(MSALErrorMismatchedUser);
        STRING_CASE(MSALErrorNetworkFailure);
        STRING_CASE(MSALErrorTokenCacheItemFailure);
        STRING_CASE(MSALErrorWrapperCacheFailure);
        STRING_CASE(MSALErrorAmbiguousAuthority);
        STRING_CASE(MSALErrorInteractionRequired);
        STRING_CASE(MSALErrorInvalidResponse);
        STRING_CASE(MSALErrorBadAuthorizationResponse);
        STRING_CASE(MSALErrorAuthorizationFailed);
        STRING_CASE(MSALErrorNoAccessTokenInResponse);
        STRING_CASE(MSALErrorNoAuthorizationResponse);
        STRING_CASE(MSALErrorUserCanceled);
        STRING_CASE(MSALErrorSessionCanceled);
        STRING_CASE(MSALErrorInteractiveSessionAlreadyRunning);
        STRING_CASE(MSALErrorInvalidState);
        STRING_CASE(MSALErrorNoViewController);
        STRING_CASE(MSALErrorInternal);
        STRING_CASE(MSALErrorUserNotFound);
            
        default:
            return [NSString stringWithFormat:@"Unmapped Error %ld", (long)code];
    }
}

MSALErrorCode MSALErrorCodeForOAuthError(NSString *oauthError, MSALErrorCode defaultCode)
{
    if ([oauthError isEqualToString:@"invalid_request"])
    {
        return MSALErrorInvalidRequest;
    }
    if ([oauthError isEqualToString:@"invalid_client"])
    {
        return MSALErrorInvalidClient;
    }
    if ([oauthError isEqualToString:@"invalid_scope"])
    {
        return MSALErrorInvalidParameter;
    }
    
    return defaultCode;
}

void MSALLogError(id<MSALRequestContext> ctx, NSString *domain, NSInteger code, NSString *errorDescription, NSString *oauthError, NSString *subError, const char *function, int line)
{
    NSString *codeString;
    if ([domain isEqualToString:MSALErrorDomain])
    {
        codeString = MSALStringForErrorCode(code);
    }
    else
    {
        codeString = domain;
    }
    
    NSMutableString *message = [codeString mutableCopy];
    if (oauthError)
    {
        [message appendFormat:@": {OAuth Error \"%@\" SubError: \"%@\" Description:\"%@\"}", oauthError, subError, errorDescription];
    }
    else
    {
        [message appendFormat:@": %@", errorDescription];
    }
    
    [message appendFormat:@" (%s:%d)", function, line];
    LOG_ERROR(ctx, @"%@", message);
    LOG_ERROR_PII(ctx, @"%@", message);
}

NSError *MSALCreateError(NSString *domain, NSInteger code, NSString *errorDescription, NSString *oauthError, NSString *subError, NSError* underlyingError)
{
    NSMutableDictionary* userInfo = [NSMutableDictionary new];
    userInfo[MSALErrorDescriptionKey] = errorDescription;
    userInfo[MSALOAuthErrorKey] = oauthError;
    userInfo[MSALOAuthSubErrorKey] = subError;
    userInfo[NSUnderlyingErrorKey]  = underlyingError;
    
    return [NSError errorWithDomain:domain code:code userInfo:[NSDictionary dictionaryWithDictionary:userInfo]];
}

NSError *MSALCreateAndLogError(id<MSALRequestContext> ctx, NSString *domain, NSInteger code, NSString *oauthError, NSString *subError, NSError *underlyingError, const char *function, int line, NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *description = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    MSALLogError(ctx, domain, code, description, oauthError, subError, function, line);
    return MSALCreateError(domain, code, description, oauthError, subError, underlyingError);
}

void MSALFillAndLogError(NSError * __autoreleasing * error, id<MSALRequestContext> ctx, NSString *domain, NSInteger code, NSString *oauthError, NSString *subError, NSError *underlyingError, const char *function, int line, NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *description = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    MSALLogError(ctx, domain, code, description, oauthError, subError, function, line);
    if (error)
    {
        *error = MSALCreateError(domain, code, description, oauthError, subError, underlyingError);
    }
}
