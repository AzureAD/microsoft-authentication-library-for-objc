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

final class ResetPasswordRequiredStateTests: XCTestCase {

    private var correlationId: UUID = UUID()
    private var exp: XCTestExpectation!
    private var controllerSpy: MSALNativeAuthResetPasswordControllerSpy!
    private var controllerMock: MSALNativeAuthResetPasswordControllerMock!
    private var sut: ResetPasswordRequiredState!

    func test_submitPassword_usesControllerSuccessfully() {
        exp = expectation(description: "ResetPasswordRequiredState expectation")
        controllerSpy = MSALNativeAuthResetPasswordControllerSpy(expectation: exp)
        XCTAssertNil(controllerSpy.context)
        XCTAssertFalse(controllerSpy.submitPasswordCalled)

        let sut = ResetPasswordRequiredState(controller: controllerSpy, flowToken: "<token>", correlationId: correlationId)
        sut.submitPassword(password: "1234", delegate: ResetPasswordRequiredDelegateSpy())

        wait(for: [exp], timeout: 1)
        XCTAssertEqual(controllerSpy.context?.correlationId(), correlationId)
        XCTAssertTrue(controllerSpy.submitPasswordCalled)
    }

    func test_submitPassword_delegate_whenError_shouldReturnCorrectError() {
        controllerMock = MSALNativeAuthResetPasswordControllerMock()
        let sut = ResetPasswordRequiredState(controller: controllerMock, flowToken: "<token>", correlationId: correlationId)

        let expectedError = PasswordRequiredError(type: .invalidPassword, message: nil)
        let expectedState = ResetPasswordRequiredState(controller: controllerMock, flowToken: "flowToken", correlationId: correlationId)

        let expectedResult: MSALNativeAuthResetPasswordControlling.ResetPasswordSubmitPasswordControllerResponse = .init(.error(error: expectedError, newState: expectedState))
        controllerMock.submitPasswordResult = expectedResult

        let exp = expectation(description: "reset password states")
        let delegate = ResetPasswordRequiredDelegateSpy(expectation: exp)

        sut.submitPassword(password: "incorrect", delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.error?.type, expectedError.type)
        XCTAssertEqual(delegate.newPasswordRequiredState, expectedState)
    }

    func test_submitPassword_delegate_whenSuccess_shouldReturnCompleted() {
        let exp = expectation(description: "reset password states")
        let exp2 = expectation(description: "telemetry expectation")
        controllerMock = MSALNativeAuthResetPasswordControllerMock()
        let sut = ResetPasswordRequiredState(controller: controllerMock, flowToken: "<token>", correlationId: correlationId)

        let expectedResult: MSALNativeAuthResetPasswordControlling.ResetPasswordSubmitPasswordControllerResponse = .init(.completed, telemetryUpdate: { _ in
            exp2.fulfill()
        })
        controllerMock.submitPasswordResult = expectedResult

        let delegate = ResetPasswordRequiredDelegateSpy(expectation: exp)

        sut.submitPassword(password: "incorrect", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertTrue(delegate.onResetPasswordCompletedCalled)
    }

    func test_submitPassword_delegate_whenSuccess_butOptionalMethodsNotImplemented_shouldReturnCorrectError() {
        let exp = expectation(description: "reset password states")
        let exp2 = expectation(description: "telemetry expectation")
        controllerMock = MSALNativeAuthResetPasswordControllerMock()
        let sut = ResetPasswordRequiredState(controller: controllerMock, flowToken: "<token>", correlationId: correlationId)

        let expectedResult: MSALNativeAuthResetPasswordControlling.ResetPasswordSubmitPasswordControllerResponse = .init(.completed, telemetryUpdate: { _ in
            exp2.fulfill()
        })
        controllerMock.submitPasswordResult = expectedResult

        let delegate = ResetPasswordRequiredDelegateOptionalMethodsNotImplemented(expectation: exp)

        sut.submitPassword(password: "incorrect", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.requiredDelegateMethod("onResetPasswordCompleted"))
    }
}
