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

class SignUpPasswordStartDelegateSpy: SignUpStartDelegate {
    let expectation: XCTestExpectation?
    private(set) var onSignUpPasswordErrorCalled = false
    private(set) var onSignUpCodeRequiredCalled = false
    private(set) var onSignUpAttributesInvalidCalled = false
    private(set) var error: SignUpStartError?
    private(set) var newState: SignUpCodeRequiredState?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSALNativeAuthChannelType?
    private(set) var codeLength: Int?
    private(set) var attributeNames: [String]?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onSignUpStartError(error: MSAL.SignUpStartError) {
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
    
    func onSignUpAttributesInvalid(attributeNames: [String]) {
        self.onSignUpAttributesInvalidCalled = true
        self.attributeNames = attributeNames
        
        XCTAssertTrue(Thread.isMainThread)
        self.expectation?.fulfill()
    }
}

class SignUpCodeStartDelegateSpy: SignUpStartDelegate {
    let expectation: XCTestExpectation?
    private(set) var onSignUpCodeErrorCalled = false
    private(set) var onSignUpCodeRequiredCalled = false
    private(set) var onSignUpAttributesInvalidCalled = false
    private(set) var error: SignUpStartError?
    private(set) var newState: SignUpCodeRequiredState?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSALNativeAuthChannelType?
    private(set) var codeLength: Int?
    private(set) var attributeNames: [String]?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onSignUpStartError(error: MSAL.SignUpStartError) {
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
    
    func onSignUpAttributesInvalid(attributeNames: [String]) {
        self.onSignUpAttributesInvalidCalled = true
        self.attributeNames = attributeNames
        
        XCTAssertTrue(Thread.isMainThread)
        self.expectation?.fulfill()
    }
}

class SignUpResendCodeDelegateSpy: SignUpResendCodeDelegate {
    let expectation: XCTestExpectation?
    private(set) var onSignUpResendCodeErrorCalled = false
    private(set) var onSignUpResendCodeCodeRequiredCalled = false
    private(set) var error: ResendCodeError?
    private(set) var newState: SignUpCodeRequiredState?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSALNativeAuthChannelType?
    private(set) var codeLength: Int?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onSignUpResendCodeError(error: MSAL.ResendCodeError, newState: MSAL.SignUpCodeRequiredState?) {
        onSignUpResendCodeErrorCalled = true
        self.newState = newState
        self.error = error

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }

    func onSignUpResendCodeCodeRequired(newState: MSAL.SignUpCodeRequiredState, sentTo: String, channelTargetType: MSAL.MSALNativeAuthChannelType, codeLength: Int) {
        onSignUpResendCodeCodeRequiredCalled = true
        self.newState = newState
        self.sentTo = sentTo
        self.codeLength = codeLength
        self.channelTargetType = channelTargetType

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class SignUpResendCodeDelegateMethodsNotImplemented: SignUpResendCodeDelegate {
    let expectation: XCTestExpectation?
    private(set) var error: ResendCodeError?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onSignUpResendCodeError(error: MSAL.ResendCodeError, newState: MSAL.SignUpCodeRequiredState?) {
        self.error = error

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class SignUpVerifyCodeDelegateSpy: SignUpVerifyCodeDelegate {
    let expectation: XCTestExpectation?
    private(set) var onSignUpVerifyCodeErrorCalled = false
    private(set) var onSignUpAttributesRequiredCalled = false
    private(set) var onSignUpPasswordRequiredCalled = false
    private(set) var onSignUpCompletedCalled = false
    private(set) var error: VerifyCodeError?
    private(set) var newCodeRequiredState: SignUpCodeRequiredState?
    private(set) var newAttributesRequiredState: SignUpAttributesRequiredState?
    private(set) var newPasswordRequiredState: SignUpPasswordRequiredState?
    private(set) var newSignInAfterSignUpState: SignInAfterSignUpState?
    private(set) var newAttributesRequired: [MSALNativeAuthRequiredAttribute]?

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

    func onSignUpAttributesRequired(attributes: [MSALNativeAuthRequiredAttribute], newState: MSAL.SignUpAttributesRequiredState) {
        onSignUpAttributesRequiredCalled = true
        newAttributesRequired = attributes
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
        newSignInAfterSignUpState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class SignUpPasswordRequiredDelegateSpy: SignUpPasswordRequiredDelegate {
    let expectation: XCTestExpectation?
    private(set) var onSignUpPasswordRequiredErrorCalled = false
    private(set) var onSignUpAttributesRequiredCalled = false
    private(set) var onSignUpCompletedCalled = false
    private(set) var error: PasswordRequiredError?
    private(set) var newPasswordRequiredState: SignUpPasswordRequiredState?
    private(set) var newAttributesRequiredState: SignUpAttributesRequiredState?
    private(set) var signInAfterSignUpState: SignInAfterSignUpState?
    private(set) var newAttributesRequired: [MSALNativeAuthRequiredAttribute]?

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

    func onSignUpAttributesRequired(attributes: [MSAL.MSALNativeAuthRequiredAttribute], newState: MSAL.SignUpAttributesRequiredState) {
        onSignUpAttributesRequiredCalled = true
        newAttributesRequiredState = newState
        newAttributesRequired = attributes

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }

    func onSignUpCompleted(newState: SignInAfterSignUpState) {
        onSignUpCompletedCalled = true
        self.signInAfterSignUpState = newState

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
    private(set) var attributes: [MSAL.MSALNativeAuthRequiredAttribute]?
    private(set) var invalidAttributes: [String]?
    private(set) var newSignInAfterSignUpState: SignInAfterSignUpState?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onSignUpAttributesRequiredError(error: MSAL.AttributesRequiredError) {
        onSignUpAttributesRequiredErrorCalled = true
        self.error = error

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }

    func onSignUpCompleted(newState: SignInAfterSignUpState) {
        onSignUpCompletedCalled = true
        newSignInAfterSignUpState = newState

        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
    
    func onSignUpAttributesRequired(attributes: [MSAL.MSALNativeAuthRequiredAttribute], newState: MSAL.SignUpAttributesRequiredState) {
        self.attributes = attributes
        self.newState = newState
        onSignUpAttributesRequiredCalled = true
        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
    
    func onSignUpAttributesInvalid(attributeNames: [String], newState: MSAL.SignUpAttributesRequiredState) {
        self.invalidAttributes = attributeNames
        self.newState = newState
        onSignUpAttributesRequiredCalled = true
        XCTAssertTrue(Thread.isMainThread)
        expectation?.fulfill()
    }
}

class SignUpAttributesRequiredDelegateOptionalMethodsNotImplemented: SignUpAttributesRequiredDelegate {
    private let expectation: XCTestExpectation?
    private(set) var error: AttributesRequiredError?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onSignUpAttributesRequiredError(error: MSAL.AttributesRequiredError) {
        self.error = error

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
}

class SignUpPasswordStartDelegateOptionalMethodsNotImplemented: SignUpStartDelegate {
    private let expectation: XCTestExpectation?
    private(set) var onSignUpPasswordErrorCalled = false
    private(set) var error: SignUpStartError?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onSignUpStartError(error: MSAL.SignUpStartError) {
        onSignUpPasswordErrorCalled = true
        self.error = error

        XCTAssertTrue(Thread.isMainThread)
        self.expectation?.fulfill()
    }
}

class SignUpStartDelegateOptionalMethodsNotImplemented: SignUpStartDelegate {
    private let expectation: XCTestExpectation?
    private(set) var onSignUpStartErrorCalled = false
    private(set) var error: SignUpStartError?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onSignUpStartError(error: MSAL.SignUpStartError) {
        onSignUpStartErrorCalled = true
        self.error = error

        XCTAssertTrue(Thread.isMainThread)
        self.expectation?.fulfill()
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
}
