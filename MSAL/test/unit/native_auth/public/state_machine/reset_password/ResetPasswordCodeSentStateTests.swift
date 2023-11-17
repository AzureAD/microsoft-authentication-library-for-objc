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

    override func setUpWithError() throws {
        try super.setUpWithError()

        controller = .init()
        sut = ResetPasswordCodeRequiredState(controller: controller, flowToken: "<token>")
    }

    // MARK: - Delegates

    // ResendCode

    func test_resendCode_delegate_whenError_shouldReturnCorrectError() {
        let expectedError = ResendCodeError(message: "test error")
        let expectedState = ResetPasswordCodeRequiredState(controller: controller, flowToken: "flowToken")

        let expectedResult: ResetPasswordResendCodeResult = .error(error: expectedError, newState: expectedState)
        controller.resendCodeResult = .init(expectedResult)

        let exp = expectation(description: "reset password states")
        let delegate = ResetPasswordResendCodeDelegateSpy(expectation: exp)

        sut.resendCode(delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.error, expectedError)
        XCTAssertEqual(delegate.newState, expectedState)
    }

    func test_resendCode_delegate_success_shouldReturnCodeRequired() {
        let expectedState = ResetPasswordCodeRequiredState(controller: controller, flowToken: "flowToken 2")

        let expectedResult: ResetPasswordResendCodeResult = .codeRequired(
            newState: expectedState,
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )
        controller.resendCodeResult = .init(expectedResult)

        let exp = expectation(description: "sign-in states")
        let delegate = ResetPasswordResendCodeDelegateSpy(expectation: exp)

        sut.resendCode(delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.newState?.continuationToken, expectedState.continuationToken)
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertEqual(delegate.codeLength, 1)
    }

    // SubmitCode

    func test_submitCode_delegate_whenError_shouldReturnCorrectError() {
        let expectedError = VerifyCodeError(type: .invalidCode)
        let expectedState = ResetPasswordCodeRequiredState(controller: controller, flowToken: "flowToken")

        let expectedResult: ResetPasswordVerifyCodeResult = .error(error: expectedError, newState: expectedState)
        controller.submitCodeResult = .init(expectedResult)

        let exp = expectation(description: "reset password states")
        let delegate = ResetPasswordVerifyCodeDelegateSpy(expectation: exp)

        sut.submitCode(code: "1234", delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.error, expectedError)
        XCTAssertEqual(delegate.newCodeRequiredState, expectedState)
    }

    func test_submitCode_delegate_success_shouldReturnPasswordRequired() {
        let expectedState = ResetPasswordRequiredState(controller: controller, flowToken: "flowToken 2")

        let expectedResult: ResetPasswordVerifyCodeResult = .passwordRequired(newState: expectedState)
        controller.submitCodeResult = .init(expectedResult)

        let exp = expectation(description: "sign-in states")
        let delegate = ResetPasswordVerifyCodeDelegateSpy(expectation: exp)

        sut.submitCode(code: "1234", delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.newPasswordRequiredState, expectedState)
    }
}
