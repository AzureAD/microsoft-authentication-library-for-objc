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
    case error(SignInStartError)

    func output() -> MSALNativeAuthSignInStartResult {
        switch self {
        case .completed(let result):
            return MSALNativeAuthSignInStartCompleted(completed: result)
        case .codeRequired(let newState, let sentTo, let channelTargetType, let codeLength):
            let result = MSALNativeAuthCodeRequiredResult(newState: newState,
                                                          sentTo: sentTo,
                                                          channelTargetType: channelTargetType,
                                                          codeLength: codeLength)
            return MSALNativeAuthSignInStartCodeRequired(codeRequired: result)
        case .passwordRequired(let newState):
            return MSALNativeAuthSignInStartPasswordRequired(passwordRequired: newState)
        case .error(let error):
            return MSALNativeAuthSignInStartError(error: error)
        }
    }
}

enum SignInResendCodeResult {
    case codeRequired(newState: SignInCodeRequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int)
    case error(error: ResendCodeError, newState: SignInCodeRequiredState?)

    func output() -> MSALNativeAuthSignInResendCodeResult {
        switch self {
        case .codeRequired(let newState, let sentTo, let channelTargetType, let codeLength):
            return MSALNativeAuthSignInResendCodeRequired(resendCodeRequired: MSALNativeAuthCodeRequiredResult(newState: newState,
                                                                                                               sentTo: sentTo,
                                                                                                               channelTargetType: channelTargetType,
                                                                                                               codeLength: codeLength))
        case .error(let error, let newState):
            return MSALNativeAuthSignInResendCodeRequiredError(resendCodeRequiredError: MSALNativeAuthSignInResendCodeErrorResult(error: error,
                                                                                                                                  newState: newState))
        }
    }
}

enum SignInPasswordRequiredResult {
    case completed(MSALNativeAuthUserAccountResult)
    case error(error: PasswordRequiredError, newState: SignInPasswordRequiredState?)
}

enum SignInVerifyCodeResult {
    case completed(MSALNativeAuthUserAccountResult)
    case error(error: VerifyCodeError, newState: SignInCodeRequiredState?)

    func output() -> MSALNativeAuthSignInVerifyCodeResult {
        switch self {
        case .completed(let result):
            return MSALNativeAuthSignInVerifyCodeCompleted(completed: result)
        case .error(let error, let newState):
            return MSALNativeAuthSignInVerifyCodeError(verifyCodeError: MSALNativeAuthSignInVerifyCodeErrorResult(error: error,
                                                                                                                  newState: newState))
        }
    }
}
