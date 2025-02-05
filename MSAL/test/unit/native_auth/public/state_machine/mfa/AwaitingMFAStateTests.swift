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

final class AwaitingMFAStateTests: XCTestCase {

    private var sut: AwaitingMFAState!
    private var controller: MSALNativeAuthSignInControllerMock!
    private var correlationId: UUID = UUID()
    private let claimsRequestJson = "claims"

    override func setUp() {
        super.setUp()

        controller = .init()
        sut = .init(controller: controller, scopes: [], claimsRequestJson: claimsRequestJson, continuationToken: "continuationToken", correlationId: correlationId)
    }

    // MARK: - Delegates

    // Request challenge

    func test_requestChallenge_delegate_withError_shouldReturnCorrectError() {
        let exp = expectation(description: "mfa state")

        let expectedError = MFARequestChallengeError(type: .generalError, message: "test error", correlationId: correlationId)
        let expectedState = MFARequiredState(controller: controller, scopes: [], claimsRequestJson: claimsRequestJson, continuationToken: "continuationToken", correlationId: correlationId)

        let expectedResult: MFARequestChallengeResult = .error(
            error: expectedError,
            newState: expectedState
        )
        controller.requestChallengeResponse = .init(expectedResult, correlationId: correlationId)

        let delegate = MFARequestChallengeDelegateSpy(expectation: exp, expectedError: expectedError)

        sut.requestChallenge(delegate: delegate)
        wait(for: [exp], timeout: 1)

        XCTAssertNil(delegate.newMFARequiredState)
    }

    func test_requestChallenge_delegateVerificationRequired_shouldReturnCorrectResult() {
        let exp = expectation(description: "mfa states")
        let exp2 = expectation(description: "expectation Telemetry")
        let expectedState = MFARequiredState(controller: controller, scopes: [], claimsRequestJson: claimsRequestJson, continuationToken: "continuationToken 2", correlationId: correlationId)
        let expectedCodeLength = 1
        let expectedChannel = MSALNativeAuthChannelType(value: "email")
        let expectedSentTo = "sentTo"

        let expectedResult: MFARequestChallengeResult = .verificationRequired(
            sentTo: expectedSentTo,
            channelTargetType: expectedChannel,
            codeLength: expectedCodeLength,
            newState: expectedState
        )
        controller.requestChallengeResponse = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = MFARequestChallengeDelegateSpy(expectation: exp)
        
        sut.requestChallenge(delegate: delegate)
        wait(for: [exp, exp2], timeout: 1.0)
        
        XCTAssertEqual(delegate.newSentTo, expectedSentTo)
        XCTAssertEqual(delegate.newChannelTargetType, expectedChannel)
        XCTAssertEqual(delegate.newCodeLength, expectedCodeLength)
        XCTAssertEqual(delegate.newMFARequiredState, expectedState)
    }
    
    func test_requestChallenge_delegateSelectionRequired_shouldReturnCorrectResult() {
        let exp = expectation(description: "mfa states")
        let exp2 = expectation(description: "expectation Telemetry")
        let expectedState = MFARequiredState(controller: controller, scopes: [], claimsRequestJson: claimsRequestJson, continuationToken: "continuationToken 2", correlationId: correlationId)
        let expectedAuthMethods = [MSALAuthMethod(id: "1", challengeType: "oob", loginHint: "hint", channelTargetType: MSALNativeAuthChannelType(value: "email"))]

        let expectedResult: MFARequestChallengeResult = .selectionRequired(authMethods: expectedAuthMethods, newState: expectedState)
        controller.requestChallengeResponse = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = MFARequestChallengeDelegateSpy(expectation: exp)
        
        sut.requestChallenge(delegate: delegate)
        wait(for: [exp, exp2], timeout: 1.0)
        
        XCTAssertEqual(delegate.newAuthMethods, expectedAuthMethods)
        XCTAssertEqual(delegate.newMFARequiredState, expectedState)
    }
}
