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
    private(set) var continuationToken: String?
    private(set) var resetPasswordCalled = false
    private(set) var resendCodeCalled = false
    private(set) var submitCodeCalled = false
    private(set) var submitPasswordCalled = false
    private(set) var username = ""

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func resetPassword(parameters: MSAL.MSALNativeAuthResetPasswordStartRequestProviderParameters) async -> ResetPasswordStartControllerResponse {
        self.context = parameters.context
        resetPasswordCalled = true
        expectation.fulfill()

        return .init(.error(.init(type: .generalError, correlationId: .init())), correlationId: parameters.context.correlationId())
    }

    func resendCode(username: String, continuationToken: String, context: MSALNativeAuthRequestContext) async -> ResetPasswordResendCodeControllerResponse {
        self.continuationToken = continuationToken
        self.username = username
        self.context = context
        resendCodeCalled = true
        expectation.fulfill()

        return .init(.error(error: .init(correlationId: .init()), newState: nil), correlationId: context.correlationId())
    }

    func submitCode(code: String, username: String, continuationToken: String, context: MSALNativeAuthRequestContext) async -> ResetPasswordSubmitCodeControllerResponse {
        self.continuationToken = continuationToken
        self.username = username
        self.context = context
        submitCodeCalled = true
        expectation.fulfill()

        return .init(.error(error: .init(type: .generalError, correlationId: .init()), newState: nil), correlationId: context.correlationId())
    }

    func submitPassword(password: String, username: String, continuationToken: String, context: MSALNativeAuthRequestContext) async -> ResetPasswordSubmitPasswordControllerResponse {
        self.continuationToken = continuationToken
        self.username = username
        self.context = context
        submitPasswordCalled = true
        expectation.fulfill()

        return .init(.error(error: .init(type: .generalError, correlationId: .init()), newState: nil), correlationId: context.correlationId())
    }
}
