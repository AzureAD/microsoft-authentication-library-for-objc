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
            .init(continuationToken: nil, challengeType: .redirect)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .redirect)
    }

    func test_whenSignUpStartSuccessResponseDoesNotContainsTokenOrRedirect_it_returns_unexpectedError() {
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .success(
            .init(continuationToken: nil, challengeType: .otp)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "Unexpected response body received")))
    }

    func test_whenSignUpStartErrorResponseIsNotExpected_it_returns_unexpectedError() {
        let error = MSALNativeAuthSignUpStartResponseError(errorDescription: "API error message")
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "API error message")))
    }

    func test_whenSignUpStart_succeedsWithContinuationToken_it_returns_success() {
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .success(.init(continuationToken: "continuation-token", challengeType: nil))

        let result = sut.validate(response, with: context)

        guard case let .success(continuationToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(continuationToken, "continuation-token")
    }

    func test_whenSignUpStart_attributeValidationFailed_it_returns_attributeValidationFailed() {
        let error = MSALNativeAuthSignUpStartResponseError(
            error: .invalidGrant,
            subError: .attributeValidationFailed,
            invalidAttributes: [MSALNativeAuthErrorBasicAttribute(name: "city")]
        )
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)

        guard case .attributeValidationFailed(_, let invalidAttributes) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(invalidAttributes.first, "city")
    }

    func test_whenSignUpStart_attributeValidationFailed_but_invalidAttributesIsEmpty_it_returns_attributeValidationFailed() {
        let error = MSALNativeAuthSignUpStartResponseError(
            error: .invalidGrant,
            subError: .attributeValidationFailed,
            invalidAttributes: []
        )
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError(.init(error: .invalidGrant, subError: .attributeValidationFailed, invalidAttributes: [])))
    }

    func test_whenSignUpStart_attributeValidationFailed_but_invalidAttributesIsNil_it_returns_attributeValidationFailed() {
        let error = MSALNativeAuthSignUpStartResponseError(
            error: .invalidGrant,
            subError: .attributeValidationFailed,
            invalidAttributes: nil
        )
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError(.init(error: .invalidGrant, subError: .attributeValidationFailed)))
    }

    func test_whenSignUpStartErrorResponseIsExpected_it_returns_error() {
        let error = MSALNativeAuthSignUpStartResponseError(error: .userAlreadyExists)
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .userAlreadyExists = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenSignUpStartErrorResponseIs_invalidRequestWithInvalidUsernameErrorDescription_it_returns_expectedError() {
        let attributes = [MSALNativeAuthErrorBasicAttribute(name: "attribute")]
        let errorCodes = [MSALNativeAuthESTSApiErrorCodes.invalidRequestParameter.rawValue, Int.max]

        let apiError = MSALNativeAuthSignUpStartResponseError(
            error: .invalidRequest,
            errorDescription: "username parameter is empty or not valid",
            errorCodes: errorCodes,
            errorURI: "aURI",
            continuationToken: "aToken",
            unverifiedAttributes: attributes,
            invalidAttributes: attributes
        )
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(apiError)

        let result = sut.validate(response, with: context)
        guard case .invalidUsername(let error) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(error as MSALNativeAuthSignUpStartResponseError, apiError)
    }
    
    func test_whenSignUpStartErrorResponseIs_invalidRequestWithUnauthorizedClientErrorDescription_it_returns_expectedError() {
        let attributes = [MSALNativeAuthErrorBasicAttribute(name: "attribute")]
        let errorCodes = [MSALNativeAuthESTSApiErrorCodes.invalidRequestParameter.rawValue, Int.max]
        
        let apiError = MSALNativeAuthSignUpStartResponseError(
            error: .invalidRequest,
            errorDescription: "client_id parameter is empty or not valid",
            errorCodes: errorCodes,
            errorURI: "aURI",
            continuationToken: "aToken",
            unverifiedAttributes: attributes,
            invalidAttributes: attributes
        )
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(apiError)
        
        let result = sut.validate(response, with: context)
        guard case .unauthorizedClient(let error) = result else {
            return XCTFail("Unexpected response")
        }
        
        XCTAssertEqual(error as MSALNativeAuthSignUpStartResponseError, apiError)
    }

    func test_whenSignUpStartErrorResponseIs_invalidRequestWithGenericErrorCode_it_returns_expectedError() {
        let attributes = [MSALNativeAuthErrorBasicAttribute(name: "attribute")]
        let errorCodes = [Int.max]

        let apiError = MSALNativeAuthSignUpStartResponseError(
            error: .invalidRequest,
            errorDescription: "aDescription",
            errorCodes: errorCodes,
            errorURI: "aURI",
            continuationToken: "aToken",
            unverifiedAttributes: attributes,
            invalidAttributes: attributes
        )
        let response: Result<MSALNativeAuthSignUpStartResponse, Error> = .failure(apiError)

        let result = sut.validate(response, with: context)
        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }

        let resultError = error as MSALNativeAuthSignUpStartResponseError
        XCTAssertEqual(resultError.error, .invalidRequest)
        XCTAssertEqual(resultError.errorDescription, "aDescription")
        XCTAssertEqual(resultError.errorCodes, errorCodes)
        XCTAssertEqual(resultError.errorURI, "aURI")
        XCTAssertEqual(resultError.continuationToken, "aToken")
        XCTAssertEqual(resultError.unverifiedAttributes, attributes)
        XCTAssertEqual(resultError.invalidAttributes, attributes)
    }

    // MARK: - Challenge Response

    func test_whenSignUpChallengeSuccessResponseDoesNotContainChallengeType_it_returns_unexpectedError() {
        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .success(.init(
            challengeType: nil,
            bindingMethod: nil,
            interval: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: nil,
            continuationToken: "token",
            codeLength: nil)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "Unexpected response body received")))
    }

    func test_whenSignUpChallengeSuccessResponseContainsRedirect_it_returns_redirect() {
        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .success(.init(
            challengeType: .redirect,
            bindingMethod: nil,
            interval: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: nil,
            continuationToken: "token",
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
            continuationToken: "token",
            codeLength: 6)
        )

        let result = sut.validate(response, with: context)

        guard case .codeRequired(let displayName, let displayType, let codeLength, let continuationToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(displayName, "challenge-type-label")
        XCTAssertEqual(displayType, .email)
        XCTAssertEqual(codeLength, 6)
        XCTAssertEqual(continuationToken, "token")
    }

    func test_whenSignUpChallengeSuccessResponseContainsValidAttributesAndPassword_it_returns_success() {
        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .success(.init(
            challengeType: .password,
            bindingMethod: nil,
            interval: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: .email,
            continuationToken: "token",
            codeLength: nil)
        )

        let result = sut.validate(response, with: context)

        guard case .passwordRequired(let continuationToken) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(continuationToken, "token")
    }

    func test_whenSignUpChallengeSuccessResponseContainsPassword_but_noToken_it_returns_unexpectedError() {
        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .success(.init(
            challengeType: .password,
            bindingMethod: nil,
            interval: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: .email,
            continuationToken: nil,
            codeLength: nil)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "Unexpected response body received")))
    }

    func test_whenSignUpChallengeSuccessResponseContainsValidAttributesAndOTP_it_returns_unexpectedError() {
        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .success(.init(
            challengeType: .otp,
            bindingMethod: nil,
            interval: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: nil,
            continuationToken: "token",
            codeLength: 6)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "Unexpected response body received")))
    }

    func test_whenSignUpChallengeSuccessResponseOmitsSomeAttributes_it_returns_unexpectedError() {
        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .success(.init(
            challengeType: .oob,
            bindingMethod: nil,
            interval: nil,
            challengeTargetLabel: "challenge-type-label",
            challengeChannel: nil,
            continuationToken: nil,
            codeLength: 6)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "Unexpected response body received")))
    }

    func test_whenSignUpChallengeErrorResponseIsNotExpected_it_returns_unexpectedError() {
        let error = MSALNativeAuthSignUpChallengeResponseError(
            error: .unknown,
            errorDescription: "API error message"
        )
        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError(.init(error: .unknown, errorDescription: "API error message")))
    }

    func test_whenSignUpChallengeErrorResponseIsExpected_it_returns_error() {
        let error = MSALNativeAuthSignUpChallengeResponseError(error: .expiredToken)

        let response: Result<MSALNativeAuthSignUpChallengeResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .expiredToken = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    // MARK: - Continue Response

    func test_whenSignUpStartSuccessResponseContainsContinuationToken_it_returns_success() {
        let response: Result<MSALNativeAuthSignUpContinueResponse, Error> = .success(
            .init(continuationToken: "<continuationToken>", expiresIn: nil)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .success(continuationToken: "<continuationToken>"))
    }

    func test_whenSignUpStartSuccessResponseButDoesNotContainContinuationToken_it_returns_successWithNoContinuationToken() throws {
        let response: Result<MSALNativeAuthSignUpContinueResponse, Error> = .success(
            .init(continuationToken: nil, expiresIn: nil)
        )

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .success(continuationToken: nil))
    }

    func test_whenSignUpContinueErrorResponseIsNotExpected_it_returns_unexpectedError() {
        let error = MSALNativeAuthSignUpContinueResponseError(errorDescription: "API error message")
        let response: Result<MSALNativeAuthSignUpContinueResponse, Error> = .failure(error)

        let result = sut.validate(response, with: context)
        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "API error message")))
    }

    func test_whenSignUpContinueErrorResponseIs_invalidOOBValue_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidGrant, expectedSubError: .invalidOOBValue, expectedContinuationToken: "continuation-token")

        guard case .invalidUserInput(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidGrant = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
        if case .invalidOOBValue = error.subError {} else {
            XCTFail("Unexpected suberror: \(String(describing: error.subError))")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_passwordTooWeak_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidGrant, expectedSubError: .passwordTooWeak, expectedContinuationToken: "continuation-token")

        guard case .invalidUserInput(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidGrant = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
        if case .passwordTooWeak = error.subError {} else {
            XCTFail("Unexpected suberror: \(String(describing: error.subError))")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_passwordTooShort_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidGrant, expectedSubError: .passwordTooShort, expectedContinuationToken: "continuation-token")

        guard case .invalidUserInput(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidGrant = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
        if case .passwordTooShort = error.subError {} else {
            XCTFail("Unexpected suberror: \(String(describing: error.subError))")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_passwordTooLong_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidGrant, expectedSubError: .passwordTooLong, expectedContinuationToken: "continuation-token")

        guard case .invalidUserInput(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidGrant = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
        if case .passwordTooLong = error.subError {} else {
            XCTFail("Unexpected suberror: \(String(describing: error.subError))")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_passwordRecentlyUsed_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidGrant, expectedSubError: .passwordRecentlyUsed, expectedContinuationToken: "continuation-token")

        guard case .invalidUserInput(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidGrant = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
        if case .passwordRecentlyUsed = error.subError {} else {
            XCTFail("Unexpected suberror: \(String(describing: error.subError))")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_passwordBanned_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidGrant, expectedSubError: .passwordBanned, expectedContinuationToken: "continuation-token")

        guard case .invalidUserInput(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidGrant = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
        if case .passwordBanned = error.subError {} else {
            XCTFail("Unexpected suberror: \(String(describing: error.subError))")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_attributeValidationFailed_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidGrant, expectedSubError: .attributeValidationFailed, invalidAttributes: [MSALNativeAuthErrorBasicAttribute(name: "email")])

        guard case .attributeValidationFailed(_, let invalidAttributes) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(invalidAttributes.first, "email")
    }
    
    func test_whenSignUpContinueErrorResponseIs_invalidRequest_it_returns_generalError() {
        let result = buildContinueErrorResponse(expectedError: .invalidRequest)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidRequest = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_attributeValidationFailed_but_invalidAttributesIsNil_it_returns_unexpectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidGrant, expectedSubError: .attributeValidationFailed, invalidAttributes: nil)

        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "Unexpected response body received")))
    }

    func test_whenSignUpContinueErrorResponseIs_attributeValidationFailed_but_invalidAttributesIsEmpty_it_returns_unexpectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidGrant, expectedSubError: .attributeValidationFailed, invalidAttributes: [])

        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "Unexpected response body received")))
    }

    func test_whenSignUpContinueErrorResponseIs_credentialRequired_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .credentialRequired, expectedContinuationToken: "continuation-token")

        guard case .credentialRequired(let continuationToken, _) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(continuationToken, "continuation-token")
    }

    func test_whenSignUpContinueErrorResponseIs_credentialRequired_but_continuationToken_isNil_it_returns_unexpectedError() {
        let result = buildContinueErrorResponse(expectedError: .credentialRequired, expectedContinuationToken: nil)
        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "Unexpected response body received")))
    }

    func test_whenSignUpContinueErrorResponseIs_attributesRequired_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .attributesRequired, expectedContinuationToken: "continuation-token", requiredAttributes: [.init(name: "email", type: "", required: true), .init(name: "city", type: "", required: false)])

        guard case .attributesRequired(let continuationToken, let requiredAttributes, _) = result else {
            return XCTFail("Unexpected response")
        }

        XCTAssertEqual(continuationToken, "continuation-token")
        XCTAssertEqual(requiredAttributes.count, 2)
        XCTAssertEqual(requiredAttributes[0].name, "email")
        XCTAssertEqual(requiredAttributes[1].name, "city")
    }

    func test_whenSignUpContinueErrorResponseIs_attributesRequired_but_continuationToken_IsNil_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .attributesRequired, expectedContinuationToken: nil, requiredAttributes: [.init(name: "email", type: "", required: true), .init(name: "city", type: "", required: false)])

        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "Unexpected response body received")))
    }

    func test_whenSignUpContinueErrorResponseIs_attributesRequired_but_requiredAttributesIsNil_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .attributesRequired, expectedContinuationToken: "continuation-token", requiredAttributes: nil)

        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "Unexpected response body received")))
    }

    func test_whenSignUpContinueErrorResponseIs_attributesRequired_but_requiredAttributes_IsEmpty_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .attributesRequired, expectedContinuationToken: "continuation-token", requiredAttributes: [])

        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "Unexpected response body received")))
    }

    func test_whenSignUpContinueErrorResponseIs_verificationRequired_it_returns_unexpectedError() {
        let result = buildContinueErrorResponse(expectedError: .attributesRequired)
        XCTAssertEqual(result, .unexpectedError(.init(errorDescription: "Unexpected response body received")))
    }

    func test_whenSignUpContinueErrorResponseIs_unauthorizedClient_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .unauthorizedClient)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .unauthorizedClient = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_invalidGrant_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidGrant)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidGrant = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_expiredToken_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .expiredToken)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .expiredToken = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_invalidRequest_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .invalidRequest)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .invalidRequest = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    func test_whenSignUpContinueErrorResponseIs_userAlreadyExists_it_returns_expectedError() {
        let result = buildContinueErrorResponse(expectedError: .userAlreadyExists)

        guard case .error(let error) = result else {
            return XCTFail("Unexpected response")
        }
        if case .userAlreadyExists = error.error {} else {
            XCTFail("Unexpected error: \(error.error.rawValue)")
        }
    }

    private func buildContinueErrorResponse(
        expectedError: MSALNativeAuthSignUpContinueOauth2ErrorCode,
        expectedSubError: MSALNativeAuthSubErrorCode? = nil,
        expectedContinuationToken: String? = nil,
        requiredAttributes: [MSALNativeAuthRequiredAttributeInternal]? = nil,
        invalidAttributes: [MSALNativeAuthErrorBasicAttribute]? = nil,
        errorCodes: [Int]? = nil
    ) -> MSALNativeAuthSignUpContinueValidatedResponse {
        let response: Result<MSALNativeAuthSignUpContinueResponse, Error> = .failure(
            MSALNativeAuthSignUpContinueResponseError(
                error: expectedError,
                subError: expectedSubError,
                errorCodes: errorCodes,
                continuationToken: expectedContinuationToken,
                requiredAttributes: requiredAttributes,
                invalidAttributes: invalidAttributes
            )
        )

        return sut.validate(response, with: context)
    }
}
