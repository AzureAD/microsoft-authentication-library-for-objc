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

final class SignUpResendCodeDelegateDispatcherTests: XCTestCase {

    private var telemetryExp: XCTestExpectation!
    private var delegateExp: XCTestExpectation!
    private var sut: SignUpResendCodeDelegateDispatcher!
    private let controllerFactoryMock = MSALNativeAuthControllerFactoryMock()
    private let correlationId = UUID()

    override func setUp() {
        super.setUp()
        telemetryExp = expectation(description: "delegateDispatcher telemetry exp")
        delegateExp = expectation(description: "delegateDispatcher delegate exp")
    }

    func test_dispatchSignUpResendCode_whenDelegateMethodsAreImplemented() async {
        let delegate = SignUpResendCodeDelegateSpy(expectation: delegateExp)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case .success = result else {
                return XCTFail("wrong result")
            }
            self.telemetryExp.fulfill()
        })

        let expectedState = SignUpCodeRequiredState(controller: controllerFactoryMock.signUpController, username: "", continuationToken: "continuationToken", correlationId: correlationId)
        let expectedSentTo = "user@contoso.com"
        let expectedChannelTargetType = MSALNativeAuthChannelType.email
        let expectedCodeLength = 4

        await sut.dispatchSignUpResendCodeCodeRequired(
            newState: expectedState,
            sentTo: expectedSentTo,
            channelTargetType: expectedChannelTargetType,
            codeLength: expectedCodeLength,
            correlationId: correlationId
        )

        await fulfillment(of: [telemetryExp, delegateExp])

        XCTAssertEqual(delegate.newState, expectedState)
        XCTAssertEqual(delegate.sentTo, expectedSentTo)
        XCTAssertEqual(delegate.channelTargetType, expectedChannelTargetType)
        XCTAssertEqual(delegate.codeLength, expectedCodeLength)
    }

    func test_dispatchSignUpResendCode_whenDelegateOptionalMethodsNotImplemented() async {
        let delegate = SignUpResendCodeDelegateMethodsNotImplemented(expectation: delegateExp)
        let expectedError = ResendCodeError(message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpResendCodeCodeRequired"), correlationId: correlationId)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case let .failure(error) = result, let customError = error as? ResendCodeError else {
                return XCTFail("wrong result")
            }

            checkError(customError)
            self.telemetryExp.fulfill()
        })

        let expectedState = SignUpCodeRequiredState(controller: controllerFactoryMock.signUpController, username: "", continuationToken: "continuationToken", correlationId: correlationId)
        let expectedSentTo = "user@contoso.com"
        let expectedChannelTargetType = MSALNativeAuthChannelType.email
        let expectedCodeLength = 4

        await sut.dispatchSignUpResendCodeCodeRequired(
            newState: expectedState,
            sentTo: expectedSentTo,
            channelTargetType: expectedChannelTargetType,
            codeLength: expectedCodeLength,
            correlationId: correlationId
        )

        await fulfillment(of: [telemetryExp, delegateExp])
        checkError(delegate.error)

        func checkError(_ error: ResendCodeError?) {
            XCTAssertEqual(error?.errorDescription, expectedError.errorDescription)
            XCTAssertEqual(error?.correlationId, expectedError.correlationId)
        }
    }
}
