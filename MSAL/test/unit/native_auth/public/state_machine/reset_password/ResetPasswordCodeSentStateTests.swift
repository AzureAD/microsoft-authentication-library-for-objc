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

final class ResetPasswordCodeRequiredStateTests: XCTestCase {

    private var controller: MSALNativeAuthResetPasswordControllerMock!
    private var sut: ResetPasswordCodeRequiredState!
    private var correlationId: UUID = UUID()

    override func setUpWithError() throws {
        try super.setUpWithError()

        controller = .init()
        sut = ResetPasswordCodeRequiredState(controller: controller, username: "username", continuationToken: "<token>", correlationId: correlationId)
    }

    // MARK: - Delegates

    // ResendCode

    func test_resendCode_delegate_whenError_shouldReturnCorrectError() {
        let expectedError = ResendCodeError(message: "test error", correlationId: correlationId)
        let expectedState = ResetPasswordCodeRequiredState(controller: controller, username: "", continuationToken: "continuationToken", correlationId: correlationId)

        let expectedResult: ResetPasswordResendCodeResult = .error(error: expectedError, newState: expectedState)
        controller.resendCodeResponse = .init(expectedResult, correlationId: correlationId)

        let exp = expectation(description: "reset password states")
        let delegate = ResetPasswordResendCodeDelegateSpy(expectation: exp)

        sut.resendCode(delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.error, expectedError)
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
        XCTAssertEqual(delegate.newState, expectedState)
    }

    func test_resendCode_delegate_success_shouldReturnCodeRequired() {
        let exp = expectation(description: "reset password states")
        let exp2 = expectation(description: "telemetry expectation")
        let expectedState = ResetPasswordCodeRequiredState(controller: controller, username: "", continuationToken: "continuationToken 2", correlationId: correlationId)

        let expectedResult: ResetPasswordResendCodeResult = .codeRequired(
            newState: expectedState,
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )
        controller.resendCodeResponse = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = ResetPasswordResendCodeDelegateSpy(expectation: exp)

        sut.resendCode(delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.newState?.continuationToken, expectedState.continuationToken)
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertEqual(delegate.codeLength, 1)
    }

    func test_resendCode_delegate_success_whenOptionalMethodNotImplemented_shouldReturnCorrectError() {
        let exp = expectation(description: "reset password states")
        let exp2 = expectation(description: "telemetry expectation")
        let expectedState = ResetPasswordCodeRequiredState(controller: controller, username: "", continuationToken: "continuationToken 2", correlationId: correlationId)

        let expectedResult: ResetPasswordResendCodeResult = .codeRequired(
            newState: expectedState,
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )
        controller.resendCodeResponse = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = ResetPasswordResendCodeDelegateOptionalMethodsNotImplemented(expectation: exp)

        sut.resendCode(delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.errorDescription, String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onResetPasswordResendCodeRequired"))
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }

    // SubmitCode

    func test_submitCode_delegate_whenError_shouldReturnCorrectError() {
        let expectedError = VerifyCodeError(type: .invalidCode, correlationId: correlationId)
        let expectedState = ResetPasswordCodeRequiredState(controller: controller, username: "", continuationToken: "continuationToken", correlationId: correlationId)

        let expectedResult: ResetPasswordSubmitCodeResult = .error(error: expectedError, newState: expectedState)
        controller.submitCodeResponse = .init(expectedResult, correlationId: correlationId)

        let exp = expectation(description: "reset password states")
        let delegate = ResetPasswordVerifyCodeDelegateSpy(expectation: exp)

        sut.submitCode(code: "1234", delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.error, expectedError)
        XCTAssertEqual(delegate.newCodeRequiredState, expectedState)
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }

    func test_submitCode_delegate_success_shouldReturnPasswordRequired() {
        let exp = expectation(description: "reset password states")
        let exp2 = expectation(description: "telemetry expectation")
        let expectedState = ResetPasswordRequiredState(controller: controller, username: "", continuationToken: "continuationToken 2", correlationId: correlationId)

        let expectedResult: ResetPasswordSubmitCodeResult = .passwordRequired(newState: expectedState)
        controller.submitCodeResponse = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = ResetPasswordVerifyCodeDelegateSpy(expectation: exp)

        sut.submitCode(code: "1234", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.newPasswordRequiredState, expectedState)
    }

    func test_submitCode_delegate_success_whenOptionalMethodsNotImplemented_shouldReturnCorrectError() {
        let exp = expectation(description: "reset password states")
        let exp2 = expectation(description: "telemetry expectation")
        let expectedState = ResetPasswordRequiredState(controller: controller, username: "", continuationToken: "continuationToken 2", correlationId: correlationId)

        let expectedResult: ResetPasswordSubmitCodeResult = .passwordRequired(newState: expectedState)
        controller.submitCodeResponse = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = ResetPasswordVerifyCodeDelegateOptionalMethodsNotImplemented(expectation: exp)

        sut.submitCode(code: "1234", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onPasswordRequired"))
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }
}
