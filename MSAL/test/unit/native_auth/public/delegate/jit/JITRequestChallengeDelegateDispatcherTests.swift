
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

final class JITRequestChallengeDelegateDispatcherTests: XCTestCase {
    private var telemetryExp: XCTestExpectation!
    private var delegateExp: XCTestExpectation!
    private var sut: JITRequestChallengeDelegateDispatcher!
    private let correlationId = UUID()

    override func setUp() {
        super.setUp()
        telemetryExp = expectation(description: "delegateDispatcher telemetry exp")
        delegateExp = expectation(description: "delegateDispatcher delegate exp")
    }

    func test_dispatchVerificationRequired_whenDelegateMethodIsImplemented() async {
        let expectedState = RegisterStrongAuthVerificationRequiredState(
            controller: MSALNativeAuthJITControllerMock(),
            continuationToken: "continuationToken",
            correlationId: correlationId
        )
        let expectedSentTo = "user@contoso.com"
        let expectedChannelTargetType = MSALNativeAuthChannelType(value: "email")
        let expectedCodeLength = 6

        let delegate = JITRequestChallengeDelegateSpy(expectation: delegateExp, expectedResult: nil, expectedError: nil)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case .success = result else {
                return XCTFail("Unexpected telemetry result")
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

        XCTAssertEqual(delegate.verificationResult?.newState as? RegisterStrongAuthVerificationRequiredState, expectedState)
        XCTAssertEqual(delegate.sentTo, expectedSentTo)
        XCTAssertEqual(delegate.channelTargetType, expectedChannelTargetType)
        XCTAssertEqual(delegate.codeLength, expectedCodeLength)
    }

    func test_dispatchVerificationRequired_whenDelegateOptionalMethodNotImplemented() async {
        let expectedError = RegisterStrongAuthChallengeError(
            type: .generalError,
            message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onRegisterStrongAuthVerificationRequired"),
            correlationId: correlationId
        )
        let delegate = JITRequestChallengeNotImplementedDelegateSpy(expectation: delegateExp, expectedError: expectedError)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case let .failure(error) = result, let customError = error as? RegisterStrongAuthChallengeError else {
                return XCTFail("Unexpected telemetry result")
            }
            checkError(customError)
            self.telemetryExp.fulfill()
        })

        await sut.dispatchVerificationRequired(
            newState: RegisterStrongAuthVerificationRequiredState(
                controller: MSALNativeAuthJITControllerMock(),
                continuationToken: "continuationToken",
                correlationId: correlationId
            ),
            sentTo: "user@contoso.com",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 6,
            correlationId: correlationId
        )

        await fulfillment(of: [telemetryExp, delegateExp], timeout: 1)

        checkError(delegate.expectedError)
        func checkError(_ error: RegisterStrongAuthChallengeError?) {
            XCTAssertEqual(error?.type, expectedError.type)
            XCTAssertEqual(error?.errorDescription, expectedError.errorDescription)
            XCTAssertEqual(error?.correlationId, expectedError.correlationId)
        }
    }

    func test_dispatchSignInCompleted_whenDelegateMethodIsImplemented() async {
        let expectedResult = MSALNativeAuthUserAccountResultStub.result
        let delegate = JITRequestChallengeDelegateSpy(expectation: delegateExp, expectedResult: expectedResult, expectedError: nil)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case .success = result else {
                return XCTFail("Unexpected telemetry result")
            }
            self.telemetryExp.fulfill()
        })

        await sut.dispatchSignInCompleted(result: expectedResult, correlationId: correlationId)

        await fulfillment(of: [telemetryExp, delegateExp], timeout: 1)

        XCTAssertEqual(delegate.expectedResult, expectedResult)
    }

    func test_dispatchSignInCompleted_whenDelegateOptionalMethodNotImplemented() async {
        let expectedError = RegisterStrongAuthChallengeError(
            type: .generalError,
            message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignInCompleted"),
            correlationId: correlationId
        )
        let delegate = JITRequestChallengeNotImplementedDelegateSpy(expectation: delegateExp, expectedError: expectedError)

        sut = .init(delegate: delegate, telemetryUpdate: { result in
            guard case let .failure(error) = result, let customError = error as? RegisterStrongAuthChallengeError else {
                return XCTFail("Unexpected telemetry result")
            }
            checkError(customError)
            self.telemetryExp.fulfill()
        })

        await sut.dispatchSignInCompleted(result: MSALNativeAuthUserAccountResultStub.result, correlationId: correlationId)

        await fulfillment(of: [telemetryExp, delegateExp], timeout: 1)
        checkError(delegate.expectedError)

        func checkError(_ error: RegisterStrongAuthChallengeError?) {
            XCTAssertEqual(error?.type, expectedError.type)
            XCTAssertEqual(error?.errorDescription, expectedError.errorDescription)
            XCTAssertEqual(error?.correlationId, expectedError.correlationId)
        }
    }
}
