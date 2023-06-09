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

final class MSALNativeAuthResetPasswordSubmitOauth2ErrorCodeTests: XCTestCase {

    private typealias sut = MSALNativeAuthResetPasswordSubmitOauth2ErrorCode

    func test_allCases() {
        XCTAssertEqual(sut.allCases.count, 8)
    }

    // MARK: - toPasswordRequiredPublicError tests

    func test_toPasswordRequiredPublicError_invalidRequest() {
        let error = sut.invalidRequest.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, nil)
    }

    func test_toPasswordRequiredPublicError_invalidClient() {
        let error = sut.invalidClient.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.invalidClient)
    }

    func test_toPasswordRequiredPublicError_expiredToken() {
        let error = sut.expiredToken.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.expiredToken)
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
}
