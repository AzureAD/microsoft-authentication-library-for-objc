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
    private var parserMock: MSALNativeAuthV2ResponseParserMock!
    private var cacheAccessorMock: MSALNativeAuthCacheAccessorMock!
    private var resultFactoryMock: MSALNativeAuthResultFactoryMock!
    private let context = MSALNativeAuthRequestContext(correlationId: UUID())

    override func setUpWithError() throws {
        try super.setUpWithError()

        requestProviderMock = .init()
        parserMock = .init()
        cacheAccessorMock = .init()
        resultFactoryMock = .init()

        sut = .init(
            config: MSALNativeAuthConfigStubs.configuration,
            requestProvider: requestProviderMock,
            responseParser: parserMock,
            cacheAccessor: cacheAccessorMock,
            resultFactory: resultFactoryMock
        )
    }

    // MARK: - Helpers

    private func makeState(
        links: [MSALNativeAuthV2LinkRelation: URL] = [:],
        continuationToken: String = "ct",
        correlationId: UUID = UUID()
    ) -> MSALNativeAuthFlowInternalState {
        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: .passwordReset,
            correlationId: correlationId,
            continuationToken: continuationToken,
            links: relationLinks(links)
        )
        return MSALNativeAuthFlowInternalState(continuation: continuation, controller: sut)
    }

    private func relationLinks(_ links: [MSALNativeAuthV2LinkRelation: URL]) -> [MSALNativeAuthV2LinkKey: URL] {
        links.reduce(into: [:]) { result, entry in
            result[.relation(entry.key)] = entry.value
        }
    }

    private func resetPasswordParameters() -> MSALNativeAuthResetPasswordParameters {
        let params = MSALNativeAuthResetPasswordParameters(username: "user@contoso.com")
        return params
    }

    // MARK: - resetPassword (happy path -> code required)

    func test_resetPassword_happyPath_returnsCodeRequired() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/reset")
        ]
        parserMock.interactionResponses = [
            .challengeRequired(
                continuationToken: "ct-2",
                methods: [MSALNativeAuthV2ChallengeMethod(id: "1", channelType: .email, hint: "u***@contoso.com", challengeHref: "https://contoso.com/challenge")]
            ),
            .verificationRequired(
                continuationToken: "ct-3",
                verifyHref: "https://contoso.com/verify",
                resendHref: "https://contoso.com/resend",
                sentTo: "u***@contoso.com",
                channelType: MSALNativeAuthChannelType(value: "email"),
                codeLength: 8
            )
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
        parserMock.authorizeChallengeResponses = [.error(MSALNativeAuthFlowError(type: .generalError))]

        let response = await sut.resetPassword(parameters: resetPasswordParameters())

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertFalse(requestProviderMock.resetPasswordStartCalled)
    }

    func test_resetPassword_whenUserNotFound_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/reset")
        ]
        parserMock.interactionResponses = [
            .error(MSALNativeAuthFlowError(type: .userNotFound))
        ]

        let response = await sut.resetPassword(parameters: resetPasswordParameters())

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isUserNotFound)
    }

    func test_resetPassword_whenChallengeMethodIsPassword_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/reset")
        ]
        parserMock.interactionResponses = [
            .challengeRequired(
                continuationToken: "ct-2",
                methods: [MSALNativeAuthV2ChallengeMethod(id: "1", channelType: .password, hint: nil, challengeHref: "https://contoso.com/password/challenge")]
            )
        ]

        let response = await sut.resetPassword(parameters: resetPasswordParameters())

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isGeneralError)
    }

    func test_resetPassword_whenMultipleMethodsIncludeEmail_selectsEmailMethod() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/reset")
        ]
        parserMock.interactionResponses = [
            .challengeRequired(
                continuationToken: "ct-2",
                methods: [
                    MSALNativeAuthV2ChallengeMethod(id: "1", channelType: .password, hint: nil, challengeHref: "https://contoso.com/password/challenge"),
                    MSALNativeAuthV2ChallengeMethod(id: "2", channelType: .email, hint: "u***@contoso.com", challengeHref: "https://contoso.com/email/challenge")
                ]
            ),
            .verificationRequired(
                continuationToken: "ct-3",
                verifyHref: "https://contoso.com/verify",
                resendHref: "https://contoso.com/resend",
                sentTo: "u***@contoso.com",
                channelType: MSALNativeAuthChannelType(value: "email"),
                codeLength: 8
            )
        ]

        let response = await sut.resetPassword(parameters: resetPasswordParameters())

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        guard state is MSALNativeAuthCodeRequiredState else {
            return XCTFail("Expected codeRequired state, got \(state)")
        }
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertEqual(requestProviderMock.challengeHrefReceived, "https://contoso.com/email/challenge")
    }

    // MARK: - submitCode

    func test_submitCode_whenUpdateRequired_returnsNewPasswordRequired() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .updateRequired(continuationToken: "ct-update", updateHref: "https://contoso.com/update")
        ]
        let state = makeState(links: [.verify: URL(string: "https://contoso.com/verify")!])

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

    func test_submitCode_whenInvalidCode_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .error(MSALNativeAuthFlowError(type: .invalidCode))
        ]
        let state = makeState(links: [.verify: URL(string: "https://contoso.com/verify")!])

        let response = await sut.submitCode("00000000", state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isInvalidCode)
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

    // MARK: - submitNewPassword (poll -> signInAfterResetPassword)

    func test_submitNewPassword_happyPath_returnsSignInAfterResetPassword() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .pollInProgress(continuationToken: "ct-poll", pollHref: "https://contoso.com/poll"),
            .readyToComplete(continuationToken: "ct-continue")
        ]
        let state = makeState(links: [.update: URL(string: "https://contoso.com/update")!])

        let response = await sut.submitNewPassword("New-Password-1", state: state)

        guard case .actionRequired(let newState) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        guard let signInState = newState as? MSALNativeAuthSignInAfterResetPasswordState else {
            return XCTFail("Expected signInAfterResetPassword state, got \(newState)")
        }
        XCTAssertEqual(signInState.internalState.continuation.continuationToken, "ct-continue")
        XCTAssertTrue(requestProviderMock.updatePasswordCalled)
        XCTAssertTrue(requestProviderMock.pollCalled)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_submitNewPassword_whenPollRelocates_followsUpdatedHrefAndToken() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .pollInProgress(continuationToken: "ct-poll-1", pollHref: "https://contoso.com/poll-1"),
            .pollInProgress(continuationToken: "ct-poll-2", pollHref: "https://contoso.com/poll-2"),
            .readyToComplete(continuationToken: "ct-continue")
        ]
        let state = makeState(links: [.update: URL(string: "https://contoso.com/update")!])

        let response = await sut.submitNewPassword("New-Password-1", state: state)

        guard case .actionRequired = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        XCTAssertEqual(requestProviderMock.pollHrefsReceived, ["https://contoso.com/poll-1", "https://contoso.com/poll-2"])
        XCTAssertEqual(requestProviderMock.pollTokensReceived, ["ct-poll-1", "ct-poll-2"])
    }

    func test_signInAfterResetPassword_happyPath_exchangesTokenAndCompletes() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .authorizationCode(code: "auth-code")
        ]
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()
        let correlationId = UUID()
        let state = makeState(correlationId: correlationId)

        let response = await sut.signInAfterResetPassword(
            scopes: ["scope1"],
            claimsRequestJson: "{\"access_token\":{}}",
            state: state
        )

        guard case .completed = response.result else {
            return XCTFail("Expected completed, got \(response.result)")
        }
        XCTAssertEqual(requestProviderMock.authorizeChallengeContinueToken, "ct")
        XCTAssertEqual(requestProviderMock.tokenCode, "auth-code")
        XCTAssertTrue(requestProviderMock.tokenScopes?.contains("scope1") ?? false)
        XCTAssertEqual(requestProviderMock.tokenClaimsRequestJson, "{\"access_token\":{}}")
        XCTAssertTrue(requestProviderMock.tokenCalled)
        XCTAssertEqual(response.correlationId, correlationId)
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

    func test_submitNewPassword_whenUpdateRejectsWeakPassword_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .error(MSALNativeAuthFlowError(type: .invalidPassword))
        ]
        let state = makeState(links: [.update: URL(string: "https://contoso.com/update")!])

        let response = await sut.submitNewPassword("weak", state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertEqual(error.type, .invalidPassword)
        XCTAssertTrue(requestProviderMock.updatePasswordCalled)
        XCTAssertFalse(requestProviderMock.pollCalled)
    }

    func test_submitNewPassword_whenPollReturnsError_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .pollInProgress(continuationToken: "ct-poll", pollHref: "https://contoso.com/poll"),
            .error(MSALNativeAuthFlowError(type: .invalidPassword))
        ]
        let state = makeState(links: [.update: URL(string: "https://contoso.com/update")!])

        let response = await sut.submitNewPassword("New-Password-1", state: state)

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(requestProviderMock.pollCalled)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_submitNewPassword_whenUpdateReturnsGeneralError_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .error(MSALNativeAuthFlowError(type: .generalError))
        ]
        let state = makeState(links: [.update: URL(string: "https://contoso.com/update")!])

        let response = await sut.submitNewPassword("New-Password-1", state: state)

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
    }

    // MARK: - resendCode

    func test_resendCode_whenCodeRequired_returnsCodeRequired() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .verificationRequired(
                continuationToken: "ct-3",
                verifyHref: "https://contoso.com/verify",
                resendHref: "https://contoso.com/resend",
                sentTo: "u***@contoso.com",
                channelType: MSALNativeAuthChannelType(value: "email"),
                codeLength: 8
            )
        ]
        let state = makeState(links: [.resend: URL(string: "https://contoso.com/resend")!])

        let response = await sut.resendCode(state: state)

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        guard state is MSALNativeAuthCodeRequiredState else {
            return XCTFail("Expected codeRequired state, got \(state)")
        }
        XCTAssertTrue(requestProviderMock.challengeCalled)
    }

    // MARK: - result handlers (branch logic)

    func test_handleChallenge_codeRequired_usesServerSentTo() async {
        let state = await mapCodeRequired(sentTo: "u***@contoso.com")
        XCTAssertEqual(state?.sentTo, "u***@contoso.com")
    }

    func test_handleChallenge_browserRequired_returnsBrowserRequiredResult() async {
        let response = await sut.handlePasswordResetChallengeResult(.browserRequired, flowContinuationState: makeFlow(), step: makeStep())
        guard case .browserRequired = response.result else {
            return XCTFail("Expected browserRequired, got \(response.result)")
        }
    }

    private func mapCodeRequired(sentTo: String) async -> MSALNativeAuthCodeRequiredState? {
        let response = await sut.handlePasswordResetChallengeResult(
            .verificationRequired(
                continuationToken: "ct",
                verifyHref: "https://contoso.com/verify",
                resendHref: "https://contoso.com/resend",
                sentTo: sentTo,
                channelType: MSALNativeAuthChannelType(value: "email"),
                codeLength: 8
            ),
            flowContinuationState: makeFlow(),
            step: makeStep()
        )
        guard case .actionRequired(let state) = response.result else {
            return nil
        }
        return state as? MSALNativeAuthCodeRequiredState
    }

    private func makeFlow() -> MSALNativeAuthFlowContinuationState {
        return MSALNativeAuthFlowContinuationState(
            flowScenario: .passwordReset,
            correlationId: UUID(),
            continuationToken: "ct",
            links: [:]
        )
    }

    private func makeStep() -> MSALNativeAuthFlowStepContext {
        return MSALNativeAuthFlowStepContext(
            apiId: .telemetryApiIdResetPassword,
            event: nil,
            context: context
        )
    }

}
