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

import Foundation

enum SignInStartResult {
    case completed(MSALNativeAuthUserAccountResult)
    case codeRequired(newState: SignInCodeRequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int)
    case passwordRequired(newState: SignInPasswordRequiredState)
    case awaitingMFA(newState: AwaitingMFAState)
    case jitAuthMethodsSelectionRequired(authMethods: [MSALAuthMethod], newState: RegisterStrongAuthState)
    case error(SignInStartError)
}

typealias SignInResendCodeResult = CodeRequiredGenericResult<SignInCodeRequiredState, ResendCodeError>

enum SignInPasswordRequiredResult {
    case completed(MSALNativeAuthUserAccountResult)
    case awaitingMFA(newState: AwaitingMFAState)
    case jitAuthMethodsSelectionRequired(authMethods: [MSALAuthMethod], newState: RegisterStrongAuthState)
    case error(error: PasswordRequiredError, newState: SignInPasswordRequiredState?)
}

enum SignInVerifyCodeResult {
    case completed(MSALNativeAuthUserAccountResult)
    case error(error: VerifyCodeError, newState: SignInCodeRequiredState?)
}

enum SignInAfterPreviousFlowResult {
    case completed(MSALNativeAuthUserAccountResult)
    case jitAuthMethodsSelectionRequired(authMethods: [MSALAuthMethod], newState: RegisterStrongAuthState)
    case error(error: MSALNativeAuthGenericError)
}
