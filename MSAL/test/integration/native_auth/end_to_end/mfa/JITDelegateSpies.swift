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

import Foundation
import XCTest
import MSAL

class RegisterStrongAuthChallengeDelegateSpy: RegisterStrongAuthChallengeDelegate {
    private let expectation: XCTestExpectation
    private(set) var onRegisterStrongAuthVerificationRequiredCalled = false
    private(set) var onRegisterStrongAuthChallengeErrorCalled = false
    private(set) var newStateVerificationRequired: RegisterStrongAuthVerificationRequiredState?
    private(set) var error: RegisterStrongAuthChallengeError?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onRegisterStrongAuthVerificationRequired(result: MSALNativeAuthRegisterStrongAuthVerificationRequiredResult) {
        onRegisterStrongAuthVerificationRequiredCalled = true
        newStateVerificationRequired = result.newState
        expectation.fulfill()
    }

    func onRegisterStrongAuthChallengeError(error: MSAL.RegisterStrongAuthChallengeError, newState: MSAL.RegisterStrongAuthState?) {
        onRegisterStrongAuthChallengeErrorCalled = true
        self.error = error
        expectation.fulfill()
    }
}

class RegisterStrongAuthSubmitChallengeDelegateSpy: RegisterStrongAuthSubmitChallengeDelegate {
    private let expectation: XCTestExpectation
    private(set) var onSignInCompletedCalled = false
    private(set) var onRegisterStrongAuthSubmitChallengeErrorCalled = false
    private(set) var result: MSALNativeAuthUserAccountResult?
    private(set) var error: RegisterStrongAuthSubmitChallengeError?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func onSignInCompleted(result: MSALNativeAuthUserAccountResult) {
        onSignInCompletedCalled = true
        self.result = result
        expectation.fulfill()
    }

    func onRegisterStrongAuthSubmitChallengeError(error: RegisterStrongAuthSubmitChallengeError, newState: RegisterStrongAuthVerificationRequiredState?) {
        onRegisterStrongAuthSubmitChallengeErrorCalled = true
        self.error = error
        expectation.fulfill()
    }
}
