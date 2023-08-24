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

final class MSALNativeAuthSignUpResponseValidatorTests: XCTestCase {

    private var sut: MSALNativeAuthSignUpResponseValidator!
    private var context: MSIDRequestContext!

    override func setUpWithError() throws {
        try super.setUpWithError()

        sut = MSALNativeAuthSignUpResponseValidator()
        context = MSALNativeAuthRequestContextMock()
    }

    // MARK: - Start Response

    func test_whenSignUpStartSuccessResponseContainsRedirect_it_returns_redirect() {
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .success(
            .init(signupToken: nil, challengeType: .redirect)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .redirect)
    }

    func test_whenSignUpStartSuccessResponseDoesNotContainsTokenOrRedirect_it_returns_unexpectedError() {
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .success(
            .init(signupToken: nil, challengeType: .otp)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpStartErrorResponseIsNotExpected_it_returns_unexpectedError() {
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(NSError())

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpStart_verificationRequiredErrorWithSignUpTokenAndUnverifiedAttributes_it_returns_verificationRequired() {
        let error = createSignUpStartError(
            error: .verificationRequired,
            signUpToken: "sign-up token",
            unverifiedAttributes: [MSALNativeAuthErrorBasicAttributes(name: "username")]
        )
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)

        guard case .verificationRequired(let signUpToken, let unverifiedAttributes) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(signUpToken, "sign-up token")
        XCTAssertEqual(unverifiedAttributes.first, "username")
    }

    func test_whenSignUpStart_verificationRequiredErrorWithSignUpToken_but_unverifiedAttributesIsEmpty_it_returns_unexpectedError() {
        let error = createSignUpStartError(
            error: .verificationRequired,
            signUpToken: "sign-up token",
            unverifiedAttributes: []
        )
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpStart_verificationRequiredErrorWithSignUpToken_but_unverifiedAttributesIsNil_it_returns_unexpectedError() {
        let error = createSignUpStartError(
            error: .verificationRequired,
            signUpToken: "sign-up token",
            unverifiedAttributes: nil
        )
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpStart_attributeValidationFailedWithSignUpTokenAndInvalidAttributes_it_returns_attributeValidationFailed() {
        let error = createSignUpStartError(
            error: .attributeValidationFailed,
            invalidAttributes: [MSALNativeAuthErrorBasicAttributes(name: "city")]
        )
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)

        guard case .attributeValidationFailed(let invalidAttributes) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(invalidAttributes.first, "city")
    }

    func test_whenSignUpStart_attributeValidationFailedWithSignUpToken_but_invalidAttributesIsEmpty_it_returns_attributeValidationFailed() {
        let error = createSignUpStartError(
            error: .attributeValidationFailed,
            invalidAttributes: []
        )
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpStart_attributeValidationFailedWithSignUpToken_but_invalidAttributesIsNil_it_returns_attributeValidationFailed() {
        let error = createSignUpStartError(
            error: .verificationRequired,
            invalidAttributes: nil
        )
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpStart_expectedVerificationRequiredErrorWithoutSignUpToken_it_returns_unexpectedError() {
        let error = createSignUpStartError(error: .verificationRequired, signUpToken: nil)
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpStartErrorResponseIsExpected_it_returns_error() {
        let error = createSignUpStartError(error: .userAlreadyExists)
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .userAlreadyExists = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    // MARK: - Challenge Response

    func test_whenSignUpChallengeSuccessResponseDoesNotContainChallengeType_it_returns_unexpectedError() {
        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .success(.init(
            challengeType: nil,
            bindingMethod: nil,
            interval: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: nil,
            signUpToken: "token",
            codeLength: nil)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpChallengeSuccessResponseContainsRedirect_it_returns_redirect() {
        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .success(.init(
            challengeType: .redirect,
            bindingMethod: nil,
            interval: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: nil,
            signUpToken: "token",
            codeLength: nil)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .redirect)
    }

    func test_whenSignUpChallengeSuccessResponseContainsValidAttributesAndOOB_it_returns_success() {
        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .success(.init(
            challengeType: .oob,
            bindingMethod: nil,
            interval: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: .email,
            signUpToken: "token",
            codeLength: 6)
        )

        let result = sut.validate(response, with: context)

        guard case .codeRequired(let displayName, let displayType, let codeLength, let signUpToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(displayName, "challenge-type-label")
        XCTAssertEqual(displayType, .email)
        XCTAssertEqual(codeLength, 6)
        XCTAssertEqual(signUpToken, "token")
    }

    func test_whenSignUpChallengeSuccessResponseContainsValidAttributesAndPassword_it_returns_success() {
        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .success(.init(
            challengeType: .password,
            bindingMethod: nil,
            interval: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: .email,
            signUpToken: "token",
            codeLength: nil)
        )

        let result = sut.validate(response, with: context)

        guard case .passwordRequired(let signUpToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(signUpToken, "token")
    }

    func test_whenSignUpChallengeSuccessResponseContainsPassword_but_noToken_it_returns_unexpectedError() {
        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .success(.init(
            challengeType: .password,
            bindingMethod: nil,
            interval: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: .email,
            signUpToken: nil,
            codeLength: nil)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpChallengeSuccessResponseContainsValidAttributesAndOTP_it_returns_unexpectedError() {
        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .success(.init(
            challengeType: .otp,
            bindingMethod: nil,
            interval: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: nil,
            signUpToken: "token",
            codeLength: 6)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpChallengeSuccessResponseOmitsSomeAttributes_it_returns_unexpectedError() {
        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .success(.init(
            challengeType: .oob,
            bindingMethod: nil,
            interval: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: nil,
            signUpToken: nil,
            codeLength: 6)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpChallengeErrorResponseIsNotExpected_it_returns_unexpectedError() {
        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .failure(NSError())

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpChallengeErrorResponseIsExpected_it_returns_error() {
        let error = createSignUpChallengeError(error: .expiredToken)

        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .expiredToken = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    // MARK: - Continue Response

    func test_whenSignUpStartSuccessResponseContainsSLT_it_returns_success() {
        let response: Result<MSALNativeAuthSignUpContinueResponse, Error> = .success(
            .init(signinSLT: "<signin_slt>", expiresIn: nil, signupToken: nil)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .success("<signin_slt>"))
    }

    func test_whenSignUpStartSuccessResponseButDoesNotContainSLT_it_returns_successWithNoSLT() throws {
        let response: Result<MSALNativeAuthSignUpContinueResponse, Error> = .success(
            .init(signinSLT: nil, expiresIn: nil, signupToken: nil)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .success(nil))
    }

    func test_whenSignUpContinueErrorResponseIsNotExpected_it_returns_unexpectedError() {
        let response: Result<MSALNativeAuthSignUpContinueResponse, Error> = .failure(NSError())

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpContinueErrorResponseIs_invalidOOBValue_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidOOBValue, expectedSignUpToken: "sign-up-token")

        guard case .invalidUserInput(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidOOBValue = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_passwordTooWeak_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .passwordTooWeak, expectedSignUpToken: "sign-up-token")

        guard case .invalidUserInput(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordTooWeak = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_passwordTooShort_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .passwordTooShort, expectedSignUpToken: "sign-up-token")

        guard case .invalidUserInput(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordTooShort = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_passwordTooLong_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .passwordTooLong, expectedSignUpToken: "sign-up-token")

        guard case .invalidUserInput(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordTooLong = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_passwordRecentlyUsed_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .passwordRecentlyUsed, expectedSignUpToken: "sign-up-token")

        guard case .invalidUserInput(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordRecentlyUsed = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_passwordBanned_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .passwordBanned, expectedSignUpToken: "sign-up-token")

        guard case .invalidUserInput(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .passwordBanned = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_attributeValidationFailed_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .attributeValidationFailed, expectedSignUpToken: "sign-up-token", invalidAttributes: [MSALNativeAuthErrorBasicAttributes(name: "email")])

        guard case .attributeValidationFailed(let signUpToken, let invalidAttributes) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(signUpToken, "sign-up-token")
        XCTAssertEqual(invalidAttributes.first, "email")
    }

    func test_whenSignUpContinueErrorResponseIs_attributeValidationFailed_but_signUpTokenIsNil_it_returns_unexpectedError() {
        let result = buildContinueErrorResponse(expectedError: .attributeValidationFailed, expectedSignUpToken: nil, invalidAttributes: [MSALNativeAuthErrorBasicAttributes(name: "email")])

        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpContinueErrorResponseIs_attributeValidationFailed_but_invalidAttributesIsNil_it_returns_unexpectedError() {
        let result = buildContinueErrorResponse(expectedError: .attributeValidationFailed, invalidAttributes: nil)

        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpContinueErrorResponseIs_attributeValidationFailed_but_invalidAttributesIsEmpty_it_returns_unexpectedError() {
        let result = buildContinueErrorResponse(expectedError: .attributeValidationFailed, invalidAttributes: [])

        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpContinueErrorResponseIs_credentialRequired_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .credentialRequired, expectedSignUpToken: "sign-up-token")

        guard case .credentialRequired(let signUpToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(signUpToken, "sign-up-token")
    }

    func test_whenSignUpContinueErrorResponseIs_credentialRequired_but_signUpToken_isNil_it_returns_unexpectedError() {
        let result = buildContinueErrorResponse(expectedError: .credentialRequired, expectedSignUpToken: nil)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpContinueErrorResponseIs_attributesRequired_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .attributesRequired, expectedSignUpToken: "sign-up-token", requiredAttributes: [.init(name: "email", type: "", required: true), .init(name: "city", type: "", required: false)])

        guard case .attributesRequired(let signUpToken, let requiredAttributes) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(signUpToken, "sign-up-token")
        XCTAssertEqual(requiredAttributes.count, 2)
        XCTAssertEqual(requiredAttributes[0].name, "email")
        XCTAssertEqual(requiredAttributes[1].name, "city")
    }

    func test_whenSignUpContinueErrorResponseIs_attributesRequired_but_signUpToken_IsNil_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .attributesRequired, expectedSignUpToken: nil, requiredAttributes: [.init(name: "email", type: "", required: true), .init(name: "city", type: "", required: false)])

        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpContinueErrorResponseIs_attributesRequired_but_requiredAttributesIsNil_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .attributesRequired, expectedSignUpToken: "sign-up-token", requiredAttributes: nil)

        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpContinueErrorResponseIs_attributesRequired_but_requiredAttributes_IsEmpty_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .attributesRequired, expectedSignUpToken: "sign-up-token", requiredAttributes: [])

        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpContinueErrorResponseIs_verificationRequired_it_returns_unexpectedError() {
        let result = buildContinueErrorResponse(expectedError: .attributesRequired)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpContinueErrorResponseIs_invalidClient_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidClient)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidClient = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_invalidGrant_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidGrant)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidGrant = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_expiredToken_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .expiredToken)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .expiredToken = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_invalidRequest_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidRequest)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidRequest = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_userAlreadyExists_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .userAlreadyExists)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .userAlreadyExists = error.error {} else {
            XCTFail("Unexpected error: \(error.error)")
        }
    }

    private func buildContinueErrorResponse(
        expectedError: MSALNativeAuthSignUpContinueOauth2ErrorCode,
        expectedSignUpToken: String? = nil,
        requiredAttributes: [MSALNativeAuthErrorRequiredAttributes]? = nil,
        invalidAttributes: [MSALNativeAuthErrorBasicAttributes]? = nil
    ) -> MSALNativeAuthSignUpContinueValidatedResponse {
        let response: Result<MSALNativeAuthSignUpContinueResponse, Error> = .failure(
            createSignUpContinueError(
                error: expectedError,
                signUpToken: expectedSignUpToken,
                requiredAttributes: requiredAttributes,
                invalidAttributes: invalidAttributes
            )
        )

        return sut.validate(response, with: context)
    }

    private func createSignUpStartError(
        error: MSALNativeAuthSignUpStartOauth2ErrorCode,
        errorDescription: String? = nil,
        errorCodes: [Int]? = nil,
        errorURI: String? = nil,
        innerErrors: [MSALNativeAuthInnerError]? = nil,
        signUpToken: String? = nil,
        unverifiedAttributes: [MSALNativeAuthErrorBasicAttributes]? = nil,
        invalidAttributes: [MSALNativeAuthErrorBasicAttributes]? = nil
    ) -> MSALNativeAuthSignUpStartResponseError {
        .init(
            error: error,
            errorDescription: errorDescription,
            errorCodes: errorCodes,
            errorURI: errorURI,
            innerErrors: innerErrors,
            signUpToken: signUpToken,
            unverifiedAttributes: unverifiedAttributes,
            invalidAttributes: invalidAttributes
        )
    }

    private func createSignUpChallengeError(
        error: MSALNativeAuthSignUpChallengeOauth2ErrorCode,
        errorDescription: String? = nil,
        errorCodes: [Int]? = nil,
        errorURI: String? = nil,
        innerErrors: [MSALNativeAuthInnerError]? = nil
    ) -> MSALNativeAuthSignUpChallengeResponseError {
        .init(
            error: error,
            errorDescription: errorDescription,
            errorCodes: errorCodes,
            errorURI: errorURI,
            innerErrors: innerErrors
        )
    }

    private func createSignUpContinueError(
        error: MSALNativeAuthSignUpContinueOauth2ErrorCode,
        errorDescription: String? = nil,
        errorCodes: [Int]? = nil,
        errorURI: String? = nil,
        innerErrors: [MSALNativeAuthInnerError]? = nil,
        signUpToken: String? = nil,
        requiredAttributes: [MSALNativeAuthErrorRequiredAttributes]? = nil,
        unverifiedAttributes: [[String: String]]? = nil,
        invalidAttributes: [MSALNativeAuthErrorBasicAttributes]? = nil
    ) -> MSALNativeAuthSignUpContinueResponseError {
        .init(
            error: error,
            errorDescription: errorDescription,
            errorCodes: errorCodes,
            errorURI: errorURI,
            innerErrors: innerErrors,
            signUpToken: signUpToken,
            requiredAttributes: requiredAttributes,
            unverifiedAttributes: unverifiedAttributes,
            invalidAttributes: invalidAttributes
        )
    }
}
