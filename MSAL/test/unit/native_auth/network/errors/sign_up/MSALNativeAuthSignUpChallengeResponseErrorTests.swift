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

final class MSALNativeAuthSignUpChallengeResponseErrorTests: XCTestCase {

    private var sut: MSALNativeAuthSignUpChallengeResponseError!
    private let testDescription = "testDescription"

    // MARK: - to SignUpCodeStartError tests

    func test_toSignUpCodeStartPublicError_unauthorizedClient() {
        testSignUpChallengeErrorToSignUpStart(code: .unauthorizedClient, description: testDescription, expectedErrorType: .generalError)
    }

    func test_toSignUpCodeStartPublicError_unsupportedChallengeType() {
        testSignUpChallengeErrorToSignUpStart(code: .unsupportedChallengeType, description: "General error", expectedErrorType: .generalError)
    }

    func test_toSignUpCodeStartPublicError_expiredToken() {
        testSignUpChallengeErrorToSignUpStart(code: .expiredToken, description: testDescription, expectedErrorType: .generalError)
    }

    func test_toSignUpCodeStartPublicError_invalidRequest() {
        testSignUpChallengeErrorToSignUpStart(code: .invalidRequest, description: testDescription, expectedErrorType: .generalError)
    }

    // MARK: - to ResendCodeError tests

    func test_toResendCodePublicError_unauthorizedClient() {
        testSignUpChallengeErrorToResendCodePublic(code: .unauthorizedClient, description: testDescription)
    }

    func test_toResendCodePublicError_unsupportedChallengeType() {
        testSignUpChallengeErrorToResendCodePublic(code: .unsupportedChallengeType, description: "General error")
    }

    func test_toResendCodePublicError_expiredToken() {
        testSignUpChallengeErrorToResendCodePublic(code: .expiredToken, description: testDescription)
    }

    func test_toResendCodePublicError_invalidRequest() {
        testSignUpChallengeErrorToResendCodePublic(code: .invalidRequest, description: testDescription)
    }

    // MARK: - to PasswordRequiredError tests

    func test_toPasswordRequiredPublicError_unauthorizedClient() {
        testSignUpChallengeErrorToPasswordRequired(code: .unauthorizedClient, description: testDescription, expectedErrorType: .generalError)
    }

    func test_toPasswordRequiredPublicError_unsupportedChallengeType() {
        testSignUpChallengeErrorToPasswordRequired(code: .unsupportedChallengeType, description: "General error", expectedErrorType: .generalError)
    }

    func test_toPasswordRequiredPublicError_expiredToken() {
        testSignUpChallengeErrorToPasswordRequired(code: .expiredToken, description: testDescription, expectedErrorType: .generalError)
    }

    func test_toPasswordRequiredPublicError_invalidRequest() {
        testSignUpChallengeErrorToPasswordRequired(code: .invalidRequest, description: testDescription, expectedErrorType: .generalError)
    }
        
    // MARK: private methods
    
    private func testSignUpChallengeErrorToSignUpStart(code: MSALNativeAuthSignUpChallengeOauth2ErrorCode, description: String?, expectedErrorType: SignUpStartError.ErrorType) {
        sut = MSALNativeAuthSignUpChallengeResponseError(error: code, errorDescription: description, errorCodes: nil, errorURI: nil, innerErrors: nil)
        let error = sut.toSignUpStartPublicError()
        XCTAssertEqual(error.type, expectedErrorType)
        XCTAssertEqual(error.errorDescription, description)
    }
    
    private func testSignUpChallengeErrorToResendCodePublic(code: MSALNativeAuthSignUpChallengeOauth2ErrorCode, description: String?) {
        sut = MSALNativeAuthSignUpChallengeResponseError(error: code, errorDescription: description, errorCodes: nil, errorURI: nil, innerErrors: nil)
        let error = sut.toResendCodePublicError()
        XCTAssertEqual(error.errorDescription, description)
    }
    
    private func testSignUpChallengeErrorToPasswordRequired(code: MSALNativeAuthSignUpChallengeOauth2ErrorCode, description: String?, expectedErrorType: PasswordRequiredError.ErrorType) {
        sut = MSALNativeAuthSignUpChallengeResponseError(error: code, errorDescription: description, errorCodes: nil, errorURI: nil, innerErrors: nil)
        let error = sut.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, expectedErrorType)
        XCTAssertEqual(error.errorDescription, description)
    }
    
}
