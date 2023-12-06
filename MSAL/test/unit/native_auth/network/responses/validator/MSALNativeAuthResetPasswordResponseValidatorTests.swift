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

final class MSALNativeAuthResetPasswordResponseValidatorTests: XCTestCase {

    private var sut: MSALNativeAuthResetPasswordResponseValidator!
    private var context: MSIDRequestContext!

    override func setUpWithError() throws {
        try super.setUpWithError()

        sut = MSALNativeAuthResetPasswordResponseValidator()
        context = MSALNativeAuthRequestContextMock()
    }

    // MARK: - Start Response

    func test_whenResetPasswordStartSuccessResponseContainsRedirect_itReturnsRedirect() {
        let response: Result<MSALNativeAuthResetPasswordStartResponse, Error> = .success(
            .init(continuationToken: nil, challengeType: .redirect)
        )

        let result = sut.validate(response, with: context)
        if case .redirect = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenResetPasswordStartSuccessResponseDoesNotContainsTokenOrRedirect_itReturnsUnexpectedError() {
        let response: Result<MSALNativeAuthResetPasswordStartResponse, Error> = .success(
            .init(continuationToken: nil, challengeType: .otp)
        )

        let result = sut.validate(response, with: context)
        if case .unexpectedError = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenResetPasswordStartSuccessResponseContainsToken_itReturnsSuccess() {
        let response: Result<MSALNativeAuthResetPasswordStartResponse, Error> = .success(
            .init(continuationToken: "<continuation_token>", challengeType: .otp)
        )

        let result = sut.validate(response, with: context)

        guard case .success(let continuationToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(continuationToken, "<continuation_token>")
    }

    func test_whenResetPasswordStartErrorResponseIsNotExpected_itReturnsUnexpectedError() {
        let response: Result<MSALNativeAuthResetPasswordStartResponse, Error> = .failure(NSError())

        let result = sut.validate(response, with: context)
        if case .unexpectedError = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenResetPasswordStartErrorResponseUserNotFound_itReturnsRelatedError() {
        let error = createResetPasswordStartError(error: .userNotFound)
        let response: Result<MSALNativeAuthResetPasswordStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        if case .error(.userNotFound) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenResetPasswordStartErrorResponseInvalidClient_itReturnsRelatedError() {
        let error = createResetPasswordStartError(error: .invalidClient)
        let response: Result<MSALNativeAuthResetPasswordStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        if case .error(.invalidClient) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenResetPasswordStartErrorResponseUnsupportedChallengeType_itReturnsRelatedError() {
        let error = createResetPasswordStartError(error: .unsupportedChallengeType)
        let response: Result<MSALNativeAuthResetPasswordStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        if case .error(.unsupportedChallengeType) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenResetPasswordStartInvalidRequestUserDoesntHaveAPwd_itReturnsRelatedError() {
        let error = createResetPasswordStartError(error: .invalidRequest, errorCodes: [500222])
        let response: Result<MSALNativeAuthResetPasswordStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        if case .error(.userDoesNotHavePassword) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenResetPasswordStartInvalidRequestGenericErrorCode_itReturnsRelatedError() {
        let error = createResetPasswordStartError(error: .invalidRequest, errorCodes: [90023])
        let response: Result<MSALNativeAuthResetPasswordStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        if case .error(.invalidRequest) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenResetPasswordStartInvalidRequestNoErrorCode_itReturnsRelatedError() {
        let error = createResetPasswordStartError(error: .invalidRequest)
        let response: Result<MSALNativeAuthResetPasswordStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        if case .error(.invalidRequest) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    // MARK: - Challenge Response

    func test_whenResetPasswordChallengeSuccessResponseContainsRedirect_itReturnsRedirect() {
        let response: Result<MSALNativeAuthResetPasswordChallengeResponse, Error> = .success(.init(
            challengeType: .redirect,
            bindingMethod: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: .email,
            continuationToken: "<continuation_token>",
            codeLength: nil)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .redirect)
    }

    func test_whenResetPasswordChallengeSuccessResponseContainsValidAttributesAndOOB_itReturnsSuccess() {
        let response: Result<MSALNativeAuthResetPasswordChallengeResponse, Error> = .success(.init(
            challengeType: .oob,
            bindingMethod: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: .email,
            continuationToken: "<continuation_token>",
            codeLength: 6)
        )

        let result = sut.validate(response, with: context)

        guard case .success(let sentTo, let channelTargetType, let codeLength, let continuationToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(sentTo, "challenge-type-label")
        XCTAssertEqual(channelTargetType, .email)
        XCTAssertEqual(codeLength, 6)
        XCTAssertEqual(continuationToken, "<continuation_token>")
    }

    func test_whenResetPasswordChallengeSuccessResponseOmitsSomeAttributes_itReturnsUnexpectedError() {
        let response: Result<MSALNativeAuthResetPasswordChallengeResponse, Error> = .success(.init(
            challengeType: .oob,
            bindingMethod: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: .email,
            continuationToken: nil,
            codeLength: 6)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenResetPasswordChallengeSuccessResponseHasInvalidChallengeChannel_itReturnsUnexpectedError() {
        let response: Result<MSALNativeAuthResetPasswordChallengeResponse, Error> = .success(.init(
            challengeType: .otp,
            bindingMethod: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: .none,
            continuationToken: nil,
            codeLength: 6)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenResetPasswordChallengeErrorResponseIsNotExpected_itReturnsUnexpectedError() {
        let response: Result<MSALNativeAuthResetPasswordChallengeResponse, Error> = .failure(NSError())

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenResetPasswordChallengeErrorResponseIsExpected_itReturnsError() {
        let error = createResetPasswordChallengeError(error: .expiredToken)

        let response: Result<MSALNativeAuthResetPasswordChallengeResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .expiredToken = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    // MARK: - Continue Response

    func test_whenResetPasswordContinueSuccessResponseContainsValidAttributesAndOOB_itReturnsSuccess() {
        let response: Result<MSALNativeAuthResetPasswordContinueResponse, Error> = .success(.init(continuationToken: "<continuation_token>", expiresIn: 300))

        let result = sut.validate(response, with: context)

        guard case .success(let continuationToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(continuationToken, "<continuation_token>")
    }

    func test_whenResetPasswordContinueErrorResponseIsNotExpected_itReturnsUnexpectedError() {
        let response: Result<MSALNativeAuthResetPasswordContinueResponse, Error> = .failure(NSError())

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenResetPasswordContinueErrorResponseIs_invalidOOBValue_itReturnsExpectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidOOBValue)

        XCTAssertEqual(result, .invalidOOB)
    }

    func test_whenResetPasswordContinueErrorResponseIs_verificationRequired_itReturnsUnexpectedError() {
        let result = buildContinueErrorResponse(expectedError: .verificationRequired)

        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenResetPasswordContinueErrorResponseIs_invalidClient_itReturnsExpectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidClient)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidClient = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordContinueErrorResponseIs_invalidGrant_itReturnsExpectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidGrant)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidGrant = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordContinueErrorResponseIs_expiredToken_itReturnsExpectedError() {
        let result = buildContinueErrorResponse(expectedError: .expiredToken)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .expiredToken = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordContinueErrorResponseIs_invalidRequest_itReturnsExpectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidRequest)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidRequest = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    // MARK: - Submit Response

    func test_whenResetPasswordSubmitSuccessResponseContainsToken_itReturnsSuccess() {
        let response: Result<MSALNativeAuthResetPasswordSubmitResponse, Error> = .success(.init(continuationToken: "<continuation_token>", pollInterval: 1))

        let result = sut.validate(response, with: context)

        guard case .success(let continuationToken, let pollInterval) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(continuationToken, "<continuation_token>")
        XCTAssertEqual(pollInterval, 1)
    }

    func test_whenResetPasswordSubmitErrorResponseIs_passwordTooWeak_itReturnsExpectedError() {
        let result = buildSubmitErrorResponse(expectedError: .passwordTooWeak)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordTooWeak = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordSubmitErrorResponseIs_passwordTooShort_itReturnsExpectedError() {
        let result = buildSubmitErrorResponse(expectedError: .passwordTooShort)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordTooShort = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordSubmitErrorResponseIs_passwordTooLong_itReturnsExpectedError() {
        let result = buildSubmitErrorResponse(expectedError: .passwordTooLong)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordTooLong = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordSubmitErrorResponseIs_passwordRecentlyUsed_itReturnsExpectedError() {
        let result = buildSubmitErrorResponse(expectedError: .passwordRecentlyUsed)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordRecentlyUsed = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordSubmitErrorResponseIs_passwordBanned_itReturnsExpectedError() {
        let result = buildSubmitErrorResponse(expectedError: .passwordBanned)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordBanned = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordSubmitErrorResponseIs_invalidRequest_itReturnsExpectedError() {
        let result = buildSubmitErrorResponse(expectedError: .invalidRequest)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidRequest = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordSubmitErrorResponseIs_invalidClient_itReturnsExpectedError() {
        let result = buildSubmitErrorResponse(expectedError: .invalidClient)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidClient = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordSubmitErrorResponseIs_expiredToken_itReturnsExpectedError() {
        let result = buildSubmitErrorResponse(expectedError: .expiredToken)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .expiredToken = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordSubmitErrorResponseIsNotExpected_itReturnsUnexpectedError() {
        let response: Result<MSALNativeAuthResetPasswordSubmitResponse, Error> = .failure(NSError())

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    // MARK: - Poll Completion Response

    func test_whenResetPasswordPollCompletionSuccessResponse_itReturnsSuccess() {
        let response: Result<MSALNativeAuthResetPasswordPollCompletionResponse, Error> = .success(.init(status: .succeeded, continuationToken: nil, expiresIn: nil))

        let result = sut.validate(response, with: context)

        guard case .success(let status) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(status, .succeeded)
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsPasswordTooWeak_itReturnsExpectedError() {
        let result = buildPollCompletionErrorResponse(expectedError: .passwordTooWeak)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordTooWeak = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsPasswordTooShort_itReturnsExpectedError() {
        let result = buildPollCompletionErrorResponse(expectedError: .passwordTooShort)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordTooShort = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsPasswordTooLong_itReturnsExpectedError() {
        let result = buildPollCompletionErrorResponse(expectedError: .passwordTooLong)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordTooLong = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsPasswordRecentlyUsed_itReturnsExpectedError() {
        let result = buildPollCompletionErrorResponse(expectedError: .passwordRecentlyUsed)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordRecentlyUsed = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsPasswordBanned_itReturnsExpectedError() {
        let result = buildPollCompletionErrorResponse(expectedError: .passwordBanned)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordBanned = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsInvalidRequest_itReturnsExpectedError() {
        let result = buildPollCompletionErrorResponse(expectedError: .invalidRequest)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidRequest = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsInvalidClient_itReturnsExpectedError() {
        let result = buildPollCompletionErrorResponse(expectedError: .invalidClient)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidClient = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsExpiredToken_itReturnsExpectedError() {
        let result = buildPollCompletionErrorResponse(expectedError: .expiredToken)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .expiredToken = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsNotExpected_itReturnsUnexpectedError() {
        let response: Result<MSALNativeAuthResetPasswordPollCompletionResponse, Error> = .failure(NSError())

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    // MARK: - Helper methods

    private func buildContinueErrorResponse(
        expectedError: MSALNativeAuthResetPasswordContinueOauth2ErrorCode,
        expectedContinuationToken: String? = nil
    ) -> MSALNativeAuthResetPasswordContinueValidatedResponse {
        let response: Result<MSALNativeAuthResetPasswordContinueResponse, Error> = .failure(
            createResetPasswordContinueError(
                error: expectedError,
                continuationToken: expectedContinuationToken
            )
        )

        return sut.validate(response, with: context)
    }

    private func buildSubmitErrorResponse(
        expectedError: MSALNativeAuthResetPasswordSubmitOauth2ErrorCode
    ) -> MSALNativeAuthResetPasswordSubmitValidatedResponse {
        let response: Result<MSALNativeAuthResetPasswordSubmitResponse, Error> = .failure(
            createResetPasswordSubmitError(
                error: expectedError
            )
        )

        return sut.validate(response, with: context)
    }

    private func buildPollCompletionErrorResponse(
        expectedError: MSALNativeAuthResetPasswordPollCompletionOauth2ErrorCode
    ) -> MSALNativeAuthResetPasswordPollCompletionValidatedResponse {
        let response: Result<MSALNativeAuthResetPasswordPollCompletionResponse, Error> = .failure(
            createResetPasswordPollCompletionError(
                error: expectedError
            )
        )

        return sut.validate(response, with: context)
    }

    private func createResetPasswordStartError(
        error: MSALNativeAuthResetPasswordStartOauth2ErrorCode,
        errorDescription: String? = nil,
        errorCodes: [Int]? = nil,
        errorURI: String? = nil,
        innerErrors: [MSALNativeAuthInnerError]? = nil,
        target: String? = nil
    ) -> MSALNativeAuthResetPasswordStartResponseError {
        .init(
            error: error,
            errorDescription: errorDescription,
            errorCodes: errorCodes,
            errorURI: errorURI,
            innerErrors: innerErrors,
            target: target
        )
    }

    private func createResetPasswordChallengeError(
        error: MSALNativeAuthResetPasswordChallengeOauth2ErrorCode,
        errorDescription: String? = nil,
        errorCodes: [Int]? = nil,
        errorURI: String? = nil,
        innerErrors: [MSALNativeAuthInnerError]? = nil,
        target: String? = nil
    ) -> MSALNativeAuthResetPasswordChallengeResponseError {
        .init(
            error: error,
            errorDescription: errorDescription,
            errorCodes: errorCodes,
            errorURI: errorURI,
            innerErrors: innerErrors,
            target: target
        )
    }

    private func createResetPasswordContinueError(
        error: MSALNativeAuthResetPasswordContinueOauth2ErrorCode,
        errorDescription: String? = nil,
        errorCodes: [Int]? = nil,
        errorURI: String? = nil,
        innerErrors: [MSALNativeAuthInnerError]? = nil,
        target: String? = nil,
        continuationToken: String? = nil
    ) -> MSALNativeAuthResetPasswordContinueResponseError {
        .init(
            error: error,
            errorDescription: errorDescription,
            errorCodes: errorCodes,
            errorURI: errorURI,
            innerErrors: innerErrors,
            target: target,
            continuationToken: continuationToken
        )
    }

    private func createResetPasswordSubmitError(
        error: MSALNativeAuthResetPasswordSubmitOauth2ErrorCode,
        errorDescription: String? = nil,
        errorCodes: [Int]? = nil,
        errorURI: String? = nil,
        innerErrors: [MSALNativeAuthInnerError]? = nil,
        target: String? = nil
    ) -> MSALNativeAuthResetPasswordSubmitResponseError {
        .init(
            error: error,
            errorDescription: errorDescription,
            errorCodes: errorCodes,
            errorURI: errorURI,
            innerErrors: innerErrors,
            target: target
        )
    }

    private func createResetPasswordPollCompletionError(
        error: MSALNativeAuthResetPasswordPollCompletionOauth2ErrorCode,
        errorDescription: String? = nil,
        errorCodes: [Int]? = nil,
        errorURI: String? = nil,
        innerErrors: [MSALNativeAuthInnerError]? = nil,
        target: String? = nil
    ) -> MSALNativeAuthResetPasswordPollCompletionResponseError {
        .init(
            error: error,
            errorDescription: errorDescription,
            errorCodes: errorCodes,
            errorURI: errorURI,
            innerErrors: innerErrors,
            target: target
        )
    }
}
