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

final class MSALNativeAuthResetPasswordChallengeOauth2ErrorCodeTests: XCTestCase {

    private typealias sut = MSALNativeAuthResetPasswordChallengeOauth2ErrorCode

    func test_allCases() {
        XCTAssertEqual(sut.allCases.count, 4)
    }

    // MARK: - to ResetPasswordStartError tests

    func test_toResetPasswordStartPublicError_invalidClient() {
        let error = sut.invalidClient.toResetPasswordStartPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.invalidClient)
    }

    func test_toResetPasswordStartPublicError_invalidRequest() {
        let error = sut.invalidRequest.toResetPasswordStartPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertNotNil(error.errorDescription)
    }

    func test_toResetPasswordStartPublicError_expiredToken() {
        let error = sut.expiredToken.toResetPasswordStartPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.expiredToken)
    }

    func test_toResetPasswordStartPublicError_unsupportedChallengeType() {
        let error = sut.unsupportedChallengeType.toResetPasswordStartPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - to ResendCodePublicError tests

    func test_toResendCodePublicError_invalidClient() {
        let error = sut.invalidClient.toResendCodePublicError()
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.invalidClient)
    }

    func test_toResendCodePublicError_invalidRequest() {
        let error = sut.invalidRequest.toResendCodePublicError()
        XCTAssertNotNil(error.errorDescription)
    }

    func test_toResendCodePublicError_expiredToken() {
        let error = sut.expiredToken.toResendCodePublicError()
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.expiredToken)
    }

    func test_toResendCodePublicError_unsupportedChallengeType() {
        let error = sut.unsupportedChallengeType.toResendCodePublicError()
        XCTAssertNotNil(error.errorDescription)
    }
}
