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
    
    // MARK: - to toVerifyCodePublicError tests
    
    func test_toVerifyCodePublicError_invalidRequest() {
        testSignUpContinueErrorToVerifyCode(code: .invalidRequest, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_unauthorizedClient() {
        testSignUpContinueErrorToVerifyCode(code: .unauthorizedClient, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_invalidGrant() {
        testSignUpContinueErrorToVerifyCode(code: .invalidGrant, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_expiredToken() {
        testSignUpContinueErrorToVerifyCode(code: .expiredToken, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_passwordTooWeak() {
        testSignUpContinueErrorToVerifyCode(code: .passwordTooWeak, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_passwordTooShort() {
        testSignUpContinueErrorToVerifyCode(code: .passwordTooShort, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_passwordTooLong() {
        testSignUpContinueErrorToVerifyCode(code: .passwordTooLong, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_passwordRecentlyUsed() {
        testSignUpContinueErrorToVerifyCode(code: .passwordRecentlyUsed, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_passwordBanned() {
        testSignUpContinueErrorToVerifyCode(code: .passwordBanned, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_userAlreadyExists() {
        testSignUpContinueErrorToVerifyCode(code: .userAlreadyExists, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_attributesRequired() {
        testSignUpContinueErrorToVerifyCode(code: .attributesRequired, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_verificationRequired() {
        testSignUpContinueErrorToVerifyCode(code: .verificationRequired, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_attributeValidationFailed() {
        testSignUpContinueErrorToVerifyCode(code: .attributeValidationFailed, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_credentialRequired() {
        testSignUpContinueErrorToVerifyCode(code: .credentialRequired, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toVerifyCodePublicError_invalidOOBValue() {
        testSignUpContinueErrorToVerifyCode(code: .invalidOOBValue, description: testDescription, expectedErrorType: .invalidCode)
    }
    
    // MARK: - toPasswordRequiredPublicError tests
    
    func test_toPasswordRequiredPublicError_invalidRequest() {
        testSignUpContinueErrorToPasswordRequired(code: .invalidRequest, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_unauthorizedClient() {
        testSignUpContinueErrorToPasswordRequired(code: .unauthorizedClient, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_invalidGrant() {
        testSignUpContinueErrorToPasswordRequired(code: .invalidGrant, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_expiredToken() {
        testSignUpContinueErrorToPasswordRequired(code: .expiredToken, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_passwordTooWeak() {
        testSignUpContinueErrorToPasswordRequired(code: .passwordTooWeak, description: testDescription, expectedErrorType: .invalidPassword)
    }
    
    func test_toPasswordRequiredPublicError_passwordTooShort() {
        testSignUpContinueErrorToPasswordRequired(code: .passwordTooShort, description: testDescription, expectedErrorType: .invalidPassword)
    }
    
    func test_toPasswordRequiredPublicError_passwordTooLong() {
        testSignUpContinueErrorToPasswordRequired(code: .passwordTooLong, description: testDescription, expectedErrorType: .invalidPassword)
    }
    
    func test_toPasswordRequiredPublicError_passwordRecentlyUsed() {
        testSignUpContinueErrorToPasswordRequired(code: .passwordRecentlyUsed, description: testDescription, expectedErrorType: .invalidPassword)
    }
    
    func test_toPasswordRequiredPublicError_passwordBanned() {
        testSignUpContinueErrorToPasswordRequired(code: .passwordBanned, description: testDescription, expectedErrorType: .invalidPassword)
    }
    
    func test_toPasswordRequiredPublicError_userAlreadyExists() {
        testSignUpContinueErrorToPasswordRequired(code: .userAlreadyExists, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_attributesRequired() {
        testSignUpContinueErrorToPasswordRequired(code: .attributesRequired, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_verificationRequired() {
        testSignUpContinueErrorToPasswordRequired(code: .verificationRequired, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_attributeValidationFailed() {
        testSignUpContinueErrorToPasswordRequired(code: .attributeValidationFailed, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_credentialRequired() {
        testSignUpContinueErrorToPasswordRequired(code: .credentialRequired, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toPasswordRequiredPublicError_invalidOOBValue() {
        testSignUpContinueErrorToPasswordRequired(code: .invalidOOBValue, description: testDescription, expectedErrorType: .generalError)
    }
    
    // MARK: - toAttributesRequiredPublicError tests
    
    func test_toAttributesRequiredPublicError_invalidRequest() {
        testSignUpContinueErrorToAttributesRequired(code: .invalidRequest, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toAttributesRequiredPublicError_unauthorizedClient() {
        testSignUpContinueErrorToAttributesRequired(code: .unauthorizedClient, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toAttributesRequiredPublicError_invalidGrant() {
        testSignUpContinueErrorToAttributesRequired(code: .invalidGrant, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toAttributesRequiredPublicError_expiredToken() {
        testSignUpContinueErrorToAttributesRequired(code: .expiredToken, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toAttributesRequiredPublicError_passwordTooWeak() {
        testSignUpContinueErrorToAttributesRequired(code: .passwordTooWeak, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toAttributesRequiredPublicError_passwordTooShort() {
        testSignUpContinueErrorToAttributesRequired(code: .passwordTooShort, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toAttributesRequiredPublicError_passwordTooLong() {
        testSignUpContinueErrorToAttributesRequired(code: .passwordTooLong, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toAttributesRequiredPublicError_passwordRecentlyUsed() {
        testSignUpContinueErrorToAttributesRequired(code: .passwordRecentlyUsed, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toAttributesRequiredPublicError_passwordBanned() {
        testSignUpContinueErrorToAttributesRequired(code: .passwordBanned, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toAttributesRequiredPublicError_userAlreadyExists() {
        testSignUpContinueErrorToAttributesRequired(code: .userAlreadyExists, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toAttributesRequiredPublicError_attributesRequired() {
        testSignUpContinueErrorToAttributesRequired(code: .attributesRequired, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toAttributesRequiredPublicError_verificationRequired() {
        testSignUpContinueErrorToAttributesRequired(code: .verificationRequired, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toAttributesRequiredPublicError_attributeValidationFailed() {
        testSignUpContinueErrorToAttributesRequired(code: .attributeValidationFailed, description: testDescription, expectedErrorType: .invalidAttributes)
    }
    
    func test_toAttributesRequiredPublicError_credentialRequired() {
        testSignUpContinueErrorToAttributesRequired(code: .credentialRequired, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toAttributesRequiredPublicError_invalidOOBValue() {
        testSignUpContinueErrorToAttributesRequired(code: .invalidOOBValue, description: testDescription, expectedErrorType: .generalError)
    }
    
    // MARK: private methods
    
    private func testSignUpContinueErrorToVerifyCode(code: MSALNativeAuthSignUpContinueOauth2ErrorCode, description: String?, expectedErrorType: VerifyCodeErrorType) {
        sut = MSALNativeAuthSignUpContinueResponseError(error: code, errorDescription: description, errorCodes: nil, errorURI: nil, innerErrors: nil, signUpToken: nil, requiredAttributes: nil, unverifiedAttributes: nil, invalidAttributes: nil)
        let error = sut.toVerifyCodePublicError()
        XCTAssertEqual(error.type, expectedErrorType)
        XCTAssertEqual(error.errorDescription, description)
    }
    
    private func testSignUpContinueErrorToPasswordRequired(code: MSALNativeAuthSignUpContinueOauth2ErrorCode, description: String?, expectedErrorType: PasswordRequiredErrorType) {
        sut = MSALNativeAuthSignUpContinueResponseError(error: code, errorDescription: description, errorCodes: nil, errorURI: nil, innerErrors: nil, signUpToken: nil, requiredAttributes: nil, unverifiedAttributes: nil, invalidAttributes: nil)
        let error = sut.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, expectedErrorType)
        XCTAssertEqual(error.errorDescription, description)
    }
    
    private func testSignUpContinueErrorToAttributesRequired(code: MSALNativeAuthSignUpContinueOauth2ErrorCode, description: String?, expectedErrorType: AttributesRequiredErrorType) {
        sut = MSALNativeAuthSignUpContinueResponseError(error: code, errorDescription: description, errorCodes: nil, errorURI: nil, innerErrors: nil, signUpToken: nil, requiredAttributes: nil, unverifiedAttributes: nil, invalidAttributes: nil)
        let error = sut.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, expectedErrorType)
        XCTAssertEqual(error.errorDescription, description)
    }
}
