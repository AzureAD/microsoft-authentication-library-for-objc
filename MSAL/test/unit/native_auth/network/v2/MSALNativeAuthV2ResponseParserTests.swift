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

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
final class MSALNativeAuthV2ResponseParserTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthV2ResponseParser!
    private var context: MSALNativeAuthRequestContext!

    override func setUp() {
        super.setUp()
        sut = MSALNativeAuthV2ResponseParser()
        context = MSALNativeAuthRequestContextMock()
    }

    // MARK: - Builders

    private func parseEnrollment(methods: [[String: Any]], token: String? = "ct-enroll") throws -> MSALNativeAuthV2InteractionParsedResponse {
        var json: [String: Any] = [
            "state": "interactionRequired",
            "action": "enroll",
            "_embedded": ["methods": methods]
        ]
        json["continuationToken"] = token
        return try parseHALInteraction(json)
    }

    private func parseHALInteraction(_ json: [String: Any]) throws -> MSALNativeAuthV2InteractionParsedResponse {
        let serialized = try MSALNativeAuthV2HALResponseSerializer().responseObject(
            for: nil,
            data: JSONSerialization.data(withJSONObject: json),
            context: context
        )
        return sut.parseInteraction(context: context, .success(try XCTUnwrap(serialized as? MSALNativeAuthHALResponse)))
    }

    func test_parsePasswordVerify_requiresNoChallengeContextOrNewResponseFields() throws {
        let verifyHref = "/tenant/api/v2.0/auth/methods/password/method-id/verify?dc=test"
        let result = try parseHALInteraction([
            "id": "method-id",
            "type": "password",
            "continuationToken": "ct-existing",
            "state": "interactionRequired",
            "action": "verify",
            "_links": [
                "verify": ["href": verifyHref, "name": "verify"],
                "recover": ["href": "/tenant/api/v2.0/auth/methods/password/method-id/recover?dc=test"],
                "self": ["href": verifyHref]
            ]
        ])
        XCTAssertEqual(result, .verificationRequired(
            continuationToken: "ct-existing",
            verifyHref: verifyHref,
            resendHref: nil,
            sentTo: "",
            channelType: MSALNativeAuthChannelType(value: "password"),
            codeLength: 0
        ))
    }

    func test_parseEnrollment_matchesPasswordVerifyResponse_andIncludesSMSAndEmail() throws {
        let href = "/tenant/api/v2.0/auth/methods/phone?dc=test"
        let result = try parseEnrollment(methods: [
            ["type": "phone", "channels": ["sms"], "_links": ["enroll": ["href": href]]],
            ["type": "email", "_links": ["enroll": ["href": "/tenant/api/v2.0/auth/methods/email"]]]
        ])
        guard case .registrationRequired(let token, let methods) = result else {
            return XCTFail("Expected registrationRequired")
        }
        XCTAssertEqual(token, "ct-enroll")
        XCTAssertEqual(methods.count, 2)
        XCTAssertEqual(methods.first?.enrollHref, href)
        XCTAssertTrue(methods.first?.publicAuthMethod.channelTargetType.isSMSType == true)
        XCTAssertFalse(try XCTUnwrap(methods.first?.id).isEmpty)
        XCTAssertEqual(methods.last?.enrollHref, "/tenant/api/v2.0/auth/methods/email")
        XCTAssertTrue(methods.last?.publicAuthMethod.channelTargetType.isEmailType == true)
        XCTAssertNotEqual(methods.first?.id, methods.last?.id)
    }

    func test_parseEnrollment_emailOnlyWithoutChannels_isSurfaced() throws {
        let result = try parseEnrollment(methods: [
            ["type": "email", "_links": ["enroll": ["href": "/email?dc=test"]]]
        ])
        guard case .registrationRequired(_, let methods) = result else {
            return XCTFail("Expected email registration option")
        }
        XCTAssertEqual(methods.count, 1)
        XCTAssertEqual(methods.first?.channelType, .email)
        XCTAssertEqual(methods.first?.publicAuthMethod.challengeType, "email")
        XCTAssertEqual(methods.first?.enrollHref, "/email?dc=test")
    }

    func test_parseEnrollment_normalizesMethodTypesLikeChallengeMethods() throws {
        let result = try parseEnrollment(methods: [
            ["type": "PHONE", "channels": ["sms"], "_links": ["enroll": ["href": "/phone?dc=test"]]],
            ["type": "Email", "_links": ["enroll": ["href": "/email?dc=test"]]]
        ])
        guard case .registrationRequired(_, let methods) = result else {
            return XCTFail("Expected case-insensitive enrollment method types")
        }
        XCTAssertEqual(methods.map(\.id), ["phone:sms:0", "email:email:1"])
        XCTAssertEqual(methods.map(\.channelType), [.sms, .email])
        XCTAssertEqual(methods.map(\.enrollHref), ["/phone?dc=test", "/email?dc=test"])
    }

    func test_parseEnrollment_preservesServerOrderAndSkipsUnknownMethods() throws {
        let result = try parseEnrollment(methods: [
            ["type": "email", "_links": ["enroll": ["href": "/email"]]],
            ["type": "unknown"],
            ["type": "phone", "channels": ["sms"], "_links": ["enroll": ["href": "/phone"]]]
        ])
        guard case .registrationRequired(_, let methods) = result else {
            return XCTFail("Expected registration options")
        }
        XCTAssertEqual(methods.map(\.channelType), [.email, .sms])
        XCTAssertEqual(methods.map(\.enrollHref), ["/email", "/phone"])
    }

    func test_parseEnrollment_noSupportedMethods_returnsError() throws {
        for methods: [[String: Any]] in [
            [],
            [["type": "unknown"]],
            [["type": "phone", "channels": ["voice"]]],
            [["type": "phone", "channels": []]]
        ] {
            let result = try parseEnrollment(methods: methods)
            guard case .error(let error) = result else {
                return XCTFail("Expected error")
            }
            XCTAssertEqual(error.type, .generalError)
            XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.noSupportedAuthMethodAvailable)
        }
    }

    func test_parseEnrollment_malformedSupportedMethod_returnsError() throws {
        for method: [String: Any] in [
            ["channels": ["sms"]],
            ["type": "phone"],
            ["type": "phone", "channels": "sms"],
            ["type": "phone", "channels": ["sms"]],
            ["type": "phone", "channels": ["sms"], "_links": ["enroll": ["href": " "]]],
            ["type": "email"],
            ["type": "email", "_links": ["enroll": ["href": " "]]]
        ] {
            guard case .error = try parseEnrollment(methods: [method]) else {
                return XCTFail("Expected malformed enrollment error")
            }
        }
    }

    func test_parseEnrollment_missingContinuationToken_returnsError() throws {
        let methods: [[String: Any]] = [["type": "phone", "channels": ["sms"], "_links": ["enroll": ["href": "/enroll"]]]]
        guard case .error = try parseEnrollment(methods: methods, token: nil) else {
            return XCTFail("Expected missing token error")
        }
    }

    func test_parseActivation_usesActivateNotVerify() throws {
        let result = try parseHALInteraction([
            "action": "activate",
            "continuationToken": "ct-activate",
            "type": "phone",
            "codeLength": 6,
            "hint": "+1******0100",
            "_links": ["activate": ["href": "/phone/id/activate?dc=test"]]
        ])
        XCTAssertEqual(result, .activationRequired(
            continuationToken: "ct-activate",
            activateHref: "/phone/id/activate?dc=test",
            resendHref: nil,
            sentTo: "+1******0100",
            codeLength: 6
        ))
    }

    func test_parseActivation_missingOrEmptyActivateLink_returnsErrorEvenWithVerifyLink() throws {
        for activateLink in [[:], ["href": ""]] {
            guard case .error = try parseHALInteraction([
                "action": "activate",
                "continuationToken": "ct-activate",
                "_links": ["activate": activateLink, "verify": ["href": "/verify"]]
            ]) else {
                return XCTFail("Expected missing activation link error")
            }
        }
    }

    func test_parseActivation_emailWithResendLink_usesActivationLinkAndEightDigitCode() throws {
        let result = try parseHALInteraction([
            "state": "interactionRequired",
            "action": "activate",
            "continuationToken": "ct-email-activate",
            "type": "email",
            "id": "method-id",
            "codeLength": 8,
            "hint": "t***@example.com",
            "_links": [
                "activate": ["href": "/email/method-id/activate?dc=test", "name": "activate"],
                "resend": ["href": "/email?dc=test", "name": "enroll"]
            ]
        ])
        XCTAssertEqual(result, .activationRequired(
            continuationToken: "ct-email-activate",
            activateHref: "/email/method-id/activate?dc=test",
            resendHref: "/email?dc=test",
            sentTo: "t***@example.com",
            codeLength: 8
        ))
    }

    func test_parseActivation_smsResend_usesRelationRatherThanLinkName() throws {
        let result = try parseHALInteraction([
            "state": "interactionRequired", "action": "activate",
            "continuationToken": "ct-sms-activate", "channel": "sms",
            "type": "phone", "id": "method-id", "codeLength": 6, "hint": "+1******0100",
            "_links": [
                "activate": ["href": "/phone/method-id/activate?dc=test", "name": "activate"],
                "resend": ["href": "/phone?dc=test", "name": "enroll"]
            ]
        ])
        XCTAssertEqual(result, .activationRequired(
            continuationToken: "ct-sms-activate",
            activateHref: "/phone/method-id/activate?dc=test",
            resendHref: "/phone?dc=test",
            sentTo: "+1******0100",
            codeLength: 6
        ))
        XCTAssertNotEqual(result, .activationRequired(
            continuationToken: "ct-sms-activate",
            activateHref: "/phone/method-id/activate?dc=test",
            resendHref: nil,
            sentTo: "+1******0100",
            codeLength: 6
        ))
    }

    func test_parseActivation_missingToken_returnsError() throws {
        guard case .error = try parseHALInteraction([
            "action": "activate", "_links": ["activate": ["href": "/activate"]]
        ]) else {
            return XCTFail("Expected missing token error")
        }
    }

    func test_parseActivation_errorAndWebFallback_takePrecedence() throws {
        let errorResult = try parseHALInteraction([
            "action": "activate",
            "error": ["code": "invalidGrant", "innerError": ["code": "invalidOneTimeCode"]]
        ])
        XCTAssertEqual(errorResult, .error(MSALNativeAuthFlowError(type: .invalidCode)))
        let browserResult = try parseHALInteraction([
            "action": "activate", "error": "invalid_grant", "suberror": "web_redirect_required"
        ])
        XCTAssertEqual(browserResult, .error(MSALNativeAuthFlowError(type: .browserRequired)))
    }

    // swiftlint:disable:next function_body_length
    private func makeResponse(
        statusCode: Int = 200,
        state: String? = nil,
        action: String? = nil,
        continuationToken: String? = nil,
        codeLength: Int? = nil,
        hint: String? = nil,
        methodType: String? = nil,
        code: String? = nil,
        links: [String: String] = [:],
        methods: [MSALNativeAuthHALChallengeResponse.EmbeddedMethod] = [],
        authenticationFactor: String? = nil,
        error: MSALNativeAuthHALResponse.ServerError? = nil
    ) -> MSALNativeAuthHALResponse {
        if let code = code {
            return MSALNativeAuthHALAuthorizationCodeResponse(
                statusCode: statusCode,
                correlationId: nil,
                continuationToken: continuationToken,
                links: links,
                error: error,
                code: code
            )
        }

        if let action = action {
            switch MSALNativeAuthV2HALAction(rawValue: action) {
            case .challenge:
                return MSALNativeAuthHALChallengeResponse(
                    statusCode: statusCode,
                    correlationId: nil,
                    continuationToken: continuationToken,
                    links: links,
                    error: error,
                    methods: methods,
                    hint: hint,
                    authenticationFactor: authenticationFactor
                )
            case .verify:
                return MSALNativeAuthHALCodeSentResponse(
                    statusCode: statusCode,
                    correlationId: nil,
                    continuationToken: continuationToken,
                    links: links,
                    error: error,
                    codeLength: codeLength,
                    methodType: methodType,
                    hint: hint,
                    action: MSALNativeAuthV2HALAction(rawValue: action)
                )
            case .update:
                return MSALNativeAuthHALUpdateResponse(
                    statusCode: statusCode,
                    correlationId: nil,
                    continuationToken: continuationToken,
                    links: links,
                    error: error
                )
            case .poll:
                return MSALNativeAuthHALPollResponse(
                    statusCode: statusCode,
                    correlationId: nil,
                    continuationToken: continuationToken,
                    links: links,
                    error: error
                )
            case .riskVerify:
                return MSALNativeAuthHALRiskVerifyResponse(
                    statusCode: statusCode,
                    correlationId: nil,
                    continuationToken: continuationToken,
                    links: links,
                    error: error
                )
            default:
                break
            }
        }

        if state == "continue" {
            return MSALNativeAuthHALReadyToCompleteResponse(
                statusCode: statusCode,
                correlationId: nil,
                continuationToken: continuationToken,
                links: links,
                error: error
            )
        }

        return MSALNativeAuthHALResponse(
            statusCode: statusCode,
            correlationId: nil,
            continuationToken: continuationToken,
            links: links,
            error: error
        )
    }

    // MARK: - Web redirect required

    func test_flatWebRedirectRequired_returnsBrowserRequiredForHALResponses() throws {
        let description = "AADSTS55214: Non-retryable error has occurred. "
            + "Trace ID: 825633ab-0997-4a21-a3bd-f5d8522c1700 "
            + "Correlation ID: 01a13121-062a-7aa5-b129-98b428a4fa97 Timestamp: 2026-10-12 17:20:41Z"
        let payload: [String: Any] = [
            "error": "invalid_grant",
            "error_description": description,
            "error_codes": [55214],
            "timestamp": "2026-10-12 17:20:41Z",
            "trace_id": "825633ab-0997-4a21-a3bd-f5d8522c1700",
            "correlation_id": "01a13121-062a-7aa5-b129-98b428a4fa97",
            "suberror": "web_redirect_required"
        ]
        let httpResponse = try XCTUnwrap(HTTPURLResponse(
            url: XCTUnwrap(URL(string: "https://contoso.com/authorize-challenge")),
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        ))
        let serialized = try MSALNativeAuthV2HALResponseSerializer().responseObject(
            for: httpResponse,
            data: JSONSerialization.data(withJSONObject: payload),
            context: context
        )
        let response = try XCTUnwrap(serialized as? MSALNativeAuthHALResponse)
        XCTAssertEqual(response.error?.code, "invalid_grant")
        XCTAssertEqual(response.error?.innerErrorCode, "web_redirect_required")
        XCTAssertEqual(response.error?.message, description)

        for scenario: MSALNativeAuthFlowScenario in [.signIn, .signUp, .passwordReset] {
            let result = sut.parseAuthorizeChallenge(context: context, .success(response), flowScenario: scenario)
            guard case .error(let error) = result else {
                return XCTFail("Expected browser-required error, got \(result)")
            }
            XCTAssertTrue(error.isBrowserRequired)
            XCTAssertEqual(error.errorDescription, description)
            XCTAssertEqual(error.errorCodes, [55214])
            XCTAssertEqual(error.correlationId, UUID(uuidString: "01a13121-062a-7aa5-b129-98b428a4fa97"))
        }

        guard case .error(let interactionError) = sut.parseInteraction(context: context, .success(response)) else {
            return XCTFail("Expected browser-required interaction error")
        }
        XCTAssertTrue(interactionError.isBrowserRequired)
        XCTAssertEqual(interactionError.errorDescription, description)
        XCTAssertEqual(interactionError.errorCodes, [55214])
        XCTAssertEqual(interactionError.correlationId, UUID(uuidString: "01a13121-062a-7aa5-b129-98b428a4fa97"))
    }

    func test_webRedirectRequired_usesOnlyErrorAndSuberrorAcrossAllResponseTypes() throws {
        let cases: [(String, String?, Bool)] = [
            ("invalid_grant", "web_redirect_required", true),
            ("invalid_grant", nil, false),
            ("invalid_grant", "other_suberror", false),
            ("redirect_to_web", "web_redirect_required", false),
            ("invalid_request", "web_redirect_required", false)
        ]
        let descriptions: [(String?, [Int])] = [
            (nil, []),
            ("Different server message", []),
            ("AADSTS55214: Non-retryable error has occurred.", [55214]),
            ("AADSTS50076: A different diagnostic code.", [50076])
        ]
        for (oauthError, suberror, expectedBrowserRequired) in cases {
            for (description, expectedCodes) in descriptions {
                var payload: [String: Any] = ["error": oauthError]
                payload["suberror"] = suberror
                payload["error_description"] = description
                let serialized = try MSALNativeAuthV2HALResponseSerializer().responseObject(
                    for: nil,
                    data: JSONSerialization.data(withJSONObject: payload),
                    context: context
                )
                let response = try XCTUnwrap(serialized as? MSALNativeAuthHALResponse)
                for scenario: MSALNativeAuthFlowScenario in [.signIn, .signUp, .passwordReset] {
                    let result = sut.parseAuthorizeChallenge(context: context, .success(response), flowScenario: scenario)
                    guard case .error(let error) = result else {
                        return XCTFail("Expected authorize-challenge error")
                    }
                    XCTAssertEqual(error.isBrowserRequired, expectedBrowserRequired)
                    XCTAssertEqual(error.isGeneralError, !expectedBrowserRequired)
                    if expectedBrowserRequired {
                        XCTAssertEqual(error.errorDescription, description ?? MSALNativeAuthErrorMessage.browserRequired)
                        XCTAssertEqual(error.errorCodes, expectedCodes)
                        XCTAssertEqual(error.correlationId, context.correlationId())
                    }
                }
                guard case .error(let interactionError) = sut.parseInteraction(context: context, .success(response)) else {
                    return XCTFail("Expected interaction error")
                }
                XCTAssertEqual(interactionError.isBrowserRequired, expectedBrowserRequired)
                XCTAssertEqual(interactionError.isGeneralError, !expectedBrowserRequired)
                if expectedBrowserRequired {
                    XCTAssertEqual(interactionError.errorDescription, description ?? MSALNativeAuthErrorMessage.browserRequired)
                    XCTAssertEqual(interactionError.errorCodes, expectedCodes)
                }
                let tokenResponse = try MSALNativeAuthCIAMTokenResponse(jsonDictionary: payload)
                guard case .error(let tokenError) = sut.parseToken(context: context, .success(tokenResponse)) else {
                    return XCTFail("Expected token error")
                }
                XCTAssertEqual(tokenError.isBrowserRequired, expectedBrowserRequired)
                XCTAssertEqual(tokenError.isGeneralError, !expectedBrowserRequired)
            }
        }
    }

    // MARK: - parseAuthorizeChallenge

    func test_legacyWebFallbackSignals_doNotReturnBrowserRequired() throws {
        let payloads: [[String: Any]] = [
            ["state": "webFallbackRequired"],
            ["error": ["code": "redirect_to_web"]],
            [
                "state": "webFallbackRequired",
                "error": ["code": "invalidGrant", "innerError": ["code": "invalidOneTimeCode"]],
                "continuationToken": "ct"
            ],
            ["state": "webFallbackRequired", "code": "auth-code"],
            ["error": ["code": "redirect_to_web"], "code": "auth-code"]
        ]
        for payload in payloads {
            let serialized = try MSALNativeAuthV2HALResponseSerializer().responseObject(
                for: nil,
                data: JSONSerialization.data(withJSONObject: payload),
                context: context
            )
            let response = try XCTUnwrap(serialized as? MSALNativeAuthHALResponse)
            for scenario: MSALNativeAuthFlowScenario in [.signIn, .signUp, .passwordReset] {
                let result = sut.parseAuthorizeChallenge(context: context, .success(response), flowScenario: scenario)
                switch result {
                case .error(let error):
                    XCTAssertFalse(error.isBrowserRequired)
                case .authorizationCode(let code):
                    XCTAssertEqual(code, "auth-code")
                default:
                    XCTFail("Unexpected authorize-challenge result")
                }
            }
            guard case .error(let error) = sut.parseInteraction(context: context, .success(response)) else {
                return XCTFail("Expected interaction error for unsupported response")
            }
            XCTAssertFalse(error.isBrowserRequired)
        }
    }

    func test_parseAuthorizeChallenge_webRedirectRequired_takesPrecedenceOverCodeAndContinuation() throws {
        let payloads: [[String: Any]] = [
            ["error": "invalid_grant", "suberror": "web_redirect_required", "code": "auth-code"],
            ["error": "invalid_grant", "suberror": "web_redirect_required", "continuationToken": "ct"]
        ]
        for payload in payloads {
            let serialized = try MSALNativeAuthV2HALResponseSerializer().responseObject(
                for: nil,
                data: JSONSerialization.data(withJSONObject: payload),
                context: context
            )
            let response = try XCTUnwrap(serialized as? MSALNativeAuthHALResponse)
            let result = sut.parseAuthorizeChallenge(context: context, .success(response), flowScenario: .signIn)
            guard case .error(let error) = result else {
                return XCTFail("Expected browser-required error")
            }
            XCTAssertTrue(error.isBrowserRequired)
        }
    }

    func test_parseAuthorizeChallenge_browserRequired_preservesServerCorrelationId() {
        let correlationId = UUID()
        let response = makeResponse(error: MSALNativeAuthHALResponse.ServerError(
            code: "invalid_grant",
            message: nil,
            innerErrorCode: "web_redirect_required",
            correlationId: correlationId
        ))
        let result = sut.parseAuthorizeChallenge(context: context, .success(response), flowScenario: .signIn)
        guard case .error(let error) = result else {
            return XCTFail("Expected browser-required error")
        }
        XCTAssertTrue(error.isBrowserRequired)
        XCTAssertEqual(error.correlationId, correlationId)
    }

    func test_parseAuthorizeChallenge_withContinuationToken() {
        let response = makeResponse(statusCode: 401, continuationToken: "ct", links: ["reset_password": "https://contoso.com/reset"])
        let result = sut.parseAuthorizeChallenge(context: context, .success(response), flowScenario: .passwordReset)
        XCTAssertEqual(result, .continuationToken(continuationToken: "ct", href: "https://contoso.com/reset"))
    }

    func test_parseAuthorizeChallenge_missingFlowLink_returnsError() {
        let response = makeResponse(statusCode: 401, continuationToken: "ct", links: ["reset_password": "https://contoso.com/reset"])
        let result = sut.parseAuthorizeChallenge(context: context, .success(response), flowScenario: .signUp)
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(
            type: .generalError,
            errorDescription: "Invalid authorize-challenge response: missing 'sign_up' link"
        )))
    }

    func test_parseAuthorizeChallenge_withAuthorizationCode() {
        let response = makeResponse(code: "auth-code")
        let result = sut.parseAuthorizeChallenge(context: context, .success(response), flowScenario: .signIn)
        XCTAssertEqual(result, .authorizationCode(code: "auth-code"))
    }

    func test_parseAuthorizeChallenge_withServerError_returnsError() {
        let serverError = MSALNativeAuthHALResponse.ServerError(code: "invalidRequest", message: "bad", innerErrorCode: nil, correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.parseAuthorizeChallenge(context: context, .success(response), flowScenario: .signIn)
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
    }

    func test_parseAuthorizeChallenge_withTransportFailure_returnsError() {
        let result = sut.parseAuthorizeChallenge(context: context, .failure(ErrorMock.error), flowScenario: .signIn)
        guard case .error = result else {
            return XCTFail("Expected error")
        }
    }

    // MARK: - parseInteraction

    func test_parseInteraction_challengeAction_returnsChallengeRequired() {
        let method = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(id: "1", type: "email", hint: "u***@contoso.com", links: ["challenge": "https://contoso.com/challenge"])
        let response = makeResponse(state: "interactionRequired", action: "challenge", continuationToken: "ct", methods: [method], authenticationFactor: "singleFactor")
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .challengeRequired(
            continuationToken: "ct",
            methods: [MSALNativeAuthV2ChallengeMethod(id: "1", channelType: .email, hint: "u***@contoso.com", challengeHref: "https://contoso.com/challenge")]
        ))
    }

    func test_parseInteraction_challengeAction_singleSMS_returnsChallengeRequired() {
        let method = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(
            id: "sms-id",
            type: "sms",
            hint: "+1********00",
            links: ["challenge": "https://contoso.com/sms/challenge"]
        )
        let response = makeResponse(
            state: "interactionRequired",
            action: "challenge",
            continuationToken: "ct",
            methods: [method],
            authenticationFactor: "singleFactor"
        )
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .challengeRequired(
            continuationToken: "ct",
            methods: [
                MSALNativeAuthV2ChallengeMethod(
                    id: "sms-id",
                    channelType: .sms,
                    hint: "+1********00",
                    challengeHref: "https://contoso.com/sms/challenge"
                )
            ]
        ))
    }

    func test_parseInteraction_challengeAction_uppercaseSMS_returnsChallengeRequired() {
        let method = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(
            id: "sms-id",
            type: "SMS",
            hint: "+1********00",
            links: ["challenge": "https://contoso.com/sms/challenge"]
        )
        let response = makeResponse(
            state: "interactionRequired",
            action: "challenge",
            continuationToken: "ct",
            methods: [method],
            authenticationFactor: "singleFactor"
        )
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .challengeRequired(
            continuationToken: "ct",
            methods: [
                MSALNativeAuthV2ChallengeMethod(
                    id: "sms-id",
                    channelType: .sms,
                    hint: "+1********00",
                    challengeHref: "https://contoso.com/sms/challenge"
                )
            ]
        ))
    }

    func test_parseInteraction_challengeAction_multiFactor_returnsMFARequired() {
        let method = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(id: "1", type: "email", hint: "u***@contoso.com", links: ["challenge": "https://contoso.com/challenge"])
        let response = makeResponse(state: "interactionRequired", action: "challenge", continuationToken: "ct", methods: [method], authenticationFactor: "multiFactor")
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .mfaRequired(
            continuationToken: "ct",
            methods: [MSALNativeAuthV2ChallengeMethod(id: "1", channelType: .email, hint: "u***@contoso.com", challengeHref: "https://contoso.com/challenge")]
        ))
    }

    func test_parseInteraction_challengeAction_singleFactorWithMultipleMethods_returnsAllMethods() {
        let method1 = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(id: "1", type: "password", hint: "", links: ["challenge": "https://contoso.com/password/challenge"])
        let method2 = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(id: "2", type: "email", hint: "u***@contoso.com", links: ["challenge": "https://contoso.com/email/challenge"])
        let response = makeResponse(state: "interactionRequired", action: "challenge", continuationToken: "ct", methods: [method1, method2], authenticationFactor: "singleFactor")
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .challengeRequired(
            continuationToken: "ct",
            methods: [
                MSALNativeAuthV2ChallengeMethod(id: "1", channelType: .password, hint: "", challengeHref: "https://contoso.com/password/challenge"),
                MSALNativeAuthV2ChallengeMethod(id: "2", channelType: .email, hint: "u***@contoso.com", challengeHref: "https://contoso.com/email/challenge")
            ]
        ))
    }

    func test_parseInteraction_challengeAction_singleFactorWithEmailAndSMS_returnsAllMethods() {
        let emailMethod = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(
            id: "email-id",
            type: "email",
            hint: "u***@contoso.com",
            links: ["challenge": "https://contoso.com/email/challenge"]
        )
        let smsMethod = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(
            id: "sms-id",
            type: "sms",
            hint: "+1********00",
            links: ["challenge": "https://contoso.com/sms/challenge"]
        )
        let response = makeResponse(
            state: "interactionRequired",
            action: "challenge",
            continuationToken: "ct",
            methods: [emailMethod, smsMethod],
            authenticationFactor: "singleFactor"
        )
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .challengeRequired(
            continuationToken: "ct",
            methods: [
                MSALNativeAuthV2ChallengeMethod(
                    id: "email-id",
                    channelType: .email,
                    hint: "u***@contoso.com",
                    challengeHref: "https://contoso.com/email/challenge"
                ),
                MSALNativeAuthV2ChallengeMethod(
                    id: "sms-id",
                    channelType: .sms,
                    hint: "+1********00",
                    challengeHref: "https://contoso.com/sms/challenge"
                )
            ]
        ))
    }

    func test_parseInteraction_challengeAction_withUnrecognizedMethodType_returnsKnownMethod() {
        let validMethod = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(id: "1", type: "password", hint: "", links: ["challenge": "https://contoso.com/password/challenge"])
        let unsupportedMethod = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(
            id: "2",
            type: "phone",
            hint: "+1********00",
            links: ["challenge": "https://contoso.com/phone/challenge"]
        )
        let response = makeResponse(
            state: "interactionRequired",
            action: "challenge",
            continuationToken: "ct",
            methods: [validMethod, unsupportedMethod],
            authenticationFactor: "singleFactor"
        )
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .challengeRequired(
            continuationToken: "ct",
            methods: [
                MSALNativeAuthV2ChallengeMethod(
                    id: "1", channelType: .password, hint: "", challengeHref: "https://contoso.com/password/challenge"
                )
            ]
        ))
    }

    func test_parseInteraction_singleFactorWithUnknownMethod_warnsAndReturnsKnownMethodsInOrder() {
        assertUnknownMethodIsSkipped(authenticationFactor: "singleFactor")
    }

    func test_parseInteraction_multiFactorWithUnknownMethod_warnsAndReturnsKnownMethodsInOrder() {
        assertUnknownMethodIsSkipped(authenticationFactor: "multiFactor")
    }

    private func assertUnknownMethodIsSkipped(
        authenticationFactor: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let email = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(
            id: "email-id", type: "email", hint: nil, links: ["challenge": "https://contoso.com/email/challenge"]
        )
        let unknown = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(
            id: "private-id", type: "future-method", hint: "private-hint", links: [:]
        )
        let sms = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(
            id: "sms-id", type: "SMS", hint: nil, links: ["challenge": "https://contoso.com/sms/challenge"]
        )
        let response = makeResponse(
            state: "interactionRequired", action: "challenge", continuationToken: "ct",
            methods: [email, unknown, sms], authenticationFactor: authenticationFactor
        )
        Self.logger.expectation = XCTestExpectation(description: "unsupported method warning")

        let result = sut.parseInteraction(context: context, .success(response))

        let expectedMethods = [
            MSALNativeAuthV2ChallengeMethod(
                id: "email-id", channelType: .email, hint: nil, challengeHref: "https://contoso.com/email/challenge"
            ),
            MSALNativeAuthV2ChallengeMethod(
                id: "sms-id", channelType: .sms, hint: nil, challengeHref: "https://contoso.com/sms/challenge"
            )
        ]
        let expected: MSALNativeAuthV2InteractionParsedResponse = authenticationFactor == "singleFactor"
            ? .challengeRequired(continuationToken: "ct", methods: expectedMethods)
            : .mfaRequired(continuationToken: "ct", methods: expectedMethods)
        XCTAssertEqual(result, expected, file: file, line: line)
        XCTAssertEqual(XCTWaiter().wait(for: [Self.logger.expectation], timeout: 1), .completed, file: file, line: line)
        XCTAssertEqual(Self.logger.level, .warning, file: file, line: line)
        XCTAssertFalse(Self.logger.containsPII, file: file, line: line)
        guard let message = Self.logger.messages.firstObject as? String else {
            return XCTFail("Expected unsupported method warning", file: file, line: line)
        }
        XCTAssertTrue(message.contains("position 2"), file: file, line: line)
        XCTAssertTrue(message.contains("unsupported by this SDK"), file: file, line: line)
        XCTAssertFalse(message.contains("private-id"), file: file, line: line)
        XCTAssertFalse(message.contains("private-hint"), file: file, line: line)
        XCTAssertFalse(message.contains("future-method"), file: file, line: line)
    }

    func test_parseInteraction_challengeAction_withNoKnownMethods_returnsExplicitError() {
        let unknown = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(
            id: "unknown-id", type: "future-method", hint: nil, links: [:]
        )
        for factor in ["singleFactor", "multiFactor"] {
            for methods in [[], [unknown]] {
                let response = makeResponse(
                    state: "interactionRequired", action: "challenge", continuationToken: "ct",
                    methods: methods, authenticationFactor: factor
                )
                let result = sut.parseInteraction(context: context, .success(response))
                guard case .error(let error) = result else {
                    return XCTFail("Expected error when no known methods remain")
                }
                XCTAssertTrue(error.isGeneralError)
                XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.noSupportedAuthMethodAvailable)
                XCTAssertEqual(error.correlationId, context.correlationId())
            }
        }
    }

    func test_parseInteraction_challengeAction_withMissingMethodTypeOrKnownMethodId_returnsError() {
        let malformedMethods = [
            MSALNativeAuthHALChallengeResponse.EmbeddedMethod(id: "1", type: nil, hint: nil, links: ["challenge": "/challenge"]),
            MSALNativeAuthHALChallengeResponse.EmbeddedMethod(id: "1", type: "", hint: nil, links: ["challenge": "/challenge"]),
            MSALNativeAuthHALChallengeResponse.EmbeddedMethod(id: nil, type: "email", hint: nil, links: ["challenge": "/challenge"])
        ]
        for method in malformedMethods {
            let response = makeResponse(
                state: "interactionRequired", action: "challenge", continuationToken: "ct",
                methods: [method], authenticationFactor: "singleFactor"
            )
            let result = sut.parseInteraction(context: context, .success(response))
            guard case .error(let error) = result else {
                return XCTFail("Expected malformed method error")
            }
            XCTAssertTrue(error.isGeneralError)
            XCTAssertEqual(error.errorDescription, "Invalid interaction response: malformed authentication method")
        }
    }

    func test_parseInteraction_challengeAction_withMethodMissingChallengeLink_returnsError() {
        let validMethod = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(id: "1", type: "email", hint: "u***@contoso.com", links: ["challenge": "https://contoso.com/email/challenge"])
        let malformedMethod = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(id: "2", type: "email", hint: "u***@contoso.com", links: [:])
        let response = makeResponse(state: "interactionRequired", action: "challenge", continuationToken: "ct", methods: [validMethod, malformedMethod], authenticationFactor: "multiFactor")
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
    }

    func test_parseInteraction_challengeAction_missingChallengeContext_returnsError() {
        let method = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(id: "1", type: "email", hint: "u***@contoso.com", links: ["challenge": "https://contoso.com/challenge"])
        let response = makeResponse(state: "interactionRequired", action: "challenge", continuationToken: "ct", methods: [method])
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
    }

    func test_parseInteraction_verifyAction_returnsVerificationRequired() {
        let response = makeResponse(
            state: "interactionRequired",
            action: "verify",
            continuationToken: "ct",
            codeLength: 8,
            hint: "u***@contoso.com",
            links: ["verify": "https://contoso.com/verify", "resend": "https://contoso.com/resend"]
        )
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .verificationRequired(
            continuationToken: "ct",
            verifyHref: "https://contoso.com/verify",
            resendHref: "https://contoso.com/resend",
            sentTo: "u***@contoso.com",
            channelType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 8
        ))
    }

    func test_parseInteraction_verifyAction_usesServerChannelType() {
        let response = makeResponse(
            state: "interactionRequired",
            action: "verify",
            continuationToken: "ct",
            codeLength: 8,
            hint: "+1 (***) ***-1234",
            methodType: "sms",
            links: ["verify": "https://contoso.com/verify", "resend": "https://contoso.com/resend"]
        )
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .verificationRequired(
            continuationToken: "ct",
            verifyHref: "https://contoso.com/verify",
            resendHref: "https://contoso.com/resend",
            sentTo: "+1 (***) ***-1234",
            channelType: MSALNativeAuthChannelType(value: "sms"),
            codeLength: 8
        ))
    }

    func test_parseInteraction_updateAction_returnsUpdateRequired() {
        let response = makeResponse(state: "interactionRequired", action: "update", continuationToken: "ct", links: ["update": "https://contoso.com/update"])
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .updateRequired(continuationToken: "ct", updateHref: "https://contoso.com/update"))
    }

    func test_parseInteraction_pollAction_returnsPollInProgress() {
        let response = makeResponse(state: "interactionRequired", action: "poll", continuationToken: "ct", links: ["poll": "https://contoso.com/poll"])
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .pollInProgress(continuationToken: "ct", pollHref: "https://contoso.com/poll"))
    }

    func test_parseInteraction_riskVerifyAction_returnsRiskVerificationRequired() {
        let response = makeResponse(
            state: "interactionRequired",
            action: "riskverify",
            continuationToken: "ct",
            links: ["riskverify": "/tenant/api/v1.0-internal/risk/phone/verify"]
        )

        let result = sut.parseInteraction(context: context, .success(response))

        XCTAssertEqual(result, .riskVerificationRequired(
            continuationToken: "ct",
            riskVerifyHref: "/tenant/api/v1.0-internal/risk/phone/verify"
        ))
    }

    func test_parseInteraction_riskVerifyAction_withoutRiskVerifyLink_failsWithMissingLink() {
        let response = makeResponse(state: "interactionRequired", action: "riskverify", continuationToken: "ct")
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
    }

    func test_parseInteraction_updateAction_withoutUpdateLink_failsWithMissingLink() {
        let response = makeResponse(state: "interactionRequired", action: "update", continuationToken: "ct")
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
    }

    func test_parseInteraction_pollAction_withoutPollLink_failsWithMissingLink() {
        let response = makeResponse(state: "interactionRequired", action: "poll", continuationToken: "ct")
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
    }

    func test_parseInteraction_verifyAction_withoutVerifyLink_failsWithMissingLink() {
        let response = makeResponse(state: "interactionRequired", action: "verify", continuationToken: "ct", codeLength: 8, hint: "u***@contoso.com")
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
    }

    func test_parseInteraction_continueState_returnsReadyToComplete() {
        let response = makeResponse(state: "continue", continuationToken: "ct")
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .readyToComplete(continuationToken: "ct"))
    }

    func test_parseInteraction_webFallbackRequiredState_returnsGeneralError() {
        let response = makeResponse(
            state: "webFallbackRequired",
            continuationToken: "ct",
            links: ["webFallback": "https://contoso.com/oauth2/v2.0/authorize"]
        )
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
    }

    func test_parseInteraction_redirectToWebError_returnsGeneralError() {
        let serverError = MSALNativeAuthHALResponse.ServerError(code: "redirect_to_web", message: nil, innerErrorCode: nil, correlationId: nil)
        let response = makeResponse(continuationToken: "ct", error: serverError)
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
    }

    func test_parseInteraction_userNotFoundBackendResponse_mapsToUserNotFound() throws {
        let message = "AADSTS10040172: The user account does not exist in the directory."
        let result = try parseHALInteraction([
            "error": [
                "code": "invalidRequest",
                "message": message,
                "timestamp": "2026-11-03 09:32:59Z",
                "traceId": "11111111-1111-1111-1111-111111111111",
                "correlationId": "22222222-2222-2222-2222-222222222222",
                "innerError": ["code": "userNotFound"]
            ],
            "_links": [
                "signup": [
                    "href": "/tenant/api/v2.0/signup/start?dc=test",
                    "name": "signup"
                ]
            ]
        ])
        guard case .error(let error) = result else {
            return XCTFail("Expected user-not-found error")
        }
        XCTAssertTrue(error.isUserNotFound)
        XCTAssertFalse(error.isGeneralError)
        XCTAssertEqual(error.errorDescription, message)
    }

    func test_parseHAL_userNotFound_doesNotDependOnMessage() throws {
        let messages: [String?] = [nil, "", "A localized message", "AADSTS50126: Error validating credentials."]
        for message in messages {
            var serverError: [String: Any] = [
                "code": "invalidRequest",
                "innerError": ["code": "userNotFound"]
            ]
            serverError["message"] = message
            let serialized = try MSALNativeAuthV2HALResponseSerializer().responseObject(
                for: nil,
                data: JSONSerialization.data(withJSONObject: ["error": serverError]),
                context: context
            )
            let response = try XCTUnwrap(serialized as? MSALNativeAuthHALResponse)
            XCTAssertEqual(
                sut.parseInteraction(context: context, .success(response)),
                .error(MSALNativeAuthFlowError(type: .userNotFound))
            )
            XCTAssertEqual(
                sut.parseAuthorizeChallenge(context: context, .success(response), flowScenario: .signIn),
                .error(MSALNativeAuthFlowError(type: .userNotFound))
            )
        }
    }

    func test_parseHAL_userNotFound_requiresBothErrorCodes() throws {
        let errorCodes: [(String?, String?)] = [
            ("invalidRequest", nil),
            ("invalidRequest", "unknown"),
            ("invalidGrant", "userNotFound"),
            ("userNotFound", "userNotFound"),
            (nil, "userNotFound")
        ]
        for (code, innerCode) in errorCodes {
            var serverError: [String: Any] = [
                "message": "AADSTS50034: The user account does not exist in the directory. AADSTS10040172"
            ]
            serverError["code"] = code
            if let innerCode = innerCode {
                serverError["innerError"] = ["code": innerCode]
            }
            let serialized = try MSALNativeAuthV2HALResponseSerializer().responseObject(
                for: nil,
                data: JSONSerialization.data(withJSONObject: ["error": serverError]),
                context: context
            )
            let response = try XCTUnwrap(serialized as? MSALNativeAuthHALResponse)
            XCTAssertEqual(
                sut.parseInteraction(context: context, .success(response)),
                .error(MSALNativeAuthFlowError(type: .generalError))
            )
            XCTAssertEqual(
                sut.parseAuthorizeChallenge(context: context, .success(response), flowScenario: .signIn),
                .error(MSALNativeAuthFlowError(type: .generalError))
            )
        }
    }

    func test_parseInteraction_obsoleteUserAlreadyExistsCode_mapsToGeneralError() throws {
        let result = try parseHALInteraction([
            "error": ["code": "userAlreadyExists"]
        ])
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
    }

    func test_parseInteraction_invalidGrantWithoutInnerCode_mapsToGeneralError() {
        let serverError = MSALNativeAuthHALResponse.ServerError(code: "invalidGrant", message: "wrong code", innerErrorCode: nil, correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
    }

    func test_parseInteraction_invalidOneTimeCode_mapsToInvalidCode() {
        let serverError = MSALNativeAuthHALResponse.ServerError(
            code: "invalidGrant",
            message: "AADSTS50184: OTP is incorrect, or no cache entry exists for the tenant/user.",
            innerErrorCode: "invalidOneTimeCode",
            correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .invalidCode)))
    }

    func test_parseInteraction_resetPasswordErrors_mapToInvalidPasswordWithoutDependingOnMessage() throws {
        let codes = [
            "passwordTooWeak", "passwordTooShort", "passwordTooLong",
            "passwordIsInvalid", "passwordRecentlyUsed", "passwordBanned"
        ]
        let messages: [String?] = [
            nil, "", "A localized message",
            "AADSTS120002: New password doesn't meet complexity requirements."
        ]
        for code in codes {
            for message in messages {
                var serverError: [String: Any] = [
                    "code": "invalidRequest",
                    "innerError": ["code": code]
                ]
                serverError["message"] = message
                let result = try parseHALInteraction(["error": serverError])
                guard case .error(let error) = result else {
                    return XCTFail("Expected password error for \(code)")
                }
                XCTAssertTrue(error.isInvalidPassword, code)
                XCTAssertFalse(error.isGeneralError, code)
                if let message = message {
                    XCTAssertEqual(error.errorDescription, message)
                }
            }
        }
    }

    func test_parseInteraction_signupPasswordPolicyViolation_mapsToInvalidPassword() throws {
        let message = "AADSTS1002027: Some of the collected attributes were invalid."
        let result = try parseHALInteraction([
            "error": [
                "code": "invalidRequest",
                "message": message,
                "innerError": [
                    "code": "attributeValidationError",
                    "details": [
                        [
                            "attributeIds": ["password"],
                            "code": "passwordPolicyViolation",
                            "message": "Password validation failed: The new password must have a minimum of 8 characters."
                        ]
                    ]
                ]
            ]
        ])
        guard case .error(let error) = result else {
            return XCTFail("Expected password policy error")
        }
        XCTAssertTrue(error.isInvalidPassword)
        XCTAssertFalse(error.isGeneralError)
        XCTAssertEqual(error.errorDescription, message)
    }

    func test_parseInteraction_signupPasswordPolicyViolation_doesNotDependOnMessagesOrDetailOrder() throws {
        let messages: [String?] = [nil, "", "A localized message"]
        for message in messages {
            var detail: [String: Any] = [
                "attributeIds": ["password"],
                "code": "passwordPolicyViolation"
            ]
            detail["message"] = message
            var serverError: [String: Any] = [
                "code": "invalidRequest",
                "innerError": [
                    "code": "attributeValidationError",
                    "details": [
                        ["attributeIds": ["displayName"], "code": "invalidValue"],
                        detail
                    ]
                ]
            ]
            serverError["message"] = message
            XCTAssertEqual(
                try parseHALInteraction(["error": serverError]),
                .error(MSALNativeAuthFlowError(type: .invalidPassword))
            )
        }
    }

    func test_parseInteraction_signupPasswordAttribute_doesNotRequireDetailCode() throws {
        let details: [[[String: Any]]] = [
            [["attributeIds": ["password"], "code": "invalidValue"]],
            [["attributeIds": ["password"]]],
            [["attributeIds": ["displayName", "password", "givenName"]]],
            [["attributeIds": ["displayName", "password"], "code": "unknown"]],
            [
                ["attributeIds": ["displayName"], "code": "passwordPolicyViolation"],
                ["attributeIds": ["password"], "code": "invalidValue"]
            ]
        ]
        for detail in details {
            let result = try parseHALInteraction([
                "error": [
                    "code": "invalidRequest",
                    "innerError": ["code": "attributeValidationError", "details": detail]
                ]
            ])
            guard case .error(let error) = result else {
                return XCTFail("Expected password attribute error")
            }
            XCTAssertTrue(error.isInvalidPassword)
            XCTAssertFalse(error.isGeneralError)
        }
    }

    func test_parseInteraction_signupOtherAttributeErrors_remainGeneralErrors() throws {
        let details: [[[String: Any]]] = [
            [],
            [["attributeIds": ["displayName"], "code": "invalidValue"]],
            [["attributeIds": ["displayName"], "code": "passwordPolicyViolation"]],
            [["attributeIds": ["displayName", "givenName"]]],
            [["code": "passwordPolicyViolation"]],
            [["attributeIds": [], "code": "passwordPolicyViolation"]],
            [["attributeIds": "password", "code": "passwordPolicyViolation"]]
        ]
        for detail in details {
            let result = try parseHALInteraction([
                "error": [
                    "code": "invalidRequest",
                    "message": "AADSTS120002: Password validation failed.",
                    "innerError": ["code": "attributeValidationError", "details": detail]
                ]
            ])
            XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
        }
    }

    func test_parseInteraction_passwordErrors_requireMatchingOuterAndInnerCodes() throws {
        let codes = [
            "passwordTooWeak", "passwordTooShort", "passwordTooLong",
            "passwordIsInvalid", "passwordRecentlyUsed", "passwordBanned", "attributeValidationError"
        ]
        for code in codes {
            for outerCode: String? in [nil, "invalidGrant", "unknown"] {
                var serverError: [String: Any] = [
                    "innerError": [
                        "code": code,
                        "details": [["attributeIds": ["password"], "code": "passwordPolicyViolation"]]
                    ]
                ]
                serverError["code"] = outerCode
                XCTAssertEqual(
                    try parseHALInteraction(["error": serverError]),
                    .error(MSALNativeAuthFlowError(type: .generalError))
                )
            }
        }
        for innerCode: String? in [nil, "unknown", "passwordPolicyViolation"] {
            var innerError: [String: Any] = [
                "details": [["attributeIds": ["password"], "code": "passwordPolicyViolation"]]
            ]
            innerError["code"] = innerCode
            XCTAssertEqual(
                try parseHALInteraction(["error": ["code": "invalidRequest", "innerError": innerError]]),
                .error(MSALNativeAuthFlowError(type: .generalError))
            )
        }
    }

    func test_parseInteraction_invalidUserNameOrPassword_mapsToInvalidPassword() {
        let correlationId = UUID()
        let serverError = MSALNativeAuthHALResponse.ServerError(
            code: "invalidGrant",
            message: "AADSTS50126: Error validating credentials.",
            innerErrorCode: "invalidUserNameOrPassword",
            correlationId: correlationId)
        let response = makeResponse(error: serverError)
        let result = sut.parseInteraction(context: context, .success(response))
        guard case .error(let error) = result else {
            return XCTFail("Expected invalid password error")
        }
        XCTAssertTrue(error.isInvalidPassword)
        XCTAssertEqual(error.errorDescription, serverError.message)
        XCTAssertEqual(error.errorCodes, [50126])
        XCTAssertEqual(error.correlationId, correlationId)
    }

    // MARK: - parseToken

    func test_parseToken_whenResponseHoldsTokens_returnsSuccess() throws {
        let tokenResponse = try MSALNativeAuthCIAMTokenResponse(jsonDictionary: [
            "access_token": "at", "refresh_token": "rt", "id_token": "idt", "token_type": "Bearer"
        ])
        let result = sut.parseToken(context: context, .success(tokenResponse))
        guard case .success(let parsed) = result else {
            return XCTFail("Expected success, got \(result)")
        }
        XCTAssertEqual(parsed.accessToken, "at")
    }

    func test_parseToken_whenResponseCarriesServerError_returnsErrorWithDescriptionAndCodes() throws {
        let tokenResponse = try MSALNativeAuthCIAMTokenResponse(jsonDictionary: [
            "error": "invalid_grant",
            "error_description": "AADSTS50076: multi-factor authentication is required.",
            "error_codes": [50076]
        ])
        let result = sut.parseToken(context: context, .success(tokenResponse))
        guard case .error(let error) = result else {
            return XCTFail("Expected error, got \(result)")
        }
        XCTAssertTrue(error.isGeneralError)
        XCTAssertEqual(error.errorDescription, "AADSTS50076: multi-factor authentication is required.")
        XCTAssertEqual(error.errorCodes, [50076])
    }

    func test_parseToken_whenWebRedirectRequired_returnsBrowserRequiredWithDiagnostics() throws {
        let tokenResponse = try MSALNativeAuthCIAMTokenResponse(jsonDictionary: [
            "error": "invalid_grant",
            "error_description": "AADSTS55214: Non-retryable error has occurred.",
            "error_codes": [55214],
            "suberror": "web_redirect_required"
        ])

        let result = sut.parseToken(context: context, .success(tokenResponse))

        guard case .error(let error) = result else {
            return XCTFail("Expected browser-required token error, got \(result)")
        }
        XCTAssertTrue(error.isBrowserRequired)
        XCTAssertFalse(error.isGeneralError)
        XCTAssertEqual(error.errorDescription, "AADSTS55214: Non-retryable error has occurred.")
        XCTAssertEqual(error.errorCodes, [55214])
        XCTAssertEqual(error.correlationId, context.correlationId())
    }

    func test_parseToken_whenTransportFails_returnsGeneralError() {
        let result = sut.parseToken(context: context, .failure(MSALNativeAuthFlowError(type: .browserRequired)))
        guard case .error(let error) = result else {
            return XCTFail("Expected error, got \(result)")
        }
        XCTAssertTrue(error.isBrowserRequired)
    }
}

// swiftlint:enable file_length
