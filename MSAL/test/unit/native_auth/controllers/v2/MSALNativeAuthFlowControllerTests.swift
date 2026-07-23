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
@_implementationOnly import MSAL_Private

// swiftlint:disable type_body_length file_length
final class MSALNativeAuthFlowControllerTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthFlowController!
    private var requestProviderMock: MSALNativeAuthV2RequestProviderMock!
    private var validatorMock: MSALNativeAuthV2ResponseValidatorMock!
    private var cacheAccessorMock: MSALNativeAuthCacheAccessorMock!
    private var resultFactoryMock: MSALNativeAuthResultFactoryMock!

    override func setUpWithError() throws {
        try super.setUpWithError()

        requestProviderMock = .init()
        validatorMock = .init()
        cacheAccessorMock = .init()
        resultFactoryMock = .init()

        sut = .init(
            config: MSALNativeAuthConfigStubs.configuration,
            requestProvider: requestProviderMock,
            responseValidator: validatorMock,
            cacheAccessor: cacheAccessorMock,
            resultFactory: resultFactoryMock
        )
    }

    // MARK: - Helpers

    private func makeState(links: [String: URL], continuationToken: String = "ct") -> MSALNativeAuthFlowInternalState {
        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: .passwordReset,
            continuationToken: continuationToken,
            links: relationLinks(links),
            username: "user@contoso.com",
            sentToHint: "u***@contoso.com",
            codeLength: 8
        )
        return MSALNativeAuthFlowInternalState(continuation: continuation, controller: sut)
    }

    private func relationLinks(_ links: [String: URL]) -> [MSALNativeAuthV2LinkKey: URL] {
        var typed: [MSALNativeAuthV2LinkKey: URL] = [:]
        for (rawRelation, url) in links {
            if let relation = MSALNativeAuthV2LinkRelation(rawValue: rawRelation) {
                typed[.relation(relation)] = url
            }
        }
        return typed
    }

    private func resetPasswordParameters() -> MSALNativeAuthResetPasswordParametersV2 {
        let params = MSALNativeAuthResetPasswordParametersV2(username: "user@contoso.com")
        return params
    }

    // MARK: - resetPassword (happy path -> code required)

    func test_resetPassword_happyPath_returnsCodeRequired() async {
        requestProviderMock.mockRequest()
        validatorMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/reset")
        ]
        validatorMock.interactionResponses = [
            .challengeRequired(continuationToken: "ct-2", challengeHref: "https://contoso.com/challenge", hint: "u***@contoso.com"),
            .codeRequired(continuationToken: "ct-3", verifyHref: "https://contoso.com/verify", resendHref: "https://contoso.com/resend", sentTo: "u***@contoso.com", channelType: MSALNativeAuthChannelType(value: "email"), codeLength: 8)
        ]

        let response = await sut.resetPassword(parameters: resetPasswordParameters())

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        guard state is MSALNativeAuthCodeRequiredState else {
            return XCTFail("Expected codeRequired state, got \(state)")
        }
        XCTAssertTrue(requestProviderMock.authorizeChallengeStartCalled)
        XCTAssertTrue(requestProviderMock.resetPasswordStartCalled)
        XCTAssertTrue(requestProviderMock.challengeCalled)
    }

    func test_resetPassword_whenAuthorizationChallengeFails_returnsError() async {
        requestProviderMock.mockRequest()
        validatorMock.authorizeChallengeResponses = [.error(MSALNativeAuthFlowError(type: .generalError))]

        let response = await sut.resetPassword(parameters: resetPasswordParameters())

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertFalse(requestProviderMock.resetPasswordStartCalled)
    }

    func test_resetPassword_whenUserNotFound_returnsError() async {
        requestProviderMock.mockRequest()
        validatorMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/reset")
        ]
        validatorMock.interactionResponses = [
            .error(MSALNativeAuthFlowError(type: .userNotFound))
        ]

        let response = await sut.resetPassword(parameters: resetPasswordParameters())

        guard case .error(let error, _) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isUserNotFound)
    }

    // MARK: - submitCode

    func test_submitCode_whenUpdateRequired_returnsNewPasswordRequired() async {
        requestProviderMock.mockRequest()
        validatorMock.interactionResponses = [
            .updateRequired(continuationToken: "ct-update", updateHref: "https://contoso.com/update")
        ]
        let state = makeState(links: ["verify": URL(string: "https://contoso.com/verify")!])

        let response = await sut.submitCode("12345678", state: state)

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        guard state is MSALNativeAuthNewPasswordRequiredState else {
            return XCTFail("Expected newPasswordRequired state, got \(state)")
        }
        XCTAssertTrue(requestProviderMock.verifyCalled)
        XCTAssertEqual(requestProviderMock.verifyHrefReceived, "https://contoso.com/verify")
    }

    func test_submitCode_whenInvalidCode_returnsErrorWithRetryState() async {
        requestProviderMock.mockRequest()
        validatorMock.interactionResponses = [
            .error(MSALNativeAuthFlowError(type: .invalidCode))
        ]
        let state = makeState(links: ["verify": URL(string: "https://contoso.com/verify")!])

        let response = await sut.submitCode("00000000", state: state)

        guard case .error(let error, let newState) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isInvalidCode)
        XCTAssertNotNil(newState)
    }

    func test_submitCode_whenVerifyLinkMissing_returnsError() async {
        requestProviderMock.mockRequest()
        let state = makeState(links: [:])

        let response = await sut.submitCode("12345678", state: state)

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertFalse(requestProviderMock.verifyCalled)
    }

    // MARK: - submitNewPassword (poll -> token -> completed)

    func test_submitNewPassword_happyPath_returnsCompleted() async {
        requestProviderMock.mockRequest()
        validatorMock.interactionResponses = [
            .pollInProgress(continuationToken: "ct-poll", pollHref: "https://contoso.com/poll"),
            .readyToComplete(continuationToken: "ct-continue")
        ]
        validatorMock.authorizeChallengeResponses = [
            .authorizationCode(code: "auth-code")
        ]
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()
        let state = makeState(links: ["update": URL(string: "https://contoso.com/update")!])

        let response = await sut.submitNewPassword("New-Password-1", state: state)

        guard case .completed = response.result else {
            return XCTFail("Expected completed, got \(response.result)")
        }
        XCTAssertTrue(requestProviderMock.updatePasswordCalled)
        XCTAssertTrue(requestProviderMock.pollCalled)
        XCTAssertTrue(requestProviderMock.tokenCalled)
    }

    func test_submitNewPassword_whenUpdateLinkMissing_returnsError() async {
        requestProviderMock.mockRequest()
        let state = makeState(links: [:])

        let response = await sut.submitNewPassword("New-Password-1", state: state)

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertFalse(requestProviderMock.updatePasswordCalled)
    }

    // MARK: - resendCode

    func test_resendCode_whenCodeRequired_returnsCodeRequired() async {
        requestProviderMock.mockRequest()
        validatorMock.interactionResponses = [
            .codeRequired(continuationToken: "ct-3", verifyHref: "https://contoso.com/verify", resendHref: "https://contoso.com/resend", sentTo: "u***@contoso.com", channelType: MSALNativeAuthChannelType(value: "email"), codeLength: 8)
        ]
        let state = makeState(links: ["resend": URL(string: "https://contoso.com/resend")!])

        let response = await sut.resendCode(state: state)

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        guard state is MSALNativeAuthCodeRequiredState else {
            return XCTFail("Expected codeRequired state, got \(state)")
        }
        XCTAssertTrue(requestProviderMock.challengeCalled)
    }
}
