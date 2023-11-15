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
@_implementationOnly import MSAL_Private

class MSALNativeAuthResetPasswordControllerSpy: MSALNativeAuthResetPasswordControlling {
    private let expectation: XCTestExpectation
    private(set) var context: MSIDRequestContext?
    private(set) var flowToken: String?
    private(set) var resetPasswordCalled = false
    private(set) var resendCodeCalled = false
    private(set) var submitCodeCalled = false
    private(set) var submitPasswordCalled = false

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func resetPassword(parameters: MSAL.MSALNativeAuthResetPasswordStartRequestProviderParameters) async -> ResetPasswordStartControllerResponse {
        self.context = parameters.context
        resetPasswordCalled = true
        expectation.fulfill()

        return .init(.error(.init(type: .generalError)))
    }

    func resendCode(passwordResetToken: String, context: MSIDRequestContext) async -> ResetPasswordResendCodeControllerResponse {
        self.flowToken = passwordResetToken
        self.context = context
        resendCodeCalled = true
        expectation.fulfill()

        return .init(.error(error: .init(), newState: nil))
    }

    func submitCode(code: String, passwordResetToken: String, context: MSIDRequestContext) async -> ResetPasswordSubmitCodeControllerResponse {
        self.flowToken = passwordResetToken
        self.context = context
        submitCodeCalled = true
        expectation.fulfill()

        return .init(.error(error: .init(type: .generalError), newState: nil))
    }

    func submitPassword(password: String, passwordSubmitToken: String, context: MSIDRequestContext) async -> ResetPasswordSubmitPasswordControllerResponse {
        self.flowToken = passwordSubmitToken
        self.context = context
        submitPasswordCalled = true
        expectation.fulfill()

        return .init(.error(error: .init(type: .generalError), newState: nil))
    }
}
