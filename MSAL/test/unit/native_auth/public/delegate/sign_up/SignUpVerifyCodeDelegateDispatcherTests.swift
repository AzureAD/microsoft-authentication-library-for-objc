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

final class SignUpVerifyCodeDelegateDispatcherTests: XCTestCase {

    private var telemetryExp: XCTestExpectation!
    private var delegateExp: XCTestExpectation!
    private var sut: SignUpVerifyCodeDelegateDispatcher!
    private let controllerFactoryMock = MSALNativeAuthControllerFactoryMock()
    private let correlationId = UUID()

    override func setUp() {
        super.setUp()
        telemetryExp = expectation(description: "delegateDispatcher telemetry exp")
        delegateExp = expectation(description: "delegateDispatcher delegate exp")
    }

    func test_dispatchSignUpAttributesRequired_whenDelegateMethodsAreImplemented() async {
        let delegate = SignUpVerifyCodeDelegateSpy(expectation: delegateExp)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case .success = result else {
                return XCTFail("wrong result")
            }
            self.telemetryExp.fulfill()
        })

        let expectedAttributes: [MSALNativeAuthRequiredAttributes] = [
            .init(name: "attribute1", type: "", required: true),
            .init(name: "attribute2", type: "", required: true),
        ]

        let expectedState = SignUpAttributesRequiredState(controller: controllerFactoryMock.signUpController, username: "", flowToken: "flowToken", correlationId: correlationId)

        await sut.dispatchSignUpAttributesRequired(attributes: expectedAttributes, newState: expectedState)

        await fulfillment(of: [telemetryExp, delegateExp])

        XCTAssertEqual(delegate.newAttributesRequired, expectedAttributes)
        XCTAssertEqual(delegate.newAttributesRequiredState, expectedState)
    }

    func test_dispatchSignUpVerifyCode_whenDelegateOptionalMethodsNotImplemented() async {
        let delegate = SignUpVerifyCodeDelegateOptionalMethodsNotImplemented(expectation: delegateExp)
        let expectedError = VerifyCodeError(type: .generalError, message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpAttributesRequired"))

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case let .failure(error) = result, let customError = error as? VerifyCodeError else {
                return XCTFail("wrong result")
            }

            checkError(customError)
            self.telemetryExp.fulfill()
        })

        let expectedAttributes: [MSALNativeAuthRequiredAttributes] = [
            .init(name: "attribute1", type: "", required: true),
            .init(name: "attribute2", type: "", required: true),
        ]

        let expectedState = SignUpAttributesRequiredState(controller: controllerFactoryMock.signUpController, username: "", flowToken: "flowToken", correlationId: correlationId)

        await sut.dispatchSignUpAttributesRequired(attributes: expectedAttributes, newState: expectedState)

        await fulfillment(of: [telemetryExp, delegateExp])
        checkError(delegate.error)

        func checkError(_ error: VerifyCodeError?) {
            XCTAssertEqual(error?.type, expectedError.type)
            XCTAssertEqual(error?.errorDescription, expectedError.errorDescription)
        }
    }

    func test_dispatchSignUpPasswordRequired_whenDelegateMethodsAreImplemented() async {
        let delegate = SignUpVerifyCodeDelegateSpy(expectation: delegateExp)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case .success = result else {
                return XCTFail("wrong result")
            }
            self.telemetryExp.fulfill()
        })

        let expectedState = SignUpPasswordRequiredState(controller: controllerFactoryMock.signUpController, username: "", flowToken: "flowToken", correlationId: correlationId)

        await sut.dispatchSignUpPasswordRequired(newState: expectedState)

        await fulfillment(of: [telemetryExp, delegateExp])

        XCTAssertEqual(delegate.newPasswordRequiredState, expectedState)
    }

    func test_dispatchSignUpPasswordRequired_whenDelegateOptionalMethodsNotImplemented() async {
        let delegate = SignUpVerifyCodeDelegateOptionalMethodsNotImplemented(expectation: delegateExp)
        let expectedError = VerifyCodeError(type: .generalError, message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpPasswordRequired"))

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case let .failure(error) = result, let customError = error as? VerifyCodeError else {
                return XCTFail("wrong result")
            }

            checkError(customError)
            self.telemetryExp.fulfill()
        })

        let expectedState = SignUpPasswordRequiredState(controller: controllerFactoryMock.signUpController, username: "", flowToken: "flowToken", correlationId: correlationId)

        await sut.dispatchSignUpPasswordRequired(newState: expectedState)

        await fulfillment(of: [telemetryExp, delegateExp])
        checkError(delegate.error)

        func checkError(_ error: VerifyCodeError?) {
            XCTAssertEqual(error?.type, expectedError.type)
            XCTAssertEqual(error?.errorDescription, expectedError.errorDescription)
        }
    }

    func test_dispatchSignUpCompleted_whenDelegateMethodsAreImplemented() async {
        let delegate = SignUpVerifyCodeDelegateSpy(expectation: delegateExp)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case .success = result else {
                return XCTFail("wrong result")
            }
            self.telemetryExp.fulfill()
        })

        let expectedState = SignInAfterSignUpState(controller: controllerFactoryMock.signInController, username: "", slt: "flowToken", correlationId: correlationId)

        await sut.dispatchSignUpCompleted(newState: expectedState)

        await fulfillment(of: [telemetryExp, delegateExp])

        XCTAssertEqual(delegate.newSignInAfterSignUpState, expectedState)
    }

    func test_dispatchSignUpCompleted_whenDelegateOptionalMethodsNotImplemented() async {
        let delegate = SignUpVerifyCodeDelegateOptionalMethodsNotImplemented(expectation: delegateExp)
        let expectedError = VerifyCodeError(type: .generalError, message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpCompleted"))

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case let .failure(error) = result, let customError = error as? VerifyCodeError else {
                return XCTFail("wrong result")
            }

            checkError(customError)
            self.telemetryExp.fulfill()
        })

        let expectedState = SignInAfterSignUpState(controller: controllerFactoryMock.signInController, username: "", slt: "flowToken", correlationId: correlationId)

        await sut.dispatchSignUpCompleted(newState: expectedState)

        await fulfillment(of: [telemetryExp, delegateExp])
        checkError(delegate.error)

        func checkError(_ error: VerifyCodeError?) {
            XCTAssertEqual(error?.type, expectedError.type)
            XCTAssertEqual(error?.errorDescription, expectedError.errorDescription)
        }
    }
}
