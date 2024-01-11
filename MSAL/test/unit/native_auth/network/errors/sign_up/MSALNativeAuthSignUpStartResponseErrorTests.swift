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

    // MARK: - to toSignUpStartPublicError tests

    func test_toSignUpStartPublicError_invalidRequest() {
        testSignUpStartErrorToSignUpStart(code: .invalidRequest, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toSignUpStartPublicError_unauthorizedClient() {
        testSignUpStartErrorToSignUpStart(code: .unauthorizedClient, description: testDescription, expectedErrorType: .generalError)
    }

    func test_toSignUpStartPublicError_unsupportedChallengeType() {
        testSignUpStartErrorToSignUpStart(code: .unsupportedChallengeType, description: "General error", expectedErrorType: .generalError)
    }
    
    func test_toSignUpStartPublicError_passwordTooWeak() {
        testSignUpStartErrorToSignUpStart(code: .invalidGrant, subError: .passwordTooWeak, description: testDescription, expectedErrorType: .invalidPassword)
    }
    
    func test_toSignUpStartPublicError_passwordTooShort() {
        testSignUpStartErrorToSignUpStart(code: .invalidGrant, subError: .passwordTooShort, description: testDescription, expectedErrorType: .invalidPassword)
    }
    
    func test_toSignUpStartPublicError_passwordTooLong() {
        testSignUpStartErrorToSignUpStart(code: .invalidGrant, subError: .passwordTooLong, description: testDescription, expectedErrorType: .invalidPassword)
    }
    
    func test_toSignUpStartPublicError_passwordRecentlyUsed() {
        testSignUpStartErrorToSignUpStart(code: .invalidGrant, subError: .passwordRecentlyUsed, description: testDescription, expectedErrorType: .invalidPassword)
    }
    
    func test_toSignUpStartPublicError_passwordBanned() {
        testSignUpStartErrorToSignUpStart(code: .invalidGrant, subError: .passwordBanned, description: testDescription, expectedErrorType: .invalidPassword)
    }
    
    func test_toSignUpStartPublicError_userAlreadyExists() {
        testSignUpStartErrorToSignUpStart(code: .userAlreadyExists, description: testDescription, expectedErrorType: .userAlreadyExists)
    }
    
    func test_toSignUpStartPublicError_attributesRequired() {
        testSignUpStartErrorToSignUpStart(code: .attributesRequired, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toSignUpStartPublicError_unsupportedAuthMethod() {
        testSignUpStartErrorToSignUpStart(code: .unsupportedAuthMethod, description: testDescription, expectedErrorType: .generalError)
    }
    
    func test_toSignUpStartPublicError_attributeValidationFailed() {
        testSignUpStartErrorToSignUpStart(code: .invalidGrant, subError: .attributeValidationFailed, description: testDescription, expectedErrorType: .generalError)
    }

    // MARK: private methods
    
    private func testSignUpStartErrorToSignUpStart(code: MSALNativeAuthSignUpStartOauth2ErrorCode, subError: MSALNativeAuthSubErrorCode? = nil, description: String?, expectedErrorType: SignUpStartError.ErrorType) {
        sut = MSALNativeAuthSignUpStartResponseError(error: code, subError: subError, errorDescription: description, errorCodes: nil, errorURI: nil, innerErrors: nil, continuationToken: nil, unverifiedAttributes: nil, invalidAttributes: nil)
        let error = sut.toSignUpStartPublicError()
        XCTAssertEqual(error.type, expectedErrorType)
        XCTAssertEqual(error.errorDescription, description)
    }
}
