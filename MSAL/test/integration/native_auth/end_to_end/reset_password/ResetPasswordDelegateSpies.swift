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
import XCTest
import MSAL

class ResetPasswordStartDelegateSpy: ResetPasswordStartDelegate {
    private let expectation: XCTestExpectation
    private(set) var onResetPasswordErrorCalled = false
    private(set) var onResetPasswordCodeRequiredCalled = false
    private(set) var error: MSAL.ResetPasswordStartError?
    private(set) var newState: MSAL.ResetPasswordCodeRequiredState?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSAL.MSALNativeAuthChannelType?
    private(set) var codeLength: Int?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onResetPasswordStartError(error: MSAL.ResetPasswordStartError) {
        onResetPasswordErrorCalled = true
        self.error = error

        expectation.fulfill()
    }

    func onResetPasswordCodeRequired(
        newState: MSAL.ResetPasswordCodeRequiredState,
        sentTo: String,
        channelTargetType: MSAL.MSALNativeAuthChannelType,
        codeLength: Int
    ) {
        onResetPasswordCodeRequiredCalled = true
        self.newState = newState
        self.sentTo = sentTo
        self.channelTargetType = channelTargetType
        self.codeLength = codeLength

        expectation.fulfill()
    }
}

class ResetPasswordVerifyCodeDelegateSpy: ResetPasswordVerifyCodeDelegate {
    private let expectation: XCTestExpectation
    private(set) var onResetPasswordVerifyCodeErrorCalled = false
    private(set) var onPasswordRequiredCalled = false
    private(set) var error: MSAL.VerifyCodeError?
    private(set) var newCodeRequiredState: MSAL.ResetPasswordCodeRequiredState?
    private(set) var newPasswordRequiredState: MSAL.ResetPasswordRequiredState?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onResetPasswordVerifyCodeError(error: MSAL.VerifyCodeError, newState: MSAL.ResetPasswordCodeRequiredState?) {
        onResetPasswordVerifyCodeErrorCalled = true
        self.error = error
        newCodeRequiredState = newState

        expectation.fulfill()
    }

    func onPasswordRequired(newState: MSAL.ResetPasswordRequiredState) {
        onPasswordRequiredCalled = true
        newPasswordRequiredState = newState

        expectation.fulfill()
    }
}

class ResetPasswordRequiredDelegateSpy: ResetPasswordRequiredDelegate {
    private let expectation: XCTestExpectation
    private(set) var onResetPasswordRequiredErrorCalled = false
    private(set) var onResetPasswordCompletedCalled = false
    private(set) var error: MSAL.PasswordRequiredError?
    private(set) var newPasswordRequiredState: MSAL.ResetPasswordRequiredState?
    private(set) var signInAfterResetPasswordState: SignInAfterResetPasswordState?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onResetPasswordRequiredError(error: MSAL.PasswordRequiredError, newState: MSAL.ResetPasswordRequiredState?) {
        onResetPasswordRequiredErrorCalled = true

        self.error = error
        newPasswordRequiredState = newState

        expectation.fulfill()
    }

    func onResetPasswordCompleted(newState: SignInAfterResetPasswordState) {
        onResetPasswordCompletedCalled = true

        signInAfterResetPasswordState = newState

        expectation.fulfill()
    }
}

class SignInAfterResetPasswordDelegateSpy: SignInAfterResetPasswordDelegate {
    private let expectation: XCTestExpectation
    private(set) var onSignInAfterResetPasswordErrorCalled = false
    private(set) var error: SignInAfterResetPasswordError?
    private(set) var onSignInCompletedCalled = false
    private(set) var result: MSALNativeAuthUserAccountResult?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onSignInAfterResetPasswordError(error: MSAL.SignInAfterResetPasswordError) {
        onSignInCompletedCalled = true
        self.error = error

        expectation.fulfill()
    }

    func onSignInCompleted(result: MSALNativeAuthUserAccountResult) {
        onSignInCompletedCalled = true
        self.result = result
        
        expectation.fulfill()
    }
}
