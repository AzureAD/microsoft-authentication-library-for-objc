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

final class MFASendChallengeDelegateDispatcherTests: XCTestCase {
    private var telemetryExp: XCTestExpectation!
    private var delegateExp: XCTestExpectation!
    private var sut: MFASendChallengeDelegateDispatcher!
    private let controllerFactoryMock = MSALNativeAuthControllerFactoryMock()
    private let correlationId = UUID()

    override func setUp() {
        super.setUp()
        telemetryExp = expectation(description: "delegateDispatcher telemetry exp")
        delegateExp = expectation(description: "delegateDispatcher delegate exp")
    }

    func test_dispatchVerificationRequired_whenDelegateMethodIsImplemented() async {
        let expectedState = MFARequiredState(controller: controllerFactoryMock.signInController, scopes: [], continuationToken: "continuationToken", correlationId: correlationId)
        let expectedSentTo = "user@contoso.com"
        let expectedChannelTargetType = MSALNativeAuthChannelType(value: "email")
        let expectedCodeLength = 4

        let delegate = MFASendChallengeDelegateSpy(expectation: delegateExp, expectedError: nil)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case .success = result else {
                return XCTFail("wrong result")
            }
            self.telemetryExp.fulfill()
        })

        await sut.dispatchVerificationRequired(
            newState: expectedState,
            sentTo: expectedSentTo,
            channelTargetType: expectedChannelTargetType,
            codeLength: expectedCodeLength,
            correlationId: correlationId
        )

        await fulfillment(of: [telemetryExp, delegateExp], timeout: 1)

        XCTAssertEqual(delegate.newMFARequiredState, expectedState)
        XCTAssertEqual(delegate.newSentTo, expectedSentTo)
        XCTAssertEqual(delegate.newChannelTargetType, expectedChannelTargetType)
        XCTAssertEqual(delegate.newCodeLength, expectedCodeLength)
    }

    func test_dispatchVerificationRequired_whenDelegateOptionalMethodNotImplemented() async {
        let expectedError = MFAError(
            type: .generalError,
            message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onMFASendChallengeVerificationRequired"),
            correlationId: correlationId
        )
        let delegate = MFASendChallengeNotImplementedDelegateSpy(expectation: delegateExp, expectedError: expectedError)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case let .failure(error) = result, let customError = error as? MFAError else {
                return XCTFail("wrong result")
            }

            checkError(customError)
            self.telemetryExp.fulfill()
        })

        await sut.dispatchVerificationRequired(
            newState: MFARequiredState(controller: controllerFactoryMock.signInController, scopes: [], continuationToken: "continuationToken", correlationId: correlationId),
            sentTo: "user@contoso.com",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 4,
            correlationId: correlationId
        )

        await fulfillment(of: [telemetryExp, delegateExp], timeout: 1)
        checkError(delegate.expectedError)

        func checkError(_ error: MFAError?) {
            XCTAssertEqual(error?.type, expectedError.type)
            XCTAssertEqual(error?.errorDescription, expectedError.errorDescription)
            XCTAssertEqual(error?.correlationId, expectedError.correlationId)
        }
    }

    func test_dispatchSelection_whenDelegateMethodIsImplemented() async {
        let delegate = MFASendChallengeDelegateSpy(expectation: delegateExp, expectedError: nil)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case .success = result else {
                return XCTFail("wrong result")
            }
            self.telemetryExp.fulfill()
        })

        let expectedState = MFARequiredState(controller: controllerFactoryMock.signInController, scopes: [], continuationToken: "continuationToken", correlationId: correlationId)
        let expectedAuthMethods = [MSALAuthMethod(id: "1", challengeType: "oob", loginHint: "us**@**oso.com", channelTargetType: MSALNativeAuthChannelType(value: "email"))]

        await sut.dispatchSelectionRequired(authMethods: expectedAuthMethods, newState: expectedState, correlationId: correlationId)

        await fulfillment(of: [telemetryExp, delegateExp], timeout: 1)

        XCTAssertEqual(delegate.newMFARequiredState, expectedState)
        XCTAssertEqual(delegate.newAuthMethods, expectedAuthMethods)
    }

    func test_dispatchSelection_whenDelegateOptionalMethodNotImplemented() async {
        let expectedError = MFAError(
            type: .generalError,
            message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onMFASendChallengeSelectionRequired"),
            correlationId: correlationId
        )
        let delegate = MFASendChallengeNotImplementedDelegateSpy(expectation: delegateExp, expectedError: expectedError)


        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case let .failure(error) = result, let customError = error as? MFAError else {
                return XCTFail("wrong result")
            }

            checkError(customError)
            self.telemetryExp.fulfill()
        })

        let expectedState = MFARequiredState(controller: controllerFactoryMock.signInController, scopes: [], continuationToken: "continuationToken", correlationId: correlationId)

        await sut.dispatchSelectionRequired(authMethods: [], newState: expectedState, correlationId: correlationId)

        await fulfillment(of: [telemetryExp, delegateExp], timeout: 1)
        checkError(delegate.expectedError)

        func checkError(_ error: MFAError?) {
            XCTAssertEqual(error?.type, expectedError.type)
            XCTAssertEqual(error?.errorDescription, expectedError.errorDescription)
            XCTAssertEqual(error?.correlationId, expectedError.correlationId)
        }
    }
}
