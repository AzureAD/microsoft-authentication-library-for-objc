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

final class MSALNativeAuthResetPasswordChallengeResponseErrorTests: XCTestCase {

    private var sut: MSALNativeAuthResetPasswordChallengeResponseError!
    private let testDescription = "testDescription"

    // MARK: - to ResetPasswordStartError tests

    func test_toResetPasswordStartPublicError_unauthorizedClient() {
        sut = MSALNativeAuthResetPasswordChallengeResponseError(error: .unauthorizedClient, errorDescription: testDescription, errorCodes: nil, errorURI: nil, innerErrors: nil, target: nil)
        let error = sut.toResetPasswordStartPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }

    func test_toResetPasswordStartPublicError_invalidRequest() {
        sut = MSALNativeAuthResetPasswordChallengeResponseError(error: .invalidRequest, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, target: nil)
        let error = sut.toResetPasswordStartPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertNotNil(error.errorDescription)
    }

    func test_toResetPasswordStartPublicError_expiredToken() {
        sut = MSALNativeAuthResetPasswordChallengeResponseError(error: .expiredToken, errorDescription: testDescription, errorCodes: nil, errorURI: nil, innerErrors: nil, target: nil)
        let error = sut.toResetPasswordStartPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }

    func test_toResetPasswordStartPublicError_unsupportedChallengeType() {
        sut = MSALNativeAuthResetPasswordChallengeResponseError(error: .unsupportedChallengeType, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, target: nil)
        let error = sut.toResetPasswordStartPublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - to ResendCodePublicError tests

    func test_toResendCodePublicError_unauthorizedClient() {
        sut = MSALNativeAuthResetPasswordChallengeResponseError(error: .unauthorizedClient, errorDescription: testDescription, errorCodes: nil, errorURI: nil, innerErrors: nil, target: nil)
        let error = sut.toResendCodePublicError()
        XCTAssertEqual(error.errorDescription, testDescription)
    }

    func test_toResendCodePublicError_invalidRequest() {
        sut = MSALNativeAuthResetPasswordChallengeResponseError(error: .invalidRequest, errorDescription: testDescription, errorCodes: nil, errorURI: nil, innerErrors: nil, target: nil)
        let error = sut.toResendCodePublicError()
        XCTAssertEqual(error.errorDescription, testDescription)
    }

    func test_toResendCodePublicError_expiredToken() {
        sut = MSALNativeAuthResetPasswordChallengeResponseError(error: .expiredToken, errorDescription: testDescription, errorCodes: nil, errorURI: nil, innerErrors: nil, target: nil)
        let error = sut.toResendCodePublicError()
        XCTAssertEqual(error.errorDescription, testDescription)
    }

    func test_toResendCodePublicError_unsupportedChallengeType() {
        sut = MSALNativeAuthResetPasswordChallengeResponseError(error: .unsupportedChallengeType, errorDescription: testDescription, errorCodes: nil, errorURI: nil, innerErrors: nil, target: nil)
        let error = sut.toResendCodePublicError()
        XCTAssertEqual(error.errorDescription, testDescription)
    }
}
