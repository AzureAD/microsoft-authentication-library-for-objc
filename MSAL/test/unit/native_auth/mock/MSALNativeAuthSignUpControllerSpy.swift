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

class MSALNativeAuthSignUpControllerSpy: MSALNativeAuthSignUpControlling {
    private let expectation: XCTestExpectation
    private(set) var context: MSIDRequestContext?
    private(set) var signUpStartPasswordCalled = false
    private(set) var signUpStartCalled = false
    private(set) var resendCodeCalled = false
    private(set) var submitCodeCalled = false
    private(set) var submitPasswordCalled = false
    private(set) var submitAttributesCalled = false

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func signUpStartPassword(
        parameters: MSAL.MSALNativeAuthSignUpStartRequestProviderParameters
    ) async -> MSALNativeAuthSignUpControlling.SignUpStartPasswordControllerResponse {
        self.context = parameters.context
        signUpStartPasswordCalled = true
        expectation.fulfill()
        return .init(.error(.init(type: .generalError)))
    }

    func signUpStartCode(
        parameters: MSAL.MSALNativeAuthSignUpStartRequestProviderParameters
    ) async -> MSALNativeAuthSignUpControlling.SignUpStartCodeControllerResponse {
        self.context = parameters.context
        signUpStartCalled = true
        expectation.fulfill()
        return .init(.error(.init(type: .generalError)))
    }

    func resendCode(
        username: String,
        context: MSIDRequestContext,
        signUpToken: String
    ) async -> SignUpResendCodeResult {
        self.context = context
        resendCodeCalled = true
        expectation.fulfill()
        return .error(.init())
    }

    func submitCode(
        _ code: String,
        username: String,
        signUpToken: String,
        context: MSIDRequestContext
    ) async -> MSALNativeAuthSignUpControlling.SignUpSubmitCodeControllerResponse {
        self.context = context
        submitCodeCalled = true
        expectation.fulfill()
        return .init(.error(error: .init(type: .generalError), newState: nil))
    }

    func submitPassword(
        _ password: String,
        username: String,
        signUpToken: String,
        context: MSIDRequestContext
    ) async -> MSALNativeAuthSignUpControlling.SignUpSubmitPasswordControllerResponse {
        self.context = context
        submitPasswordCalled = true
        expectation.fulfill()
        return .init(.error(error: .init(type: .generalError), newState: nil))
    }

    func submitAttributes(
        _ attributes: [String: Any],
        username: String,
        signUpToken: String,
        context: MSIDRequestContext
    ) async -> SignUpAttributesRequiredResult {
        self.context = context
        submitAttributesCalled = true
        expectation.fulfill()
        return .error(error: .init())
    }
}
