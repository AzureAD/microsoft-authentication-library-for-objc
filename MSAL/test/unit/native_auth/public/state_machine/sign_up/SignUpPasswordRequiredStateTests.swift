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
    private var correlationId: UUID = UUID()

    override func setUpWithError() throws {
        try super.setUpWithError()

        controller = .init()
        sut = SignUpPasswordRequiredState(controller: controller, username: "<username>", continuationToken: "<token>", correlationId: correlationId)
    }

    // MARK: - Delegate

    func test_submitPassword_delegate_whenError_shouldReturnPasswordRequiredError() {
        let expectedError = PasswordRequiredError(type: .invalidPassword, correlationId: correlationId)
        let expectedState = SignUpPasswordRequiredState(controller: controller, username: "", continuationToken: "continuationToken 2", correlationId: correlationId)

        let expectedResult: SignUpPasswordRequiredResult = .error(error: expectedError, newState: expectedState)
        controller.submitPasswordResult = .init(expectedResult, correlationId: correlationId)

        let exp = expectation(description: "sign-up states")
        let delegate = SignUpPasswordRequiredDelegateSpy(expectation: exp)

        sut.submitPassword(password: "1234", delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.error, expectedError)
        XCTAssertEqual(delegate.newPasswordRequiredState?.continuationToken, expectedState.continuationToken)
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }

    func test_submitCode_delegate_whenAttributesRequired_AndUserHasImplementedOptionalDelegate_shouldReturnAttributesRequired() {
        let expectedAttributesRequiredState = SignUpAttributesRequiredState(controller: controller, username: "", continuationToken: "continuationToken 2", correlationId: correlationId)

        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "exp telemetry is called")

        let expectedResult: SignUpPasswordRequiredResult = .attributesRequired(attributes: [], newState: expectedAttributesRequiredState)
        controller.submitPasswordResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpPasswordRequiredDelegateSpy(expectation: exp)

        sut.submitPassword(password: "1234", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.newAttributesRequiredState, expectedAttributesRequiredState)
    }

    func test_submitCode_delegate_whenAttributesRequired_ButUserHasNotImplementedOptionalDelegate_shouldReturnPasswordRequiredError() {
        let expectedAttributesRequiredState = SignUpAttributesRequiredState(controller: controller, username: "", continuationToken: "continuationToken 2", correlationId: correlationId)

        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "exp telemetry is called")

        let expectedResult: SignUpPasswordRequiredResult = .attributesRequired(attributes: [], newState: expectedAttributesRequiredState)
        controller.submitPasswordResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpPasswordRequiredDelegateOptionalMethodsNotImplemented(expectation: exp)

        sut.submitPassword(password: "1234", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpAttributesRequired"))
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }

    func test_submitCode_delegate_whenSuccess_shouldReturnSignUpCompleted() {
        let expectedSignInAfterSignUpState = SignInAfterSignUpState(controller: MSALNativeAuthSignInControllerMock(), username: "", continuationToken: "continuationToken", correlationId: correlationId)

        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "telemetry expectation")

        let expectedResult: SignUpPasswordRequiredResult = .completed(expectedSignInAfterSignUpState)
        controller.submitPasswordResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpPasswordRequiredDelegateSpy(expectation: exp)

        sut.submitPassword(password: "1234", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.signInAfterSignUpState, expectedSignInAfterSignUpState)
    }

    func test_submitCode_delegate_whenSuccess_ButUserHasNotImplementedOptionalDelegate_shouldReturnCorrectError() {
        let expectedSignInAfterSignUpState = SignInAfterSignUpState(controller: MSALNativeAuthSignInControllerMock(), username: "", continuationToken: "continuationToken", correlationId: correlationId)

        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "telemetry expectation")

        let expectedResult: SignUpPasswordRequiredResult = .completed(expectedSignInAfterSignUpState)
        controller.submitPasswordResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpPasswordRequiredDelegateOptionalMethodsNotImplemented(expectation: exp)

        sut.submitPassword(password: "1234", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpCompleted"))
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }
}
