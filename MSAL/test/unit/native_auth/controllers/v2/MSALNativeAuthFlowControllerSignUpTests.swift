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

    private func emailAttribute() -> MSALNativeAuthRequiredAttributeInternal {
        MSALNativeAuthRequiredAttributeInternal(name: "email", type: "text", required: true)
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
                attributes: [emailAttribute()]
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
        // Everything supplied up front is submitted at once, regardless of what the server asked for.
        // The username is sent as the `email` attribute here, not on the start request.
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["email"] as? String, username)
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["password"] as? String, "password")
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["city"] as? String, "Seattle")
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
                attributes: [emailAttribute()]
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
                attributes: [emailAttribute()]
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
        // Reserved keys are not overridden: the SDK's username/password are submitted, not the app-supplied ones.
        XCTAssertEqual(requestProviderMock.submitAttributesReceived?["email"] as? String, username)
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
                attributes: [emailAttribute()]
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

    // MARK: - submitCode

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
