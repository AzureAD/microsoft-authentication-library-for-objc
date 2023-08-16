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

import XCTest
@testable import MSAL

class SignUpPasswordStartDelegateSpy: SignUpPasswordStartDelegate {
    private let expectation: XCTestExpectation?
    private(set) var onSignUpPasswordErrorCalled = false
    private(set) var onSignUpCodeRequiredCalled = false
    private(set) var error: SignUpPasswordStartError?
    private(set) var newState: SignUpCodeRequiredState?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSALNativeAuthChannelType?
    private(set) var codeLength: Int?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onSignUpPasswordError(error: MSAL.SignUpPasswordStartError) {
        onSignUpPasswordErrorCalled = true
        self.error = error

        XCTAssertTrue(Thread.isMainThread)
        self.expectation?.fulfill()
    }

    func onSignUpCodeRequired(newState: SignUpCodeRequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int) {
        onSignUpCodeRequiredCalled = true
        self.newState = newState
        self.sentTo = sentTo
        self.channelTargetType = channelTargetType
        self.codeLength = codeLength

        XCTAssertTrue(Thread.isMainThread)
        self.expectation?.fulfill()
    }
}

class SignUpCodeStartDelegateSpy: SignUpStartDelegate {
    private let expectation: XCTestExpectation?
    private(set) var onSignUpCodeErrorCalled = false
    private(set) var onSignUpCodeRequiredCalled = false
    private(set) var error: SignUpStartError?
    private(set) var newState: SignUpCodeRequiredState?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSALNativeAuthChannelType?
    private(set) var codeLength: Int?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onSignUpError(error: MSAL.SignUpStartError) {
        onSignUpCodeErrorCalled = true
        self.error = error

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }

    func onSignUpCodeRequired(newState: MSAL.SignUpCodeRequiredState, sentTo: String, channelTargetType: MSAL.MSALNativeAuthChannelType, codeLength: Int) {
        onSignUpCodeRequiredCalled = true
        self.newState = newState
        self.sentTo = sentTo
        self.channelTargetType = channelTargetType
        self.codeLength = codeLength

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class SignUpResendCodeDelegateSpy: SignUpResendCodeDelegate {
    private let expectation: XCTestExpectation?
    private(set) var onSignUpResendCodeErrorCalled = false
    private(set) var onSignUpResendCodeCodeRequiredCalled = false
    private(set) var error: ResendCodeError?
    private(set) var newState: SignUpCodeRequiredState?
    private(set) var sentTo: String?
    private(set) var codeLength: Int?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onSignUpResendCodeError(error: ResendCodeError) {
        onSignUpResendCodeErrorCalled = true
        self.error = error

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }

    func onSignUpResendCodeCodeRequired(newState: MSAL.SignUpCodeRequiredState, sentTo: String, channelTargetType: MSAL.MSALNativeAuthChannelType, codeLength: Int) {
        onSignUpResendCodeCodeRequiredCalled = true
        self.newState = newState
        self.sentTo = sentTo
        self.codeLength = codeLength

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class SignUpVerifyCodeDelegateSpy: SignUpVerifyCodeDelegate {
    private let expectation: XCTestExpectation?
    private(set) var onSignUpVerifyCodeErrorCalled = false
    private(set) var onSignUpAttributesRequiredCalled = false
    private(set) var onSignUpPasswordRequiredCalled = false
    private(set) var onSignUpCompletedCalled = false
    private(set) var error: VerifyCodeError?
    private(set) var newCodeRequiredState: SignUpCodeRequiredState?
    private(set) var newAttributesRequiredState: SignUpAttributesRequiredState?
    private(set) var newPasswordRequiredState: SignUpPasswordRequiredState?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onSignUpVerifyCodeError(error: MSAL.VerifyCodeError, newState: MSAL.SignUpCodeRequiredState?) {
        onSignUpVerifyCodeErrorCalled = true
        self.error = error
        newCodeRequiredState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }

    func onSignUpAttributesRequired(newState: MSAL.SignUpAttributesRequiredState) {
        onSignUpAttributesRequiredCalled = true
        newAttributesRequiredState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }

    func onSignUpPasswordRequired(newState: MSAL.SignUpPasswordRequiredState) {
        onSignUpPasswordRequiredCalled = true
        newPasswordRequiredState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }

    func onSignUpCompleted(newState: SignInAfterSignUpState) {
        onSignUpCompletedCalled = true

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class SignUpPasswordRequiredDelegateSpy: SignUpPasswordRequiredDelegate {
    private let expectation: XCTestExpectation?
    private(set) var onSignUpPasswordRequiredErrorCalled = false
    private(set) var onSignUpAttributesRequiredCalled = false
    private(set) var onSignUpCompletedCalled = false
    private(set) var error: PasswordRequiredError?
    private(set) var newPasswordRequiredState: SignUpPasswordRequiredState?
    private(set) var newAttributesRequiredState: SignUpAttributesRequiredState?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onSignUpPasswordRequiredError(error: MSAL.PasswordRequiredError, newState: MSAL.SignUpPasswordRequiredState?) {
        onSignUpPasswordRequiredErrorCalled = true
        self.error = error
        newPasswordRequiredState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }

    func onSignUpAttributesRequired(newState: MSAL.SignUpAttributesRequiredState) {
        onSignUpAttributesRequiredCalled = true
        newAttributesRequiredState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }

    func onSignUpCompleted(newState: SignInAfterSignUpState) {
        onSignUpCompletedCalled = true

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class SignUpAttributesRequiredDelegateSpy: SignUpAttributesRequiredDelegate {
    private let expectation: XCTestExpectation?
    private(set) var onSignUpAttributesRequiredCalled = false
    private(set) var onSignUpAttributesRequiredErrorCalled = false
    private(set) var onSignUpCompletedCalled = false
    private(set) var error: AttributesRequiredError?
    private(set) var newState: SignUpAttributesRequiredState?
    private(set) var attributes: [MSAL.MSALNativeAuthErrorRequiredAttributes]?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onSignUpAttributesRequired(newState: SignUpAttributesRequiredState) {
        onSignUpAttributesRequiredCalled = true
        self.newState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }

    func onSignUpAttributesRequiredError(error: MSAL.AttributesRequiredError, newState: MSAL.SignUpAttributesRequiredState?) {
        onSignUpAttributesRequiredErrorCalled = true
        self.error = error
        self.newState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }

    func onSignUpCompleted(newState: SignInAfterSignUpState) {
        onSignUpCompletedCalled = true

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
    
    func onSignUpAttributesRequired(attributes: [MSAL.MSALNativeAuthErrorRequiredAttributes], newState: MSAL.SignUpAttributesRequiredState) {
        self.attributes = attributes
        self.newState = newState
        onSignUpAttributesRequiredCalled = true
        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
    
    func onSignUpAttributesInvalid(attributeNames: [String], newState: MSAL.SignUpAttributesRequiredState) {
        self.newState = newState
        onSignUpAttributesRequiredCalled = true
        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class SignUpVerifyCodeDelegateOptionalMethodsNotImplemented: SignUpVerifyCodeDelegate {
    private let expectation: XCTestExpectation
    private(set) var error: VerifyCodeError?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onSignUpVerifyCodeError(error: MSAL.VerifyCodeError, newState: MSAL.SignUpCodeRequiredState?) {
        self.error = error
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }

    func onSignUpCompleted(newState: SignInAfterSignUpState) {
        XCTAssertTrue(Thread.isMainThread)
    }
}

class SignUpPasswordRequiredDelegateOptionalMethodsNotImplemented: SignUpPasswordRequiredDelegate {
    private let expectation: XCTestExpectation
    private(set) var error: PasswordRequiredError?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onSignUpPasswordRequiredError(error: MSAL.PasswordRequiredError, newState: MSAL.SignUpPasswordRequiredState?) {
        self.error = error
        XCTAssertTrue(Thread.isMainThread)
        expectation.fulfill()
    }

    func onSignUpCompleted(newState: SignInAfterSignUpState) {
        XCTAssertTrue(Thread.isMainThread)
    }
}
