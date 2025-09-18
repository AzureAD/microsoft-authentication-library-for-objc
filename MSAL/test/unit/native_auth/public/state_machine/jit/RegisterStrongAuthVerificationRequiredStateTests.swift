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

final class RegisterStrongAuthVerificationRequiredStateTests: XCTestCase {

    private var sut: RegisterStrongAuthVerificationRequiredState!
    private var controller: MSALNativeAuthJITControllerMock!
    private var correlationId: UUID!
    private let continuationToken = "testContinuationToken"

    override func setUp() {
        super.setUp()
        controller = .init()
        correlationId = UUID()
        sut = .init(controller: controller, continuationToken: continuationToken, correlationId: correlationId)
    }

    func test_submitChallenge_withInvalidChallenge_shouldReturnError() {
        let exp = expectation(description: "submit challenge error")

        let expectedError = RegisterStrongAuthSubmitChallengeError(type: .invalidChallenge, correlationId: correlationId)
        controller.submitJITChallengeResponse = .init(
            .error(error: expectedError, newState: sut),
            correlationId: correlationId
        )

        let delegate = JITSubmitChallengeDelegateSpy(expectation: exp, expectedResult: nil, expectedError: expectedError)

        sut.submitChallenge(challenge: "invalidChallenge", delegate: delegate)
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(delegate.newState, sut)
    }
    
    func test_submitChallenge_withValidChallenge_shouldReturnCompletedResult() {
        let exp = expectation(description: "submit challenge completed")
        let exp2 = expectation(description: "telemetry update")

        let expectedAccount = MSALNativeAuthUserAccountResultStub.result
        controller.submitJITChallengeResponse = .init(
            .completed(expectedAccount),
            correlationId: correlationId,
            telemetryUpdate: { _ in exp2.fulfill() }
        )

        let delegate = JITSubmitChallengeDelegateSpy(expectation: exp, expectedResult: expectedAccount, expectedError: nil)

        sut.submitChallenge(challenge: "challenge", delegate: delegate)
        wait(for: [exp, exp2], timeout: 1.0)

        XCTAssertNil(delegate.newState)
    }



    func test_challengeAuthMethod_verificationRequired_shouldReturnCorrectResult() {
        let exp = expectation(description: "verification required")
        let exp2 = expectation(description: "telemetry update")

        let expectedState = RegisterStrongAuthVerificationRequiredState(
            controller: controller,
            continuationToken: continuationToken,
            correlationId: correlationId
        )
        let expectedSentTo = "email@contoso.com"
        let expectedChannel = MSALNativeAuthChannelType(value: "email")
        let expectedCodeLength = 8

        let expectedResult: JITRequestChallengeResult = .verificationRequired(
            sentTo: expectedSentTo,
            channelTargetType: expectedChannel,
            codeLength: expectedCodeLength,
            newState: expectedState
        )
        controller.requestJITChallengeResponse = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = JITRequestChallengeDelegateSpy(expectation: exp, expectedResult: nil, expectedError: nil)
        let parameters = makeParameters(channelType: expectedChannel, verificationContact: expectedSentTo)

        sut.challengeAuthMethod(parameters: parameters, delegate: delegate)
        wait(for: [exp, exp2], timeout: 1.0)

        XCTAssertEqual(delegate.sentTo, expectedSentTo)
        XCTAssertEqual(delegate.channelTargetType, expectedChannel)
        XCTAssertEqual(delegate.codeLength, expectedCodeLength)
        XCTAssertEqual(delegate.verificationResult?.newState as? RegisterStrongAuthVerificationRequiredState, expectedState)
    }

    private func makeParameters(channelType: MSALNativeAuthChannelType,
                                verificationContact: String) -> MSALNativeAuthChallengeAuthMethodParameters {
        let parameters = MSALNativeAuthChallengeAuthMethodParameters(
            authMethod: MSALAuthMethod(id: "1",
                                       challengeType: "oob",
                                       loginHint: "email@contoso.com",
                                       channelTargetType: channelType),
            verificationContact: verificationContact)
        return parameters
    }
}
