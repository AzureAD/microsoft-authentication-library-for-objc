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

final class MSALNativeAuthV2ResponseParserTests: XCTestCase {

    private var sut: MSALNativeAuthV2ResponseParser!
    private var context: MSALNativeAuthRequestContext!

    override func setUp() {
        super.setUp()
        sut = MSALNativeAuthV2ResponseParser()
        context = MSALNativeAuthRequestContextMock()
    }

    // MARK: - Builders

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
        let isWebFallbackRequired = error?.code == "redirect_to_web" || state == "webFallbackRequired"

        if let code = code {
            return MSALNativeAuthHALAuthorizationCodeResponse(
                statusCode: statusCode,
                correlationId: nil,
                continuationToken: continuationToken,
                links: links,
                error: error,
                isWebFallbackRequired: isWebFallbackRequired,
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
                    isWebFallbackRequired: isWebFallbackRequired,
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
                    isWebFallbackRequired: isWebFallbackRequired,
                    codeLength: codeLength,
                    methodType: methodType,
                    hint: hint
                )
            case .update:
                return MSALNativeAuthHALUpdateResponse(
                    statusCode: statusCode,
                    correlationId: nil,
                    continuationToken: continuationToken,
                    links: links,
                    error: error,
                    isWebFallbackRequired: isWebFallbackRequired
                )
            case .poll:
                return MSALNativeAuthHALPollResponse(
                    statusCode: statusCode,
                    correlationId: nil,
                    continuationToken: continuationToken,
                    links: links,
                    error: error,
                    isWebFallbackRequired: isWebFallbackRequired
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
                error: error,
                isWebFallbackRequired: isWebFallbackRequired
            )
        }

        return MSALNativeAuthHALResponse(
            statusCode: statusCode,
            correlationId: nil,
            continuationToken: continuationToken,
            links: links,
            error: error,
            isWebFallbackRequired: isWebFallbackRequired
        )
    }

    // MARK: - parseAuthorizeChallenge

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

    func test_parseInteraction_challengeAction_withUnrecognizedMethodType_returnsError() {
        let validMethod = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(id: "1", type: "password", hint: "", links: ["challenge": "https://contoso.com/password/challenge"])
        let unsupportedMethod = MSALNativeAuthHALChallengeResponse.EmbeddedMethod(id: "2", type: "sms", hint: "+1********00", links: ["challenge": "https://contoso.com/sms/challenge"])
        let response = makeResponse(state: "interactionRequired", action: "challenge", continuationToken: "ct", methods: [validMethod, unsupportedMethod], authenticationFactor: "singleFactor")
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
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

    func test_parseInteraction_webFallbackRequiredState_returnsBrowserRequired() {
        let response = makeResponse(
            state: "webFallbackRequired",
            continuationToken: "ct",
            links: ["webFallback": "https://contoso.com/oauth2/v2.0/authorize"]
        )
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .browserRequired)
    }

    func test_parseInteraction_redirectToWebError_returnsBrowserRequired() {
        let serverError = MSALNativeAuthHALResponse.ServerError(code: "redirect_to_web", message: nil, innerErrorCode: nil, correlationId: nil)
        let response = makeResponse(continuationToken: "ct", error: serverError)
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .browserRequired)
    }

    func test_parseInteraction_userNotFound_mapsToUserNotFound() {
        let serverError = MSALNativeAuthHALResponse.ServerError(code: "invalidRequest", message: "AADSTS50034 user not found", innerErrorCode: nil, correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .userNotFound)))
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

    func test_parseInteraction_passwordTooWeak_mapsToInvalidPassword() {
        let serverError = MSALNativeAuthHALResponse.ServerError(
            code: "invalidRequest",
            message: "AADSTS120002: New password doesn't meet complexity requirements.",
            innerErrorCode: "passwordTooWeak",
            correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .invalidPassword)))
    }

    func test_parseInteraction_invalidUserNameOrPassword_mapsToInvalidCredentials() {
        let serverError = MSALNativeAuthHALResponse.ServerError(
            code: "invalidGrant",
            message: "AADSTS50126: Error validating credentials.",
            innerErrorCode: "invalidUserNameOrPassword",
            correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.parseInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .invalidCredentials)))
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

    func test_parseToken_whenTransportFails_returnsGeneralError() {
        let result = sut.parseToken(context: context, .failure(MSALNativeAuthFlowError(type: .browserRequired)))
        guard case .error(let error) = result else {
            return XCTFail("Expected error, got \(result)")
        }
        XCTAssertTrue(error.isBrowserRequired)
    }
}
