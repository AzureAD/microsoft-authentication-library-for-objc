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

final class MSALNativeAuthResetPasswordContinueOauth2ErrorCodeTests: XCTestCase {

    private typealias sut = MSALNativeAuthResetPasswordContinueOauth2ErrorCode

    func test_allCases() {
        XCTAssertEqual(sut.allCases.count, 6)
    }

    // MARK: - toVerifyCodePublicError tests

    func test_toVerifyCodePublicError_invalidRequest() {
        let error = sut.invalidRequest.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, nil)
    }

    func test_toVerifyCodePublicError_invalidClient() {
        let error = sut.invalidClient.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.invalidClient)
    }

    func test_toVerifyCodePublicError_invalidGrant() {
        let error = sut.invalidGrant.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, nil)
    }

    func test_toVerifyCodePublicError_expiredToken() {
        let error = sut.expiredToken.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.expiredToken)
    }

    func test_toVerifyCodePublicError_verificationRequired() {
        let error = sut.verificationRequired.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, nil)
    }

    func test_toVerifyCodePublicError_invalidOOBValue() {
        let error = sut.invalidOOBValue.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .invalidCode)
        XCTAssertEqual(error.errorDescription, nil)
    }
}
