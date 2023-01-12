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

import Foundation
@_implementationOnly import MSAL_Private

// TODO: Add or remove cases as needed to handle all possible cases needed by our logic

typealias MSALNativeOperationType = Int

enum MSALNativeSignUpType: MSALNativeOperationType {
    case MSALNativeSignUpWithPassword = 0
    case MSALNativeSignUpWithOTP = 1
    case MSALNativeSignUpWithMFA = 2
}

enum MSALNativeSignInType: MSALNativeOperationType {
    case MSALNativeSignInithPassword = 0
    case MSALNativeSignInWithOTP = 1
    case MSALNativeSignInWithMFA = 2
}

typealias MSALNativeTokenRefreshType = TokenCacheRefreshType

enum MSALNativeResetPasswordStartType: MSALNativeOperationType {
    case MSALNativeResetPasswordStart = 0
}

enum MSALNativeResetPasswordCompleteType: MSALNativeOperationType {
    case MSALNativeResetPasswordComplete = 0
}

enum MSALNativeResendCodeType: MSALNativeOperationType {
    case MSALNativeResendCode = 0
}

enum MSALNativeVerifyCodeType: MSALNativeOperationType {
    case MSALNativeVerifyCode = 0
}

enum MSALNativeSignOutType: MSALNativeOperationType {
    case MSALNativeTelemetrySignOutAction = 0
    case MSALNativeTelemetrySignOutForced = 1
}

