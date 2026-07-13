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

final class MSALNativeAuthV2ResponseValidatorTests: XCTestCase {

    private var sut: MSALNativeAuthV2ResponseValidator!

    override func setUp() {
        super.setUp()
        sut = MSALNativeAuthV2ResponseValidator()
    }

    // MARK: - Builders

    private func makeResponse(
        statusCode: Int = 200,
        state: String? = nil,
        action: String? = nil,
        continuationToken: String? = nil,
        codeLength: Int? = nil,
        hint: String? = nil,
        methodId: String? = nil,
        methodType: String? = nil,
        attributes: [MSALNativeAuthHALResponse.RequiredAttributeEntry] = [],
        code: String? = nil,
        accessToken: String? = nil,
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
            methodId: methodId,
            methodType: methodType,
            attributes: attributes,
            code: code,
            accessToken: accessToken,
            links: links,
            methods: methods,
            error: error
        )
    }

    // MARK: - validateAuthorizeChallenge

    func test_validateAuthorizeChallenge_withContinuationToken() {
        let response = makeResponse(statusCode: 401, continuationToken: "ct", links: ["reset_password": "https://contoso.com/reset"])
        let result = sut.validateAuthorizeChallenge(.success(response), flowType: .resetPassword)
        XCTAssertEqual(result, .continuationToken(continuationToken: "ct", href: "https://contoso.com/reset"))
    }

    func test_validateAuthorizeChallenge_missingFlowLink_returnsError() {
        let response = makeResponse(statusCode: 401, continuationToken: "ct", links: ["reset_password": "https://contoso.com/reset"])
        let result = sut.validateAuthorizeChallenge(.success(response), flowType: .signUp)
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(
            kind: .generalError,
            errorDescription: "Invalid authorize-challenge response: missing 'sign_up' link"
        )))
    }

    func test_validateAuthorizeChallenge_withAuthorizationCode() {
        let response = makeResponse(code: "auth-code")
        let result = sut.validateAuthorizeChallenge(.success(response), flowType: .signIn)
        XCTAssertEqual(result, .authorizationCode(code: "auth-code"))
    }

    func test_validateAuthorizeChallenge_withServerError_returnsError() {
        let serverError = MSALNativeAuthHALResponse.ServerError(code: "invalidRequest", message: "bad", innerErrorCode: nil, correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.validateAuthorizeChallenge(.success(response), flowType: .signIn)
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(kind: .generalError)))
    }

    func test_validateAuthorizeChallenge_withTransportFailure_returnsError() {
        let result = sut.validateAuthorizeChallenge(.failure(ErrorMock.error), flowType: .signIn)
        guard case .error = result else {
            return XCTFail("Expected error")
        }
    }

    // MARK: - validateInteraction

    func test_validateInteraction_challengeAction_returnsChallengeRequired() {
        let method = MSALNativeAuthHALResponse.EmbeddedMethod(id: "1", type: "email", hint: "u***@contoso.com", links: ["challenge": "https://contoso.com/challenge"])
        let response = makeResponse(state: "interactionRequired", action: "challenge", continuationToken: "ct", methods: [method])
        let result = sut.validateInteraction(.success(response))
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
        let result = sut.validateInteraction(.success(response))
        XCTAssertEqual(result, .codeRequired(continuationToken: "ct", verifyHref: "https://contoso.com/verify", resendHref: "https://contoso.com/resend", sentTo: "u***@contoso.com", codeLength: 8))
    }

    func test_validateInteraction_updateAction_returnsUpdateRequired() {
        let response = makeResponse(state: "interactionRequired", action: "update", continuationToken: "ct", links: ["update": "https://contoso.com/update"])
        let result = sut.validateInteraction(.success(response))
        XCTAssertEqual(result, .updateRequired(continuationToken: "ct", updateHref: "https://contoso.com/update"))
    }

    func test_validateInteraction_pollAction_returnsPollInProgress() {
        let response = makeResponse(state: "interactionRequired", action: "poll", continuationToken: "ct", links: ["poll": "https://contoso.com/poll"])
        let result = sut.validateInteraction(.success(response))
        XCTAssertEqual(result, .pollInProgress(continuationToken: "ct", pollHref: "https://contoso.com/poll"))
    }

    func test_validateInteraction_updateAction_withoutUpdateLink_failsWithMissingLink() {
        let response = makeResponse(state: "interactionRequired", action: "update", continuationToken: "ct")
        let result = sut.validateInteraction(.success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(kind: .generalError)))
    }

    func test_validateInteraction_pollAction_withoutPollLink_failsWithMissingLink() {
        let response = makeResponse(state: "interactionRequired", action: "poll", continuationToken: "ct")
        let result = sut.validateInteraction(.success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(kind: .generalError)))
    }

    func test_validateInteraction_verifyAction_withoutVerifyLink_failsWithMissingLink() {
        let response = makeResponse(state: "interactionRequired", action: "verify", continuationToken: "ct", codeLength: 8, hint: "u***@contoso.com")
        let result = sut.validateInteraction(.success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(kind: .generalError)))
    }

    func test_validateInteraction_collectAttributesAction_withoutSubmitLink_failsWithMissingLink() {
        let response = makeResponse(state: "interactionRequired", action: "collectAttributes", continuationToken: "ct")
        let result = sut.validateInteraction(.success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(kind: .generalError)))
    }

    func test_validateInteraction_continueState_returnsReadyToComplete() {
        let response = makeResponse(state: "continue", continuationToken: "ct")
        let result = sut.validateInteraction(.success(response))
        XCTAssertEqual(result, .readyToComplete(continuationToken: "ct"))
    }

    func test_validateInteraction_userNotFound_mapsToUserNotFound() {
        let serverError = MSALNativeAuthHALResponse.ServerError(code: "invalidRequest", message: "AADSTS50034 user not found", innerErrorCode: nil, correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.validateInteraction(.success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(kind: .userNotFound)))
    }

    func test_validateInteraction_invalidGrant_mapsToInvalidCode() {
        let serverError = MSALNativeAuthHALResponse.ServerError(code: "invalidGrant", message: "wrong code", innerErrorCode: nil, correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.validateInteraction(.success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(kind: .invalidCode)))
    }

    func test_validateInteraction_invalidContinuationToken_mapsCorrectly() {
        let serverError = MSALNativeAuthHALResponse.ServerError(code: "invalidRequest", message: "bad token", innerErrorCode: "invalidContinuationToken", correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.validateInteraction(.success(response))
        XCTAssertEqual(result, .error(MSALNativeAuthFlowError(kind: .invalidContinuationToken)))
    }

    // MARK: - validateToken

    func test_validateToken_success() {
        let response = makeResponse(accessToken: "access-token")
        let result = sut.validateToken(.success(response))
        guard case .success(let accessToken) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(accessToken, "access-token")
    }

    func test_validateToken_withServerError_returnsError() {
        let serverError = MSALNativeAuthHALResponse.ServerError(code: "invalidGrant", message: "bad", innerErrorCode: nil, correlationId: nil)
        let response = makeResponse(error: serverError)
        let result = sut.validateToken(.success(response))
        guard case .error = result else {
            return XCTFail("Expected error")
        }
    }
}
