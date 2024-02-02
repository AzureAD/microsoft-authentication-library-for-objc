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

final class SignInPasswordRequiredStateTests: XCTestCase {

    private var sut: SignInPasswordRequiredState!
    private var controller: MSALNativeAuthSignInControllerMock!
    private var correlationId: UUID = UUID()

    override func setUp() {
        super.setUp()

        controller = .init()
        sut = .init(scopes: [], username: "username", controller: controller, continuationToken: "continuationToken", correlationId: correlationId)
    }

    // MARK: - Delegates

    func test_submitPassword_delegate_withError_shouldReturnError() {
        let expectedError = PasswordRequiredError(type: .invalidPassword, correlationId: .init())
        let expectedState = SignInPasswordRequiredState(scopes: [], username: "", controller: controller, continuationToken: "continuationToken 2", correlationId: correlationId)

        let expectedResult: SignInPasswordRequiredResult = .error(
            error: expectedError,
            newState: expectedState
        )
        controller.submitPasswordResult = .init(expectedResult, correlationId: correlationId)

        let exp = expectation(description: "sign-in states")
        let delegate = SignInPasswordRequiredDelegateSpy(expectation: exp, expectedError: expectedError)

        sut.submitPassword(password: "invalid password", delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.newPasswordRequiredState?.continuationToken, expectedState.continuationToken)
    }

    func test_submitPassword_delegate_success_shouldReturnSuccess() {
        let exp = expectation(description: "sign-in states")
        let exp2 = expectation(description: "expectation Telemetry")
        let expectedAccountResult = MSALNativeAuthUserAccountResultStub.result

        let expectedResult: SignInPasswordRequiredResult = .completed(expectedAccountResult)
        controller.submitPasswordResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignInPasswordRequiredDelegateSpy(expectation: exp, expectedUserAccountResult: expectedAccountResult)

        sut.submitPassword(password: "password", delegate: delegate)
        wait(for: [exp, exp2])
    }

    func test_submitPassword_delegate_success_whenMethodsNotImplemented_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-in states")
        let exp2 = expectation(description: "expectation Telemetry")
        let expectedAccountResult = MSALNativeAuthUserAccountResultStub.result

        let expectedResult: SignInPasswordRequiredResult = .completed(expectedAccountResult)
        controller.submitPasswordResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignInPasswordRequiredDelegateOptionalMethodsNotImplemented(expectation: exp)

        sut.submitPassword(password: "password", delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.delegateError?.errorDescription, String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignInCompleted"))
        XCTAssertEqual(delegate.delegateError?.correlationId, correlationId)
    }
}
