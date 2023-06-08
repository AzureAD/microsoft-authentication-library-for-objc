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

    func test_whenSignUpStart_verificationRequiredErrorWithSignUpToken_it_returns_verificationRequired() {
        let error = MSALNativeAuthSignUpStartResponseError(error: .verificationRequired, signUpToken: "sign-up token")
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)

        guard case .verificationRequired(let signUpToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(signUpToken, "sign-up token")
    }

    func test_whenSignUpStart_expectedVerificationRequiredErrorWithoutSignUpToken_it_returns_unexpectedError() {
        let error = MSALNativeAuthSignUpStartResponseError(error: .verificationRequired, signUpToken: nil)
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpStartErrorResponseIsExpected_it_returns_error() {
        let error = MSALNativeAuthSignUpStartResponseError(error: .userAlreadyExists)
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .error(.userAlreadyExists))
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

        guard case .successOOB(let displayName, let displayType, let codeLength, let signUpToken) = result else {
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

        guard case .successPassword(let signUpToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(signUpToken, "token")
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
        let error = MSALNativeAuthSignUpChallengeResponseError(error: .expiredToken)

        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .error(.expiredToken))
    }

    // MARK: - Continue Response

    func test_whenSignUpStartSuccessResponseContainsSLT_it_returns_success() {
        let response: Result<MSALNativeAuthSignUpContinueResponse, Error> = .success(
            .init(signinSLT: "<signin_slt here>", expiresIn: nil, signupToken: nil)
        )

        let result = sut.validate(response, with: context)

        guard case .success(let slt) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(slt, "<signin_slt here>")
    }

    func test_whenSignUpStartSuccessResponseButDoesNotContainSLT_it_returns_unexpectedError() throws {
        let response: Result<MSALNativeAuthSignUpContinueResponse, Error> = .success(
            .init(signinSLT: "<signin_slt>", expiresIn: nil, signupToken: nil)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .success("<signin_slt>"))
    }

    func test_whenSignUpContinueErrorResponseIsNotExpected_it_returns_unexpectedError() {
        let response: Result<MSALNativeAuthSignUpContinueResponse, Error> = .failure(NSError())

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError)
    }

    func test_whenSignUpContinueErrorResponseIs_invalidOOBValue_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidOOBValue, expectedSignUpToken: "sign-up-token")

        guard case .invalidUserInput(let error, let flowToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(error, .invalidOOBValue)
        XCTAssertEqual(flowToken, "sign-up-token")
    }

    func test_whenSignUpContinueErrorResponseIs_passwordTooWeak_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .passwordTooWeak, expectedSignUpToken: "sign-up-token")

        guard case .invalidUserInput(let error, let flowToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(error, .passwordTooWeak)
        XCTAssertEqual(flowToken, "sign-up-token")
    }

    func test_whenSignUpContinueErrorResponseIs_passwordTooShort_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .passwordTooShort, expectedSignUpToken: "sign-up-token")

        guard case .invalidUserInput(let error, let flowToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(error, .passwordTooShort)
        XCTAssertEqual(flowToken, "sign-up-token")
    }

    func test_whenSignUpContinueErrorResponseIs_passwordTooLong_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .passwordTooLong, expectedSignUpToken: "sign-up-token")

        guard case .invalidUserInput(let error, let flowToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(error, .passwordTooLong)
        XCTAssertEqual(flowToken, "sign-up-token")
    }

    func test_whenSignUpContinueErrorResponseIs_passwordRecentlyUsed_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .passwordRecentlyUsed, expectedSignUpToken: "sign-up-token")

        guard case .invalidUserInput(let error, let flowToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(error, .passwordRecentlyUsed)
        XCTAssertEqual(flowToken, "sign-up-token")
    }

    func test_whenSignUpContinueErrorResponseIs_passwordBanned_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .passwordBanned, expectedSignUpToken: "sign-up-token")

        guard case .invalidUserInput(let error, let flowToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(error, .passwordBanned)
        XCTAssertEqual(flowToken, "sign-up-token")
    }

    func test_whenSignUpContinueErrorResponseIs_attributeValidationFailed_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .attributeValidationFailed, expectedSignUpToken: "sign-up-token")

        guard case .invalidUserInput(let error, let flowToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(error, .attributeValidationFailed)
        XCTAssertEqual(flowToken, "sign-up-token")
    }

    func test_whenSignUpContinueErrorResponseIs_invalidAttributes_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidAttributes, expectedSignUpToken: "sign-up-token")

        guard case .invalidUserInput(let error, let flowToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(error, .invalidAttributes)
        XCTAssertEqual(flowToken, "sign-up-token")
    }

    func test_whenSignUpContinueErrorResponseIs_credentialRequired_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .credentialRequired, expectedSignUpToken: "sign-up-token")

        guard case .credentialRequired(let flowToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(flowToken, "sign-up-token")
    }

    func test_whenSignUpContinueErrorResponseIs_attributesRequired_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .attributesRequired, expectedSignUpToken: "sign-up-token")

        guard case .attributesRequired(let flowToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(flowToken, "sign-up-token")
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

        XCTAssertEqual(error, .invalidClient)
    }

    func test_whenSignUpContinueErrorResponseIs_invalidGrant_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidGrant)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(error, .invalidGrant)
    }

    func test_whenSignUpContinueErrorResponseIs_expiredToken_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .expiredToken)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(error, .expiredToken)
    }

    func test_whenSignUpContinueErrorResponseIs_invalidRequest_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidRequest)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(error, .invalidRequest)
    }

    func test_whenSignUpContinueErrorResponseIs_userAlreadyExists_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .userAlreadyExists)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(error, .userAlreadyExists)
    }

    private func buildContinueErrorResponse(
        expectedError: MSALNativeAuthSignUpContinueOauth2ErrorCode,
        expectedSignUpToken: String? = nil
    ) -> MSALNativeAuthSignUpContinueValidatedResponse {
        let response: Result<MSALNativeAuthSignUpContinueResponse, Error> = .failure(
            MSALNativeAuthSignUpContinueResponseError(
                error: expectedError,
                signUpToken: expectedSignUpToken
            )
        )

        return sut.validate(response, with: context)
    }
}
