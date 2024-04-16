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

final class MSALNativeAuthSignUpContinueResponseErrorTests: XCTestCase {
    
    private var sut: MSALNativeAuthSignUpContinueResponseError!
    private let testDescription = "testDescription"
    private let testErrorCodes = [1, 2, 3]
    private let testCorrelationId = UUID()
    private let testErrorUri = "test error uri"

    // MARK: - to toVerifyCodePublicError tests
    
    func test_toVerifyCodePublicError_invalidRequest() {
        testSignUpContinueErrorToVerifyCode(code: .invalidRequest, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_unauthorizedClient() {
        testSignUpContinueErrorToVerifyCode(code: .unauthorizedClient, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_invalidGrant() {
        testSignUpContinueErrorToVerifyCode(code: .invalidGrant, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_expiredToken() {
        testSignUpContinueErrorToVerifyCode(code: .expiredToken, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_passwordTooWeak() {
        testSignUpContinueErrorToVerifyCode(code: .invalidGrant, subError: .passwordTooWeak, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_passwordTooShort() {
        testSignUpContinueErrorToVerifyCode(code: .invalidGrant, subError: .passwordTooShort, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_passwordTooLong() {
        testSignUpContinueErrorToVerifyCode(code: .invalidGrant, subError: .passwordTooLong, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_passwordRecentlyUsed() {
        testSignUpContinueErrorToVerifyCode(code: .invalidGrant, subError: .passwordRecentlyUsed, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_passwordBanned() {
        testSignUpContinueErrorToVerifyCode(code: .invalidGrant, subError: .passwordBanned, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_userAlreadyExists() {
        testSignUpContinueErrorToVerifyCode(code: .userAlreadyExists, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_attributesRequired() {
        testSignUpContinueErrorToVerifyCode(code: .attributesRequired, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_verificationRequired() {
        testSignUpContinueErrorToVerifyCode(code: .verificationRequired, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_attributeValidationFailed() {
        testSignUpContinueErrorToVerifyCode(code: .invalidGrant, subError: .attributeValidationFailed, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_credentialRequired() {
        testSignUpContinueErrorToVerifyCode(code: .credentialRequired, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_invalidOOBValue() {
        testSignUpContinueErrorToVerifyCode(code: .invalidGrant, subError: .invalidOOBValue, expectedErrorType: .invalidCode)
    }

    func test_toVerifyCodePublicError_errorUnknown() {
        testSignUpContinueErrorToVerifyCode(code: .unknown, expectedErrorType: .generalError)
    }

    func test_toVerifyCodePublicError_suberrorUnknown() {
        testSignUpContinueErrorToVerifyCode(code: .invalidGrant, subError: .unknown, expectedErrorType: .generalError)
    }

    // MARK: - toPasswordRequiredPublicError tests
    
    func test_toPasswordRequiredPublicError_invalidRequest() {
        testSignUpContinueErrorToPasswordRequired(code: .invalidRequest, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_unauthorizedClient() {
        testSignUpContinueErrorToPasswordRequired(code: .unauthorizedClient, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_invalidGrant() {
        testSignUpContinueErrorToPasswordRequired(code: .invalidGrant, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_expiredToken() {
        testSignUpContinueErrorToPasswordRequired(code: .expiredToken, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_passwordTooWeak() {
        testSignUpContinueErrorToPasswordRequired(code: .invalidGrant, subError: .passwordTooWeak, expectedErrorType: .invalidPassword)
    }
    
    func test_toPasswordRequiredPublicError_passwordTooShort() {
        testSignUpContinueErrorToPasswordRequired(code: .invalidGrant, subError: .passwordTooShort, expectedErrorType: .invalidPassword)
    }
    
    func test_toPasswordRequiredPublicError_passwordTooLong() {
        testSignUpContinueErrorToPasswordRequired(code: .invalidGrant, subError: .passwordTooLong, expectedErrorType: .invalidPassword)
    }
    
    func test_toPasswordRequiredPublicError_passwordRecentlyUsed() {
        testSignUpContinueErrorToPasswordRequired(code: .invalidGrant, subError: .passwordRecentlyUsed, expectedErrorType: .invalidPassword)
    }
    
    func test_toPasswordRequiredPublicError_passwordBanned() {
        testSignUpContinueErrorToPasswordRequired(code: .invalidGrant, subError: .passwordBanned, expectedErrorType: .invalidPassword)
    }
    
    func test_toPasswordRequiredPublicError_userAlreadyExists() {
        testSignUpContinueErrorToPasswordRequired(code: .userAlreadyExists, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_attributesRequired() {
        testSignUpContinueErrorToPasswordRequired(code: .attributesRequired, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_verificationRequired() {
        testSignUpContinueErrorToPasswordRequired(code: .verificationRequired, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_attributeValidationFailed() {
        testSignUpContinueErrorToPasswordRequired(code: .invalidGrant, subError: .attributeValidationFailed, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_credentialRequired() {
        testSignUpContinueErrorToPasswordRequired(code: .credentialRequired, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_invalidOOBValue() {
        testSignUpContinueErrorToPasswordRequired(code: .invalidGrant, subError: .invalidOOBValue, expectedErrorType: .generalError)
    }

    func test_toPasswordRequiredPublicError_errorUnknown() {
        testSignUpContinueErrorToPasswordRequired(code: .unknown, subError: .invalidOOBValue, expectedErrorType: .generalError)
    }

    func test_toPasswordRequiredPublicError_suberrorUnknown() {
        testSignUpContinueErrorToPasswordRequired(code: .invalidGrant, subError: .unknown, expectedErrorType: .generalError)
    }

    // MARK: - toAttributesRequiredPublicError tests
    
    func test_toAttributesRequiredPublicError_invalidRequest() {
        testSignUpContinueErrorToAttributesRequired(code: .invalidRequest)
    }
    
    func test_toAttributesRequiredPublicError_unauthorizedClien() {
        testSignUpContinueErrorToAttributesRequired(code: .unauthorizedClient)
    }
    
    func test_toAttributesRequiredPublicError_invalidGrant() {
        testSignUpContinueErrorToAttributesRequired(code: .invalidGrant)
    }
    
    func test_toAttributesRequiredPublicError_expiredToken() {
        testSignUpContinueErrorToAttributesRequired(code: .expiredToken)
    }
    
    func test_toAttributesRequiredPublicError_passwordTooWeak() {
        testSignUpContinueErrorToAttributesRequired(code: .invalidGrant, subError: .passwordTooWeak)
    }
    
    func test_toAttributesRequiredPublicError_passwordTooShort() {
        testSignUpContinueErrorToAttributesRequired(code: .invalidGrant, subError: .passwordTooShort)
    }
    
    func test_toAttributesRequiredPublicError_passwordTooLong() {
        testSignUpContinueErrorToAttributesRequired(code: .invalidGrant, subError: .passwordTooLong)
    }
    
    func test_toAttributesRequiredPublicError_passwordRecentlyUsed() {
        testSignUpContinueErrorToAttributesRequired(code: .invalidGrant, subError: .passwordRecentlyUsed)
    }
    
    func test_toAttributesRequiredPublicError_passwordBanned() {
        testSignUpContinueErrorToAttributesRequired(code: .invalidGrant, subError: .passwordBanned)
    }
    
    func test_toAttributesRequiredPublicError_userAlreadyExists() {
        testSignUpContinueErrorToAttributesRequired(code: .userAlreadyExists)
    }
    
    func test_toAttributesRequiredPublicError_attributesRequired() {
        testSignUpContinueErrorToAttributesRequired(code: .attributesRequired)
    }
    
    func test_toAttributesRequiredPublicError_verificationRequired() {
        testSignUpContinueErrorToAttributesRequired(code: .verificationRequired)
    }
    
    func test_toAttributesRequiredPublicError_attributeValidationFailed() {
        testSignUpContinueErrorToAttributesRequired(code: .invalidGrant, subError: .attributeValidationFailed)
    }
    
    func test_toAttributesRequiredPublicError_credentialRequired() {
        testSignUpContinueErrorToAttributesRequired(code: .credentialRequired)
    }
    
    func test_toAttributesRequiredPublicError_invalidOOBValue() {
        testSignUpContinueErrorToAttributesRequired(code: .invalidGrant, subError: .invalidOOBValue)
    }

    func test_toAttributesRequiredPublicError_errorUnknown() {
        testSignUpContinueErrorToAttributesRequired(code: .unknown, subError: .invalidOOBValue)
    }

    func test_toAttributesRequiredPublicError_suberrorUnknown() {
        testSignUpContinueErrorToAttributesRequired(code: .invalidGrant, subError: .unknown)
    }

    // MARK: private methods
    
    private func testSignUpContinueErrorToVerifyCode(code: MSALNativeAuthSignUpContinueOauth2ErrorCode, subError: MSALNativeAuthSubErrorCode? = nil, expectedErrorType: VerifyCodeError.ErrorType) {
        sut = MSALNativeAuthSignUpContinueResponseError(error: code, subError: subError, errorDescription: testDescription, errorCodes: testErrorCodes, errorURI: testErrorUri, correlationId: testCorrelationId)
        
        let error = sut.toVerifyCodePublicError(correlationId: testCorrelationId)
        XCTAssertEqual(error.type, expectedErrorType)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
    
    private func testSignUpContinueErrorToPasswordRequired(code: MSALNativeAuthSignUpContinueOauth2ErrorCode, subError: MSALNativeAuthSubErrorCode? = nil, expectedErrorType: PasswordRequiredError.ErrorType) {
        sut = MSALNativeAuthSignUpContinueResponseError(error: code, subError: subError, errorDescription: testDescription, errorCodes: testErrorCodes, errorURI: testErrorUri, correlationId: testCorrelationId)

        let error = sut.toPasswordRequiredPublicError(correlationId: testCorrelationId)
        XCTAssertEqual(error.type, expectedErrorType)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)

    }
    
    private func testSignUpContinueErrorToAttributesRequired(code: MSALNativeAuthSignUpContinueOauth2ErrorCode, subError: MSALNativeAuthSubErrorCode? = nil) {
        sut = MSALNativeAuthSignUpContinueResponseError(error: code, subError: subError, errorDescription: testDescription, errorCodes: testErrorCodes, errorURI: testErrorUri, correlationId: testCorrelationId)
        let error = sut.toAttributesRequiredPublicError(correlationId: testCorrelationId)

        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, testCorrelationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
}
