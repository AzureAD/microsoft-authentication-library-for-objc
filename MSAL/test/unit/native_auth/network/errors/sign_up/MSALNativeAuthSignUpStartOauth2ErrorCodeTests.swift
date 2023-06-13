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

final class MSALNativeAuthSignUpStartOauth2ErrorCodeTests: XCTestCase {

    private typealias sut = MSALNativeAuthSignUpStartOauth2ErrorCode

    func test_allCases() {
        XCTAssertEqual(sut.allCases.count, 13)
    }

    // MARK: - to SignUpPasswordStartError tests

    func test_toSignUpStartPasswordPublicError_invalidClient() {
        let error = sut.invalidClient.toSignUpStartPasswordPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.invalidClient)
    }

    func test_toSignUpStartPasswordPublicError_unsupportedChallengeType() {
        let error = sut.unsupportedChallengeType.toSignUpStartPasswordPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.unsupportedChallengeType)
    }

    func test_toSignUpStartPasswordPublicError_passwordTooWeak() {
        let error = sut.passwordTooWeak.toSignUpStartPasswordPublicError()
        XCTAssertEqual(error.type, .invalidPassword)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.passwordTooWeak)
    }

    func test_toSignUpStartPasswordPublicError_passwordTooShort() {
        let error = sut.passwordTooShort.toSignUpStartPasswordPublicError()
        XCTAssertEqual(error.type, .invalidPassword)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.passwordTooShort)
    }

    func test_toSignUpStartPasswordPublicError_passwordTooLong() {
        let error = sut.passwordTooLong.toSignUpStartPasswordPublicError()
        XCTAssertEqual(error.type, .invalidPassword)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.passwordTooLong)
    }

    func test_toSignUpStartPasswordPublicError_passwordRecentlyUsed() {
        let error = sut.passwordRecentlyUsed.toSignUpStartPasswordPublicError()
        XCTAssertEqual(error.type, .invalidPassword)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.passwordRecentlyUsed)
    }

    func test_toSignUpStartPasswordPublicError_passwordBanned() {
        let error = sut.passwordBanned.toSignUpStartPasswordPublicError()
        XCTAssertEqual(error.type, .invalidPassword)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.passwordBanned)
    }

    func test_toSignUpStartPasswordPublicError_userAlreadyExists() {
        let error = sut.userAlreadyExists.toSignUpStartPasswordPublicError()
        XCTAssertEqual(error.type, .userAlreadyExists)
    }

    func test_toSignUpStartPasswordPublicError_authNotSupported() {
        let error = sut.authNotSupported.toSignUpStartPasswordPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.unsupportedAuthMethod)
    }

    func test_toSignUpStartPasswordPublicError_attributeValidationFailed() {
        let error = sut.attributeValidationFailed.toSignUpStartPasswordPublicError()
        XCTAssertEqual(error.type, .invalidAttributes)
    }

    func test_toSignUpStartPasswordPublicError_attributesRequired() {
        let error = sut.attributesRequired.toSignUpStartPasswordPublicError()
        XCTAssertEqual(error.type, .invalidAttributes)
    }

    func test_toSignUpStartPasswordPublicError_invalidRequest() {
        let error = sut.invalidRequest.toSignUpStartPasswordPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toSignUpStartPasswordPublicError_verificationRequired() {
        let error = sut.verificationRequired.toSignUpStartPasswordPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    // MARK: - to SignUpCodeStartError tests

    func test_toSignUpStartCodePublicError_invalidClient() {
        let error = sut.invalidClient.toSignUpStartPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.invalidClient)
    }

    func test_toSignUpStartCodePublicError_unsupportedChallengeType() {
        let error = sut.unsupportedChallengeType.toSignUpStartPasswordPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.unsupportedChallengeType)
    }

    func test_toSignUpStartCodePublicError_passwordTooWeak() {
        let error = sut.passwordTooWeak.toSignUpStartPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toSignUpStartCodePublicError_passwordTooShort() {
        let error = sut.passwordTooShort.toSignUpStartPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toSignUpStartCodePublicError_passwordTooLong() {
        let error = sut.passwordTooLong.toSignUpStartPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toSignUpStartCodePublicError_passwordRecentlyUsed() {
        let error = sut.passwordRecentlyUsed.toSignUpStartPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toSignUpStartCodePublicError_passwordBanned() {
        let error = sut.passwordBanned.toSignUpStartPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toSignUpStartCodePublicError_userAlreadyExists() {
        let error = sut.userAlreadyExists.toSignUpStartPublicError()
        XCTAssertEqual(error.type, .userAlreadyExists)
    }

    func test_toSignUpStartCodePublicError_authNotSupported() {
        let error = sut.authNotSupported.toSignUpStartPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.unsupportedAuthMethod)
    }

    func test_toSignUpStartCodePublicError_attributeValidationFailed() {
        let error = sut.attributeValidationFailed.toSignUpStartPasswordPublicError()
        XCTAssertEqual(error.type, .invalidAttributes)
    }

    func test_toSignUpStartCodePublicError_attributesRequired() {
        let error = sut.attributesRequired.toSignUpStartPublicError()
        XCTAssertEqual(error.type, .invalidAttributes)
    }

    func test_toSignUpStartCodePublicError_invalidRequest() {
        let error = sut.invalidRequest.toSignUpStartPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toSignUpStartCodePublicError_verificationRequired() {
        let error = sut.verificationRequired.toSignUpStartPublicError()
        XCTAssertEqual(error.type, .generalError)
    }
}
