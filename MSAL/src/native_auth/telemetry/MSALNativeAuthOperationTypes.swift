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

typealias MSALNativeAuthOperationType = Int

enum MSALNativeAuthSignUpType: MSALNativeAuthOperationType {
    case signUpWithPassword = 0
    case signUpWithOTP = 1
    case signUpWithMFA = 2
    case signUpStart = 3
    case signUpChallenge = 4
    case signUpContinue = 5
}

enum MSALNativeAuthSignInType: MSALNativeAuthOperationType {
    case signInWithOTP = 0
    case signInWithMFA = 1
    case signInInitiate = 2
    case signInChallenge = 3
}

enum MSALNativeAuthTokenType: MSALNativeAuthOperationType {
    case signInWithPassword = 0
    case refreshToken = 1

}
enum MSALNAtiveAuthResetPasswordType: MSALNativeAuthOperationType {
    case resetPasswordStart = 0
    case resetPasswordChallenge = 1
    case resetPasswordContinue = 2
    case resetPasswordSubmit = 3
    case resetPasswordPollCompletion = 4
}

enum MSALNativeAuthResetPasswordStartType: MSALNativeAuthOperationType {
    case resetPasswordStart = 0
}

enum MSALNativeAuthResetPasswordCompleteType: MSALNativeAuthOperationType {
    case resetPasswordComplete = 0
}

enum MSALNativeAuthResendCodeType: MSALNativeAuthOperationType {
    case resendCode = 0
}

enum MSALNativeAuthVerifyCodeType: MSALNativeAuthOperationType {
    case verifyCode = 0
}

enum MSALNativeAuthSignOutType: MSALNativeAuthOperationType {
    case signOutAction = 0
    case signOutForced = 1
}
