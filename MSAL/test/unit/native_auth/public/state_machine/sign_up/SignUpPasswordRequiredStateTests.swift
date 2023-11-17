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
@testable import MSAL

final class SignUpPasswordRequiredStateTests: XCTestCase {

    private var controller: MSALNativeAuthSignUpControllerMock!
    private var sut: SignUpPasswordRequiredState!

    override func setUpWithError() throws {
        try super.setUpWithError()

        controller = .init()
        sut = SignUpPasswordRequiredState(controller: controller, username: "<username>", flowToken: "<token>")
    }

    // MARK: - Delegate

    func test_submitPassword_delegate_whenError_shouldReturnPasswordRequiredError() {
        let expectedError = PasswordRequiredError(type: .invalidPassword)
        let expectedState = SignUpPasswordRequiredState(controller: controller, username: "", flowToken: "flowToken 2")

        let expectedResult: SignUpPasswordRequiredResult = .error(error: expectedError, newState: expectedState)
        controller.submitPasswordResult = .init(expectedResult)

        let exp = expectation(description: "sign-up states")
        let delegate = SignUpPasswordRequiredDelegateSpy(expectation: exp)

        sut.submitPassword(password: "1234", delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.error, expectedError)
        XCTAssertEqual(delegate.newPasswordRequiredState?.continuationToken, expectedState.continuationToken)
    }

    func test_submitCode_delegate_whenAttributesRequired_AndUserHasImplementedOptionalDelegate_shouldReturnAttributesRequired() {
        let expectedAttributesRequiredState = SignUpAttributesRequiredState(controller: controller, username: "", flowToken: "flowToken 2")

        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "exp telemetry is called")

        let expectedResult: SignUpPasswordRequiredResult = .attributesRequired(attributes: [], newState: expectedAttributesRequiredState)
        controller.submitPasswordResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpPasswordRequiredDelegateSpy(expectation: exp)

        sut.submitPassword(password: "1234", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.newAttributesRequiredState, expectedAttributesRequiredState)
    }

    func test_submitCode_delegate_whenAttributesRequired_ButUserHasNotImplementedOptionalDelegate_shouldReturnPasswordRequiredError() {
        let expectedError = PasswordRequiredError(type: .generalError, message: MSALNativeAuthErrorMessage.delegateNotImplemented)
        let expectedAttributesRequiredState = SignUpAttributesRequiredState(controller: controller, username: "", flowToken: "flowToken 2")

        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "exp telemetry is called")

        let expectedResult: SignUpPasswordRequiredResult = .attributesRequired(attributes: [], newState: expectedAttributesRequiredState)
        controller.submitPasswordResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpPasswordRequiredDelegateOptionalMethodsNotImplemented(expectation: exp)

        sut.submitPassword(password: "1234", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, expectedError.type)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.delegateNotImplemented)
    }

    func test_submitCode_delegate_whenSuccess_shouldReturnSignUpCompleted() {
        let expectedSignInAfterSignUpState = SignInAfterSignUpState(controller: MSALNativeAuthSignInControllerMock(), username: "", slt: "slt")

        let exp = expectation(description: "sign-up states")

        let expectedResult: SignUpPasswordRequiredResult = .completed(expectedSignInAfterSignUpState)
        controller.submitPasswordResult = .init(expectedResult)

        let delegate = SignUpPasswordRequiredDelegateSpy(expectation: exp)

        sut.submitPassword(password: "1234", delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.signInAfterSignUpState, expectedSignInAfterSignUpState)
    }
}
