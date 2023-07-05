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

final class MSALNativeAuthSignUpChallengeOauth2ErrorCodeTests: XCTestCase {

    private typealias sut = MSALNativeAuthSignUpChallengeOauth2ErrorCode

    func test_allCases() {
        XCTAssertEqual(sut.allCases.count, 4)
    }

    // MARK: - to SignUpPasswordStartError tests

    func test_toSignUpPasswordStartPublicError_invalidClient() {
        let error = sut.invalidClient.toSignUpPasswordStartPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.invalidClient)
    }

    func test_toSignUpPasswordStartPublicError_unsupportedChallengeType() {
        let error = sut.unsupportedChallengeType.toSignUpPasswordStartPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.unsupportedChallengeType)
    }

    func test_toSignUpPasswordStartPublicError_expiredToken() {
        let error = sut.expiredToken.toSignUpPasswordStartPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.expiredToken)
    }

    func test_toSignUpPasswordStartPublicError_invalidRequest() {
        let error = sut.invalidRequest.toSignUpPasswordStartPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    // MARK: - to SignUpCodeStartError tests

    func test_toSignUpCodeStartPublicError_invalidClient() {
        let error = sut.invalidClient.toSignUpStartPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.invalidClient)
    }

    func test_toSignUpCodeStartPublicError_unsupportedChallengeType() {
        let error = sut.unsupportedChallengeType.toSignUpStartPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.unsupportedChallengeType)
    }

    func test_toSignUpCodeStartPublicError_expiredToken() {
        let error = sut.expiredToken.toSignUpStartPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.expiredToken)
    }

    func test_toSignUpCodeStartPublicError_invalidRequest() {
        let error = sut.invalidRequest.toSignUpStartPublicError()
        XCTAssertEqual(error.type, .generalError)
    }

    // MARK: - to ResendCodeError tests

    func test_toResendCodePublicError_invalidClient() {
        let error = sut.invalidClient.toResendCodePublicError()
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.invalidClient)
    }

    func test_toResendCodePublicError_unsupportedChallengeType() {
        let error = sut.unsupportedChallengeType.toResendCodePublicError()
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.unsupportedChallengeType)
    }

    func test_toResendCodePublicError_expiredToken() {
        let error = sut.expiredToken.toResendCodePublicError()
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.expiredToken)
    }

    func test_toResendCodePublicError_invalidRequest() {
        let error = sut.invalidRequest.toResendCodePublicError()
        XCTAssertNil(error.errorDescription)
    }

    // MARK: - to PasswordRequiredError tests

    func test_toPasswordRequiredPublicError_invalidClient() {
        let error = sut.invalidClient.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.invalidClient)
    }

    func test_toPasswordRequiredPublicError_unsupportedChallengeType() {
        let error = sut.unsupportedChallengeType.toPasswordRequiredPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.unsupportedChallengeType)
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
}
