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
    let expectation: XCTestExpectation?
    private(set) var onResetPasswordErrorCalled = false
    private(set) var onResetPasswordCodeRequiredCalled = false
    private(set) var error: ResetPasswordStartError?
    private(set) var newState: ResetPasswordCodeRequiredState?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSALNativeAuthChannelType?
    private(set) var codeLength: Int?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onResetPasswordStartError(error: MSAL.ResetPasswordStartError) {
        onResetPasswordErrorCalled = true
        self.error = error

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
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

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class ResetPasswordStartDelegateOptionalMethodsNotImplemented: ResetPasswordStartDelegate {
    let expectation: XCTestExpectation?
    private(set) var error: ResetPasswordStartError?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onResetPasswordStartError(error: MSAL.ResetPasswordStartError) {
        self.error = error

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class ResetPasswordResendCodeDelegateSpy: ResetPasswordResendCodeDelegate {
    let expectation: XCTestExpectation?
    private(set) var onResetPasswordResendCodeErrorCalled = false
    private(set) var onResetPasswordResendCodeRequiredCalled = false
    private(set) var error: ResendCodeError?
    private(set) var newState: ResetPasswordCodeRequiredState?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSALNativeAuthChannelType?
    private(set) var codeLength: Int?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onResetPasswordResendCodeError(error: ResendCodeError, newState: ResetPasswordCodeRequiredState?) {
        onResetPasswordResendCodeErrorCalled = true

        self.error = error
        self.newState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }

    func onResetPasswordResendCodeRequired(newState: MSAL.ResetPasswordCodeRequiredState, sentTo: String, channelTargetType: MSAL.MSALNativeAuthChannelType, codeLength: Int) {
        onResetPasswordResendCodeRequiredCalled = true

        self.newState = newState
        self.sentTo = sentTo
        self.channelTargetType = channelTargetType
        self.codeLength = codeLength

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class ResetPasswordResendCodeDelegateOptionalMethodsNotImplemented: ResetPasswordResendCodeDelegate {
    let expectation: XCTestExpectation?
    private(set) var error: ResendCodeError?
    private(set) var newState: ResetPasswordCodeRequiredState?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onResetPasswordResendCodeError(error: ResendCodeError, newState: ResetPasswordCodeRequiredState?) {
        self.error = error
        self.newState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class ResetPasswordVerifyCodeDelegateSpy: ResetPasswordVerifyCodeDelegate {
    let expectation: XCTestExpectation?
    private(set) var onResetPasswordVerifyCodeErrorCalled = false
    private(set) var onPasswordRequiredCalled = false
    private(set) var error: VerifyCodeError?
    private(set) var newCodeRequiredState: ResetPasswordCodeRequiredState?
    private(set) var newPasswordRequiredState: ResetPasswordRequiredState?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onResetPasswordVerifyCodeError(error: VerifyCodeError, newState: ResetPasswordCodeRequiredState?) {
        onResetPasswordVerifyCodeErrorCalled = true
        self.error = error
        newCodeRequiredState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }

    func onPasswordRequired(newState: ResetPasswordRequiredState) {
        onPasswordRequiredCalled = true
        newPasswordRequiredState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class ResetPasswordVerifyCodeDelegateOptionalMethodsNotImplemented: ResetPasswordVerifyCodeDelegate {
    let expectation: XCTestExpectation?
    private(set) var error: VerifyCodeError?
    private(set) var newCodeRequiredState: ResetPasswordCodeRequiredState?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onResetPasswordVerifyCodeError(error: VerifyCodeError, newState: ResetPasswordCodeRequiredState?) {
        self.error = error
        newCodeRequiredState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class ResetPasswordRequiredDelegateSpy: ResetPasswordRequiredDelegate {
    let expectation: XCTestExpectation?
    private(set) var onResetPasswordRequiredErrorCalled = false
    private(set) var onResetPasswordCompletedCalled = false
    private(set) var error: PasswordRequiredError?
    private(set) var newPasswordRequiredState: ResetPasswordRequiredState?
    private(set) var signInAfterResetPasswordState: SignInAfterResetPasswordState?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onResetPasswordRequiredError(error: PasswordRequiredError, newState: ResetPasswordRequiredState?) {
        onResetPasswordRequiredErrorCalled = true

        self.error = error
        newPasswordRequiredState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }

    func onResetPasswordCompleted(newState: SignInAfterResetPasswordState) {
        onResetPasswordCompletedCalled = true
        signInAfterResetPasswordState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class ResetPasswordRequiredDelegateOptionalMethodsNotImplemented: ResetPasswordRequiredDelegate {
    let expectation: XCTestExpectation?
    private(set) var error: PasswordRequiredError?
    private(set) var newPasswordRequiredState: ResetPasswordRequiredState?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onResetPasswordRequiredError(error: PasswordRequiredError, newState: ResetPasswordRequiredState?) {
        self.error = error
        newPasswordRequiredState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class SignInAfterResetPasswordDelegateOptionalMethodsNotImplemented: SignInAfterResetPasswordDelegate {

    private let expectation: XCTestExpectation
    var expectedError: SignInAfterResetPasswordError?

    init(expectation: XCTestExpectation, expectedError: SignInAfterResetPasswordError? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
    }

    public func onSignInAfterResetPasswordError(error: MSAL.SignInAfterResetPasswordError) {
        XCTAssertEqual(error.errorDescription, expectedError?.errorDescription)
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }
}
