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

final class MSALNativeAuthSignUpContinueOauth2ErrorCodeTests: XCTestCase {

    private typealias sut = MSALNativeAuthSignUpContinueOauth2ErrorCode

    func test_allCases() {
        XCTAssertEqual(sut.allCases.count, 16)
    }

    // MARK: - to VerifyCodeError tests

    func test_toVerifyCodePublicError_invalidClient() {
        let error = sut.invalidClient.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.invalidClient)
    }

    func test_toVerifyCodePublicError_invalidOOBValue() {
        let error = sut.invalidOOBValue.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .invalidCode)
    }

    func test_toVerifyCodePublicError_expiredToken() {
        let error = sut.expiredToken.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.expiredToken)
    }

    func test_toVerifyCodePublicError_invalidRequest() {
        let error = sut.invalidRequest.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toVerifyCodePublicError_invalidGrant() {
        let error = sut.invalidGrant.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toVerifyCodePublicError_passwordTooWeak() {
        let error = sut.passwordTooWeak.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toVerifyCodePublicError_passwordTooShort() {
        let error = sut.passwordTooShort.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toVerifyCodePublicError_passwordTooLong() {
        let error = sut.passwordTooLong.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toVerifyCodePublicError_passwordRecentlyUsed() {
        let error = sut.passwordRecentlyUsed.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toVerifyCodePublicError_passwordBanned() {
        let error = sut.passwordBanned.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toVerifyCodePublicError_userAlreadyExists() {
        let error = sut.userAlreadyExists.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toVerifyCodePublicError_attributesRequired() {
        let error = sut.attributesRequired.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toVerifyCodePublicError_verificationRequired() {
        let error = sut.verificationRequired.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toVerifyCodePublicError_credentialRequired() {
        let error = sut.credentialRequired.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toVerifyCodePublicError_attributeValidationFailed() {
        let error = sut.attributeValidationFailed.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toVerifyCodePublicError_invalidAttributes() {
        let error = sut.invalidAttributes.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    // MARK: - to PasswordRequiredError tests

    func test_toPasswordRequiredPublicError_invalidClient() {
        let error = sut.invalidClient.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.invalidClient)
    }

    func test_toPasswordRequiredPublicError_invalidOOBValue() {
        let error = sut.invalidOOBValue.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toPasswordRequiredPublicError_expiredToken() {
        let error = sut.expiredToken.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.expiredToken)
    }

    func test_toPasswordRequiredPublicError_invalidRequest() {
        let error = sut.invalidRequest.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toPasswordRequiredPublicError_invalidGrant() {
        let error = sut.invalidGrant.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toPasswordRequiredPublicError_passwordTooWeak() {
        let error = sut.passwordTooWeak.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .invalidPassword)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.passwordTooWeak)
    }

    func test_toPasswordRequiredPublicError_passwordTooShort() {
        let error = sut.passwordTooShort.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .invalidPassword)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.passwordTooShort)
    }

    func test_toPasswordRequiredPublicError_passwordTooLong() {
        let error = sut.passwordTooLong.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .invalidPassword)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.passwordTooLong)
    }

    func test_toPasswordRequiredPublicError_passwordRecentlyUsed() {
        let error = sut.passwordRecentlyUsed.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .invalidPassword)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.passwordRecentlyUsed)
    }

    func test_toPasswordRequiredPublicError_passwordBanned() {
        let error = sut.passwordBanned.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .invalidPassword)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.passwordBanned)
    }

    func test_toPasswordRequiredPublicError_userAlreadyExists() {
        let error = sut.userAlreadyExists.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toPasswordRequiredPublicError_attributesRequired() {
        let error = sut.attributesRequired.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toPasswordRequiredPublicError_verificationRequired() {
        let error = sut.verificationRequired.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toPasswordRequiredPublicError_credentialRequired() {
        let error = sut.credentialRequired.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toPasswordRequiredPublicError_attributeValidationFailed() {
        let error = sut.attributeValidationFailed.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toPasswordRequiredPublicError_invalidAttributes() {
        let error = sut.invalidAttributes.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    // MARK: - to AttributesRequiredError tests

    func test_toAttributesRequiredPublicError_invalidClient() {
        let error = sut.invalidClient.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.invalidClient)
    }

    func test_toAttributesRequiredPublicError_invalidOOBValue() {
        let error = sut.invalidOOBValue.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toAttributesRequiredPublicError_expiredToken() {
        let error = sut.expiredToken.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.expiredToken)
    }

    func test_toAttributesRequiredPublicError_invalidRequest() {
        let error = sut.invalidRequest.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toAttributesRequiredPublicError_invalidGrant() {
        let error = sut.invalidGrant.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toAttributesRequiredPublicError_passwordTooWeak() {
        let error = sut.passwordTooWeak.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toAttributesRequiredPublicError_passwordTooShort() {
        let error = sut.passwordTooShort.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toAttributesRequiredPublicError_passwordTooLong() {
        let error = sut.passwordTooLong.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toAttributesRequiredPublicError_passwordRecentlyUsed() {
        let error = sut.passwordRecentlyUsed.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toAttributesRequiredPublicError_passwordBanned() {
        let error = sut.passwordBanned.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toAttributesRequiredPublicError_userAlreadyExists() {
        let error = sut.userAlreadyExists.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toAttributesRequiredPublicError_attributesRequired() {
        let error = sut.attributesRequired.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toAttributesRequiredPublicError_verificationRequired() {
        let error = sut.verificationRequired.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toAttributesRequiredPublicError_credentialRequired() {
        let error = sut.credentialRequired.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    func test_toAttributesRequiredPublicError_attributeValidationFailed() {
        let error = sut.attributeValidationFailed.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, .invalidAttributes)
    }

    func test_toAttributesRequiredPublicError_invalidAttributes() {
        let error = sut.invalidAttributes.toAttributesRequiredPublicError()
        XCTAssertEqual(error.type, .invalidAttributes)
    }
}
