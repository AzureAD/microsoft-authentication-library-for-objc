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

final class MSALNativeAuthSignUpStartResponseErrorTests: XCTestCase {

    private var sut: MSALNativeAuthSignUpStartResponseError!
    private let testDescription = "testDescription"

    // MARK: - to toSignUpStartPasswordPublicError tests

    func test_toSignUpStartPasswordPublicError_invalidRequest() {
        testSignUpStartErrorToSignUpStartPassword(code: .invalidRequest, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toSignUpStartPasswordPublicError_invalidClient() {
        testSignUpStartErrorToSignUpStartPassword(code: .invalidClient, description: testDescription, expectedErrorType: .generalError)
    }

    func test_toSignUpStartPasswordPublicError_unsupportedChallengeType() {
        testSignUpStartErrorToSignUpStartPassword(code: .unsupportedChallengeType, description: "General error", expectedErrorType: .generalError)
    }

    func test_toSignUpStartPasswordPublicError_passwordTooWeak() {
        testSignUpStartErrorToSignUpStartPassword(code: .passwordTooWeak, description: testDescription, expectedErrorType: .invalidPassword)
    }
    
    func test_toSignUpStartPasswordPublicError_passwordTooShort() {
        testSignUpStartErrorToSignUpStartPassword(code: .passwordTooShort, description: testDescription, expectedErrorType: .invalidPassword)
    }
    
    func test_toSignUpStartPasswordPublicError_passwordTooLong() {
        testSignUpStartErrorToSignUpStartPassword(code: .passwordTooLong, description: testDescription, expectedErrorType: .invalidPassword)
    }
    
    func test_toSignUpStartPasswordPublicError_passwordRecentlyUsed() {
        testSignUpStartErrorToSignUpStartPassword(code: .passwordRecentlyUsed, description: testDescription, expectedErrorType: .invalidPassword)
    }
    
    func test_toSignUpStartPasswordPublicError_passwordBanned() {
        testSignUpStartErrorToSignUpStartPassword(code: .passwordBanned, description: testDescription, expectedErrorType: .invalidPassword)
    }
    
    func test_toSignUpStartPasswordPublicError_userAlreadyExists() {
        testSignUpStartErrorToSignUpStartPassword(code: .userAlreadyExists, description: testDescription, expectedErrorType: .userAlreadyExists)
    }
    
    func test_toSignUpStartPasswordPublicError_attributesRequired() {
        testSignUpStartErrorToSignUpStartPassword(code: .attributesRequired, description: testDescription, expectedErrorType: .invalidAttributes)
    }
    
    func test_toSignUpStartPasswordPublicError_verificationRequired() {
        testSignUpStartErrorToSignUpStartPassword(code: .verificationRequired, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toSignUpStartPasswordPublicError_authNotSupported() {
        testSignUpStartErrorToSignUpStartPassword(code: .authNotSupported, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toSignUpStartPasswordPublicError_attributeValidationFailed() {
        testSignUpStartErrorToSignUpStartPassword(code: .attributeValidationFailed, description: testDescription, expectedErrorType: .invalidAttributes)
    }

    // MARK: - to toSignUpStartPublicError tests

    func test_toSignUpStartPublicError_invalidRequest() {
        testSignUpStartErrorToSignUpStart(code: .invalidRequest, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toSignUpStartPublicError_invalidClient() {
        testSignUpStartErrorToSignUpStart(code: .invalidClient, description: testDescription, expectedErrorType: .generalError)
    }

    func test_toSignUpStartPublicError_unsupportedChallengeType() {
        testSignUpStartErrorToSignUpStart(code: .unsupportedChallengeType, description: "General error", expectedErrorType: .generalError)
    }
    
    func test_toSignUpStartPublicError_passwordTooWeak() {
        testSignUpStartErrorToSignUpStart(code: .passwordTooWeak, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toSignUpStartPublicError_passwordTooShort() {
        testSignUpStartErrorToSignUpStart(code: .passwordTooShort, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toSignUpStartPublicError_passwordTooLong() {
        testSignUpStartErrorToSignUpStart(code: .passwordTooLong, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toSignUpStartPublicError_passwordRecentlyUsed() {
        testSignUpStartErrorToSignUpStart(code: .passwordRecentlyUsed, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toSignUpStartPublicError_passwordBanned() {
        testSignUpStartErrorToSignUpStart(code: .passwordBanned, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toSignUpStartPublicError_userAlreadyExists() {
        testSignUpStartErrorToSignUpStart(code: .userAlreadyExists, description: testDescription, expectedErrorType: .userAlreadyExists)
    }
    
    func test_toSignUpStartPublicError_attributesRequired() {
        testSignUpStartErrorToSignUpStart(code: .attributesRequired, description: testDescription, expectedErrorType: .invalidAttributes)
    }
    
    func test_toSignUpStartPublicError_verificationRequired() {
        testSignUpStartErrorToSignUpStart(code: .verificationRequired, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toSignUpStartPublicError_authNotSupported() {
        testSignUpStartErrorToSignUpStart(code: .authNotSupported, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toSignUpStartPublicError_attributeValidationFailed() {
        testSignUpStartErrorToSignUpStart(code: .attributeValidationFailed, description: testDescription, expectedErrorType: .invalidAttributes)
    }

    // MARK: private methods
    
    private func testSignUpStartErrorToSignUpStartPassword(code: MSALNativeAuthSignUpStartOauth2ErrorCode, description: String?, expectedErrorType: SignUpPasswordStartErrorType) {
        sut = MSALNativeAuthSignUpStartResponseError(error: code, errorDescription: description, errorCodes: nil, errorURI: nil, innerErrors: nil, signUpToken: nil, unverifiedAttributes: nil, invalidAttributes: nil)
        let error = sut.toSignUpStartPasswordPublicError()
        XCTAssertEqual(error.type, expectedErrorType)
        XCTAssertEqual(error.errorDescription, description)
    }
    
    private func testSignUpStartErrorToSignUpStart(code: MSALNativeAuthSignUpStartOauth2ErrorCode, description: String?, expectedErrorType: SignUpStartErrorType) {
        sut = MSALNativeAuthSignUpStartResponseError(error: code, errorDescription: description, errorCodes: nil, errorURI: nil, innerErrors: nil, signUpToken: nil, unverifiedAttributes: nil, invalidAttributes: nil)
        let error = sut.toSignUpStartPublicError()
        XCTAssertEqual(error.type, expectedErrorType)
        XCTAssertEqual(error.errorDescription, description)
    }
}
