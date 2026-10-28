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
            claimsRequestJson: nil,
            submittedAttributes: submittedAttributes
        )
        return MSALNativeAuthFlowInternalState(continuation: continuation, controller: sut)
    }

    private func passwordAttribute() -> MSALNativeAuthRequiredAttributeInternal {
        MSALNativeAuthRequiredAttributeInternal(name: "password", type: "password", required: true)
    }

    // MARK: - signUp start

    func test_signUp_upfrontValuesSubmitted_returnsCodeRequired() async {
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

        let response = await sut.signUp(parameters: signUpParameters(password: "password", attributes: ["city": "Seattle"]))

        guard case .actionRequired(let state) = response.result else {
            return XCTFail("Expected actionRequired, got \(response.result)")
        }
        XCTAssertTrue(state is MSALNativeAuthCodeRequiredState)
        XCTAssertTrue(requestProviderMock.authorizeChallengeStartCalled)
        XCTAssertTrue(requestProviderMock.signUpStartCalled)
        XCTAssertTrue(requestProviderMock.submitAttributesCalled)
        XCTAssertEqual(requestProviderMock.signUpStartUsername, username)
        XCTAssertNil(requestProviderMock.submitAttributesReceived?["email"])
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["password"] as? String, "password")
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["city"] as? String, "Seattle")
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

    func test_signInAfterSignUp_completesWithToken() async {
        requestProviderMock.mockRequest()
        parserMock.authorizeChallengeResponses = [
            .authorizationCode(code: "auth-code")
        ]
        cacheAccessorMock.expectedMSIDTokenResult = MSIDTokenResult()

        let state = makeSignUpState(continuationToken: "ct-continue")
        let response = await sut.signInAfterSignUp(scopes: ["scope1"], claimsRequestJson: nil, state: state)

        guard case .completed = response.result else {
            return XCTFail("Expected completed, got \(response.result)")
        }
        XCTAssertTrue(requestProviderMock.tokenCalled)
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
        let response = await sut.signInAfterSignUp(scopes: ["scope1"], claimsRequestJson: nil, state: nilState)

        guard case .error = response.result else {
            return XCTFail("Expected error, got \(response.result)")
        }
    }
}
// swiftlint:enable type_body_length file_length
