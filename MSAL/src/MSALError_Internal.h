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

#import <Foundation/Foundation.h>


extern NSString *MSALStringForErrorCode(MSALErrorCode code);
extern MSALErrorCode MSALErrorCodeForOAuthError(NSString *oauthError, MSALErrorCode defaultCode);

extern void MSALLogError(id<MSALRequestContext> ctx, MSALErrorCode code, NSString *errorDescription, NSString *subError, NSString *oauthError, const char *function, int line);
extern NSError *MSALCreateError(MSALErrorCode code, NSString *errorDescription, NSString *oauthError, NSString *subError, NSError* underlyingError);

extern NSError *MSALCreateAndLogError(id<MSALRequestContext> ctx, MSALErrorCode code, NSString *oauthError, NSString *subError, NSError *underlyingError, const char *function, int line, NSString *format, ...) NS_FORMAT_FUNCTION(8, 9);
extern void MSALFillAndLogError(NSError * __autoreleasing *, id<MSALRequestContext> ctx, MSALErrorCode code, NSString *oauthError, NSString *subError, NSError *underlyingError, const char *function, int line, NSString *format, ...) NS_FORMAT_FUNCTION(9, 10);

// Convenience macro for checking and filling an optional NSError** parameter
#define MSAL_ERROR_PARAM(_CTX, _CODE, _DESC, ...) MSALFillAndLogError(error, _CTX, _CODE, nil, nil, nil, __FUNCTION__, __LINE__, _DESC, ##__VA_ARGS__)

#define MSAL_OSERROR_PARAM(_CTX, _CODE, _OSERROR, _DESC, ...) MSALFillAndLogError(error, _CTX, _CODE, nil, nil, [NSError errorWithDomain:NSOSStatusErrorDomain code:_OSERROR userInfo:nil], __FUNCTION__, __LINE__, _DESC, ##__VA_ARGS__)

#define CREATE_LOG_ERROR(_CTX, _CODE, _DESC, ...) MSALCreateAndLogError(_CTX, _CODE, nil, nil, nil, __FUNCTION__, __LINE__, _DESC, ##__VA_ARGS__)

// Convenience macros for checking a false/nil return result and passing along
// an error to a completion block with quick return
#define CHECK_COMPLETION(_CHECK) if (!_CHECK) { \
    completionBlock(nil, error); \
    return; \
}
#define ERROR_COMPLETION(_CTX, _CODE, _DESC, ...) \
    completionBlock(nil, CREATE_LOG_ERROR(_CTX, _CODE, _DESC, ##__VA_ARGS__)); \
    return; \

// Convenience macro to create invalid response error
#define CREATE_ERROR_INVALID_RESULT(_CTX, _PARAMETER, _ERROR) \
    _ERROR = MSALCreateAndLogError(_CTX, MSALErrorInvalidResponse, nil, nil, nil, __FUNCTION__, __LINE__, @#_PARAMETER " is not found in the response.")

// Check and pass an error back through the completion block
#define CHECK_ERROR_COMPLETION(_CHECK, _CTX, _CODE, _DESC, ...) if (!_CHECK) { ERROR_COMPLETION(_CTX, _CODE, _DESC, ##__VA_ARGS__); }

// Convenience macro for checking a value for false/nil, creating an error
// based on the parameters passed in and returning 0/false/nil
#define CHECK_ERROR_RETURN_NIL(_CHECK, _CTX, _CODE, _DESC, ...) \
    if (!_CHECK) { MSAL_ERROR_PARAM(_CTX, _CODE, _DESC, ##__VA_ARGS__); return 0; }

#define CHECK_RETURN_NIL(_CHECK) if (!_CHECK) { return nil; }

// Convenience macro for creating a required parameter error based on the
// parameter passed into the macro
#define REQUIRED_PARAMETER(_PARAMETER, _CTX) if (!_PARAMETER) { REQUIRED_PARAMETER_ERROR(_PARAMETER, _CTX); return nil; }

#define REQUIRED_STRING_PARAMETER(_PARAMETER, _CTX) if ([NSString msalIsStringNilOrBlank:_PARAMETER]) { REQUIRED_PARAMETER_ERROR(_PARAMETER, _CTX); return nil; }

#define REQUIRED_PARAMETER_ERROR(_PARAMETER, _CTX) MSALFillAndLogError(error, _CTX, MSALErrorInvalidParameter, nil, nil, nil, __FUNCTION__, __LINE__, @#_PARAMETER " is a required parameter and must not be nil or empty.")

// Convenience macro for creating a cache error
#define MSAL_KEYCHAIN_ERROR_PARAM(_CTX, _OSERROR, _OPERATION) MSAL_OSERROR_PARAM(_CTX, MSALErrorKeychainFailure, _OSERROR, @"Keychain failure (%d) while %@", (int)_OSERROR, _OPERATION)
