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

final class SignInCodeRequiredStateTests: XCTestCase {

    private var sut: SignInCodeRequiredState!
    private var controller: MSALNativeAuthSignInControllerMock!

    override func setUp() {
        super.setUp()

        controller = .init()
        sut = .init(scopes: [], controller: controller, continuationToken: "<continuation_token>")
    }

    // MARK: - Delegates

    // ResendCode

    func test_resendCode_delegate_withError_shouldReturnSignInResendCodeError() {
        let expectedError = ResendCodeError(message: "test error")
        let expectedState = SignInCodeRequiredState(scopes: [], controller: controller, continuationToken: "<continuation_token2>")

        let expectedResult: SignInResendCodeResult = .error(
            error: expectedError,
            newState: expectedState
        )
        controller.resendCodeResult = .init(expectedResult)

        let exp = expectation(description: "sign-in states")
        let delegate = SignInResendCodeDelegateSpy(expectation: exp)

        sut.resendCode(delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.newSignInResendCodeError, expectedError)
        XCTAssertEqual(delegate.newSignInCodeRequiredState?.continuationToken, expectedState.continuationToken)
    }

    func test_resendCode_delegate_success_shouldReturnSignInResendCodeCodeRequired() {
        let expectedState = SignInCodeRequiredState(scopes: [], controller: controller, continuationToken: "<continuation_token2>")

        let expectedResult: SignInResendCodeResult = .codeRequired(
            newState: expectedState,
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )
        controller.resendCodeResult = .init(expectedResult)

        let exp = expectation(description: "sign-in states")
        let delegate = SignInResendCodeDelegateSpy(expectation: exp, expectedSentTo: "sentTo", expectedChannelTargetType: .email, expectedCodeLength: 1)

        sut.resendCode(delegate: delegate)
        wait(for: [exp])
        XCTAssertEqual(delegate.newSignInCodeRequiredState?.continuationToken, expectedState.continuationToken)
    }

    // SubmitCode

    func test_submitCode_delegate_withError_shouldReturnSignInVerifyCodeError() {
        let expectedError = VerifyCodeError(type: .invalidCode)
        let expectedState = SignInCodeRequiredState(scopes: [], controller: controller, continuationToken: "<continuation_token2>")

        let expectedResult: SignInVerifyCodeResult = .error(
            error: expectedError,
            newState: expectedState
        )
        controller.submitCodeResult = .init(expectedResult)

        let exp = expectation(description: "sign-in states")
        let delegate = SignInVerifyCodeDelegateSpy(expectation: exp, expectedError: expectedError)
        delegate.expectedNewState = expectedState

        sut.submitCode(code: "1234", delegate: delegate)
        wait(for: [exp])
    }

    func test_submitCode_delegate_success_shouldReturnAccountResult() {
        let expectedAccountResult = MSALNativeAuthUserAccountResultStub.result

        let expectedResult: SignInVerifyCodeResult = .completed(expectedAccountResult)
        controller.submitCodeResult = .init(expectedResult)

        let exp = expectation(description: "sign-in states")
        let delegate = SignInVerifyCodeDelegateSpy(expectation: exp, expectedUserAccountResult: expectedAccountResult)

        sut.submitCode(code: "1234", delegate: delegate)
        wait(for: [exp])
    }
}
