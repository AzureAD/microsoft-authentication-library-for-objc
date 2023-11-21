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

final class SignUpCodeRequiredStateTests: XCTestCase {

    private var controller: MSALNativeAuthSignUpControllerMock!
    private var sut: SignUpCodeRequiredState!
    private var correlationId: UUID = UUID()

    override func setUpWithError() throws {
        try super.setUpWithError()

        controller = .init()
        sut = SignUpCodeRequiredState(controller: controller, username: "<username>", flowToken: "<token>", correlationId: correlationId)
    }

    // MARK: - Delegates

    // ResendCode

    func test_resendCode_delegate_whenError_shouldReturnCorrectError() {
        let expectedError = ResendCodeError(message: "test error")

        let expectedResult: SignUpResendCodeResult = .error(error: expectedError, newState: nil)
        controller.resendCodeResult = .init(expectedResult)

        let exp = expectation(description: "sign-up states")
        let delegate = SignUpResendCodeDelegateSpy(expectation: exp)

        sut.resendCode(delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.error, expectedError)
    }

    func test_resendCode_delegate_success_shouldReturnCodeRequired() {
        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "telemetry expectation")
        let expectedState = SignUpCodeRequiredState(controller: controller, username: "", flowToken: "flowToken 2", correlationId: correlationId)

        let expectedResult: SignUpResendCodeResult = .codeRequired(
            newState: expectedState,
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )
        controller.resendCodeResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpResendCodeDelegateSpy(expectation: exp)

        sut.resendCode(delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.newState?.flowToken, expectedState.flowToken)
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertEqual(delegate.codeLength, 1)
    }

    func test_resendCode_delegate_success_butMethodNotImplemented() {
        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "telemetry expectation")
        let expectedState = SignUpCodeRequiredState(controller: controller, username: "", flowToken: "flowToken 2", correlationId: correlationId)

        let expectedResult: SignUpResendCodeResult = .codeRequired(
            newState: expectedState,
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )
        controller.resendCodeResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpResendCodeDelegateMethodsNotImplemented(expectation: exp)

        sut.resendCode(delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.errorDescription, String(format: MSALNativeAuthErrorMessage.requiredDelegateMethod, "onSignUpResendCodeCodeRequired"))
    }

    // SubmitCode

    func test_submitCode_delegate_whenError_shouldReturnCorrectError() {
        let expectedError = VerifyCodeError(type: .invalidCode)
        let expectedState = SignUpCodeRequiredState(controller: controller, username: "", flowToken: "flowToken 2", correlationId: correlationId)

        let expectedResult: SignUpVerifyCodeResult = .error(
            error: expectedError,
            newState: expectedState
        )
        controller.submitCodeResult = .init(expectedResult)

        let exp = expectation(description: "sign-up states")
        let delegate = SignUpVerifyCodeDelegateSpy(expectation: exp)

        sut.submitCode(code: "1234", delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.error, expectedError)
        XCTAssertEqual(delegate.newCodeRequiredState?.flowToken, expectedState.flowToken)
    }

    func test_submitCode_delegate_whenPasswordRequired_AndUserHasImplementedOptionalDelegate_shouldReturnPasswordRequired() {
        let expectedPasswordRequiredState = SignUpPasswordRequiredState(controller: controller, username: "", flowToken: "flowToken 2", correlationId: correlationId)

        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "exp telemetry is called")

        let expectedResult: SignUpVerifyCodeResult = .passwordRequired(expectedPasswordRequiredState)
        controller.submitCodeResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpVerifyCodeDelegateSpy(expectation: exp)

        sut.submitCode(code: "1234", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.newPasswordRequiredState, expectedPasswordRequiredState)
    }

    func test_submitCode_delegate_whenPasswordRequired_ButUserHasNotImplementedOptionalDelegate_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "exp telemetry is called")

        let expectedResult: SignUpVerifyCodeResult = .passwordRequired(.init(controller: controller, username: "", flowToken: "", correlationId: correlationId))
        controller.submitCodeResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpVerifyCodeDelegateOptionalMethodsNotImplemented(expectation: exp)

        sut.submitCode(code: "1234", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            String(format: MSALNativeAuthErrorMessage.requiredDelegateMethod, "onSignUpPasswordRequired")
        )
    }

    func test_submitCode_delegate_whenAttributesRequired_AndUserHasImplementedOptionalDelegate_shouldReturnAttributesRequired() {
        let expectedAttributesRequiredState = SignUpAttributesRequiredState(controller: controller, username: "", flowToken: "flowToken 2", correlationId: correlationId)

        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "exp telemetry is called")

        let expectedResult: SignUpVerifyCodeResult = .attributesRequired(attributes: [], newState: expectedAttributesRequiredState)
        controller.submitCodeResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpVerifyCodeDelegateSpy(expectation: exp)

        sut.submitCode(code: "1234", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.newAttributesRequiredState, expectedAttributesRequiredState)
    }

    func test_submitCode_delegate_whenAttributesRequired_ButUserHasNotImplementedOptionalDelegate_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "exp telemetry is called")

        let expectedResult: SignUpVerifyCodeResult = .attributesRequired(attributes: [], newState: .init(controller: controller, username: "", flowToken: "", correlationId: correlationId))
        controller.submitCodeResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpVerifyCodeDelegateOptionalMethodsNotImplemented(expectation: exp)

        sut.submitCode(code: "1234", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            String(format: MSALNativeAuthErrorMessage.requiredDelegateMethod, "onSignUpAttributesRequired")
        )
    }

    func test_submitCode_delegate_whenSuccess_shouldReturnAccountResult() {
        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "telemetry expectation")
        let expectedSignInAfterSignUpState = SignInAfterSignUpState(controller: MSALNativeAuthSignInControllerMock(), username: "", slt: "slt", correlationId: correlationId)

        let expectedResult: SignUpVerifyCodeResult = .completed(expectedSignInAfterSignUpState)
        controller.submitCodeResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpVerifyCodeDelegateSpy(expectation: exp)

        sut.submitCode(code: "1234", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.newSignInAfterSignUpState, expectedSignInAfterSignUpState)
    }

    func test_submitCode_delegate_whenSuccess_ButUserHasNotImplementedOptionalDelegate_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "telemetry expectation")
        let expectedSignInAfterSignUpState = SignInAfterSignUpState(controller: MSALNativeAuthSignInControllerMock(), username: "", slt: "slt", correlationId: correlationId)
        let result: SignUpVerifyCodeResult = .completed(expectedSignInAfterSignUpState)
        controller.submitCodeResult = .init(result, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpVerifyCodeDelegateOptionalMethodsNotImplemented(expectation: exp)

        sut.submitCode(code: "1234", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            String(format: MSALNativeAuthErrorMessage.requiredDelegateMethod, "onSignUpCompleted")
        )
    }
}
