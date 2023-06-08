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

@testable import MSAL
import XCTest

class ResetPasswordStartDelegateSpy: ResetPasswordStartDelegate {
    private(set) var onResetPasswordErrorCalled = false
    private(set) var onResetPasswordCodeRequiredCalled = false
    private(set) var error: ResetPasswordStartError?
    private(set) var newState: ResetPasswordCodeRequiredState?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSALNativeAuthChannelType?
    private(set) var codeLength: Int?

    func onResetPasswordError(error: MSAL.ResetPasswordStartError) {
        onResetPasswordErrorCalled = true
        self.error = error

    }

    func onResetPasswordCodeRequired(
        newState: ResetPasswordCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int
    ) {
        onResetPasswordCodeRequiredCalled = true
        self.newState = newState
        self.sentTo = sentTo
        self.channelTargetType = channelTargetType
        self.codeLength = codeLength

    }
}

class ResetPasswordResendCodeDelegateSpy: ResetPasswordResendCodeDelegate {
    private(set) var onResetPasswordResendCodeErrorCalled = false
    private(set) var onResetPasswordResendCodeRequiredCalled = false
    private(set) var error: ResendCodeError?
    private(set) var newState: ResetPasswordCodeRequiredState?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSALNativeAuthChannelType?
    private(set) var codeLength: Int?

    func onResetPasswordResendCodeError(error: ResendCodeError, newState: ResetPasswordCodeRequiredState?) {
        onResetPasswordResendCodeErrorCalled = true

        self.error = error
        self.newState = newState

    }

    func onResetPasswordResendCodeRequired(newState: MSAL.ResetPasswordCodeRequiredState, sentTo: String, channelTargetType: MSAL.MSALNativeAuthChannelType, codeLength: Int) {
        onResetPasswordResendCodeRequiredCalled = true

        self.newState = newState
        self.sentTo = sentTo
        self.channelTargetType = channelTargetType
        self.codeLength = codeLength

    }
}

class ResetPasswordVerifyCodeDelegateSpy: ResetPasswordVerifyCodeDelegate {
    private(set) var onResetPasswordVerifyCodeErrorCalled = false
    private(set) var onPasswordRequiredCalled = false
    private(set) var error: VerifyCodeError?
    private(set) var newCodeRequiredState: ResetPasswordCodeRequiredState?
    private(set) var newPasswordRequiredState: ResetPasswordRequiredState?

    func onResetPasswordVerifyCodeError(error: VerifyCodeError, newState: ResetPasswordCodeRequiredState?) {
        onResetPasswordVerifyCodeErrorCalled = true
        self.error = error
        newCodeRequiredState = newState

    }

    func onPasswordRequired(newState: ResetPasswordRequiredState) {
        onPasswordRequiredCalled = true
        newPasswordRequiredState = newState

    }
}

class ResetPasswordRequiredDelegateSpy: ResetPasswordRequiredDelegate {
    private(set) var onResetPasswordRequiredErrorCalled = false
    private(set) var onResetPasswordCompletedCalled = false
    private(set) var error: PasswordRequiredError?
    private(set) var newPasswordRequiredState: ResetPasswordRequiredState?

    func onResetPasswordRequiredError(error: PasswordRequiredError, newState: ResetPasswordRequiredState?) {
        onResetPasswordRequiredErrorCalled = true

        self.error = error
        newPasswordRequiredState = newState

    }

    func onResetPasswordCompleted() {
        onResetPasswordCompletedCalled = true

    }
}
