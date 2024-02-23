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

class SignInPasswordStartDelegateSpy: SignInStartDelegate {
    private let expectation: XCTestExpectation
    private(set) var onSignInPasswordErrorCalled = false
    private(set) var onSignInCompletedCalled = false
    private(set) var error: MSAL.SignInStartError?
    private(set) var result: MSAL.MSALNativeAuthUserAccountResult?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    public func onSignInStartError(error: MSAL.SignInStartError) {
        onSignInPasswordErrorCalled = true
        self.error = error

        expectation.fulfill()
    }

    public func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {
        onSignInCompletedCalled = true
        self.result = result

        expectation.fulfill()
    }
}

class SignInStartDelegateSpy: SignInStartDelegate {
    private let expectation: XCTestExpectation

    private(set) var onSignInErrorCalled = false
    private(set) var error: MSAL.SignInStartError?

    private(set) var onSignInCodeRequiredCalled = false
    private(set) var newStateCodeRequired: MSAL.SignInCodeRequiredState?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSAL.MSALNativeAuthChannelType?
    private(set) var codeLength: Int?

    private(set) var onSignInPasswordRequiredCalled = false
    private(set) var newStatePasswordRequired: MSAL.SignInPasswordRequiredState?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    public func onSignInStartError(error: MSAL.SignInStartError) {
        onSignInErrorCalled = true
        self.error = error

        expectation.fulfill()
    }

    public func onSignInCodeRequired(newState: MSAL.SignInCodeRequiredState, sentTo: String, channelTargetType: MSAL.MSALNativeAuthChannelType, codeLength: Int) {
        onSignInCodeRequiredCalled = true
        self.newStateCodeRequired = newState
        self.sentTo = sentTo
        self.channelTargetType = channelTargetType
        self.codeLength = codeLength

        expectation.fulfill()
    }

    public func onSignInPasswordRequired(newState: SignInPasswordRequiredState) {
        onSignInPasswordRequiredCalled = true
        self.newStatePasswordRequired = newState

        expectation.fulfill()
    }
}

class SignInVerifyCodeDelegateSpy: SignInVerifyCodeDelegate {
    private let expectation: XCTestExpectation

    private(set) var onSignInVerifyCodeErrorCalled = false
    private(set) var error: MSAL.VerifyCodeError?

    private(set) var onSignInCompletedCalled = false
    private(set) var result: MSAL.MSALNativeAuthUserAccountResult?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    public func onSignInVerifyCodeError(error: MSAL.VerifyCodeError, newState: MSAL.SignInCodeRequiredState?) {
        onSignInVerifyCodeErrorCalled = true
        self.error = error

        expectation.fulfill()
    }

    public func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {
        onSignInCompletedCalled = true
        self.result = result

        expectation.fulfill()
    }
}

class SignInPasswordRequiredDelegateSpy: SignInPasswordRequiredDelegate {
    private let expectation: XCTestExpectation
    private(set) var onSignInPasswordRequiredErrorCalled = false
    private(set) var onSignInCompletedCalled = false
    private(set) var error: MSAL.PasswordRequiredError?
    private(set) var result: MSAL.MSALNativeAuthUserAccountResult?
    private(set) var newState: MSAL.SignInPasswordRequiredState?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }
    func onSignInPasswordRequiredError(error: MSAL.PasswordRequiredError, newState: MSAL.SignInPasswordRequiredState?) {
        onSignInPasswordRequiredErrorCalled = true
        self.error = error
        self.newState = newState

        expectation.fulfill()
    }

    func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {
        onSignInCompletedCalled = true
        self.result = result

        expectation.fulfill()
    }
}
