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
final class MSALNativeAuthFlowControllerSignInTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthFlowController!
    private var requestProviderMock: MSALNativeAuthV2RequestProviderMock!
    private var parserMock: MSALNativeAuthV2ResponseParserMock!
    private var cacheAccessorMock: MSALNativeAuthCacheAccessorMock!
    private var resultFactoryMock: MSALNativeAuthResultFactoryMock!

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

    private func signInParameters(scopes: [String]? = ["scope1"], password: String? = nil) -> MSALNativeAuthSignInParameters {
        let params = MSALNativeAuthSignInParameters(username: "user@contoso.com")
        params.scopes = scopes
        params.password = password
        return params
    }

    private func makeSignInState(
        links: [MSALNativeAuthV2LinkRelation: URL] = [:],
        continuationToken: String = "ct",
        scopes: [String] = ["scope1"],
        claimsRequestJson: String? = nil,
        correlationId: UUID = UUID()
    ) -> MSALNativeAuthFlowInternalState {
        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: .signIn,
            correlationId: correlationId,
            continuationToken: continuationToken,
            links: relationLinks(links),
            scopes: scopes,
            claimsRequestJson: claimsRequestJson
        )
        return MSALNativeAuthFlowInternalState(continuation: continuation, controller: sut)
    }

    private func relationLinks(_ links: [MSALNativeAuthV2LinkRelation: URL]) -> [MSALNativeAuthV2LinkKey: URL] {
        links.reduce(into: [:]) { result, entry in
            result[.relation(entry.key)] = entry.value
        }
    }

    private func makeMFAState(
        methodLinks: [String: URL],
        continuationToken: String = "ct-mfa",
        scopes: [String] = ["scope1"],
        correlationId: UUID = UUID()
    ) -> MSALNativeAuthFlowInternalState {
        var links: [MSALNativeAuthV2LinkKey: URL] = [:]
        for (id, url) in methodLinks {
            links[.method(id: id)] = url
        }
        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: .signIn,
            correlationId: correlationId,
            continuationToken: continuationToken,
            links: links,
            scopes: scopes,
            claimsRequestJson: nil
        )
        return MSALNativeAuthFlowInternalState(continuation: continuation, controller: sut)
    }

    // MARK: - signIn (happy path -> password required)

    func test_signIn_happyPath_returnsPasswordRequired() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signin")
        ]
        parserMock.interactionResponses = [
            .challengeRequired(continuationToken: "ct-2", challengeHref: "https://contoso.com/password/challenge", hint: nil),
            .verificationRequired(
                continuationToken: "ct-3",
                verifyHref: "https://contoso.com/password/verify",
                resendHref: nil,
                sentTo: "",
                channelType: MSALNativeAuthChannelType(value: "password"),
                codeLength: 0
            )
        ]

        let response = await sut.signIn(parameters: signInParameters())

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        guard state is MSALNativeAuthPasswordRequiredState else {
            return XCTFail("Expected passwordRequired state, got \(state)")
        }
        XCTAssertTrue(requestProviderMock.authorizeChallengeStartCalled)
        XCTAssertTrue(requestProviderMock.signInStartCalled)
        XCTAssertTrue(requestProviderMock.challengeCalled)
    }

    func test_signIn_whenPasswordSupplied_autoSubmitsAndCompletes() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signin"),
            .authorizationCode(code: "auth-code")
        ]
        parserMock.interactionResponses = [
            .challengeRequired(continuationToken: "ct-2", challengeHref: "https://contoso.com/password/challenge", hint: nil),
            .verificationRequired(
                continuationToken: "ct-3",
                verifyHref: "https://contoso.com/password/verify",
                resendHref: nil,
                sentTo: "",
                channelType: MSALNativeAuthChannelType(value: "password"),
                codeLength: 0
            ),
            .readyToComplete(continuationToken: "ct-continue")
        ]
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()

        let response = await sut.signIn(parameters: signInParameters(password: "password"))

        guard case .completed = response.result else {
            return XCTFail("Expected completed, got \(response.result)")
        }
        XCTAssertTrue(requestProviderMock.submitPasswordCalled)
        XCTAssertEqual(requestProviderMock.submitPasswordHrefReceived, "https://contoso.com/password/verify")
        XCTAssertTrue(requestProviderMock.tokenCalled)
    }

    func test_signIn_whenAuthorizationChallengeFails_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [.error(MSALNativeAuthFlowError(type: .generalError))]

        let response = await sut.signIn(parameters: signInParameters())

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertFalse(requestProviderMock.signInStartCalled)
    }

    func test_signIn_whenUserNotFound_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signin")
        ]
        parserMock.interactionResponses = [
            .error(MSALNativeAuthFlowError(type: .userNotFound))
        ]

        let response = await sut.signIn(parameters: signInParameters())

        guard case .error(let error, _) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isUserNotFound)
    }

    func test_signIn_whenVerificationMethodIsNotPassword_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signin")
        ]
        parserMock.interactionResponses = [
            .challengeRequired(continuationToken: "ct-2", challengeHref: "https://contoso.com/email/challenge", hint: nil),
            .verificationRequired(
                continuationToken: "ct-3",
                verifyHref: "https://contoso.com/email/verify",
                resendHref: nil,
                sentTo: "user@contoso.com",
                channelType: MSALNativeAuthChannelType(value: "email"),
                codeLength: 8
            )
        ]

        let response = await sut.signIn(parameters: signInParameters())

        guard case .error(let error, _) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isUserDoesNotHavePassword)
    }

    func test_submitPassword_happyPath_exchangesTokenAndCompletes() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [.readyToComplete(continuationToken: "ct-continue")]
        parserMock.authorizeChallengeResponses = [.authorizationCode(code: "auth-code")]
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()
        let state = makeSignInState(
            links: [.verify: URL(string: "https://contoso.com/password/verify")!],
            scopes: ["scope1"],
            claimsRequestJson: "{\"access_token\":{}}"
        )

        let response = await sut.submitPassword("password", state: state)

        guard case .completed = response.result else {
            return XCTFail("Expected completed, got \(response.result)")
        }
        XCTAssertTrue(requestProviderMock.submitPasswordCalled)
        XCTAssertEqual(requestProviderMock.submitPasswordHrefReceived, "https://contoso.com/password/verify")
        XCTAssertEqual(requestProviderMock.tokenCode, "auth-code")
        XCTAssertTrue(requestProviderMock.tokenScopes?.contains("scope1") ?? false)
        XCTAssertEqual(requestProviderMock.tokenClaimsRequestJson, "{\"access_token\":{}}")
        XCTAssertTrue(requestProviderMock.tokenCalled)
    }

    func test_submitPassword_whenMFARequired_returnsMFARequired() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .mfaRequired(
                continuationToken: "ct-mfa",
                methods: [
                    MSALNativeAuthV2ChallengeMethod(
                        id: "email-id",
                        channelType: "email",
                        hint: "u***@contoso.com",
                        challengeHref: "https://contoso.com/email/challenge"
                    )
                ]
            )
        ]
        let state = makeSignInState(links: [.verify: URL(string: "https://contoso.com/password/verify")!])

        let response = await sut.submitPassword("password", state: state)

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        guard let mfaState = state as? MSALNativeAuthMFARequiredState else {
            return XCTFail("Expected mfaRequired state, got \(state)")
        }
        XCTAssertEqual(mfaState.authMethods.count, 1)
        XCTAssertEqual(mfaState.authMethods.first?.id, "email-id")
        XCTAssertEqual(mfaState.authMethods.first?.channelTargetType.value, "email")
        XCTAssertTrue(requestProviderMock.submitPasswordCalled)
        XCTAssertFalse(requestProviderMock.challengeCalled)
    }

    // MARK: - selectAuthMethod (sign-in MFA)

    func test_selectAuthMethod_signIn_whenCodeRequired_returnsMFAVerificationRequired() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .verificationRequired(
                continuationToken: "ct-otp",
                verifyHref: "https://contoso.com/email/verify",
                resendHref: "https://contoso.com/email/challenge",
                sentTo: "u***@contoso.com",
                channelType: MSALNativeAuthChannelType(value: "email"),
                codeLength: 8
            )
        ]
        let method = MSALAuthMethod(
            id: "email-id",
            challengeType: "email",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            loginHint: "u***@contoso.com"
        )
        let state = makeMFAState(methodLinks: ["email-id": URL(string: "https://contoso.com/email/challenge")!])

        let response = await sut.selectAuthMethod(method, verificationContact: nil, state: state)

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        guard let verificationState = state as? MSALNativeAuthMFAVerificationRequiredState else {
            return XCTFail("Expected mfaVerificationRequired state, got \(state)")
        }
        XCTAssertEqual(verificationState.codeLength, 8)
        XCTAssertEqual(verificationState.channel.value, "email")
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertEqual(requestProviderMock.challengeHrefReceived, "https://contoso.com/email/challenge")
    }

    func test_selectAuthMethod_signIn_whenChallengeLinkMissing_returnsError() async {
        requestProviderMock.mockRequest()
        let method = MSALAuthMethod(
            id: "unknown-id",
            challengeType: "email",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            loginHint: nil
        )
        let state = makeMFAState(methodLinks: [:])

        let response = await sut.selectAuthMethod(method, verificationContact: nil, state: state)

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertFalse(requestProviderMock.challengeCalled)
    }

    // MARK: - submitChallenge (sign-in MFA)

    func test_submitChallenge_signIn_happyPath_exchangesTokenAndCompletes() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [.readyToComplete(continuationToken: "ct-continue")]
        parserMock.authorizeChallengeResponses = [.authorizationCode(code: "auth-code")]
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()
        let state = makeSignInState(links: [.verify: URL(string: "https://contoso.com/email/verify")!], scopes: ["scope1"])

        let response = await sut.submitChallenge("12345678", state: state)

        guard case .completed = response.result else {
            return XCTFail("Expected completed, got \(response.result)")
        }
        XCTAssertTrue(requestProviderMock.verifyCalled)
        XCTAssertTrue(requestProviderMock.tokenScopes?.contains("scope1") ?? false)
        XCTAssertTrue(requestProviderMock.tokenCalled)
    }

    func test_submitChallenge_signIn_whenInvalidCode_returnsErrorWithRetryState() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [.error(MSALNativeAuthFlowError(type: .invalidCode))]
        let state = makeSignInState(links: [.verify: URL(string: "https://contoso.com/email/verify")!])

        let response = await sut.submitChallenge("00000000", state: state)

        guard case .error(let error, let newState) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isInvalidCode)
        XCTAssertNotNil(newState)
    }

    func test_submitPassword_whenInvalidPassword_returnsErrorWithRetryState() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [.error(MSALNativeAuthFlowError(type: .invalidPassword))]
        let state = makeSignInState(links: [.verify: URL(string: "https://contoso.com/password/verify")!])

        let response = await sut.submitPassword("wrong", state: state)

        guard case .error(let error, let newState) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertEqual(error.type, .invalidPassword)
        XCTAssertNotNil(newState)
    }

    func test_submitPassword_whenVerifyLinkMissing_returnsError() async {
        requestProviderMock.mockRequest()
        let state = makeSignInState(links: [:])

        let response = await sut.submitPassword("password", state: state)

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertFalse(requestProviderMock.submitPasswordCalled)
    }

    // MARK: - submitCode (sign-in MFA)

    func test_submitCode_signIn_happyPath_exchangesTokenAndCompletes() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [.readyToComplete(continuationToken: "ct-continue")]
        parserMock.authorizeChallengeResponses = [.authorizationCode(code: "auth-code")]
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()
        let state = makeSignInState(links: [.verify: URL(string: "https://contoso.com/email/verify")!], scopes: ["scope1"])

        let response = await sut.submitCode("12345678", state: state)

        guard case .completed = response.result else {
            return XCTFail("Expected completed, got \(response.result)")
        }
        XCTAssertTrue(requestProviderMock.verifyCalled)
        XCTAssertTrue(requestProviderMock.tokenScopes?.contains("scope1") ?? false)
        XCTAssertTrue(requestProviderMock.tokenCalled)
    }

    func test_submitCode_signIn_whenInvalidCode_returnsErrorWithRetryState() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [.error(MSALNativeAuthFlowError(type: .invalidCode))]
        let state = makeSignInState(links: [.verify: URL(string: "https://contoso.com/email/verify")!])

        let response = await sut.submitCode("00000000", state: state)

        guard case .error(let error, let newState) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isInvalidCode)
        XCTAssertNotNil(newState)
    }

    // MARK: - resendCode (sign-in MFA)

    func test_resendCode_signIn_whenCodeRequired_returnsCodeRequired() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .verificationRequired(
                continuationToken: "ct-otp",
                verifyHref: "https://contoso.com/email/verify",
                resendHref: "https://contoso.com/email/challenge",
                sentTo: "u***@contoso.com",
                channelType: MSALNativeAuthChannelType(value: "email"),
                codeLength: 8
            )
        ]
        let state = makeSignInState(links: [.resend: URL(string: "https://contoso.com/email/challenge")!])

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
