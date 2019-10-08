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

#define MSAL_VER_HIGH       1
#define MSAL_VER_LOW        0
#define MSAL_VER_PATCH      0

#define STR_HELPER(x) #x
#define STR(x) STR_HELPER(x)

// Framework versions only support high and low for the double value, sadly.
#define MSAL_VERSION_STRING     STR(MSAL_VER_HIGH) "." STR(MSAL_VER_LOW) "." STR(MSAL_VER_PATCH)

#import "IdentityCore_Internal.h"
#import "MSIDLogger+Internal.h"
#import "MSALError.h"
#import "MSIDRequestContext.h"
#import "MSALDefinitions.h"
#import "MSALError.h"
