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

    private func jitRegistration(includeEmail: Bool = false) -> MSALNativeAuthV2InteractionParsedResponse {
        var methods = [MSALNativeAuthV2EnrollmentMethod(
            id: "phone:sms:0",
            enrollHref: "https://contoso.com/phone?dc=test",
            channelType: .sms
        )]
        if includeEmail {
            methods.append(MSALNativeAuthV2EnrollmentMethod(
                id: "email:email:1",
                enrollHref: "https://contoso.com/email?dc=test",
                channelType: .email
            ))
        }
        return .registrationRequired(continuationToken: "ct-enroll", methods: methods)
    }

    private func jitActivation() -> MSALNativeAuthV2InteractionParsedResponse {
        .activationRequired(
            continuationToken: "ct-activate",
            activateHref: "https://contoso.com/phone/id/activate?dc=test",
            sentTo: "+1******0100",
            codeLength: 6
        )
    }

    private func jitRegistrationState(includeEmail: Bool = false) -> MSALNativeAuthFlowInternalState {
        var links: [MSALNativeAuthV2LinkKey: URL] = [
            .method(id: "phone:sms:0"): URL(string: "https://contoso.com/phone?dc=test")!
        ]
        if includeEmail {
            links[.method(id: "email:email:1")] = URL(string: "https://contoso.com/email?dc=test")!
        }
        return MSALNativeAuthFlowInternalState(
            continuation: MSALNativeAuthFlowContinuationState(
                flowScenario: .signIn,
                correlationId: UUID(),
                continuationToken: "ct-enroll",
                links: links,
                scopes: ["scope1"],
                claimsRequestJson: "{\"id_token\":{}}",
                challengeResponse: jitRegistration(includeEmail: includeEmail)
            ),
            controller: sut
        )
    }

    private func jitMethod(id: String = "phone:sms:0") -> MSALAuthMethod {
        MSALAuthMethod(id: id, challengeType: "sms", channelTargetType: MSALNativeAuthChannelType(value: "sms"), loginHint: nil)
    }

    // MARK: - JIT enrollment

    // swiftlint:disable:next function_body_length
    func test_signInWithPassword_withoutCapabilities_enrollActivateAndComplete_preservesContinuationContext() async throws {
        XCTAssertNil(MSALNativeAuthConfigStubs.configuration.capabilities)
        prepareSignInStart(methods: [primaryMethods()[0]])
        parserMock.interactionResponses += [
            passwordVerificationRequired(), jitRegistration(), jitActivation(), .readyToComplete(continuationToken: "ct-done")
        ]
        parserMock.authorizeChallengeResponses.append(.authorizationCode(code: "authorization-code"))
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()

        let parameters = signInParameters(password: "test-password")
        parameters.correlationId = UUID()
        let response = await sut.signIn(parameters: parameters)
        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected registration state")
        }
        let registration = try XCTUnwrap(state as? MSALNativeAuthStrongAuthRegistrationRequiredState)
        XCTAssertEqual(registration.authMethods.count, 1)
        XCTAssertEqual(registration.internalState.continuation.continuationToken, "ct-enroll")
        XCTAssertEqual(registration.internalState.continuation.correlationId, parameters.correlationId)
        XCTAssertNil(requestProviderMock.enrollHrefReceived)
        XCTAssertFalse(requestProviderMock.tokenCalled)

        let enrolled = await sut.selectAuthMethod(
            try XCTUnwrap(registration.authMethods.first),
            verificationContact: "+15555550100",
            state: registration.internalState
        )
        guard case .actionRequired(let enrolledState) = enrolled.result else {
            return XCTFail("Expected activation state")
        }
        let activation = try XCTUnwrap(enrolledState as? MSALNativeAuthStrongAuthVerificationRequiredState)
        XCTAssertEqual(activation.sentTo, "+1******0100")
        XCTAssertEqual(activation.codeLength, 6)
        XCTAssertTrue(activation.channel.isSMSType)
        XCTAssertEqual(activation.internalState.continuation.continuationToken, "ct-activate")
        XCTAssertEqual(activation.internalState.continuation.scopes, registration.internalState.continuation.scopes)
        XCTAssertEqual(requestProviderMock.enrollHrefReceived, "https://contoso.com/phone?dc=test")
        XCTAssertEqual(requestProviderMock.enrollVerificationContactReceived, "+15555550100")
        XCTAssertEqual(requestProviderMock.enrollChannelTypeReceived, .sms)
        XCTAssertEqual(requestProviderMock.enrollTokenReceived, "ct-enroll")
        XCTAssertEqual(requestProviderMock.enrollApiIdReceived, .telemetryApiIdV2JITChallenge)

        let completed = await sut.submitChallenge("123456", state: activation.internalState)
        guard case .completed(let accountResult) = completed.result else {
            return XCTFail("Expected completed sign-in")
        }
        XCTAssertEqual(completed.scenario, .signIn)
        XCTAssertEqual(completed.correlationId, parameters.correlationId)
        XCTAssertEqual(requestProviderMock.activateHrefReceived, "https://contoso.com/phone/id/activate?dc=test")
        XCTAssertEqual(requestProviderMock.activateCodeReceived, "123456")
        XCTAssertEqual(requestProviderMock.activateTokenReceived, "ct-activate")
        XCTAssertEqual(requestProviderMock.activateApiIdReceived, .telemetryApiIdV2JITChallenge)
        XCTAssertEqual(requestProviderMock.authorizeChallengeContinueToken, "ct-done")
        XCTAssertEqual(requestProviderMock.tokenScopes, registration.internalState.continuation.scopes)
        XCTAssertFalse(requestProviderMock.verifyCalled)
        XCTAssertFalse(requestProviderMock.requests.isEmpty)
        XCTAssertTrue(requestProviderMock.requests.allSatisfy { $0.sendCallCount == 1 })
        XCTAssertTrue(cacheAccessorMock.validateAndSaveTokensWasCalled)
        XCTAssertFalse(cacheAccessorMock.clearCacheWasCalled)
        accountResult.signOut()
        XCTAssertTrue(cacheAccessorMock.clearCacheWasCalled)
    }

    func test_resultFactory_accountResult_reusesInjectedCacheAccessor() throws {
        let account = resultFactoryMock.makeAccount(
            tokenResult: MSIDTokenResult(),
            context: MSALNativeAuthRequestContextMock()
        )
        let result = try XCTUnwrap(resultFactoryMock.makeUserAccountResult(account: account, rawIdToken: nil))

        XCTAssertFalse(cacheAccessorMock.clearCacheWasCalled)
        result.signOut()
        XCTAssertTrue(cacheAccessorMock.clearCacheWasCalled)
    }

    func test_performRequest_instanceFake_propagatesTransportError() async throws {
        let context = MSALNativeAuthRequestContextMock()
        let expectedError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        requestProviderMock.responseError = expectedError
        let request = try requestProviderMock.enroll(
            href: "https://contoso.com/email",
            verificationContact: "test@example.com",
            channelType: .email,
            continuationToken: "ct-enroll",
            apiId: .telemetryApiIdV2JITChallenge,
            context: context
        )

        let result: Result<MSALNativeAuthHALResponse, Error> = await sut.performRequest(request, context: context)
        guard case .failure(let error) = result else {
            return XCTFail("Expected transport failure")
        }
        XCTAssertTrue(error as NSError === expectedError)
        XCTAssertEqual(requestProviderMock.requests.count, 1)
        XCTAssertEqual(requestProviderMock.requests.first?.sendCallCount, 1)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_performTokenRequest_instanceFake_parsesTokensAndPreservesRequestCorrelationId() async throws {
        let requestContext = MSALNativeAuthRequestContextMock(correlationId: UUID())
        let request = try requestProviderMock.token(
            code: "authorization-code",
            scopes: ["scope"],
            claimsRequestJson: nil,
            apiId: .telemetryApiIdV2JITChallenge,
            context: requestContext
        )

        let result = await sut.performTokenRequest(
            request,
            requestCorrelationId: requestContext.correlationId().uuidString,
            context: MSALNativeAuthRequestContextMock()
        )
        guard case .success(let response) = result else {
            return XCTFail("Expected parsed token response")
        }
        XCTAssertEqual(response.accessToken, "access-token")
        XCTAssertEqual(response.correlationId, requestContext.correlationId().uuidString)
        XCTAssertEqual(requestProviderMock.requests.count, 1)
        XCTAssertEqual(requestProviderMock.requests.first?.sendCallCount, 1)
    }

    func test_performTokenRequest_withoutRequestCorrelationId_doesNotUseLoggingContext() async throws {
        let context = MSALNativeAuthRequestContextMock()
        let request = try MSALNativeAuthV2HTTPRequestMock(
            responseJSON: MSALNativeAuthV2RequestProviderMock.successfulTokenResponseJson,
            expectsRawJSONResponse: true,
            context: context
        )

        let result = await sut.performTokenRequest(request, requestCorrelationId: nil, context: context)
        guard case .success(let response) = result else {
            return XCTFail("Expected parsed token response")
        }
        XCTAssertNil(response.correlationId)
        XCTAssertEqual(request.sendCallCount, 1)
    }

    func test_performTokenRequest_serverCorrelationId_takesPrecedenceOverRequestCorrelationId() async throws {
        let context = MSALNativeAuthRequestContextMock()
        let serverCorrelationId = UUID().uuidString
        var responseJSON = MSALNativeAuthV2RequestProviderMock.successfulTokenResponseJson
        responseJSON[MSID_OAUTH2_CORRELATION_ID_RESPONSE] = serverCorrelationId
        let request = try MSALNativeAuthV2HTTPRequestMock(
            responseJSON: responseJSON,
            expectsRawJSONResponse: true,
            context: context
        )

        let result = await sut.performTokenRequest(
            request,
            requestCorrelationId: context.correlationId().uuidString,
            context: context
        )
        guard case .success(let response) = result else {
            return XCTFail("Expected parsed token response")
        }
        XCTAssertEqual(response.correlationId, serverCorrelationId)
        XCTAssertEqual(request.sendCallCount, 1)
    }

    func test_submitCode_registrationRequired_surfacesJITStateAndPreservesClaims() async {
        parserMock.interactionResponses = [jitRegistration()]
        let state = makeSignInState(links: [.verify: URL(string: "https://contoso.com/verify")!], claimsRequestJson: "{\"id_token\":{}}")
        let response = await sut.submitCode("123456", state: state)
        guard case .actionRequired(let next) = response.result else {
            return XCTFail("Expected registration state")
        }
        XCTAssertTrue(next is MSALNativeAuthStrongAuthRegistrationRequiredState)
        XCTAssertEqual(next.internalState.continuation.claimsRequestJson, state.continuation.claimsRequestJson)
        XCTAssertEqual(next.internalState.continuation.scopes, state.continuation.scopes)
    }

    func test_submitPassword_withoutCapabilities_returnsRegistrationRequired() async throws {
        parserMock.interactionResponses = [jitRegistration()]
        let response = await sut.submitPassword(
            "test-password",
            state: makeSignInState(links: [.verify: URL(string: "https://contoso.com/verify")!])
        )
        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected server-driven registration without capabilities")
        }
        let registration = try XCTUnwrap(state as? MSALNativeAuthStrongAuthRegistrationRequiredState)
        XCTAssertEqual(registration.authMethods.map(\.id), ["phone:sms:0"])
        XCTAssertEqual(registration.internalState.continuation.continuationToken, "ct-enroll")
        XCTAssertNil(requestProviderMock.enrollHrefReceived)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_selectEnrollmentMethod_usesJITRequestAndDispatchesActivationResult() async throws {
        parserMock.interactionResponses = [jitActivation()]
        let response = await sut.selectAuthMethod(
            jitMethod(),
            verificationContact: "+15555550100",
            state: jitRegistrationState()
        )
        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected activation state")
        }
        let activation = try XCTUnwrap(state as? MSALNativeAuthStrongAuthVerificationRequiredState)
        XCTAssertTrue(activation.channel.isSMSType)
        XCTAssertEqual(activation.internalState.continuation.continuationToken, "ct-activate")
        XCTAssertEqual(requestProviderMock.enrollApiIdReceived, .telemetryApiIdV2JITChallenge)
        XCTAssertEqual(requestProviderMock.enrollHrefReceived, "https://contoso.com/phone?dc=test")
        XCTAssertEqual(requestProviderMock.enrollVerificationContactReceived, "+15555550100")
        XCTAssertEqual(parserMock.parseInteractionCallCount, 1)
        XCTAssertFalse(requestProviderMock.challengeCalled)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_flowEntry_registrationResponse_doesNotBypassPrimaryChallenge() async {
        for scenario: MSALNativeAuthFlowScenario in [.signIn, .passwordReset] {
            parserMock.authorizeChallengeResponses.append(
                .continuationToken(continuationToken: "ct-start", href: "https://contoso.com/start")
            )
            parserMock.interactionResponses.append(jitRegistration(includeEmail: true))
            let response: MSALNativeAuthFlowControllerResponse
            switch scenario {
            case .signIn:
                response = await sut.signIn(parameters: signInParameters(password: nil))
            case .passwordReset:
                response = await sut.resetPassword(parameters: MSALNativeAuthResetPasswordParameters(username: "test@example.com"))
            default:
                return XCTFail("Unexpected test scenario")
            }
            guard case .error = response.result else {
                return XCTFail("Expected the start response to require a primary challenge")
            }
            XCTAssertEqual(response.scenario, scenario)
            XCTAssertFalse(requestProviderMock.challengeCalled)
            XCTAssertNil(requestProviderMock.enrollHrefReceived)
            XCTAssertNil(requestProviderMock.activateHrefReceived)
        }
    }

    // swiftlint:disable:next function_body_length
    func test_submitPassword_registrationCompletesBeforeMFASelection() async throws {
        let mfaMethod = MSALNativeAuthV2ChallengeMethod(
            id: "sms-mfa",
            channelType: .sms,
            hint: "+1******0100",
            challengeHref: "https://contoso.com/mfa/challenge"
        )
        parserMock.interactionResponses = [
            jitRegistration(),
            jitActivation(),
            .mfaRequired(continuationToken: "ct-mfa", methods: [mfaMethod]),
            .verificationRequired(
                continuationToken: "ct-mfa-verify",
                verifyHref: "https://contoso.com/mfa/verify",
                resendHref: nil,
                sentTo: "+1******0100",
                channelType: MSALNativeAuthChannelType(value: "sms"),
                codeLength: 6
            )
        ]
        let state = makeSignInState(
            links: [.verify: URL(string: "https://contoso.com/password/verify")!],
            claimsRequestJson: "{\"id_token\":{}}"
        )

        let verified = await sut.submitPassword("test-password", state: state)
        guard case .actionRequired(let registrationState) = verified.result else {
            return XCTFail("Expected registration after primary verification")
        }
        let registration = try XCTUnwrap(registrationState as? MSALNativeAuthStrongAuthRegistrationRequiredState)
        XCTAssertTrue(requestProviderMock.submitPasswordCalled)
        XCTAssertEqual(parserMock.parseInteractionCallCount, 1)
        XCTAssertNil(requestProviderMock.enrollHrefReceived)
        XCTAssertFalse(requestProviderMock.challengeCalled)

        let enrolled = await sut.selectAuthMethod(
            try XCTUnwrap(registration.authMethods.first),
            verificationContact: "+15555550100",
            state: registration.internalState
        )
        guard case .actionRequired(let activationState) = enrolled.result else {
            return XCTFail("Expected activation before MFA")
        }
        let activation = try XCTUnwrap(activationState as? MSALNativeAuthStrongAuthVerificationRequiredState)
        XCTAssertEqual(requestProviderMock.enrollTokenReceived, "ct-enroll")
        XCTAssertEqual(parserMock.parseInteractionCallCount, 2)
        XCTAssertNil(requestProviderMock.activateHrefReceived)
        XCTAssertFalse(requestProviderMock.challengeCalled)

        let activated = await sut.submitChallenge("123456", state: activation.internalState)
        guard case .actionRequired(let next) = activated.result else {
            return XCTFail("Expected MFA selection after activation")
        }
        let selection = try XCTUnwrap(next as? MSALNativeAuthAuthMethodSelectionRequiredState)
        XCTAssertEqual(selection.authMethods.map(\.id), ["sms-mfa"])
        XCTAssertEqual(selection.internalState.continuation.continuationToken, "ct-mfa")
        XCTAssertEqual(selection.internalState.continuation.scopes, state.continuation.scopes)
        XCTAssertEqual(selection.internalState.continuation.claimsRequestJson, state.continuation.claimsRequestJson)
        XCTAssertEqual(activated.correlationId, state.continuation.correlationId)
        XCTAssertEqual(selection.internalState.continuation.flowScenario, .signIn)
        XCTAssertEqual(requestProviderMock.activateTokenReceived, "ct-activate")
        XCTAssertEqual(parserMock.parseInteractionCallCount, 3)
        XCTAssertFalse(requestProviderMock.challengeCalled)
        XCTAssertFalse(requestProviderMock.tokenCalled)

        let challenged = await sut.selectAuthMethod(
            try XCTUnwrap(selection.authMethods.first),
            verificationContact: nil,
            state: selection.internalState
        )
        guard case .actionRequired(let mfaState) = challenged.result else {
            return XCTFail("Expected MFA verification after selecting the method")
        }
        XCTAssertTrue(mfaState is MSALNativeAuthMFAVerificationRequiredState)
        XCTAssertEqual(mfaState.internalState.continuation.continuationToken, "ct-mfa-verify")
        XCTAssertEqual(requestProviderMock.challengeCallCount, 1)
        XCTAssertEqual(requestProviderMock.challengeHrefReceived, mfaMethod.challengeHref)
        XCTAssertEqual(requestProviderMock.challengeApiIdReceived, .telemetryApiIdV2MFAGetAuthMethods)
        XCTAssertEqual(parserMock.parseInteractionCallCount, 4)
    }

    // swiftlint:disable:next function_body_length
    func test_registration_duringSignUpOrPasswordReset_preservesAndResumesOriginalFlow() async throws {
        for scenario: MSALNativeAuthFlowScenario in [.signUp, .passwordReset] {
            parserMock.interactionResponses += [
                jitRegistration(),
                jitActivation(),
                .readyToComplete(continuationToken: "ct-done")
            ]
            let state = MSALNativeAuthFlowInternalState(
                continuation: MSALNativeAuthFlowContinuationState(
                    flowScenario: scenario,
                    correlationId: UUID(),
                    continuationToken: "ct-verify",
                    links: [.relation(.verify): URL(string: "https://contoso.com/verify")!],
                    scopes: ["scope1"],
                    claimsRequestJson: "{\"id_token\":{}}",
                    submittedAttributes: scenario == .signUp ? ["password"] : [],
                    pendingSignUpAttributes: scenario == .signUp ? ["city": "Seattle"] : [:]
                ),
                controller: sut
            )
            let required = await sut.submitCode("123456", state: state)
            guard case .actionRequired(let registrationState) = required.result else {
                return XCTFail("Expected registration state")
            }
            let registration = try XCTUnwrap(registrationState as? MSALNativeAuthStrongAuthRegistrationRequiredState)
            XCTAssertEqual(registration.internalState.continuation.flowScenario, scenario)
            XCTAssertEqual(registration.internalState.continuation.submittedAttributes, state.continuation.submittedAttributes)
            XCTAssertEqual(
                registration.internalState.continuation.pendingSignUpAttributes as? [String: String],
                state.continuation.pendingSignUpAttributes as? [String: String]
            )

            let enrolled = await sut.selectAuthMethod(
                jitMethod(),
                verificationContact: "+15555550100",
                state: registration.internalState
            )
            guard case .actionRequired(let activationState) = enrolled.result else {
                return XCTFail("Expected activation state")
            }
            let activation = try XCTUnwrap(activationState as? MSALNativeAuthStrongAuthVerificationRequiredState)
            XCTAssertEqual(activation.internalState.continuation.flowScenario, scenario)
            XCTAssertEqual(activation.internalState.continuation.scopes, state.continuation.scopes)
            XCTAssertEqual(activation.internalState.continuation.claimsRequestJson, state.continuation.claimsRequestJson)
            XCTAssertEqual(activation.internalState.continuation.submittedAttributes, state.continuation.submittedAttributes)
            XCTAssertEqual(
                activation.internalState.continuation.pendingSignUpAttributes as? [String: String],
                state.continuation.pendingSignUpAttributes as? [String: String]
            )
            XCTAssertEqual(requestProviderMock.enrollApiIdReceived, .telemetryApiIdV2JITChallenge)

            let resumed = await sut.submitChallenge("123456", state: activation.internalState)
            guard case .actionRequired(let next) = resumed.result else {
                return XCTFail("Expected the original flow's sign-in continuation")
            }
            if scenario == .signUp {
                XCTAssertTrue(next is MSALNativeAuthSignInAfterSignUpState)
            } else {
                XCTAssertTrue(next is MSALNativeAuthSignInAfterResetPasswordState)
            }
            XCTAssertEqual(next.internalState.continuation.flowScenario, scenario)
            XCTAssertEqual(resumed.correlationId, state.continuation.correlationId)
            XCTAssertEqual(next.internalState.continuation.continuationToken, "ct-done")
            XCTAssertTrue(next.internalState.continuation.pendingSignUpAttributes.isEmpty)
            XCTAssertEqual(requestProviderMock.activateTokenReceived, "ct-activate")
            XCTAssertFalse(requestProviderMock.challengeCalled)
            XCTAssertFalse(requestProviderMock.tokenCalled)
        }
    }

    // swiftlint:disable:next function_body_length
    func test_submitNewPassword_whenPollRequiresRegistration_enrollsAndActivatesBeforeResumingReset() async throws {
        let methods = [
            (id: "phone:sms:0", type: "phone", contact: "+15555550100"),
            (id: "email:email:1", type: "email", contact: "test@example.com")
        ]
        for (index, method) in methods.enumerated() {
            let pollHref = "https://contoso.com/password/id/pollUpdate?dc=test"
            let activateHref = "https://contoso.com/\(method.type)/id/activate?dc=test"
            parserMock.interactionResponses += [
                .pollInProgress(continuationToken: "ct-poll", pollHref: pollHref),
                jitRegistration(includeEmail: true),
                .activationRequired(
                    continuationToken: "ct-activate",
                    activateHref: activateHref,
                    sentTo: method.contact,
                    codeLength: 6
                ),
                .readyToComplete(continuationToken: "ct-done")
            ]
            let state = MSALNativeAuthFlowInternalState(
                continuation: MSALNativeAuthFlowContinuationState(
                    flowScenario: .passwordReset,
                    correlationId: UUID(),
                    continuationToken: "ct-update",
                    links: [.relation(.update): URL(string: "https://contoso.com/password/id/update?dc=test")!],
                    scopes: ["scope1"],
                    claimsRequestJson: "{\"id_token\":{}}"
                ),
                controller: sut
            )

            let response = await sut.submitNewPassword("New-Password-1", state: state)

            guard case .actionRequired(let registrationState) = response.result else {
                return XCTFail("Expected registration after password-update polling")
            }
            let registration = try XCTUnwrap(registrationState as? MSALNativeAuthStrongAuthRegistrationRequiredState)
            XCTAssertEqual(registration.authMethods.map(\.id), methods.map { $0.id })
            XCTAssertEqual(registration.authMethods.map(\.channelTargetType.value), ["sms", "email"])
            XCTAssertEqual(registration.internalState.continuation.continuationToken, "ct-enroll")
            XCTAssertEqual(registration.internalState.continuation.flowScenario, .passwordReset)
            XCTAssertEqual(registration.internalState.continuation.correlationId, state.continuation.correlationId)
            XCTAssertEqual(registration.internalState.continuation.scopes, state.continuation.scopes)
            XCTAssertEqual(registration.internalState.continuation.claimsRequestJson, state.continuation.claimsRequestJson)
            XCTAssertEqual(requestProviderMock.pollHrefsReceived.last, pollHref)
            XCTAssertEqual(requestProviderMock.pollTokensReceived.last, "ct-poll")
            XCTAssertEqual(requestProviderMock.pollHrefsReceived.count, index + 1)
            let selected = try XCTUnwrap(registration.authMethods.first { $0.id == method.id })
            let enrolled = await sut.selectAuthMethod(
                selected,
                verificationContact: method.contact,
                state: registration.internalState
            )
            guard case .actionRequired(let activationState) = enrolled.result else {
                return XCTFail("Expected activation state")
            }
            let activation = try XCTUnwrap(activationState as? MSALNativeAuthStrongAuthVerificationRequiredState)
            XCTAssertEqual(activation.internalState.continuation.flowScenario, .passwordReset)
            XCTAssertEqual(activation.internalState.continuation.continuationToken, "ct-activate")
            XCTAssertEqual(activation.internalState.continuation.link(.activate)?.absoluteString, activateHref)
            XCTAssertEqual(activation.channel.value, selected.channelTargetType.value)
            XCTAssertEqual(requestProviderMock.enrollTokenReceived, "ct-enroll")
            XCTAssertEqual(requestProviderMock.enrollHrefReceived, "https://contoso.com/\(method.type)?dc=test")
            XCTAssertEqual(requestProviderMock.enrollVerificationContactReceived, method.contact)

            let resumed = await sut.submitChallenge("123456", state: activation.internalState)

            guard case .actionRequired(let next) = resumed.result else {
                return XCTFail("Expected sign-in-after-reset state")
            }
            let signInState = try XCTUnwrap(next as? MSALNativeAuthSignInAfterResetPasswordState)
            XCTAssertEqual(signInState.internalState.continuation.flowScenario, .passwordReset)
            XCTAssertEqual(signInState.internalState.continuation.continuationToken, "ct-done")
            XCTAssertEqual(resumed.correlationId, state.continuation.correlationId)
            XCTAssertEqual(requestProviderMock.activateTokenReceived, "ct-activate")
            XCTAssertEqual(requestProviderMock.activateHrefReceived, activateHref)
            XCTAssertEqual(requestProviderMock.pollHrefsReceived.count, index + 1)
            XCTAssertEqual(parserMock.parseInteractionCallCount, (index + 1) * 4)
            XCTAssertFalse(requestProviderMock.challengeCalled)
            XCTAssertFalse(requestProviderMock.tokenCalled)
        }
    }

    // swiftlint:disable:next function_body_length
    func test_submitNewPassword_whenPollRequiresMFA_verifiesSMSBeforeResumingReset() async throws {
        let challengeHref = "/tenant/api/v2.0/auth/methods/sms/sms-id/challenge?dc=test"
        let verifyHref = "/tenant/api/v2.0/auth/methods/sms/sms-id/verify?dc=test"
        let resolver = MSALNativeAuthV2HrefURLResolver(config: MSALNativeAuthConfigStubs.configuration)
        let challengeURL = try resolver.url(forHref: challengeHref)
        let verifyURL = try resolver.url(forHref: verifyHref)
        let mfaResult = MSALNativeAuthV2InteractionParsedResponse.mfaRequired(
            continuationToken: "ct-mfa",
            methods: [
                MSALNativeAuthV2ChallengeMethod(
                    id: "sms-id",
                    channelType: .sms,
                    hint: "+1********00",
                    challengeHref: challengeHref
                )
            ]
        )
        parserMock.interactionResponses = [
            .pollInProgress(continuationToken: "ct-poll", pollHref: "https://contoso.com/password/id/pollUpdate?dc=test"),
            mfaResult,
            .verificationRequired(
                continuationToken: "ct-verify",
                verifyHref: verifyHref,
                resendHref: nil,
                sentTo: "+1********00",
                channelType: MSALNativeAuthChannelType(value: "sms"),
                codeLength: 6
            ),
            .readyToComplete(continuationToken: "ct-done")
        ]
        let state = MSALNativeAuthFlowInternalState(
            continuation: MSALNativeAuthFlowContinuationState(
                flowScenario: .passwordReset,
                correlationId: UUID(),
                continuationToken: "ct-update",
                links: [.relation(.update): URL(string: "https://contoso.com/password/id/update?dc=test")!]
            ),
            controller: sut
        )

        let response = await sut.submitNewPassword("New-Password-1", state: state)

        guard case .actionRequired(let next) = response.result else {
            return XCTFail("Expected MFA method selection after password-update polling")
        }
        let selection = try XCTUnwrap(next as? MSALNativeAuthAuthMethodSelectionRequiredState)
        let method = try XCTUnwrap(selection.authMethods.first)
        XCTAssertEqual(selection.authMethods.count, 1)
        XCTAssertEqual(method.id, "sms-id")
        XCTAssertTrue(method.channelTargetType.isSMSType)
        XCTAssertEqual(selection.internalState.continuation.flowScenario, .passwordReset)
        XCTAssertEqual(selection.internalState.continuation.continuationToken, "ct-mfa")
        XCTAssertEqual(selection.internalState.continuation.challengeResponse, mfaResult)
        XCTAssertEqual(selection.internalState.continuation.methodLink(for: method.id), challengeURL)
        XCTAssertEqual(response.correlationId, state.continuation.correlationId)
        XCTAssertEqual(requestProviderMock.pollTokensReceived, ["ct-poll"])
        XCTAssertFalse(requestProviderMock.challengeCalled)
        XCTAssertFalse(requestProviderMock.tokenCalled)

        let challenged = await sut.selectAuthMethod(method, verificationContact: nil, state: selection.internalState)

        guard case .actionRequired(let verificationState) = challenged.result else {
            return XCTFail("Expected SMS code-required state")
        }
        let codeState = try XCTUnwrap(verificationState as? MSALNativeAuthCodeRequiredState)
        XCTAssertEqual(codeState.internalState.continuation.flowScenario, .passwordReset)
        XCTAssertEqual(codeState.internalState.continuation.continuationToken, "ct-verify")
        XCTAssertEqual(codeState.internalState.continuation.link(.verify), verifyURL)
        XCTAssertEqual(requestProviderMock.challengeHrefReceived, challengeURL.absoluteString)
        XCTAssertEqual(requestProviderMock.challengeApiIdReceived, .telemetryApiIdV2MFAGetAuthMethods)

        let resumed = await sut.submitCode("123456", state: codeState.internalState)

        guard case .actionRequired(let completedState) = resumed.result else {
            return XCTFail("Expected sign-in-after-reset state")
        }
        let signInState = try XCTUnwrap(completedState as? MSALNativeAuthSignInAfterResetPasswordState)
        XCTAssertEqual(signInState.internalState.continuation.flowScenario, .passwordReset)
        XCTAssertEqual(signInState.internalState.continuation.continuationToken, "ct-done")
        XCTAssertEqual(resumed.correlationId, state.continuation.correlationId)
        XCTAssertEqual(requestProviderMock.verifyHrefReceived, verifyURL.absoluteString)
        XCTAssertEqual(requestProviderMock.pollHrefsReceived.count, 1)
        XCTAssertEqual(parserMock.parseInteractionCallCount, 4)
        XCTAssertNil(requestProviderMock.enrollHrefReceived)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_selectEnrollmentMethod_missingContactOrUnknownMethod_doesNotSendRequest() async {
        for (id, contact): (String, String?) in [
            ("phone:sms:0", nil), ("phone:sms:0", ""), ("phone:sms:0", " \n"), ("unknown", "+15555550100")
        ] {
            let response = await sut.selectAuthMethod(jitMethod(id: id), verificationContact: contact, state: jitRegistrationState())
            guard case .error(let error) = response.result else {
                return XCTFail("Expected invalid input")
            }
            XCTAssertEqual(error.type, .invalidInput)
            XCTAssertEqual(
                error.errorDescription,
                id == "unknown" ? "Select an offered enrollment method." : "Provide a nonempty verification contact."
            )
            XCTAssertNil(requestProviderMock.enrollHrefReceived)
            XCTAssertFalse(requestProviderMock.challengeCalled)
            XCTAssertEqual(parserMock.parseInteractionCallCount, 0)
        }
    }

    func test_selectEnrollmentMethod_missingState_reportsSpecificGeneralError() async {
        let original = jitRegistrationState().continuation
        for (links, token, expectedMessage): ([MSALNativeAuthV2LinkKey: URL], String?, String) in [
            ([:], "ct-enroll", "Missing enrollment link for selected auth method"),
            (original.links, nil, MSALNativeAuthErrorMessage.missingContinuationToken)
        ] {
            let state = MSALNativeAuthFlowInternalState(
                continuation: MSALNativeAuthFlowContinuationState(
                    flowScenario: original.flowScenario,
                    correlationId: original.correlationId,
                    continuationToken: token,
                    links: links,
                    challengeResponse: jitRegistration()
                ),
                controller: sut
            )
            let response = await sut.selectAuthMethod(jitMethod(), verificationContact: "+15555550100", state: state)

            guard case .error(let error) = response.result else {
                return XCTFail("Expected missing enrollment state error")
            }
            XCTAssertEqual(error.type, .generalError)
            XCTAssertEqual(error.errorDescription, expectedMessage)
            XCTAssertEqual(response.scenario, original.flowScenario)
            XCTAssertEqual(response.correlationId, original.correlationId)
            XCTAssertNil(requestProviderMock.enrollHrefReceived)
            XCTAssertFalse(requestProviderMock.challengeCalled)
            XCTAssertEqual(parserMock.parseInteractionCallCount, 0)
        }
    }

    // swiftlint:disable:next function_body_length
    func test_registration_surfacesBothMethods_emailActivationRetriesAndCompletesSignIn() async throws {
        XCTAssertNil(MSALNativeAuthConfigStubs.configuration.capabilities)
        parserMock.interactionResponses = [
            jitRegistration(includeEmail: true),
            .activationRequired(
                continuationToken: "ct-email-activate",
                activateHref: "https://contoso.com/email/id/activate?dc=test",
                sentTo: "t***@example.com",
                codeLength: 8
            ),
            .error(MSALNativeAuthFlowError(type: .invalidCode)),
            .readyToComplete(continuationToken: "ct-email-done")
        ]
        parserMock.authorizeChallengeResponses = [.authorizationCode(code: "authorization-code")]
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()
        let response = await sut.submitPassword(
            "test-password",
            state: makeSignInState(links: [.verify: URL(string: "https://contoso.com/verify")!])
        )
        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected registration options")
        }
        let registration = try XCTUnwrap(state as? MSALNativeAuthStrongAuthRegistrationRequiredState)
        XCTAssertEqual(registration.authMethods.map(\.channelTargetType.value), ["sms", "email"])
        let email = try XCTUnwrap(registration.authMethods.last)
        XCTAssertEqual(
            registration.internalState.continuation.methodLink(for: email.id)?.absoluteString,
            "https://contoso.com/email?dc=test"
        )
        let enrolled = await sut.selectAuthMethod(
            email,
            verificationContact: "test@example.com",
            state: registration.internalState
        )
        guard case .actionRequired(let next) = enrolled.result else {
            return XCTFail("Expected email activation state")
        }
        let activation = try XCTUnwrap(next as? MSALNativeAuthStrongAuthVerificationRequiredState)
        XCTAssertTrue(activation.channel.isEmailType)
        XCTAssertEqual(activation.codeLength, 8)
        XCTAssertEqual(activation.sentTo, "t***@example.com")
        XCTAssertEqual(activation.internalState.continuation.continuationToken, "ct-email-activate")
        XCTAssertEqual(requestProviderMock.enrollHrefReceived, "https://contoso.com/email?dc=test")
        XCTAssertEqual(requestProviderMock.enrollVerificationContactReceived, "test@example.com")
        XCTAssertEqual(requestProviderMock.enrollChannelTypeReceived, .email)
        XCTAssertEqual(requestProviderMock.enrollTokenReceived, "ct-enroll")
        XCTAssertFalse(requestProviderMock.tokenCalled)

        let rejected = await sut.submitChallenge("00000000", state: activation.internalState)
        guard case .error(let error) = rejected.result else {
            return XCTFail("Expected invalid code")
        }
        XCTAssertEqual(error.type, .invalidCode)
        XCTAssertFalse(requestProviderMock.tokenCalled)

        let completed = await sut.submitChallenge("12345678", state: activation.internalState)
        guard case .completed = completed.result else {
            return XCTFail("Expected completed sign-in")
        }
        XCTAssertEqual(completed.correlationId, registration.internalState.continuation.correlationId)
        XCTAssertEqual(requestProviderMock.activateHrefReceived, "https://contoso.com/email/id/activate?dc=test")
        XCTAssertEqual(requestProviderMock.activateCodeReceived, "12345678")
        XCTAssertEqual(requestProviderMock.activateTokenReceived, "ct-email-activate")
        XCTAssertEqual(requestProviderMock.authorizeChallengeContinueToken, "ct-email-done")
        XCTAssertEqual(requestProviderMock.tokenScopes, registration.internalState.continuation.scopes)
        XCTAssertEqual(requestProviderMock.tokenClaimsRequestJson, registration.internalState.continuation.claimsRequestJson)
        XCTAssertFalse(requestProviderMock.verifyCalled)
        XCTAssertFalse(requestProviderMock.riskVerifyCalled)
    }

    func test_emailEnrollment_observedResponseWithRealParser_returnsEightDigitEmailActivation() async throws {
        sut = MSALNativeAuthFlowController(
            config: MSALNativeAuthConfigStubs.configuration,
            requestProvider: requestProviderMock,
            responseParser: MSALNativeAuthV2ResponseParser(),
            cacheAccessor: cacheAccessorMock,
            resultFactory: resultFactoryMock
        )
        let href = "/tenant/api/v2.0/auth/methods/email/method-id/activate?dc=test"
        requestProviderMock.enrollResponseJSON = [
            "codeLength": 8,
            "id": "method-id",
            "type": "email",
            "hint": "t***@example.com",
            "continuationToken": "ct-email-activate",
            "state": "interactionRequired",
            "action": "activate",
            "_links": [
                "activate": ["href": href, "name": "activate"],
                "resend": ["href": "/tenant/api/v2.0/auth/methods/email?dc=test", "name": "enroll"]
            ]
        ]
        // The stored server method determines the channel, not the caller's supplied metadata.
        let response = await sut.selectAuthMethod(
            jitMethod(id: "email:email:1"),
            verificationContact: "test@example.com",
            state: jitRegistrationState(includeEmail: true)
        )
        guard case .actionRequired(let next) = response.result else {
            return XCTFail("Expected email activation state")
        }
        let activation = try XCTUnwrap(next as? MSALNativeAuthStrongAuthVerificationRequiredState)
        XCTAssertEqual(activation.codeLength, 8)
        XCTAssertEqual(activation.sentTo, "t***@example.com")
        XCTAssertTrue(activation.channel.isEmailType)
        XCTAssertEqual(activation.internalState.continuation.continuationToken, "ct-email-activate")
        let expectedURL = try MSALNativeAuthV2HrefURLResolver(config: MSALNativeAuthConfigStubs.configuration).url(forHref: href)
        XCTAssertEqual(activation.internalState.continuation.link(.activate), expectedURL)
        XCTAssertEqual(activation.internalState.continuation.link(.activate)?.query, "dc=test")
        XCTAssertEqual(requestProviderMock.enrollChannelTypeReceived, .email)
        XCTAssertNil(requestProviderMock.activateHrefReceived)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_emailEnrollment_missingContact_doesNotSendRequest() async {
        for contact: String? in [nil, "", " \n"] {
            let response = await sut.selectAuthMethod(
                jitMethod(id: "email:email:1"),
                verificationContact: contact,
                state: jitRegistrationState(includeEmail: true)
            )
            guard case .error(let error) = response.result else {
                return XCTFail("Expected invalid input")
            }
            XCTAssertEqual(error.type, .invalidInput)
            XCTAssertEqual(error.errorDescription, "Provide a nonempty verification contact.")
            XCTAssertNil(requestProviderMock.enrollHrefReceived)
        }
    }

    func test_emailEnrollment_requestFailure_isNotReportedAsSent() async {
        requestProviderMock.throwError = true
        let expected = MSALNativeAuthFlowError(type: .generalError, errorDescription: "Request failed")
        parserMock.interactionResponses = [.error(expected)]
        let response = await sut.selectAuthMethod(
            jitMethod(id: "email:email:1"),
            verificationContact: "test@example.com",
            state: jitRegistrationState(includeEmail: true)
        )
        guard case .error(let error) = response.result else {
            return XCTFail("Expected request failure")
        }
        XCTAssertTrue(error === expected)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_emailEnrollment_serverError_isPropagated() async {
        sut = MSALNativeAuthFlowController(
            config: MSALNativeAuthConfigStubs.configuration,
            requestProvider: requestProviderMock,
            responseParser: MSALNativeAuthV2ResponseParser(),
            cacheAccessor: cacheAccessorMock,
            resultFactory: resultFactoryMock
        )
        requestProviderMock.enrollResponseJSON = [
            "error": ["code": "invalidRequest", "message": "Enrollment request rejected"]
        ]
        let response = await sut.selectAuthMethod(
            jitMethod(id: "email:email:1"),
            verificationContact: "test@example.com",
            state: jitRegistrationState(includeEmail: true)
        )
        guard case .error(let error) = response.result else {
            return XCTFail("Expected server error")
        }
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, "Enrollment request rejected")
        XCTAssertEqual(requestProviderMock.requests.count, 1)
        XCTAssertEqual(requestProviderMock.requests.first?.sendCallCount, 1)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_enrollment_riskVerification_usesLatestTokenAndReturnsActivationState() async {
        parserMock.interactionResponses = [
            .riskVerificationRequired(continuationToken: "ct-risk", riskVerifyHref: "https://contoso.com/risk?dc=test"),
            jitActivation(),
            .readyToComplete(continuationToken: "ct-done")
        ]
        parserMock.authorizeChallengeResponses = [.authorizationCode(code: "code")]
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()
        let original = jitRegistrationState()
        let response = await sut.selectAuthMethod(jitMethod(), verificationContact: "+15555550100", state: original)
        guard case .actionRequired(let next) = response.result else {
            return XCTFail("Expected activation state")
        }
        XCTAssertTrue(next is MSALNativeAuthStrongAuthVerificationRequiredState)
        XCTAssertEqual(requestProviderMock.riskVerifyTokenReceived, "ct-risk")
        XCTAssertEqual(requestProviderMock.riskVerifyHrefReceived, "https://contoso.com/risk?dc=test")
        XCTAssertEqual(next.internalState.continuation.continuationToken, "ct-activate")
        let completed = await sut.submitChallenge("123456", state: next.internalState)
        guard case .completed = completed.result else {
            return XCTFail("Expected completed")
        }
        XCTAssertEqual(requestProviderMock.tokenClaimsRequestJson, original.continuation.claimsRequestJson)
        XCTAssertEqual(requestProviderMock.tokenScopes, original.continuation.scopes)
        XCTAssertEqual(completed.correlationId, original.continuation.correlationId)
    }

    func test_enrollment_repeatedRiskVerification_stopsWithoutLooping() async {
        let risk: MSALNativeAuthV2InteractionParsedResponse = .riskVerificationRequired(
            continuationToken: "ct-risk",
            riskVerifyHref: "https://contoso.com/risk"
        )
        parserMock.interactionResponses = [risk, risk]
        let response = await sut.selectAuthMethod(jitMethod(), verificationContact: "+15555550100", state: jitRegistrationState())
        guard case .error = response.result else {
            return XCTFail("Expected repeated risk error")
        }
        XCTAssertEqual(requestProviderMock.riskVerifyCallCount, 1)
        XCTAssertNil(requestProviderMock.activateHrefReceived)
    }

    func test_emailEnrollment_riskVerification_returnsErrorWithoutRiskRequest() async {
        parserMock.interactionResponses = [
            .riskVerificationRequired(continuationToken: "ct-risk", riskVerifyHref: "https://contoso.com/risk")
        ]
        let response = await sut.selectAuthMethod(
            jitMethod(id: "email:email:1"),
            verificationContact: "test@example.com",
            state: jitRegistrationState(includeEmail: true)
        )

        guard case .error(let error) = response.result else {
            return XCTFail("Expected unsupported email risk verification error")
        }
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(requestProviderMock.enrollChannelTypeReceived, .email)
        XCTAssertEqual(requestProviderMock.riskVerifyCallCount, 0)
        XCTAssertEqual(parserMock.parseInteractionCallCount, 1)
        XCTAssertNil(requestProviderMock.activateHrefReceived)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_enrollment_browserFallback_isPropagated() async {
        parserMock.interactionResponses = [.browserRequired]
        let response = await sut.selectAuthMethod(jitMethod(), verificationContact: "+15555550100", state: jitRegistrationState())
        guard case .browserRequired = response.result else {
            return XCTFail("Expected browser fallback")
        }
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_enrollment_serverError_isPropagatedWithoutCompleting() async {
        let expected = MSALNativeAuthFlowError(type: .generalError)
        parserMock.interactionResponses = [.error(expected)]
        let response = await sut.selectAuthMethod(jitMethod(), verificationContact: "+15555550100", state: jitRegistrationState())
        guard case .error(let error) = response.result else {
            return XCTFail("Expected enrollment error")
        }
        XCTAssertTrue(error === expected)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_activate_invalidCode_isPropagatedWithoutTokenExchange() async {
        parserMock.interactionResponses = [.error(MSALNativeAuthFlowError(type: .invalidCode))]
        let response = await sut.submitChallenge(
            "000000",
            state: makeSignInState(
                links: [.activate: URL(string: "https://contoso.com/activate")!],
                challengeResponse: jitActivation()
            )
        )
        guard case .error(let error) = response.result else {
            return XCTFail("Expected invalid code")
        }
        XCTAssertEqual(error.type, .invalidCode)
        XCTAssertFalse(requestProviderMock.authorizeChallengeContinueCalled)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_activate_forwardsCodesUnchangedAndLeavesValidationToServer() async {
        let codes = ["", " ", "\n\t", "1", "123456", "12345678", "12345678901234567890", "aB-?!", " 12345678 "]
        let expected = MSALNativeAuthFlowError(type: .invalidCode)
        parserMock.interactionResponses = codes.map { _ in .error(expected) }
        for code in codes {
            let response = await sut.submitChallenge(
                code,
                state: makeSignInState(
                    links: [.activate: URL(string: "https://contoso.com/activate")!],
                    challengeResponse: jitActivation()
                )
            )
            guard case .error(let error) = response.result else {
                return XCTFail("Expected server validation error")
            }
            XCTAssertTrue(error === expected)
            XCTAssertEqual(requestProviderMock.activateCodeReceived, code)
            XCTAssertEqual(requestProviderMock.activateHrefReceived, "https://contoso.com/activate")
        }
        XCTAssertEqual(parserMock.parseInteractionCallCount, codes.count)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_submitChallenge_activationWithoutLink_doesNotFallBackToMFA() async {
        let state = makeSignInState(
            links: [.verify: URL(string: "https://contoso.com/verify")!],
            challengeResponse: jitActivation()
        )
        let response = await sut.submitChallenge("123456", state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected missing activation link error")
        }
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, "Missing activation link")
        XCTAssertFalse(requestProviderMock.verifyCalled)
        XCTAssertNil(requestProviderMock.activateHrefReceived)
        XCTAssertEqual(parserMock.parseInteractionCallCount, 0)
    }

    func test_submitChallenge_activationWithoutToken_reportsMissingContinuation() async {
        let state = makeSignInState(
            links: [.activate: URL(string: "https://contoso.com/activate")!],
            continuationToken: nil,
            challengeResponse: jitActivation()
        )
        let response = await sut.submitChallenge("123456", state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected missing continuation token error")
        }
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.missingContinuationToken)
        XCTAssertEqual(response.correlationId, state.continuation.correlationId)
        XCTAssertFalse(requestProviderMock.verifyCalled)
        XCTAssertNil(requestProviderMock.activateHrefReceived)
        XCTAssertEqual(parserMock.parseInteractionCallCount, 0)
    }

    func test_submitChallenge_activationLinkAlone_doesNotSelectEnrollmentActivation() async {
        let response = await sut.submitChallenge(
            "123456",
            state: makeSignInState(links: [.activate: URL(string: "https://contoso.com/activate")!])
        )

        guard case .error(let error) = response.result else {
            return XCTFail("Expected missing MFA verify link error")
        }
        XCTAssertEqual(error.errorDescription, "Missing verify link")
        XCTAssertFalse(requestProviderMock.verifyCalled)
        XCTAssertNil(requestProviderMock.activateHrefReceived)
        XCTAssertEqual(parserMock.parseInteractionCallCount, 0)
    }

    func test_enrollment_requestFailure_isPropagatedByRealParser() async {
        sut = MSALNativeAuthFlowController(
            config: MSALNativeAuthConfigStubs.configuration,
            requestProvider: requestProviderMock,
            responseParser: MSALNativeAuthV2ResponseParser(),
            cacheAccessor: cacheAccessorMock,
            resultFactory: resultFactoryMock
        )
        requestProviderMock.mockRequest(throwError: true)
        let response = await sut.selectAuthMethod(jitMethod(), verificationContact: "+15555550100", state: jitRegistrationState())
        guard case .error(let error) = response.result else {
            return XCTFail("Expected transport failure")
        }
        XCTAssertEqual(error.type, .generalError)
        XCTAssertNil(requestProviderMock.activateHrefReceived)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_registration_invalidEnrollmentLink_returnsErrorBeforePresentingState() async {
        parserMock.interactionResponses = [.registrationRequired(
            continuationToken: "ct-enroll",
            methods: [
                MSALNativeAuthV2EnrollmentMethod(
                    id: "phone:sms:0",
                    enrollHref: "https://contoso.com/phone?dc=test",
                    channelType: .sms
                ),
                MSALNativeAuthV2EnrollmentMethod(id: "email:email:1", enrollHref: " ", channelType: .email)
            ]
        )]
        let response = await sut.submitPassword(
            "test-password",
            state: makeSignInState(links: [.verify: URL(string: "https://contoso.com/verify")!])
        )
        guard case .error(let error) = response.result else {
            return XCTFail("Expected invalid enrollment link error")
        }
        XCTAssertEqual(error.errorDescription, "Invalid enrollment link")
        XCTAssertNil(requestProviderMock.enrollHrefReceived)
    }

    func test_enrollment_invalidActivationLink_returnsErrorBeforePresentingState() async {
        parserMock.interactionResponses = [.activationRequired(
            continuationToken: "ct-activate", activateHref: " ", sentTo: "", codeLength: 6
        )]
        let response = await sut.selectAuthMethod(jitMethod(), verificationContact: "+15555550100", state: jitRegistrationState())
        guard case .error(let error) = response.result else {
            return XCTFail("Expected invalid activation link error")
        }
        XCTAssertEqual(error.errorDescription, "Invalid activation link")
        XCTAssertNil(requestProviderMock.activateHrefReceived)
    }

    private func signInParameters(scopes: [String]? = ["scope1"], password: String? = nil) -> MSALNativeAuthSignInParameters {
        let params = MSALNativeAuthSignInParameters(username: "user@contoso.com")
        params.scopes = scopes
        params.password = password
        return params
    }

    private func makeSignInState(
        links: [MSALNativeAuthV2LinkRelation: URL] = [:],
        continuationToken: String? = "ct",
        scopes: [String] = ["scope1"],
        claimsRequestJson: String? = nil,
        correlationId: UUID = UUID(),
        challengeResponse: MSALNativeAuthV2InteractionParsedResponse? = nil
    ) -> MSALNativeAuthFlowInternalState {
        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: .signIn,
            correlationId: correlationId,
            continuationToken: continuationToken,
            links: relationLinks(links),
            scopes: scopes,
            claimsRequestJson: claimsRequestJson,
            challengeResponse: challengeResponse
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
            challengeResponse: .mfaRequired(continuationToken: continuationToken, methods: [])
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
            challengeResponse: .challengeRequired(continuationToken: continuationToken ?? "", methods: methods)
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

    private func smsMethod() -> MSALNativeAuthV2ChallengeMethod {
        return MSALNativeAuthV2ChallengeMethod(
            id: "sms-id", channelType: .sms, hint: "+1********00", challengeHref: "https://contoso.com/sms/challenge"
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

    func test_signIn_whenEmailSMSAndPasswordAvailable_returnsAllChoicesInServerOrder() async {
        let methods = primaryMethods(passwordFirst: false)
        let sms = smsMethod()
        let serverMethods = [methods[0], sms, methods[1]]
        prepareSignInStart(methods: serverMethods)

        let response = await sut.signIn(parameters: signInParameters())

        guard case .actionRequired(let state) = response.result,
              let selectionState = state as? MSALNativeAuthAuthMethodSelectionRequiredState else {
            return XCTFail("Expected authentication method selection")
        }
        XCTAssertEqual(selectionState.authMethods.map(\.id), serverMethods.map(\.id))
        XCTAssertEqual(selectionState.internalState.continuation.methodLink(for: sms.id)?.absoluteString, sms.challengeHref)
        XCTAssertFalse(requestProviderMock.challengeCalled)
        XCTAssertFalse(requestProviderMock.submitPasswordCalled)
    }

    func test_signIn_whenSMSAndEmailAvailable_returnsSelectionRequired() async {
        await assertPrimarySelectionRequired(password: nil, methods: [smsMethod(), primaryMethods()[1]])
    }

    func test_signIn_whenNoMethods_returnsErrorWithoutChallenge() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .continuationToken(continuationToken: "ct-authorization-challenge", href: "https://contoso.com/signin")
        ]
        parserMock.interactionResponses = [
            .challengeRequired(
                continuationToken: "ct-2",
                methods: []
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

    // MARK: - Shared interaction routing

    // swiftlint:disable:next function_body_length
    func test_submitCode_rejectsInteractionResultsNotSupportedByScenario() async {
        let attributes = MSALNativeAuthV2InteractionParsedResponse.attributesRequired(
            continuationToken: "ct-attributes",
            submitHref: "https://contoso.com/attributes",
            attributes: [MSALNativeAuthRequiredAttributeInternal(name: "city", type: "text", required: true)]
        )
        let update = MSALNativeAuthV2InteractionParsedResponse.updateRequired(
            continuationToken: "ct-update",
            updateHref: "https://contoso.com/update"
        )
        let verification = MSALNativeAuthV2InteractionParsedResponse.verificationRequired(
            continuationToken: "ct-verify",
            verifyHref: "https://contoso.com/verify",
            resendHref: nil,
            sentTo: "t***@example.com",
            channelType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 8
        )
        let mfa = MSALNativeAuthV2InteractionParsedResponse.mfaRequired(
            continuationToken: "ct-mfa",
            methods: [
                MSALNativeAuthV2ChallengeMethod(
                    id: "sms-id", channelType: .sms, hint: "+1********00", challengeHref: "https://contoso.com/challenge"
                )
            ]
        )
        let cases: [(MSALNativeAuthFlowScenario, MSALNativeAuthV2InteractionParsedResponse)] = [
            (.signUp, update),
            (.signUp, mfa),
            (.signUp, .verificationRequired(
                continuationToken: "ct-sms",
                verifyHref: "https://contoso.com/sms/verify",
                resendHref: nil,
                sentTo: "+1********00",
                channelType: MSALNativeAuthChannelType(value: "sms"),
                codeLength: 6
            )),
            (.signIn, attributes),
            (.signIn, update),
            (.signIn, verification),
            (.passwordReset, attributes),
            (.passwordReset, verification)
        ]
        for (scenario, result) in cases {
            parserMock.interactionResponses.append(result)
            let state = MSALNativeAuthFlowInternalState(
                continuation: MSALNativeAuthFlowContinuationState(
                    flowScenario: scenario,
                    correlationId: UUID(),
                    continuationToken: "ct",
                    links: [.relation(.verify): URL(string: "https://contoso.com/verify")!]
                ),
                controller: sut
            )

            let response = await sut.submitCode("12345678", state: state)

            guard case .error(let error) = response.result else {
                return XCTFail("Expected unsupported interaction error for \(scenario), got \(response.result)")
            }
            XCTAssertTrue(error.isGeneralError)
            XCTAssertEqual(response.correlationId, state.continuation.correlationId)
        }
        XCTAssertEqual(parserMock.parseInteractionCallCount, cases.count)
        XCTAssertFalse(requestProviderMock.submitAttributesCalled)
        XCTAssertFalse(requestProviderMock.updatePasswordCalled)
        XCTAssertFalse(requestProviderMock.challengeCalled)
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    // swiftlint:disable:next function_body_length
    func test_submitCode_signUp_collectsAttributesThenVerifiesEmail_preservingContinuation() async throws {
        let submitURL = try XCTUnwrap(URL(string: "https://contoso.com/signup/attributes?dc=test"))
        let verifyURL = try XCTUnwrap(URL(string: "https://contoso.com/signup/verify?dc=test"))
        let resendURL = try XCTUnwrap(URL(string: "https://contoso.com/signup/resend?dc=test"))
        parserMock.interactionResponses = [
            .attributesRequired(
                continuationToken: "ct-attributes",
                submitHref: submitURL.absoluteString,
                attributes: [MSALNativeAuthRequiredAttributeInternal(name: "city", type: "text", required: true)]
            ),
            .verificationRequired(
                continuationToken: "ct-email",
                verifyHref: verifyURL.absoluteString,
                resendHref: resendURL.absoluteString,
                sentTo: "t***@example.com",
                channelType: MSALNativeAuthChannelType(value: "email"),
                codeLength: 8
            )
        ]
        let state = MSALNativeAuthFlowInternalState(
            continuation: MSALNativeAuthFlowContinuationState(
                flowScenario: .signUp,
                correlationId: UUID(),
                continuationToken: "ct-verify",
                links: [.relation(.verify): URL(string: "https://contoso.com/verify")!],
                scopes: ["scope1"],
                claimsRequestJson: "{\"id_token\":{}}",
                submittedAttributes: ["email", "password"]
            ),
            controller: sut
        )

        let response = await sut.submitCode("12345678", state: state)

        guard case .actionRequired(let next) = response.result else {
            return XCTFail("Expected additional sign-up attributes")
        }
        let attributesState = try XCTUnwrap(next as? MSALNativeAuthAttributesRequiredState)
        XCTAssertEqual(attributesState.attributes.map(\.name), ["city"])
        XCTAssertEqual(attributesState.internalState.continuation.continuationToken, "ct-attributes")
        XCTAssertEqual(attributesState.internalState.continuation.link(.submitAttributes), submitURL)
        XCTAssertEqual(attributesState.internalState.continuation.submittedAttributes, ["email", "password"])
        XCTAssertFalse(requestProviderMock.submitAttributesCalled)

        let submitted = await sut.submitAttributes(["city": "Seattle"], state: attributesState.internalState)

        guard case .actionRequired(let verificationState) = submitted.result else {
            return XCTFail("Expected email verification")
        }
        let codeState = try XCTUnwrap(verificationState as? MSALNativeAuthCodeRequiredState)
        let continuation = codeState.internalState.continuation
        XCTAssertEqual(continuation.flowScenario, .signUp)
        XCTAssertEqual(continuation.continuationToken, "ct-email")
        XCTAssertEqual(continuation.link(.verify), verifyURL)
        XCTAssertEqual(continuation.link(.resend), resendURL)
        XCTAssertEqual(continuation.submittedAttributes, ["email", "password", "city"])
        XCTAssertEqual(continuation.scopes, state.continuation.scopes)
        XCTAssertEqual(continuation.claimsRequestJson, state.continuation.claimsRequestJson)
        XCTAssertEqual(continuation.correlationId, state.continuation.correlationId)
        XCTAssertEqual(requestProviderMock.submitAttributesHrefReceived, submitURL.absoluteString)
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["city"] as? String, "Seattle")
        XCTAssertFalse(requestProviderMock.tokenCalled)
    }

    func test_submitNewPassword_whenPollRequestsAnotherUpdate_doesNotBypassPollResultFilter() async {
        parserMock.interactionResponses = [
            .pollInProgress(continuationToken: "ct-poll", pollHref: "https://contoso.com/pollUpdate"),
            .updateRequired(continuationToken: "ct-update-again", updateHref: "https://contoso.com/update-again")
        ]
        let state = MSALNativeAuthFlowInternalState(
            continuation: MSALNativeAuthFlowContinuationState(
                flowScenario: .passwordReset,
                correlationId: UUID(),
                continuationToken: "ct-update",
                links: [.relation(.update): URL(string: "https://contoso.com/update")!]
            ),
            controller: sut
        )

        let response = await sut.submitNewPassword("New-Password-1", state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected unexpected poll response error")
        }
        XCTAssertTrue(error.isGeneralError)
        XCTAssertEqual(requestProviderMock.pollHrefsReceived.count, 1)
        XCTAssertEqual(parserMock.parseInteractionCallCount, 2)
        XCTAssertFalse(requestProviderMock.tokenCalled)
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
        XCTAssertEqual(selectionState.internalState.continuation.challengeResponse, parserMock.interactionResponses[0])
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

    func test_submitPassword_duplicateMFAMethodIds_preservesLastResolvedLink() async throws {
        let first = primaryMethods()[1]
        let last = MSALNativeAuthV2ChallengeMethod(
            id: first.id,
            channelType: .email,
            hint: first.hint,
            challengeHref: "https://contoso.com/email/challenge?dc=latest"
        )
        parserMock.interactionResponses = [.mfaRequired(continuationToken: "ct-mfa", methods: [first, last])]

        let response = await sut.submitPassword(
            "password",
            state: makeSignInState(links: [.verify: URL(string: "https://contoso.com/password/verify")!])
        )

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected method selection, not a link-count error")
        }
        let selection = try XCTUnwrap(state as? MSALNativeAuthAuthMethodSelectionRequiredState)
        XCTAssertEqual(selection.authMethods.count, 2)
        XCTAssertEqual(selection.internalState.continuation.methodLink(for: first.id)?.absoluteString, last.challengeHref)
        XCTAssertFalse(requestProviderMock.challengeCalled)
    }

    func test_submitPassword_invalidLinkBeforeValidDuplicate_returnsError() async {
        let valid = primaryMethods()[1]
        let invalid = MSALNativeAuthV2ChallengeMethod(
            id: valid.id,
            channelType: .email,
            hint: valid.hint,
            challengeHref: " "
        )
        parserMock.interactionResponses = [.mfaRequired(continuationToken: "ct-mfa", methods: [invalid, valid])]

        let response = await sut.submitPassword(
            "password",
            state: makeSignInState(links: [.verify: URL(string: "https://contoso.com/password/verify")!])
        )

        guard case .error(let error) = response.result else {
            return XCTFail("Expected invalid link to fail before a duplicate can overwrite it")
        }
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.invalidAuthMethodChallengeLink)
        XCTAssertFalse(requestProviderMock.challengeCalled)
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
        XCTAssertNil(resultState.internalState.continuation.challengeResponse, file: file, line: line)
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
        XCTAssertEqual(requestProviderMock.challengeApiIdReceived, .telemetryApiIdV2SignInSelectAuthMethod)
        XCTAssertFalse(requestProviderMock.submitPasswordCalled)
    }

    func test_selectAuthMethod_primaryPassword_repeatedSelectionFollowsServerResponses() async {
        requestProviderMock.mockRequest()
        parserMock.interactionResponses = [
            .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Challenge request failed")),
            passwordVerificationRequired()
        ]
        let methods = primaryMethods()
        let state = makePrimarySelectionState(methods: methods)
        let selectedMethod = methods[0].publicAuthMethod

        let firstResponse = await sut.selectAuthMethod(selectedMethod, verificationContact: nil, state: state)
        let secondResponse = await sut.selectAuthMethod(selectedMethod, verificationContact: nil, state: state)

        guard case .error(let error) = firstResponse.result,
              case .actionRequired(let passwordState) = secondResponse.result else {
            return XCTFail("Expected server error followed by passwordRequired on retry")
        }
        XCTAssertEqual(error.errorDescription, "Challenge request failed")
        XCTAssertTrue(passwordState is MSALNativeAuthPasswordRequiredState)
        XCTAssertEqual(requestProviderMock.challengeCallCount, 2)
        XCTAssertFalse(requestProviderMock.submitPasswordCalled)
    }

    // MARK: - selectAuthMethod (sign-in MFA)

    func test_selectAuthMethod_afterPasswordRequestsEmailMFA_returnsMFAVerificationRequired() async {
        requestProviderMock.mockRequest()
        let method = primaryMethods()[1]
        parserMock.interactionResponses = [
            .mfaRequired(continuationToken: "ct-mfa", methods: [method]),
            emailVerificationRequired()
        ]
        let state = makeSignInState(links: [.verify: URL(string: "https://contoso.com/password/verify")!])

        let passwordResponse = await sut.submitPassword("password", state: state)
        guard case .actionRequired(let nextState) = passwordResponse.result,
              let selectionState = nextState as? MSALNativeAuthAuthMethodSelectionRequiredState else {
            return XCTFail("Expected method selection, got \(passwordResponse.result)")
        }

        let response = await sut.selectAuthMethod(
            selectionState.authMethods[0],
            verificationContact: nil,
            state: selectionState.internalState
        )

        guard case .actionRequired(let resultState) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        XCTAssertTrue(resultState is MSALNativeAuthMFAVerificationRequiredState)
        XCTAssertEqual(requestProviderMock.challengeApiIdReceived, .telemetryApiIdV2MFAGetAuthMethods)
        XCTAssertNil(resultState.internalState.continuation.challengeResponse)
    }

    func test_selectAuthMethod_withoutChallengeResponse_returnsErrorWithoutRequest() async {
        requestProviderMock.mockRequest()
        let method = primaryMethods()[0].publicAuthMethod
        let state = makeSignInState()

        let response = await sut.selectAuthMethod(method, verificationContact: nil, state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isGeneralError)
        XCTAssertFalse(requestProviderMock.challengeCalled)
    }

    func test_selectAuthMethod_withNonChallengeResponse_returnsErrorWithoutRequest() async {
        requestProviderMock.mockRequest()
        let method = primaryMethods()[0].publicAuthMethod
        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: .signIn,
            correlationId: UUID(),
            continuationToken: "ct",
            links: [.method(id: method.id): URL(string: "https://contoso.com/password/challenge")!],
            challengeResponse: .readyToComplete(continuationToken: "ct")
        )
        let state = MSALNativeAuthFlowInternalState(continuation: continuation, controller: sut)

        let response = await sut.selectAuthMethod(method, verificationContact: nil, state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertTrue(error.isGeneralError)
        XCTAssertFalse(requestProviderMock.challengeCalled)
    }

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
        XCTAssertEqual(requestProviderMock.challengeApiIdReceived, .telemetryApiIdV2MFAGetAuthMethods)
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

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.missingAuthMethodChallengeLink)
        XCTAssertFalse(requestProviderMock.challengeCalled)
        XCTAssertEqual(parserMock.parseInteractionCallCount, 0)
        XCTAssertNil(requestProviderMock.enrollHrefReceived)
    }

    func test_selectAuthMethod_primaryMissingContinuation_returnsError() async {
        requestProviderMock.mockRequest()
        let methods = primaryMethods()
        let state = makePrimarySelectionState(methods: methods, continuationToken: nil)

        let response = await sut.selectAuthMethod(methods[0].publicAuthMethod, verificationContact: nil, state: state)

        guard case .error(let error) = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.missingContinuationToken)
        XCTAssertFalse(requestProviderMock.challengeCalled)
        XCTAssertFalse(requestProviderMock.submitPasswordCalled)
        XCTAssertEqual(parserMock.parseInteractionCallCount, 0)
        XCTAssertNil(requestProviderMock.enrollHrefReceived)
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
