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
    private let expectation: XCTestExpectation?
    private(set) var onResetPasswordErrorCalled = false
    private(set) var onResetPasswordCodeSentCalled = false
    private(set) var error: ResetPasswordStartError?
    private(set) var newState: ResetPasswordCodeSentState?
    private(set) var displayName: String?
    private(set) var codeLength: Int?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onResetPasswordError(error: MSAL.ResetPasswordStartError) {
        onResetPasswordErrorCalled = true
        self.error = error

        self.expectation?.fulfill()
    }

    func onResetPasswordCodeSent(newState: MSAL.ResetPasswordCodeSentState, displayName: String, codeLength: Int) {
        onResetPasswordCodeSentCalled = true
        self.newState = newState
        self.displayName = displayName
        self.codeLength = codeLength

        self.expectation?.fulfill()
    }
}

class ResetPasswordResendCodeDelegateSpy: ResetPasswordResendCodeDelegate {
    private let expectation: XCTestExpectation?
    private(set) var onResetPasswordResendCodeErrorCalled = false
    private(set) var onResetPasswordResendCodeSentCalled = false
    private(set) var error: ResendCodeError?
    private(set) var newState: ResetPasswordCodeSentState?
    private(set) var displayName: String?
    private(set) var codeLength: Int?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onResetPasswordResendCodeError(error: ResendCodeError, newState: ResetPasswordCodeSentState?) {
        onResetPasswordResendCodeErrorCalled = true

        self.error = error
        self.newState = newState

        expectation?.fulfill()
    }

    func onResetPasswordResendCodeSent(newState: ResetPasswordCodeSentState, displayName: String, codeLength: Int) {
        onResetPasswordResendCodeSentCalled = true

        self.newState = newState
        self.displayName = displayName
        self.codeLength = codeLength

        expectation?.fulfill()
    }
}

class ResetPasswordVerifyCodeDelegateSpy: ResetPasswordVerifyCodeDelegate {
    private let expectation: XCTestExpectation?
    private(set) var onResetPasswordVerifyCodeErrorCalled = false
    private(set) var onPasswordRequiredCalled = false
    private(set) var error: VerifyCodeError?
    private(set) var newCodeSentState: ResetPasswordCodeSentState?
    private(set) var newPasswordRequiredState: ResetPasswordRequiredState?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onResetPasswordVerifyCodeError(error: VerifyCodeError, newState: ResetPasswordCodeSentState?) {
        onResetPasswordVerifyCodeErrorCalled = true
        self.error = error
        newCodeSentState = newState

        expectation?.fulfill()
    }

    func onPasswordRequired(newState: ResetPasswordRequiredState) {
        onPasswordRequiredCalled = true
        newPasswordRequiredState = newState

        expectation?.fulfill()
    }
}

class ResetPasswordRequiredDelegateSpy: ResetPasswordRequiredDelegate {
    private let expectation: XCTestExpectation?
    private(set) var onResetPasswordRequiredErrorCalled = false
    private(set) var onResetPasswordCompletedCalled = false
    private(set) var error: PasswordRequiredError?
    private(set) var newPasswordRequiredState: ResetPasswordRequiredState?
    private(set) var resetPasswordCompletedCalled = false

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onResetPasswordRequiredError(error: PasswordRequiredError, newState: ResetPasswordRequiredState?) {
        onResetPasswordRequiredErrorCalled = true

        self.error = error
        newPasswordRequiredState = newState

        expectation?.fulfill()
    }

    func onResetPasswordCompleted() {
        onResetPasswordCompletedCalled = true

        resetPasswordCompletedCalled = true
        
        expectation?.fulfill()
    }
}
