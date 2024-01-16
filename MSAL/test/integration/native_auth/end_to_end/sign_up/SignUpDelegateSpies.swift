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

class SignUpPasswordStartDelegateSpy: SignUpStartDelegate {    
    private let expectation: XCTestExpectation
    private(set) var onSignUpPasswordErrorCalled = false
    private(set) var error: MSAL.SignUpStartError?
    private(set) var onSignUpCodeRequiredCalled = false
    private(set) var newState: SignUpCodeRequiredState?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSALNativeAuthChannelType?
    private(set) var codeLength: Int?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onSignUpStartError(error: MSAL.SignUpStartError) {
        onSignUpPasswordErrorCalled = true
        self.error = error

        expectation.fulfill()
    }

    func onSignUpCodeRequired(newState: SignUpCodeRequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int) {
        onSignUpCodeRequiredCalled = true
        self.newState = newState
        self.sentTo = sentTo
        self.channelTargetType = channelTargetType
        self.codeLength = codeLength

        expectation.fulfill()
    }
}

class SignUpStartDelegateSpy: SignUpStartDelegate {
    private let expectation: XCTestExpectation
    private(set) var onSignUpErrorCalled = false
    private(set) var error: MSAL.SignUpStartError?
    private(set) var onSignUpCodeRequiredCalled = false
    private(set) var newState: SignUpCodeRequiredState?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSALNativeAuthChannelType?
    private(set) var codeLength: Int?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onSignUpStartError(error: SignUpStartError) {
        onSignUpErrorCalled = true
        self.error = error

        expectation.fulfill()
    }

    func onSignUpCodeRequired(newState: SignUpCodeRequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int) {
        onSignUpCodeRequiredCalled = true
        self.newState = newState
        self.sentTo = sentTo
        self.channelTargetType = channelTargetType
        self.codeLength = codeLength

        expectation.fulfill()
    }
}

class SignUpVerifyCodeDelegateSpy: SignUpVerifyCodeDelegate {
    private let expectation: XCTestExpectation
    private(set) var onSignUpVerifyCodeErrorCalled = false
    private(set) var error: VerifyCodeError?
    private(set) var onSignUpAttributesRequiredCalled = false
    private(set) var attributesRequiredNewState: SignUpAttributesRequiredState?
    private(set) var onSignUpPasswordRequiredCalled = false
    private(set) var passwordRequiredState: SignUpPasswordRequiredState?
    private(set) var onSignUpCompletedCalled = false
    private(set) var signInAfterSignUpState: SignInAfterSignUpState?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onSignUpVerifyCodeError(error: VerifyCodeError, newState: SignUpCodeRequiredState?) {
        onSignUpVerifyCodeErrorCalled = true
        self.error = error

        expectation.fulfill()
    }

    func onSignUpAttributesRequired(attributes: [MSALNativeAuthRequiredAttribute], newState: SignUpAttributesRequiredState) {
        onSignUpAttributesRequiredCalled = true
        attributesRequiredNewState = newState

        expectation.fulfill()
    }

    func onSignUpPasswordRequired(newState: SignUpPasswordRequiredState) {
        onSignUpPasswordRequiredCalled = true
        passwordRequiredState = newState

        expectation.fulfill()
    }

    func onSignUpCompleted(newState: SignInAfterSignUpState) {
        onSignUpCompletedCalled = true
        signInAfterSignUpState = newState

        expectation.fulfill()
    }
}

class SignUpResendCodeDelegateSpy: SignUpResendCodeDelegate {
    private let expectation: XCTestExpectation
    private(set) var onSignUpResendCodeErrorCalled = false
    private(set) var error: ResendCodeError?
    private(set) var onSignUpResendCodeCodeRequiredCalled = false
    private(set) var signUpCodeRequiredState: SignUpCodeRequiredState?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSALNativeAuthChannelType?
    private(set) var codeLength: Int?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onSignUpResendCodeError(error: MSAL.ResendCodeError, newState: MSAL.SignUpCodeRequiredState?) {
        onSignUpResendCodeErrorCalled = true
        self.error = error
    }

    func onSignUpResendCodeCodeRequired(newState: SignUpCodeRequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int) {
        onSignUpResendCodeCodeRequiredCalled = true
        signUpCodeRequiredState = newState
        self.sentTo = sentTo
        self.channelTargetType = channelTargetType
        self.codeLength = codeLength

        expectation.fulfill()
    }
}

class SignUpPasswordRequiredDelegateSpy: SignUpPasswordRequiredDelegate {
    private let expectation: XCTestExpectation
    private(set) var onSignUpPasswordRequiredErrorCalled = false
    private(set) var error: PasswordRequiredError?
    private(set) var passwordRequiredState: SignUpPasswordRequiredState?
    private(set) var onSignUpAttributesRequiredCalled = false
    private(set) var attributesRequiredState: SignUpAttributesRequiredState?
    private(set) var onSignUpCompletedCalled = false
    private(set) var signInAfterSignUpState: SignInAfterSignUpState?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onSignUpPasswordRequiredError(error: PasswordRequiredError, newState: SignUpPasswordRequiredState?) {
        onSignUpPasswordRequiredErrorCalled = true
        self.error = error
        passwordRequiredState = newState

        expectation.fulfill()
    }

    func onSignUpAttributesRequired(attributes: [MSALNativeAuthRequiredAttribute], newState: SignUpAttributesRequiredState) {
        onSignUpAttributesRequiredCalled = true
        attributesRequiredState = newState

        expectation.fulfill()
    }

    func onSignUpCompleted(newState: SignInAfterSignUpState) {
        onSignUpCompletedCalled = true
        signInAfterSignUpState = newState

        expectation.fulfill()
    }
}

class SignUpAttributesRequiredDelegateSpy: SignUpAttributesRequiredDelegate {
    var expectation: XCTestExpectation
    private(set) var onSignUpAttributesRequiredErrorCalled = false
    private(set) var error: AttributesRequiredError?
    private(set) var attributesRequiredState: SignUpAttributesRequiredState?
    private(set) var onSignUpCompletedCalled = false
    private(set) var signInAfterSignUpState: SignInAfterSignUpState?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onSignUpAttributesRequiredError(error: AttributesRequiredError) {
        onSignUpAttributesRequiredErrorCalled = true
        self.error = error

        expectation.fulfill()
    }

    func onSignUpCompleted(newState: SignInAfterSignUpState) {
        onSignUpCompletedCalled = true
        signInAfterSignUpState = newState

        expectation.fulfill()
    }
    
    func onSignUpAttributesRequired(attributes: [MSAL.MSALNativeAuthRequiredAttribute], newState: MSAL.SignUpAttributesRequiredState) {
        onSignUpAttributesRequiredErrorCalled = true
        attributesRequiredState = newState
        expectation.fulfill()
    }
    
    func onSignUpAttributesInvalid(attributeNames: [String], newState: MSAL.SignUpAttributesRequiredState) {
        onSignUpAttributesRequiredErrorCalled = true
        attributesRequiredState = newState
        expectation.fulfill()
    }
}

class SignInAfterSignUpDelegateSpy: SignInAfterSignUpDelegate {
    private let expectation: XCTestExpectation
    private(set) var onSignInAfterSignUpErrorCalled = false
    private(set) var error: SignInAfterSignUpError?
    private(set) var onSignInCompletedCalled = false
    private(set) var result: MSALNativeAuthUserAccountResult?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onSignInAfterSignUpError(error: SignInAfterSignUpError) {
        onSignInAfterSignUpErrorCalled = true
        self.error = error

        expectation.fulfill()
    }

    func onSignInCompleted(result: MSALNativeAuthUserAccountResult) {
        onSignInCompletedCalled = true
        self.result = result

        expectation.fulfill()
    }
}
