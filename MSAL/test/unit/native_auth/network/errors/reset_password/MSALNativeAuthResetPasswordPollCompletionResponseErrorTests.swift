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

final class MSALNativeAuthResetPasswordPollCompletionResponseErrorTests: XCTestCase {

    private var sut: MSALNativeAuthResetPasswordPollCompletionResponseError!
    private let testDescription = "testDescription"

    // MARK: - toPasswordRequiredPublicError tests
    
    func test_toPasswordRequiredPublicError_invalidRequest() {
        testPasswordRequiredError(code: .invalidRequest, description: testDescription, expectedErrorType: .generalError)
    }

    func test_toPasswordRequiredPublicError_invalidClient() {
        testPasswordRequiredError(code: .invalidClient, description: "General error", expectedErrorType: .generalError)
    }

    func test_toPasswordRequiredPublicError_expiredToken() {
        testPasswordRequiredError(code: .expiredToken, description: testDescription, expectedErrorType: .generalError)
    }

    func test_toPasswordRequiredPublicError_passwordTooWeak() {
        testPasswordRequiredError(code: .invalidGrant, subError: .passwordTooWeak, description: testDescription, expectedErrorType: .invalidPassword)
    }

    func test_toPasswordRequiredPublicError_passwordTooShort() {
        testPasswordRequiredError(code: .invalidGrant,subError: .passwordTooShort, description: testDescription, expectedErrorType: .invalidPassword)
    }

    func test_toPasswordRequiredPublicError_passwordTooLong() {
        testPasswordRequiredError(code: .invalidGrant, subError: .passwordTooLong, description: "General error", expectedErrorType: .invalidPassword)
    }

    func test_toPasswordRequiredPublicError_passwordRecentlyUsed() {
        testPasswordRequiredError(code: .invalidGrant, subError: .passwordRecentlyUsed, description: testDescription, expectedErrorType: .invalidPassword)
    }

    func test_toPasswordRequiredPublicError_passwordBanned() {
        testPasswordRequiredError(code: .invalidGrant, subError: .passwordBanned, description: testDescription, expectedErrorType: .invalidPassword)
    }
    
    func test_toPasswordRequiredPublicError_userNotFound() {
        testPasswordRequiredError(code: .userNotFound, description: testDescription, expectedErrorType: .generalError)
    }
    
    // MARK: private methods
    
    private func testPasswordRequiredError(code: MSALNativeAuthResetPasswordPollCompletionOauth2ErrorCode, subError: MSALNativeAuthSubErrorCode? = nil, description: String?, expectedErrorType: PasswordRequiredError.ErrorType) {
        sut = MSALNativeAuthResetPasswordPollCompletionResponseError(error: code, subError: subError, errorDescription: description, errorCodes: nil, errorURI: nil, innerErrors: nil, target: nil)
        let error = sut.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, expectedErrorType)
        XCTAssertEqual(error.errorDescription, description)
    }
}
