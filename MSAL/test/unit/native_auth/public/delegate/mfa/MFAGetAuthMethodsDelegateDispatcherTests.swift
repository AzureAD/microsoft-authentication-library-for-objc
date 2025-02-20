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

final class MFAGetAuthMethodsDelegateDispatcherTests: XCTestCase {
    private var telemetryExp: XCTestExpectation!
    private var delegateExp: XCTestExpectation!
    private var sut: MFAGetAuthMethodsDelegateDispatcher!
    private let controllerFactoryMock = MSALNativeAuthControllerFactoryMock()
    private let correlationId = UUID()

    override func setUp() {
        super.setUp()
        telemetryExp = expectation(description: "delegateDispatcher telemetry exp")
        delegateExp = expectation(description: "delegateDispatcher delegate exp")
    }

    func test_dispatchSelection_whenDelegateMethodIsImplemented() async {
        let delegate = MFAGetAuthMethodsDelegateSpy(expectation: delegateExp, expectedError: nil)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case .success = result else {
                return XCTFail("wrong result")
            }
            self.telemetryExp.fulfill()
        })

        let expectedState = MFARequiredState(controller: controllerFactoryMock.signInController, scopes: [], claimsRequestJson: nil, continuationToken: "continuationToken", correlationId: correlationId)
        let expectedAuthMethods = [MSALAuthMethod(id: "1", challengeType: "oob", loginHint: "us**@**oso.com", channelTargetType: MSALNativeAuthChannelType(value: "email"))]

        await sut.dispatchSelectionRequired(authMethods: expectedAuthMethods, newState: expectedState, correlationId: correlationId)

        await fulfillment(of: [telemetryExp, delegateExp], timeout: 1)

        XCTAssertEqual(delegate.newMFARequiredState, expectedState)
        XCTAssertEqual(delegate.newAuthMethods, expectedAuthMethods)
    }

    func test_dispatchSelection_whenDelegateOptionalMethodNotImplemented() async {
        let expectedError = MFAGetAuthMethodsError(
            type: .generalError,
            message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onMFAGetAuthMethodsSelectionRequired"),
            correlationId: correlationId
        )
        let delegate = MFAGetAuthMethodsNotImplementedDelegateSpy(expectation: delegateExp, expectedError: expectedError)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case let .failure(error) = result, let customError = error as? MFAGetAuthMethodsError else {
                return XCTFail("wrong result")
            }

            checkError(customError)
            self.telemetryExp.fulfill()
        })

        let expectedState = MFARequiredState(controller: controllerFactoryMock.signInController, scopes: [], claimsRequestJson: nil, continuationToken: "continuationToken", correlationId: correlationId)

        await sut.dispatchSelectionRequired(authMethods: [], newState: expectedState, correlationId: correlationId)

        await fulfillment(of: [telemetryExp, delegateExp], timeout: 1)
        checkError(delegate.expectedError)

        func checkError(_ error: MFAGetAuthMethodsError?) {
            XCTAssertEqual(error?.type, expectedError.type)
            XCTAssertEqual(error?.errorDescription, expectedError.errorDescription)
            XCTAssertEqual(error?.correlationId, expectedError.correlationId)
        }
    }
}
