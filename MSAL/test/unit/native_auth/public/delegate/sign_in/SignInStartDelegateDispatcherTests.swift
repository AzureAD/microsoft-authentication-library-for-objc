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

final class SignInStartDelegateDispatcherTests: XCTestCase {
    private var telemetryExp: XCTestExpectation!
    private var delegateExp: XCTestExpectation!
    private var sut: SignInStartDelegateDispatcher!
    private let controllerFactoryMock = MSALNativeAuthControllerFactoryMock()
    private let correlationId = UUID()

    override func setUp() {
        super.setUp()
        telemetryExp = expectation(description: "delegateDispatcher telemetry exp")
        delegateExp = expectation(description: "delegateDispatcher delegate exp")
    }

    func test_dispatchSignInCodeRequired_whenDelegateMethodsAreImplemented() async {
        let expectedState = SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, flowToken: "flowToken", correlationId: correlationId)
        let expectedSentTo = "user@contoso.com"
        let expectedChannelTargetType = MSALNativeAuthChannelType.email
        let expectedCodeLength = 4

        let delegate = SignInCodeStartDelegateSpy(expectation: delegateExp, expectedSentTo: expectedSentTo, expectedChannelTargetType: expectedChannelTargetType, expectedCodeLength: expectedCodeLength)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case .success = result else {
                return XCTFail("wrong result")
            }
            self.telemetryExp.fulfill()
        })

        await sut.dispatchSignInCodeRequired(
            newState: expectedState,
            sentTo: expectedSentTo,
            channelTargetType: expectedChannelTargetType,
            codeLength: expectedCodeLength
        )

        await fulfillment(of: [telemetryExp, delegateExp])

        XCTAssertEqual(delegate.newSignInCodeRequiredState, expectedState)
        XCTAssertEqual(delegate.expectedSentTo, expectedSentTo)
        XCTAssertEqual(delegate.expectedChannelTargetType, expectedChannelTargetType)
        XCTAssertEqual(delegate.expectedCodeLength, expectedCodeLength)
    }

    func test_dispatchSignInCodeRequired_whenDelegateOptionalMethodsNotImplemented() async {
        let expectedError = SignInStartError(type: .generalError, message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignInCodeRequired"))
        let delegate = SignInCodeStartDelegateOptionalMethodNotImplemented(expectation: delegateExp, expectedError: expectedError)


        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case let .failure(error) = result, let customError = error as? SignInStartError else {
                return XCTFail("wrong result")
            }

            checkError(customError)
            self.telemetryExp.fulfill()
        })

        let expectedState = SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, flowToken: "flowToken", correlationId: correlationId)
        let expectedSentTo = "user@contoso.com"
        let expectedChannelTargetType = MSALNativeAuthChannelType.email
        let expectedCodeLength = 4

        await sut.dispatchSignInCodeRequired(
            newState: expectedState,
            sentTo: expectedSentTo,
            channelTargetType: expectedChannelTargetType,
            codeLength: expectedCodeLength
        )

        await fulfillment(of: [telemetryExp, delegateExp])
        checkError(delegate.expectedError)

        func checkError(_ error: SignInStartError?) {
            XCTAssertEqual(error?.type, expectedError.type)
            XCTAssertEqual(error?.errorDescription, expectedError.errorDescription)
        }
    }

    func test_dispatchSignInPasswordRequired_whenDelegateMethodsAreImplemented() async {
        let delegate = SignInCodeStartDelegateWithPasswordRequiredSpy(expectation: delegateExp)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case .success = result else {
                return XCTFail("wrong result")
            }
            self.telemetryExp.fulfill()
        })

        let expectedState = SignInPasswordRequiredState(scopes: [], username: "username", controller: controllerFactoryMock.signInController, flowToken: "flowToken", correlationId: correlationId)

        await sut.dispatchSignInPasswordRequired(newState: expectedState)

        await fulfillment(of: [telemetryExp, delegateExp])

        XCTAssertEqual(delegate.passwordRequiredState, expectedState)
    }

    func test_dispatchSignInPasswordRequired_whenDelegateOptionalMethodsNotImplemented() async {
        let expectedError = SignInStartError(type: .generalError, message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignInPasswordRequired"))
        let delegate = SignInCodeStartDelegateOptionalMethodNotImplemented(expectation: delegateExp, expectedError: expectedError)


        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case let .failure(error) = result, let customError = error as? SignInStartError else {
                return XCTFail("wrong result")
            }

            checkError(customError)
            self.telemetryExp.fulfill()
        })

        let expectedState = SignInPasswordRequiredState(scopes: [], username: "username", controller: controllerFactoryMock.signInController, flowToken: "flowToken", correlationId: correlationId)

        await sut.dispatchSignInPasswordRequired(newState: expectedState)

        await fulfillment(of: [telemetryExp, delegateExp])
        checkError(delegate.expectedError)

        func checkError(_ error: SignInStartError?) {
            XCTAssertEqual(error?.type, expectedError.type)
            XCTAssertEqual(error?.errorDescription, expectedError.errorDescription)
        }
    }
}
