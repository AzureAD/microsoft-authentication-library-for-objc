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
#define MSAL_VER_LOW        1
#define MSAL_VER_PATCH      1

#define STR_HELPER(x) #x
#define STR(x) STR_HELPER(x)
#define INT_CONCAT_HELPER(x,y) x ## . ## y
#define INT_CONCAT(x,y) INT_CONCAT_HELPER(x,y)

// Framework versions only support high and low for the double value, sadly.
#define MSAL_VERSION_NUMBER INT_CONCAT(MSAL_VER_HIGH, MSAL_VER_LOW)

#define MSAL_VERSION_STRING     STR(MSAL_VER_HIGH) "." STR(MSAL_VER_LOW) "." STR(MSAL_VER_PATCH) "-dev"
#define MSAL_VERSION_NSSTRING   @"" STR(MSAL_VER_HIGH) "." STR(MSAL_VER_LOW) "." STR(MSAL_VER_PATCH) "-dev"

#define MSAL_VERSION_HELPER(high, low, patch) msalVersion_ ## high ## _ ## low ## _ ## patch
#define MSAL_VERSION_(high, low, patch) MSAL_VERSION_HELPER(high, low, patch)

// This is specially crafted so the name of the variable matches the full MSAL version
#define MSAL_VERSION_VAR MSAL_VERSION_(MSAL_VER_HIGH, MSAL_VER_LOW, MSAL_VER_PATCH)


// Utility macros for convience classes wrapped around JSON dictionaries
#define DICTIONARY_READ_PROPERTY_IMPL(DICT, KEY, GETTER) \
- (NSString *)GETTER { return [DICT objectForKey:KEY]; }

#define DICTIONARY_WRITE_PROPERTY_IMPL(DICT, KEY, SETTER) \
- (void)SETTER:(NSString *)value { [DICT setValue:[value copy] forKey:KEY]; }

#define DICTIONARY_RW_PROPERTY_IMPL(DICT, KEY, GETTER, SETTER) \
    DICTIONARY_READ_PROPERTY_IMPL(DICT, KEY, GETTER) \
    DICTIONARY_WRITE_PROPERTY_IMPL(DICT, KEY, SETTER)

//General macro for throwing exception named NSInvalidArgumentException
#define THROW_ON_CONDITION_ARGUMENT(CONDITION, ARG) \
{ \
    if (CONDITION) \
    { \
        LOG_ERROR(nil, @"InvalidArgumentException: " #ARG); \
        @throw [NSException exceptionWithName: NSInvalidArgumentException \
                                       reason:@"Please provide a valid '" #ARG "' parameter." \
                                     userInfo:nil];  \
    } \
}

// Checks a selector NSString argument to a method for being null or empty. Throws NSException with name
// NSInvalidArgumentException if the argument is invalid:
#define THROW_ON_NIL_EMPTY_ARGUMENT(ARG) THROW_ON_CONDITION_ARGUMENT([NSString adIsStringNilOrBlank:ARG], ARG);

//Checks a selector argument for being null. Throws NSException with name NSInvalidArgumentException if
//the argument is invalid
#define THROW_ON_NIL_ARGUMENT(ARG) THROW_ON_CONDITION_ARGUMENT(!(ARG), ARG);

@class NSOrderedSet<T>;
@class NSString;

// Internally scopes usually are passed around as an ordered set of strings
typedef NSOrderedSet<NSString *> MSALScopes;

#include "MSAL.h"
#include "MSALLogger+Internal.h"
#include "MSALRequestParameters.h"
#include "MSALError_Internal.h"
