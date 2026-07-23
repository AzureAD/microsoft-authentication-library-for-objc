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

final class MSALNativeAuthV2ResponseValidatorTests: XCTestCase {

    private var sut: MSALNativeAuthV2ResponseValidator!
    private var context: MSALNativeAuthRequestContext!

    override func setUp() {
        super.setUp()
        sut = MSALNativeAuthV2ResponseValidator()
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
        authenticationFactor: String? = nil,
        methodId: String? = nil,
        methodType: String? = nil,
        attributes: [MSALNativeAuthHALResponse.RequiredAttributeEntry] = [],
        code: String? = nil,
        links: [String: String] = [:],
        methods: [MSALNativeAuthHALResponse.EmbeddedMethod] = [],
        error: MSALNativeAuthHALResponse.ServerError? = nil
    ) -> MSALNativeAuthHALResponse {
        return MSALNativeAuthHALResponse(
            statusCode: statusCode,
            correlationId: nil,
            state: state,
            action: action,
            continuationToken: continuationToken,
            codeLength: codeLength,
            hint: hint,
            authenticationFactor: authenticationFactor,
            methodId: methodId,
            methodType: methodType,
            attributes: attributes,
            code: code,
            links: links,
            methods: methods,
            error: error
        )
    }

    // MARK: - validateAuthorizeChallenge

    func test_validateAuthorizeChallenge_withContinuationToken() {
        let response = makeResponse(statusCode: 401, continuationToken: "ct", links: ["reset_password": "https://contoso.com/reset"])
        let result = sut.validateAuthorizeChallenge(context: context, .success(response), flowScenario: .passwordReset)
        XCTAssertEqual(result, .continuationToken(continuationToken: "ct", href: "https://contoso.com/reset"))
    }

    func test_validateAuthorizeChallenge_missingFlowLink_returnsError() {
        let response = makeResponse(statusCode: 401, continuationToken: "ct", links: ["reset_password": "https://contoso.com/reset"])
        let result = sut.validateAuthorizeChallenge(context: context, .success(response), flowScenario: .signUp)
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(
            type: .generalError,
            errorDescription: "Invalid authorize-challenge response: missing 'sign_up' link"
        )))
    }

    func test_validateAuthorizeChallenge_withAuthorizationCode() {
        let response = makeResponse(code: "auth-code")
        let result = sut.validateAuthorizeChallenge(context: context, .success(response), flowScenario: .signIn)
        XCTAssertEqual(result, .authorizationCode(code: "auth-code"))
    }

    func test_validateAuthorizeChallenge_withServerError_returnsError() {
        let serverError = MSALNativeAuthHALResponse.ServerError(code: "invalidRequest", message: "bad", innerErrorCode: nil, correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.validateAuthorizeChallenge(context: context, .success(response), flowScenario: .signIn)
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
    }

    func test_validateAuthorizeChallenge_withTransportFailure_returnsError() {
        let result = sut.validateAuthorizeChallenge(context: context, .failure(ErrorMock.error), flowScenario: .signIn)
        guard case .error = result else {
            return XCTFail("Expected error")
        }
    }

    // MARK: - validateInteraction

    func test_validateInteraction_challengeAction_returnsChallengeRequired() {
        let method = MSALNativeAuthHALResponse.EmbeddedMethod(id: "1", type: "email", hint: "u***@contoso.com", links: ["challenge": "https://contoso.com/challenge"])
        let response = makeResponse(state: "interactionRequired", action: "challenge", continuationToken: "ct", methods: [method])
        let result = sut.validateInteraction(context: context, .success(response))
        XCTAssertEqual(result, .challengeRequired(continuationToken: "ct", challengeHref: "https://contoso.com/challenge", hint: "u***@contoso.com"))
    }

    func test_validateInteraction_verifyAction_returnsCodeRequired() {
        let response = makeResponse(
            state: "interactionRequired",
            action: "verify",
            continuationToken: "ct",
            codeLength: 8,
            hint: "u***@contoso.com",
            links: ["verify": "https://contoso.com/verify", "resend": "https://contoso.com/resend"]
        )
        let result = sut.validateInteraction(context: context, .success(response))
        XCTAssertEqual(result, .codeRequired(continuationToken: "ct", verifyHref: "https://contoso.com/verify", resendHref: "https://contoso.com/resend", sentTo: "u***@contoso.com", channelType: MSALNativeAuthChannelType(value: "email"), codeLength: 8))
    }

    func test_validateInteraction_verifyAction_usesServerChannelType() {
        let response = makeResponse(
            state: "interactionRequired",
            action: "verify",
            continuationToken: "ct",
            codeLength: 8,
            hint: "+1 (***) ***-1234",
            methodType: "sms",
            links: ["verify": "https://contoso.com/verify", "resend": "https://contoso.com/resend"]
        )
        let result = sut.validateInteraction(context: context, .success(response))
        XCTAssertEqual(result, .codeRequired(continuationToken: "ct", verifyHref: "https://contoso.com/verify", resendHref: "https://contoso.com/resend", sentTo: "+1 (***) ***-1234", channelType: MSALNativeAuthChannelType(value: "sms"), codeLength: 8))
    }

    func test_validateInteraction_updateAction_returnsUpdateRequired() {
        let response = makeResponse(state: "interactionRequired", action: "update", continuationToken: "ct", links: ["update": "https://contoso.com/update"])
        let result = sut.validateInteraction(context: context, .success(response))
        XCTAssertEqual(result, .updateRequired(continuationToken: "ct", updateHref: "https://contoso.com/update"))
    }

    func test_validateInteraction_pollAction_returnsPollInProgress() {
        let response = makeResponse(state: "interactionRequired", action: "poll", continuationToken: "ct", links: ["poll": "https://contoso.com/poll"])
        let result = sut.validateInteraction(context: context, .success(response))
        XCTAssertEqual(result, .pollInProgress(continuationToken: "ct", pollHref: "https://contoso.com/poll"))
    }

    func test_validateInteraction_updateAction_withoutUpdateLink_failsWithMissingLink() {
        let response = makeResponse(state: "interactionRequired", action: "update", continuationToken: "ct")
        let result = sut.validateInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
    }

    func test_validateInteraction_pollAction_withoutPollLink_failsWithMissingLink() {
        let response = makeResponse(state: "interactionRequired", action: "poll", continuationToken: "ct")
        let result = sut.validateInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
    }

    func test_validateInteraction_verifyAction_withoutVerifyLink_failsWithMissingLink() {
        let response = makeResponse(state: "interactionRequired", action: "verify", continuationToken: "ct", codeLength: 8, hint: "u***@contoso.com")
        let result = sut.validateInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
    }

    func test_validateInteraction_continueState_returnsReadyToComplete() {
        let response = makeResponse(state: "continue", continuationToken: "ct")
        let result = sut.validateInteraction(context: context, .success(response))
        XCTAssertEqual(result, .readyToComplete(continuationToken: "ct"))
    }

    func test_validateInteraction_userNotFound_mapsToUserNotFound() {
        let serverError = MSALNativeAuthHALResponse.ServerError(code: "invalidRequest", message: "AADSTS50034 user not found", innerErrorCode: nil, correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.validateInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .userNotFound)))
    }

    func test_validateInteraction_invalidGrant_mapsToInvalidCode() {
        let serverError = MSALNativeAuthHALResponse.ServerError(code: "invalidGrant", message: "wrong code", innerErrorCode: nil, correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.validateInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .invalidCode)))
    }

    func test_validateInteraction_invalidContinuationToken_mapsToGeneralError() {
        let serverError = MSALNativeAuthHALResponse.ServerError(code: "invalidRequest", message: "bad token", innerErrorCode: "invalidContinuationToken", correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.validateInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .generalError)))
    }

    func test_validateInteraction_passwordTooWeak_mapsToInvalidPassword() {
        let serverError = MSALNativeAuthHALResponse.ServerError(
            code: "invalidRequest",
            message: "AADSTS120002: New password doesn't meet complexity requirements.",
            innerErrorCode: "passwordTooWeak",
            correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.validateInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .invalidPassword)))
    }

    func test_validateInteraction_invalidUserNameOrPassword_mapsToInvalidCredentials() {
        let serverError = MSALNativeAuthHALResponse.ServerError(
            code: "invalidGrant",
            message: "AADSTS50126: Error validating credentials.",
            innerErrorCode: "invalidUserNameOrPassword",
            correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.validateInteraction(context: context, .success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(type: .invalidCredentials)))
    }
}
