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

@testable import MSAL
import XCTest

final class ResetPasswordRequiredDelegateDispatcherTests: XCTestCase {

    private var telemetryExp: XCTestExpectation!
    private var delegateExp: XCTestExpectation!
    private var sut: ResetPasswordRequiredDelegateDispatcher!
    private let signInControllerMock = MSALNativeAuthSignInControllerMock()
    private let correlationId = UUID()

    override func setUp() {
        super.setUp()
        telemetryExp = expectation(description: "delegateDispatcher telemetry exp")
        delegateExp = expectation(description: "delegateDispatcher delegate exp")
    }

    func test_dispatchPasswordRequired_whenDelegateMethodsAreImplemented() async {
        let delegate = ResetPasswordRequiredDelegateSpy(expectation: delegateExp)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case .success = result else {
                return XCTFail("wrong result")
            }
            self.telemetryExp.fulfill()
        })

        let expectedState = SignInAfterResetPasswordState(
            controller: signInControllerMock,
            username: "username",
            continuationToken: "continuationToken",
            correlationId: correlationId
        )

        await sut.dispatchResetPasswordCompleted(newState: expectedState, correlationId: correlationId)

        await fulfillment(of: [telemetryExp, delegateExp])

        XCTAssertTrue(delegate.onResetPasswordCompletedCalled)
        XCTAssertEqual(delegate.signInAfterResetPasswordState, expectedState)
    }

    func test_dispatchPasswordRequired_whenDelegateOptionalMethodsNotImplemented() async {
        let delegate = ResetPasswordRequiredDelegateOptionalMethodsNotImplemented(expectation: delegateExp)
        let expectedError = PasswordRequiredError(type: .generalError, message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onResetPasswordCompleted"), correlationId: correlationId)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case let .failure(error) = result, let customError = error as? PasswordRequiredError else {
                return XCTFail("wrong result")
            }

            checkError(customError)
            self.telemetryExp.fulfill()
        })

        let expectedState = SignInAfterResetPasswordState(
            controller: signInControllerMock,
            username: "username",
            continuationToken: "continuationToken",
            correlationId: correlationId
        )

        await sut.dispatchResetPasswordCompleted(newState: expectedState, correlationId: correlationId)

        await fulfillment(of: [telemetryExp, delegateExp])
        checkError(delegate.error)

        func checkError(_ error: PasswordRequiredError?) {
            XCTAssertEqual(error?.type, expectedError.type)
            XCTAssertEqual(error?.errorDescription, expectedError.errorDescription)
            XCTAssertEqual(error?.correlationId, expectedError.correlationId)
        }
    }
}
