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

final class RegisterStrongAuthStateTests: XCTestCase {

    private var sut: RegisterStrongAuthState!
    private var controller: MSALNativeAuthJITControllerMock!
    private var correlationId: UUID!
    private let continuationToken = "continuationToken"

    override func setUp() {
        super.setUp()
        controller = .init()
        correlationId = UUID()
        sut = .init(controller: controller, continuationToken: continuationToken, correlationId: correlationId)
    }

    // challenge auth method

    func test_challengeAuthMethod_delegate_withError_shouldReturnCorrectError() {
        let exp = expectation(description: "error case")

        let expectedError = RegisterStrongAuthChallengeError(type: .generalError, message: "Invalid input", correlationId: correlationId)
        let expectedState = RegisterStrongAuthState(controller: controller, continuationToken: continuationToken, correlationId: correlationId)

        let expectedResult: JITRequestChallengeResult = .error(
            error: expectedError,
            newState: expectedState
        )
        controller.requestJITChallengeResponse = .init(expectedResult, correlationId: correlationId)

        let delegate = JITRequestChallengeDelegateSpy(expectation: exp, expectedResult: nil, expectedError: expectedError)
        let parameters = makeParameters(channelType: MSALNativeAuthChannelType(value: "email"), verificationContact: "")

        sut.challengeAuthMethod(parameters: parameters, delegate: delegate)
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(delegate.newState?.continuationToken, expectedState.continuationToken)
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

    func test_challengeAuthMethod_completed_shouldReturnCorrectResult() {
        let exp = expectation(description: "completed case")
        let exp2 = expectation(description: "expectation Telemetry")

        let expectedAccount = MSALNativeAuthUserAccountResultStub.result
        let expectedResult: JITRequestChallengeResult = .completed(expectedAccount)
        controller.requestJITChallengeResponse = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })
        
        let delegate = JITRequestChallengeDelegateSpy(expectation: exp, expectedResult: expectedAccount, expectedError: nil)
        let parameters = makeParameters(channelType: MSALNativeAuthChannelType(value: "email"), verificationContact: "email@contoso.com")

        sut.challengeAuthMethod(parameters: parameters, delegate: delegate)
        wait(for: [exp, exp2], timeout: 1.0)

        XCTAssertNil(delegate.verificationResult)
        XCTAssertNil(delegate.newState)
    }
    
    func test_challengeAuthMethod_failed_whenVerificationContactIsInvalid() {
        let exp = expectation(description: "verificationContactMissing")
        let state = RegisterStrongAuthState(
            controller: controller,
            continuationToken: continuationToken,
            correlationId: correlationId
        )
        let channelTargetType = MSALNativeAuthChannelType(value: "sms")
        let parameters = MSALNativeAuthChallengeAuthMethodParameters(
            authMethod: MSALAuthMethod(id: "1",
                                       challengeType: "oob",
                                       channelTargetType: channelTargetType,
                                       loginHint: "+35383********"),
            verificationContact: ""
        )
        XCTAssertTrue(channelTargetType.isSMSType)
        let expectedError = RegisterStrongAuthChallengeError(type: .invalidInput, correlationId: correlationId)
        let delegate = JITRequestChallengeDelegateSpy(expectation: exp, expectedResult: nil, expectedError: expectedError)
        state.challengeAuthMethod(parameters: parameters, delegate: delegate)
        wait(for: [exp], timeout: 1.0)
    }

    private func makeParameters(channelType: MSALNativeAuthChannelType,
                                verificationContact: String) -> MSALNativeAuthChallengeAuthMethodParameters {
        let parameters = MSALNativeAuthChallengeAuthMethodParameters(
            authMethod: MSALAuthMethod(id: "1",
                                       challengeType: "oob",
                                       channelTargetType: channelType,
                                       loginHint: "email@contoso.com"),
            verificationContact: verificationContact)
        return parameters
    }
}
