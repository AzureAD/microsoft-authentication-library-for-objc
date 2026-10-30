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
@_implementationOnly import MSAL_Unit_Test_Private

// swiftlint:disable type_body_length file_length
final class MSALNativeAuthFlowControllerSignUpTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthFlowController!
    private var requestProviderMock: MSALNativeAuthV2RequestProviderMock!
    private var parserMock: MSALNativeAuthV2ResponseParserMock!
    private var cacheAccessorMock: MSALNativeAuthCacheAccessorMock!
    private var resultFactoryMock: MSALNativeAuthResultFactoryMock!

    private let username = "user@contoso.com"

    override func setUpWithError() throws {
        try super.setUpWithError()

        requestProviderMock = .init()
        parserMock = .init()
        cacheAccessorMock = .init(
            tokenCache: try XCTUnwrap(MSIDDefaultTokenCacheAccessor(dataSource: MSIDTestCacheDataSource(), otherCacheAccessors: [])),
            accountMetadataCache: try XCTUnwrap(MSIDAccountMetadataCacheAccessor(dataSource: MSIDTestCacheDataSource()))
        )
        resultFactoryMock = .init(cacheAccessor: cacheAccessorMock)

        sut = .init(
            config: MSALNativeAuthConfigStubs.configuration,
            requestProvider: requestProviderMock,
            responseParser: parserMock,
            cacheAccessor: cacheAccessorMock,
            resultFactory: resultFactoryMock
        )
    }

    // MARK: - Helpers

    private func signUpParameters(
        password: String? = nil,
        attributes: [String: Any]? = nil,
        scopes: [String]? = ["scope1"]
    ) -> MSALNativeAuthSignUpParametersV2 {
        let params = MSALNativeAuthSignUpParametersV2(username: username)
        params.password = password
        params.attributes = attributes
        params.scopes = scopes
        return params
    }

    private func makeSignUpState(
        links: [MSALNativeAuthV2LinkRelation: URL] = [:],
        continuationToken: String = "ct",
        scopes: [String] = ["scope1"],
        claimsRequestJson: String? = nil,
        submittedAttributes: [String] = [],
        correlationId: UUID = UUID()
    ) -> MSALNativeAuthFlowInternalState {
        let resolved = links.reduce(into: [MSALNativeAuthV2LinkKey: URL]()) { result, entry in
            result[.relation(entry.key)] = entry.value
        }
        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: .signUp,
            correlationId: correlationId,
            continuationToken: continuationToken,
            links: resolved,
            scopes: scopes,
            claimsRequestJson: claimsRequestJson,
            submittedAttributes: submittedAttributes
        )
        return MSALNativeAuthFlowInternalState(continuation: continuation, controller: sut)
    }

    private func passwordAttribute() -> MSALNativeAuthRequiredAttributeInternal {
        MSALNativeAuthRequiredAttributeInternal(name: "password", type: "password", required: true)
    }

    // MARK: - signUp start

    // swiftlint:disable:next function_body_length
    func test_signUpStart_existingAccount_challengesOfferedMethodBeforeCollectingCredential() async throws {
        let configuration = MSALNativeAuthConfigStubs.configuration
        for channel in ["password", "email"] {
            let requestProvider = MSALNativeAuthV2RequestProviderMock()
            requestProvider.authorizeChallengeStartResponseJSON = [
                "continuationToken": "ct-start",
                "_links": ["sign_up": ["href": "https://contoso.com/signup"]]
            ]
            let methodPath = "/tenant/api/v2.0/auth/methods/\(channel)/method-id"
            let resolvedMethodPath = "\(configuration.authority.url.path)/api/v2.0/auth/methods/\(channel)/method-id"
            let challengeHref = "\(methodPath)/challenge?dc=test"
            let verifyHref = "\(methodPath)/verify?dc=test"
            requestProvider.signUpStartResponseJSON = [
                "challengeContext": ["authenticationFactor": "singleFactor"],
                "continuationToken": "ct-existing",
                "state": "interactionRequired", "action": "challenge",
                "_embedded": ["methods": [[
                    "id": "method-id", "type": channel, "hint": "",
                    "_links": [
                        "challenge": ["href": challengeHref, "name": "challenge"],
                        "verify": ["href": verifyHref, "name": "verify"]
                    ]
                ]]],
                "_links": ["self": ["href": "/tenant/api/v2.0/signin/start?dc=test"]]
            ]
            var verification: [String: Any] = [
                "id": "method-id", "type": channel,
                "continuationToken": "ct-verify",
                "state": "interactionRequired", "action": "verify",
                "_links": ["verify": ["href": verifyHref, "name": "verify"]]
            ]
            if channel == "email" {
                verification["hint"] = "u***@contoso.com"
                verification["codeLength"] = 6
                verification["_links"] = [
                    "verify": ["href": verifyHref],
                    "resend": ["href": "\(methodPath)/challenge?dc=resend"]
                ]
            }
            requestProvider.challengeResponseJSON = verification
            let controller = MSALNativeAuthFlowController(
                config: configuration,
                requestProvider: requestProvider,
                responseParser: MSALNativeAuthV2ResponseParser(),
                cacheAccessor: cacheAccessorMock,
                resultFactory: resultFactoryMock
            )
            let parameters = signUpParameters(password: "proposed-new-password", attributes: ["city": "Seattle"])
            parameters.correlationId = UUID()
            let response = await controller.signUp(parameters: parameters)
            guard case .actionRequired(let state) = response.result else { return XCTFail("Expected existing-account credential collection") }
            if channel == "password" {
                XCTAssertTrue(state is MSALNativeAuthExistingAccountPasswordRequiredState)
            } else {
                let codeState = try XCTUnwrap(state as? MSALNativeAuthExistingAccountCodeRequiredState)
                XCTAssertEqual(codeState.sentTo, "u***@contoso.com")
                XCTAssertEqual(codeState.codeLength, 6)
                XCTAssertTrue(codeState.channel.isEmailType)
                XCTAssertEqual(state.internalState.continuation.link(.resend)?.query, "dc=resend")
            }
            let continuation = state.internalState.continuation
            XCTAssertEqual(continuation.flowScenario, .signIn)
            XCTAssertEqual(continuation.correlationId, parameters.correlationId)
            XCTAssertEqual(response.correlationId, parameters.correlationId)
            XCTAssertEqual(continuation.continuationToken, "ct-verify")
            XCTAssertEqual(continuation.link(.verify)?.path, "\(resolvedMethodPath)/verify")
            XCTAssertEqual(continuation.link(.verify)?.query, "dc=test")
            XCTAssertEqual(continuation.scopes, ["scope1", "openid", "profile", "offline_access"])
            XCTAssertTrue(continuation.pendingSignUpAttributes.isEmpty)
            XCTAssertTrue(continuation.submittedAttributes.isEmpty)
            XCTAssertEqual(requestProvider.requests.count, 3)
            XCTAssertTrue(requestProvider.requests.allSatisfy { $0.sendCallCount == 1 })
            XCTAssertEqual(requestProvider.challengeCallCount, 1)
            XCTAssertEqual(requestProvider.challengeHrefReceived, challengeHref)
            XCTAssertEqual(requestProvider.challengeTokenReceived, "ct-existing")
            XCTAssertEqual(requestProvider.challengeApiIdReceived, .telemetryApiIdV2SignUpStart)
            XCTAssertFalse(requestProvider.submitPasswordCalled)
            XCTAssertFalse(requestProvider.verifyCalled)
            XCTAssertFalse(requestProvider.submitAttributesCalled)
            XCTAssertFalse(requestProvider.authorizeChallengeContinueCalled)
        }
    }

    func test_signUpStart_directPasswordVerify_isNotAnExistingAccountChallenge() async {
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-start", href: "https://contoso.com/signup")
        ]
        parserMock.interactionResponses = [existingAccountVerification(channel: "password")]
        let response = await sut.signUp(parameters: signUpParameters(password: "proposed-password"))
        guard case .error(let error) = response.result else { return XCTFail("Expected unsupported sign-up response") }
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(response.scenario, .signUp)
        XCTAssertFalse(requestProviderMock.challengeCalled)
        XCTAssertFalse(requestProviderMock.submitPasswordCalled)
    }

    func test_signUpStart_directEmailVerify_stillVerifiesNewAccount() async throws {
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-start", href: "https://contoso.com/signup")
        ]
        parserMock.interactionResponses = [existingAccountVerification()]
        let response = await sut.signUp(parameters: signUpParameters(password: "proposed-password"))
        guard case .actionRequired(let state) = response.result else { return XCTFail("Expected sign-up code verification") }
        XCTAssertTrue(state is MSALNativeAuthCodeRequiredState)
        XCTAssertFalse(state is MSALNativeAuthExistingAccountCodeRequiredState)
        XCTAssertEqual(state.internalState.continuation.flowScenario, .signUp)
        XCTAssertEqual(state.internalState.continuation.pendingSignUpAttributes["password"] as? String, "proposed-password")
        XCTAssertFalse(requestProviderMock.challengeCalled)
        XCTAssertFalse(requestProviderMock.submitPasswordCalled)
    }

    func test_signUpStart_mfaChallenge_isNotReclassifiedAsExistingAccount() async {
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-start", href: "https://contoso.com/signup")
        ]
        parserMock.interactionResponses = [.mfaRequired(continuationToken: "ct-mfa", methods: [
            .init(id: "email", channelType: .email, hint: "***", challengeHref: "https://contoso.com/mfa")
        ])]
        let response = await sut.signUp(parameters: signUpParameters())
        guard case .error(let error) = response.result else { return XCTFail("Expected unsupported sign-up MFA response") }
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(response.scenario, .signUp)
        XCTAssertFalse(requestProviderMock.challengeCalled)
    }

    private func existingAccountChallenge(
        _ channel: MSALNativeAuthV2ChallengeMethodChannelType
    ) -> MSALNativeAuthV2InteractionParsedResponse {
        .challengeRequired(continuationToken: "ct-existing", methods: [
            MSALNativeAuthV2ChallengeMethod(
                id: "method-id", channelType: channel, hint: nil,
                challengeHref: "https://contoso.com/signin/challenge?dc=test"
            )
        ])
    }

    private func existingAccountVerification(
        channel: String = "email",
        token: String = "ct-verify",
        length: Int = 6
    ) -> MSALNativeAuthV2InteractionParsedResponse {
        .verificationRequired(
            continuationToken: token,
            verifyHref: "https://contoso.com/signin/verify?dc=test",
            resendHref: "https://contoso.com/signin/resend?dc=test",
            sentTo: "u***@contoso.com",
            channelType: MSALNativeAuthChannelType(value: channel),
            codeLength: length
        )
    }

    private func startExistingAccount(
        channel: MSALNativeAuthV2ChallengeMethodChannelType,
        challengeResult: MSALNativeAuthV2InteractionParsedResponse? = nil
    ) async throws -> MSALNativeAuthState {
        parserMock.authorizeChallengeResponses.append(
            .continuationToken(continuationToken: "ct-start", href: "https://contoso.com/signup")
        )
        parserMock.interactionResponses += [
            existingAccountChallenge(channel),
            challengeResult ?? existingAccountVerification(channel: channel.rawValue)
        ]
        let parameters = signUpParameters(password: "proposed-new-password", attributes: ["city": "Seattle"])
        parameters.correlationId = UUID()
        parameters.claimsRequest = try XCTUnwrap(MSALClaimsRequest(
            jsonString: "{\"access_token\":{\"acrs\":{\"essential\":true,\"value\":\"c1\"}}}", error: nil
        ))
        let response = await sut.signUp(parameters: parameters)
        let actionState: MSALNativeAuthState?
        if case .actionRequired(let state) = response.result {
            actionState = state
        } else {
            actionState = nil
        }
        let state = try XCTUnwrap(actionState, "Expected existing-account actionRequired")
        let continuation = state.internalState.continuation
        XCTAssertEqual(continuation.flowScenario, .signIn)
        XCTAssertEqual(continuation.correlationId, parameters.correlationId)
        XCTAssertEqual(response.correlationId, parameters.correlationId)
        XCTAssertEqual(continuation.scopes, ["scope1", "openid", "profile", "offline_access"])
        XCTAssertEqual(requestProviderMock.authorizeChallengeStartClaimsRequestJson, parameters.claimsRequest?.jsonString())
        XCTAssertNil(continuation.claimsRequestJson)
        XCTAssertTrue(continuation.pendingSignUpAttributes.isEmpty)
        XCTAssertTrue(continuation.submittedAttributes.isEmpty)
        XCTAssertFalse(requestProviderMock.submitPasswordCalled)
        XCTAssertFalse(requestProviderMock.submitAttributesCalled)
        XCTAssertFalse(requestProviderMock.authorizeChallengeContinueCalled)
        XCTAssertEqual(requestProviderMock.challengeTokenReceived, "ct-existing")
        XCTAssertEqual(requestProviderMock.challengeHrefReceived, "https://contoso.com/signin/challenge?dc=test")
        return state
    }

    func test_existingAccountPassword_collectsExplicitCredentialAndSupportsRetryAndCompletion() async throws {
        let state = try await startExistingAccount(channel: .password)
        XCTAssertTrue(state is MSALNativeAuthExistingAccountPasswordRequiredState)
        parserMock.interactionResponses += [
            .error(MSALNativeAuthFlowError(type: .invalidCredentials)),
            .readyToComplete(continuationToken: "ct-complete")
        ]
        let failed = await sut.submitPassword("incorrect-password", state: state.internalState)
        guard case .error(let error) = failed.result else { return XCTFail("Expected invalid password") }
        XCTAssertEqual(error.type, .invalidPassword)
        XCTAssertEqual(failed.scenario, .signIn)
        parserMock.authorizeChallengeResponses.append(.authorizationCode(code: "auth-code"))
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()

        let completed = await sut.submitPassword("current-password", state: state.internalState)
        guard case .completed = completed.result else { return XCTFail("Expected existing account sign-in completion") }
        XCTAssertEqual(completed.scenario, .signIn)
        XCTAssertEqual(requestProviderMock.submitPasswordCallCount, 2)
        XCTAssertEqual(requestProviderMock.submitPasswordReceived, "current-password")
        XCTAssertEqual(requestProviderMock.submitPasswordTokenReceived, "ct-verify")
        XCTAssertEqual(requestProviderMock.submitPasswordHrefReceived, "https://contoso.com/signin/verify?dc=test")
        XCTAssertEqual(requestProviderMock.submitPasswordApiIdReceived, .telemetryApiIdV2SignInSubmitPassword)
        XCTAssertFalse(requestProviderMock.submitAttributesCalled)
    }

    func test_existingAccountCode_sharedResendUsesFreshContinuation_thenRetriesAndCompletes() async throws {
        let state = try await startExistingAccount(channel: .email, challengeResult: existingAccountVerification(channel: "EMAIL"))
        let initial = try XCTUnwrap(state as? MSALNativeAuthExistingAccountCodeRequiredState)
        XCTAssertEqual(initial.sentTo, "u***@contoso.com")
        XCTAssertEqual(initial.codeLength, 6)
        XCTAssertTrue(initial.channel.isEmailType)
        parserMock.interactionResponses += [
            existingAccountVerification(token: "ct-resend", length: 8),
            .error(MSALNativeAuthFlowError(type: .invalidCode)),
            .readyToComplete(continuationToken: "ct-complete")
        ]
        let resent = await sut.resendCode(state: initial.internalState)
        guard case .actionRequired(let resentState) = resent.result else { return XCTFail("Expected resent code state") }
        let next = try XCTUnwrap(resentState as? MSALNativeAuthCodeRequiredState)
        XCTAssertFalse(next is MSALNativeAuthExistingAccountCodeRequiredState)
        XCTAssertEqual(next.codeLength, 8)
        XCTAssertEqual(next.internalState.continuation.continuationToken, "ct-resend")
        XCTAssertEqual(next.internalState.continuation.flowScenario, .signIn)
        XCTAssertNil(next.internalState.continuation.claimsRequestJson)
        XCTAssertEqual(requestProviderMock.challengeHrefReceived, "https://contoso.com/signin/resend?dc=test")
        let failed = await sut.submitCode("incorrect-code", state: next.internalState)
        guard case .error(let error) = failed.result else { return XCTFail("Expected invalid code") }
        XCTAssertEqual(error.type, .invalidCode)
        XCTAssertEqual(failed.scenario, .signIn)
        parserMock.authorizeChallengeResponses.append(.authorizationCode(code: "auth-code"))
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()

        let completed = await sut.submitCode("12345678", state: next.internalState)
        guard case .completed = completed.result else { return XCTFail("Expected sign-in completion") }
        XCTAssertEqual(completed.scenario, .signIn)
        XCTAssertEqual(requestProviderMock.verifyTokenReceived, "ct-resend")
        XCTAssertEqual(requestProviderMock.verifyApiIdReceived, .telemetryApiIdV2SignInSubmitCode)
        XCTAssertEqual(requestProviderMock.verifyHrefReceived, "https://contoso.com/signin/verify?dc=test")
        XCTAssertFalse(requestProviderMock.submitAttributesCalled)
    }

    func test_existingAccountDetection_isLimitedToSignUpStart() async throws {
        for result in [existingAccountChallenge(.password), existingAccountVerification(channel: "password")] {
            for operation in ["code", "password", "attributes"] {
                parserMock.interactionResponses.append(result)
                let state = makeSignUpState(
                    links: [
                        .verify: try XCTUnwrap(URL(string: "https://contoso.com/signup/verify")),
                        .submitAttributes: try XCTUnwrap(URL(string: "https://contoso.com/signup/attributes"))
                    ],
                    submittedAttributes: ["city"]
                )
                let response: MSALNativeAuthFlowControllerResponse
                switch operation {
                case "code": response = await sut.submitCode("123456", state: state)
                case "password": response = await sut.submitPassword("proposed-password", state: state)
                default: response = await sut.submitAttributes(["displayName": "Test"], state: state)
                }
                guard case .error(let error) = response.result else { return XCTFail("Expected unexpected sign-up response to fail") }
                XCTAssertEqual(error.type, .generalError)
                XCTAssertEqual(response.scenario, .signUp)
            }
        }
        XCTAssertFalse(requestProviderMock.challengeCalled)
        XCTAssertFalse(requestProviderMock.submitPasswordCalled)
    }

    func test_existingAccountChallenge_enrollmentInterruptionRemainsSignInThroughActivation() async throws {
        let state = try await startExistingAccount(channel: .password, challengeResult: .registrationRequired(
            continuationToken: "ct-enroll",
            methods: [.init(id: "email", enrollHref: "https://contoso.com/enroll", channelType: .email)]
        ))
        let registration = try XCTUnwrap(state as? MSALNativeAuthStrongAuthRegistrationRequiredState)
        parserMock.interactionResponses += [
            .activationRequired(
                continuationToken: "ct-activate", activateHref: "https://contoso.com/activate",
                sentTo: "u***@contoso.com", codeLength: 6
            ),
            .readyToComplete(continuationToken: "ct-complete")
        ]
        let enrolled = await sut.selectAuthMethod(
            try XCTUnwrap(registration.authMethods.first), verificationContact: username, state: state.internalState
        )
        guard case .actionRequired(let activation) = enrolled.result else { return XCTFail("Expected activation") }
        XCTAssertTrue(activation is MSALNativeAuthStrongAuthVerificationRequiredState)
        XCTAssertEqual(activation.internalState.continuation.flowScenario, .signIn)
        parserMock.authorizeChallengeResponses.append(.authorizationCode(code: "auth-code"))
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()
        let completed = await sut.submitChallenge("123456", state: activation.internalState)
        guard case .completed = completed.result else { return XCTFail("Expected sign-in completion") }
        XCTAssertEqual(completed.scenario, .signIn)
    }

    func test_existingAccountCredentials_continueWithOrdinaryMFA() async throws {
        for channel: MSALNativeAuthV2ChallengeMethodChannelType in [.email, .password] {
            parserMock.authorizeChallengeResponses.append(
                .continuationToken(continuationToken: "ct-start", href: "https://contoso.com/signup")
            )
            parserMock.interactionResponses += [
                existingAccountChallenge(channel), existingAccountVerification(channel: channel.rawValue),
                .mfaRequired(continuationToken: "ct-mfa", methods: [
                    .init(id: "sms", channelType: .sms, hint: "***", challengeHref: "https://contoso.com/mfa")
                ])
            ]
            let started = await sut.signUp(parameters: signUpParameters())
            guard case .actionRequired(let state) = started.result else { return XCTFail("Expected credential state") }
            let response = channel == .email
                ? await sut.submitCode("123456", state: state.internalState)
                : await sut.submitPassword("current-password", state: state.internalState)
            guard case .actionRequired(let next) = response.result else { return XCTFail("Expected MFA") }
            XCTAssertTrue(next is MSALNativeAuthAuthMethodSelectionRequiredState)
            XCTAssertEqual(next.internalState.continuation.flowScenario, .signIn)
        }
    }

    func test_existingAccountChallenge_rejectsMismatchedChannelsAndUnexpectedCompletion() async {
        for channel: MSALNativeAuthV2ChallengeMethodChannelType in [.email, .password, .sms] {
            for result in [
                existingAccountVerification(channel: "sms"),
                existingAccountVerification(channel: channel == .email ? "password" : "email"),
                .readyToComplete(continuationToken: "ct-complete")
            ] {
                parserMock.authorizeChallengeResponses.append(
                    .continuationToken(continuationToken: "ct-start", href: "https://contoso.com/signup")
                )
                parserMock.interactionResponses.append(existingAccountChallenge(channel))
                if channel != .sms { parserMock.interactionResponses.append(result) }
                let response = await sut.signUp(parameters: signUpParameters())
                guard case .error(let error) = response.result else { return XCTFail("Expected unsupported challenge error") }
                XCTAssertEqual(error.type, .generalError)
            }
        }
        XCTAssertFalse(requestProviderMock.tokenCalled)
        XCTAssertFalse(requestProviderMock.submitPasswordCalled)
    }

    func test_existingAccountChallenge_choosesFirstSupportedMethodInServerOrder() async throws {
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-start", href: "https://contoso.com/signup")
        ]
        parserMock.interactionResponses = [
            .challengeRequired(continuationToken: "ct-existing", methods: [
                .init(id: "sms", channelType: .sms, hint: nil, challengeHref: "https://contoso.com/sms"),
                .init(id: "password", channelType: .password, hint: nil, challengeHref: "https://contoso.com/password"),
                .init(id: "email", channelType: .email, hint: nil, challengeHref: "https://contoso.com/email")
            ]),
            existingAccountVerification(channel: "password")
        ]
        let response = await sut.signUp(parameters: signUpParameters())
        guard case .actionRequired(let state) = response.result else { return XCTFail("Expected password collection") }
        XCTAssertTrue(state is MSALNativeAuthExistingAccountPasswordRequiredState)
        XCTAssertEqual(requestProviderMock.challengeHrefReceived, "https://contoso.com/password")
        XCTAssertEqual(requestProviderMock.challengeCallCount, 1)
    }

    func test_existingAccountChallenge_propagatesBrowserAndServerErrorsAsSignIn() async {
        let serverError = MSALNativeAuthFlowError(type: .generalError, correlationId: UUID())
        for result: MSALNativeAuthV2InteractionParsedResponse in [.browserRequired, .error(serverError)] {
            parserMock.authorizeChallengeResponses.append(
                .continuationToken(continuationToken: "ct-start", href: "https://contoso.com/signup")
            )
            parserMock.interactionResponses += [existingAccountChallenge(.email), result]
            let response = await sut.signUp(parameters: signUpParameters())
            XCTAssertEqual(response.scenario, .signIn)
            switch (result, response.result) {
            case (.browserRequired, .browserRequired): break
            case (.error, .error(let error)): XCTAssertTrue(error === serverError)
            default: XCTFail("Expected the challenge failure to propagate")
            }
        }
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_normalEnrollment_afterSignUpSubmissionsKeepsSignUpScenario() async throws {
        for operation in ["code", "password", "attributes"] {
            parserMock.interactionResponses += [
                .registrationRequired(continuationToken: "ct-enroll", methods: [
                    .init(id: "email", enrollHref: "https://contoso.com/enroll", channelType: .email)
                ])
            ]
            let state = makeSignUpState(
                links: [
                    .verify: try XCTUnwrap(URL(string: "https://contoso.com/signup/verify")),
                    .submitAttributes: try XCTUnwrap(URL(string: "https://contoso.com/signup/attributes"))
                ],
                submittedAttributes: ["city"]
            )
            let response: MSALNativeAuthFlowControllerResponse
            switch operation {
            case "code": response = await sut.submitCode("123456", state: state)
            case "password": response = await sut.submitPassword("proposed-password", state: state)
            default: response = await sut.submitAttributes(["displayName": "Test"], state: state)
            }
            guard case .actionRequired(let next) = response.result else { return XCTFail("Expected enrollment") }
            XCTAssertTrue(next is MSALNativeAuthStrongAuthRegistrationRequiredState)
            XCTAssertEqual(next.internalState.continuation.flowScenario, .signUp)
            XCTAssertTrue(next.internalState.continuation.hasSubmittedAttribute("city"))
            XCTAssertTrue(next.internalState.continuation.pendingSignUpAttributes.isEmpty)
        }
    }

    func test_signUp_upfrontValuesSubmitted_preservesInitialScopesThroughCompletion() async throws {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signup")
        ]
        parserMock.interactionResponses = [
            .attributesRequired(
                continuationToken: "ct-2",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [passwordAttribute()]
            ),
            .verificationRequired(
                continuationToken: "ct-3",
                verifyHref: "https://contoso.com/signup/verify",
                resendHref: "https://contoso.com/signup/resend",
                sentTo: "user@contoso.com",
                channelType: MSALNativeAuthChannelType(value: "email"),
                codeLength: 8
            )
        ]

        let parameters = signUpParameters(password: "password", attributes: ["city": "Seattle"])
        let claims = "{\"access_token\":{\"acrs\":{\"essential\":true,\"value\":\"c1\"}}}"
        parameters.claimsRequest = try XCTUnwrap(MSALClaimsRequest(jsonString: claims, error: nil))
        let expectedClaims = try XCTUnwrap(parameters.claimsRequest?.jsonString())
        let response = await sut.signUp(parameters: parameters)

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        XCTAssertTrue(state is MSALNativeAuthCodeRequiredState)
        XCTAssertTrue(requestProviderMock.authorizeChallengeStartCalled)
        XCTAssertEqual(requestProviderMock.authorizeChallengeStartScopes, ["scope1", "openid", "profile", "offline_access"])
        XCTAssertEqual(requestProviderMock.authorizeChallengeStartClaimsRequestJson, expectedClaims)
        XCTAssertTrue(requestProviderMock.signUpStartCalled)
        XCTAssertTrue(requestProviderMock.submitAttributesCalled)
        XCTAssertEqual(requestProviderMock.signUpStartUsername, username)
        XCTAssertNil(requestProviderMock.submitAttributesReceived?["email"])
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["password"] as? String, "password")
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["city"] as? String, "Seattle")
        let expectedScopes = ["scope1", "openid", "profile", "offline_access"]
        XCTAssertEqual(state.internalState.continuation.scopes, expectedScopes)

        parameters.scopes = ["changed-after-start"]
        parserMock.interactionResponses.append(.readyToComplete(continuationToken: "ct-complete"))
        parserMock.authorizeChallengeResponses.append(.authorizationCode(code: "auth-code"))
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()

        let verification = await sut.submitCode("12345678", state: state.internalState)
        guard case .actionRequired(let nextState) = verification.result,
              let signInState = nextState as? MSALNativeAuthSignInAfterSignUpState else {
            return XCTFail("Expected signInAfterSignUp, got \(verification.result)")
        }
        XCTAssertEqual(signInState.internalState.continuation.scopes, expectedScopes)

        let completion = await sut.signInAfterSignUp(state: signInState.internalState)
        guard case .completed(let accountResult) = completion.result else {
            return XCTFail("Expected completed, got \(completion.result)")
        }
        XCTAssertEqual(resultFactoryMock.makeMSIDConfigurationScopes, expectedScopes)
        XCTAssertTrue(cacheAccessorMock.validateAndSaveTokensWasCalled)
        XCTAssertEqual(requestProviderMock.tokenScopes, [])
        XCTAssertNil(requestProviderMock.tokenClaimsRequestJson)
        XCTAssertFalse(cacheAccessorMock.clearCacheWasCalled)
        accountResult.signOut()
        XCTAssertTrue(cacheAccessorMock.clearCacheWasCalled)
    }

    func test_signUp_upfrontAttributesSubmitted_returnsJITRegistration() async throws {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signup")
        ]
        parserMock.interactionResponses = [
            .attributesRequired(
                continuationToken: "ct-attributes",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [passwordAttribute()]
            ),
            .registrationRequired(
                continuationToken: "ct-enroll",
                methods: [
                    MSALNativeAuthV2EnrollmentMethod(id: "phone:sms:0", enrollHref: "https://contoso.com/phone", channelType: .sms)
                ]
            )
        ]
        let parameters = signUpParameters(password: "password", attributes: ["city": "Seattle"])
        parameters.correlationId = UUID()

        let response = await sut.signUp(parameters: parameters)

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected JIT registration, got \(response.result)")
        }
        let registration = try XCTUnwrap(state as? MSALNativeAuthStrongAuthRegistrationRequiredState)
        XCTAssertEqual(requestProviderMock.signUpStartUsername, username)
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["password"] as? String, "password")
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["city"] as? String, "Seattle")
        XCTAssertNil(requestProviderMock.submitAttributesReceived?["email"])
        XCTAssertEqual(registration.internalState.continuation.flowScenario, .signUp)
        XCTAssertEqual(response.correlationId, parameters.correlationId)
        XCTAssertEqual(registration.authMethods.map(\.id), ["phone:sms:0"])
        XCTAssertEqual(registration.internalState.continuation.continuationToken, "ct-enroll")
        XCTAssertTrue(registration.internalState.continuation.hasSubmittedAttribute("password"))
        XCTAssertTrue(registration.internalState.continuation.hasSubmittedAttribute("city"))
        XCTAssertTrue(registration.internalState.continuation.pendingSignUpAttributes.isEmpty)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_signUp_upfrontAttributesSubmit_isAttributedToSignUpStartApiId() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signup")
        ]
        parserMock.interactionResponses = [
            .attributesRequired(
                continuationToken: "ct-2",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [passwordAttribute()]
            ),
            .verificationRequired(
                continuationToken: "ct-3",
                verifyHref: "https://contoso.com/signup/verify",
                resendHref: "https://contoso.com/signup/resend",
                sentTo: "user@contoso.com",
                channelType: MSALNativeAuthChannelType(value: "email"),
                codeLength: 8
            )
        ]

        _ = await sut.signUp(parameters: signUpParameters(password: "password", attributes: ["city": "Seattle"]))

        // One public call = one API id: every network request made while servicing signUp() start - including
        // the upfront submitAttributes - is reported under the sign-up start API id.
        XCTAssertTrue(requestProviderMock.submitAttributesCalled)
        XCTAssertEqual(requestProviderMock.submitAttributesApiIdReceived, .telemetryApiIdV2SignUpStart)
    }

    func test_signUp_appSuppliedReservedAttributes_areIgnored_soSDKValuesWin() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signup")
        ]
        parserMock.interactionResponses = [
            .attributesRequired(
                continuationToken: "ct-2",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [passwordAttribute()]
            ),
            .verificationRequired(
                continuationToken: "ct-3",
                verifyHref: "https://contoso.com/signup/verify",
                resendHref: "https://contoso.com/signup/resend",
                sentTo: "user@contoso.com",
                channelType: MSALNativeAuthChannelType(value: "email"),
                codeLength: 8
            )
        ]

        // App tries to override the SDK-owned username/password via attributes, using different casing.
        let response = await sut.signUp(parameters: signUpParameters(
            password: "password",
            attributes: ["Email": "attacker@contoso.com", "PASSWORD": "attackerPassword", "city": "Seattle"]
        ))

        guard case .actionRequired = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        XCTAssertTrue(requestProviderMock.submitAttributesCalled)
        XCTAssertEqual(requestProviderMock.signUpStartUsername, username)
        XCTAssertNil(requestProviderMock.submitAttributesReceived?["email"])
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["password"] as? String, "password")
        XCTAssertNil(requestProviderMock.submitAttributesReceived?["Email"])
        XCTAssertNil(requestProviderMock.submitAttributesReceived?["PASSWORD"])
        // Non-reserved attributes are still submitted.
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["city"] as? String, "Seattle")
    }

    func test_signUp_serverRequestsNewAttributeAfterUpfront_returnsAttributesRequired() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signup")
        ]
        parserMock.interactionResponses = [
            .attributesRequired(
                continuationToken: "ct-2",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [passwordAttribute()]
            ),
            .attributesRequired(
                continuationToken: "ct-3",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [MSALNativeAuthRequiredAttributeInternal(name: "city", type: "text", required: true)]
            )
        ]

        let response = await sut.signUp(parameters: signUpParameters(password: "password"))

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        XCTAssertTrue(state is MSALNativeAuthAttributesRequiredState)
        // The up-front dump was submitted; the newly requested attribute is surfaced to the app.
        XCTAssertTrue(requestProviderMock.submitAttributesCalled)
    }

    func test_signUp_serverReRequestsAlreadySubmittedAttribute_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signup")
        ]
        parserMock.interactionResponses = [
            .attributesRequired(
                continuationToken: "ct-2",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [MSALNativeAuthRequiredAttributeInternal(name: "city", type: "text", required: true)]
            ),
            .attributesRequired(
                continuationToken: "ct-3",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [MSALNativeAuthRequiredAttributeInternal(name: "city", type: "text", required: true)]
            )
        ]

        let response = await sut.signUp(parameters: signUpParameters(attributes: ["city": "Seattle"]))

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
    }

    func test_signUp_whenUserAlreadyExists_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signup")
        ]
        parserMock.interactionResponses = [
            .error(MSALNativeAuthFlowError(type: .userAlreadyExists))
        ]

        let response = await sut.signUp(parameters: signUpParameters(password: "password"))

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
    }

    func test_signUp_whenServerRequestsEmailWithPassword_returnsGeneralErrorWithoutSubmittingAttributes() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-start", href: "https://contoso.com/signup")
        ]
        parserMock.interactionResponses = [
            .attributesRequired(
                continuationToken: "ct-attributes",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [
                    passwordAttribute(),
                    MSALNativeAuthRequiredAttributeInternal(name: "Email", type: "text", required: true)
                ]
            )
        ]

        let response = await sut.signUp(parameters: signUpParameters(password: "password", attributes: ["city": "Seattle"]))

        guard case .error(let error) = response.result else {
            return XCTFail("Expected general error, got \(response.result)")
        }
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(requestProviderMock.signUpStartUsername, username)
        XCTAssertFalse(requestProviderMock.submitAttributesCalled)
    }

    func test_signUp_withoutUpfrontAttributes_returnsPasswordRequiredWithoutEmptySubmission() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-start", href: "https://contoso.com/signup")
        ]
        parserMock.interactionResponses = [
            .attributesRequired(
                continuationToken: "ct-attributes",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [passwordAttribute()]
            )
        ]

        let response = await sut.signUp(parameters: signUpParameters())

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        XCTAssertTrue(state is MSALNativeAuthPasswordRequiredState)
        XCTAssertEqual(requestProviderMock.signUpStartUsername, username)
        XCTAssertFalse(requestProviderMock.submitAttributesCalled)
    }

    func test_signUp_withoutUpfrontAttributes_returnsProfileAttributesRequired() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-start", href: "https://contoso.com/signup")
        ]
        parserMock.interactionResponses = [
            .attributesRequired(
                continuationToken: "ct-attributes",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [MSALNativeAuthRequiredAttributeInternal(name: "city", type: "text", required: true)]
            )
        ]

        let response = await sut.signUp(parameters: signUpParameters())

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        XCTAssertTrue(state is MSALNativeAuthAttributesRequiredState)
        XCTAssertFalse(requestProviderMock.submitAttributesCalled)
    }

    func test_signUp_whenServerRequestsEmailAfterAttributeSubmission_returnsGeneralError() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-start", href: "https://contoso.com/signup")
        ]
        parserMock.interactionResponses = [
            .attributesRequired(
                continuationToken: "ct-attributes",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [passwordAttribute()]
            ),
            .attributesRequired(
                continuationToken: "ct-email",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [MSALNativeAuthRequiredAttributeInternal(name: "email", type: "text", required: true)]
            )
        ]

        let response = await sut.signUp(parameters: signUpParameters(password: "password"))

        guard case .error(let error) = response.result else {
            return XCTFail("Expected general error, got \(response.result)")
        }
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["password"] as? String, "password")
        XCTAssertNil(requestProviderMock.submitAttributesReceived?["email"])
    }

    func test_signUp_verificationAndResendBeforeAttributes_preservesUpfrontValuesUntilSubmitted() async throws {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-start", href: "https://contoso.com/signup")
        ]
        let verification: MSALNativeAuthV2InteractionParsedResponse = .verificationRequired(
            continuationToken: "ct-code",
            verifyHref: "https://contoso.com/signup/verify",
            resendHref: "https://contoso.com/signup/resend",
            sentTo: username,
            channelType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 8
        )
        parserMock.interactionResponses = [
            verification,
            verification,
            .attributesRequired(
                continuationToken: "ct-attributes",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [passwordAttribute()]
            ),
            .readyToComplete(continuationToken: "ct-complete")
        ]
        let parameters = signUpParameters(password: "password", attributes: ["city": "Seattle"])
        let start = await sut.signUp(parameters: parameters)
        guard case .actionRequired(let initialState) = start.result else {
            return XCTFail("Expected verification, got \(start.result)")
        }
        let codeState = try XCTUnwrap(initialState as? MSALNativeAuthCodeRequiredState)
        XCTAssertEqual(requestProviderMock.signUpStartUsername, username)
        XCTAssertFalse(requestProviderMock.submitAttributesCalled)
        parameters.password = "changed-password"
        parameters.attributes = ["city": "changed-city"]

        let resend = await sut.resendCode(state: codeState.internalState)
        guard case .actionRequired(let resentState) = resend.result else {
            return XCTFail("Expected verification, got \(resend.result)")
        }
        let resentCodeState = try XCTUnwrap(resentState as? MSALNativeAuthCodeRequiredState)
        let verified = await sut.submitCode("12345678", state: resentCodeState.internalState)
        guard case .actionRequired(let finalState) = verified.result else {
            return XCTFail("Expected sign-in after sign-up, got \(verified.result)")
        }
        let completed = try XCTUnwrap(finalState as? MSALNativeAuthSignInAfterSignUpState)
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["password"] as? String, "password")
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["city"] as? String, "Seattle")
        XCTAssertNil(requestProviderMock.submitAttributesReceived?["email"])
        XCTAssertEqual(requestProviderMock.submitAttributesApiIdReceived, .telemetryApiIdV2SignUpSubmitCode)
        XCTAssertTrue(completed.internalState.continuation.pendingSignUpAttributes.isEmpty)
        XCTAssertFalse(completed.internalState.continuation.hasSubmittedAttribute("email"))
        XCTAssertTrue(completed.internalState.continuation.hasSubmittedAttribute("password"))
    }

    func test_signUp_whenCompleteWithoutAttributeCollection_dropsPendingValues() async throws {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-start", href: "https://contoso.com/signup")
        ]
        parserMock.interactionResponses = [.readyToComplete(continuationToken: "ct-complete")]

        let response = await sut.signUp(parameters: signUpParameters(password: "password", attributes: ["city": "Seattle"]))

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected sign-in after sign-up, got \(response.result)")
        }
        let completed = try XCTUnwrap(state as? MSALNativeAuthSignInAfterSignUpState)
        XCTAssertTrue(completed.internalState.continuation.pendingSignUpAttributes.isEmpty)
        XCTAssertTrue(completed.internalState.continuation.submittedAttributes.isEmpty)
        XCTAssertFalse(requestProviderMock.submitAttributesCalled)
    }

    // MARK: - submitCode

    func test_submitCode_whenServerRequestsEmailWithUnsubmittedPassword_returnsGeneralError() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .attributesRequired(
                continuationToken: "ct-attributes",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [
                    passwordAttribute(),
                    MSALNativeAuthRequiredAttributeInternal(name: "EMAIL", type: "text", required: true)
                ]
            )
        ]
        let state = makeSignUpState(links: [.verify: URL(string: "https://contoso.com/signup/verify")!])

        let response = await sut.submitCode("12345678", state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected general error, got \(response.result)")
        }
        XCTAssertEqual(error.type, .generalError)
        XCTAssertFalse(requestProviderMock.submitAttributesCalled)
    }

    func test_submitCode_returnsSignInAfterSignUp() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .readyToComplete(continuationToken: "ct-continue")
        ]

        let state = makeSignUpState(
            links: [.verify: URL(string: "https://contoso.com/signup/verify")!]
        )
        let response = await sut.submitCode("12345678", state: state)

        guard case .actionRequired(let resultState) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        XCTAssertTrue(resultState is MSALNativeAuthSignInAfterSignUpState)
        XCTAssertTrue(requestProviderMock.verifyCalled)
    }

    func test_submitCode_whenServerReRequestsAlreadySubmittedPassword_returnsError() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .attributesRequired(
                continuationToken: "ct-pwd",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [passwordAttribute()]
            )
        ]

        let state = makeSignUpState(
            links: [.verify: URL(string: "https://contoso.com/signup/verify")!],
            submittedAttributes: ["password"]
        )
        let response = await sut.submitCode("12345678", state: state)

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertFalse(requestProviderMock.submitAttributesCalled)
    }

    func test_submitCode_whenServerRequestsUnsubmittedPassword_returnsPasswordRequired() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .attributesRequired(
                continuationToken: "ct-pwd",
                submitHref: "https://contoso.com/signup/attributes",
                attributes: [passwordAttribute()]
            )
        ]

        let state = makeSignUpState(
            links: [.verify: URL(string: "https://contoso.com/signup/verify")!]
        )
        let response = await sut.submitCode("12345678", state: state)

        guard case .actionRequired(let resultState) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        XCTAssertTrue(resultState is MSALNativeAuthPasswordRequiredState)
        XCTAssertFalse(requestProviderMock.submitAttributesCalled)
    }

    // MARK: - submitPassword

    func test_submitPassword_signUp_submitsAttributesAndReturnsSignInAfterSignUp() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .readyToComplete(continuationToken: "ct-continue")
        ]

        let state = makeSignUpState(
            links: [.submitAttributes: URL(string: "https://contoso.com/signup/attributes")!]
        )
        let response = await sut.submitPassword("password", state: state)

        guard case .actionRequired(let resultState) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        XCTAssertTrue(resultState is MSALNativeAuthSignInAfterSignUpState)
        XCTAssertTrue(requestProviderMock.submitAttributesCalled)
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["password"] as? String, "password")
    }

    // MARK: - submitAttributes

    func test_submitAttributes_whenAppSuppliesEmail_returnsGeneralErrorWithoutSendingEmail() async {
        let state = makeSignUpState(links: [.submitAttributes: URL(string: "https://contoso.com/signup/attributes")!])

        let response = await sut.submitAttributes(["Email": username, "city": "Seattle"], state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected general error, got \(response.result)")
        }
        XCTAssertEqual(error.type, .generalError)
        XCTAssertFalse(requestProviderMock.submitAttributesCalled)
    }

    func test_submitAttributes_signUp_returnsSignInAfterSignUp() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .readyToComplete(continuationToken: "ct-continue")
        ]

        let state = makeSignUpState(
            links: [.submitAttributes: URL(string: "https://contoso.com/signup/attributes")!]
        )
        let response = await sut.submitAttributes(["city": "Seattle"], state: state)

        guard case .actionRequired(let resultState) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        XCTAssertTrue(resultState is MSALNativeAuthSignInAfterSignUpState)
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["city"] as? String, "Seattle")
    }

    // MARK: - resendCode

    func test_resendCode_signUp_returnsCodeRequired() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .verificationRequired(
                continuationToken: "ct-3",
                verifyHref: "https://contoso.com/signup/verify",
                resendHref: "https://contoso.com/signup/resend",
                sentTo: "user@contoso.com",
                channelType: MSALNativeAuthChannelType(value: "email"),
                codeLength: 8
            )
        ]

        let state = makeSignUpState(
            links: [.resend: URL(string: "https://contoso.com/signup/resend")!]
        )
        let response = await sut.resendCode(state: state)

        guard case .actionRequired(let resultState) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        XCTAssertTrue(resultState is MSALNativeAuthCodeRequiredState)
        XCTAssertTrue(requestProviderMock.challengeCalled)
    }

    // MARK: - signInAfterSignUp

    func test_signInAfterSignUp_completesWithoutResendingScopesOrClaims() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .authorizationCode(code: "auth-code")
        ]
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()

        let state = makeSignUpState(continuationToken: "ct-continue", claimsRequestJson: "{\"access_token\":{}}")
        let response = await sut.signInAfterSignUp(state: state)

        guard case .completed = response.result else {
            return XCTFail("Expected completed, got \(response.result)")
        }
        XCTAssertTrue(requestProviderMock.tokenCalled)
        XCTAssertEqual(requestProviderMock.authorizeChallengeContinueToken, "ct-continue")
        XCTAssertEqual(requestProviderMock.tokenCode, "auth-code")
        XCTAssertEqual(requestProviderMock.tokenScopes, [])
        XCTAssertNil(requestProviderMock.tokenClaimsRequestJson)
        XCTAssertFalse(requestProviderMock.authorizeChallengeStartCalled)
        XCTAssertEqual(resultFactoryMock.makeMSIDConfigurationScopes, ["scope1"])
    }

    func test_signInAfterSignUp_whenMissingContinuationToken_returnsError() async {
        requestProviderMock.mockRequest()
        let state = makeSignUpState(continuationToken: "")
        // Build a continuation with a nil continuation token explicitly.
        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: .signUp,
            correlationId: UUID(),
            continuationToken: nil,
            links: [:]
        )
        let nilState = MSALNativeAuthFlowInternalState(continuation: continuation, controller: sut)
        _ = state
        let response = await sut.signInAfterSignUp(state: nilState)

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertFalse(requestProviderMock.authorizeChallengeContinueCalled)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }
}
// swiftlint:enable type_body_length file_length
