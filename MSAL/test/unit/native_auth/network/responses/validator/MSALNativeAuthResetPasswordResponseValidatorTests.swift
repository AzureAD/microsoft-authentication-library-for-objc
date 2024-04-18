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
            .init(continuationToken: "continuationToken", challengeType: .otp)
        )

        let result = sut.validate(response, with: context)

        guard case .success(let continuationToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(continuationToken, "continuationToken")
    }

    func test_whenResetPasswordStartErrorResponseIsNotExpected_itReturnsUnexpectedError() {
        let error = MSALNativeAuthResetPasswordStartResponseError(errorDescription: "API error message")
        let response: Result<MSALNativeAuthResetPasswordStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .error(.unexpectedError(.init(errorDescription: "API error message"))))
    }

    func test_whenResetPasswordStartErrorResponseUserNotFound_itReturnsRelatedError() {
        let error = MSALNativeAuthResetPasswordStartResponseError(error: .userNotFound)
        let response: Result<MSALNativeAuthResetPasswordStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        if case .error(.userNotFound) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenResetPasswordStartErrorResponseUnauthorizedClient_itReturnsRelatedError() {
        let error = MSALNativeAuthResetPasswordStartResponseError(error: .unauthorizedClient)
        let response: Result<MSALNativeAuthResetPasswordStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        if case .error(.unauthorizedClient) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenResetPasswordStartErrorResponseUnsupportedChallengeType_itReturnsRelatedError() {
        let error = MSALNativeAuthResetPasswordStartResponseError(error: .unsupportedChallengeType)
        let response: Result<MSALNativeAuthResetPasswordStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        if case .error(.unsupportedChallengeType) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenResetPasswordStartInvalidRequestUserDoesntHaveAPwd_itReturnsRelatedError() {
        let error = MSALNativeAuthResetPasswordStartResponseError(error: .invalidRequest, errorCodes: [500222])
        let response: Result<MSALNativeAuthResetPasswordStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        if case .error(.userDoesNotHavePassword) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenResetPasswordStartInvalidRequestGenericErrorCode_itReturnsRelatedError() {
        let error = MSALNativeAuthResetPasswordStartResponseError(error: .invalidRequest, errorCodes: [90023])
        let response: Result<MSALNativeAuthResetPasswordStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        if case .error(.invalidRequest) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenResetPasswordStartInvalidRequestNoErrorCode_itReturnsRelatedError() {
        let error = MSALNativeAuthResetPasswordStartResponseError(error: .invalidRequest)
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
            continuationToken: "token",
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
            continuationToken: "token",
            codeLength: 6)
        )

        let result = sut.validate(response, with: context)

        guard case .success(let sentTo, let channelTargetType, let codeLength, let continuationToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(sentTo, "challenge-type-label")
        XCTAssertEqual(channelTargetType, .email)
        XCTAssertEqual(codeLength, 6)
        XCTAssertEqual(continuationToken, "token")
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
        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "Unexpected response body received")))
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
        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedChallengeType)))
    }

    func test_whenResetPasswordChallengeErrorResponseIsNotExpected_itReturnsUnexpectedError() {
        let error = MSALNativeAuthResetPasswordChallengeResponseError(errorDescription: "API error message")
        let response: Result<MSALNativeAuthResetPasswordChallengeResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "API error message")))
    }

    func test_whenResetPasswordChallengeErrorResponseIsExpected_itReturnsError() {
        let error = MSALNativeAuthResetPasswordChallengeResponseError(error: .expiredToken)

        let response: Result<MSALNativeAuthResetPasswordChallengeResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .expiredToken = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    // MARK: - Continue Response

    func test_whenResetPasswordContinueSuccessResponseContainsValidAttributesAndOOB_itReturnsSuccess() {
        let response: Result<MSALNativeAuthResetPasswordContinueResponse, Error> = .success(.init(continuationToken: "continuationToken", expiresIn: 300))

        let result = sut.validate(response, with: context)

        guard case .success(let continuationToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(continuationToken, "continuationToken")
    }

    func test_whenResetPasswordContinueErrorResponseIsNotExpected_itReturnsUnexpectedError() {
        let error = MSALNativeAuthResetPasswordContinueResponseError(errorDescription: "API error message")
        let response: Result<MSALNativeAuthResetPasswordContinueResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "API error message")))
    }

    func test_whenResetPasswordContinueErrorResponseIs_invalidOOBValue_itReturnsExpectedError() {
        let apiError = MSALNativeAuthResetPasswordContinueResponseError(
            error: .invalidGrant,
            subError: .invalidOOBValue
        )
        let result = buildContinueErrorResponse(expectedError: .invalidGrant, expectedSubError: .invalidOOBValue)

        XCTAssertEqual(result, .invalidOOB(apiError))
    }

    func test_whenResetPasswordContinueErrorResponseIs_verificationRequired_itReturnsUnexpectedError() {
        let result = buildContinueErrorResponse(expectedError: .verificationRequired)

        XCTAssertEqual(result, .unexpectedError(nil))
    }

    func test_whenResetPasswordContinueErrorResponseIs_unauthorizedClient_itReturnsExpectedError() {
        let result = buildContinueErrorResponse(expectedError: .unauthorizedClient)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .unauthorizedClient = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordContinueErrorResponseIs_invalidGrant_itReturnsExpectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidGrant)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidGrant = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordContinueErrorResponseIs_expiredToken_itReturnsExpectedError() {
        let result = buildContinueErrorResponse(expectedError: .expiredToken)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .expiredToken = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordContinueErrorResponseIs_invalidRequest_itReturnsExpectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidRequest)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidRequest = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    // MARK: - Submit Response

    func test_whenResetPasswordSubmitSuccessResponseContainsToken_itReturnsSuccess() {
        let response: Result<MSALNativeAuthResetPasswordSubmitResponse, Error> = .success(.init(continuationToken: "continuationToken", pollInterval: 1))

        let result = sut.validate(response, with: context)

        guard case .success(let continuationToken, let pollInterval) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(continuationToken, "continuationToken")
        XCTAssertEqual(pollInterval, 1)
    }

    func test_whenResetPasswordSubmitErrorResponseIs_passwordTooWeak_itReturnsExpectedError() {
        let result = buildSubmitErrorResponse(expectedError: .invalidGrant, expectedSubError: .passwordTooWeak)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordTooWeak = error.subError {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordSubmitErrorResponseIs_passwordTooShort_itReturnsExpectedError() {
        let result = buildSubmitErrorResponse(expectedError: .invalidGrant, expectedSubError: .passwordTooShort)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordTooShort = error.subError {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordSubmitErrorResponseIs_passwordTooLong_itReturnsExpectedError() {
        let result = buildSubmitErrorResponse(expectedError: .invalidGrant, expectedSubError: .passwordTooLong)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordTooLong = error.subError {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordSubmitErrorResponseIs_passwordRecentlyUsed_itReturnsExpectedError() {
        let result = buildSubmitErrorResponse(expectedError: .invalidGrant, expectedSubError: .passwordRecentlyUsed)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordRecentlyUsed = error.subError {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordSubmitErrorResponseIs_passwordBanned_itReturnsExpectedError() {
        let result = buildSubmitErrorResponse(expectedError: .invalidGrant, expectedSubError: .passwordBanned)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordBanned = error.subError {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordSubmitErrorResponseIs_invalidRequest_itReturnsExpectedError() {
        let result = buildSubmitErrorResponse(expectedError: .invalidRequest)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidRequest = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordSubmitErrorResponseIs_unauthorizedClient_itReturnsExpectedError() {
        let result = buildSubmitErrorResponse(expectedError: .unauthorizedClient)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .unauthorizedClient = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordSubmitErrorResponseIs_expiredToken_itReturnsExpectedError() {
        let result = buildSubmitErrorResponse(expectedError: .expiredToken)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .expiredToken = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordSubmitErrorResponseIsNotExpected_itReturnsUnexpectedError() {
        let error = MSALNativeAuthResetPasswordSubmitResponseError(errorDescription: "API error message")
        let response: Result<MSALNativeAuthResetPasswordSubmitResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "API error message")))
    }

    // MARK: - Poll Completion Response

    func test_whenResetPasswordPollCompletionSuccessResponse_itReturnsSuccess() {
        let response: Result<MSALNativeAuthResetPasswordPollCompletionResponse, Error> = .success(.init(status: .succeeded, continuationToken: "continuationToken", expiresIn: nil))

        let result = sut.validate(response, with: context)

        guard case .success(let status, let continuationToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(status, .succeeded)
        XCTAssertEqual(continuationToken, "continuationToken")
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsPasswordTooWeak_itReturnsExpectedError() {
        let result = buildPollCompletionErrorResponse(expectedError: .invalidGrant, expectedSubError: .passwordTooWeak)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordTooWeak = error.subError {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsPasswordTooShort_itReturnsExpectedError() {
        let result = buildPollCompletionErrorResponse(expectedError: .invalidGrant, expectedSubError: .passwordTooShort)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordTooShort = error.subError {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsPasswordTooLong_itReturnsExpectedError() {
        let result = buildPollCompletionErrorResponse(expectedError: .invalidGrant, expectedSubError: .passwordTooLong)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordTooLong = error.subError {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsPasswordRecentlyUsed_itReturnsExpectedError() {
        let result = buildPollCompletionErrorResponse(expectedError: .invalidGrant, expectedSubError: .passwordRecentlyUsed)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordRecentlyUsed = error.subError {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsPasswordBanned_itReturnsExpectedError() {
        let result = buildPollCompletionErrorResponse(expectedError: .invalidGrant, expectedSubError: .passwordBanned)

        guard case .passwordError(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordBanned = error.subError {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsInvalidRequest_itReturnsExpectedError() {
        let result = buildPollCompletionErrorResponse(expectedError: .invalidRequest)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidRequest = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsUnauthorizedClient_itReturnsExpectedError() {
        let result = buildPollCompletionErrorResponse(expectedError: .unauthorizedClient)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .unauthorizedClient = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsExpiredToken_itReturnsExpectedError() {
        let result = buildPollCompletionErrorResponse(expectedError: .expiredToken)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .expiredToken = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenResetPasswordPollCompletionErrorResponseIsNotExpected_itReturnsUnexpectedError() {
        let error = MSALNativeAuthResetPasswordPollCompletionResponseError(errorDescription: "API error message")
        let response: Result<MSALNativeAuthResetPasswordPollCompletionResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "API error message")))
    }

    // MARK: - Helper methods

    private func buildContinueErrorResponse(
        expectedError: MSALNativeAuthResetPasswordContinueOauth2ErrorCode,
        expectedSubError: MSALNativeAuthSubErrorCode? = nil,
        expectedContinuationToken: String? = nil
    ) -> MSALNativeAuthResetPasswordContinueValidatedResponse {
        let response: Result<MSALNativeAuthResetPasswordContinueResponse, Error> = .failure(
            MSALNativeAuthResetPasswordContinueResponseError(
                error: expectedError,
                subError: expectedSubError,
                continuationToken: expectedContinuationToken
            )
        )

        return sut.validate(response, with: context)
    }

    private func buildSubmitErrorResponse(
        expectedError: MSALNativeAuthResetPasswordSubmitOauth2ErrorCode,
        expectedSubError: MSALNativeAuthSubErrorCode? = nil
    ) -> MSALNativeAuthResetPasswordSubmitValidatedResponse {
        let response: Result<MSALNativeAuthResetPasswordSubmitResponse, Error> = .failure(
            MSALNativeAuthResetPasswordSubmitResponseError(
                error: expectedError,
                subError: expectedSubError
            )
        )

        return sut.validate(response, with: context)
    }

    private func buildPollCompletionErrorResponse(
        expectedError: MSALNativeAuthResetPasswordPollCompletionOauth2ErrorCode,
        expectedSubError: MSALNativeAuthSubErrorCode? = nil
    ) -> MSALNativeAuthResetPasswordPollCompletionValidatedResponse {
        let response: Result<MSALNativeAuthResetPasswordPollCompletionResponse, Error> = .failure(
            MSALNativeAuthResetPasswordPollCompletionResponseError(
                error: expectedError,
                subError: expectedSubError
            )
        )

        return sut.validate(response, with: context)
    }
}
