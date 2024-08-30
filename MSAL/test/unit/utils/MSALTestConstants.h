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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#pragma once

#include "MSALPublicClientApplication+Internal.h"

// Unit test client ID
#define UNIT_TEST_CLIENT_ID                 @"b92e0ba5-f86e-4411-8e18-6b5f928d968a"

// Unit test correlation ID
#define UNIT_TEST_CORRELATION_ID            @"60032DDF-822D-470B-9957-D694F92E3D27"

// Unit test redirect scheme : msal<clientId>
#define UNIT_TEST_DEFAULT_REDIRECT_SCHEME   @"msal"UNIT_TEST_CLIENT_ID

// Unit test redirect uri : msal<clientId>://auth
#if TARGET_OS_IPHONE
#define UNIT_TEST_DEFAULT_REDIRECT_URI      UNIT_TEST_DEFAULT_REDIRECT_SCHEME"://auth"
#else
#define UNIT_TEST_DEFAULT_REDIRECT_URI      @"msauth.com.microsoft.unit-test-host://auth"
#endif

#define UNIT_TEST_DEFAULT_BUNDLE_ID         @"com.microsoft.mytest.bundleId"

#define UT_SLICE_PARAMS_QUERY 
