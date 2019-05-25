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

#define MSAL_VER_HIGH       0
#define MSAL_VER_LOW        3
#define MSAL_VER_PATCH      2

#define STR_HELPER(x) #x
#define STR(x) STR_HELPER(x)

// Framework versions only support high and low for the double value, sadly.
#define MSAL_VERSION_STRING     STR(MSAL_VER_HIGH) "." STR(MSAL_VER_LOW) "." STR(MSAL_VER_PATCH)


//General macro for throwing exception named NSInvalidArgumentException
#define THROW_ON_CONDITION_ARGUMENT(CONDITION, ARG) \
{ \
    if (CONDITION) \
    { \
        MSID_LOG_ERROR(nil, @"InvalidArgumentException: " #ARG); \
        @throw [NSException exceptionWithName: NSInvalidArgumentException \
                                       reason:@"Please provide a valid '" #ARG "' parameter." \
                                     userInfo:nil];  \
    } \
}

//Checks a selector argument for being null. Throws NSException with name NSInvalidArgumentException if
//the argument is invalid
#define THROW_ON_NIL_ARGUMENT(ARG) THROW_ON_CONDITION_ARGUMENT(!(ARG), ARG);

@class NSOrderedSet<T>;
@class NSString;

// Internally scopes usually are passed around as an ordered set of strings
typedef NSOrderedSet<NSString *> MSALScopes;

#import "IdentityCore_Internal.h"
#include "MSIDLogger+Internal.h"
#include "MSALError_Internal.h"
#import  "MSIDRequestContext.h"
#import "MSALConstants.h"
