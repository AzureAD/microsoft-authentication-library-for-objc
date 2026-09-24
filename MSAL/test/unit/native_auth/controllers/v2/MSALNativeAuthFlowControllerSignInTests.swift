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
            claimsRequestJson: nil,
            authMethodSelectionType: .mfa
        )
        return MSALNativeAuthFlowInternalState(continuation: continuation, controller: sut)
    }

    private func makePrimarySelectionState(
        methods: [MSALNativeAuthV2ChallengeMethod],
        continuationToken: String? = "ct-primary",
        scopes: [String] = ["scope1"],
        claimsRequestJson: String? = nil,
        correlationId: UUID = UUID()
    ) -> MSALNativeAuthFlowInternalState {
        var links: [MSALNativeAuthV2LinkKey: URL] = [:]
        for method in methods {
            links[.method(id: method.id)] = URL(string: method.challengeHref)
        }
        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: .signIn,
            correlationId: correlationId,
            continuationToken: continuationToken,
            links: links,
            scopes: scopes,
            claimsRequestJson: claimsRequestJson,
            authMethodSelectionType: .primarySignIn
        )
        return MSALNativeAuthFlowInternalState(continuation: continuation, controller: sut)
    }

    private func primaryMethods(passwordFirst: Bool = true) -> [MSALNativeAuthV2ChallengeMethod] {
        let password = MSALNativeAuthV2ChallengeMethod(
            id: "password-id",
            channelType: .password,
            hint: nil,
            challengeHref: "https://contoso.com/password/challenge"
        )
        let email = MSALNativeAuthV2ChallengeMethod(
            id: "email-id",
            channelType: .email,
            hint: "u***@contoso.com",
            challengeHref: "https://contoso.com/email/challenge"
        )
        return passwordFirst ? [password, email] : [email, password]
    }

    private func prepareSignInStart(methods: [MSALNativeAuthV2ChallengeMethod]) {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signin")
        ]
        parserMock.interactionResponses = [.challengeRequired(continuationToken: "ct-2", methods: methods)]
    }

    private func passwordVerificationRequired() -> MSALNativeAuthV2InteractionParsedResponse {
        return .verificationRequired(
            continuationToken: "ct-password",
            verifyHref: "https://contoso.com/password/verify",
            resendHref: nil,
            sentTo: "",
            channelType: MSALNativeAuthChannelType(value: "password"),
            codeLength: 0
        )
    }

    private func emailVerificationRequired() -> MSALNativeAuthV2InteractionParsedResponse {
        return .verificationRequired(
            continuationToken: "ct-email",
            verifyHref: "https://contoso.com/email/verify",
            resendHref: "https://contoso.com/email/resend",
            sentTo: "u***@contoso.com",
            channelType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 8
        )
    }

    private func assertPrimarySelectionRequired(
        password: String?,
        methods: [MSALNativeAuthV2ChallengeMethod],
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        prepareSignInStart(methods: methods)
        let response = await sut.signIn(parameters: signInParameters(password: password))

        guard case .actionRequired(let state) = response.result,
              let selectionState = state as? MSALNativeAuthAuthMethodSelectionRequiredState else {
            return XCTFail("Expected auth method selection state, got \(response.result)", file: file, line: line)
        }
        XCTAssertEqual(selectionState.authMethods.map(\.id), methods.map(\.id), file: file, line: line)
        XCTAssertFalse(requestProviderMock.challengeCalled, file: file, line: line)
        XCTAssertFalse(requestProviderMock.submitPasswordCalled, file: file, line: line)
    }

    // MARK: - signIn (happy path -> password required)

    func test_signIn_happyPath_returnsPasswordRequired() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signin")
        ]
        parserMock.interactionResponses = [
            .challengeRequired(
                continuationToken: "ct-2",
                methods: [MSALNativeAuthV2ChallengeMethod(id: "1", channelType: .password, hint: nil, challengeHref: "https://contoso.com/password/challenge")]
            ),
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
            .challengeRequired(
                continuationToken: "ct-2",
                methods: [MSALNativeAuthV2ChallengeMethod(id: "1", channelType: .password, hint: nil, challengeHref: "https://contoso.com/password/challenge")]
            ),
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

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isUserNotFound)
    }

    func test_signIn_whenMultipleSupportedMethodsAndNoPassword_returnsSelectionRequired() async {
        await assertPrimarySelectionRequired(password: nil, methods: primaryMethods())
    }

    func test_signIn_whenMultipleSupportedMethodsAndEmptyPassword_returnsSelectionRequired() async {
        await assertPrimarySelectionRequired(password: "", methods: primaryMethods(passwordFirst: false))
    }

    func test_signIn_whenMultipleSupportedMethodsAndPassword_returnsSelectionRequired() async {
        await assertPrimarySelectionRequired(password: "upfront-password", methods: primaryMethods())
    }

    func test_signIn_whenMultipleMethodsShareSupportedChannel_returnsSelectionRequired() async {
        let methods = [
            MSALNativeAuthV2ChallengeMethod(id: "email-1", channelType: .email, hint: "first", challengeHref: "https://contoso.com/email/first"),
            MSALNativeAuthV2ChallengeMethod(id: "email-2", channelType: .email, hint: "second", challengeHref: "https://contoso.com/email/second")
        ]
        await assertPrimarySelectionRequired(password: nil, methods: methods)
    }

    func test_signIn_whenOneSupportedMethodAndSMSAvailable_challengesSupportedMethod() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signin")
        ]
        parserMock.interactionResponses = [
            .challengeRequired(
                continuationToken: "ct-2",
                methods: [
                    MSALNativeAuthV2ChallengeMethod(id: "sms-id", channelType: .sms, hint: nil, challengeHref: "https://contoso.com/sms/challenge"),
                    MSALNativeAuthV2ChallengeMethod(id: "email-id", channelType: .email, hint: "user@contoso.com", challengeHref: "https://contoso.com/email/challenge")
                ]
            ),
            .verificationRequired(
                continuationToken: "ct-3",
                verifyHref: "https://contoso.com/email/verify",
                resendHref: nil,
                sentTo: "u***@contoso.com",
                channelType: MSALNativeAuthChannelType(value: "email"),
                codeLength: 8
            )
        ]

        let response = await sut.signIn(parameters: signInParameters())

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        XCTAssertTrue(state is MSALNativeAuthCodeRequiredState)
        XCTAssertEqual(requestProviderMock.challengeHrefReceived, "https://contoso.com/email/challenge")
    }

    func test_signIn_whenNoSupportedMethods_returnsErrorWithoutChallenge() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signin")
        ]
        parserMock.interactionResponses = [
            .challengeRequired(
                continuationToken: "ct-2",
                methods: [
                    MSALNativeAuthV2ChallengeMethod(id: "sms-id", channelType: .sms, hint: nil, challengeHref: "https://contoso.com/sms/challenge")
                ]
            )
        ]

        let response = await sut.signIn(parameters: signInParameters(password: "password"))

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isGeneralError)
        XCTAssertFalse(requestProviderMock.challengeCalled)
        XCTAssertFalse(requestProviderMock.submitPasswordCalled)
    }

    func test_signIn_whenPasswordSuppliedAndOnlyEmailAvailable_returnsCodeRequired() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signin")
        ]
        parserMock.interactionResponses = [
            .challengeRequired(
                continuationToken: "ct-2",
                methods: [
                    MSALNativeAuthV2ChallengeMethod(
                        id: "1",
                        channelType: .email,
                        hint: "user@contoso.com",
                        challengeHref: "https://contoso.com/email/challenge"
                    )
                ]
            ),
            .verificationRequired(
                continuationToken: "ct-3",
                verifyHref: "https://contoso.com/email/verify",
                resendHref: "https://contoso.com/email/challenge",
                sentTo: "u***@contoso.com",
                channelType: MSALNativeAuthChannelType(value: "email"),
                codeLength: 8
            )
        ]

        let response = await sut.signIn(parameters: signInParameters(password: ""))

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        XCTAssertTrue(state is MSALNativeAuthCodeRequiredState)
        XCTAssertEqual(requestProviderMock.challengeHrefReceived, "https://contoso.com/email/challenge")
    }

    // MARK: - submitCode (sign-in)

    func test_submitCode_signIn_happyPath_exchangesTokenAndCompletes() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [.readyToComplete(continuationToken: "ct-continue")]
        parserMock.authorizeChallengeResponses = [.authorizationCode(code: "auth-code")]
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()
        let state = makeSignInState(
            links: [.verify: URL(string: "https://contoso.com/email/verify")!],
            scopes: ["scope1"],
            claimsRequestJson: "{\"access_token\":{}}"
        )

        let response = await sut.submitCode("12345678", state: state)

        guard case .completed = response.result else {
            return XCTFail("Expected completed, got \(response.result)")
        }
        XCTAssertTrue(requestProviderMock.verifyCalled)
        XCTAssertEqual(requestProviderMock.verifyHrefReceived, "https://contoso.com/email/verify")
        XCTAssertEqual(requestProviderMock.tokenCode, "auth-code")
        XCTAssertTrue(requestProviderMock.tokenScopes?.contains("scope1") ?? false)
        XCTAssertEqual(requestProviderMock.tokenClaimsRequestJson, "{\"access_token\":{}}")
        XCTAssertTrue(requestProviderMock.tokenCalled)
    }

    func test_submitCode_signIn_whenSMSMFARequired_returnsAuthMethodSelectionRequired() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .mfaRequired(
                continuationToken: "ct-mfa",
                methods: [
                    MSALNativeAuthV2ChallengeMethod(
                        id: "sms-id",
                        channelType: .sms,
                        hint: "+1********00",
                        challengeHref: "/tenant/api/v0.1/auth/methods/sms/sms-id/challenge?dc=test-dc"
                    )
                ]
            )
        ]
        let state = makeSignInState(
            links: [.verify: URL(string: "https://contoso.com/email/verify")!],
            scopes: ["scope1"],
            claimsRequestJson: "{\"access_token\":{}}"
        )

        let response = await sut.submitCode("12345678", state: state)

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        guard let selectionState = state as? MSALNativeAuthAuthMethodSelectionRequiredState else {
            return XCTFail("Expected authMethodSelectionRequired state, got \(state)")
        }
        XCTAssertEqual(selectionState.authMethods.count, 1)
        XCTAssertEqual(selectionState.authMethods.first?.id, "sms-id")
        XCTAssertTrue(selectionState.authMethods.first?.channelTargetType.isSMSType ?? false)
        XCTAssertEqual(selectionState.internalState.continuation.continuationToken, "ct-mfa")
        XCTAssertEqual(selectionState.internalState.continuation.scopes, ["scope1"])
        XCTAssertEqual(selectionState.internalState.continuation.claimsRequestJson, "{\"access_token\":{}}")
        XCTAssertEqual(selectionState.internalState.continuation.authMethodSelectionType, .mfa)
        XCTAssertFalse(requestProviderMock.challengeCalled)
    }

    func test_submitCode_signIn_whenInvalidCode_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [.error(MSALNativeAuthFlowError(type: .invalidCode))]
        let state = makeSignInState(links: [.verify: URL(string: "https://contoso.com/email/verify")!])

        let response = await sut.submitCode("00000000", state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isInvalidCode)
    }

    func test_resendCode_signIn_preservesScopesAndClaims() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .verificationRequired(
                continuationToken: "ct-new",
                verifyHref: "https://contoso.com/email/verify-new",
                resendHref: "https://contoso.com/email/challenge-new",
                sentTo: "u***@contoso.com",
                channelType: MSALNativeAuthChannelType(value: "email"),
                codeLength: 8
            )
        ]
        let state = makeSignInState(
            links: [.resend: URL(string: "https://contoso.com/email/challenge")!],
            scopes: ["scope1"],
            claimsRequestJson: "{\"access_token\":{}}"
        )

        let response = await sut.resendCode(state: state)

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        guard let codeRequiredState = state as? MSALNativeAuthCodeRequiredState else {
            return XCTFail("Expected codeRequired state, got \(state)")
        }
        XCTAssertEqual(codeRequiredState.internalState.continuation.scopes, ["scope1"])
        XCTAssertEqual(codeRequiredState.internalState.continuation.claimsRequestJson, "{\"access_token\":{}}")
        XCTAssertEqual(codeRequiredState.internalState.continuation.continuationToken, "ct-new")
        XCTAssertEqual(requestProviderMock.challengeHrefReceived, "https://contoso.com/email/challenge")
        XCTAssertEqual(requestProviderMock.challengeApiIdReceived, .telemetryApiIdV2SignInResendCode)
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

    func test_submitPassword_whenTokenExchangeReturnsMFARequired_returnsGeneralError() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [.readyToComplete(continuationToken: "ct-continue")]
        parserMock.authorizeChallengeResponses = [.authorizationCode(code: "auth-code")]
        parserMock.tokenResponses = [.error(MSALNativeAuthFlowError(
            type: .generalError,
            errorDescription: "AADSTS50076: multi-factor authentication is required.",
            errorCodes: [50076]
        ))]
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()
        let state = makeSignInState(links: [.verify: URL(string: "https://contoso.com/password/verify")!])

        let response = await sut.submitPassword("password", state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isGeneralError)
        XCTAssertEqual(error.errorDescription, "AADSTS50076: multi-factor authentication is required.")
        XCTAssertTrue(requestProviderMock.tokenCalled)
    }

    func test_submitPassword_whenTokenExchangeReturnsGenericError_returnsGeneralError() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [.readyToComplete(continuationToken: "ct-continue")]
        parserMock.authorizeChallengeResponses = [.authorizationCode(code: "auth-code")]
        parserMock.tokenResponses = [.error(MSALNativeAuthFlowError(
            type: .generalError,
            errorDescription: "AADSTS70000: provided grant is invalid.",
            errorCodes: [70000]
        ))]
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()
        let state = makeSignInState(links: [.verify: URL(string: "https://contoso.com/password/verify")!])

        let response = await sut.submitPassword("password", state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isGeneralError)
        XCTAssertEqual(error.errorDescription, "AADSTS70000: provided grant is invalid.")
        XCTAssertFalse(error.isBrowserRequired)
        XCTAssertTrue(requestProviderMock.tokenCalled)
    }

    func test_submitPassword_whenEmailMFARequired_returnsAuthMethodSelectionRequired() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .mfaRequired(
                continuationToken: "ct-mfa",
                methods: [
                    MSALNativeAuthV2ChallengeMethod(
                        id: "email-id",
                        channelType: .email,
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
        guard let mfaState = state as? MSALNativeAuthAuthMethodSelectionRequiredState else {
            return XCTFail("Expected mfaRequired state, got \(state)")
        }
        XCTAssertEqual(mfaState.authMethods.count, 1)
        XCTAssertEqual(mfaState.authMethods.first?.id, "email-id")
        XCTAssertEqual(mfaState.authMethods.first?.channelTargetType.value, "email")
        XCTAssertTrue(requestProviderMock.submitPasswordCalled)
        XCTAssertFalse(requestProviderMock.challengeCalled)
    }

    func test_submitPassword_whenSMSMFARequired_returnsAuthMethodSelectionRequired() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .mfaRequired(
                continuationToken: "ct-mfa",
                methods: [
                    MSALNativeAuthV2ChallengeMethod(
                        id: "sms-id",
                        channelType: .sms,
                        hint: "+1********00",
                        challengeHref: "/tenant/api/v0.1/auth/methods/sms/sms-id/challenge?dc=test-dc"
                    )
                ]
            )
        ]
        let state = makeSignInState(links: [.verify: URL(string: "https://contoso.com/password/verify")!])

        let response = await sut.submitPassword("password", state: state)

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        guard let selectionState = state as? MSALNativeAuthAuthMethodSelectionRequiredState else {
            return XCTFail("Expected authMethodSelectionRequired state, got \(state)")
        }
        XCTAssertEqual(selectionState.authMethods.count, 1)
        XCTAssertEqual(selectionState.authMethods.first?.id, "sms-id")
        XCTAssertTrue(selectionState.authMethods.first?.channelTargetType.isSMSType ?? false)
        XCTAssertTrue(requestProviderMock.submitPasswordCalled)
        XCTAssertFalse(requestProviderMock.challengeCalled)
    }

    func test_submitPassword_whenMFAMethodHasEmptyChallengeLink_returnsError() async {
        await assertSubmitPasswordRejectsMFAChallengeHref("")
    }

    func test_submitPassword_whenMFAMethodHasWhitespaceOnlyChallengeLink_returnsError() async {
        await assertSubmitPasswordRejectsMFAChallengeHref(" \t\r\n ")
    }

    private func assertSubmitPasswordRejectsMFAChallengeHref(_ href: String, file: StaticString = #filePath, line: UInt = #line) async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .mfaRequired(
                continuationToken: "ct-mfa",
                methods: [
                    MSALNativeAuthV2ChallengeMethod(
                        id: "email-id",
                        channelType: .email,
                        hint: "u***@contoso.com",
                        challengeHref: href
                    )
                ]
            )
        ]
        let state = makeSignInState(links: [.verify: URL(string: "https://contoso.com/password/verify")!])

        let response = await sut.submitPassword("password", state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)", file: file, line: line)
        }
        XCTAssertTrue(error.isGeneralError, file: file, line: line)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.invalidAuthMethodChallengeLink, file: file, line: line)
        XCTAssertTrue(requestProviderMock.submitPasswordCalled, file: file, line: line)
        XCTAssertFalse(requestProviderMock.challengeCalled, file: file, line: line)
    }

    // MARK: - selectAuthMethod (primary sign-in)

    func test_selectAuthMethod_primaryPassword_completesOnlyAfterExplicitPasswordSubmission() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            passwordVerificationRequired(),
            .readyToComplete(continuationToken: "ct-continue")
        ]
        parserMock.authorizeChallengeResponses = [.authorizationCode(code: "auth-code")]
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()
        let methods = primaryMethods()
        let state = makePrimarySelectionState(
            methods: methods,
            scopes: ["scope1"],
            claimsRequestJson: "{\"access_token\":{}}"
        )
        let selectedMethod = MSALAuthMethod(
            id: "password-id",
            challengeType: "email",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            loginHint: nil
        )

        let response = await sut.selectAuthMethod(selectedMethod, verificationContact: nil, state: state)

        guard case .actionRequired(let resultState) = response.result,
              let passwordState = resultState as? MSALNativeAuthPasswordRequiredState else {
            return XCTFail("Expected passwordRequired, got \(response.result)")
        }
        XCTAssertEqual(requestProviderMock.challengeHrefReceived, "https://contoso.com/password/challenge")
        XCTAssertEqual(requestProviderMock.challengeApiIdReceived, .telemetryApiIdV2SignInSelectAuthMethod)
        XCTAssertFalse(requestProviderMock.submitPasswordCalled)
        XCTAssertFalse(requestProviderMock.tokenCalled)
        XCTAssertEqual(passwordState.internalState.continuation.correlationId, state.continuation.correlationId)

        let completion = await sut.submitPassword("explicit-password", state: passwordState.internalState)

        guard case .completed = completion.result else {
            return XCTFail("Expected completed, got \(completion.result)")
        }
        XCTAssertEqual(requestProviderMock.submitPasswordReceived, "explicit-password")
        XCTAssertEqual(requestProviderMock.submitPasswordCallCount, 1)
        XCTAssertTrue(requestProviderMock.tokenScopes?.contains("scope1") ?? false)
        XCTAssertEqual(requestProviderMock.tokenClaimsRequestJson, "{\"access_token\":{}}")
    }

    func test_selectAuthMethod_primaryPasswordWithUpfrontPassword_returnsPasswordRequired() async {
        await assertPrimaryPasswordSelectionRequiresPassword(upfrontPassword: "must-not-be-submitted")
    }

    func test_selectAuthMethod_primaryPasswordWithoutUpfrontPassword_returnsPasswordRequired() async {
        await assertPrimaryPasswordSelectionRequiresPassword(upfrontPassword: nil)
    }

    func test_selectAuthMethod_primaryPasswordWithEmptyUpfrontPassword_returnsPasswordRequired() async {
        await assertPrimaryPasswordSelectionRequiresPassword(upfrontPassword: "")
    }

    private func assertPrimaryPasswordSelectionRequiresPassword(
        upfrontPassword: String?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let methods = primaryMethods()
        prepareSignInStart(methods: methods)
        let startResponse = await sut.signIn(parameters: signInParameters(password: upfrontPassword))
        guard case .actionRequired(let startState) = startResponse.result,
              let selectionState = startState as? MSALNativeAuthAuthMethodSelectionRequiredState else {
            return XCTFail("Expected auth method selection state, got \(startResponse.result)", file: file, line: line)
        }
        parserMock.interactionResponses.append(passwordVerificationRequired())
        let selectedMethod = methods[0].publicAuthMethod

        let response = await sut.selectAuthMethod(selectedMethod, verificationContact: nil, state: selectionState.internalState)

        guard case .actionRequired(let resultState) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)", file: file, line: line)
        }
        XCTAssertTrue(resultState is MSALNativeAuthPasswordRequiredState, file: file, line: line)
        XCTAssertNil(resultState.internalState.continuation.authMethodSelectionType, file: file, line: line)
        XCTAssertTrue(requestProviderMock.challengeCalled, file: file, line: line)
        XCTAssertFalse(requestProviderMock.submitPasswordCalled, file: file, line: line)
        XCTAssertFalse(requestProviderMock.tokenCalled, file: file, line: line)
    }

    func test_selectAuthMethod_primaryEmailWithUpfrontPassword_returnsCodeRequiredWithoutSubmittingPassword() async {
        let methods = primaryMethods()
        prepareSignInStart(methods: methods)
        let startResponse = await sut.signIn(parameters: signInParameters(password: "must-not-be-submitted"))
        guard case .actionRequired(let startState) = startResponse.result,
              let selectionState = startState as? MSALNativeAuthAuthMethodSelectionRequiredState else {
            return XCTFail("Expected auth method selection state, got \(startResponse.result)")
        }
        parserMock.interactionResponses.append(emailVerificationRequired())
        let selectedMethod = MSALAuthMethod(
            id: "email-id",
            challengeType: "password",
            channelTargetType: MSALNativeAuthChannelType(value: "password"),
            loginHint: nil
        )

        let response = await sut.selectAuthMethod(selectedMethod, verificationContact: nil, state: selectionState.internalState)

        guard case .actionRequired(let resultState) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        XCTAssertTrue(resultState is MSALNativeAuthCodeRequiredState)
        XCTAssertEqual(requestProviderMock.challengeHrefReceived, "https://contoso.com/email/challenge")
        XCTAssertFalse(requestProviderMock.submitPasswordCalled)
    }

    func test_selectAuthMethod_primaryPassword_cannotReuseConsumedSelection() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [passwordVerificationRequired()]
        let methods = primaryMethods()
        let state = makePrimarySelectionState(methods: methods)
        let selectedMethod = methods[0].publicAuthMethod

        let firstResponse = await sut.selectAuthMethod(selectedMethod, verificationContact: nil, state: state)
        let secondResponse = await sut.selectAuthMethod(selectedMethod, verificationContact: nil, state: state)

        guard case .actionRequired(let passwordState) = firstResponse.result,
              case .error = secondResponse.result else {
            return XCTFail("Expected passwordRequired followed by an error for repeated selection")
        }
        XCTAssertTrue(passwordState is MSALNativeAuthPasswordRequiredState)
        XCTAssertEqual(requestProviderMock.challengeCallCount, 1)
        XCTAssertFalse(requestProviderMock.submitPasswordCalled)
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

    func test_selectAuthMethod_signIn_whenSMSRiskVerificationRequired_returnsMFAVerificationRequired() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .riskVerificationRequired(
                continuationToken: "ct-risk",
                riskVerifyHref: "/tenant/api/v1.0-internal/risk/phone/verify"
            ),
            .verificationRequired(
                continuationToken: "ct-otp",
                verifyHref: "https://contoso.com/sms/verify",
                resendHref: "https://contoso.com/sms/challenge",
                sentTo: "+1********00",
                channelType: MSALNativeAuthChannelType(value: "sms"),
                codeLength: 6
            )
        ]
        let method = MSALAuthMethod(
            id: "sms-id",
            challengeType: "sms",
            channelTargetType: MSALNativeAuthChannelType(value: "sms"),
            loginHint: "+1********00"
        )
        let state = makeMFAState(
            methodLinks: ["sms-id": URL(string: "https://contoso.com/sms/challenge")!]
        )

        let response = await sut.selectAuthMethod(method, verificationContact: nil, state: state)

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        guard let verificationState = state as? MSALNativeAuthMFAVerificationRequiredState else {
            return XCTFail("Expected mfaVerificationRequired state, got \(state)")
        }
        XCTAssertTrue(verificationState.channel.isSMSType)
        XCTAssertEqual(verificationState.codeLength, 6)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertTrue(requestProviderMock.riskVerifyCalled)
        XCTAssertEqual(
            requestProviderMock.riskVerifyHrefReceived,
            "/tenant/api/v1.0-internal/risk/phone/verify"
        )
        XCTAssertEqual(requestProviderMock.riskVerifyTokenReceived, "ct-risk")
        XCTAssertEqual(requestProviderMock.riskVerifyApiIdReceived, .telemetryApiIdV2MFAGetAuthMethods)
    }

    func test_selectAuthMethod_signIn_whenSMSRiskVerificationRequiredTwice_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .riskVerificationRequired(
                continuationToken: "ct-risk",
                riskVerifyHref: "/tenant/api/v1.0-internal/risk/phone/verify"
            ),
            .riskVerificationRequired(
                continuationToken: "ct-risk-repeat",
                riskVerifyHref: "/tenant/api/v1.0-internal/risk/phone/verify-repeat"
            )
        ]
        let method = MSALAuthMethod(
            id: "sms-id",
            challengeType: "sms",
            channelTargetType: MSALNativeAuthChannelType(value: "sms"),
            loginHint: "+1********00"
        )
        let state = makeMFAState(
            methodLinks: ["sms-id": URL(string: "https://contoso.com/sms/challenge")!]
        )

        let response = await sut.selectAuthMethod(method, verificationContact: nil, state: state)

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertEqual(requestProviderMock.riskVerifyCallCount, 1)
    }

    func test_selectAuthMethod_signIn_whenEmailRiskVerificationRequired_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .riskVerificationRequired(
                continuationToken: "ct-risk",
                riskVerifyHref: "/tenant/api/v1.0-internal/risk/phone/verify"
            )
        ]
        let method = MSALAuthMethod(
            id: "email-id",
            challengeType: "email",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            loginHint: "u***@contoso.com"
        )
        let state = makeMFAState(
            methodLinks: ["email-id": URL(string: "https://contoso.com/email/challenge")!]
        )

        let response = await sut.selectAuthMethod(method, verificationContact: nil, state: state)

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertFalse(requestProviderMock.riskVerifyCalled)
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

    func test_selectAuthMethod_primaryMissingContinuation_returnsError() async {
        requestProviderMock.mockRequest()
        let methods = primaryMethods()
        let state = makePrimarySelectionState(methods: methods, continuationToken: nil)

        let response = await sut.selectAuthMethod(methods[0].publicAuthMethod, verificationContact: nil, state: state)

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertFalse(requestProviderMock.challengeCalled)
        XCTAssertFalse(requestProviderMock.submitPasswordCalled)
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

    func test_submitChallenge_signIn_whenInvalidCode_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [.error(MSALNativeAuthFlowError(type: .invalidCode))]
        let state = makeSignInState(links: [.verify: URL(string: "https://contoso.com/email/verify")!])

        let response = await sut.submitChallenge("00000000", state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isInvalidCode)
    }

    func test_submitPassword_whenInvalidPassword_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [.error(MSALNativeAuthFlowError(type: .invalidPassword))]
        let state = makeSignInState(links: [.verify: URL(string: "https://contoso.com/password/verify")!])

        let response = await sut.submitPassword("wrong", state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertEqual(error.type, .invalidPassword)
    }

    func test_submitPassword_whenInvalidCredentials_surfacesInvalidPassword() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [.error(MSALNativeAuthFlowError(
            type: .invalidCredentials,
            errorDescription: "AADSTS50126: Error validating credentials.",
            errorCodes: [50126]
        ))]
        let state = makeSignInState(links: [.verify: URL(string: "https://contoso.com/password/verify")!])

        let response = await sut.submitPassword("wrong", state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isInvalidPassword)
        XCTAssertEqual(error.errorDescription, "AADSTS50126: Error validating credentials.")
        XCTAssertEqual(error.errorCodes, [50126])
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
}
