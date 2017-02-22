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
        STRING_CASE(MSALErrorRedirectSchemeNotRegistered);
        STRING_CASE(MSALErrorMismatchedUser);
        STRING_CASE(MSALErrorNetworkFailure);
        STRING_CASE(MSALErrorKeychainFailure);
        STRING_CASE(MSALErrorInteractionRequired);
        STRING_CASE(MSALErrorInvalidResponse);
        STRING_CASE(MSALErrorBadAuthorizationResponse);
        STRING_CASE(MSALErrorAuthorizationFailed);
        STRING_CASE(MSALErrorNoAuthorizationResponse);
        STRING_CASE(MSALErrorUserCanceled);
        STRING_CASE(MSALErrorSessionCanceled);
        STRING_CASE(MSALErrorInteractiveSessionAlreadyRunning);
        STRING_CASE(MSALErrorInvalidState);
        STRING_CASE(MSALErrorNoViewController);
        STRING_CASE(MSALErrorInternal);
    }
}

void MSALLogError(id<MSALRequestContext> ctx, MSALErrorCode code, NSString *errorDescription, NSString *oauthError, const char *function, int line)
{
    NSString* codeString = MSALStringForErrorCode(code);
    if (oauthError)
    {
        LOG_ERROR(ctx, @"%@ from \"%@\" - %@ (%s:%d)", codeString, oauthError, errorDescription, function, line);
    }
    else
    {
        LOG_ERROR(ctx, @"%@ - %@ (%s:%d)", codeString, errorDescription, function, line);
    }
}

NSError* MSALCreateError(MSALErrorCode code, NSString *errorDescription, NSString *oauthError, NSError* underlyingError)
{
    NSMutableDictionary* userInfo = [NSMutableDictionary new];
    userInfo[MSALErrorDescriptionKey] = errorDescription;
    userInfo[MSALOAuthErrorKey] = oauthError;
    userInfo[NSUnderlyingErrorKey]  = underlyingError;
    
    return [NSError errorWithDomain:MSALErrorDomain code:code userInfo:userInfo];
}

NSError *MSALCreateAndLogError(id<MSALRequestContext> ctx, MSALErrorCode code, NSString *oauthError, NSError *underlyingError, const char *function, int line, NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *description = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    MSALLogError(ctx, code, description, oauthError, function, line);
    return MSALCreateError(code, description, oauthError, underlyingError);
}

void MSALFillAndLogError(NSError * __autoreleasing * error, id<MSALRequestContext> ctx, MSALErrorCode code, NSString *oauthError, NSError *underlyingError, const char *function, int line, NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *description = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    MSALLogError(ctx, code, description, oauthError, function, line);
    if (error)
    {
        *error = MSALCreateError(code, description, oauthError, underlyingError);
    }
}
